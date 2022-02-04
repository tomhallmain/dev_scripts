#!/usr/bin/awk
# DS:SORTM
#
# NAME
#       ds:sortm, ds:s, fields_qsort.awk
#
# SYNOPSIS
#       ds:sortm [file] [keys] [order=a|d] [sort_type] [awkargs]
#
# DESCRIPTION
#       fields_qsort.awk is a script to quicksort data by a given field order.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based
#       systems it should be), and call it on two files along with utils.awk:
#
#          > awk -F',' -f support/utils.awk -f fields_qsort.awk -v k=3,2 -v order=d file
#
#       ds:sortm is the caller function for the fields_qsort.awk script. To run any of the 
#       examples below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#          $ data | ds:sortm [keys] [order] [sort_type]
#
# FIELD CONSIDERATIONS
#       When running ds:sortm, an attempt is made to infer a field separator of up to 
#       three characters. If none found, FS will be set to default value, a single
#       space = " ". To override FS, add as a trailing awkarg. Be sure to escape and 
#       quote if needed. AWK's extended regex can be used as FS:
#
#          $ ds:sortm file -v FS=','
#
#          $ ds:sortm file -v FS=" {2,}"
#
#          $ ds:sortm file -F'\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:sortm file -v FS=""
#
# USAGE
#       keys - Comma-separated list of field indices or header patterns. If unset, 
#       will default to 1.
#
#       order - if not d[esc], will default to ascending
#
#       sort_type - use this to set numeric sort:
#
#          ds:sortm file "" "" n
#
# AWKARG OPTS
#       If headers are present, set the header variable to any value to ensure header 
#       values remain first in output:
#
#          -v header=1
#
#       Force interpretation of all keys as patterns to match against headera (usually 
#       not required):
#
#          -v gen_keys=1
#
#       Force a more involved sort calculation that considers the key fields not 
#       specified in the sorting
#
#          -v deterministic=1
#
#       Sort both rows and columns simultaneously, taking the average of values in both 
#       index sets:
#
#          -v multisort=1
#
#
## TODO: Multikey numeric sort
## TODO: Float tests
## TODO: Length sort

BEGIN {
    n_keys = 0
    SeedRandom()
    
    if (multisort) {
        _OInit()
    }
    else if (k) {
        n_keys = split(k, Keys, /,+/)
        
        for (i = 1; i <= n_keys; i++) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", Keys[i])
            key = Keys[i]

            if (length(key) == 0) {
                continue
            }
            else if (!gen_keys && !(key == "NF") && (!(key ~ /^[0-9]+$/) || length(key) > 3)) {
                gen_keys = 1
            }
            else {
                KeyFields[key] = 1
            }
        }
    }
    else {
        Keys[1] = 0
        n_keys = 1
    }

    desc = (order && "desc" ~ "^"order)

    if (type && "numeric" ~ "^"type) {
        n = 1
        n_re = "^[[:space:]]*\\$?[[:space:]]?-?\\$?([0-9]{,3},)*[0-9]*\\.?[0-9]+((E|e)(\\+|-)?[0-9]+)?"
        f_re = "^[[:space:]]*-?[0-9]\.[0-9]+(E|e)(\\+|-)?[0-9]+[[:space:]]*$"
    }

    err = 0

    if (header) {
        header_unset = 1
    }

    sort_nr = 0
}

$0 ~ /^[[:space:]]*$/ {
    next
}

multisort {
    _R[NR] = NR
    
    for (f = 1; f <= NF; f++) {
        _[NR, f] = $f
        _C[f] = f
        if (n) {
            n_str = GetN($f)
            if (n_str ~ n_re) {
                RN[NR] += n_str
                CN[f] += n_str
                AdvChars(NR, f, NExt[$f], n_end+1, RSums, CSums)
            }
            else {
                AdvChars(NR, f, n_str, 1, RSums, CSums)
            }
        }
        else {
            AdvChars(NR, f, $f, 1, RSums, CSums)
        }
    }

    if (NF > max_nf) max_nf = NF
    next
}

header_unset || gen_keys {
    if (gen_keys) {
        gen_keys = 0

        for (i = 1; i <= n_keys; i++) {
            key_pattern = Keys[i]
            
            if (key_pattern == "NF") {
                continue
            }
            
            key_found = 0

            if (!case_sensitive) {
                key_pattern = tolower(key_pattern)
            }

            for (f = 1; f <= NF; f++) {
                field = case_sensitive ? $f : tolower($f)
            
                if (field ~ "^(\"|')*"key_pattern) {
                    Keys[i] = f
                    KeyFields[f] = 1
                    key_found = 1
                    break
                }
            }

            if (!key_found) {
                n_keys--
                delete Keys[i]
            }
        }

        if (n_keys < 1) {
            "No key patterns provided matched header"
            err = 1
            exit
        }
    }
    
    if (header_unset) {
        header_unset = 0
    }
    
    header = $0
    next
}

