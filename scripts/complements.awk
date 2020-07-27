# Script to print the records in one file that do not match the records in
# another file and vice versa. Similar to the join command but does not need
# sorting for use.
#
# Run examples:
# awk -f complements.awk -v fs1="|" -v fs2="\t" -v k1=1 -v k2=3 "file1" "file2"
# OR
# awk -f complements.awk -v fs="," -v k=2 "file1" "file2"
#
# Field separator args (fs, fs1, fs2) are not required if they can be reasonably
# inferred from the data.

BEGIN {
  f1 = ARGV[1]
  f2 = ARGV[2]

  if ( fs ) { # TODO: Add this logic for keys
    fs1 = fs
    fs2 = fs
  } else {
    if ( ! fs1 ) { # TODO: Script is currently failing on this line
      cmd = "awk -f ~/dev_scripts/scripts/infer_field_separator.awk " f1 
      cmd | getline fs1
      close(cmd)
    }
    if ( ! fs2 ) {
      cmd = "awk -f ~/dev_scripts/scripts/infer_field_separator.awk " f2
      cmd | getline fs2
      close(cmd)
    }
  }

  FS = fs1
  print ""
  print "Records found in " f2 " not present in " f1 ":"
}

NR == FNR {
  _[$k1] = 1
  first[$k1] = $0
  next
}

NR > FNR {
  if ( FNR == 1 ) {
    split($0, row, fs2)
    if ( _[row[k2]] != 1 ) {
      print $0
      f2_count++
    } else {
      both[row[k2]] = first[row[k2]]
      delete first[row[k2]]
    }
    FS=fs2
    next
  }
  if ( _[$k2] != 1 ) {
    print $0
    f2_count++
  } else {
    both[$k2] = first[$k2]
    delete first[$k2]
  }
}

END {
  if ( ! f2_count ) print "NONE"
  print ""
  print "Records found in " f1 " not present in " f2 ":"
  if ( length(first) > 0 ) {
    for (r in first)
      print first[r]
  } else {
    print "NONE"
  }
  print ""
}
