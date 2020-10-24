#!/usr/bin/awk
#
# Add index numbers to text data.

BEGIN {
  if (FS ~ /\[\[:space:\]\]\{2.\}/) {
    FS = "  "; space_fs = 1 }
  else if (FS ~ /\[.+\]/) {
    FS = " "; space_fs = 1 }

  space = space_fs && !pipeout
  start_mod = header - 1
  if (ARGV[1]) { "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0 }
}

{
  i = NR - start_mod
  if (space) {
    len_max = max_nr ? length(max_nr) : 6
    format_str = "%"len_max"s"
    printf format_str, i
    print FS $0 }
  else
    print i FS $0
}

END {
  if (!NR) exit 1
}
