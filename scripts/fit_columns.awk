#!/usr/bin/awk
# DS:FIT
# 
# NAME
#       ds:fit, fit_columns.awk
#
# SYNOPSIS
#       ds:fit [-h|--help|file] [prefield=t] [awkargs]
#
# DESCRIPTION
#       fit_columns.awk is a sript to fit a table of values with dynamic column 
#       lengths. If running with AWK, files must be passed twice.
#
#       To run on a single file, ensure utils.awk is passed first:
#
#          $ awk -f support/utils.awk -f fit_columns.awk file{,}
#
#       ds:fit is the caller function for the fit_columns.awk script. To run with 
#       any of the overrides below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#          $ data_in | ds:fit [awkargs]
#
#       When running with ds:fit, an attempt will be made to infer a field separator 
#       of up to three characters. If none is found, FS will be set to default value,
#       a single space = " ". To override the FS, add as a trailing awkarg. Be sure 
#       to escape and quote if needed. AWK's extended regex can be used as FS:
#
#          $ ds:fit datafile -v FS=" {2,}"
#
#       When running ds:fit, an attempt is made to extract relevant instances of field
#       separators in the case that a field separator appears in field values. This is 
#       currently a persistent setting.
#
#       ds:fit will also attempt to detect whether AWK is multibyte safe to handle 
#       cases of multibyte characters with a width that does not match its awk length.
#       If a limited version of AWK is installed, the fit for multibyte characters 
#       such as emoji may be incorrect.
#
# OPTS AND AWKARG OPTS
#       Print this help:
#
#         -h, --help
#
#       Run with gridlines (overrides buffer, bufferchar; does not work with
#       onlyfit, nofit):
#
#         -v gridlines=1
#
#       Run with custom buffer (default is 1):
#
#         -v buffer=5
#
#       Custom character for buffer/separator:
#
#         -v bufferchar="|"
#
#       Run with custom decimal setting:
#
#         -v d=4
#
#       Run with custom decimal setting of zero:
#
#         -v d=z
#
#       Run with float output on decimal/number-valued fields:
#
#         -v d=-1
#
#       Run without decimal or scientific notation transformations:
#
#         -v no_tf_num=1
#
#       Turn off default behavior of setting zeros in decimal columns to "-":
#
#         -v no_zero_blank=1
#
#       Run with no color or warning:
#
#         -v color=never
#
#       Fit all rows except where matching pattern:
#
#         -v nofit=pattern
#
#       Fit only rows matching pattern, print rest normally:
#
#         -v onlyfit=pattern
#
#       Start fit at pattern, end fit at pattern:
#
#         -v startfit=startpattern
#         -v endfit=endpattern
#
#       NOTE: To match the FS in patterns above, use the string '__FS__'
#
#       Start fit at row number, end fit at row number:
#
#         -v startrow=100
#         -v endrow=200
#
#       Fit up to a certain number of columns, and squeeze the rest:
#
#         -v endfit_col=10
#
# VERSION
#       1.3
#
# AUTHORS
#       Tom Hall (tomhallmain@gmail.com)
#
## TODO: Resolve lossy multibyte char output
## TODO: Fit newlines in fields
## TODO: Fix rounding in some cases (see test reo output fit)
## TODO: Pagination
## TODO: Variant float output for normal sized nums
## TODO: SetType function checking field against relevant re one time at start

