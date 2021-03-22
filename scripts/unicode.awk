#!/usr/bin/awk
#
# Conversion of character byte output from xxd to various code point forms

BEGIN {
  if (!to || "codepoint" ~ to)
    to = 0
  else if ("octet" ~ to || "hex" ~ to)
    to = 1
}

to < 1 {
  # Codepoint case
  if ($3 ~ /^[0-1]+/) {
    b[1] = substr($2, 5, 4)
    b[2] = substr($3, 3, 6)
    if ($4 ~ /^[0-1]+/) {
      b[3] = substr($4, 3, 6)
      if ($5 ~ /^[0-1]+/) {
        b[4] = substr($5, 3, 6)
      }
    }
  } else {
    b[1] = substr($2, 2, 7)
  }

  for (i = 1; i <= length(b); i++)
    d = d b[i]
}

to == 1 {
  # Octet/hex case
  for (i = 1; i <= NF; i++) {
    if (i < 2) continue
    if ($i ~ /^[0-1]+/) {
      if (d)
        d = d";"$i
      else
        d = $i
    }
  }
}

{
  print "obase=16; ibase=2; " d
}
