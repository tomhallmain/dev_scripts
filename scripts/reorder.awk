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
# > awk -f reorder.awk -v r=1,100..200 -v c=1..3,5
#
# Reorder/Repeat:
# > awk -f reorder.awk -v r=3,3,5,1 -v c=4-1,1,3,5
#
# TODO: quoted fields handling
# TODO: reverse case
# TODO: not equql to comparison
# TODO: mechanism for 'all the others, unspecified' (records or fields)

# SETUP

BEGIN {
  BuildRe(Re); BuildTokens(Tk); BuildTokenMap(TkMap)
  assume_constant_fields = 0 # TODO: Better mechanism for this

  if (debug) debug_print(-1)
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
            reo_r_count = FillReoArr(r_i, RRExprs, reo_r_count, ReoR, token)
          else if (token == "re")
            reo_r_count = FillReoArr(r_i, RRSearches, reo_r_count, ReoR, token)
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
            reo_c_count = FillReoArr(c_i, RCExprs, reo_c_count, ReoC, token)
          else if (token == "re")
            reo_c_count = FillReoArr(c_i, RCSearches, reo_c_count, ReoC, token)
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

  OFS = BuildOFSFromUnescapedFS()
  reo_r_len = length(ReoR)
  reo_c_len = length(ReoC)
  if (debug) debug_print(0)
  if (debug) debug_print(7)
}



# SIMPLE PROCESSING/DATA GATHERING

indx { if (NR == r) { print $c; exit } next }

base { if (pass_r || NR in R) FieldBase(); next }

range && !reo { if (pass_r || NR in R) FieldRange(); next }

