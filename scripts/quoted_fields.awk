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
  split(FS, fs, "")
  for (i = 1; i <= length(fs); i++)
    if (!(fs[i] == "\\"))
      EFS = EFS "\\" fs[i]

  exs = "[^" EFS sq "]*"
  exd = "[^" EFS dq "]*"

  sqre = "(^|" FS ")" sq "(" exs FS ")+" exs sq "(" FS "|$)"
  dqre = "(^|" FS ")" dq "(" exd FS ")+" exd dq "(" FS "|$)"
  na = (FS == "" || FS ~ sq || FS ~ dq)
}

na || !($0 ~ FS) { print; next }

{
  init = 1; nf = 0
  if (!dqset) {
    dqset = ($0 ~ dqre)
    if (dqset) q = dq }
  if (!dqset && !sqset) { 
    sqset = ($0 ~ sqre)
    if (sqset) q = sq }

  for (i = 1; i < 1000; i++) {
    len0 = length($0)
    if (len0 < 1) break
    nf++
    ifs = index($0, FS)
    iq = index($0, q)
    q_cut = 0

    previ = i - 1
    if (_[NR, previ]) pi = _[NR, previ]
    if (debug) debugPrint(1)

    if (init) {
      init = 0
      print q, index(substr($0,2),q)
      if (iq == 1 && index(substr($0,2),q) >= ifs) {
        startf = 2
        endf = index($0, q FS) - 2
      } else {
        startf = 1
        endf = ifs - 1
      }
    } else if (!qset) {
      if (iq - ifs == 1) {
        if (index($0, q FS) || index(substr($0,2),q) == len0) {
          qset = 1
          startf = 1
          endf = ifs - 1
        } else {
          startf = 2 + lenfs
          endf = len0 - 1
        }
      } else if (iq == 0 && ifs == 0) {
        startf = 1
        endf = len0
      } else if (ifs == 0) {
        startf = lenfs + 1
        endf = len0 - 1
      } else if (iq == 0) {
        startf = 1
        endf = ifs - 1
      } else if (iq - ifs > 1 || ifs - iq > 1) {
        startf = 1
        endf = ifs - 1
      } else {
        startf = 1
        endf = ifs - 1
      }
    } else if (qset) {
      qset = 0
      startf = lenfs + 1
      q_cut = 2
      endf = index($0, q FS) - 2
    }

    _[NR, i] = substr($0, startf, endf)
    $0 = substr($0, endf + lenfs + q_cut + 1)
    if (debug) debugPrint(2)
  }
  
  for (i = 1; i < nf; i++)
    printf "%s", _[NR, i] OFS

  print _[NR, nf]
}

function debugPrint(case) {
  if (case == 1 ) {
    print i, qset, len0, $0
    print "previ:" pi
    print "ifs: " ifs, "iq: " iq
  } else if (case == 2) {
    print "substr($0, " startf ", " endf ")"
    print _[NR, i]
    print ""
  }
}

