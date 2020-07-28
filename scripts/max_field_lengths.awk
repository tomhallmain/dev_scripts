#!/usr/bin/awk
#
# Unoptimized script to print a table of values with 
# dynamic column lengths. Unfortunately this requires 
# passing the file twice to Awk, once to read the lengths
# and once to print the output - and within that there are
# for loops to look at each field individually.
#
# Calling the script on a single file "same_file":
# > awk -f max_field_lengths.awk same_file same_file

NR == FNR {
  for (i=1; i<=NF; i++) {
    len = length($i)
    if (len)
      max[i] = ( len > max[i] ? len : max[i] )
    if (d && ! d_set[i] && ($i ~ "^[0-9]+[\.][0-9]*$") == 1) {
      max[i] += d
      d_set[i] = 1
    }
  }
}

NR > FNR {
  if (FNR == 1) {
    for (i=1; i<=NF; i++)
      if(max[i]) max[i] += buffer
  }
  for (i=1; i<=NF; i++) {
    if (max[i]) {
      if (d && d_set[i]) {
        justify_str = "%"
        if (($i ~ "^[0-9]+\.?[0-9]*$") == 1)
          type_str = "." d "f"
        else
          type_str = "s"
        fmt_str = justify_str max[i] type_str
        printf fmt_str, $i
        printf "%.*s", buffer, "                      "
      } else {
        justify_str = "%-"
        fmt_str = justify_str max[i] "s"
        printf fmt_str, $i
      }
    }
    if (i == NF) { printf "\n" }
  }
}
