#!/usr/bin/awk
# DS:PIVOT
#
# NAME
#       ds:pivot, pivot.awk
#
# SYNOPSIS
#       ds:join [-h|--help|file*] y_keys x_keys [z_keys=count_xy] [agg_type] [awkargs]
#
# DESCRIPTION
#      pivot.awk is a scirpt to pivot tabular data.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based
#       systems it should be), and call it on a file:
#
#          > awk -f pivot.awk file
#
#       ds:pivot is the caller function for the pivot.awk script. To run any of the examples 
#       below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#          $ data_in | ds:pivot 1 2
#
#       ds:pivot can be run on multiple files simultaneously applying the same arguments:
#
#          $ ds:pivot file1.csv file2.csv file3.csv ... y_keys x_keys ...
#
# FIELD CONSIDERATIONS
#       When running ds:pivot, an attempt is made to infer field separators of up to
#       three characters. If none found, FS will be set to default value, a single
#       space = " ". To override FS, add as a trailing awkarg. Be sure to escape and 
#       quote if needed. AWK's extended regex can be used as FS:
#
#          $ ds:pivot file 1 2 -v FS=" {2,}"
#
#          $ ds:pivot file 3 2 4 -F'\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:pivot file 1 4 -v FS=""
#
#       If ds:pivot detects it is connected to a terminal, it will attempt to fit the data
#       into the terminal width using the same field separator. If the data is being sent to
#       a file or a pipe, no attempt to fit will be made. One easy way to turn off fit is to
#       cat the output or redirect to a file.
#
#          $ ds:pivot file 1 2 | cat
#
# USAGE
#       y_keys, x_keys, z_keys can be any field index, set of field indexes, or pattern 
#       matching any headers, separated by commas.
#
#       Example input:
#
#          $ cat test.csv
#          a,b,c,d
#          1,2,3,4
#
#      If no value is passed for z_keys, ds:pivot outputs a count of each combination:
#
#          $ ds:pivot test.csv 1,2 4
#          PIVOT     d  4
#              a  b  1
#              1  2     1
#
#      If a value is passed for z_keys, ds:pivot outputs the value found at each combination::
#
#          $ ds:pivot test.csv 1,2 4 3
#          PIVOT     d  4
#              a  b  c
#              1  2     3
#
#      Passing a header pattern instead of a field index will remove the first row from 
#      the pivot and generate a pivot based on the first field header found matching the 
#      pattern:
#
#          $ ds:pivot test.csv a,b d c
#          a::b \ d     4
#                 1  2  3
#
#       Note field keys cannot overlap, and if any key pattern given overlaps with
#       another field already defined it will be skipped.
#
#       Aggregation options:
#          [c]ount   - count all instances of x-y combination
#          [s]um     - add the value at each x-y combination
#          [p]roduct - return the product of values at each x-y combination
#
#
# AWKARG OPTS
#       Recognize a header without specifying a field name by header title:
#
#          $ ds:pivot test.csv 1,2 4 3 -v header=1
#          a::b \ d     4
#                 1  2  3
#
# VERSION
#      1.0
#
# AUTHORS
#      Tom Hall (tomhall.main@gmail.com)
#
## TODO: Sort rows and cols by header - use multisort script?
## TODO: transformations

BEGIN {
  _ = SUBSEP
  if (!(FS ~ "\\[:.+:\\]")) OFS = FS
  
  if (!x || !y) {
    print "Missing axis fields"; exit 1 }

  len_x = split(x, XKeys, /,+/)
  len_y = split(y, YKeys, /,+/)

  for (i = 1; i <= len_x; i++) {
    key = XKeys[i]
    
    if (!(key ~ /^[0-9]+$/)) {
      GenKey["x", i] = key
      continue
    }

    XK[key] = 1
  }

  for (i = 1; i <= len_y; i++) {
    key = YKeys[i]

    if (!(key ~ /^[0-9]+$/)) {
      GenKey["y", i] = key
      continue
    }
    
    if (key in XK) {
      print "Axis field sets cannot overlap"
      exit 1
    }

    YK[key] = 1
  }

  if (agg) {
    if ("sum" ~ "^"agg) s = 1
    else if ("count" ~ "^"agg) c = 1
    else if ("product" ~ "^"agg) p = 1
    else agg = 0
  }
  else no_agg = 1

  if (z) {
    if (z == "_") {
      count_xy = 1
    }
    else {
      len_z = split(z, ZKeys, /,+/)
    
      for (i = 1; i <= len_z; i++) {
        key = ZKeys[i]
        
        if (!(key ~ /^[0-9]+$/)) {
          GenKey["z", i] = key
          continue
        }
        
        if (key in XK || key in YK) {
          print "Field sets cannot overlap"
          exit 1
        }

        ZK[key] = 1
      }
    }
  }
  else gen_z = 1

  if (transform || transform_expr) {
    if (transform && "norm" ~ "^"transform)
      n = 1
    else if (transform_expr)
      trx = 1
  }
}

