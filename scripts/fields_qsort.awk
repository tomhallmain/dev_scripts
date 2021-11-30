#!/usr/bin/awk
#
# Quicksort by a given field order
# Adapted from http://www.netlib.org/research/awkbookcode/ch7
#
# Example sorting with custom FS on field 3 then 2 in descending order:
# > awk -F||| -f fields_qsort.awk -v k=3,2 -v order=d file
#
## TODO: Multikey numeric sort
## TODO: Float tests
## TODO: Manpage

BEGIN {
    n_keys = 0
    
    if (k) {
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
        }
    }
    else {
        Keys[1] = 0
        n_keys = 1
    }

    desc = (order && "desc" ~ "^"order)

    if (type && "numeric" ~ "^"type) {
        n = 1
        n_re = "^[[:space:]]*\\$?[[:space:]]?-?\\$?([0-9]{,3},)*[0-9]*\\.?[0-9]+"
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

    sort_nr++
    A[sort_nr] = sort_key
    _[sort_nr] = $0
}

END {
    if (err) exit err
    
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
        print _[i]
    }
}

function QSA(A,left,right,    i,last) {
    if (left >= right) return

    S(A, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++)
        if (A[i] < A[left])
            S(A, ++last, i)

    S(A, left, last)
    QSA(A, left, last-1)
    QSA(A, last+1, right)
}

function QSD(A,left,right,    i,last) {
    if (left >= right) return

    S(A, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++)
        if (A[i] > A[left])
            S(A, ++last, i)

    S(A, left, last)
    QSD(A, left, last-1)
    QSD(A, last+1, right)
}

function QSAN(A,left,right,    i,last) {
    if (left >= right) return

    S(A, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++) {
        if (GetN(A[i]) < GetN(A[left])) {
            S(A, ++last, i)
        }
        else if (GetN(A[i]) == GetN(A[left]) && NExt[A[i]] < NExt[A[left]]) {
            S(A, ++last, i)
        }
    }

    S(A, left, last)
    QSAN(A, left, last-1)
    QSAN(A, last+1, right)
}

function QSDN(A,left,right,    i,last) {
    if (left >= right) return

    S(A, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++) {
        if (GetN(A[i]) > GetN(A[left])) {
            S(A, ++last, i)
        }
        else if (GetN(A[i]) == GetN(A[left]) && NExt[A[i]] < NExt[A[left]]) {
            S(A, ++last, i)
        }
    }

    S(A, left, last)
    QSDN(A, left, last-1)
    QSDN(A, last+1, right)
}

function S(A,i,j,t) {
    t = A[i]; A[i] = A[j]; A[j] = t
    t = _[i]; _[i] = _[j]; _[j] = t
}

function GetN(str) {
    if (NS[str]) {
        return NS[str]
    }
    else if (match(str, n_re)) {
        n_end = RSTART + RLENGTH
        n_str = substr(str, RSTART, n_end)

        if (n_str != str) {
            NExt[str] = substr(str, n_end+1, length(str))
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
