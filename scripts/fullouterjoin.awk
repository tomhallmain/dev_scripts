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

BEGIN {
  if (fs) {
    fs1 = fs
    fs2 = fs
  } else {
    if (!fs1) fs1 = FS
    if (!fs2) fs2 = FS
  }

  if (k) {
    k1 = k
    k2 = k
  } else {
    if (!k1) { print "Missing key"; exit }
    if (!k2) { print "Missing key"; exit }
  }
  split(k1, keys1, ",")
  split(k2, keys2, ",")
  for (i in keys1) { if (! keys1[i] ~ /^[0-9]$/) { print "Bad key value"; exit } }
  for (i in keys2) { if (! keys2[i] ~ /^[0-9]$/) { print "Bad key value"; exit } }

  FS = fs1
}

# Save first stream
NR==FNR {   
  if ( header && FNR == 1 ) {
    headers1 = $0
    next
  }
  s1[$0] = 1
  key1[$k1] = 1
  nrs1 = FNR
  next
}

# Save second stream
NR < FNR {
  if ( header && FNR == 1 ) {
    headers2 = $0
    next
  }
  s2[$1] = $2
  ns2 = FNR
  next
}



END {
# Process first stream the second time. Print header in first line and for
# the rest check if first field is found in the hash.
FNR == (NR - LR_F1 - LR_F2) {
  if ( $1 in hash2 ) { 
    printf "%s\n", $1, hash2[ $1 ], $2, $3, $4
  } else {
    printf "%s\n", $1, "null", $2, $3, $4
  }
}

# Process second file of arguments the second time. Check if the first field is found 
# in the hash.
FNR < (NR - LR_F1 - LR_F2) {
  if ( $1 in hash1 || FNR == 1 ) {
    next
  } else {
    printf "%s\n", $0, "null", "null", "null"
  }
}

}
