#!/usr/bin/awk
# DS:DIFF_FIELDS
#
# NAME
#       ds:diff_fields, diff_fields.awk
#
# SYNOPSIS
#       ds:diff_fields [-h|--help|file] [file*] [op=-] [exclude_fields=0] [prefield=f] [awkargs]
#
# DESCRIPTION
#       diff_fields.awk is a script to perform an elementwise operation on the fields 
#       of two files or data streams with equivalent length and field placement.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based
#       systems it should be), and call it on two files along with utils.awk:
#
#          > awk -f support/utils.awk -f diff_fields.awk file1 file2
#
#       ds:diff_fields is the caller function for the diff_fields.awk script. To run any 
#       of the examples below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#          $ file2_data | ds:diff_fields file1
#
#       ds:diff_fields can be run with multiple files beyond the second, using the same 
#       arguments as the initial operation, with limited extended functionality:
#
#          $ ds:diff_fields file1 file2 file3 file4 ... [op] ...
#
# FIELD CONSIDERATIONS
#       When running ds:diff_fields, an attempt is made to infer field separators of up 
#       to three characters. If none found, FS will be set to default value, a single
#       space = " ". To override FS, add as a trailing awkarg. If the two files have
#       different FS, assign to vars fs1 and fs2. Be sure to escape and quote if needed. 
#       AWK's extended regex can be used as FS:
#
#          $ ds:diff_fields file1 file2 -v fs1=',' -v fs2=':'
#
#          $ ds:diff_fields file1 file2 -v FS=" {2,}"
#
#          $ ds:diff_fields file1 file2 -F'\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:diff_fields file1 file2 -v FS=""
#
#       When running ds:diff_fields, an attempt is made to extract relevant instances of 
#       field separators in the case that a field separator appears in field values. To 
#       turn this off set prefield to false in the positional arg.
#
#          $ ds:diff_fields simple1.csv simple2.csv % 1 1 [f|false]
#
#       If ds:join detects it is connected to a terminal, it will attempt to fit the data
#       into the terminal width using the same field separator. If the data is being sent to
#       a file or a pipe, no attempt to fit will be made. One easy way to turn off fit is to
#       cat the output or redirect to a file.
#
#          $ file2_data | ds:join file1 | cat
#
# USAGE
#       op (diff operation) takes one of five options:
#
#          - - elementwise subtraction
#          % - elementwise percent difference
#          + - elementwise addition
#          * - elementwise multiplication
#          / - elementwise division
#
#       exclude_fields will default to the first field. To set multiple exclude fields, 
#       list their indices separated by commas:
#
#          ds:diff_fields file1 file2 [op] 3,4
#
#       If exclude_fields is set to 0 (default) or empty string, no fields will be 
#       excluded.
#
# AWKARG OPTS
#       If headers are present, set the header variable to any value to ensure header 
#       values are not diffed and labeled properly in output:
#
#          -v header=1
#
#       Set extra lines of printout listing the field headers involved in each diff 
#       intersection, along with the values involved, when the diff is not zero (implies 
#       header):
#
#          -v diff_list=1
#
#       To print out only the diff list, set its value to "only":
#
#          -v diff_list=only
#
#       By default the diff list is sorted in descending order of diff. To turn this off:
#
#          -v diff_list_sort=off
#
#       To sort diff list in ascending order:
#
#          -v diff_list_sort=a[sc]
#
# VERSION
#       0.1
#
# AUTHORS
#       Tom Hall (tomhall.main@gmail.com)
#
## TODO: Diff by unordered join keys

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

    if (!exclude_fields || exclude_fields == "" || exclude_fields == 0) {
        exclude_fields = 0
    }
    else {
        split(exclude_fields, _ExcludeFields, /,+/)

        for (i = 1; i <= length(_ExcludeFields); i++) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", _ExcludeFields[i])
            field_index = _ExcludeFields[i]

            if (length(field_index) == 0) {
                continue
            }
            else if (!(field_index ~ /^[0-9]+$/)) {
                print "Invalid exclude field index (exclude_fields must be a list of ints): " field_index
                err = 1
                exit(err)
            }

            ExcludeFields[field_index] = 1

            if (i == 1 && diff_list) {
                diff_list_row_header = field_index
            }
        }
    }
    
    file_labels = (ARGV[1] && ARGV[2] && ARGV[1] != ARGV[2])

    if (!left_label) {
        left_label = file_labels ? ARGV[1] : "FILE1"
        
        if (left_label ~ /^\/tmp\/ds_diff_fields/) {
            left_label = "LEFTDATA"
        }
    }
    if (!right_label) {
        right_label = file_labels ? ARGV[2] : "FILE2"

        if (piped) {
            right_label = "PIPEDATA"
        }
        else if (right_label ~ /^\/tmp\/ds_diff_fields/) {
            right_label = "RIGHTDATA"
        }
    }

    if (op == "-") subtract = 1
    else if (op == "+") add = 1
    else if (op == "%") pc = 1
    else if (op == "*") mult = 1
    else if (op == "/") div = 1

    if (diff_list) {
        if (tolower(diff_list) == "only") {
            diff_list = 1
            diff_list_only = 1
        }

        if (tolower(diff_list_sort) == "off") {
            sort_off = 1
        }
        else if (!deterministic) {
            SeedRandom()
        }
    }

    "wc -l < \""ARGV[1]"\"" | getline f1nr; f1nr+=0 # Get number of rows in file1
}

