# Script to run a full outer join of two files or data streams similar to the 
# `join` Unix program but with slightly different features.
# 
# If there is one field number to join on, assign that value to var k at runtime:
# > awk -f fullouterjoin.awk -v k=1 file1 file2
#
# If there are different keys in each file, run as:
# > awk -f fullouterjoin.awk -v k1=1 -v k2=2 file1 file2
#
# If there are multiple fields to join on in a single file, separate the column
# numbers with commas:
# > awk -f fullouterjoin.awk -v k1=1,2 -v k2=3,4 file1 file2
#
# If headers are present, set the header variable to any value:
# > awk -f fullouterjoin.awk -v headers=true -v k=1 file1 file2
#
# Any other Awk variables such as OFS can be assigned as normal.

function genKeyString(keys) {
  str = ""
  for (i in keys)
    k = keys[i]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $k)
    str = str $k _
  return str
}

function genOutputString(line, fs) {
  gsub(fs, OFS, line)
  return line
}

function printNullFields(nf) {
  for (i=1; i<=nf; i++)
    printf "NULL" OFS
}

BEGIN {
  _ = SUBSEP

  if (!fs1) fs1 = FS
  if (!fs2) fs2 = FS

  if (k) {
    k1 = k
    k2 = k
  } else {
    if (!k1) { print "Missing key"; err=1; exit }
    if (!k2) { print "Missing key"; err=1; exit }
  }
  split(k1, keys1, /[[:punct:]]+/)
  split(k2, keys2, /[[:punct:]]+/)
  for (i in keys1)
    if (! keys1[i] ~ /^\d+$/) { print "Keys must be integers"; err=1; exit }
  for (i in keys2)
    if (! keys2[i] ~ /^\d+$/) { print "Keys must be integers"; err=1; exit }

  FS = fs1
}

debug { print NR, FNR, keycount, key }
keycount = 0

# Save first stream
NR == FNR {
  if (k1 > NF) { print "Key out of range in file 1"; err = 1; exit }

  if (NF > max_nf1) max_nf1 = NF

  if (FNR == 1 && header) { header1 = $0; next }

  keybase = genKeyString(keys1)
  key = keybase
  
  while (key in s1)
    keycount++
    key = keybase keycount

  s1[key] = $0
  #if (!getline) FS = fs2
  next
}

# Save second stream and print first matches and second file complements
NR > FNR { 
  if (k2 > NF) { print "Key out of range in file 2";  err = 1; exit }
  
  if (NF > max_nf2) max_nf2 = NF
  
  if (FNR == 1 && header) { 
    print genOutputString(header1, fs1), genOutputString($0, fs2)
    next
  }

  keybase = genKeyString(keys2)
  key = keybase keycount

  if (key in s1) {
    while (key in s1) {
      print s1[key], genOutputString($0, fs2)
      delete s1[key]
      keycount++
      key = keybase keycount
    }
  } else {
    printNullFields(max_nf1)
    print genOutputString($0, fs2)
  }
}

END {
  if (err) exit err

  for (key in s1) {
    printf genOutputString(s1[key], fs1) OFS
    printNullFields(max_nf2)
    print ""
  }
}
