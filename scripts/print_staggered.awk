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
# awk -f max_field_lengths.awk same_file same_file

BEGIN {  
  if (!TTY_WIDTH) { 
    print "Terminal width not provided - exiting"
    exit 1 
  } 
}

{
  spacer = 0
  space_string = ""

  for (i=1; i<=NF; i++) {
    field_width = TTY_WIDTH - spacer
    if (field_width < 0) { field_width = 0 }
    
    if (length($i) > field_width) {
      while (length($i) > field_width) {
        print space_string substr($i, 1, field_width)
        $i=substr($i, field_width + 1)
      }
    }
    
    print space_string $i
    spacer += 5
    space_string = space_string "     "
  }

  print ""
}
