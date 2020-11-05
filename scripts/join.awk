#!/usr/bin/awk
#
# Script to run a join of two files or data streams similar to `join` Unix 
# program but with slightly different features.
# 
# If there is one field number to join on, assign it to var k at runtime:
#     > awk -f join.awk -v k=1 file1 file2
#
# If there are different keys in each file, run as:
#     > awk -f join.awk -v k1=1 -v k2=2 file1 file2
#
# If there are multiple fields to join on in a single file, separate the column
# numbers with commas:
#     > awk -f join.awk -v k1=1,2 -v k2=3,4 file1 file2
#
# If headers are present, set the header variable to any value:
#     -v headers=1
#
# Add an index:
#     -v ind=true
#
# Merge with output indicating files involved:
#     -v merge_verbose=1
#
# Merge with custom labels:
#     -v left_label="Stuff"
#     -v right_label="Other stuff"
#     -v inner_label="All the stuff"
#
# Any other Awk variables such as FS, OFS can be assigned as normal

BEGIN {
  _ = SUBSEP

  if (!fs1) fs1 = FS
  if (!fs2) fs2 = FS
  FS = fs1
  if (!(FS ~ "\\[\:.+\:\\]")) OFS = FS

  if (merge) {
    if (merge_verbose || right_label || left_label) {
      merge_verbose = 1
      file_labels = (ARGV[1] && ARGV[2] && ARGV[1] != ARGV[2])
      if (!left_label)
        left_label = (file_labels ? ARGV[1] : "FILE1") OFS
      if (!right_label)
        right_label = (file_labels ? ARGV[2] : "FILE2/PIPED") OFS
      if (!inner_label)
        inner_label = "BOTH" OFS }}
  else {
    if (k) { k1 = k; k2 = k; equal_keys = 1 }
    else if (!k1 || !k2) {
      print "Missing key"; exit 1 }

    len_k1 = split(k1, Keys1, /[[:punct:]]+/)
    len_k2 = split(k2, Keys2, /[[:punct:]]+/)
    if (len_k1 != len_k2) {
      print "Keysets must be equal in length"; exit 1 }
    for (i = 1; i <= len_k1; i++) {
      key = Keys1[i]
      if (!(key ~ /^[0-9]+$/)) { print "Keys must be integers"; exit 1 }}
    for (i = 1; i <= len_k2; i++) {
      key = Keys2[i]
      joint_key = Keys1[i]
      if (!(key ~ /^[0-9]+$/)) { print "Keys must be integers"; exit 1 }
      K2[key] = joint_key
      K1[joint_key] = key }}

  if (join == "left") left = 1
  else if (join == "right") right = 1
  else if (join == "inner") inner = 1
  else if (join == "diff") diff = 1

  run_inner = !diff
  run_right = !left && !inner
  skip_left = inner || right

  "wc -l < \""ARGV[1]"\"" | getline f1nr; f1nr+=0 # Get number of rows in file1
}

debug { print NR, FNR, keycount, key, FS }
keycount = 0

merge && FNR == 1 { GenMergeKeys(NF, K1, K2) }

## Save first stream
NR == FNR {
  #if (k1 > NF) { print "Key out of range in file 1"; err = 1; exit }

  if (NF > max_nf1) max_nf1 = NF

  if (header && FNR == 1) { header1 = $0; next }

  keybase = GenKeyString(Keys1)
  key = keybase _ keycount

  while (key in S1) {
    keycount++
    key = keybase _ keycount }
  
  S1[key] = $0

  if (NR == f1nr) FS = fs2
  next
}

## Print matches and second file unmatched rows
NR > FNR { 
  #if (k2 > NF) { print "Key out of range in file 2";  err = 1; exit }
  
  if (NF > max_nf2) max_nf2 = NF

  if (header && FNR == 1) { 
    if (ind) printf "%s", OFS
    print GenInnerOutputString(header1, $0, K2, max_nf1, max_nf2, fs1)
    next }

  keybase = GenKeyString(Keys2)
  key = keybase _ keycount

  if (key in S1) {
    while (key in S1) {
      if (run_inner) {
        record_count++
        if (ind) printf "%s", record_count OFS
        print GenInnerOutputString(S1[key], $0, K2, max_nf1, max_nf2, fs1) }
      delete S1[key]
      keycount++
      key = keybase _ keycount }}
  else {
    S2[key] = $0

    while (key in S2) {
      record_count++
      if (run_right) {
        if (ind) printf "%s", record_count OFS
        print GenRightOutputString(S2[key], K1, K2, max_nf1, max_nf2, fs2) }
      keycount++
      key = keybase _ keycount }}
}

END {
  if (err) exit err
  if (skip_left) exit

  # Print first file unmatched rows
  for (key in S1) {
    record_count++
    if (ind) printf "%s", record_count OFS
    print GenLeftOutputString(S1[key], K1, max_nf1, max_nf2, fs1) }
}


function GenMergeKeys(nf, K1, K2) {
  for (f = 1; f <= nf; f++) {
    K1[f] = f; K2[f] = f
    Keys1[f] = f; Keys2[f] = f}
}
function Max(a, b) {
  if (a > b) return a
  else if (a < b) return b
  else return a
}
function GenKeyString(Keys) {
  str = ""
  for (i in Keys) {
    k = Keys[i]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $k)
    if (length($k) == 0) $k = "<NULL>"
    str = str $k _ }
  return str
}
function GenInnerOutputString(line1, line2, K2, nf1, nf2, fs1) {
  nf_pad = Max(nf1 - gsub(fs1, OFS, line1), 0)
  jn = inner_label line1
  for (f = nf_pad; f > 1; f--)
    jn = jn OFS
  for (f = 1; f <= nf2; f++) {
    if (f in K2) continue
    jn = jn OFS $f }
  return jn
}
function GenRightOutputString(line2, K1, K2, nf1, nf2, fs2) {
  jn = right_label
  for (f = 1; f <= nf1; f++) {
    if (f in K1)
      jn = jn $K1[f]
    else
      jn = jn "<NULL>"
    if (f < nf1) jn = jn OFS }
  for (f = 1; f <= nf2; f++) {
    if (f in K2) continue
    jn = jn OFS $f }
  return jn
}
function GenLeftOutputString(line1, K1, nf1, nf2, fs1) {
  nf_pad = Max(nf1 - gsub(fs1, OFS, line1), 0)
  jn = left_label line1
  for (f = nf_pad; f > 1; f--)
    jn = jn OFS
  for (f = 1; f <= nf2; f++) {
    if (f in K2) continue
    jn = jn OFS "<NULL>" }
  return jn
}
