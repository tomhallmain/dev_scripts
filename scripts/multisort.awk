#!/usr/bin/awk
#
# Sort in two dimensions
#
## TODO: Length sort?

BEGIN {
  _OInit()
  if (type && "numeric" ~ "^"type) {
    n = 1
    n_re = "^[[:space:]]*\\$?[[:space:]]?-?\\$?([0-9]{,3},)*[0-9]*\\.?[0-9]+((E|e)(\\+|-)?[0-9]+)?"
    f_re = "^[[:space:]]*-?[0-9]\.[0-9]+(E|e)(\\+|-)?[0-9]+[[:space:]]*$" }

  desc = (order && "desc" ~ "^"order)
}

{
  for (f = 1; f <= NF; f++) {
    _[NR, f] = $f
    _R[NR] = NR
    _C[f] = f
    if (n) {
      n_str = GetN($f)
      if (n_str ~ n_re) {
        RN[NR] += n_str
        CN[f] += n_str
        AdvChars(NR, f, NExt[$f], n_end+1, RSums, CSums) }
      else
        AdvChars(NR, f, n_str, 1, RSums, CSums) }
    else
      AdvChars(NR, f, $f, 1, RSums, CSums) }

  if (NF > max_nf) max_nf = NF
}

END {
  if (!(NR && max_nf)) exit 1

  if (debug) print "----- CONTRACTING ROW VALS -----"
  ContractCharVals(NR, RSums, RCounts, RCCounts, RVals)
  if (debug) print "----- CONTRACTING COL VALS -----"
  ContractCharVals(max_nf, CSums, CCounts, CCCounts, CVals)

  if (n) {
    if (desc) {
      if (debug) print "----- SORTING ROW VALS -----"
      SDN(RN, RVals, _R, 1, NR)
      if (debug) print "----- SORTING COL VALS -----"
      SDN(CN, CVals, _C, 1, max_nf) }
    else {
      if (debug) print "----- SORTING ROW VALS -----"
      SAN(RN, RVals, _R, 1, NR)
      if (debug) print "----- SORTING COL VALS -----"
      SAN(CN, CVals, _C, 1, max_nf) }}
  else {
    if (desc) {
      if (debug) print "----- SORTING ROW VALS -----"
      SD(RVals, _R, 1, NR)
      if (debug) print "----- SORTING COL VALS -----"
      SD(CVals, _C, 1, max_nf) }
    else {
      if (debug) print "----- SORTING ROW VALS -----"
      SA(RVals, _R, 1, NR)
      if (debug) print "----- SORTING COL VALS -----"
      SA(CVals, _C, 1, max_nf) }}

  if (debug) {
    print "test tieback"
    for (i = 1; i <= length(_R); i++)
      print "_R["i"]="_R[i]
    print "test tieback"
    for (i = 1; i <= length(_C); i++)
      print "_C["i"]="_C[i]
    print "---- ORIGINAL HEAD ----"
    for (i = 1; i <= 10; i++) {
      if (i > NR) continue
      for (j = 1; j <= 10; j++) {
        if (j > max_nf) continue
        printf "%s", _[i, j] OFS}
      print "" }
    print "---- OUTPUT ----" }
  for (i = 1; i <= NR; i++) {
    for (j = 1; j <= max_nf; j++) {
      printf "%s", _[_R[i], _C[j]] OFS }
    print "" }
}

