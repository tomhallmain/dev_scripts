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
#       Fit a table of values with dynamic column lengths. Prefer the shell
#       entry point `ds:fit`.
#
#       Manual awk load order (required):
#         > awk -f support/utils.awk \
#               -f scripts/fit_columns_functions.awk \
#               -f scripts/fit_columns_program.awk \
#               file{,}
#
#       Multibyte-safe installs should also load `support/wcwidth.awk`
#       (ds:fit does this when awksafe). Files must be passed twice when
#       invoking awk directly.
#
#       Help text lives in this file (`ds:fit -h`). Do not also load the
#       stub `fit_columns.awk` with the modules (it is documentation-only).
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
#       Custom gridline characters (with gridlines=1):
#
#         -v gridline_h="─"    Horizontal segment (default box-drawing)
#         -v gridline_v="│"    Vertical separator (default box-drawing)
#
#       Run with custom buffer (default is 1):
#
#         -v buffer=5
#
#       Custom character for buffer/separator:
#
#         -v bufferchar="|"
#
#       Cache / batch tuning (optional):
#
#         -v chunk_size=50
#         -v cache_cleanup_interval=10000
#         -v cache_cleanup_max_entries=1000
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
#       Strip currency symbols ($/£) from number fields, like the default
#       comma normalization:
#
#         -v strip_currency=1
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
# PERFORMANCE
#       - Caches multibyte display widths (wcscolumns) per distinct field value
#       - Pre-seeds pad strings for common widths (8, 10, 19)
#       - Pre-generates short gridline segments after gridline chars are set
#       - Walks wide rows in field chunks (default chunk_size=50)
#       - Periodically clears cut/trunc/width caches on long files
#       - Number / decimal / float patterns are compiled once in BEGIN
#       - Proportional column shrinking for terminal width fitting
#
# VERSION
#       1.4
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
## TODO: Custom gridline corner characters (h/v overrides cover runs/separators today)
## TODO: Optionally apply a currency/unit symbol to number column values (inverse of strip_currency, e.g. -v apply_currency=$)
## TODO: Implement parallel processing for very large files
## TODO: Add column-specific formatting rules
