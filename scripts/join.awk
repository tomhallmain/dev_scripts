#!/usr/bin/awk
# DS:JOIN
#
# NAME
#       ds:join, ds:jn, join.awk
#
# SYNOPSIS
#       ds:join [-h|--help|file] [file*] [jointype=outer] [k|merge] [k2] [prefield=t] [awkargs]
#
# DESCRIPTION
#       join.awk is a script to run a join of two files or data streams with variant 
#       options for output.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based
#       systems it should be), and call it on two files:
#
#          > awk -f join.awk file1 file2
#
#       ds:join is the caller function for the join.awk script. To run any of the examples 
#       below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#          $ file2_data | ds:join file1
#
#       ds:jn can be run with multiple files beyond the second, using the same arguments
#       as the initial join, with limited extended functionality:
#
#          $ ds:join file1 file2 file3 file4 ... [jointype] ...
#
# FIELD CONSIDERATIONS
#       When running ds:jn, an attempt is made to infer field separators of up to
#       three characters. If none found, FS will be set to default value, a single
#       space = " ". To override FS, add as a trailing awkarg. If the two files have
#       different FS, assign to vars fs1 and fs2. Be sure to escape and quote if needed. 
#       AWK's extended regex can be used as FS:
#
#          $ ds:join file1 file2 -v fs1=',' -v fs2=':'
#
#          $ ds:join file1 file2 -v FS=" {2,}"
#
#          $ ds:join file1 file2 -F'\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:join file1 file2 -v FS=""
#
#       When running ds:jn, an attempt is made to extract relevant instances of field
#       separators in the case that a field separator appears in field values. To turn this
#       off set prefield to false in the positional arg.
#
#          $ ds:join simple1.csv simple2.csv inner 1 1 [f|false]
#
#       If ds:jn detects it is connected to a terminal, it will attempt to fit the data
#       into the terminal width using the same field separator. If the data is being sent to
#       a file or a pipe, no attempt to fit will be made. One easy way to turn off fit is to
#       cat the output or redirect to a file.
#
#          $ file2_data | ds:join file1 | cat
#
# USAGE
#       Jointype takes one of five options:
#
#          o[uter] - default
#          i[nner]
#          l[eft]
#          r[ight]
#          d[iff]
#
#       Certain jointypes will not function well when joining more than two files: left,
#       right, diff
#
#       If there is one field number to join on, assign it to var k at runtime:
#
#          $ ds:join file1 file2 o 1
#
#       If there are different keys in each file, assign file2's key second:
#
#          $ ds:join file1 file2 o 1 2
#
#       If there are multiple fields to join on in a single file, separate the column
#       numbers with commas. Note the key sets must be equal in length:
#
#          $ ds:join file1 file2 o 1,2 2,3
#
#       To join on all fields from both files, set k to "merge":
#
#          $ ds:join file1 file2 left merge
#
# AWKARG OPTS
#       Note that any fields beyond the maximum of the first row in the first file will 
#       not be merged unless mf_max is set:
#
#          $ ds:join file1 file2 right merge -v mf_max=9
#
#   **  If headers are present, set the header variable to any value to ensure
#       consistent header positioning:
#
#          -v header=1
#
#   **  Add an index to output:
#
#          -v ind=1
#
#   **  Merge with an extra column of output indicating files involved:
#
#          -v merge_verbose=1
#
#   **  Merge with custom labels:
#
#          -v left_label="Stuff"
#          -v right_label="Other stuff"
#          -v inner_label="BOTH stuff"
#
#
#   ** - Works only on two-file joins
#
# VERSION
#       1.0
#
# AUTHORS
#       Tom Hall (tomhall.main@gmail.com)
#

BEGIN {
  _ = SUBSEP

  if (!fs1) fs1 = FS
  if (!fs2) fs2 = FS
  FS = fs1
  OFS = SetOFS()
  if (OFS ~ /\[\:.+\:\]\{2,\}/)
    OFS = "  "
  else if (OFS ~ /\[\:.+\:\]/)
    OFS = " "

  if (merge) {
    if (merge_verbose) {
      merge_verbose = 1
      file_labels = (ARGV[1] && ARGV[2] && ARGV[1] != ARGV[2])

      if (!left_label)
        left_label = (file_labels ? ARGV[1] : "FILE1")
      if (!right_label)
        right_label = (file_labels ? ARGV[2] : "FILE2")
      if (!inner_label)
        inner_label = "BOTH"

      left_label = left_label OFS
      right_label = piped ? "PIPEDDATA" OFS : right_label OFS
      inner_label = inner_label OFS
    }
    else {
      left_label = ""; right_label = ""; inner_label = ""
    }
  }
  else {
    left_label = ""; right_label = ""; inner_label = ""

    if (k) {
      k1 = k
      k2 = k
      equal_keys = 1
    }
    else if (!k1 || !k2) {
      print "Missing key"
      exit 1
    }

    len_k1 = split(k1, Keys1, /[[:punct:]]+/)
    len_k2 = split(k2, Keys2, /[[:punct:]]+/)

    if (len_k1 != len_k2) {
      print "Keysets must be equal in length"
      exit 1
    }

    for (i = 1; i <= len_k1; i++) {
      key = Keys1[i]

      if (!(key ~ /^[0-9]+$/)) {
        print "Keys must be integers"
        exit 1
      }
    }

    for (i = 1; i <= len_k2; i++) {
      key = Keys2[i]
      joint_key = Keys1[i]

      if (!(key ~ /^[0-9]+$/)) {
        print "Keys must be integers"
        exit 1
      }

      K2[key] = joint_key
      K1[joint_key] = key
    }
  }

  if (join == "left") left = 1
  else if (join == "right") right = 1
  else if (join == "inner") inner = 1
  else if (join == "diff") diff = 1

  run_inner = !diff
  run_right = !left && !inner
  skip_left = inner || right

  "wc -l < \""ARGV[1]"\"" | getline f1nr; f1nr+=0 # Get number of rows in file1
}

