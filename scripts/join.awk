#!/usr/bin/awk
# DS:JOIN
#
# NAME
#       ds:join, join.awk
#
# SYNOPSIS
#       ds:join [-h|--help|file] [file*] [jointype=outer] [k|merge] [k2] [prefield=t] [awkargs]
#
# DESCRIPTION
#       join.awk is a script to run a join of two files or data streams with variant 
#       options for output.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based
#       systems it should be), and call it on two files along with utils.awk:
#
#          > awk -f support/utils.awk -f join.awk file1 file2
#
#       ds:join is the caller function for the join.awk script. To run any of the examples 
#       below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#          $ file2_data | ds:join file1
#
#       ds:join can be run with multiple files beyond the second, using the same arguments
#       as the initial join, with limited extended functionality:
#
#          $ ds:join file1 file2 file3 file4 ... [jointype] ...
#
# FIELD CONSIDERATIONS
#       When running ds:join, an attempt is made to infer field separators of up to
#       three characters. If none found, FS will be set to default value, a single
#       space = " ". To override FS, add as a trailing awkarg. If the two files have
#       different FS, assign to vars fs1 and fs2. Be sure to escape and quote if needed. 
#       AWK's extended regex can be used as FS:
#
#          $ ds:join file1 file2 -v fs1=',' -v fs2=':'
#
#          $ ds:join file1 file2 -v FS=" {2,}"
#
#          $ ds:join file1 file2 -F'\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:join file1 file2 -v FS=""
#
#       When running ds:join, an attempt is made to extract relevant instances of field
#       separators in the case that a field separator appears in field values. To turn this
#       off set prefield to false in the positional arg.
#
#          $ ds:join simple1.csv simple2.csv inner 1 1 [f|false]
#
#       If ds:join detects it is connected to a terminal, it will attempt to fit the data
#       into the terminal width using the same field separator. If the data is being sent to
#       a file or a pipe, no attempt to fit will be made. One easy way to turn off fit is to
#       cat the output or redirect to a file.
#
#          $ file2_data | ds:join file1 | cat
#
# USAGE
#       Jointype takes one of five options:
#
#          o[uter] - default
#          i[nner]
#          l[eft]
#          r[ight]
#          d[iff]
#
#       If there is one field number to join on, assign it to var k at runtime:
#
#          $ ds:join file1 file2 o 1
#
#       If there are different keys in each file, assign file2's key second:
#
#          $ ds:join file1 file2 o 1 2
#
#       If there are multiple fields to join on in a single file, separate the column
#       numbers with commas. Note the key sets must be equal in length:
#
#          $ ds:join file1 file2 o 1,2 2,3
#
#       Keys can also be generated from matching regex patterns in the first row with data 
#       in each file:
#
#          $ ds:join file1 file2 o f1header1,f1header2 f2header1,f2header2
#
#       To join on all fields from both files, set k to "merge":
#
#          $ ds:join file1 file2 left merge
#
#
# AWKARG OPTS
#       Any fields beyond the maximum of the first row in the first file will not be merged 
#       unless mf_max is set to a higher value. It can also be set to a lower value to merge 
#       all fields up to a certain index, and join as normal on the others:
#
#          -v mf_max={int}
#
#   **  If headers are present, set the header variable to any value to ensure consistent 
#       header positioning - usually not required:
#
#          -v header=1
#
#   **  Add an index to output:
#
#          -v ind=1
#
#   **  Merge with an extra column of output indicating files involved:
#
#          -v merge_verbose=1
#
#   **  Merge with custom labels in the verbose column:
#
#          -v left_label="Prior Data"
#          -v right_label="Current Data"
#          -v inner_label="No Change"
#
#       Merge with a bias to the right join on certain fields (by default nulls in right joins 
#       will be overwritten with the left join value):
#
#          -v bias_merge_keys={keys}
#
#       Merge with a bias on all keys except for keys in bias_merge_exclude_keys:
#
#          -v bias_merge_exclude_keys={keys}
#
#       Override null overwrite default behavior in bias merges to preserve nulls from the 
#       right join:
#
#          -v full_bias=1
#
#       Print null fields as empty instead of <NULL>:
#
#          -v null_off=1
#
#       Force key generation from regex matching integer key inputs, as opposed to assuming 
#       these indicate field indices:
#
#          -v gen_keys=1
#
#       Limit key generation to key matches sensitive to case:
#
#          -v case_sensitive=1
#
#       Inherit generated keys indices from left data if they are not found in right data:
#
#          -v inherit_keys=1
#
#   ** - Indicates opt functions well only on two-file joins
#
#
# VERSION
#       1.2
#
# AUTHORS
#       Tom Hall (tomhall.main@gmail.com)
#

