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
# TODO: reverse case


# SETUP

BEGIN {
  BuildRe(Re); BuildTokens(Tk); BuildTokenMap(TkMap)

  if (r) {
    split(r, r_order, Re["ordsep"])
    r_len = length(r_order)

    for (i = 1; i <= r_len; i++) {
      r_i = r_order[i]
      if (!r_i) { print "Skipping unparsable 0 row arg"; continue }

      token = TokenPrecedence(r_i)
      if (debug) debug_print(1)

      if (!token) {
        if (!(r_i ~ Re["int"])) continue
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
          if (token == "mat")
            reo_r_count = FillReoArr(r_i, Exprs, reo_r_count, ReoR, token)
          else if (token == "re")
            reo_r_count = FillReoArr(r_i, Searches, reo_r_count, ReoR, token)
        }}}
  } else { pass_r = 1 }
  if (!reo_r_count) pass_r = 1

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
      if (debug) debug_print(1.5)

      if (!token) {
        if (!(c_i ~ Re["int"])) continue
        reo_c_count = FillReoArr(c_i, RangeC, reo_c_count, ReoC)
        if (!reo && c_i > max_c_i)
          max_c_i = c_i
        else
          reo = 1
      } else {
        delete c_order[i]
        max_c_i = TestArg(c_i, max_c_i, token)

        if (token == "rng") {
          reo_c_count = FillRange(c_i, C, reo_c_count, ReoC)
        } else {
          reo_c = 1
          if (token == "mat")
            reo_c_count = FillReoArr(c_i, Exprs, reo_c_count, ReoC, token)
          else if (token == "re")
            reo_c_count = FillReoArr(c_i, Searches, reo_c_count, ReoC, token)
        }}}
  } else { pass_c = 1 }
  if (!reo_c_count) pass_c = 1

  if (pass_r && pass_c) pass = 1

  if (r_len == 1 && c_len == 1 && !pass_r && !pass_c && !range && !reo)
    indx = 1
  else if (!range && !reo)
    base = 1
  else if (reo && !mat && !re)
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
  } else {
    row_os = 1
    if (NR in R) StoreRow(_, NR, $0, RowCounts)
    if (re && row_os) {
      for (search in Searches) {
        if (!row_os) break
        split(search, tmp, "~")
        if (substr(search, 1, 1) ~ Re["num"]) {
          search = tmp[2]
          anchor = $tmp[1] }
        else anchor = $0
        if (anchor ~ search) StoreRow(_, NR, $0, RowCounts)
      }
    }
    if (mat && row_os) {
      for (expr in Exprs) {
        if (!row_os) break
        comp = "="; compval = 0
        if (substr(expr, 1, 1) ~ Re["num"]) {
          split(expr, tmp, Re["nan"])
          expr = substr(expr, length(tmp[1])+1, length(expr))
          anchor = $tmp[1] }
        else anchor = NR

        if (expr ~ Re["comp"]) {
          if (expr ~ ">")
            comp = ">"
          else if (expr ~ "<")
            comp = "<"
          else
            comp = "="

          split(expr, tmp, comp)
          expr = tmp[1]
          compval = tmp[2]
        }

        if (comp == "=") {
          if (EvalExpr(anchor expr) == compval) StoreRow(_, NR, $0, RowCounts)
        } else if (comp == ">") {
          if (EvalExpr(anchor expr) > compval) StoreRow(_, NR, $0, RowCounts)
        } else {
          if (EvalExpr(anchor expr) < compval) StoreRow(_, NR, $0, RowCounts)
        }
      }
    }
  }
  next
}

pass { print $0 }



# FINAL PROCESSING FOR REORDER CASES

