#!/usr/bin/awk
# DS:AGG
#
# NAME
#       ds:agg — modular entry (stub)
#
# SYNOPSIS (manual awk)
#       awk -f support/utils.awk \
#           -f scripts/agg_functions_extended.awk \
#           -f scripts/agg_functions.awk \
#           -f scripts/agg_program.awk \
#           -v r_aggs=… -v c_aggs=… file
#
# DESCRIPTION
#       Logic lives in:
#         agg_functions_extended.awk  — median/mode/quartile/stddev helpers
#         agg_functions.awk           — expression parsing and core helpers
#         agg_program.awk             — BEGIN / main / END
#         agg_documentation.awk       — help text for `ds:agg -h`
#
#       Prefer `ds:agg` from commands.sh, which loads the modules in that order.
#
#       This file is intentionally not a runnable program (avoids double-BEGIN
#       if loaded alongside the modules).
#
