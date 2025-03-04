#!/usr/bin/awk
# DS:AGG
#
# NAME
#       ds:agg, agg.awk - Advanced data aggregation and statistical analysis
#
# SYNOPSIS
#       ds:agg [-h|file*] [r_aggs=expr] [c_aggs=expr] [-v option=value]
#
# DESCRIPTION
#       agg.awk is a powerful script for aggregating and analyzing data streams or files
#       using various aggregation expressions and statistical functions. It supports basic
#       arithmetic operations, advanced statistical measures, and flexible grouping options.
#
#       Basic Usage:
#         > awk -f support/utils.awk -f agg.awk -v r_aggs=+ -v c_aggs=+ file
#
#       With Extended Functions:
#         > awk -f support/utils.awk -f agg_functions.awk -f agg_functions_extended.awk -f agg.awk file
#
#       If no aggregation expressions are provided, sum aggregation will be run on all 
#       rows and columns.
#
#       Pipeline Usage:
#         $ data_in | ds:agg [r_aggs=expr] [c_aggs=expr]
#
# AGGREGATION OPERATORS
#      Basic Operators:
#        +    Addition (sum)
#        -    Subtraction
#        *    Multiplication
#        /    Division
#        m    Mean (shorthand)
#        mean Mean (full name)
#
#      Statistical Operators:
#        med    Median
#        mode   Mode (most frequent value)
#        sd     Standard deviation
#        q1     First quartile (25th percentile)
#        q2     Second quartile (median)
#        q3     Third quartile (75th percentile)
#
# EXPRESSION TYPES
#      1. Range Expressions:
#         Format: [operator]|[index_scope]
#         Examples:
#           +|all          Sum all numeric fields
#           mean|all       Average of all numeric fields
#           *|2..6         Product of fields 2 through 6
#           med|all        Median of all numeric fields
#           sd|2..10       Standard deviation of fields 2-10
#
#      2. Specific Field Expressions:
#         Format: [operator]|field1[op]field2...
#         Examples:
#           $1+$3          Sum of fields 1 and 3
#           $2*$4          Product of fields 2 and 4
#           price+tax      Sum of fields with headers "price" and "tax"
#           med|cost       Median of fields with header "cost"
#
#      3. Search-Based Expressions:
#         Format: [operator]|[field]~pattern
#         Examples:
#           ~test          Count occurrences of "test"
#           +|~price       Sum fields containing "price"
#           med|~value     Median of fields containing "value"
#
#      4. Comparison Expressions:
#         Format: [operator]|[field][comp]value
#         Examples:
#           >4             Count fields greater than 4
#           +|>100         Sum of fields greater than 100
#           med|$2>50      Median of values where field 2 > 50
#
#         Supported comparisons: =, <, >, !=
#
#      5. Cross-Aggregation Expressions:
#         Format: [operator]|agg_field|group_fields
#         Examples:
#           $3             Sum field 3 grouped by field 1
#           mean|$3|$4     Mean of field 3 grouped by field 4
#           med|$3|4..5    Median of field 3 grouped by fields 4-5
#
# FIELD HANDLING
#      Field Separator (FS) Options:
#        - Auto-detection of separators up to 3 characters
#        - Manual override: -F':' or -v FS=":"
#        - Extended regex: -v FS=" {2,}"
#        - Escaped separators: -v FS='\\\|'
#        - Character mode: -v FS=""
#
#      Terminal Output:
#        - Auto-fits to terminal width when output is to terminal
#        - No fitting when output is redirected: ds:agg file > output.txt
#
# OPTIONS
#      extract_vals=1     Extract numbers from non-numeric fields
#      fixed_nf=N        Set fixed maximum column count
#      og_off=1          Force print all expression headers
#      awksafe=1         Extra-safe number extraction
#      debug=1           Enable debug output
#
# CACHING AND PERFORMANCE
#      The script implements several optimization strategies:
#      - Value extraction caching
#      - Statistical computation caching
#      - Periodic cache cleanup
#      - Fast string splitting for frequently used patterns
#
# EXAMPLES
#      Basic Usage:
#        $ ds:agg data.csv -v r_aggs=+|all
#        $ ds:agg data.tsv -v c_aggs=mean|2..5
#
#      Statistical Analysis:
#        $ ds:agg data.csv -v r_aggs=med|all,q1|all,q3|all
#        $ ds:agg data.csv -v r_aggs=sd|price,mean|cost
#
#      Combined Operations:
#        $ ds:agg data.csv -v r_aggs=+|all,med|all,sd|all
#        $ ds:agg data.csv -v c_aggs=mean|price,q3|sales
#
# VERSION
#      2.0
#
# AUTHORS
#      Tom Hall (tomhallmain@gmail.com)
#      Extended statistical functions added by the development team
#
# NOTES
#      - Memory usage increases with data size and number of statistical operations
#      - Cache cleanup occurs periodically to manage memory usage
#      - Statistical functions cache results for improved performance
#
# TODO
#      - Add support for weighted means and medians
#      - Implement additional statistical measures (skewness, kurtosis)
#      - Enhance pattern matching for header aggregations
#      - Add support for custom aggregation functions
#      - Implement parallel processing for large datasets