{
    sort_key = ""
    has_started_sort_key = 0

    for (i = 1; i <= n_keys; i++) {
        kf = Keys[i]
        
        if (!kf) continue
        else if (kf < 0) kf = NF + kf
        else if (kf == "NF") kf = NF
        
        sort_key = has_started_sort_key ? sort_key FS $kf : $kf
        
        if (!has_started_sort_key) {
            has_started_sort_key = 1
        }
    }

    if (deterministic) {
        for (i = 1; i <= NF; i++) {
            if (!(i in KeyFields)) {
                sort_key = has_started_sort_key ? sort_key FS $i : $i
                if (!has_started_sort_key) {
                    has_started_sort_key = 1
                }
            }
        }
    }

    sort_nr++
    A[sort_nr] = sort_key
    ___[sort_nr] = $0
}

END {
    if (err) exit err
    if (!NR) exit 1

    if (multisort) {
        if (!max_nf) exit 1
        
        if (debug) print ""
        if (debug) print "----- CONTRACTING ROW VALS -----"
        ContractCharVals(NR, RSums, RCounts, RCCounts, RVals)
        if (debug) print "----- CONTRACTING COL VALS -----"
        ContractCharVals(max_nf, CSums, CCounts, CCCounts, CVals)

        if (n) {
            if (desc) {
                if (debug) print "----- SORTING ROW VALS -----"
                SDN(RN, RVals, _R, 1, NR)
                if (debug) print "\n----- SORTING COL VALS -----"
                SDN(CN, CVals, _C, 1, max_nf) }
            else {
                if (debug) print "----- SORTING ROW VALS -----"
                SAN(RN, RVals, _R, 1, NR)
                if (debug) print "\n----- SORTING COL VALS -----"
                SAN(CN, CVals, _C, 1, max_nf)
            }
        }
        else {
            if (desc) {
                if (debug) print "----- SORTING ROW VALS -----"
                SD(RVals, _R, 1, NR)
                if (debug) print "\n----- SORTING COL VALS -----"
                SD(CVals, _C, 1, max_nf)
            }
            else {
                if (debug) print "----- SORTING ROW VALS -----"
                SA(RVals, _R, 1, NR)
                if (debug) print "\n----- SORTING COL VALS -----"
                SA(CVals, _C, 1, max_nf)
            }
        }

        if (debug) {
            print "\ntest tieback"

            for (i = 1; i <= length(_R); i++)
                print "_R["i"]="_R[i]

            print "\ntest tieback"

            for (i = 1; i <= length(_C); i++)
                print "_C["i"]="_C[i]

            print "\n---- ORIGINAL HEAD ----"

            for (i = 1; i <= 10; i++) {
                if (i > NR) continue

                for (j = 1; j <= 10; j++) {
                    if (j > max_nf) continue
                    printf "%s", _[i, j] OFS
                }

                print ""
            }
            print "\n---- OUTPUT ----"
        }

        for (i = 1; i <= NR; i++) {
            for (j = 1; j <= max_nf; j++) {
                printf "%s", _[_R[i], _C[j]] OFS
            }
            print ""
        }

    }
    else {
        
        if (n) {
            if (desc) QSDN(A, 1, sort_nr)
            else      QSAN(A, 1, sort_nr)
        }
        else {
            if (desc) QSD(A, 1, sort_nr)
            else      QSA(A, 1, sort_nr)
        }

        if (header) {
            print header
        }

        for (i = 1; i <= sort_nr; i++) {
            print ___[i]
        }
    
    }
}

function GetN(str) {
    if (NS[str]) {
        return NS[str]
    }
    else if (match(str, n_re)) {
        n_end = RSTART + RLENGTH
        n_str = substr(str, RSTART, n_end - 1)

        if (n_str != str) {
            NExt[str] = substr(str, n_end, length(str))
        }

        n_str = sprintf("%f", n_str)
        gsub(/[^0-9\.Ee\+\-]+/, "", n_str)
        gsub(/^0*/, "", n_str)
        n_str = n_str + 0
        NS[str] = n_str
        return n_str
    }
    else {
        return str
    }
}

function AdvChars(row, field, str, start, R, C) {
    r_count = 0; c_count = 0
    len_chars = split($f, Chars, "") + start

    for (c = start; c < len_chars; c++) {
        char_val = O[Chars[c]]

        if (debug) print row, field, str, char_val

        R[row, c] += char_val
        C[field, c] += char_val

        RCCounts[row, c]++
        CCCounts[field, c]++
    }

    if (len_chars < 1) {
        RCCounts[row, 0]++
        CCCounts[field, 0]++
    }

    if (len_chars > RCounts[row]) RCounts[row] = len_chars
    if (len_chars > CCounts[field]) CCounts[field] = len_chars 
    if (len_chars > max_len) max_len = len_chars
}

