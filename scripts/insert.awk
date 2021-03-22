#!/usr/bin/awk
#
# Adds the lines from one file into the lines of another file at 
# the specified location and prints to stdout
#
# Insertion point as first match of regex pattern:
# > awk -v pattern=pattern -f insert.awk sinkfile sourcefile
#
# Insertion point as line number:
# > awk -v lineno=lineno -f insert.awk sinkfile sourcefile

BEGIN {
  if (pattern) check_pattern = 1
  if (lineno) check_lineno = 1
}

NR == FNR { _[NR] = $0 }
NR > FNR { __[FNR] = $0 }

END {
  fnr_sink = length(_)
  fnr_source = length(__)
  
  if (check_lineno && fnr_sink < lineno) {
    if (lineno - fnr_sink > 500) {
      print "Line number insertion point is too far from end of sink file"
      exit 1
    }

    extend_sink = 1
  }

  for (i = 1; i <= fnr_sink; i++) {
    line = _[i]

    if (ins) {
      match_found = 1
      ins = 0
      
      for (j = 1; j <= fnr_source; j++) 
        print __[j]
    }

    print line
    
    if (!first_match_insert || !match_found) {
      if (check_lineno && i == lineno)
        ins = 1
      else if (check_pattern && line ~ pattern)
        ins = 1
    }
  }

  if (extend_sink) {
    for (i = i; i <= lineno; i++) {
      if (i < lineno)
        print ""
      else {
        for (j = 1; j <= fnr_source; j++)
          print __[j]
      }
    }
  }

  if (!match_found) {
    print "No match line found"
    exit 1
  }
}