BEGIN {
    WCW_FS = " "
    FIT_FS = FS

    if (file && !nofit && !onlyfit && !startfit && !endfit && !startrow && !endrow) {
        if (file ~ /\.(properties|csv|tsv)$/ && !gridlines)
            nofit = "^#"
    }
    else if (nofit || onlyfit || startfit || endfit) {
        gsub(/__FS__/, FS, nofit)
        gsub(/__FS__/, FS, onlyfit)
        gsub(/__FS__/, FS, startfit)
        gsub(/__FS__/, FS, endfit)
    }

    partial_fit = nofit || onlyfit || startfit || endfit || startrow || endrow
    prefield = FS == "@@@"
    OFS = SetOFS()

    if (d != "z" && !(d ~ /-?[0-9]+/)) {
        d = 0
    } else if (d < 0) {
        sn = -d
        d = "z"
    }

    if (d) {
        fix_dec = d == "z" ? 0 : d
    }

    zero_blank = !no_zero_blank || zero_blank

    sn0_len = 1 + 4 # e.g. 0e+00
  
    if (sn && d) {
        if (d == "z") {
            sn_len = sn0_len
        }
        else {
            sn_len = 2 + d + 4 # e.g. 0.00e+00
        }
    }

    if (gridlines) {
        if (nofit || onlyfit) {
            gridlines = 0 # This option combination is too complex
        }
        else {
            gridlines = 1
            buffer = 5
            bufferchar = "\xE2\x94\x82"
            gridline_base_char = "\xE2\x94\x80"
            if (!partial_fit) {
                to_print_start_gridline = 1
                to_print_final_gridline = 1
            }
            for (i = 0; i < 100; i++) gridline_base = gridline_base gridline_base_char
        }
    }

    if (!buffer) buffer = 2
    if (!(color == "never" || color == "off")) {
        color_on = 1
        color_pending = 1
    }
    
    space_str = "                                                                   "
    buffer_str = bufferchar space_str

    if (!(color == "never")) {
        hl = "\033[1;36m"
        white = "\033[1:37m"
        orange = "\033[38;2;255;165;1m"
        red = "\033[1;31m"
        no_color = "\033[0m"
    }

    # TODO: Support more complex color defs like orange above
    color_re = "\x1b\[((0|1);)?(3|4)?[0-7](;(0|1))?m"
    trailing_color_re = "[^^]\x1b\[((0|1);)?(3|4)?[0-7](;(0|1))?m"
    null_re = "^\<?NULL\>?$"
    int_re = "^[[:space:]]*-?(\\$|£)?[0-9]+[[:space:]]*$"
    num_re = "^[[:space:]]*(\\$|£)?-?(\\$|£)?(([0-9])?([0-9])?[0-9](,[0-9][0-9][0-9])*(\\.[0-9]+)?|[0-9]*\\.?[0-9]+)[[:space:]]*$"
    decimal_re = "^[[:space:]]*(\\$|£)?-?(\\$|£)?(([0-9])?([0-9])?[0-9](,[0-9][0-9][0-9])*(\\.[0-9]+)|[0-9]*\\.[0-9]+)[[:space:]]*$"
    float_re = "^[[:space:]]*-?[0-9]\.[0-9]+(E|e)(\\+|-)?[0-9]+[[:space:]]*$"

    if (!tty_size) {
        "[ \"$TERM\" ] && tput cols || echo 100" | getline tty_size; tty_size += 0
    }
}


## Reconcile lengths with term width after first pass

FNR < 2 && NR > FNR {
    for (i = 1; i <= max_nf; i++) {
        if (FieldMax[i]) {
            MaxFieldLen[i] = FieldMax[i]
            total_fields_len += buffer

            if (FieldMax[i] / total_fields_len > 0.4 ) { 
                GMax[i] = FieldMax[i] + buffer
                g_max_len += GMax[i]
                g_count++
            }
        }
    }

    shrink = tty_size && total_fields_len > tty_size

    if (shrink) {
        if (color_on) PrintWarning()

        if (length(GMax)) {
            while (g_max_len / total_fields_len / length(GMax) > Min(length(GMax) / max_nf * 2, 1) \
                            && total_fields_len > tty_size) {
                for (i in GMax) {
                    cut_len = int(FieldMax[i]/30)
                    FieldMax[i] -= cut_len
                    total_fields_len -= cut_len
                    g_max_len -= cut_len
                    ShrinkF[i] = 1
                    MaxFieldLen[i] = FieldMax[i]
                    if (debug) DebugPrint(9)
                }
            }
        }

        reduction_scaler = 14
    
        while (total_fields_len > tty_size && reduction_scaler > 0) {
            average_field_len = total_fields_len / max_nf
            cut_len = int(average_field_len/10)
            scaled_cut = cut_len * reduction_scaler
            if (debug) DebugPrint(4)
      
            for (i = 1; i <= max_nf; i++) {
                if (!DecimalSet[i] \
                        && !(NumberSet[i] && !NumberOverset[i]) \
                        && FieldMax[i] > scaled_cut \
                        && FieldMax[i] - cut_len > buffer) {
                    mod_cut_len = int((cut_len*2) ^ (FieldMax[i]/total_fields_len))
                    FieldMax[i] -= cut_len
                    total_fields_len -= cut_len
                    ShrinkF[i] = 1
                    MaxFieldLen[i] = FieldMax[i]
                    if (debug) DebugPrint(5)
                }
            }

            reduction_scaler--
        }
    }
}

