#!/usr/bin/awk
#
# Script to infer a probable set of join fields between two text-based 
# field-separated data files.
#
# Run with a field separator common to both files (e.g. comma):
# > awk -f infer_join_fields.awk -F"," file1 file2
#
# Run with a field separator unique to each file:
# > awk -f infer_join_fields.awk -v fs1="," -v fs2 =":" file1 file2


BEGIN {
  Re["i"] = "^[0-9]+$"                       # is integer
  Re["hi"] = "[0-9]+"                        # has integer
  Re["d"] = "^[0-9]+\.[0-9]+$"               # is decimal
  Re["hd"] = "[0-9]+\.[0-9]+"                # has decimal
  Re["a"] = "[A-z]+"                         # is alpha
  Re["ha"] = "[A-z]+"                        # has alpha
  Re["u"] = "^[A-Z]+$"                       # is uppercase letters
  Re["hu"] = "[A-Z]+"                        # has uppercase letters
  Re["nl"] = "^[^a-z]+$"                     # does not have lowercase letters
  Re["w"] = "[A-z ]+"                        # words with spaces
  Re["ns"] = "^[^[:space:]]$"                # no spaces
  Re["id"] = "(^|_| |\-)?[Ii][Dd](\-|_| |$)" # the string ` id ` appears in any casing
  Re["d1"] = "^[0-9]{1,2}[\-\.\/][0-9]{1,2}[\-\.\/]([0-9]{2}|[0-9]{4})$" # date1
  Re["d2"] = "^[0-9]{4}[\-\.\/][0-9]{1,2}[\-\.\/][0-9]{1,2}$"            # date2
  Re["l"] = ":\/\/"                                      # link
  Re["j"] = "^\{[,:\"\'{}\[\]A-z0-9.\-+ \n\r\t]{2,}\}$"  # json
  Re["h"] = "\<\/\w+\>"                                  # html/xml

  if (!fs1) fs1 = FS
  if (!fs2) fs2 = FS

  if (ARGV[1])

  max_rows = 50
  if (!trim) trim = 1
  if (!header) header = 1
  FS = fs2 # Field splitting not started until second file reached
}


debug && FNR < max_rows { debug_print(1) }


# Save first stream
NR == FNR && FNR <= max_rows {
  if (trim) $0 = trimField($0)
  if ( header && FNR == 1 ) {
    headers = $0
    next
  }
 
  s1[$0] = 1
  rcount1++
  next
}


NR > FNR && FNR <= max_rows { 
  if (trim) $0 = trimField($0)
  if ( header && FNR == 1 ) {
    split(headers, headers1, fs1)
    split($0, headers2, fs2)
    for (i in headers1) {
      for (j in headers2) {
        h1 = headers1[i]
        h2 = headers2[j]
        if (trim) {
          h1 = trimField(h1) 
          h2 = trimField(h2) }
        if (h1 == h2) {
          if (i == j) print i
          else print i, j
          keys_found = 1
          exit }
        if ((h1 ~ h2) < 1) { # Is one header contained within another?
          k1[i, j] += 5000 * rcount1
          k2[j, i] += 5000 * rcount1 }
        if ((h1 ~ Re["id"]) < 1 && (h2 ~ Re["id"]) < 1) { # ID headers should have advantage
          k1[i, j] += 1000 * rcount1
          k2[j, i] += 1000 * rcount1 }}}
    next }

  nf2 = split($0, fr2, fs2)
  
  for (fr in s1) {
    nf1 = split(fr, fr1, fs1)
    
    for (i in fr1) {
      f1 = fr1[i]
      if (trim) f1 = trimField(f1)
      if ((header && FNR == 2) || (!header && FNR == 1)) {
        k1[i, "dlt"] = f1 }
      buildFieldScore(f1, i, k1)
      if (debug) debug_print("endbfsf1")
      
      for (j in fr2) {
        f2 = fr2[j]
        if (trim) f2 = trimField(f2)
        if ((header && FNR == 2) || (!header && FNR == 1)) {
          k2[i, "dlt"] = f2 }
        buildFieldScore(f2, j, k2)
        if (debug) debug_print("endbfsf2")
        
        if (f1 != f2) {
          k1[i, j] += 100
          k2[j, i] += 100 }
        if ((f1 ~ Re["d"]) > 0 || (f2 ~ Re["d"]) > 0) {
          k1[i, j] += 1000 * rcount1
          k2[j, i] += 1000 * rcount1 }
        if ((f1 ~ Re["j"]) > 0 || (f2 ~ Re["j"]) > 0) {
          k1[i, j] += 1000 * rcount1
          k2[j, i] += 1000 * rcount1 }
        if ((f1 ~ Re["h"]) > 0 || (f2 ~ Re["h"]) > 0) {
          k1[i, j] += 1000 * rcount1
          k2[j, i] += 1000 * rcount1 }
      }}}

  if (nf1 > max_nf1) max_nf1 = nf1
  if (nf2 > max_nf2) max_nf2 = nf2
  rcount2++
}


