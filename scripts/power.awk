#!/usr/bin/awk
#
# Script to print characteristic combinations of values in
# field-separated data
#
# > awk -f power.awk file
#
# TODO: Link between fields and combination sets
# TODO: Refactor as set, not as left->right ordered combination (may not be
# feasible performance wise
# TODO: Add functionality to remove combinations intersecting with
# low-variance fields as these do not add more info - this would have to be
# done BEFORE or WHILE permorming exclusions relating to contained fields
# TODO: Generally distill combinations (maybe only output pairs at most, or
# even just single fields based on their interaction characteristic value?)

BEGIN {
  if (!min) min = 10
  min_floor = min - 1
  OFS = UnescapeOFS()
  len_ofs = length(OFS)
}

invert && NR == 1 && c_counts {
  for (i = 1; i <= 2^NF - 2; i++) {
    h_str = ""
    c_str = ""

    for (j = 1; j <= NF; j++)
      if (i % (2^j) < 2^(j-1)) {
        h_str = h_str $j OFS
        c_str = c_str j OFS }
    
    h_str = substr(h_str, 1, length(h_str) - len_ofs)
    c_str = substr(c_str, 1, length(c_str) - len_ofs)
    CPatterns[c_str] = 1
    CHeaders[c_str] = h_str }
}

{  
  if (debug && FNR < 3) DebugPrint(0)

  for (i = 1; i <= 2^NF-2; i++) {
    str = ""
    c_str = ""

    for (j = 1; j <= NF; j++)
      if (i%(2^j) < 2^(j-1)) {
        if ($j ~ "^[[:space:]]*$") continue
        str = str $j OFS
        if (debug && FNR < 3) DebugPrint(1)
        c_str = c_str j OFS }

    RC[c_str]++
    if (str ~ "^[[:space:]]*$" || RC[c_str] > 1) continue
    if (debug && FNR < 3) DebugPrint(0.5)

    if (c_counts) {
      c_str = substr(c_str, 1, length(c_str) - len_ofs)
      C[c_str ":::: " str]++ }
    else {
      str = substr(str, 1, length(str) - len_ofs)
      C[str]++ }}

  gsub(FS, OFS)
  C[$0]++
  delete RC
}

END {

  if (c_counts) {
    for (i in C) {
      j = C[i]
      if (C[i] < min) { 
        delete C[i]
        continue }
      c_pattern = substr(i, 1, match(i, ":::: ") - 1)
      if (invert) delete CHeaders[c_pattern]
      CCount[c_pattern] += j }

    if (!invert) {
      for (i in CHeaders)
        if (!(i in CCount)) delete CHeaders[i] }}

  else {
    if (debug) DebugPrint(1.5)
    for (i in C) {
      j = C[i]
      if (j < min) { 
        delete C[i]
        continue }
      N[j]++
      metakey = j OFS N[j]
      M[metakey] = i
      if (debug) DebugPrint(2) }

    for (i in N) {
      n_n = N[i]
      for (j = 1; j <= n_n; j++) {
        for (k = 1; k <= n_n; k++) {
          if (j == k) continue
          metakey1 = i OFS j
          metakey2 = i OFS k
          t1 = M[metakey1]
          t2 = M[metakey2]
          if (!(C[t1] && C[t2])) continue
          #if (debug) DebugPrint(3)
          split(t1, Tmp1, OFS)
          split(t2, Tmp2, OFS)
          matchcount = 0
          for (l in Tmp1) {
            for (m in Tmp2) {
              if (Tmp1[l] == Tmp2[m]) matchcount++ }}
          l1 = length(Tmp1)
          l2 = length(Tmp2)
          if (matchcount >= l1 || matchcount >= l2) {
            if (l1 > l2) {
              if (debug) DebugPrint(4)
              delete C[t2] }
            else if (l2 > l1) {
              if (debug) DebugPrint(5)
              delete C[t1]
            }}}}}}

  print ""

  if (c_counts) {
    if (invert)
      for (i in CHeaders) { print CHeaders[i] }
    else
      for (i in CCount) { print CCount[i]/NR, i }}
  else
    for (i in C) { if (C[i]) print C[i], i }
}

function UnescapeOFS() {
  split(OFS, OFSTokens, "\\")
  OFS = ""
  for (i = 1; i <= length(OFSTokens); i++)
    OFS = OFS OFSTokens[i]

  return OFS
}
function DebugPrint(case) {
  if (case == 0) {
    print "----------- NEW RECORD ------------"
    print $0
    printf "%5s%5s%7s%15s%15s  %s\n", "[i]", "[j]", "[2*j]", "[i % (2*j)]", "[2^(j-1)]", "[str]" }
  else if (case == 1) {
    printf "%5s%5s%7s%15s%15s  %s\n", i, j, 2*j, i % (2*j), 2^(j-1), str }
  else if (case == 0.5) {
    printf "%s\n\n", "SAVE COMBIN:  " str }
  else if (case == 1.5) {
    printf "%5s  %-80s%10s%10s  %-80s\n", "[j]", "[i]", "N[j]", "[metakey]", "M[metakey]" }
  else if (case == 2) {
    printf "%5s  %-80s%10s%10s  %-80s\n", j, i, N[j], metakey, M[metakey] }
  else if (case == 3) {
    print "------- COMBIN COMP --------"
    printf "%-12s%-10s%-10s%-10s%s\n", "[iOFSj] " j, metakey1, " [l1] " l1, " C[t1] " C[t1], " [t1] " t1
    printf "%-12s%-10s%-10s%-10s%s\n", "[iOFSk] " k, metakey2, " [l2] " l2, " C[t2] " C[t2], " [t2] " t2 }
  else if (case == 4) {
    print "<< delete [t2] "t2
    print ">> keep   [t1] "t1"\n" }
  else if (case == 5) {
    print "<< delete [t1] "t1
    print ">> keep   [t2] "t2"\n" }
}