partial_fit {
    started_new_fit = 0
    
    if (FNR < 2) {
        fit_complete = 0
        in_fit = 0
    }
    if (in_fit) {
        if ((endfit && $0 ~ endfit) \
            || (endrow && FNR == endrow)) {
            in_fit = 0
            fit_complete = 1
            if (NR > FNR && gridlines) {
                to_print_final_gridline = 1
            }
        }
    }
    else {
        if (fit_complete \
            || (nofit && $0 ~ nofit) \
            || (onlyfit && !($0 ~ onlyfit)) \
            || (startrow && FNR < startrow) \
            || (startfit && !($0 ~ startfit))) {
            if (NR == FNR) {
                next
            } else {
                if (gridlines && to_print_final_gridline) {
                    PrintGridline(1, max_nf)
                    to_print_final_gridline = 0
                }
                if (prefield) gsub(FS, OFS) # Need to add to prefield too to ensure this isn't lossy
                print
                next
            }
        }
        else if ((startfit && $0 ~ startfit) \
            || (startrow && FNR == startrow) \
            || (!startfit && endfit) \
            || (!startrow && endrow)) {
            in_fit = 1
            if (gridlines) {
                to_print_start_gridline = 1
            }
        }
    }
}

$0 ~ /^No matches found/ {
    print
    err = 1
    exit(err)
}

## First pass, gather field info