BEGIN {
    _ = SUBSEP

    if (!fs1) fs1 = FS
    if (!fs2) fs2 = FS
    FS = fs1
    OFS = SetOFS()
    if (OFS ~ /\[\:.+\:\]\{2,\}/) {
        OFS = "  "
    }
    else if (OFS ~ /\[\:.+\:\]/) {
        OFS = " "
    }

    if (merge) {
        merge = 1
        
        if (merge_verbose) {
            merge_verbose = 1
            file_labels = (ARGV[1] && ARGV[2] && ARGV[1] != ARGV[2])

            if (!left_label) {
                left_label = (file_labels ? ARGV[1] : "FILE1")
            }
            if (!right_label) {
                right_label = (file_labels ? ARGV[2] : "FILE2")
                right_label = piped ? "PIPEDATA" : right_label
            }
            if (!inner_label) {
                inner_label = "BOTH"
            }

            left_label = left_label OFS
            right_label = right_label OFS
            inner_label = inner_label OFS
        }
        else {
            left_label = ""; right_label = ""; inner_label = ""
        }

        if (bias_merge_keys) {
            bias_merge = 1
            split(bias_merge_keys, _BiasMergeKeys, ",")

            for (key_index in _BiasMergeKeys) {
                key = _BiasMergeKeys[key_index]
                
                if (!(key ~ /^[0-9]+$/)) {
                    print "Bias merge keys must be integers, found key: " key
                    exit 1
                }

                BiasMergeKeys[key] = key_index
            }

            if (full_bias) {
                full_bias = 1
            }
        }

        if (bias_merge_exclude_keys) {
            bias_merge = 1
            gen_bias_merge_keys_from_exclusion = 1
            split(bias_merge_exclude_keys, _BiasMergeExcludeKeys, ",")

            for (key_index in _BiasMergeExcludeKeys) {
                key = _BiasMergeExcludeKeys[key_index]

                if (!(key ~ /^[0-9]+$/)) {
                    print "Bias merge exclude keys must be integers, found key: " key
                    exit 1
                }

                if (key in BiasMergeKeys) {
                    delete BiasMergeKeys[key]
                }

                BiasMergeExcludeKeys[key] = 1
            }

            if (full_bias) {
                full_bias = 1
            }
        }
    }
    else {
        left_label = ""
        right_label = ""
        inner_label = ""

        if (k) {
            k1 = k
            k2 = k
            equal_keys = 1
        }
        else if (!k1 || !k2) {
            print "Missing join key fields"
            exit 1
        }

        len_k1 = split(k1, Keys1, /,+/)
        len_k2 = split(k2, Keys2, /,+/)

        if (len_k1 != len_k2) {
            print "Keysets must be equal in length"
            exit 1
        }

        for (i = 1; i <= len_k1; i++) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", Keys1[i])
            key = Keys1[i]

            if (length(key) == 0) {
                continue
            }
            else if (!gen_keys && (!(key ~ /^[0-9]+$/) || length(key) > 3)) {
                gen_keys = 1
            }
        }

        for (i = 1; i <= len_k2; i++) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", Keys2[i])
            key = Keys2[i]
            joint_key = Keys1[i]

            if (length(key) == 0) {
                continue
            }
            else if (!gen_keys && !(key ~ /^[0-9]+$/) || length(key) > 3) {
                gen_keys = 1
            }

            K2[key] = joint_key
            K1[joint_key] = key
        }
    }
    
    if (debug) {
        for (i in Keys1) print i, Keys1[i]
        for (i in Keys2) print i, Keys2[i]
    }

    if (join == "left") left = 1
    else if (join == "right") right = 1
    else if (join == "inner") inner = 1
    else if (join == "diff") diff = 1

    if (!merge) {
        bias_merge = 0
    }

    run_inner = !diff
    run_right = !left && !inner
    skip_left = inner || right
    null_field = null_off ? "" : "<NULL>"

    "wc -l < \""ARGV[1]"\"" | getline f1nr; f1nr+=0 # Get number of rows in file1
}

