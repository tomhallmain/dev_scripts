#!/usr/bin/awk
#
# Separates a text file by an implied pattern given in addition 
# to existing field separators, effectively creating new fields
# for each subfield identified.
#
# Running:
# > awk -f subseparator.awk -v subsep_pattern=" " file


BEGIN {
  if (!subsep_pattern) {
    print "Variable subsep pattern must be set"
    exit 1
  }
  if (length(nomatch_handler) == 0) {
    nomatch_handler = "[[:space:]]+"
    if (debug) print "splitting lines on " FS " then on " subsep_pattern " with whitespace tiebreaker"
  } else {
    if (debug) print "splitting lines on " FS " then on " subsep_pattern " with tiebreaker " nomatch_handler 
    if (escape) nomatch_handler = escaped(nomatch_handler)
  }
  if (escape) subsep_pattern = escaped(subsep_pattern)
  print ""
}


NR == FNR {
  for (i = 1; i <= NF; i++) {
    num_subseps = split($i, subseparated_line, subsep_pattern)
    if (num_subseps > 1 && num_subseps > max_subseps[i]) {
      max_subseps[i] = num_subseps
      for (j = 1; j <= num_subseps; j++) {
        if (!trim(subseparated_line[j])) {
          subfield_shift[i]--
        }
      }
    }
  }
}


NR > FNR {
  for (i = 1; i <= NF; i++) {
    last_field = i == NF
    conditional_ofs = (last_field ? "" : OFS)
    shift = subfield_shift[i]
    n_outer_subfields = max_subseps[i] + shift
    subfield_partitions = n_outer_subfields * 2 - 1 - shift
    if (debug) debug_print(1)
    if (subfield_partitions > 0) {
      num_subseps = split($i, subseparated_line, subsep_pattern)
      k = 0
      for (j = 1; j <= subfield_partitions; j++) {
        if (last_field && j == subfield_partitions) conditional_ofs = ""
        outer_subfield = j % 2 + shift
        if (outer_subfield) k++
        if (debug) debug_print(2)
        if (num_subseps < n_outer_subfields - shift) {
          split($i, handling_line, nomatch_handler)
          if (outer_subfield) {
            printf trim(handling_line[k]) conditional_ofs
          } else {
            printf conditional_ofs
          }
        } else {
          if (outer_subfield) {
            printf trim(subseparated_line[k]) conditional_ofs
          } else {
            printf unescaped(subsep_pattern) OFS
          }
        }
      }
    } else {
      printf trim($i) conditional_ofs
    }
  }
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
    print ""
    print FNR, i, "shift: " shift, "nos: " n_outer_subfields, "sf_part: " subfield_partitions, "cofs: " conditional_ofs
  } else if (case == 2) {
    print ""
    print FNR, i, "shift: " shift, "nos: " n_outer_subfields, "sf_part: " subfield_partitions, "cofs: " conditional_ofs, "osf: " outer_subfield, "k: " k
  }
}