NR == FNR {
    fitrows++

    for (i = 1; i <= NF; i++) {
        if (endfit_col) {
            if (i == 1) res_line = $0
            if (i < endfit_col) {
                init_f = $i
                match(res_line, FS)
                res_line = substr(res_line, RSTART+RLENGTH, length(res_line))
            }
            else {
                gsub("[[:space:]]*" FS "[[:space:]]*", OFS, res_line)
                ResLine[NR] = res_line
                init_f = res_line
            }
        }
        else {
            init_f = $i
            gsub("(^[[:space:]]*|[[:space:]]*$|^[[:space:]]+$)", "", init_f)
        }

        init_len = length(init_f)
        if (init_len < 1) continue

        f_ntc = StripTrailingColors(init_f)
        len_ntc = length(f_ntc)
        tc_diff = init_len - len_ntc
        if (tc_diff > 0) {
            color_detected = 1
            COLOR_DIFF[NR, i] = tc_diff
        }

        f = StripColors(init_f)
        len = length(f)
        if (len < 1) continue

        orig_max = FieldMax[i]
        len_diff = len - orig_max
        decimal_diff = 0
        decimal_max_diff = 0
        field_diff = 0

        # Get the actual field length

        if (awksafe && f != 0) {
            FS = WCW_FS
            wcw = wcscolumns(f)
            FS = FIT_FS

            wcw_diff = len - wcw

            if (wcw_diff == 0) {
                f_wcw_kludge = StripBasicASCII(f)
                len_wcw_kludge = length(f_wcw_kludge)
                wcw_diff += len_wcw_kludge
            }
            if (wcw_diff) {
                WCWIDTH_DIFF[NR, i] = wcw_diff
                if (debug) DebugPrint(10)
            }
        }

        # If column confirmed as number column and not confirmed as decimal
        # and current field is not blank, null, or number, overset the number
        # setting for column
        
        if (len > 0 && NumberSet[i] && !DecimalSet[i] && !NumberOverset[i] && !AnyFormatNumber(f) && !(f ~ null_re)) {
            NumberOverset[i] = 1
            if (debug) DebugPrint(8)
            if (SaveNumberMax[i] > FieldMax[i] && SaveNumberMax[i] > SaveSMax[i]) {
                recap_n_diff = Max(SaveNumberMax[i] - FieldMax[i], 0)
                FieldMax[i] += recap_n_diff
                total_fields_len += recap_n_diff
            }
        }

        # Handle number field lengths and mark column as number column
        # if in first 30 rows

        if (f ~ num_re) {
            commas = gsub(",", "", f)

            if (commas) {
                len_diff -= commas
                len -= commas
            }

            if (fitrows < 30) {
                if (debug && !NumberSet[i]) DebugPrint(7)
                NumberSet[i] = 1
            }

            if (NumberSet[i] && !NumberOverset[i]) {
                if (f ~ int_re) {
                    if (len > IMax[i]) IMax[i] = len

                    if (!DecimalSet[i] && len > DecPush[i] && f ~ /^(\$|£|-)/) {
                        DecPush[i] = len
                    }
                }
                if (f ~ /^0+[1-9]/) {
                    f = sprintf("%f", f)
                    if (f ~ /\.[0-9]+0+/) {
                        sub(/0*$/, "", f) # Remove trailing zeros in decimal part
                    }

                    len = length(f)
                    len_diff = len - orig_max
                }
                if (len > NumberMax[i]) NumberMax[i] = len 
            }
        }

        if (NumberSet[i] && !NumberOverset[i] && !LargeVals[i] && (f+0 > 9999)) LargeVals[i] = 1

        # If column unconfirmed as decimal and the current field is decimal
        # set decimal for column and handle field length changes

        if (!no_tf_num && !DecimalSet[i] && ComplexFmtNum(f)) {
            DecimalSet[i] = 1

            float = f ~ float_re
            tval = TruncVal(f, 0, LargeVals[i])

            if (tval ~ /\.[0-9]+0+/) {
                sub(/0*$/, "", tval) # Remove trailing zeros in decimal part
            }
            sub(/\.0*$/, "", tval) # Remove decimal part if equal to zero

            t_len = length(tval)
            t_diff = 0
            len_diff = t_len - orig_max

            split(tval, NParts, /\./)
            dec_len = length(NParts[2])
            DecimalMax[i] = dec_len
            apply_decimal = (d != "z" && (d || DecimalMax[i]))

            if (sn) {
                if (!d) sn_len = 2 + dec_len + 4
                sn_diff = sn_len - orig_max
                field_diff = Max(sn_diff, 0)
            }
            else {
                gsub(/[^0-9\-]/, "", NParts[1])
                int_len = length(NParts[1])
                if (int_len > 4) LargeVals[i] = 1

                if (DecPush[i] && !(NParts[1] ~ /^($|-)/)) {
                    int_len = Max(DecPush[i] + apply_decimal, int_len)
                    dec_push = 1
                    delete DecPush[i]
                }
                if (int_len > NumberMax[i]) NumberMax[i] = int_len
                int_diff = int_len - t_len

                if (int_len > IMax[i]) {
                    IMax[i] = int_len
                }
                else {
                    int_diff += IMax[i] - int_len
                }

                if (len_diff > 0) {
                    if (apply_decimal) {
                        dot = (fix_dec || dec_len ? 1 : 0)
                        dec = (float || !dec_len ? dot : 0)
                        decimal_diff = dec + (d ? fix_dec : dec_len)
                    }

                    field_diff = Max(len_diff + int_diff + decimal_diff - t_diff, 0)
                }
            }

            if (debug) DebugPrint(2)
        }

        # Else if column confirmed as decimal and current field is decimal
        # handle field length adjustments

        else if (!no_tf_num && DecimalSet[i] && AnyFormatNumber(f)) {
            float = f ~ float_re
            tval = TruncVal(f, 0, LargeVals[i])

            if (tval ~ /\.[0-9]+0+/) {
                sub(/0*$/, "", tval) # Remove trailing zeros in decimal part
            }
            sub(/\.0*$/, "", tval) # Remove decimal part if equal to zero

            t_len = length(tval)
            t_diff = float ? 0 : Max(len - t_len, 0)
            len_diff = t_len - orig_max

            split(tval, NParts, /\./)
            dec_len = length(NParts[2])

            if (dec_len > DecimalMax[i]) {
                decimal_max_diff = float ? dec_len - DecimalMax[i] : 0
                DecimalMax[i] = dec_len
            }

            apply_decimal = (d != "z" && (d || DecimalMax[i]))

            if (sn) {
                if (!d) sn_len = 2 + DecimalMax[i] + 4
                sn_diff = sn_len - orig_max
                field_diff = Max(sn_diff, 0)
            }
            else {
                gsub(/[^0-9\-]/, "", NParts[1])
                int_len = length(int(NParts[1]))
                if (int_len > 4) LargeVals[i] = 1

                if (orig_max) {
                    if (DecPush[i] && !(NParts[1] ~ /^($|-)/)) {
                        int_len = Max(DecPush[i], int_len)
                        dec_push = 1
                        delete DecPush[i]
                    }
                    if (int_len > NumberMax[i]) NumberMax[i] = int_len
                    int_diff = len - t_len

                    if (int_len > IMax[i]) {
                        IMax[i] = int_len
                    }
                    else if (!float) {
                        int_diff += IMax[i] - int_len
                    }

                    if (apply_decimal) {
                        dot = 1
                        dec = (d ? fix_dec : DecimalMax[i])
                        decimal_diff = (float || !dec_len ? dot : 0) + dec - dec_len
                        field_diff = Max(len_diff + int_diff + decimal_diff + decimal_max_diff - t_diff, 0)
                    }
                    else {
                        field_diff = Max(len_diff + int_diff + decimal_diff + decimal_max_diff - t_diff, 0)
                    }
                }

                else {
                    if (int_len > NumberMax[i]) NumberMax[i] = int_len
                    field_diff = len_diff
                }
            }

            if (debug && field_diff) DebugPrint(3)
        }

        # Otherwise just handle simple field length increases and store number
        # columns for later justification

        else if (len_diff > 0) {
            if (NumberSet[i] && !NumberOverset[i] && f ~ num_re) {
                if (len > SaveNumberMax[i]) {
                    SaveNumberMax[i] = len
                }
                if (sn && NumberMax[i] > sn0_len) {
                    sn_diff = sn0_len - orig_max
                    len_diff = sn_diff
                }
            }

            if (sn && !(f ~ num_re) && len > SaveSMax[i]) {
                SaveSMax[i] = len
            }

            field_diff = len_diff

            if (debug) DebugPrint(1)
        }

        if (field_diff) {
            FieldMax[i] += field_diff
            total_fields_len += field_diff
        }

        if (endfit_col && i == endfit_col) break

    }

    if (NF > max_nf) {
        max_nf = endfit_col && endfit_col < NF ? endfit_col : NF
    }
}