debug {
  if (NR < 2) {
    for (i in Keys1) print i, Keys1[i]
    for (i in Keys2) print i, Keys2[i]
  }
  print NR, FNR, keycount, key, FS
}

keycount = 0

merge && FNR < 2 {
  GenMergeKeys(mf_max ? mf_max : NF, K1, K2)
}

## Save first stream
NR == FNR {
  #if (k1 > NF) { print "Key out of range in file 1"; err = 1; exit }

  if (NF > max_nf1) max_nf1 = NF

  if (header && FNR < 2) {
    header1 = $0
    next
  }

  keybase = GenKeyString(Keys1)
  key = keybase _ keycount

  while (key in S1) {
    keycount++
    key = keybase _ keycount
  }

  SK1[key]++
  S1[key, SK1[key]] = $0

  if (NR == f1nr) FS = fs2
  next
}

## Print matches and second file unmatched
NR > FNR { 
  #if (k2 > NF) { print "Key out of range in file 2";  err = 1; exit }

  if (NF > max_nf2) max_nf2 = NF

  if (header && FNR == 1) { 
    if (ind) printf "%s", OFS
    print GenInnerOutputString(header1, $0, K2, max_nf1, max_nf2, fs1)
    next
  }

  keybase = GenKeyString(Keys2)
  key = keybase _ keycount

  # Print right joins and inner joins

  if (key in SK1) {
    SK2[key]++

    while (key _ SK2[key] in S1) {
      sk2_keycount = SK2[key]

      if (run_inner) {
        record_count++
        if (ind) printf "%s", record_count OFS
        print GenInnerOutputString(S1[key, sk2_keycount], $0, K2, max_nf1, max_nf2, fs1)
      }

      delete S1[key, sk2_keycount]
      keycount++
      key = keybase _ keycount
    }
  }
  else {
    S2[key] = $0

    while (key in S2) {
      record_count++

      if (run_right) {
        if (ind) printf "%s", record_count OFS
        print GenRightOutputString(S2[key], K1, K2, max_nf1, max_nf2, fs2)
      }

      keycount++
      key = keybase _ keycount
    }
  }
}

END {
  if (err) exit err
  if (skip_left) exit

  # Print left joins

  for (compound_key in S1) {
    record_count++
    if (ind) printf "%s", record_count OFS
    print GenLeftOutputString(S1[compound_key], K1, max_nf1, max_nf2, fs1)
  }
}

function GenMergeKeys(nf, K1, K2) {
  for (f = 1; f <= nf; f++) {
    K1[f] = f
    K2[f] = f
    Keys1[f] = f
    Keys2[f] = f
  }
}

function GenKeyString(Keys) {
  str = ""

  for (i in Keys) {
    k = Keys[i]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $k)
    if (length($k) == 0) $k = "<NULL>"
    str = str $k _
  }

  return str
}

function GenInnerOutputString(line1, line2, K2, nf1, nf2, fs1) {
  nf_pad = Max(nf1 - gsub(fs1, OFS, line1), 0)
  jn = inner_label line1

  for (f = nf_pad; f > 1; f--)
    jn = jn OFS

  for (f = 1; f <= nf2; f++) {
    if (f in K2) continue
    jn = jn OFS $f
  }

  return jn
}

function GenRightOutputString(line2, K1, K2, nf1, nf2, fs2) {
  jn = right_label

  for (f = 1; f <= nf1; f++) {
    if (f in K1)
      jn = jn $K1[f]
    else
      jn = jn "<NULL>"
    if (f < nf1) jn = jn OFS
  }

  for (f = 1; f <= nf2; f++) {
    if (f in K2) continue
    jn = jn OFS $f
  }

  return jn
}

function GenLeftOutputString(line1, K1, nf1, nf2, fs1) {
  nf_pad = Max(nf1 - gsub(fs1, OFS, line1), 0)
  jn = left_label line1

  for (f = nf_pad; f > 1; f--)
    jn = jn OFS

  for (f = 1; f <= nf2; f++) {
    if (f in K2) continue
    jn = jn OFS "<NULL>"
  }

  return jn
}
