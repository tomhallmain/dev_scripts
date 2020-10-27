#!/usr/bin/awk
#
# Print fields containing a field separator as one field as long as they are
# surrounded by single or double quotes
#
# Example execution:
# > awk -v FS="," -f quoted_fields.awk file.csv
## TODO: Carriage return character handling


BEGIN {
  sq = "'"
  dq = "\""
  na = (FS == "" || FS ~ sq || FS ~ dq)

  if (!na) {
    if (FS == " ") FS = "[[:space:]]+"
    if (fixed_space) FS = " "
    lenfs = length(FS)

    if (!("          " ~ "^"FS"$")) {
      sp = "[[:space:]]*"
      init_sp = "^" sp }
    dqre = "(^|[^"dq"]*[^"FS"]*[^"dq"]+"FS")"sp dq
    sqre = "(^|[^"sq"]*[^"FS"]*[^"sq"]+"FS")"sp sq

    q_cut_len = retain_outer_quotes ? 0 : 2
    mod_f_len1 = retain_outer_quotes ? 1 : 2
    mod_f_len0 = retain_outer_quotes ? 0 : 1
    if (debug) DebugPrint(0) }
}

na || (!q_rebal && !($0 ~ FS)) { print; next }

q_rebal && !($0 ~ QRe["e"]) {
  if (debug) DebugPrint(6)
  _[save_i] = _[save_i] " \\n " $0
  next
}

{
  diff = 0; iq_imbal_s = 0; iq_imbal_e = 0; close_multiline_field = 0
  if (!dqset) {
    dqset = ($0 ~ dqre)
    if (dqset) { q = dq; qre = dqre; init_q = 1 }}
  if (!dqset && !sqset) {
    sqset = ($0 ~ sqre)
    if (sqset) { q = sq; qre = sqre; init_q = 1 }}
  if (init_q) {
    init_q = 0
    run_prefield = 1
    qq = q q
    qfs = q sp FS; qqfs = qq sp FS; fsq = FS sp q
    BuildRe(QRe, FS, q, sp)
    qq_replace = retain_outer_quotes ? qq : q }

  if (debug) DebugPrint(3)

  if (q_rebal) {
    if (debug) DebugPrint(4)
    save_bal = balance_os
    diff = QBalance($0, QRe, q_rebal) 
    balance_os += diff
    if (debug && save_bal != balance_os)
      DebugPrint(5)
    if (diff && balance_os == 0) {
      q_rebal = 0; close_multiline_field = 1 }}
  else if (run_prefield) {
    balance_os = QBalance($0, QRe)
    save_i = 1 }

  if (debug && q_rebal) print "carried q"
  if (balance_os) {
    if (debug) print "Unbalanced"
    q_rebal = 1 }

  if (run_prefield && (q_rebal || $0 ~ q)) {
    i_seed = diff && save_i ? save_i : 1
    for (i = i_seed; i < 500; i++) {
      gsub(qq, "_qqqq_", $0)
      gsub(init_sp, "", $0)
      len0 = length($0)
      if (len0 < 1) break
      match($0, qfs); iqfs = RSTART; len_iqfs = RLENGTH
      while (substr($0, iqfs-1, 1) == q && substr($0, iqfs-2, 1) != q) {
        match(substr($0, iqfse, len0), qfs)
        iqfs = RSTART; len_iqfs = RLENGTH }

      if (close_multiline_field) {
        match($0, QRe["e_imbal"])
        startf = 1; endf = RLENGTH - mod_f_len0
        q_cut = mod_f_len0 }
      else {
        match($0, fsq); ifsq = RSTART; len_ifsq = RLENGTH
        match($0, FS); ifs = RSTART; lenfs = Max(RLENGTH, 1)
        iq = index($0, q)
        iqq = index($0, "_qqqq_")
        if (balance_os) {
          match($0, QRe["s_imbal"]); iq_imbal_s = RSTART
          match($0, QRe["sep_exc"]); inqfs = RSTART }
        if (iq == 1 && !(iqq == 1)) qset = 1
        q_cut = 0

        if (debug) {
          previ = i - 1
          if (_[previ]) pi = _[previ]
          DebugPrint(1) }

        if (qset) {
          qset = 0; q_cut = q_cut_len
          startf = balance_os ? mod_f_len1 : lenfs + mod_f_len0
          endf = iqfs - q_cut_len
          if (endf < 1) {
            if (iq != 1 && !balance_os) startf++
            endf = len0 - q_cut_len }}
        else {
          if (iq == 0 && ifs == 0) {
            startf = 1; endf = len0 }
          else if (iq_imbal_s > 0 && iq_imbal_s <= inqfs \
                  && iq_imbal_s < iq && iq_imbal_s < ifs) {
            if (retain_outer_quotes) {
              startf = iq_bal; endf = len0 }
            else {
              startf = iq_bal + 1; endf = len0 - 1 }}
          else if (iq == iqq && (iqfs - 1 == iq || ifs == 0)) {
            if (retain_outer_quotes) {
              startf = iq; endf = iq + 2 }
            else {
              startf = iq + 1; endf = iq + 1 }}
          else if ((iqfs > 0 || substr($0,len0) == q) && ifsq == ifs) {
            startf = 1; endf = ifsq - 1
            qset = 1 }
          else if (ifs == 0) {
            startf = lenfs + 1; endf = len0 - 1 }
          else if (iq - ifs == 1) {
            if (iqfs || index(substr($0,2),q) == len0) {
              qset = 1
              startf = 1; endf = ifs - mod_f_len1 }
            else {
              startf = lenfs; endf = ifs - mod_f_len0 }}
          else if (iq == 0) {
            startf = 1; endf = ifs - 1 }
          else if (iq - ifs > 1 || ifs - iq > 1) {
            startf = 1; endf = ifs - 1 }
          else {
            startf = 1; endf = ifs - 1 }}}

      f_part = substr($0, startf, endf)
      _[i] = close_multiline_field ? _[i] f_part : f_part
      gsub("_qqqq_", qq_replace, _[i])
      $0 = substr($0, endf + lenfs + q_cut + 1)
      if (debug) DebugPrint(2)
      close_multiline_field = 0 }}
  else {
    for (i = 1; i <= NF; i++) _[i] = $i }

  if (balance_os) {
    q_rebal = 1
    save_i = i - 1
    next }

  len_ = length(_)
  for (i = 1; i < len_; i++) {
    printf "%s", _[i] OFS
    delete _[i] }

  print _[len_]; delete _[len_]; delete prev_i
}

