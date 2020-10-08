#!/usr/bin/awk
#
# Transpose the field values of a text-based field-separated file
#
# > awk -f transpose.awk file
# > command | awk -f transpose.awk

{ 
  if (NF > max_nf) max_nf = NF
  for (i = 1; i <= NF; i++)
    _[i, NR] = $i 
  if (!VAR_OFS && !(FS ~ "\[.+\]")) {
    if (FS ~ "\\\\") 
      FS = UnescapeOFS() 
    else
      OFS = FS }
}

END {
  for (i = 1; i <= max_nf; i++) {
    for (j = 1; j < NR; j++) {
      printf _[i, j] OFS
      delete _[i, j] }
    printf "%s\n", _[i, j] }
}

function UnescapeOFS() {
  split(FS, FSTokens, "\\")
  OFS = ""
  for (i = 1; i <= length(FSTokens); i++)
    OFS = OFS FSTokens[i]

  return OFS
}