FNR < 2 {
    header_unset = 1
}

$0 ~ /^[[:space:]]*$/ {
    next
}

debug {
    print NR, FNR, keycount, key, "\""FS"\""
}

keycount = 0

merge && header_unset {
    if (!header) {
        header_unset = 0
    }
    GenMergeKeys(mf_max ? mf_max : NF, K1, K2)
}

## Save first stream

NR == FNR {
    #if (k1 > NF) { print "Key out of range in file 1"; err = 1; exit }

    if (NF > max_nf1) max_nf1 = NF

    if (header_unset) {
        header_unset = 0

        if (gen_keys) {
            GenKeys(0, NF, K1, K2)
        }

        if (header) {
            header1 = $0
            next
        }
    }

    keybase = GenKeyString(Keys1)
    key = keybase _ keycount

    while (key in S1) {
        keycount++
        key = keybase _ keycount
    }

    SK1[key]++
    S1[key, SK1[key]] = $0

    if (NR == f1nr) FS = fs2
    next
}

## Print matches and second file unmatched

NR > FNR { 
    #if (k2 > NF) { print "Key out of range in file 2";  err = 1; exit }
    if (NF > max_nf2) max_nf2 = NF

    if (header_unset) {
        header_unset = 0

        if (gen_keys) {
            GenKeys(1, NF, K1, K2)
        }

        if (header) { 
            if (ind) printf "%s", OFS
            print GenInnerOutputString(header1, $0, K2, max_nf1, max_nf2, fs1)
            header_unset = 0
            next
        }
    }

    keybase = GenKeyString(Keys2)
    key = keybase _ keycount

    # Print right joins and inner joins

    if (key in SK1) {
        SK2[key]++

        while (key _ SK2[key] in S1) {
            sk2_keycount = SK2[key]

            if (run_inner) {
                record_count++
                if (ind) printf "%s", record_count OFS
                print GenInnerOutputString(S1[key, sk2_keycount], $0, K2, max_nf1, max_nf2, fs1)
            }

            delete S1[key, sk2_keycount]
            keycount++
            key = keybase _ keycount
        }
    }
    else {
        S2[key] = $0

        while (key in S2) {
            record_count++

            if (run_right) {
                if (ind) printf "%s", record_count OFS
                print GenRightOutputString(S2[key], K1, K2, max_nf1, max_nf2, fs2)
            }

            keycount++
            key = keybase _ keycount
        }
    }
}

END {
    if (err) exit err
    if (skip_left) exit

    # Print left joins

    for (compound_key in S1) {
        record_count++
        if (ind) printf "%s", record_count OFS
        stream2_line = full_bias ? S2[compound_key] : ""
        print GenLeftOutputString(S1[compound_key], stream2_line, K1, max_nf1, max_nf2, fs1, fs2)
    }
}

function GenKeys(file2_call, nf, K1, K2, GenKeySet) {
    delete MissingKeys
    
    for (i = 1; i <= length(file2_call ? Keys2 : Keys1); i++) {
        key_pattern = file2_call ? Keys2[i] : Keys1[i]
        key_found = 0

        if (!case_sensitive) {
            key_pattern = tolower(key_pattern)
        }

        for (f = 1; f <= nf; f++) {
            field = case_sensitive ? $f : tolower($f)
            
            if (field ~ "^(\"|')*"key_pattern) {
                if (file2_call) {
                    Keys2[i] = f
                    K2[f] = Keys1[i]
                    K1[K2[f]] = f
                    
                    if (K2[key_pattern] in K1) {
                        delete K1[K2[key_pattern]]
                    }
                    
                    delete K2[key_pattern]
                }
                else {
                    Keys1[i] = f
                    K1[f] = f
                    K2[K1[f]] = f
                    delete K1[key_pattern]
                }
                
                key_found = 1
                break
            }
        }

        if (!key_found) {
            MissingKeys[key_pattern] = 1
        }
    }

    if (length(MissingKeys) > 0) {
        if (file2_call && inherit_keys) {
            n_keys = length(Keys2)

            for (i = 1; i <= n_keys; i++) {
                delete K2[Keys2[i]]
                delete Keys2[i]
            }

            for (i = 1; i <= n_keys; i++) {
                key = Keys1[i]
                Keys2[i] = key
                K2[key] = K1[key]
            }

            return
        }

        err = 1
        
        if (file2_call) {
            filename = ARGV[2]
            
            if (filename ~ /^\/tmp\//) {
                filename = "right data"
            }
        }
        else {
            filename = ARGV[1]

            if (filename ~ /^\/tmp\//) {
                filename = "left data"
            }
        }
        
        printf "%s", "Could not locate keys in "filename": "
        PrintMap(MissingKeys, 1)
        exit
    }
}

