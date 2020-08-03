#!/usr/bin/awk
#
# Script to infer a probable set of join fields between two linear data files.
#
# With a field separator common to both files (for example comma) run as:
# > awk -f infer_join_fields.awk -F"," file1 file2
#
# With a field separator unique to each file, run as:
# > awk -f infer_join_fields.awk -v fs1="," -v fs2 =":" file1 file2

function trimField(field) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
  return field
}

function buildFieldScore(field, position, Keys) {
  Keys[position, "len"] += length(field)
  for (m in Re) {
    re = Re[m]
    matches = field ~ re
    if (matches > 0) {
      Keys[position, m] += 1; matchcount++
    }
  }
  if (position == 1 && FNR < 3 &&  matchcount!=10) print position, matches, Keys[position, m], m
  if (debug) print "k1 " k1[position, 1], "k2 " k2[position, 1]
}

function calcSims(Keys1, Keys2) {
  for (k = 1; k <= max_nf1; k++) {
    for (l = 1; l <= max_nf2; l++) {
      
      kscore1 = Keys1[k, l]
      kscore2 = Keys2[l, k]
      scores[k, l] += ((kscore1 + kscore2) / (rcount1 + rcount2)) ** 2
      
      klen1 = Keys1[k, "len"]
      klen2 = Keys2[l, "len"]
      scores[k, l] += (klen1 / rcount1 - klen2 / rcount2) ** 2
      
      for (m in Re) {
        kscore1 = Keys1[k, m]
        kscore2 = Keys2[l, m]
        scores[k, l] += (kscore1 / rcount1 - kscore2 / rcount2) ** 2
        if (debug) print kscore1, kscore2
      }

      if (debug) print k, l, scores[k, l]
    }
  }
  if (debug) print "--- end calc sim ---"
}

BEGIN {
  # is integer
  Re["i"] = "^[0-9]+$"
  # has integer
  Re["hi"] = "[0-9]+"
  # is decimal
  Re["d"] = "^[0-9]+\.[0-9]+$"
  # has decimal
  Re["hd"] = "[0-9]+\.[0-9]+"
  # is alpha
  Re["a"] = "[A-z]+"
  # has alpha
  Re["ha"] = "[A-z]+"
  # is uppercase letters
  Re["u"] = "^[A-Z]+$"
  # has uppercase letters
  Re["hu"] = "[A-Z]+"
  # does not have lowercase letters
  Re["nl"] = "^[^a-z]+$"
  # words with spaces
  Re["w"] = "[\w ]+"
  # no spaces
  Re["ns"] = "^[^[:space:]]$"
  # the string ` id ` appears in any casing
  Re["id"] = "(^|_| |\-)[Ii][Dd](\-|_| |$)"
  # date1
  Re["d1"] = "^\d{1,2}[\.\-\/]\d{1,2}[\.\-\/](\d{2}|\d{4})$"
  # date2
  Re["d2"] = "^\d{4}[\.\-\/]\d{1,2}[\.\-\/]\d{1,2}$"
  # link
  Re["l"] = ":\/\/"
  # json
  Re["j"] = "^\{[,:\"\'{}\[\]A-z0-9.\-+ \n\r\t]{2,}\}$"
  # html/xml
  #Re["h"] = "\<\/?\w+((\s+[\w-]+(\s*=\s*(?:\".*?\"|\'.*?\'|[\^\'\">\s]+))?)+\s*|\s*)?\>?"

  if (!fs1) fs1 = FS
  if (!fs2) fs2 = FS

  max_rows = 100 # This number will be squared and multiplied by NF for each file
  trim = "true"
  FS = fs2
}

debug { print "NEW ROW " NR, FNR, k1[1], k2[1], rcount1, rcount2 }

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
        if (trim) h1 = trimField(h1) 
        if (trim) h2 = trimField(h2)
        if (h1 != h2) { # Give strong advantage to matching headers
          k1[i, j] += 1000 * rcount1
          k2[j, i] += 1000 * rcount1
        }
        if ((h1 ~ h2) < 1) { # Is one header is contained inside the other?
          k1[i, j] += 100 * rcount1
          k2[j, i] += 100 * rcount1
        }
        if ((h1 ~ Re["id"]) < 1 && (h2 ~ Re["id"]) < 1) { # ID headers should have advantage
          k1[i, j] += 1000 * rcount1
          k2[j, i] += 1000 * rcount1
        }
      }
    }
    next
  }

  nf1 = split($0, fr2, fs2)
  
  for (fr in s1) {
    nf2 = split(fr, fr1, fs1)
    
    for (i in fr1) {
      f1 = fr1[i]
      if (trim) f1 = trimField(f1)
      buildFieldScore(f1, i, k1)
      if (debug) print "--- end bfs f1 ----"
      
      for (j in fr2) {
        f2 = fr2[j]
        if (trim) f2 = trimField(f2)
        buildFieldScore(f2, j, k2)
        if (debug) print "--- end bfs f2 ----"
        
        if (f1 != f2) {
          k1[i, j] += 100
          k2[j, i] += 100
        }
        if ((f1 ~ Re["d"]) > 0 || (f2 ~ Re["d"]) > 0) { # trying this constraint out
          if (NR < 5) print "test"
          k1[i, j] += 1000 * rcount1
          k2[j, i] += 1000 * rcount1
        }
      }
    }
  }

  if (nf1 > max_nf1) max_nf1 = nf1
  if (nf2 > max_nf2) max_nf2 = nf2
  rcount2++
}

END {
  calcSims(k1, k2)

  for (i = 1; i <= max_nf1; i++) {
    for (j = 1; j <= max_nf2; j++) {
      print i, j, scores[i, j]
    }
  }

  if (debug) {
    for (i in k1) {
      print i
    }
  }
}

function debug_print(case) {
  if (case == 1) {
    
  } else if 
}
