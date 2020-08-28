#!/usr/bin/awk
#
# Reorder, repeat or slice the rows and columns of fielded data
#
# Index:
# > awk -f reorder.awk -v r=1 -v c=1
#
# Specific rows and/or columns:
# > awk -f reorder.awk -v r="{1..100}" -v c=1,4,5
#
# Range (and/or individual rows and columns):
# > awk -f reorder.awk -v r=1,100-200 -v c=1-3,4
#
# Reorder/Repeat:
# > awk -f reorder.awk -v r=3,3,5,1 -v c=4-1,1,3,5
#
# TODO: Might be more efficient to break out handling and cases each in their own files 
# TODO: Add > and < functionality
# TODO: Add modulo functionality
# TODO: Untether row and column in methods
# TODO: On reo case add print and deletion for ascending order elements in reorder, save
# only fields needed after triggering of reorder while reading the lines

BEGIN {
  #quote handling setup
  #ReoSetup() - wrap the below in a function
  n_re = "^[0-9]+$"
  ord_sep = "[ ,\|\:\;\.\_]+"
  range_sep = "\-"
  search_sep = "="
  head_sep="\["
  re_sep = "\~"
  comp_sep = "(<|>)"
  gt = ">"
  lt = "<"
  mod = "%"

  if (r) {
    split(r, r_order, ord_sep)
    r_len = length(r_order)

    if (r_len > 1) {
      for (i = 1; i <= r_len; i++) {
        r_i = r_order[i]
        if (debug) debug_print(1)
 
        if (!r_i) {
          print "Skipping unparsable 0 row arg"

        } else if (r_i ~ range_sep) {
          max_r_i = TestRangeArg(r_i, max_r_i)
          reo_r_count = FillRange(r_i, R, reo_r_count, ReoR)

        } else {
          reo_r_count = FillReoArr(r_i, R, reo_r_count, ReoR)

          if (!reo && r_i > max_r_i)
            max_r_i = r_i
          else
            reo = 1
        }
      }
    } else if (r ~ range_sep) {
      TestRangeArg(r, max_r_i)
      reo_r_count = FillRange(r, R, reo_r_count, ReoR)
    } else if (!(r ~ n_re)) {
      pass_r = 1
    } else {
      reo_r_count = FillReoArr(r, R, reo_r_count, ReoR)
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
          print "Skipping unparsable 0 col arg"
          delete c_order[i]

        } else if (c_i ~ range_sep) {
          max_c_i = TestRangeArg(c_i, max_c_i)
          delete c_order[i]
          reo_c_count = FillRange(c_i, C, reo_c_count, ReoC)

        } else {
          reo_c_count = FillReoArr(c_i, RangeC, reo_c_count, ReoC)

          if (!reo && c_i > max_c_i)
            max_c_i = c_i
          else
            reo = 1
        }
      }
    } else if (c ~ range_sep) {
      TestRangeArg(c, max_c_i)
      reo_c_count = FillRange(c, C, reo_c_count, ReoC)
    } else if (!(c ~ n_re)) {
      pass_c = 1
    } else {
      reo_c_count = FillReoArr(c, C, reo_c_count, ReoC)
    }
  } else {
    pass_c = 1
  }

  if (pass_r && pass_c) pass = 1

  if (r_len == 1 && c_len == 1 && !pass_r && !pass_c && !range && !reo)
    indx = 1
  else if (!range && !reo)
    base = 1

  if (debug) {
    print "Reorder counts, start vals, end vals (row, column)"
    print reo_r_count, reo_c_count
    print ReoR[1], ReoC[1]
    print ReoR[reo_r_count], ReoC[reo_c_count]
  }
  OFS = FS
  reo_c_len = length(ReoC)
}


indx { if (NR == r) { print $c; exit } next }

base { if (pass_r || NR in R) FieldBase(); next }

range && !reo { if (pass_r || NR in R) FieldRange(); next }

reo { 
  if (pass_r) {
    for (i = 1; i < reo_c_len; i++)
      printf "%s", $ReoC[i] OFS

    print $ReoC[reo_c_len]

  } else if (NR in R) {
    _[NR] = $0
  }
  next
}

pass { print $0 }


END {
  if (debug) {
    if (indx) print "index case"
    if (base) print "base case"
    if (range) print "range case"
    if (reo) print "reo case"
  }

  if (err || !reo || pass_r) exit err


  for (i = 1; i <= length(ReoR); i++) {
    if (pass_c) print _[ReoR[i]]
    else {
      split(_[ReoR[i]], Row, FS)

      for (j = 1; j < reo_c_len; j++)
        printf "%s", Row[ReoC[j]] OFS

      print Row[ReoC[reo_c_len]]
    }
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

  range = 1

  if (ra1 >= ra2 || ra1 <= max_i)
    reo = 1
  else
    max_i = ra2

  return max_i
}
function FillRange(rangeArg, RangeArr, reoCount, ReoArr) {
  split(rangeArg, RngAnc, range_sep)
  start = RngAnc[1]
  end = RngAnc[2]

  if (debug) debug_print(2)

  if (start > end) {
    for (k = start; k >= end; k--)
      reoCount = FillReoArr(k, RangeArr, reoCount, ReoArr)

  } else {
    for (k = start; k <= end; k++)
      reoCount = FillReoArr(k, RangeArr, reoCount, ReoArr)
  }

  return reoCount
}
function FillReoArr(val, KeyArr, count, ReoArray) {
  KeyArr[val] = 1
  count++
  ReoArray[count] = val
  
  return count
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
    for (i = 1; i < reo_c_count; i++)
      printf "%s", $ReoC[i] OFS

    print $ReoC[reo_c_count]
  }
}
function debug_print(case) {
  if (case == 1) {
    print "i: " i, " r_i: " r_i, " r_len: " r_len
  } else if (case == 2) {
    print "FillRange ra1: " ra1, " ra2: " ra2
  }
}
