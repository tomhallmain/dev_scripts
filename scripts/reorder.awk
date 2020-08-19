#!/usr/bin/awk
#
# Reorder, repeat or slice the rows and columns of fielded data
#
# > awk -f reorder.awk
#
# TODO: Might be more efficient to break out handling and cases each in their own files 
# TODO: Add > and < functionality
# TODO: Add mod functionality

BEGIN {
  n_re = "^[0-9]+$"
  ord_sep = "[ ,\|\:\;\.\_\~]+"
  range_sep = "\-"

  if (r) {
    split(r, r_order, ord_sep)
    r_len = length(r_order)

    if (r_len > 1) {
      for (i = 1; i <= r_len; i++) {
        r_i = r_order[i]
 
        if (!r_i) {
          print "Skipping non-applicable 0 row arg"
          delete r_order[i]
          r_len--

        } else if (r_i ~ range_sep) {
          max_r_i = TestRangeArg(r_i, max_r_i)
          delete r_order[i]
          range_len = FillRange(R, r_i, ReoR, reo_r_count)
          r_len += range_len - 1

        } else {
          R[r_i] = 1
          reo_r_count++
          ReoR[reo_r_count] = r_i

          if (!reo_case && r_i > max_r_i)
            max_r_i = r_i
          else
            reo_case = 1
        }
      }
    } else if (r ~ range_sep) {
      TestRangeArg(r, max_r_i)
      range_len = FillRange(R, r_i, ReoR, reo_r_count)
      r_len += range_len - 1
    } else if (!(r ~ n_re)) {
      pass_r = 1
    } else {
      R[r] = 1
      ReoR[1] = r
    }
  } else {
    pass_r = 1
  }

  if (c) {
    split(c, c_order, ord_sep)
    c_len = length(c_order)

    if (c_len > 1) { 
      for (i = 1; i <= c_len; i++) {
        c_i = c_order[i]

        if (!c_i) {
          print "Skipping non-applicable 0 col arg"
          delete c_order[i]
          c_len--

        } else if (c_i ~ range_sep) {
          max_c_i = TestRangeArg(c_i, max_c_i)
          delete c_order[i]
          range_len = FillRange(C, c_i, ReoC, reo_c_count)
          c_len += range_len - 1

        } else {
          C[c_i] = 1
          reo_c_count++
          ReoC[reo_c_count] = c_i

          if (!reo_case && c_i > max_c_i)
            max_c_i = c_i
          else
            reo_case = 1
        }
      }
    } else if (c ~ range_sep) {
      TestRangeArg(c, max_c_i)
      range_len = FillRange(C, c_i, ReoC, reo_c_count)
      c_len += range_len - 1
    } else if (!(c ~ n_re)) {
      pass_c = 1
    } else {
      C[c] = 1
      ReoC[1] = c
    }
  } else {
    pass_c = 1
  }

  if (pass_r && pass_c) pass = 1
  if (r_len == 1 && c_len == 1 && !pass_r && !pass_c && !range_case && !reo_case) {
    index_case = 1
  } else if (!range_case && !reo_case) {
    base_case = 1
  }

  OFS = FS
}

index_case { if (NR == r) { print $c; exit } next }

base_case {
  if (pass_r || NR in R)
    FieldBase()
  next
}

range_case && !reo_case {
  if (pass_r || NR in R)
    FieldRange()
  next
}

reo_case { if (NR in R) _[NR] = $0; next }

pass { print $0 }


END {
  if (debug) {
    if (index_case) print "index case"
    if (base_case) print "base case"
    if (range_case) print "range case"
    if (reo_case) print "reo case"
  }

  if (err || !reo_case) exit err

  reo_c_len = length(ReoC)

  for (i = 1; i <= length(ReoR); i++) {
    split(_[ReoR[i]], Row, FS)

    for (j = 1; j < reo_c_len; j++)
      printf Row[ReoC[j]] OFS

    print Row[ReoC[reo_c_len]]
  }
}


function TestRangeArg(rangeArg, max_i) {
  split(rangeArg, RngAnc, range_sep)
  ra1 = RngAnc[1]
  ra2 = RngAnc[2]

  if (length(RngAnc) != 2 || !(ra1 ~ n_re) || !(ra2 ~ n_re) ) {
    print "Invalid row order range arg " rangeArg " - range format is for example: 1-9 - exiting script"
    err = 1
    exit err
  }

  range_case = 1

  if (ra1 >= ra2 || ra1 <= max_i)
    reo_case = 1
  else
    max_i = ra2

  return max_i
}
function FillRange(RangeArr, rangeArg, ReoArr, reoCount) {
  split(rangeArg, RngAnc, range_sep)
  ra1 = RngAnc[1]
  ra2 = RngAnc[2]

  if (ra1 > ra2) {
    start = ra2
    end = ra1
  } else {
    start = ra1
    end = ra2
  }
  diff = end - start

  for (k = start; k <= end; k++) {
    RangeArr[k] = 1
    reoCount++
    ReoArr[reoCount] = k
  }

  return diff
}
function FieldBase() {
  if (pass_c) print $0
  else {
    for (i = 1; i < c_len; i++)
      printf $c_order[i] OFS

    print $c_order[c_len]
  }
}
function FieldRange() {
  if (pass_c) print $0
  else {
    for (i = 1; i < NF; i++)
      if (i in C)
        printf $i OFS

    if (NF in C) print $NF
  }
}