function BuildRe(ReArr, sep, q, sp) {
  ReArr["exc"] = "[^"q"]*[^"sep"]*[^"q"]+"
  ReArr["sep_exc"] = "[^"q sep"]+"
  ReArr["l"] = "(^|"sep")"sp q
  ReArr["r"] = q sp"("sep"|$)"
  ReArr["f"] = ReArr["l"] ReArr["exc"] ReArr["r"]
  ReArr["s"] = "(^|"sep")"sp q sp"("qq"[^"q"]|[^"q"]|$)"
  ReArr["e"] = "(^|[^"q"]|[^"q"]"qq")"sp q sp"("sep"|$)"
  ReArr["s_imbal"] = "^"sp q ReArr["exc"]"$"
  ReArr["e_imbal"] = "^[^"q sep"]*[^"q"]*" q
}
function QBalance(line, QRe, qset) {
  tmp_starts = line
  tmp_ends = line
  n_starts = gsub(QRe["s"], "", tmp_starts)
  n_ends = gsub(QRe["e"], "", tmp_ends)
  if (debug) print "n_starts: "n_starts", n_ends: "n_ends
  base_diff = n_starts - n_ends
  bal = n_starts > 0 ? base_diff - qset : base_diff
  return bal
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
    print "---- CALCS / OUTPUT ----" }
  else if (case == 1 ) {
    print "----- CALCS FIELD "i" ------"
    print "NR: "NR" qset: " qset " len0: " len0 " $0: " $0
    print "previ: " pi
    print "ifs: "ifs" iq: "iq" iqfs: "iqfs" ifsq: "ifsq" iqq: "iqq 
    if (balance_os) print "balance os: "balance_os", iq_imbal_s: "iq_imbal_s }
  else if (case == 2) {
    print "_["i"] = substr($0, "startf", "endf")"
    print "$0 = substr($0, "endf" + "lenfs" + "q_cut" + 1)"
    print "----- OUTPUT FIELD "i" -----"
    print _[i]
    print "" }
  else if (case == 3) {
    print ""
    print "NR: "NR", $0: "$0
    print "match_start: "match($0, QRe["s"])", RLENGTH: "RLENGTH" QRe[\"s\"]"QRe["s"]
    print "match_field: "match($0, QRe["f"])", RLENGTH: "RLENGTH" QRe[\"f\"]"QRe["f"] }
  else if (case == 4)
    print "bal: "balance_os
  else if (case == 5)
    print "newbal: "balance_os
  else if (case == 6)
    print "NR: "NR", save_i: "save_i", _[save_i]: "_[save_i]
}

