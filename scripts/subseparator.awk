#!/usr/bin/awk
#
# Separates a text file by an implied pattern given in addition to existing field 
# separators, effectively creating new fields for each subfield identified.
#
# Running:
# > awk -f subseparator.awk -v subsep_pattern=" " file file


BEGIN {
  if (!subsep_pattern) {
    print "Variable subsep pattern must be set"
    exit 1 }
  if (length(nomatch_handler) == 0) {
    nomatch_handler = "[[:space:]]+"
    if (debug) print "splitting lines on "FS" then on "subsep_pattern" with whitespace tiebreaker" }
  else {
    if (debug) print "splitting lines on "FS" then on "subsep_pattern" with tiebreaker "nomatch_handler 
    if (escape) nomatch_handler = escaped(nomatch_handler) }
  if (escape) subsep_pattern = escaped(subsep_pattern)
  if (apply_to_fields) {
    split(apply_to_fields, Fields, ",")
    len_af = length(Fields) 
    for (f = 1; f <= len_af; f++) {
      af = Fields[f]
      if (!(af ~ "^[0-9]+$")) continue
      RelevantFields[af] = 1 }
    if (length(RelevantFields) < 1) exit 1 }
}

NR == FNR {
  if (apply_to_fields) {
    for (f in RelevantFields) {
      num_subseps = split($f, SubseparatedLine, subsep_pattern)
      if (num_subseps > 1 && num_subseps > max_subseps[f]) {
        max_subseps[f] = num_subseps
        for (j = 1; j <= num_subseps; j++) {
          if (!trim(SubseparatedLine[j])) {
            subfield_shift[f]--  }}}}}
  else {
    for (f = 1; f <= NF; f++) {
      num_subseps = split($f, SubseparatedLine, subsep_pattern)
      if (num_subseps > 1 && num_subseps > max_subseps[f]) {
        max_subseps[f] = num_subseps
        for (j = 1; j <= num_subseps; j++) {
          if (!trim(subseparated_line[j])) {
            subfield_shift[f]--  }}}}}
}

NR > FNR {
  for (f = 1; f <= NF; f++) {
    last_field = f == NF
    conditional_ofs = (last_field ? "" : OFS)
    shift = subfield_shift[f]
    n_outer_subfields = max_subseps[f] + shift
    subfield_partitions = n_outer_subfields * 2 - 1 - shift
    if (subfield_partitions > 0) {
      if (debug) debug_print(1)
      num_subseps = split($f, SubseparatedLine, subsep_pattern)
      k = 0
      for (j = 1; j <= subfield_partitions; j++) {
        if (last_field && j == subfield_partitions) conditional_ofs = ""
        outer_subfield = j % 2 + shift
        if (outer_subfield) k++
        if (debug && (retain_pattern || outer_subfield)) debug_print(2)
        if (num_subseps < n_outer_subfields - shift) {
          split($f, HandlingLine, nomatch_handler)
          if (outer_subfield)
            printf trim(HandlingLine[k]) conditional_ofs
          else if (retain_pattern)
            printf conditional_ofs }
        else {
          if (outer_subfield)
            printf trim(SubseparatedLine[k]) conditional_ofs
          else if (retain_pattern)
            printf unescaped(subsep_pattern) OFS }}}
    else
      printf trim($f) conditional_ofs }

  print ""
}


function trim(string) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", string)
  return string
}
function escaped(string) {
  gsub(/[\\.^$(){}\[\]|*+?]/, "\\\\&", string)
  return string
}
function unescaped(string) {
  gsub("\\", "", string)
  return string
}
function debug_print(case) {
  if (case == 1) {
    print "FNR: "FNR" f: "f" shift: "shift" nos: "n_outer_subfields" sf_part: "subfield_partitions" cofs: "conditional_ofs }
  else if (case == 2) {
    print "FNR: "FNR" f: "f" shift: "shift" nos: "n_outer_subfields" sf_part: "subfield_partitions" cofs: "conditional_ofs" osf: "outer_subfield" k: "k }
}
