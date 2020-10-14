#!/usr/bin/awk
#
# Print fields containing a field separator as one field as long as they are
# surrounded by single or double quotes
#
# Example execution:
# > awk -v FS="," -f quoted_fields.awk file.csv

BEGIN {
  sq = "'"
  dq = "\""
  lenfs = length(FS)

  sqre = "(^|" FS ")" sq ".*" sq "(" FS "|$)"
  dqre = "(^|" FS ")" dq ".+" dq "(" FS "|$)"
  na = (FS == "" || FS ~ sq || FS ~ dq)
  q_cut_len = retain_outer_quotes ? 0 : 2
  mod_f_len1 = retain_outer_quotes ? 1 : 2
  mod_f_len0 = retain_outer_quotes ? 0 : 1
  if (debug) DebugPrint(0)
}

na || !($0 ~ FS) { print; next }

{
  init = 1; nf = 0
  if (!dqset) { dqset = ($0 ~ dqre)
    if (dqset) { q = dq; qq = "\"\""
      qq_replace = retain_outer_quotes ? qq : q
      qfs = q FS; qqfs = q q FS; fsq = FS q 
      run_pf = 1; qre = dqre }}
  if (!dqset && !sqset) { sqset = ($0 ~ sqre)
    if (sqset) { q = sq; qq = "\'\'"
      qq_replace = retain_outer_quotes ? qq : q
      qfs = q FS; qqfs = q q FS; fsq = FS q
      run_pf = 1; qre = sqre }}

  if (run_pf && $0 ~ qre) {
    for (i = 1; i < 500; i++) {
      gsub(qq, "_qqqq_", $0)
      len0 = length($0)
      if (len0 < 1) break
      nf++
      match($0, qfs); iqfs = RSTART
      while (substr($0, iqfs-1, 1) == q && substr($0, iqfs-2, 1) != q) {
        match(substr($0, iqfse, len0), qfs)
        iqfs = RSTART }
      match($0, fsq); ifsq = RSTART
      match($0, FS); ifs = RSTART; lenfs = Max(RLENGTH, 0)
      iq = index($0, q)
      iqq = index($0, "_qqqq_")
      if (iq == 1 && !(iqq == 1)) qset = 1
      q_cut = 0

      if (debug) {
        previ = i - 1
        if (_[previ]) pi = _[previ]
        DebugPrint(1) }

      if (qset) {
        qset = 0; q_cut = q_cut_len
        startf = lenfs + mod_f_len0
        endf = iqfs - q_cut_len
        if (endf < 1) endf = len0 - 1 - mod_f_len0 }
      else {
        if (iq == 0 && ifs == 0) {
          startf = 1; endf = len0 }
        else if ((iqfs > 0 || substr($0,len0) == q) && ifsq == ifs) {
          startf = 1; endf = ifsq - 1
          qset = 1}#; q_cut = q_cut_len }
        else if (ifs == 0) {
          startf = lenfs + 1; endf = len0 - 1 }
        else if (iq - ifs == 1) {
          if (iqfs || index(substr($0,2),q) == len0) {
            qset = 1
            startf = 1; endf = ifs - mod_f_len1 }
          else {
            startf = lenfs; endf = len0 - mod_f_len1 }}
        else if (iq == 0) {
          startf = 1; endf = ifs - 1 }
        else if (iq - ifs > 1 || ifs - iq > 1) {
          startf = 1; endf = ifs - 1 }
        else {
          startf = 1; endf = ifs - 1 }}

      _[i] = substr($0, startf, endf)
      gsub("_qqqq_", qq_replace, _[i])
      $0 = substr($0, endf + lenfs + q_cut + 1)
      if (debug) DebugPrint(2) }}
  else {
    nf = NF
    for (i = 1; i <= NF; i++) _[i] = $i }

  for (i = 1; i < nf; i++)
    printf "%s", _[i] OFS

  print _[nf]
}

function Max(a, b) {
  if (a > b) return a
  else if (a < b) return b
  else return a
}
function DebugPrint(case) {
  if (case == 0) {
    print "-------- SETUP --------"
    print "retain_outer_quotes: "retain_outer_quotes" q_cut_len: "q_cut_len" mod_f_len0: "mod_f_len0" mod_f_len1: "mod_f_len1
    print "---- CALCS / OUTPUT ----"
  } else if (case == 1 ) {
    print "----- CALCS FIELD "i" ------"
    print "NR: "NR" qset: " qset " len0: " len0 " $0: " $0
    print "previ: " pi
    print "ifs: "ifs" iq: "iq" iqfs: "iqfs" ifsq: "ifsq" iqq: "iqq
  } else if (case == 2) {
    print "_["i"] = substr($0, " startf ", " endf ")"
    print "$0 = substr($0, "endf" + "lenfs" + "q_cut" + 1)"
    print "----- OUTPUT FIELD "i" -----"
    print _[i]
    print ""
  }
}

