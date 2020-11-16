#!/usr/bin/awk
#
# Script to infer if headers are present in the first row of a file
#
#


BEGIN {
  # is integer
  Re["i"] = "^[0-9]+$"
  # is decimal
  Re["d"] = "^[0-9]+\.[0-9]+$"
  # is alpha
  Re["a"] = "[A-z]+"
  # is uppercase letters
  Re["u"] = "^[A-Z]+$"
  # has integer
  Re["hi"] = "[0-9]+"
  # has decimal
  Re["hd"] = "[0-9]+\.[0-9]+"
  # has alpha
  Re["ha"] = "[A-z]+"
  # has uppercase letters
  Re["hu"] = "[A-Z]+"
  # does not have lowercase letters
  Re["nl"] = "^[^a-z]+$"
  # words with spaces
  Re["w"] = "[A-z ]+"
  # no spaces
  Re["ns"] = "^[^[:space:]]$"
  # the string ` id ` appears in any casing
  Re["id"] = "(^|_| |\-)?[Ii][Dd](\-|_| |$)"
  # date1
  Re["d1"] = "^[0-9]{1,2}[\-\.\/][0-9]{1,2}[\-\.\/]([0-9]{2}|[0-9]{4})$"
  # date2
  Re["d2"] = "^[0-9]{4}[\-\.\/][0-9]{1,2}[\-\.\/][0-9]{1,2}$"
  # link
  Re["l"] = ":\/\/"
  # json
  Re["j"] = "^\{[,:\"\'{}\[\]A-z0-9.\-+ \n\r\t]{2,}\}$"
  # html/xml

  NonHeaderRe = " i d d1 d2 l j "
  HeaderRe = " a u w id "

  max_rows = 100
  potential_header_rows = 1
  control_rows = max_rows - potential_header_rows
  if (!trim) trim = "true"
}

NR == 1 {
  if (NF < 2) headerScore -= 100

  # Evaluate first row field values
  for (i = 1; i <= NF; i++) {
    field = TrimField($i)
    BuildFirstRowScore(field, i) }

  next
}

NR <= max_rows {
  for (i = 1; i <= NF; i++) {
    field = TrimField($i)
    BuildControlRowScore(field, i) }
}

END {
  if (NR < max_rows) {
    max_rows = NR
    control_rows = max_rows - potential_header_rows }

  CalcSims(FirstRow, ControlRows)
  
  if (debug) print headerScore
  if (headerScore > 0)
    exit 0
  else
    exit 1
}

function TrimField(field) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
  return field
}
function BuildFirstRowScore(field, position) {
  FirstRow[position, "len"] = length(field)
  for (m in Re) {
    re = Re[m]
    if (field ~ re) {
      FirstRow[position, m] = 1
      if (NonHeaderRe ~ " " m " ") headerScore -= 100
      if (HeaderRe ~ " " m " ") headerScore += 30
      if (debug && NR < 3) print NR, position, m, field, headerScore }}
}
function BuildControlRowScore(field, position) {
  headerScore += sqrt((FirstRow[position, "len"] - length(field))**2) / control_rows
  for (m in Re) {
    if (field ~ Re[m]) {
      ControlRow[position, m] += 1
      if (debug && NR < 3) print NR, position, m, field, headerScore }}
}
function CalcSims(first, control) {
  if (debug) print "--- start calc sim ---"
  for (i = 1; i <= NF; i++) {
    for (m in Re) {
      first_score = first[i, m]
      ctrl_score = control[i, m]
      headerScore += sqrt((first_score - ctrl_score / control_rows)**2)
      if (debug) print i, m, first_score, ctrl_score/control_rows, headerScore }}
  if (debug) print "--- end calc sim ---"
}
