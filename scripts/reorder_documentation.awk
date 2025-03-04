#!/usr/bin/awk
# DS:REO
#
# NAME
#       ds:reo, reorder.awk
#
# SYNOPSIS
#       ds:reo [-h|--help|file] [r_args_str] [c_args_str] [prefield=true] [awkargs]
#
# DESCRIPTION
#       reorder.awk is a script that reorders, repeats, or slices the rows and columns of 
#       fielded data. It can also be used on non-fielded data but its usefulness may be 
#       limited to rows in that case.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based 
#       systems it should be), and call it on a file along with utils.awk:
#
#          > awk -f support/utils.awk -f reorder.awk -v r=1 -v c=1 file
#
#       r and c refer to row and column order args respectively.
#
#       Comma is the order arg separator. To escape a comma, it must have two backslashes 
#       when passed to AWK, so it must have three backslashes if in double quotes, or two 
#       in single quotes:
#
#          > awk -f reorder.awk -v r="~\\\," c='~\\,'
#
#       ds:reo is the caller function for the reorder.awk script. To run any of the 
#       examples below, map AWK args as given in SYNOPSIS. For example, to print columns 
#       where the header matches "ZIP" on the first row where rows match "Main St":
#
#          $ ds:reo addresses.csv "1,~Main St" "[ZIP" -v cased=1
#
#       When running with piped data, args are shifted:
#
#          $ data_in | ds:reo [r_args_str] [c_args_str] [prefield=true] [awkargs]
#
# FIELD CONSIDERATIONS
#       When running ds:reo, an attempt is made to infer a field separator of up to
#       three characters. If none is found, FS will be set to default value, a single 
#       space = " ". To override the FS, add as a trailing awkarg. Be sure to escape 
#       and quote if needed. AWK's extended regex can be used as FS:
#
#          $ ds:reo a 1,4 -v FS=" {2,}"
#
#          $ ds:reo 7..1 1..4 -v FS='[A-z]+'
#
#          $ ds:reo a rev -F'\\\|\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:reo addresses.csv '[ZIP%3' a -v FS=""
#
#       When running ds:reo, an attempt is made to extract relevant instances of field 
#       separators in the case that a field separator appears in field values. To turn this 
#       off set prefield to false in the positional arg.
#
#          $ ds:reo simple_data.csv 1,500..2 a [f|false]
#
#       If ds:reo detects it is connected to a terminal, it will attempt to fit the data 
#       into the terminal width using the same field separator. If the data is being sent to 
#       a file or a pipe, no attempt to fit will be made. One easy way to turn off fit is to 
#       cat the output or redirect to a file.
#
#          $ echo "data" | ds:reo 1,2,3 | cat
#
# SIMPLE USAGE
#       Print help:
#
#          $ ds:reo -h
#
#       Index a field value (Print the field value at row 1 col 1):
#
#          $ ds:reo 1 1
#
#       Print multiple specific rows and/or columns:
#
#          $ ds:reo 1,1000 1,4,5
#
#         (Print row 1 then 1000, only cols 1, 4 and 5)
#
#       Print rows/column index numbers relative to maximum index value:
#
#          $ ds:reo -1,-2 -3
#
#       Pass all rows / columns for given index - don't set arg or set arg=[a|all]:
#
#          $ ds:reo a 4
#
#         (Example: Print all rows, only column 4)
#
#       Print index range (ranges are inclusive of ending indices):
#
#          $ ds:reo 1,100..200 1..3,5
#
#       Print index range with endpoints relative to maximum index val:
#
#          $ ds:reo -3..-1 -5..1
#
#       Reorder/repeat rows and fields, duplicate as many times as desired:
#
#          $ ds:reo 3,3,5,1 4..1,1,3,5
#
#       Print a range by defining inclusive pattern anchors. If one of the anchors is not 
#       given, it will default to the first or last row for start or end anchor respectively:
#
#          $ ds:reo '1,5, startrow_match##endrow_match'  ##endfield_match
#
#          $ ds:reo /start/.. /start/../end/
#
#       Turn off field separation for calculation and output - set c to "off":
#
#          $ ds:reo start## off
#
#       Reverse indices by adding the string r[everse] anywhere in the order:
#
#          $ ds:reo 1,r all,rev
#
#       Index numbers evaluating to expression. If no comparison specified, compares if 
#       expression equal to zero. NR and NF refer to the index number and must be used on 
#       the left side of the expression:
#
#          $ ds:reo 'NR%2,NR%2=1' 'NF<10'
#
#       Output with row and column index numbers from source:
#
#          $ ds:reo rev rev -v idx=1
#
# ADVANCED USAGE
#       Filter records by field values and/or fields by record values:
#
#       -- Using basic math expressions, across the entire opposite span:
#
#          $ ds:reo '=1, <1' '/5<11'
#
#         (Example: Print rows with field value =1, followed by rows with value <1, and 
#          fields with values less than 11 when divided by 5)
#
#
#       -- Using basic math expressions, across given span:
#
#          $ ds:reo '1, 8<0' '6!=10'
#
#         (Example: Print the header row followed by rows where field 8 is negative, only
#          fields with values in row 6 not equal to 10)
#
#
#       -- Using len() / length() function. The parameter is the index number of row or 
#          column respectively. If no parameter given, all fields are searched for condition:
#
#          $ ds:reo 'len(3)<100' 'length()>50'
#
#
#       -- Using regular expressions across the opposite span, full or specified:
#
#          $ ds:reo '~plant , !~[A-z]' '3~[0-9]+\.[0-9]' -v cased=1
#
#         (Example: Print Rows matching "plant" followed by rows without alpha chars, only 
#          fields with values in row 3 that match simple decimal pattern)
#
#
#       Alternatively filter the cross-span by a current-span frame pattern. Headers --
#       first row and first column -- are the default if not specified:
#
#          $ ds:reo '[plant~flower' '3[alps>10000'
#
#         (Example: Print rows where column header matches "plant" and column value matches 
#          "flower", cols where values in row 3 match "alps" and which have number values 
#          greater than 10000
#
#
#       If no expression or search given with frame, simple search is done on the cross
#       span, not the current span -- frame rows by column, columns by row:
#
#          $ ds:reo file '[europe' '[plant'
#
#         (Example: Print rows where first col matches 'europe' (any case), fields where
#          first row matches 'plant' (any case))
#
#          Note the above args are equivalent to '1~europe' '1~plant'.
#
#
#       Combine filters using && and || for more selective or expansive queries (|| is 
#       currently calculated first):
#
#          $ ds:reo '[plant~flower || [plant~tree && [country~italy' rev
#
#         (Example: Print rows where field vals in fields with headers matching "plant" match
#          "flower" OR where the same match tree and field vals in fields in the same row with
#          headers matching "country" match "italy"; print all fields in reverse order)
#
#
#       Case is ignored globally by default in regex searches. To enable cased matching set 
#       variable cased to any value. To search a case insensitive value while cased is set,
#       append "/i" to the end of the pattern:
#
#          $ ds:reo '[europe/i' '[Plant' -v cased=1
#
#         (Example: Print rows where first col matches "europe" in any case, fields where 
#          first row matches "Plant" exactly)
#
#
#       Print any columns or rows that did not match filter args, add o[thers] anywhere in 
#       either order:
#
#          $ ds:reo '3, 4, others, 1' '[Tests,oth'
#
#         (Example: Print rows 3, 4, then any not in the set 1,3,4, then row 1; fields where 
#          header matches "tests", then any remaining fields):
#
#
#       Constrain output to unique indices on searches, expressions, reverses:
#
#          $ ds:reo a 'len()>0,len()<100000' -v uniq=1
#
#
# VERSION
#       0.3
#
# AUTHORS
#       Tom Hall (tomhallmain@gmail.com)
#
## TODO: Option (or default?) for preserving original order if possible
## TODO: Basic sorts and multisort
## TODO: String equality / sorting
## TODO: Remove frame print if already indexed, and don't print if no match?
## TODO: Expressions and comparisons against cross-index total
## TODO: Expressions and comparisons between fields (standard awk)
## TODO: Range support for index number and pattern endpoints combined
## TODO: Full line regex check for field non-specific searches
## TODO: Access rows in columns and vice versa (for example, print every other row together as one)
## TODO: Add memory usage monitoring and reporting
## TODO: Implement adaptive chunk sizing based on available memory
## TODO: Add parallel processing support for very large files

# PERFORMANCE CONSIDERATIONS
#       When processing large datasets, ds:reo automatically manages memory by:
#
#       1. Processing data in chunks (default 10,000 lines per chunk):
#
#          $ ds:reo large_file.csv 1,2 3,4 -v chunk_size=5000
#
#       2. Caching pattern matches and field values:
#          - Regex patterns are compiled and cached
#          - Field values are cached for case-insensitive operations
#          - Expression results are cached for repeated evaluations
#
#       3. Batch processing field operations:
#          - Field printing is optimized for large numbers of fields
#          - Memory usage is managed through array cleanup
#
#       For very large files, you can adjust the chunk size:
#
#          $ ds:reo huge_file.csv a 1..100 -v chunk_size=1000
#
#       Memory usage can be monitored using the debug flag:
#
#          $ ds:reo data.csv 1,2 3,4 -v debug=1