## Second pass, print formatted if applicable

NR > FNR {
    gsub(/\015$/, "") # TODO: Move to prefield

    if (gridlines) {
        if (to_print_start_gridline) {
            to_print_start_gridline = 0
            mode = -1
        }
        else {
            mode = 0
        }
        PrintGridline(mode, max_nf)
    }

    for (i = 1; i <= max_nf; i++) {
        if (gridlines && i == 1) PrintBuffer(3)
        not_last_f = i < max_nf
        f = endfit_col && i == endfit_col ? ResLine[FNR] : $i
        gsub("(^[[:space:]]*|[[:space:]]*$|^[[:space:]]+$)", "", f)

        if (FieldMax[i]) {
            if (DecimalSet[i] || (NumberSet[i] && !NumberOverset[i])) {

                if (AnyFormatNumber(f)) {
                    gsub(",", "", f)

                    if (DecimalSet[i]) {
                        if (zero_blank && f + 0 == 0) {
                            type_str = "s"
                            value = "-"
                        }
                        else if (d == "z") {
                            type_str = (sn ? ".0e" : "s")
                            value = int(f)
                        }
                        else {
                            dec = (d ? fix_dec : DecimalMax[i])
                            type_str = (sn ? "." dec "e" : "." dec "f")
                            value = GetOrSetTruncVal(f, dec, LargeVals[i])
                        }
                    }
                    else {
                        type_str = (sn ? ".0e" : "s")
                        value = f
                    }
                }
                else {
                    type_str = "s"
                    value = f
                }

                print_len = FieldMax[i] + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]
                justify_str = "%" # Right-align
                fmt_str = justify_str print_len type_str

                if (color_on && color_pending) fmt_str = white fmt_str no_color

                printf fmt_str, value
                if (not_last_f || gridlines) PrintBuffer(buffer)
            }

            else {
                if (ShrinkF[i]) {
                    if (color_on) {
                        a_color = hl
                        color_off = no_color
                    }
                    value = GetOrSetCutStringByVisibleLen(f, MaxFieldLen[i] + WCWIDTH_DIFF[FNR, i])
                }
                else {
                    if (color_on) {
                        a_color = color_pending ? white : ""
                        color_off = color_pending ? no_color : ""
                    }
                    value = f
                }

                if (not_last_f) {
                    print_len = MaxFieldLen[i] + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]
                }
                else {
                    print_len = length(value) + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]
                }

                justify_str = "%-" # Left-align
                fmt_str = a_color justify_str print_len "s" color_off

                printf fmt_str, value
                
                if (gridlines) {
                    printf "%.*s", MaxFieldLen[i] + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i] - print_len, space_str
                }

                if (not_last_f) PrintBuffer(buffer)
                else if (gridlines) {
                    printf "%s", bufferchar
                }
            }
        }
        if (debug && FNR < 2) DebugPrint(6)
    }
    
    print ""

    if (color_pending) color_pending = 0
}