function ContractCharVals(max_base, SumsArr, BaseCounts, CharIdxCounts, ValsArr) {

    if (debug) printf "%5s%9s%15s\n", "idx", "char_idx", "merge_char_val"

    for (i = 1; i <= max_base; i++) {
        base_count = BaseCounts[i]

        for (j = 1; j <= base_count; j++) {

            if (!(SumsArr[i, j] && CharIdxCounts[i, j]))
                continue

            merge_char_val = SumsArr[i, j] / CharIdxCounts[i, j]

            if (debug) printf "%5s%9s%15s\n", i, j, merge_char_val

            if (j == 1) {
                ValsArr[i] = merge_char_val
            }
            else {
                ValsArr[i] = ValsArr[i] SUBSEP merge_char_val
            }
        }
    }
    
    if (debug) print ""
}

function SA(A,TieBack,left,right,    i,last) {
    if (left >= right) return

    SM(A, TieBack, left, left + int((right-left+1)*rand()))
    last = left
    
    for (i = left+1; i <= right; i++) {
        len_i_vals = split(A[i], i_vals, SUBSEP)
        len_left_vals = split(A[left], left_vals, SUBSEP)
        
        for (j = 1; j <= len_i_vals; j++) {
            if (!left_vals[j] || i_vals[j] > left_vals[j]) {
                break
            }
            else if (!i_vals[j] || i_vals[j] < left_vals[j]) {
                if (++last != i) {
                    SM(A, TieBack, last, i)
                    break
                }
            }
        }
    }

    SM(A, TieBack, left, last)
    SA(A, TieBack, left, last-1)
    SA(A, TieBack, last+1, right)
}

function SD(A,TieBack,left,right,    i,last) {
    if (left >= right) return

    SM(A, TieBack, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++) {
        len_i_vals = split(A[i], i_vals, SUBSEP)
        len_left_vals = split(A[left], left_vals, SUBSEP)
        
        for (j = 1; j <= len_i_vals; j++) {
            if (!i_vals[j] || i_vals[j] < left_vals[j]) {
                break
            }
            else if (!left_vals[j] || i_vals[j] > left_vals[j]) {
                if (++last != i) {
                    SM(A, TieBack, last, i)
                    break
                }
            }
        }
    }

    SM(A, TieBack, left, last)
    SD(A, TieBack, left, last-1)
    SD(A, TieBack, last+1, right)
}

function SAN(AN,A,TieBack,left,right,    i,last) {
    if (left >= right) return

    SN(AN, A, TieBack, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++) {
        if (AN[i] < AN[left]) {
            SN(AN, A, TieBack, ++last, i)
        }
        else if (AN[i] == AN[left]) {
            len_i_vals = split(A[i], i_vals, SUBSEP)
            len_left_vals = split(A[left], left_vals, SUBSEP)
            
            for (j = 1; j <= len_i_vals; j++) {
                if (!i_vals[j] || i_vals[j] < left_vals[j]) {
                    break
                }
                else if (!left_vals[j] || i_vals[j] > left_vals[j]) {
                    if (++last != i) {
                        SN(AN, A, TieBack, last, i)
                        break
                    }
                }
            }
        }
    }

    SN(AN, A, TieBack, left, last)
    SAN(AN, A, TieBack, left, last-1)
    SAN(AN, A, TieBack, last+1, right)
}

function SDN(AN,A,TieBack,left,right,    i,last) {
    if (left >= right) return

    SN(AN, A, TieBack, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++) {
        if (AN[i] > AN[left]) {
            if (++last != i) {
                SN(AN, A, TieBack, last, i)
            }
        }
        else if (AN[i] == AN[left]) {
            len_i_vals = split(A[i], i_vals, SUBSEP)
            len_left_vals = split(A[left], left_vals, SUBSEP)
            
            for (j = 1; j <= len_i_vals; j++) {
                if (!i_vals[j] || i_vals[j] < left_vals[j]) {
                    break
                }
                else if (!left_vals[j] || i_vals[j] > left_vals[j]) {
                    if (++last != i) {
                        SN(AN, A, TieBack, last, i)
                        break
                    }
                }
            }
        }
    }

    SN(AN, A, TieBack, left, last)
    SDN(AN, A, TieBack, left, last-1)
    SDN(AN, A, TieBack, last+1, right)
}

function SM(A,TieBack,i,j,   t) {
    t = A[i]; A[i] = A[j]; A[j] = t
    t = TieBack[i]; TieBack[i] = TieBack[j]; TieBack[j] = t
}

function SN(AN,A,TieBack,i,j,   t) {
    t = AN[i]; AN[i] = AN[j]; AN[j] = t
    t = A[i]; A[i] = A[j]; A[j] = t
    t = TieBack[i]; TieBack[i] = TieBack[j]; TieBack[j] = t
}

function _OInit(    low, high, i, t) {
    low = sprintf("%c", 7) # BEL is ascii 7
    if (low == "\a") {     # regular ascii
        low = 0
        high = 127
    }
    else if (sprintf("%c", 128 + 7) == "\a") {
        low = 128            # ascii, mark parity
        high = 255
    }
    else {                 # ebcdic(!)
        low = 0
        high = 255
    }

    for (i = low; i <= high; i++) {
        t = sprintf("%c", i)
        O[t] = i
        _O[i] = t
    }
}

function Round(val) {
    int_val = int(val)
  
    if (val - int_val >= 0.5)
        return int_val++
    else
        return int_val
}
