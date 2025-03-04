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
#       1.3.1
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

# fit_columns.awk - Fit a table of values with dynamic column lengths
#
# SYNOPSIS
#   awk -f fit_columns.awk [options] [file ...]
#
# DESCRIPTION
#   Formats input data into aligned columns with dynamic width adjustment.
#   Optimized for performance with large datasets and multibyte characters.
#
# PERFORMANCE OPTIMIZATIONS
#   - Caches common field widths and multibyte character widths
#   - Batch processing for large files (>100 fields)
#   - Smart memory management with periodic cache cleanup
#   - Efficient number format detection
#   - Pre-generated grid line patterns
#   - Proportional column shrinking for terminal width fitting
#
# OPTIONS
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
# IMPLEMENTATION NOTES
#   - Uses "@@@" as standard field separator (from quoted_fields.awk)
#   - Caches widths for common field sizes (8, 10, 19 chars)
#   - Performs cleanup every 10k records to manage memory
#   - Processes large files in batches of 50 fields
#   - Pre-compiles regex patterns for number detection
#
# TODO
#   - Add support for custom width caching patterns
#   - Implement parallel processing for very large files
#   - Add column-specific formatting rules
#   - Support custom cache cleanup intervals