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
# > awk -f reorder.awk -v r=1,100-200 -v c=1-3,5
#
# Reorder/Repeat:
# > awk -f reorder.awk -v r=3,3,5,1 -v c=4-1,1,3,5
#
# TODO: quoted fields handling


# SETUP

BEGIN {
  BuildRe(Re); BuildTokens(Tk)

  if (r) {
    split(r, r_order, Re["ordsep"])
    r_len = length(r_order)

    for (i = 1; i <= r_len; i++) {
      r_i = r_order[i]
      if (!r_i) { print "Skipping unparsable 0 row arg"; continue }

      token = TokenPrecedence(r_i)
      if (debug) debug_print(1)
 
      if (!token) {
        reo_r_count = FillReoArr(r_i, R, reo_r_count, ReoR)
        if (!reo && r_i > max_r_i)
          max_r_i = r_i
        else
          reo = 1
      } else {
        max_r_i = TestArg(r_i, max_r_i, token)

        if (token == "rng") {
          reo_r_count = FillRange(r_i, R, reo_r_count, ReoR)
        } else {
          if (token == "mod") Keys = Mods
          else if (token == "gt" || token == "lt") Keys = Comps
          else if (token == "re") Keys = Searches
          reo_r_count = FillReoArr(r_i, Keys, reo_r_count, ReoR, token)
        }}}
  } else { pass_r = 1 }

  if (c) {
    split(c, c_order, Re["ordsep"])
    c_len = length(c_order)

    for (i = 1; i <= c_len; i++) {
      c_i = c_order[i]
      if (!c_i) {
        print "Skipping unparsable 0 col arg"
        delete c_order[i]
      }
      
      token = TokenPrecedence(c_i)
      if (debug) debug_print(1)
      
      if (!token) {
        reo_c_count = FillReoArr(c_i, RangeC, reo_c_count, ReoC)
        if (!reo && c_i > max_c_i)
          max_c_i = c_i
        else
          reo = 1
      } else {
        delete c_order[i]
        if (token == "rng") {
          reo_c_count = FillRange(c_i, C, reo_c_count, ReoC)
        } else {}
      }}
  } else { pass_c = 1 }

  if (pass_r && pass_c) pass = 1

  if (r_len == 1 && c_len == 1 && !pass_r && !pass_c && !range && !reo)
    indx = 1
  else if (!range && !reo)
    base = 1
  else if (reo && !comp && !mod && !re)
    base_reo = 1

  if (debug) {
    print "Reorder counts, start vals, end vals (row, column)"
    print reo_r_count, reo_c_count
    print ReoR[1], ReoC[1]
    print ReoR[reo_r_count], ReoC[reo_c_count]
  }
  OFS = BuildOFSFromUnescapedFS()
  reo_c_len = length(ReoC)
}



# SIMPLE PROCESSING/DATA GATHERING

indx { if (NR == r) { print $c; exit } next }

base { if (pass_r || NR in R) FieldBase(); next }

range && !reo { if (pass_r || NR in R) FieldRange(); next }

reo { 
  if (pass_r && base_reo) {
      for (i = 1; i < reo_c_len; i++)
        printf "%s", $ReoC[i] OFS

      print $ReoC[reo_c_len]
  } else if (NR in R) {
    _[NR] = $0
  } else if (mod) {
    if (NR in Mods) {
    }
  } else if (re) {
    for (i in Searches) {
      if ($0 ~ i)
    }
  }
  next
}

pass { print $0 }



# FINAL PROCESSING

END {
  if (debug) debug_print(4) 

  if (err || !reo || pass_r) exit err # error only triggered if set


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



# FUNCTIONS

function BuildOFSFromUnescapedFS() {
  OFS = ""
  split(FS, fstokens, "\\")
  for (i = 1; i <= length(fstokens); i++) {
    OFS = OFS fstokens[i]
  }
  return OFS
}
function BuildRe(Re) {
  Re["num"] = "[0-9]+"
  Re["int"] = "^" Re["num"] "$"
  Re["modarg"] = "^" Re["num"] "(=" Re["num"] ")?"
  Re["ordsep"] = "[ ,\;]+"
  Re["comp"] = "(<|>)"
}
function BuildTokens(Tk) {
  Tk["rng"] = "\-"
  Tk["re"] = "\~"
  Tk["gt"] = ">"
  Tk["lt"] = "<"
  Tk["mod"] = "%"
}
function TokenPrecedence(arg) {
  foundToken = ""; loc_min = 100000
  for (t in Tk) {
    tk_loc = index(arg, Tk[t])
    if (debug) print arg, t, tk_loc
    if (tk_loc && tk_loc < loc_min) {
      loc_min = tk_loc
      foundToken = t }}
  return foundToken
}
function TestArg(arg, max_i, type) {
  if (!type) {
    if (arg ~ Re["int"])
      return arg
    else {
      print "Order arg " arg " not parsable - simple order arg format is integer"
      exit 1 }} 

  split(arg, Subargv, Tk[type])
  sa1 = Subargv[1]; sa2 = Subargv[2]
  len_sargv = length(Subargv)

  if (type == "rng") { range = 1
    if (len_sargv != 2 || !(sa1 ~ Re["int"]) || !(sa2 ~ Re["int"])) {
      print "Invalid order range arg " arg " - range format is for example: 1-9"
      exit 1
    if (reo || sa1 >= sa2 || sa1 <= max_i)
      reo = 1
    else
      max_i = ra2 }

  } else if (type == "gt" || type == "lt") { reo = 1; comp = 1
    if (len_sargv != 2 || !(sa2 ~ Re["int"])) {
      print "Invalid order comparison arg " arg " - comparison arg format is for example: >4 OR <3"
      exit 1 }

  } else if (type == "mod") { reo = 1; mod = 1
    if (len_sargv != 2 || !(sa2 ~ Re["modarg"])) {
      print "Invalid order mod range arg " arg " - mod range format is for example: %2 OR %2=1"
      exit 1 }

  } else if (type == "re") { reo = 1; re = 1
    re_test = substr(arg, index(arg, sa1)+1, length(arg))
    if ("" ~ re_test) {
      print "Invalid order search range arg - search arg format is for example: 2~searchpattern"
      exit 1 }}

  return max_i
}
function FillRange(rangeArg, RangeArr, reoCount, ReoArr) {
  split(rangeArg, RngAnc, Tk["rng"])
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
function FillReoArr(val, KeyArr, count, ReoArray, token) {
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
    print "i: " i, " r_i: " r_i, " r_len: " r_len, " token: " token
  } else if (case == 2) {
    print "FillRange ra1: " ra1, " ra2: " ra2
  } else if (case == 4) {
    if (indx) print "index case"
    if (base) print "base case"
    if (range) print "range case"
    if (comp) print "comp case"
    if (gt) print "gt case"
    if (mod) print "mod case"
    if (re) print "re case"
    if (reo) print "reo case"
    if (base_reo) print "base reo case"
  }
}
