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

NR == FNR { _[NR] = $0 }
NR > FNR { __[FNR] = $0 }

END {
  for (i = 1; i <= length(_); i++) {
    line = _[i]

    if (ins) {
      mtch = 1
      ins = 0
      for (j = 1; j <= length(__); j++) 
        print __[j] }

    if (!mtch && (i == lineno || line ~ pattern)) { ins = 1 }

    print line }
}