END {
    if (err) exit(err)
    if (gridlines && !has_printed_final_gridline) {
        PrintGridline(1, max_nf)
    }
}


function StripTrailingColors(str) {
    gsub(trailing_color_re, "", str) # Remove ANSI color codes
    return str
}

function StripColors(str) {
    gsub(color_re, "", str) # Remove ANSI color codes
    return str
}

function StripBasicASCII(str) {
    # TODO: Strengthen cases where not multibyte-safe
    gsub(/[ -~ -¬®-˿Ͱ-ͷͺ-Ϳ΄-ΊΌΎ-ΡΣ-҂Ҋ-ԯԱ-Ֆՙ-՟ա-և։֊־׀׃׆א-תװ-״]+/, "", str)
    return str
}

function GetOrSetCutStringByVisibleLen(str, reduction_len) {
    if (CutString[str, reduction_len]) return CutString[str, reduction_len]

    if (str ~ trailing_color_re) {
        rem_str = str
        reduced_str = ""
        reduced_str_len = 0
        next_color = ""

        split(str, PrintStr, trailing_color_re)
        p_len = length(PrintStr)

        for (p = 1; p <= p_len && reduced_str_len <= reduction_len; p++) {

            p_cur = p == 1 ? PrintStr[p] : substr(PrintStr[p], 2)
            add = substr(p_cur, 1, Max(reduction_len - reduced_str_len, 0))
            rem_str = substr(rem_str, index(rem_str, p_cur) + length(p_cur) + 1)
            next_color = p == p_len ? rem_str : substr(rem_str, 1, index(rem_str, PrintStr[p+1]))

            reduced_str = reduced_str add next_color
            reduced_str_len += length(add)
        }
    }
    else {
        reduced_str = substr(str, 1, reduction_len)
    }

    CutString[str, reduction_len] = reduced_str
    return reduced_str
}

function GetOrSetTruncVal(val, dec, large_vals) {
    if (TVal[val]) return TVal[val]
    trunc_val = TruncVal(val, dec, larg_vals)
    TVal[val] = trunc_val
    return trunc_val
}

function TruncVal(val, dec, large_vals) {
    if (large_vals || (val+0 > 9999) || val ~ /-?[0-9]\.[0-9]+(E|e\+)([4-9]|[1-9][0-9]+)$/) {
        dec_f = d ? fix_dec : Max(dec, 0)
        full_f = length(int(val))
        if (dec_f) full_f += dec_f + 1

        return sprintf("%"full_f"."dec_f"f", val)
    }
    else if (val ~ /\.[0-9]{5,}$/) {
        dec_f = d ? fix_dec : Max(dec, 4)
        full_f = length(int(val)) + dec_f + 1

        return sprintf("%"full_f"."dec_f"f", val)
    }
    else {
        return sprintf("%f", val) # Small floats flow through this logic
    }
}

function AnyFormatNumber(str) {
    return (str ~ num_re || str ~ decimal_re || str ~ float_re)
}

function ComplexFmtNum(str) {
    return (str ~ decimal_re || str ~ float_re)
}

function PrintWarning() {
    print orange "WARNING: Total max field lengths larger than display width!" no_color
    if (!color_detected) print "Columns cut printed in " hl "HIGHLIGHT" no_color
    print ""
}

function PrintBuffer(buffer) {
    printf "%.*s", buffer, buffer_str
}

