#!/usr/bin/awk
#
# Script to run a full outer join of two files or data streams similar to 
# `join` Unix program but with slightly different features.
# 
# If there is one field number to join on, assign it to var k at runtime:
# > awk -f join.awk -v k=1 file1 file2
#
# If there are different keys in each file, run as:
# > awk -f join.awk -v k1=1 -v k2=2 file1 file2
#
# If there are multiple fields to join on in a single file, separate the column
# numbers with commas:
# > awk -f join.awk -v k1=1,2 -v k2=3,4 file1 file2
#
# If headers are present, set the header variable to any value:
# -v headers=1
#
# Add an index:
# -v ind=true
#
# Any other Awk variables such as FS, OFS can be assigned as normal

BEGIN {
  _ = SUBSEP

  if (!fs1) fs1 = FS
  if (!fs2) fs2 = FS

  if (k) {
    k1 = k
    k2 = k
  } else {
    if (!k1) { print "Missing key"; err=1; exit err }
    if (!k2) { print "Missing key"; err=1; exit err }
  }
  split(k1, keys1, /[[:punct:]]+/)
  split(k2, keys2, /[[:punct:]]+/)
  for (i in keys1)
    if (! keys1[i] ~ /^\d+$/) { print "Keys must be integers"; err=1; exit err }
  for (i in keys2)
    if (! keys2[i] ~ /^\d+$/) { print "Keys must be integers"; err=1; exit err }

  "wc -l < \""ARGV[1]"\"" | getline f1nr; f1nr+=0 # Get number of rows in file1
  FS = fs1
  if (!(FS ~ "\\[\:.+\:\\]")) OFS = FS
}

debug { print NR, FNR, keycount, key, FS }
keycount = 0

# Save first stream
NR == FNR {
  if (k1 > NF) { print "Key out of range in file 1"; err = 1; exit }

  if (NF > max_nf1) max_nf1 = NF

  if (FNR == 1 && header) { header1 = $0; next }

  keybase = genKeyString(keys1)
  key = keybase _ keycount

  while (key in s1) {
    keycount++
    key = keybase _ keycount
  }
  
  s1[key] = $0
  if (NR == f1nr) FS = fs2
  next
}

# Print matches and second file unmatched rows
NR > FNR { 
  if (k2 > NF) { print "Key out of range in file 2";  err = 1; exit }
  
  if (NF > max_nf2) max_nf2 = NF
  
  if (FNR == 1 && header) { 
    if (ind) printf "%s", OFS
    print genOutputString(header1, fs1), genOutputString($0, fs2)
    next
  }

  keybase = genKeyString(keys2)
  key = keybase _ keycount

  if (key in s1) {
    while (key in s1) {
      recordcount++
      if (ind) printf "%s", recordcount OFS
      print genOutputString(s1[key], fs1), genOutputString($0, fs2)
      delete s1[key]
      keycount++
      key = keybase _ keycount
    }
  } else {
    s2[key] = $0

    while (key in s2) {
      recordcount++
      if (ind) printf "%s", recordcount OFS
      printNullFields(max_nf1)
      print OFS genOutputString(s2[key], fs2)
      keycount++
      key = keybase _ keycount
    }
  }
}

END {
  if (err) exit err

  # Print first file unmatched rows
  for (key in s1) {
    recordcount++
    if (ind) printf "%s", recordcount OFS
    printf "%s", genOutputString(s1[key], fs1) OFS
    printNullFields(max_nf2)
    print ""
  }
}

function genKeyString(keys) {
  str = ""
  for (i in keys)
    k = keys[i]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $k)
    if (length($k) == 0) $k = "<NULL>"
    str = str $k _
  return str
}
function genOutputString(line, fs) {
  gsub(fs, OFS, line)
  return line
}
function printNullFields(nf) {
  for (i=1; i<=nf; i++)
    if (i == nf) { printf "%s", "<NULL>" } else { printf "%s", "<NULL>" OFS }
}