reo {
  if (pass_r) {
    if (base_reo) {
      for (i = 1; i < reo_c_len; i++)
        printf "%s", $ReoC[i] OFS

      print $ReoC[reo_c_len]
    } else {
      StoreRow(_, NR, $0, RowCounts)
    }
  } else {
    row_os = 1
    if (NR in R) StoreRow(_, NR, $0, RowCounts)
    if (re && row_os) {
      for (search in RRSearches) {
        if (!row_os) break
        split(search, tmp, "~")
        if (substr(search, 1, 1) ~ Re["num"]) {
          base_search = tmp[2]
          anchor = $tmp[1] }
        else {
          base_search = search; anchor = $0 }
        if (anchor ~ base_search) StoreRow(_, NR, $0, RowCounts)
      }
    }
    if (mat && row_os) {
      for (expr in RRExprs) {
        if (!row_os) break
        comp = "="; compval = 0
        if (substr(expr, 1, 1) ~ Re["num"]) {
          split(expr, tmp, Re["nan"])
          base_expr = substr(expr, length(tmp[1])+1, length(expr))
          anchor = $tmp[1] }
        else {
          base_expr = expr; anchor = NR }

        if (base_expr ~ Re["comp"]) {
          if (base_expr ~ ">")
            comp = ">"
          else if (base_expr ~ "<")
            comp = "<"
          else
            comp = "="

          split(base_expr, tmp, comp)
          base_expr = tmp[1]
          compval = tmp[2]
        }

        if (comp == "=") {
          if (EvalExpr(anchor base_expr) == compval) StoreRow(_, NR, $0, RowCounts)
        } else if (comp == ">") {
          if (EvalExpr(anchor base_expr) > compval) StoreRow(_, NR, $0, RowCounts)
        } else {
          if (EvalExpr(anchor base_expr) < compval) StoreRow(_, NR, $0, RowCounts)
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

  if (err || !reo || (base_reo && pass_r)) exit err
  
  if (debug) {
    (!pass_c) debug_print(6)
    debug_print(8)
  }

  if (pass_r) {
    for (i = 1; i <= length(_); i++) {
      for (j = 1; j <= reo_c_len; j++) {
        c_key = ReoC[j]
        row = _[i]
        split(row, Row, FS)
        if (c_key ~ Re["int"]) {
          print_field(Row[c_key])
        }
        else
          Reo(c_key, Row, "", 0)
      }
      print ""
    }

    exit
  }

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

function Reo(key, CrossSpan, Span, row, RowCounts) {
  anchor_unset = 0
  token = TypeMap[key]
  if (token == "re") {
    search = key
    if (substr(search, 1, 1) ~ Re["num"]) {
      split(search, tmp, Re["nan"])
      base_search = substr(search, length(tmp[1])+1, length(search))
      anchor = CrossSpan[tmp[1]] }
    else { base_search = search; anchor_unset = 1 }
    }
  else if (token == "mat") {
    expr = key
    comp = "="; compval = 0
    if (substr(expr, 1, 1) ~ Re["num"]) {
      split(expr, tmp, Re["nan"])
      base_expr = substr(expr, length(tmp[1])+1, length(expr))
      anchor = CrossSpan[tmp[1]]
    }
    else anchor_unset = 1

    if (base_expr ~ Re["comp"]) {
      if (base_expr ~ ">")
        comp = ">"
      else if (base_expr ~ "<")
        comp = "<"
      else
        comp = "="

      split(base_expr, tmp, comp)
      base_expr = tmp[1]
      compval = tmp[2]
    }}
  # Pull mat, NR case evals out of for loop - the property is consistent
  if (row) {
    for (k = 1; k <= length(RowCounts); k++) {
      nr = RowCounts[k]
      item = CrossSpan[nr]
      if (token == "re") {
        if (anchor_unset) anchor = item
        if (anchor ~ base_search)
          printf "%s", item
      } else if (token == "mat") {
        if (anchor_unset) anchor = nr
        if (comp == "=") {
          if (EvalExpr(anchor base_expr) == compval) print item
        } else if (comp == ">") {
          if (EvalExpr(anchor base_expr) > compval) print item
        } else {
          if (EvalExpr(anchor base_expr) < compval) print item
        }
      }

      print ""
    }
  } else {
    if (token == "re") {
      fields = SearchFO[search]
    } else if (token == "mat") {
      fields = ExprFO[expr]
    }
    split(fields, PrintFields, ",")
    len_printf = length(PrintFields)
    len_printf--
    for (f = 1; f <= len_printf; f++) {
      print_field(CrossSpan[PrintFields[f]])
    }
  }
}

function FieldBase() {
  if (pass_c) print $0
  else {
    for (i = 1; i < c_len; i++)
      printf "%s", $c_order[i] OFS

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


function FillRange(range_arg, RangeArr, reo_count, ReoArr) {
  split(range_arg, RngAnc, TkMap["rng"])
  start = RngAnc[1]
  end = RngAnc[2]

  if (debug) debug_print(2)

  if (start > end) {
    reo = 1
    for (k = start; k >= end; k--)
      reo_count = FillReoArr(k, RangeArr, reo_count, ReoArr)
    
  } else {
    for (k = start; k <= end; k++)
      reo_count = FillReoArr(k, RangeArr, reo_count, ReoArr)
  }

  return reo_count
}

function FillReoArr(val, KeyArr, count, ReoArray, type) {
  KeyArr[val] = 1
  count++
  ReoArray[count] = val
  if (type) TypeMap[val] = type

  return count
}

function StoreRow(_, nr, row, RowCounts) {
  _[nr] = row
  RowCounts[rc++] = nr
  ColCounts[nr] = NF
  row_os = 0
  StoreFieldRefs()
}

function StoreFieldRefs() {
  # Check each field for each expression and search pattern, if applicable and
  # not already positively linked. Fields can be made non-applicable by field 
  # filter within the first subarg of the reo arg.
  if (re) {
    for (search in RCSearches) {
      split(search, tmp, "~")
      if (substr(search, 1, 1) ~ Re["num"]) {
        base_search = tmp[2]; start = tmp[1]; end = start }
      else { base_search = search # TODO: figure out short circuit for this case
        start = 1; end = NF }
      
      for (f = start; f <= end; f++) {
        if (!(SearchFO[search] ~ f",") && $f ~ base_search) {
          SearchFO[search] = SearchFO[search] f","
        }
      }
    }
  }

  if (mat) {
    for (expr in RCExprs) {
      if (assume_constant_fields && RCExprFieldsSet[expr]) continue
      # ^ may result in missed fields unless the number of fields of first row
      # is gt or equal to number of fields in all other rows
      comp = "="; compval = 0; settable = 0
      if (substr(expr, 1, 1) ~ Re["num"]) { # TODO: put this type of check in TestArg
        split(expr, tmp, Re["nan"])
        if (NR != tmp[1]) continue
        base_expr = substr(expr, length(tmp[1])+1, length(expr)) }
      else { base_expr = expr; settable = 1 # TODO: figure out short circuit for this case
        RCExprFieldsSet[expr] = 1 }

      if (base_expr ~ Re["comp"]) {
        if (base_expr ~ ">")
          comp = ">"
        else if (base_expr ~ "<")
          comp = "<"
        else
          comp = "="

        split(base_expr, tmp, comp)
        base_expr = tmp[1]
        compval = tmp[2]
      }

      for (f = 1; f <= NF; f++) {
        if (!(ExprFO[expr] ~ f",")) {
          if (settable) anchor = f
          else if ($f ~ Re["decnum"]) anchor = $f
          else continue
          if (debug) debug_print(5)
          if (comp == "=") {
            if (EvalExpr(anchor base_expr) == compval) ExprFO[expr] = ExprFO[expr] f","
          } else if (comp == ">") {
            if (EvalExpr(anchor base_expr) > compval) ExprFO[expr] = ExprFO[expr] f","
          } else {
            if (EvalExpr(anchor base_expr) < compval) ExprFO[expr] = ExprFO[expr] f","
          }
        }
      }
    }
  }
}

function TokenPrecedence(arg) {
  found_token = ""; loc_min = 100000
  for (tk in Tk) {
    tk_loc = index(arg, tk)
    if (debug) debug_print(3)
    if (tk_loc && tk_loc < loc_min) {
      loc_min = tk_loc
      found_token = Tk[tk] }}
  return found_token
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

function BuildRe(Re) {
  Re["num"] = "[0-9]+"
  Re["int"] = "^" Re["num"] "$"
  Re["decnum"] = "^[[:space:]]*[0-9]+([\.][0-9]*)?[[:space:]]*$"
  Re["nan"] = "[^0-9]"
  Re["matarg1"] = "^[0123456789\\+\\-\\*\\/%\\^]+([=<>]" Re["num"] ")?$"
  Re["matarg2"] = "^[=<>]" Re["num"] "$"
  Re["ordsep"] = "[ ,]+"
  Re["comp"] = "(<|>|=)"
}

function BuildTokenMap(TkMap) {
  TkMap["rng"] = "\\.\\."
  TkMap["head"] = "\\["
  TkMap["re"] = "\~"
  TkMap["mat"] = "[\+\-\*\/%\^<>=]"
}

function BuildTokens(Tk) {
  Tk[".."] = "rng"
  Tk["~"] = "re"
  Tk["["] = "head" #]
  Tk["="] = "mat"
  Tk[">"] = "mat"
  Tk["<"] = "mat"
  Tk["+"] = "mat"
  Tk["-"] = "mat"
  Tk["/"] = "mat"
  Tk["%"] = "mat"
  Tk["^"] = "mat"
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


function BuildOFSFromUnescapedFS() {
  OFS = ""
  split(FS, fstokens, "\\")
  for (i = 1; i <= length(fstokens); i++) {
    OFS = OFS fstokens[i]
  }
  return OFS
}

function print_field(field_val) {
  padded_field = field_val OFS
  printf "%s", padded_field
}


function debug_print(case) {
  if (case == -1) {
    print "----------- ARGS TESTS -------------"
  }
  if (case == 0) {
    print "---------- ARGS FINDINGS -----------"
    print_reo_r_count = pass_r ? "all/undefined" : reo_r_count
    print "Reorder count (row):", print_reo_r_count
    printf "Reorder vals (row): "
    if (pass_r) print "all"
    else {
      for (i = 1; i < reo_r_len; i++) printf "%s", ReoR[i] OFS
      print ReoR[reo_r_count] }
    print_reo_c_count = pass_c ? "all/undefined" : reo_c_count
    print "Reorder count (col):", print_reo_c_count
    printf "Reorder vals (col): "
    if (pass_c) print "all"
    else { for (i = 1; i < reo_c_len; i++) printf "%s", ReoC[i] OFS
      print ReoC[reo_c_count] }

  } else if (case == 1) {
    print "i: " i, " r_i: " r_i, " r_len: " r_len, " token: " token
  } else if (case == 1.5) {
    print "i: " i, " c_i: " c_i, " c_len: " c_len, " token: " token
  } else if (case == 2) {
    print "FillRange start: " start, " end: " end
  } else if (case == 3) {
    print arg, tk, tk_loc

  } else if (case == 4) {
    print "----------- CASE MATCHES -----------"
    if (indx) print "index case"
    if (base) print "base case"
    if (range) print "range case"
    if (mat) print "mat case"
    if (re) print "re case"
    if (reo) print "reo case"
    if (base_reo) print "base reo case"

  } else if (case == 5) {
    eval = EvalExpr(anchor base_expr)
    print anchor, base_expr, "evals to:", eval, "compare:", comp, compval

  } else if (case == 6) {
    if (length(RCExprs)) { print "------------- RCExprs --------------"
      for (ex in RCExprs) print ex, ExprFO[ex] }
    if (length(RCSearches)) { print "------------- RCSearches -------------"
      for (se in RCSearches) print se, SearchFO[se] }
  } else if (case == 7) {
    print "------ EVALS OR BASIC OUTPUT -------"
  } else if (case == 8) {
    print "------------- OUTPUT ---------------"
  }
}
