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
    gsub(/[ -~ -¬®-˿Ͱ-ͷͺ-Ϳ΄-ΊΌΎ-ΡΣ-҂Ҋ-ԯԱ-Ֆՙ-՟ա-և։֊־׀׃׆א-תװ-״]+/, "", str)
    return str
}

function GetOrSetCutStringByVisibleLen(str, reduction_len) {
    # Use cached value if available
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

    # Cache the result
    CutString[str, reduction_len] = reduced_str
    return reduced_str
}

function GetOrSetTruncVal(val, dec, large_vals) {
    # Use cached value if available
    if (TVal[val]) return TVal[val]
    
    trunc_val = TruncVal(val, dec, large_vals)
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

            # Use cached grid line pattern if available
            if (print_len <= 10) {
                printf "%s", GRID_PATTERNS[print_len]
            } else {
                printf "%.*s", print_len * 3, gridline_base
            }
            
            if (not_last_f) { 
                printf "%s", intersect_char
                printf "%.*s", 6, gridline_base
            }
        }
    }
    
    print end_char
}

function DebugPrint(_case) {
    # Switch statement not supported in all Awk implementations
    if (debug_col && i != debug_col) return
    if (_case == 1) {
        if (!debug1_title_printed) { debug1_title_printed=1
            printf "%-20s%5s%5s%5s%5s%5s%5s\n", "", "FNR", "i", "len", "ogmx", "fmxi", "ldf" }
        printf "%-20s%5s%5s%5s%5s%5s%5s", "max change: ", FNR, i, len, orig_max, FieldMax[i], len_diff }
    else if (_case == 2) {
        if (!debug2_title_printed) { debug2_title_printed=1
            printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s\n", "", "FNR", "i", "d", "i_ln", "d_ln", "t_ln", "nmax", "dmax", "omax", "len", "i_df", "d_df", "l_df", "t_df", "f_df", "tval" }
        printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s", "decimal setting: ", FNR, i, d, int_len, dec_len, t_len, NumberMax[i], 0, orig_max, len, int_diff, decimal_diff, len_diff, t_diff, field_diff, tval }
    else if (_case == 3) {
        if (!debug3_title_printed) { debug3_title_printed=1
            printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s\n", "", "FNR", "i", "d", "i_ln", "d_ln", "t_ln", "nmax", "dmax", "omax", "len", "i_df", "d_df", "l_df", "t_df", "f_df", "tval" }
        printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s", "decimal adjustment: ", FNR, i, d, int_len, dec_len, t_len, NumberMax[i], DecimalMax[i], orig_max, len, int_diff, decimal_diff, len_diff, t_diff, field_diff, tval }
    else if (_case == 4) {
        if (!s_title_printed) { s_title_printed=1
            printf "%-15s%5s%5s%5s%5s%5s%5s%5s\n", "", "i", "fmxi", "avfl", "mxnf", "rdsc", "tfl", "ttys" }
        printf "%-15s%15s%5s%5s%5s%5s", "shrink step: ", average_field_len, max_nf, reduction_scaler, total_fields_len, tty_size }
    else if (_case == 5)
        printf "%-15s%5s%5s", "shrink field: ", i, FieldMax[i]
    else if (_case == 6)
        { print ""; print i, fmt_str, $i, value; print "" }
    else if (_case == 7)
        printf "%s %s %s", "Number pattern set for col:", NR, i
    else if (_case == 8) 
        printf "%s %s %s", "Number pattern overset for col:", NR, i
    else if (_case == 9) 
        printf "%s %s %s", "g_max_cut: "cut_len, "MaxFieldLen[i]: "MaxFieldLen[i], "total_fields_len: "total_fields_len
    else if (_case == 10)
        printf "%s %s %s %s %s %s %s %s", "wcwdiff! NR: " NR, " f: "f, "i: "i, " init_len: "init_len, "len: "len, "wcw_diff: "wcw_diff, " wcw: "wcw, " f_wcw_kludge: "len_wcw_kludge

    print ""
}
