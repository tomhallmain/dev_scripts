# Unoptimized script to print a table of values with 
# dynamic column lengths. Unfortunately this requires 
# passing the file twice to AWK, once to read the lengths
# and once to print the output - and within that there are
# for loops to look at each field individually.

# Any large optimization that preserves a deterministic output
# that exactly matches column widths in every field would 
# probably require a different language, or some weird use of
# regex on the full line based on the separator passed.

# Calling the script on a single file "same_file":
#
# awk -f max_field_lengths.awk same_file same_file

NR == FNR {
  for (i=1; i<=NF; i++) {
    len = length($i)
    if (len) {
      max[i] = ( len > max[i] ? len : max[i] )
    }
  }
}
NR > FNR {
  if (FNR == 1) { 
    for (i=1; i<=NF; i++)
      if(max[i]) { max[i] += buffer }
  }
  for (i=1; i<=NF; i++) {
    if (max[i]) {
      fmt_str = "%-" max[i] "s"
      printf fmt_str, $i
    }
    if (i == NF) { printf "\n" }
  }
}