NR < 2 {
  if (length(GenKey) > 0) {
    GenKeysFromHeader("x", KeyFound, XKeys, XK, YK, ZK)
    GenKeysFromHeader("y", KeyFound, YKeys, XK, YK, ZK)
    GenKeysFromHeader("z", KeyFound, ZKeys, XK, YK, ZK)
    
    if (length(XK) < 1 || length(YK) < 1) {
      print "Fields not found for both x and y dimensions with given key params"
      error_exit = 1
      exit 1
    }
    else if (!count_xy && length(ZK) < 1) {
      print "Z dimension fields not found with given key params"
      error_exit = 1
      exit 1
    }
    
    header = 1
  }

  if (gen_z) {
    GenZKeys(NF, ZK, ZKeys, XK, YK)
    len_z = length(ZK)
  }

  if (header) {
    for (i=1; i<=len_y; i++) {
      if (GenKey["y", i] && !KeyFound["y", i]) continue
      pivot_header = i == len_y ? pivot_header $YKeys[i] : pivot_header $YKeys[i] "::"
    }
    
    pivot_header = pivot_header " \\ "
    
    for (i=1; i<=len_x; i++) {
      if (GenKey["x", i] && !KeyFound["x", i]) continue
      pivot_header = i == len_x ? pivot_header $XKeys[i] : pivot_header $XKeys[i] "::"
    }
    
    next
  }
  else {
    pivot_header = "PIVOT"
  }
}

{
  # TODO: Handle noagg partial duplicate case
  if (NF < 1) next

  x_str = ""; y_str = ""; z_str = ""

  for (i=1; i<=len_x; i++) {
    if (GenKey["x", i] && !KeyFound["x", i]) continue
    x_str = i == len_x ? x_str $XKeys[i] OFS : x_str $XKeys[i] "::"
  }
  for (i=1; i<=len_y; i++) {
    if (GenKey["y", i] && !KeyFound["y", i]) continue
    y_str = y_str $YKeys[i] OFS
  }
  if (!count_xy) {
    for (i=1; i<=len_z; i++) {
      if (GenKey["z", i] && !KeyFound["z", i]) continue
      z_str = i == len_z ? z_str $ZKeys[i] : z_str $ZKeys[i] "::"
    }
  }

  if (x_str y_str z_str == "") next

  X[x_str]++
  Y[y_str]++

  if (no_agg && !count_xy)
    Z[x_str y_str] = z_str
  else if (c || count_xy)
    Z[x_str y_str]++
  else if (s) {
    adder = z_str + 0
    Z[x_str y_str] += adder
  }
  else if (p) {
    multiplier = z_str + 0
    Z[x_str y_str] *= multiplier
  }

  if (debug) {
    print x_str, y_str
    print z_str
  }
}

END {
  if (error_exit)
    exit

  # Header
  
  printf "%s", pivot_header
  
  for (yk = 1; yk <= length(YKeys); yk++) {
    if (GenKey["y", yk] && !KeyFound["y", yk]) continue
    printf "%s", OFS
  }

  for (x in X)
    printf "%s", x
  
  print ""

  # Data

  for (y in Y) {
    printf "%s", y
    
    for (x in X) {
      cr = Z[x y] ? Z[x y] : placeholder
      printf "%s", cr OFS
    }
    
    print ""
  }
}

function GenKeysFromHeader(pivot_dim, KeyFound, KeysMap, XK, YK, ZK) {
  for (k = 1; k <= length(KeysMap); k++) {
    if (!GenKey[pivot_dim, k]) continue

    key = KeysMap[k]
    
    for (f = 1; f <= NF; f++) {
      if ($f ~ key || tolower($f) ~ key) {
        if (!(f in XK || f in YK || f in ZK)) {
          if (pivot_dim == "x") {
            XK[f] = 1
          }
          else if (pivot_dim == "y") {
            YK[f] = 1
          }
          else {
            ZK[f] = 1
          }

          KeysMap[k] = f
          KeyFound[pivot_dim, k] = 1
          break
        }
      }
    }
  }
}

function GenZKeys(nf, Z, ZKeys, XK, YK) {
  z_count = 1

  for (f = 1; f <= nf; f++) {
    if (f in XK || f in YK) continue
    
    ZK[f] = 1; ZKeys[z_count++] = f
  }
}