header && FNR < 2 {
    header_unset = 1
}

$0 ~ /^[[:space:]]*$/ {
    next
}

header && header_unset {
    header_unset = 0
    
    if (NR > FNR) {
        gsub(FS, OFS)        

        if (diff_list) {
            split($0, Header, fs2)

            for (i = 1; i <= length(Header); i++) {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", Header[i])
            }

            if (!diff_list_only) {
                print $0
            }
        }
        else {
            print $0
        }
    }

    next
}

## Save first stream

NR == FNR {
    S1[NR] = $0
    if (NR == f1nr) FS = fs2
    next
}

## Print diff op result

NR > FNR { 
    split(S1[FNR], Stream1Line, fs1)
    
    for (f = 1; f <= NF; f++) {
        s1_val = Stream1Line[f]
        s2_val = $f
        
        if (f in ExcludeFields) { 
            PrintDiffField($f)
        }
        else {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s1_val)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s2_val)
            
            while (s1_val != "" || s2_val != "") {
                if (s1_val == "") {
                    s1_val = 0
                    s2_val = GetOrSetExtractVal(s2_val)

                    if (!s2_val && s2_val != 0) {
                        PrintDiffField($f)
                        break
                    }

                    s2_val = GetOrSetTruncVal(s1_val)
                }
                else if (s2_val == "") {
                    s1_val = GetOrSetExtractVal(s1_val)
                    s2_val = 0
                    
                    if (!s1_val && s1_val != 0) {
                        PrintDiffField(Stream1Line[f])
                        break
                    }

                    s1_val = GetOrSetTruncVal(s1_val)
                }
                else {
                    s1_val = GetOrSetExtractVal(s1_val)
                    s2_val = GetOrSetExtractVal(s2_val)

                    if (!s1_val && s1_val != 0) {
                        if (!s2_val && s2_val != 0) {
                            break
                        }
                        else {
                            PrintDiffField($f)
                            break
                        }
                    }
                    else if (!s2_val && s2_val != 0) {
                        PrintDiffField(Stream1Line[f])
                        break
                    }

                    s1_val = GetOrSetTruncVal(s1_val)
                    s2_val = GetOrSetTruncVal(s2_val)
                }

                if (subtract) {
                    diff_val = s1_val - s2_val
                }
                else if (pc) {
                    if (s1_val == 0) {
                        if (s2_val == 0) {
                            diff_val = 0
                        }
                        else {
                            diff_val = 1
                        }
                    }
                    else {
                        diff_val = (s2_val - s1_val) / s1_val
                        
                        if (s1_val < 0 && s2_val < 0) {
                            diff_val *= -1
                        }
                    }
                }
                else if (add) {
                    diff_val = s1_val + s2_val
                }
                else if (mult) {
                    diff_val = s1_val * s2_val
                }
                else {
                    if (s2_val == 0) {
                        break
                    }
                    else {
                        diff_val = s1_val / s2_val
                    }
                }

                PrintDiffField(diff_val)

                if (diff_list) {
                    if (div) {
                        if (diff_val == 1) {
                            break
                        }
                    }
                    else {
                        if (diff_val == 0) {
                            break
                        }
                    }

                    if (diff_list_row_header) {
                        if (header) {
                            list_val = $diff_list_row_header _ Header[f] _ Stream1Line[f] _ $f _ diff_val
                        }
                        else {
                            list_val = $diff_list_row_header _ f _ Stream1Line[f] _ $f _ diff_val
                        }
                    }
                    else {
                        list_val = FNR _ f _ Stream1Line[f] _ $f _ diff_val
                    }

                    DiffList[++diff_counter] = list_val
                }

                break
            }
        }

        if (f < NF) PrintDiffField(OFS)
    }

    PrintDiffField("\n")
}

