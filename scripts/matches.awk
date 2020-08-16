#!/usr/bin/awk
#
# Script to print the records in one file that match records in another file. 
#
# Run examples:
# > awk -f matches.awk -v fs1="|" -v fs2="\t" -v k1=1 -v k2=3 "file1" "file2"
# OR
# > awk -f matches.awk -v fs="," -v k=2 "file1" "file2"
#
# If no key is given the entire record $0 will be used.
#
# Field separator args (fs, fs1, fs2) are not required if they can be reasonably
# inferred from the data.

BEGIN {
  f1 = ARGV[1]
  f2 = ARGV[2]
  piped = (substr(f2, 1, 4) == "/tmp" || substr(f2, 1, 4) == "/dev")
  f2_print = (piped ? "piped data" : f2)

  if (fs) { fs1 = fs; fs2 = fs }
  else {
    if (!fs1) { # TODO: Script is currently failing on this line
      cmd = "awk -f ~/dev_scripts/scripts/infer_field_separator.awk " f1 
      cmd | getline fs1
      close(cmd)
    }
    if (!fs2) {
      cmd = "awk -f ~/dev_scripts/scripts/infer_field_separator.awk " f2
      cmd | getline fs2
      close(cmd)
    }
  }

  if (k) { k1 = k; k2 = k }
  else if (k1 || k2) {
    if (!k1) k1 = k2
    if (!k2) k2 = k1
  } else {
    k1 = 0; k2 = 0
  }

  FS = fs1
  print ""
}

NR == FNR {  _[$k1] = 1 }

NR > FNR {
  if (FNR == 1) {
    if (k2 == 0)
      row[k2] = $0
    else
      split($0, row, fs2)

    if (_[row[k2]] == 1) {
      print "Records found in both " f1 " and " f2_print ":\n"
      print $0
      match_found = 1
    }
    FS = fs2
    next
  }

  if (_[$k2] == 1) {
    if (!match_found) {
      print "Records found in both " f1 " and " f2_print ":\n"
      match_found = 1
    }
    print $0
  }
}

END {
  if (!match_found) print "NO MATCHES FOUND"
  print ""
}