function GenMergeKeys(nf, K1, K2) {
    for (f = 1; f <= nf; f++) {
        if (f in BiasMergeKeys) {
            continue
        }
        else if (gen_bias_merge_keys_from_exclusion \
            && !(f in BiasMergeExcludeKeys)) {
            BiasMergeKeys[f] = f
            continue
        }

        K1[f] = f
        K2[f] = f
        Keys1[f] = f
        Keys2[f] = f
    }
}

function GenKeyString(Keys) {
    str = ""

    for (i in Keys) {
        k = Keys[i]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $k)
        if (length($k) == 0) $k = null_field
        str = str $k _
    }

    return str
}

function GenInnerOutputString(line1, line2, K2, nf1, nf2, fs1) {
    jn = inner_label
    
    if (bias_merge) {
        split(line1, Line1, fs1)

        for (f = 1; f <= nf1; f++) {
            if (f in BiasMergeKeys && (full_bias || (length($f) > 0 && $f != null_field))) {
                if (full_bias && length($f) == 0) {
                    jn = jn null_field
                }
                else {
                    jn = jn $f
                }
            }
            else {
                jn = jn Line1[f]
            }
            
            if (f < nf1) jn = jn OFS
        }
    }
    else {
        nf_pad = Max(nf1 - gsub(fs1, OFS, line1), 0)
        jn = jn line1

        for (f = nf_pad; f > 1; f--) {
            jn = jn OFS
        }
    }

    for (f = 1; f <= nf2; f++) {
        if (f in K2) continue
        if (bias_merge && f in BiasMergeKeys) continue
        jn = jn OFS $f
    }

    return jn
}

function GenRightOutputString(line2, K1, K2, nf1, nf2, fs2) {
    jn = right_label

    for (f = 1; f <= nf1; f++) {
        if (f in K1) {
            jn = jn $K1[f]
        }
        else if (bias_merge && f in BiasMergeKeys) {
            if (length($f) == 0) {
                jn = jn null_field
            }
            else {
                jn = jn $f
            }
        }
        else {
            jn = jn null_field
        }
        if (f < nf1) jn = jn OFS
    }

    for (f = 1; f <= nf2; f++) {
        if (f in K2) continue
        if (bias_merge && f in BiasMergeKeys) continue
        jn = jn OFS $f
    }

    return jn
}

function GenLeftOutputString(line1, line2, K1, nf1, nf2, fs1, fs2) {
    jn = inner_label
    
    if (full_bias) {
        split(line1, Line1, fs1)
        split(line2, Line2, fs2)

        for (f = 1; f <= nf1; f++) {
            if (f in BiasMergeKeys) {
                new_field = Line2[f]
            }
            else {
                new_field = Line1[f]
            }

            if (length(new_field) == 0) {
                new_field = null_field
            }

            jn = jn new_field
            
            if (f < nf1) jn = jn OFS
        }
    }
    else {
        nf_pad = Max(nf1 - gsub(fs1, OFS, line1), 0)
        jn = jn line1

        for (f = nf_pad; f > 1; f--) {
            jn = jn OFS
        }
    }

    for (f = 1; f <= nf2; f++) {
        if (f in K2) continue
        if (bias_merge && f in BiasMergeKeys) continue
        jn = jn OFS null_field
    }

    return jn
}
