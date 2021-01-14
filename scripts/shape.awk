#!/usr/bin/awk
#
# Print the shape of text-based data
## TODO: optional setting - multiple shape charts for each field

BEGIN {
  if (!tty_size) tty_size = 100
  lineno_size = Max(length(lines), 5)
  output_space = tty_size - lineno_size - 2
  if (!span) span = 15
  if (measure) measure = SetMeasure(measure)
  else {
    if (FS == " ") measure = 0
    else measure = 1
  }
  if (FS == " ") FS = "[[:space:]]"
  measure_desc = measure ? "\""FS"\"" : "length"
  if (pattern) {
    pat_len = length(pattern)
    pat_len_mod = pat_len > 1 ? tty_size / pat_len : tty_size
    for (i = 1; i <= pat_len_mod; i++)
      pattern_string = pattern_string pattern }
  else
    for (i = 1; i <= tty_size; i++)
      pattern_string = pattern_string "+"
}

{
  if (NF > max_nf) max_nf = NF
  totalnf += NF
  i = NR % span
  m = Max(Measure(measure), 0)
  j += m
  if (m) match_lines++
  if (i == 0) {
    if (j > max_j) max_j = j
    _[NR/span] = j
    j = 0 }
}

END {
  if (i) {
    j = j / i * span
    if (j > max_j) max_j = j
    l = (NR - i + span) / span
    _[l] = j }
  if (!max_j) { print "Data not found with given parameters"; exit }
  avg_f = totalnf / NR
  len_ = length(_)
  print "lines: "NR
  print "lines with "measure_desc": "match_lines
  print "fields: "max_nf
  print "average fields: "avg_f
  if (!simple) {
    print "approx field var: "(max_nf-avg_f)**2
    printf "%"lineno_size"s ", "lineno"
    mod_j = max_j <= output_space ? 1 : output_space / max_j
    print "distribution of "measure_desc
    for (i = 1; i <= len_; i++) {
      printf " %"lineno_size"s ", i * span
      printf "%.*s\n", _[i] * mod_j, pattern_string }}
}

function SetMeasure(measure) {
  if ("length" ~ "^"measure) return 0
  else if ("fields" ~ "^"measure) return 1
}
function Measure(measure) {
  if (measure)
    { if (measure == 1) return NF - 1 }
  else return length($0)
}
function Max(a, b) {
  if (a > b) return a
  else if (a < b) return b
  else return a
}
function Min(a, b) {
  if (a > b) return b
  else if (a < b) return a
  else return a
}