END {
    if (err) exit err
    if (!diff_list) {
        exit
    }

    if (!sort_off) {
        if (diff_list_sort ~ /^a/) {
            QSAN(DiffList, 1, diff_counter)
        }
        else {
            QSDN(DiffList, 1, diff_counter)
        }
    }

    if (!diff_list_only) {
        print "\n\n"
    }

    print "ROW" OFS "FIELD" OFS left_label OFS right_label OFS "DIFF"

    for (i = 1; i <= diff_counter; i++) {
        gsub(_, OFS, DiffList[i])
        print DiffList[i]
    }
}

function PrintDiffField(field_val) {
    if (diff_list_only) {
        return
    }

    printf "%s", field_val
}

function GetOrSetTruncVal(val) {
    if (TruncVal[val]) return TruncVal[val]

    large_val = val > 999
    large_dec = val ~ /\.[0-9]{3,}/

    if ((large_val && large_dec) \
        || val ~ /^-?[0-9]*\.?[0-9]+(E|e)\+?([4-9]|[1-9][0-9]+)$/) {
        trunc_val = int(val)
    }
    else {
        trunc_val = sprintf("%f", val) # Small floats flow through this logic
    }

    trunc_val += 0
    TruncVal[val] = trunc_val
    return trunc_val
}

function GetOrSetExtractVal(val) {
    if (ExtractVal[val]) return ExtractVal[val]
    if (NoVal[val]) return ""

    cleaned_val = val
    gsub(",", "", cleaned_val)
    
    if (ExtractVal[cleaned_val]) return ExtractVal[cleaned_val]
    if (NoVal[cleaned_val]) return ""
    
    if (match(cleaned_val, /-?[0-9]*\.?[0-9]+((E|e)(\+|-)[0-9]+)?/)) {
        if (extract_vals) {
            extract_val = substr(cleaned_val, RSTART, RSTART+RLENGTH)
        }
        else if (RSTART > 1 || RLENGTH < length(cleaned_val)) {
            NoVal[val] = 1
            return ""
        }
        else {
            extract_val = cleaned_val
        }
    }
    else {
        NoVal[val] = 1
        return ""
    }

    extract_val += 0
    ExtractVal[val] = extract_val
    return extract_val
}

function GetN(str) {
    if (NS[str]) {
        return NS[str]
    }
    
    split(str, Line, _)
    n_val = Line[length(Line)]
    n_val = n_val + 0
    NS[str] = n_val
    if (diff_list_row_header) {
        NExt[str] = Line[2] _ Line[3] _ Line[4] _ Line[5]
    }
    else {
        NExt[str] = Line[1] _ Line[2] _ Line[3] _ Line[4]
    }
    return n_val
}
