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
  if (!TTY_WIDTH) { 
    print "Terminal width not provided - exiting"
    exit 1 
  } 
}

{
  spacer = 0
  space_str = ""

  for (i=1; i<=NF; i++) {
    if (spacer && TTY_WIDTH / spacer < 1.5) {
      spacer = 0
      space_str = ""
    }

    field_width = TTY_WIDTH - spacer
    
    if (length($i) > field_width) {
      while (length($i) > field_width) {
        print space_str substr($i, 1, field_width)
        $i=substr($i, field_width + 1)
      }
    }
    
    print space_str $i
    spacer += 5
    space_str = space_str "     "
  }

  print ""
}
