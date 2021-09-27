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

not_applicable || (!quote_rebalance && !($0 ~ FS)) {
    gsub(FS, OFS)
    print
    next
}

simple_replace {
    gsub(replace_fieldsep, OFS)
    print
    next
}

quote_rebalance && !($0 ~ QRe["e"]) {
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
        quotequotefs = quotequote space FS
        fsinglequote = FS space q
        BuildRe(QRe, FS, q, space)
        quotequote_replace = retain_outer_quotes ? quotequote : q
    }

    if (debug) DebugPrint(3)

    if (quote_rebalance) {
        if (debug) DebugPrint(4)
        save_bal = balance_os
        diff = QBalance($0, QRe, quote_rebalance) 
        balance_os += diff
        if (debug && save_bal != balance_os) DebugPrint(5)
        if (diff && balance_os == 0) {
            quote_rebalance = 0
            close_multiline_field = 1
        }
    }
    else if (run_prefield) {
        balance_os = QBalance($0, QRe)
        save_i = 1
    }

    if (debug && quote_rebalance) print "carried q"
    if (balance_os) {
        if (debug) print "Unbalanced"
        quote_rebalance = 1
    }

    if (run_prefield && (quote_rebalance || $0 ~ q)) {
        i_seed = diff && save_i ? save_i : 1
        for (i = i_seed; i < 500; i++) {
            gsub(quotequote, "_qqqq_", $0)
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
                match($0, QRe["e_imbal"])
                startf = 1
                endf = RLENGTH - mod_f_len0
                quote_cut = mod_f_len0
            }
            else {
                match($0, fsinglequote)
                index_fieldsep_quote = RSTART
                len_index_fieldsep_quote = RLENGTH
                match($0, FS)
                index_fieldsep = RSTART
                len_fieldsep = Max(RLENGTH, 1)
                index_quote = index($0, q)
                index_quotequote = index($0, "_qqqq_")
                if (balance_os) {
                    match($0, QRe["s_imbal"])
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
                    startf = balance_os ? mod_f_len1 : len_fieldsep + mod_f_len0
                    endf = index_quote_fieldsep - quote_cut_len
                    
                    if (endf < 1) {
                        if (index_quote != 1 && !balance_os) {
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
            gsub("_qqqq_", quotequote_replace, _[i])
            $0 = substr($0, endf + len_fieldsep + quote_cut + 1)
            if (debug) DebugPrint(2)
            close_multiline_field = 0
        }
    }
    else {
        for (i = 1; i <= NF; i++)
            _[i] = $i
    }

    if (balance_os) {
        quote_rebalance = 1
        save_i = i - 1
        next
    }

    len_ = length(_)
    for (i = 1; i < len_; i++) {
        printf "%s", _[i] OFS
        delete _[i]
    }

    print _[len_]; delete _[len_]; delete prev_i
}

function BuildRe(ReArr, sep, q, space) {
    ReArr["exc"] = "[^"q"]*[^"sep"]*[^"q"]+"
    ReArr["sep_exc"] = "[^"q sep"]+"
    ReArr["l"] = "(^|"sep")"space q
    ReArr["r"] = q space"("sep"|$)"
    ReArr["f"] = ReArr["l"] ReArr["exc"] ReArr["r"]
    ReArr["s"] = "(^|"sep")"space q space"("quotequote"[^"q"]|[^"q"]|$)"
    ReArr["e"] = "(^|[^"q"]|[^"q"]"quotequote")"space q space"("sep"|$)"
    ReArr["s_imbal"] = "^"space q ReArr["exc"]"$"
    ReArr["e_imbal"] = "^[^"q sep"]*[^"q"]*" q
}
function QBalance(line, QRe, quote_set) {
    tmp_starts = line
    tmp_ends = line
    n_starts = gsub(QRe["s"], "", tmp_starts)
    n_ends = gsub(QRe["e"], "", tmp_ends)
    if (debug) print "n_starts: "n_starts", n_ends: "n_ends
    base_diff = n_starts - n_ends
    bal = n_starts > 0 ? base_diff - quote_set : base_diff
    return bal
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
        if (balance_os) print "balance os: "balance_os", index_quote_imbal_start: "index_quote_imbal_start }
    else if (case == 2) {
        print "_["i"] = substr($0, "startf", "endf")"
        print "$0 = substr($0, "endf" + "len_fieldsep" + "quote_cut" + 1)"
        print "----- OUTPUT FIELD "i" -----"
        print _[i]
        print "" }
    else if (case == 3) {
        print ""
        print "NR: "NR", $0: "$0
        print "match_start: "match($0, QRe["s"])", RLENGTH: "RLENGTH" QRe[\"s\"]"QRe["s"]
        print "match_field: "match($0, QRe["f"])", RLENGTH: "RLENGTH" QRe[\"f\"]"QRe["f"] }
    else if (case == 4)
        print "bal: "balance_os
    else if (case == 5)
        print "newbal: "balance_os
    else if (case == 6)
        print "NR: "NR", save_i: "save_i", _[save_i]: "_[save_i]
}