function PrintGridline(mode, max_nf) {
    if (mode < 0) {
        start_char = "\xE2\x94\x8C"
        end_char = "\xE2\x94\x90"
        intersect_char = "\xE2\x94\xAC"
    }
    else if (mode > 0) {
        start_char = "\xE2\x94\x94"
        end_char = "\xE2\x94\x98"
        intersect_char = "\xE2\x94\xB4"
        has_printed_final_gridline = 1
    }
    else {
        start_char = "\xE2\x94\x9C"
        end_char = "\xE2\x94\xA4"
        intersect_char = "\xE2\x94\xBC"
    }
    
    for (i = 1; i <= max_nf; i++) {
        
        if (i == 1) printf "%s", start_char
        not_last_f = i < max_nf

        if (FieldMax[i]) {
            if (DecimalSet[i] || (NumberSet[i] && !NumberOverset[i])) {
                print_len = FieldMax[i]
            }
            else if (not_last_f || ShrinkF[i]) {
                print_len = MaxFieldLen[i]
            }
            else {
                f = endfit_col && i == endfit_col ? ResLine[FNR] : $i
                print_len = length(f)
                
                if (print_len < MaxFieldLen[i]) {
                    print_len = MaxFieldLen[i]
                }
            }

            printf "%.*s", print_len * 3, gridline_base
            
            if (not_last_f) { 
                printf "%s", intersect_char
                printf "%.*s", 6, gridline_base
            }
        }
    }
    
    print end_char
}

function DebugPrint(case) {
    # Switch statement not supported in all Awk implementations
    if (debug_col && i != debug_col) return
    if (case == 1) {
        if (!debug1_title_printed) { debug1_title_printed=1
            printf "%-20s%5s%5s%5s%5s%5s%5s\n", "", "FNR", "i", "len", "ogmx", "fmxi", "ldf" }
        printf "%-20s%5s%5s%5s%5s%5s%5s", "max change: ", FNR, i, len, orig_max, FieldMax[i], len_diff }
    else if (case == 2) {
        if (!debug2_title_printed) { debug2_title_printed=1
            printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s\n", "", "FNR", "i", "d", "i_ln", "d_ln", "t_ln", "nmax", "dmax", "omax", "len", "i_df", "d_df", "l_df", "t_df", "f_df", "tval" }
        printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s", "decimal setting: ", FNR, i, d, int_len, dec_len, t_len, NumberMax[i], 0, orig_max, len, int_diff, decimal_diff, len_diff, t_diff, field_diff, tval }
    else if (case == 3) {
        if (!debug3_title_printed) { debug3_title_printed=1
            printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s\n", "", "FNR", "i", "d", "i_ln", "d_ln", "t_ln", "nmax", "dmax", "omax", "len", "i_df", "d_df", "l_df", "t_df", "f_df", "tval" }
        printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s", "decimal adjustment: ", FNR, i, d, int_len, dec_len, t_len, NumberMax[i], DecimalMax[i], orig_max, len, int_diff, decimal_diff, len_diff, t_diff, field_diff, tval }
    else if (case == 4) {
        if (!s_title_printed) { s_title_printed=1
            printf "%-15s%5s%5s%5s%5s%5s%5s%5s\n", "", "i", "fmxi", "avfl", "mxnf", "rdsc", "tfl", "ttys" }
        printf "%-15s%15s%5s%5s%5s%5s", "shrink step: ", average_field_len, max_nf, reduction_scaler, total_fields_len, tty_size }
    else if (case == 5)
        printf "%-15s%5s%5s", "shrink field: ", i, FieldMax[i]
    else if (case == 6)
        { print ""; print i, fmt_str, $i, value; print "" }
    else if (case == 7)
        printf "%s %s %s", "Number pattern set for col:", NR, i
    else if (case == 8) 
        printf "%s %s %s", "Number pattern overset for col:", NR, i
    else if (case == 9) 
        printf "%s %s %s", "g_max_cut: "cut_len, "MaxFieldLen[i]: "MaxFieldLen[i], "total_fields_len: "total_fields_len
    else if (case == 10)
        printf "%s %s %s %s %s %s %s %s", "wcwdiff! NR: " NR, " f: "f, "i: "i, " init_len: "init_len, "len: "len, "wcw_diff: "wcw_diff, " wcw: "wcw, " f_wcw_kludge: "len_wcw_kludge

    print ""
}