END {
  if (debug) debug_print(4) 

  if (err || !reo || pass_r) exit err # error only triggered if set


  for (i = 1; i <= length(ReoR); i++) {
    r_key = ReoR[i]
    if (pass_c && base_reo) {
      print _[r_key]
    } else {
      if (r_key ~ Re["int"]) {
        if (pass_c) print _[r_key]
        else {
          split(_[r_key], Row, FS)

          for (j = 1; j < reo_c_len; j++) {
            c_key = ReoC[j]
            if (c_key ~ Re["int"])
              printf "%s", Row[c_key] OFS
            else
              Reo(c_key, Row, "", 0, RowCounts)
          }

          c_key = ReoC[reo_c_len]
          if (c_key ~ Re["int"])
            print Row[c_key]
          else
            Reo(c_key, Row, "", 0, RowCounts)
        }
      } else Reo(r_key, _, "", 1, RowCounts)
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
  Re["nan"] = "[^0-9]"
  Re["matarg1"] = "^[0123456789\\+\\-\\*\\/%\\^]+([=<>]" Re["num"] ")?$"
  Re["matarg2"] = "^[=<>]" Re["num"] "$"
  Re["ordsep"] = "[ ,]+"
  Re["comp"] = "(<|>|=)"
}
function BuildTokenMap(TkMap) {
  TkMap["rng"] = "\\.\\."
  TkMap["re"] = "\~"
  TkMap["mat"] = "[\+\-\*\/%\^<>=]"
}
function BuildTokens(Tk) {
  Tk[".."] = "rng"
  Tk["~"] = "re"
  Tk["="] = "mat"
  Tk[">"] = "mat"
  Tk["<"] = "mat"
  Tk["+"] = "mat"
  Tk["-"] = "mat"
  Tk["/"] = "mat"
  Tk["%"] = "mat"
  Tk["^"] = "mat"
}
function TokenPrecedence(arg) {
  foundToken = ""; loc_min = 100000
  for (tk in Tk) {
    tk_loc = index(arg, tk)
    if (debug) print arg, tk, tk_loc
    if (tk_loc && tk_loc < loc_min) {
      loc_min = tk_loc
      foundToken = Tk[tk] }}
  return foundToken
}
function TestArg(arg, max_i, type) {
  if (!type) {
    if (arg ~ Re["int"])
      return arg
    else {
      print "Order arg " arg " not parsable - simple order arg format is integer"
      exit 1 }} 

  split(arg, Subargv, TkMap[type])
  sa1 = Subargv[1]; sa2 = Subargv[2]
  len_sargv = length(Subargv)

  if (type == "rng") { range = 1
    if (len_sargv != 2 || !(sa1 ~ Re["int"]) || !(sa2 ~ Re["int"])) {
      print "Invalid order range arg " arg " - range format is for example: 1..9"
      exit 1
    if (reo || sa1 >= sa2 || sa1 <= max_i)
      reo = 1
    else
      max_i = ra2 }

  } else if (type == "mat") { reo = 1; mat = 1
    for (sa_i = 2; sa_i <= length(Subargv); sa_i++) {
      if (!(Subargv[sa_i] ~ Re["int"])) nonint_sarg = 1
    }
    if (nonint_sarg || !(arg ~ Re["matarg1"] || arg ~ Re["matarg2"])) {
      print "Invalid order expression arg " arg " - expression format examples include: %2  %3=5  *6/8%2=1"
      exit 1 }

  } else if (type == "re") { reo = 1; re = 1
    re_test = substr(arg, length(sa1)+1, length(arg))
    if ("" ~ re_test) {
      print "Invalid order search range arg - search arg format examples include: ~search  2~search"
      exit 1 }}

  return max_i
}
function FillRange(rangeArg, RangeArr, reoCount, ReoArr) {
  split(rangeArg, RngAnc, TkMap["rng"])
  start = RngAnc[1]
  end = RngAnc[2]

  if (debug) debug_print(2)

  if (start > end) {
    reo = 1
    for (k = start; k >= end; k--)
      reoCount = FillReoArr(k, RangeArr, reoCount, ReoArr)
    
  } else {
    for (k = start; k <= end; k++)
      reoCount = FillReoArr(k, RangeArr, reoCount, ReoArr)
  }

  return reoCount
}
function FillReoArr(val, KeyArr, count, ReoArray, type) {
  KeyArr[val] = 1
  count++
  ReoArray[count] = val
  
  return count
}
function StoreRow(_, nr, row, RowCounts) {
  _[nr] = row
  RowCounts[rc++] = nr
  row_os = 0
}
function EvalExpr(expr) {
  res = 0
  split(expr, a, "+")
  for(a_i in a){
    split(a[a_i], s, "-")
      for(s_i in s){
        split(s[s_i], m, "*")
        for(m_i in m){
          split(m[m_i], d, "/")
          for(d_i in d){
            split(d[d_i], u, "%")
            for(u_i in u){
              split(u[u_i], e, "\^")
              for(e_i in e){
                if (e_i > 1) e[1] = e[1] ** e[e_i] }
              u[u_i] = e[1]; delete e
              if (u_i > 1) u[1] = u[1] % u[u_i] }
            d[d_i] = u[1]; delete u
            if (d_i > 1) d[1] /= d[d_i] }
          m[m_i] = d[1]; delete d
          if (m_i > 1) m[1] *= m[m_i] }
        s[s_i] = m[1]; delete m
        if (s_i > 1) s[1] -= s[s_i] }
    a[a_i] = s[1]; delete s }

  for (a_i in a)
    res += a[a_i]
  return res
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
function Reo(key, CrossSpan, Span, row, RowCounts) {
  anchor_unset = 0
  token = TokenPrecedence(key)
  if (token == "re") {
    search = key
    if (substr(search, 1, 1) ~ Re["num"]) {
      split(search, tmp, Re["nan"])
      search = substr(search, length(tmp[1])+1, length(search))
      anchor = $tmp[1] }
    else anchor_unset = 1
    }
  else if (token == "mat") {
    expr = key
    comp = "="; compval = 0
    if (substr(expr, 1, 1) ~ Re["num"]) {
      split(expr, tmp, Re["nan"])
      expr = substr(expr, length(tmp[1])+1, length(expr))
      anchor = CrossSpan[tmp[1]] }
    else anchor_unset = 1

    if (expr ~ Re["comp"]) {
      if (expr ~ ">")
        comp = ">"
      else if (expr ~ "<")
        comp = "<"
      else
        comp = "="

      split(expr, tmp, comp)
      expr = tmp[1]
      compval = tmp[2]
    }}
# Pull mat, NR case evals out of for loop - the property is consistent
  if (row) {
    for (k = 1; k <= length(RowCounts); k++) {
      nr = RowCounts[k]
      item = CrossSpan[nr]
      if (token == "re") {
        if (anchor_unset) anchor = item
        if (anchor ~ search)
          printf "%s", item
      } else if (token == "mat") {
        if (anchor_unset) anchor = nr
        if (comp == "=") {
          if (EvalExpr(anchor expr) == compval) print item
        } else if (comp == ">") {
          if (EvalExpr(anchor expr) > compval) print item
        } else {
          if (EvalExpr(anchor expr) < compval) print item
        }
      }

      print ""
    }
  } else {
    len_span = length(CrossSpan)
    for (k = 1; k <= len_span; k++) {
      item = CrossSpan[k]
      if (!anchor_unset) anchor = CrossSpan[anchor]
    # Need to rebuild a column in its entirety to be able to search along it?
    # Or just pass through searching once as separate function..
      if (token == "re") {
        if (anchor_unset) anchor = item
        if (anchor ~ search)
          printf "%s", item
      } else if (token == "mat") {
        if (anchor_unset) anchor = k
        if (comp == "=") {
          if (EvalExpr(anchor expr) == compval) print_field(item, k, len_span)
        } else if (comp == ">") {
          if (EvalExpr(anchor expr) > compval) print_field(item, k, len_span)
        } else {
          if (EvalExpr(anchor expr) < compval) print_field(item, k, len_span)
        }
      }
    }
    print ""
  }
}
function print_field(field_val, field_count, end_count) {
  padded_field = field_val OFS
  if (field_count == end_count)
    printf "%s", field_val
  else
    printf "%s", padded_field
}
function debug_print(case) {
  if (case == 1) {
    print "i: " i, " r_i: " r_i, " r_len: " r_len, " token: " token
  } else if (case == 1.5) {
    print "i: " i, " c_i: " c_i, " c_len: " c_len, " token: " token
  } else if (case == 2) {
    print "FillRange start: " start, " end: " end
  } else if (case == 4) {
    if (indx) print "index case"
    if (base) print "base case"
    if (range) print "range case"
    if (mat) print "mat case"
    if (re) print "re case"
    if (reo) print "reo case"
    if (base_reo) print "base reo case"
  }
}
