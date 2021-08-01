#!/usr/bin/awk
#
# Script to print with fields in a staggered format.
# Useful to print files with long column values readably.
# 
# Example - F1 F2 F3 F4 becomes:
# F1
#      F2
#            F3
#                   F4
#
# Calling the script on a single file "same_file":
#
# > awk -f max_field_lengths.awk same_file same_file

BEGIN {
    if (!stag_size) stag_size = 5
    space = "                                                                             "
    stag = sprintf("%.*s", stag_size, space)
    if (!tty_size) "tput cols" | getline tty_size; tty_size += 0
}

{
    spacer = 0
    stag_space = ""

    for (i=1; i<=NF; i++) {
        if (spacer && tty_size / spacer < 1.5) {
            spacer = 0
            stag_space = ""
        }

        field_width = tty_size - spacer
    
        if (length($i) > field_width) {
            while (length($i) > field_width) {
                print stag_space substr($i, 1, field_width)
                $i=substr($i, field_width + 1)
            }
        }
    
        print stag_space $i
        spacer += stag_size
        stag_space = stag_space stag
    }

    print ""
}