END {
  if (keys_found) exit

  calcSims(k1, k2)

  jf1 = 999 # Seeding with high values unlikely to be reached
  jf2 = 999
  scores[jf1, jf2] = 100000000000000000000000000

  for (i = 1; i <= max_nf1; i++) {
    for (j = 1; j <= max_nf2; j++) {
      if (scores[i, j] < scores[jf1, jf2]) {
        jf1 = i; jf2 = j }
      if (debug) debug_print(7) }}

  # Return possible join fields with lowest score
  if (jf1 == jf2) print jf1
  else print jf1, jf2
}


function trimField(field) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
  return field
}
function buildFieldScore(field, position, Keys) {
  if (Keys[position, "dlt"] && field != Keys[position, "dlt"]) {
    delete Keys[position, "dlt"] }
  Keys[position, "len"] += length(field)
  for (m in Re) {
    re = Re[m]
    matches = field ~ re
    if (matches > 0) {
      Keys[position, m] += 1; matchcount++ }}
  if (debug) debug_print(2)
}
function calcSims(Keys1, Keys2) {
  for (k = 1; k <= max_nf1; k++) {
    for (l = 1; l <= max_nf2; l++) {
      kscore1 = Keys1[k, l]
      kscore2 = Keys2[l, k]
      scores[k, l] += ((kscore1 + kscore2) / (rcount1 + rcount2)) ** 2
      
      if (Keys1[k, "dlt"] || Keys2[l, "dlt"]) scores[k, l] += 1000 * (rcount1+rcount2)

      klen1 = Keys1[k, "len"]
      klen2 = Keys2[l, "len"]
      scores[k, l] += (klen1 / rcount1 - klen2 / rcount2) ** 2
      
      for (m in Re) {
        kscore1 = Keys1[k, m]
        kscore2 = Keys2[l, m]
        scores[k, l] += (kscore1 / rcount1 - kscore2 / rcount2) ** 2
        if (debug) debug_print(3) }

      if (debug) debug_print(4) }}
  if (debug) print "--- end calc sim ---"
}
function debug_print(case) {
  if (case == 1) {
    print "New row: " NR, FNR, k1[1], k2[1], rcount1, rcount2
  } else if (case == 2) {
    if (position == 1 && FNR < 3 && matchcount!=10) print position, matches, Keys[position, m], m
    print "k1 " k1[position, 1], "k2 " k2[position, 1]
  } else if (case == 3) {
    print kscore1, kscore2
  } else if (case == 4) {
    print k, l, scores[k, l]
  } else if (case == "endbfsf1") {
    print "--- end bfs f1 ----"
  } else if (case == "endbfsf2") {
    print "--- end bfs f2 ----"
  } else if (case == 7) {
    print i, j, scores[i, j]
  }
}