function AdvChars(row, field, str, start, R, C) {
  r_count = 0; c_count = 0
  len_chars = split($f, Chars, "") + start

  for (c = start; c < len_chars; c++) {
    char_val = O[Chars[c]]
    if (debug) print row, field, str, char_val
    R[row, c] += char_val; C[field, c] += char_val
    RCCounts[row, c]++;    CCCounts[field, c]++ }

  if (len_chars < 1) {
    RCCounts[row, c]++;    CCCounts[field, c]++ }

  if (len_chars > RCounts[row]) RCounts[row] = len_chars
  if (len_chars > CCounts[field]) CCounts[field] = len_chars 
  if (len_chars > max_len) max_len = len_chars
}
function ContractCharVals(max_base, SumsArr, BaseCounts, CharIdxCounts, ValsArr) {
  if (debug) printf "%7s%7s%15s%15s\n", "idx", "c_idx", "merge_char", "merge_char_val"
  for (i = 1; i <= max_base; i++) {
    base_count = BaseCounts[i]
    for (j = 1; j <= base_count; j++) {
      if (!(SumsArr[i, j] && CharIdxCounts[i, j]))
        continue
      merge_char_val = Round(SumsArr[i, j] / CharIdxCounts[i, j])
      merge_char = _O[merge_char_val]
      # TODO: lossy discrete case - see descending case with "b a c d\nd c e f\na b d f"
      if (!merge_char) merge_char = sprintf("%c", 255)
      if (debug) printf "%7s%7s%15s%15s\n", i, j, merge_char, merge_char_val
      ValsArr[i] = ValsArr[i] merge_char }}
}
function SA(A,TieBack,left,right,    i,last) {
  if (left >= right) return

  if (debug) print A[left], TieBack[left]
  S(A, TieBack, left, left + int((right-left+1)*rand()))
  if (debug) print A[left], TieBack[left]
  last = left

  for (i = left+1; i <= right; i++) {
    if (debug) print "ADVSORTI FOR LEFT: " left, A[left], i, A[i]
    if (A[i] < A[left]) {
      if (++last != i)
        S(A, TieBack, last, i) }}

  S(A, TieBack, left, last)
  SA(A, left, last-1)
  SA(A, last+1, right)
}
function SD(A,TieBack,left,right,    i,last) {
  if (left >= right) return

  S(A, TieBack, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++)
    if (A[i] > A[left]) {
      if (++last != i)
        S(A, TieBack, last, i) }

  S(A, TieBack, left, last)
  SD(A, left, last-1)
  SD(A, last+1, right)
}
function SAN(AN,A,TieBack,left,right,    i,last) {
  if (left >= right) return

  SN(AN, A, TieBack, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++) {
    if (AN[i] < AN[left])
      SN(AN, A, TieBack, ++last, i)
    else if (AN[i] == AN[left] && A[i] && A[left] && A[i] < A[left])
      SN(AN, A, TieBack, ++last, i) }

  SN(AN, A, TieBack, left, last)
  SAN(AN, A, left, last-1)
  SAN(AN, A, last+1, right)
}
function SDN(AN,A,TieBack,left,right,    i,last) {
  if (left >= right) return

  SN(AN, A, TieBack, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++) {
    if (AN[i] > AN[left])
      SN(AN, A, TieBack, ++last, i)
    else if (AN[i] == AN[left] && A[i] && A[left] && A[i] > A[left])
      SN(AN, A, TieBack, ++last, i) }

  SN(AN, A, TieBack, left, last)
  SDN(AN, A, left, last-1)
  SDN(AN, A, last+1, right)
}
function S(A,TieBack,i,j,   t) {
  if (debug) print "SWAP: " i, j, A[i], A[j], TieBack[i], TieBack[j]
  t = A[i]; A[i] = A[j]; A[j] = t
  t = TieBack[i]; TieBack[i] = TieBack[j]; TieBack[j] = t
}
function SN(AN,A,TieBack,i,j,   t) {
  t = AN[i]; AN[i] = AN[j]; AN[j] = t
  t = A[i]; A[i] = A[j]; A[j] = t
  t = TieBack[i]; TieBack[i] = TieBack[j]; TieBack[j] = t
}
function GetN(str) {
  if (NS[str])
    return NS[str]
  else if (match(str, n_re)) {
    n_end = RSTART + RLENGTH
    n_str = substr(str, RSTART, n_end)
    if (n_str != str) {
      NExt[str] = substr(str, n_end+1, length(str)) }
    n_str = sprintf("%f", n_str)
    gsub(/[^0-9\.Ee\+\-]+/, "", n_str)
    gsub(/^0*/, "", n_str)
    n_str = n_str + 0
    NS[str] = n_str
    return n_str }
  else
    return str
}
function _OInit(    low, high, i, t) {
    low = sprintf("%c", 7) # BEL is ascii 7
    if (low == "\a") {     # regular ascii
        low = 0
        high = 127 }
    else if (sprintf("%c", 128 + 7) == "\a") {
      low = 128            # ascii, mark parity
      high = 255 }
    else {                 # ebcdic(!)
      low = 0
      high = 255 }

    for (i = low; i <= high; i++) {
      t = sprintf("%c", i)
      O[t] = i
      _O[i] = t }
}
function Round(val) {
  int_val = int(val)
  if (val - int_val >= 0.5)
    return int_val++
  else
    return int_val
}
