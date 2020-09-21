#!/usr/bin/awk
#
# Print fields containing a field separator as one field as long as they are
# surrounded by single or double quotes
#
# > awk -f quoted_fields.awk

BEGIN {
  sq = "'"
  dq = "\""
  lenfs = length(FS)

  sqre = "(^|" FS ")" sq ".*" sq "(" FS "|$)"
  dqre = "(^|" FS ")" dq ".+" dq "(" FS "|$)"
  na = (FS == "" || FS ~ sq || FS ~ dq)
}

na || !($0 ~ FS) { print; next }

{
  init = 1; nf = 0
  if (!dqset) { dqset = ($0 ~ dqre)
    if (dqset) { q = dq; qq = "\"\""
      qfs = q FS; qqfs = q q FS }}
  if (!dqset && !sqset) { sqset = ($0 ~ sqre)
    if (sqsiet) { q = sq; qq = "\'\'"
      qfs = q FS; qqfs = q q FS }}

  if (dqset) {
    for (i = 1; i < 1000; i++) {
      len0 = length($0)
      if (len0 < 1) break
      nf++
      iqfs = index($0, qfs)
      while (substr($0, iqfs-1, 1) == q && substr($0, iqfs-2, 1) != q) {
        iqfs += index(substr($0, iqfs + lenfs, len0), qfs) }
      ifs = index($0, FS)
      iq = index($0, q)
      q_cut = 0

      if (debug) {
        previ = i - 1
        if (_[previ]) pi = _[previ]
        debugPrint(1) }

      if (init) {
        init = 0
        if (iq == 1 && iqfs) {
          startf = 2; endf = iqfs - 2
          q_cut = 2 }
        else {
          startf = 1; endf = ifs - 1 }}
      else if (!qset) {
        if (iq == 0 && ifs == 0) {
          startf = 1; endf = len0 }
        else if (ifs == 0) {
          startf = lenfs + 1; endf = len0 - 1 }
        else if (iq - ifs == 1) {
          if (iqfs || index(substr($0,2),q) == len0) {
            qset = 1
            startf = 1; endf = ifs - 1 }
          else {
            startf = 2 + lenfs; endf = len0 - 1 }}
        else if (iq == 0) {
          startf = 1; endf = ifs - 1 }
        else if (iq - ifs > 1 || ifs - iq > 1) {
          startf = 1; endf = ifs - 1 }
        else {
          startf = 1; endf = ifs - 1 }}
      else if (qset) {
        qset = 0; q_cut = 2
        startf = lenfs + 1; endf = iqfs - 2 }

      _[i] = substr($0, startf, endf)
      gsub(qq, q, _[i])
      $0 = substr($0, endf + lenfs + q_cut + 1)
      if (debug) debugPrint(2) }}
  else {
    nf = NF
    for (i = 1; i <= NF; i++) _[i] = $i }

  for (i = 1; i < nf; i++)
    printf "%s", _[i] OFS

  print _[nf]
}

function debugPrint(case) {
  if (case == 1 ) {
    print i, qset, len0, $0
    print "previ:" pi
    print "ifs: " ifs, "iq: " iq, "iqfs: " iqfs
  } else if (case == 2) {
    print "substr($0, " startf ", " endf ")"
    print _[i]
    print ""
  }
}

