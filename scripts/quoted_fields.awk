#!/usr/bin/awk
#
# Print fields containing a field separator as one field as long as they are
# surrounded by single or double quotes
#
# Example execution:
# > awk -v FS="," -f quoted_fields.awk file.csv
## TODO: Carriage return character handling


BEGIN {
    singlequote = "'"
    doublequote = "\""

    if (FS == "" \
        || FS ~ singlequote \
        || FS ~ doublequote \
        || (FS ~ ":" && !(FS ~ /\[/))) {
        not_applicable = 1
    }
    else if (FS == "@@@") {
        simple_replace = 1
        replace_fieldsep = retain_outer_quotes ? OFS : "(\"?" OFS "\"?|'?" OFS "'?)"
    }
    else {
        if (FS == " ") FS = "[[:space:]]+"
        if (fixed_space) FS = " "
        len_fieldsep = length(FS)

        if (!("          " ~ "^"FS"$")) {
            space = "[[:space:]]*"
            init_space = "^" space
        }

        doublequotere = "(^|[^"doublequote"]*[^"FS"]*[^"doublequote"]+"FS")"space doublequote
        singlequotere = "(^|[^"singlequote"]*[^"FS"]*[^"singlequote"]+"FS")"space singlequote

        quote_cut_len = retain_outer_quotes ? 0 : 2
        mod_f_len1 = retain_outer_quotes ? 1 : 2
        mod_f_len0 = retain_outer_quotes ? 0 : 1
        if (debug) DebugPrint(0)
    }
}

{
    gsub(/\015$/, "") # Remove Carriage Returns "\r"
}

not_applicable || (!quote_rebalance && !($0 ~ FS) && q && !($0 ~ q)) {
    gsub(FS, OFS)
    print
    next
}

simple_replace {
    gsub(replace_fieldsep, OFS)
    print
    next
}

quote_rebalance && !($0 ~ QRe["end"]) {
    if (debug) DebugPrint(6)
    _[save_i] = _[save_i] " \\n " $0
    next
}

{
    diff = 0
    index_quote_imbal_start = 0
    close_multiline_field = 0
    
    if (!doublequoteset) {
        doublequoteset = ($0 ~ doublequotere)
        if (doublequoteset) {
            q = doublequote
            qre = doublequotere
            init_quote = 1
        }
    }
    
    if (!doublequoteset && !singlequoteset) {
        singlequoteset = ($0 ~ singlequotere)
        if (singlequoteset) {
            q = singlequote
            qre = singlequotere
            init_quote = 1
        }
    }
    
    if (init_quote) {
        init_quote = 0
        run_prefield = 1
        quotequote = q q
        quote_fieldsep = q space FS
        quotequote_marker = "_qqqq_"
        empty_field_re = "^" quotequote_marker space "$"
        fieldsep_quote = FS space q
        BuildRe(QRe, FS, q, space)
        quotequote_replace0 = retain_outer_quotes ? quotequote : ""
        quotequote_replace1 = retain_outer_quotes ? quotequote : q
    }

    if (debug) DebugPrint(3)

    if (quote_rebalance) {
        if (debug) DebugPrint(4)
        save_bal = balance_outstanding
        starts = QuoteStarts($0, QRe)
        ends = QuoteEnds($0, QRe)
        balance_outstanding += starts - ends
        if (debug && save_bal != balance_outstanding) DebugPrint(5)
        if (ends) {
            if (balance_outstanding == 0) quote_rebalance = 0
            close_multiline_field = 1
        }
    }
    else if (run_prefield) {
        balance_outstanding = QuoteDiff($0, QRe)
        save_i = 1
    }

    if (debug && quote_rebalance) print "carried q"
    if (balance_outstanding) {
        if (debug) print "Unbalanced"
        quote_rebalance = 1
    }

    if (run_prefield && (quote_rebalance || $0 ~ q)) {
        i_seed = save_i ? save_i : 1
        
        for (i = i_seed; i < 500; i++) {
            gsub(quotequote, quotequote_marker, $0)
            gsub(init_space, "", $0)
            len0 = length($0)
            if (len0 < 1) break

            match($0, quote_fieldsep)
            index_quote_fieldsep = RSTART
            len_index_quote_fieldsep = RLENGTH
            
            while (substr($0, index_quote_fieldsep - 1, 1) == q \
                    && substr($0, index_quote_fieldsep - 2, 1) != q) {
                match(substr($0, index_quote_fieldsep, len0), quote_fieldsep)
                index_quote_fieldsep = RSTART
                len_index_quote_fieldsep = RLENGTH
            }

            if (close_multiline_field) {
                match($0, QRe["end_imbal"])
                startf = 1
                endf = RLENGTH - mod_f_len0
                quote_cut = mod_f_len0
            }
            else {
                match($0, fieldsep_quote)
                index_fieldsep_quote = RSTART
                len_index_fieldsep_quote = RLENGTH
                match($0, FS)
                index_fieldsep = RSTART
                len_fieldsep = Max(RLENGTH, 1)
                index_quote = index($0, q)
                index_quotequote = index($0, quotequote_marker)
                
                if (balance_outstanding) {
                    match($0, QRe["start_imbal"])
                    index_quote_imbal_start = RSTART
                    match($0, QRe["sep_exc"])
                    inquote_fieldsep = RSTART
                }
                
                if (index_quote == 1 && !(index_quotequote == 1)) {
                    quote_set = 1
                }
                
                quote_cut = 0

                if (debug) {
                    previous_i = i - 1
                    if (_[previous_i]) pi = _[previous_i]
                    DebugPrint(1)
                }

                if (quote_set) {
                    quote_set = 0
                    quote_cut = quote_cut_len
                    startf = balance_outstanding ? mod_f_len1 : len_fieldsep + mod_f_len0
                    endf = index_quote_fieldsep - quote_cut_len
                    
                    if (endf < 1) {
                        if (index_quote != 1 && !balance_outstanding) {
                            startf++
                        }
                        endf = len0 - quote_cut_len
                    }
                }
                else {
                    if (index_quote == 0 && index_fieldsep == 0) {
                        startf = 1
                        endf = len0
                    }
                    else if (index_quote_imbal_start > 0 \
                            && index_quote_imbal_start <= inquote_fieldsep \
                            && index_quote_imbal_start < index_quote \
                            && index_quote_imbal_start < index_fieldsep) {
                        
                        if (retain_outer_quotes) {
                            startf = index_quote_bal
                            endf = len0
                        }
                        else {
                            startf = index_quote_bal + 1
                            endf = len0 - 1
                        }
                    }
                    else if (index_quote == index_quotequote \
                            && (index_quote_fieldsep - 1 == index_quote \
                                    || index_fieldsep == 0)) {
                        
                        if (retain_outer_quotes) {
                            startf = index_quote
                            endf = index_quote + 2
                        }
                        else {
                            startf = index_quote + 1
                            endf = index_quote + 1
                        }
                    }
                    else if ((index_quote_fieldsep > 0 || substr($0,len0) == q) \
                            && index_fieldsep_quote == index_fieldsep) {
                        startf = 1
                        endf = index_fieldsep_quote - 1
                        quote_set = 1
                    }
                    else if (index_fieldsep == 0) {
                        startf = len_fieldsep + 1
                        endf = len0 - 1
                    }
                    else if (index_quote - index_fieldsep == 1) {
                        if (index_quote_fieldsep || index(substr($0,2),q) == len0) {
                            quote_set = 1
                            startf = 1
                            endf = index_fieldsep - mod_f_len1
                        }
                        else {
                            startf = len_fieldsep
                            endf = index_fieldsep - mod_f_len0
                        }
                    }
                    else if (index_quote == 0) {
                        startf = 1
                        endf = index_fieldsep - 1
                    }
                    else if (index_quote - index_fieldsep > 1 \
                            || index_fieldsep - index_quote > 1) {
                        startf = 1
                        endf = index_fieldsep - 1
                    }
                    else {
                        startf = 1
                        endf = index_fieldsep - 1
                    }
                }
            }

            f_part = substr($0, startf, endf)
            _[i] = close_multiline_field ? _[i] f_part : f_part
            
            # Field is empty if only has two quotes
            gsub(empty_field_re, quotequote_replace0, _[i])
            # Any remaining quotequotes assumed escaped quotes
            gsub("_qqqq_", quotequote_replace1, _[i])
            
            $0 = substr($0, endf + len_fieldsep + quote_cut + 1)
            if (debug) DebugPrint(2)
            close_multiline_field = 0
        }
    }
    else {
        for (i = 1; i <= NF; i++)
            _[i] = $i
    }

    if (balance_outstanding) {
        quote_rebalance = 1
        save_i = i - 1
        next
    }

    len_ = length(_)
    for (i = 1; i < len_; i++) {
        printf "%s", _[i] OFS
        delete _[i]
    }

    print _[len_]
    delete _[len_]
    delete prev_i
}

function BuildRe(ReArr, sep, q, space) {
    exclude_fieldsep_quote = GetExclusiveQuoteRegex(sep, q)
    ReArr["exc"] = "[^"q"]*[^"sep"]*[^"q"]+"
    ReArr["sep_exc"] = "[^"q sep"]+"
    ReArr["left"] = "(^|"sep")"space q
    ReArr["right"] = q space"("sep"|$)"
    ReArr["field"] = ReArr["left"] ReArr["exc"] ReArr["right"]
    ReArr["start"] = "(^|"sep")"space q space"("quotequote exclude_fieldsep_quote"|"exclude_fieldsep_quote"|$)"
    ReArr["end"] = "(^|"exclude_fieldsep_quote"|"exclude_fieldsep_quote quotequote")"space q space"("sep"|$)"
    ReArr["start_imbal"] = "^"space q ReArr["exc"]"$"
    ReArr["end_imbal"] = "^[^"q sep"]*[^"q"]*" q
}
function GetExclusiveQuoteRegex(str, quote,   regex, c) {
    regex = ""
    split(str, Chars, "")
    for (c in Chars) {
        escape_c = match(Chars[c], /[A-z0-9]/) ? Chars[c] : "\\" Chars[c]
        if (c > 1) {
            regex = regex "[^" escape_c "]"
        }
        else {
            regex = regex "[^" quote escape_c "]"
        }
    }
    return regex
}
function QuoteStarts(line, QRe) {
    tmp_line = line
    return gsub(QRe["start"], "", tmp_line)
}
function QuoteEnds(line, QRe) {
    tmp_line = line
    return gsub(QRe["end"], "", tmp_line)
}
function QuoteDiff(line, QRe, quote_set) {
    n_starts = QuoteStarts(line, QRe)
    n_ends = QuoteEnds(line, QRe)
    if (debug) print "n_starts: "n_starts", n_ends: "n_ends
    return n_starts - n_ends
}
function DebugPrint(case) {
    if (case == 0) {
        print "-------- SETUP --------"
        print "retain_outer_quotes: "retain_outer_quotes" quote_cut_len: "quote_cut_len" mod_f_len0: "mod_f_len0" mod_f_len1: "mod_f_len1
        print "---- CALCS / OUTPUT ----" }
    else if (case == 1 ) {
        print "----- CALCS FIELD "i" ------"
        print "NR: "NR" quote_set: " quote_set " len0: " len0 " $0: " $0
        print "previous_i: " pi
        print "index_fieldsep: "index_fieldsep" index_quote: "index_quote" index_quote_fieldsep: "index_quote_fieldsep" index_fieldsep_quote: "index_fieldsep_quote" index_quotequote: "index_quotequote 
        if (balance_outstanding) print "balance outstanding: "balance_outstanding", index_quote_imbal_start: "index_quote_imbal_start }
    else if (case == 2) {
        if (close_multiline_field) {
            print "_["i"] = _[save_i] substr($0, "startf", "endf")"
            print "$0 = substr($0, "endf" + "len_fieldsep" + "quote_cut" + 1)"
            print "----- OUTPUT FIELD "i" -----"
            print _[i]
            print ""
        }
        else {
            print "_["i"] = substr($0, "startf", "endf")"
            print "$0 = substr($0, "endf" + "len_fieldsep" + "quote_cut" + 1)"
            print "----- OUTPUT FIELD "i" -----"
            print _[i]
            print ""
        }
    }
    else if (case == 3) {
        print ""
        print "NR: "NR", $0: "$0
        print "match_start: "match($0, QRe["start"])", RLENGTH: "RLENGTH" QRe[\"s\"]"QRe["start"]
        print "match_field: "match($0, QRe["field"])", RLENGTH: "RLENGTH" QRe[\"f\"]"QRe["field"] }
    else if (case == 4)
        print "bal: "balance_outstanding
    else if (case == 5)
        print "newbal: "balance_outstanding
    else if (case == 6)
        print "NR: "NR", save_i: "save_i", _[save_i]: "_[save_i]
}

