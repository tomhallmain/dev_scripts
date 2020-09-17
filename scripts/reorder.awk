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
# Index Numbers Evaluating to Expression (if no comparison specified, compares 
# if expression equal to zero):
# > awk -f reorder.awk -v r="NR**3%2+2,NR**3%2+2=1" -v c="NF<10"
#    Row numbers evaluating to 0 from these ^          ^ Only print fields
#    expressions will be printed in given order          with index <10
#
# Filter Records by Field Values and/or Fields by Record Values:
# -- Using basic numerical expressions, across the entire opposite span:
# > awk -f reorder.awk -v r="=1,<1" -v c="/5<10"
#     Rows with field val =1 ^         ^ Columns with field vals less than 10
#  Followed by rows with a field <1      when divided by 5
#
# -- Using numerical expressions, across a specified cross span:
# > awk -f reorder.awk      -v r="1,8<0" -v c="6!=10"
#   Print the header row followed by ^       ^ Fields where vals in row 6 are
#   rows where field 8 is negative             not equal to 10
#
# -- Using regeular expressions, across the opposite span (full or specified):
# > awk -f reorder.awk -v r="~plant,~[A-z]" -v c="3~[0-9]+\.[0-9]"
#     Rows matching "plant" ^                  ^ Columns where vals in row 3
#     Followed by rows with alpha chars          match simple decimal pattern
#
# Alternatively filter the cross span by a header (first row and first column
# is default)
# > awk -f reorder.awk -v r="[Plant~flower" -v c="3[Alps>10000"
#     Rows where column header matches ^          ^ Columns where vals in col
#     "Plant" and column value matches "flower"     3 matches "Alps" and which
#                                                   are greater than 10000
#
#
# TODO: quoted fields handling
# TODO: reverse case
# TODO: nomatch regex comparison
# TODO: mechanism for 'all the others, unspecified' (records or fields)
# TODO: error exit for no matches found


# SETUP

BEGIN {
  BuildRe(Re); BuildTokens(Tk); BuildTokenMap(TkMap)
  assume_constant_fields = 0 # TODO: Better mechanism for this
  base_r = 1; base_c = 1

  if (debug) debug_print(-1)
  if (r) {
    split(r, r_order, Re["ordsep"])
    r_len = length(r_order)

    for (i = 1; i <= r_len; i++) {
      r_i = r_order[i]
      if (!r_i) { print "Skipping unparsable 0 row arg"; continue }

      token = r_i ~ Re["alltokens"] ? TokenPrecedence(r_i) : ""
      if (debug) debug_print(1)

      if (!token) {
        if (!(r_i ~ Re["int"])) continue
        reo_r_count = FillReoArr(r_i, R, reo_r_count, ReoR)
        if (!reo && r_i > max_r_i)
          max_r_i = r_i
        else
          reo = 1 }
      else {
        max_r_i = TestArg(r_i, max_r_i, token)

        if (token == "rng")
          reo_r_count = FillRange(r_i, R, reo_r_count, ReoR)
        else {
          if (token == "mat")
            reo_r_count = FillReoArr(r_i, RRExprs, reo_r_count, ReoR, token)
          else if (token == "re")
            reo_r_count = FillReoArr(r_i, RRSearches, reo_r_count, ReoR, token)
          else if (token == "head") {
            if (headtype == "mat")
              reo_r_count = FillReoArr(r_i, RRHeadExprs, reo_r_count, ReoR, "mat")
            else if (headtype == "re")
              reo_r_count = FillReoArr(r_i, RRHeadSearches, reo_r_count, ReoR, "re")
          }
        }}}}
  else { pass_r = 1 }
  if (!reo_r_count) pass_r = 1
  if (reo) base_r = 0

  if (c) {
    split(c, c_order, Re["ordsep"])
    c_len = length(c_order)

    for (i = 1; i <= c_len; i++) {
      c_i = c_order[i]
      if (!c_i) {
        print "Skipping unparsable 0 col arg"
        delete c_order[i] }

      token = c_i ~ Re["alltokens"] ? TokenPrecedence(c_i) : ""
      if (debug) debug_print(1.5)

      if (!token) {
        if (!(c_i ~ Re["int"])) continue
        reo_c_count = FillReoArr(c_i, RangeC, reo_c_count, ReoC)
        if (!reo && c_i > max_c_i)
          max_c_i = c_i
        else {
          reo = 1; base_c = 0 }}
      else {
        delete c_order[i]
        max_c_i = TestArg(c_i, max_c_i, token)
        base_c = 0

        if (token == "rng")
          reo_c_count = FillRange(c_i, C, reo_c_count, ReoC)
        else {
          if (token == "mat")
            reo_c_count = FillReoArr(c_i, RCExprs, reo_c_count, ReoC, token)
          else if (token == "re")
            reo_c_count = FillReoArr(c_i, RCSearches, reo_c_count, ReoC, token)
        }}}}
  else { pass_c = 1 }
  if (!reo_c_count) pass_c = 1

  if (pass_r && pass_c) pass = 1

  if (r_len == 1 && c_len == 1 && !pass_r && !pass_c && !range && !reo)
    indx = 1
  else if (!range && !reo)
    base = 1
  else if (reo && !mat && !re)
    base_reo = 1

  if (mat && ARGV[1]) { # TODO: this for stdin case
    "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0 }
  if (!(FS ~ "[.+]")) OFS = BuildOFSFromUnescapedFS()
  reo_r_len = length(ReoR)
  reo_c_len = length(ReoC)
  if (debug) debug_print(0)
  if (debug) debug_print(7)
}



# SIMPLE PROCESSING/DATA GATHERING

indx { if (NR == r) { print $c; exit } next }

base { if (pass_r || NR in R) FieldBase(); next }

range && !reo { if (pass_r || NR in R) FieldRange(); next }

head {
  if (NR == 1) { StoreHeaders(Headers, 0); next }
  else StoreHeaders(Headers, 1)
}

reo {
  if (pass_r) {
    if (base_reo) {
      for (i = 1; i < reo_c_len; i++)
        printf "%s", $ReoC[i] OFS

      print $ReoC[reo_c_len] }
    else {
      StoreRow(_)
      StoreFieldRefs() }}
  else {
    row_os = 1
    if (NR in R) {
      StoreRow(_)
      if (base_reo) next }

    if (row_os) StoreRow(_)
    if (!base_c) StoreFieldRefs()
    if (!base_r) StoreRowRefs() } 

  next
}

pass { print $0 }



# FINAL PROCESSING FOR REORDER CASES

END {
  if (debug) debug_print(4) 
  if (err || !reo || (base_reo && pass_r)) exit err
  if (debug) {
    (!pass_c) debug_print(6)
    debug_print(8) }

  if (pass_r) {
    for (i = 1; i <= length(_); i++) {
      for (j = 1; j <= reo_c_len; j++) {
        c_key = ReoC[j]
        row = _[i]
        split(row, Row, FS)
        if (c_key ~ Re["int"])
          print_field(Row[c_key], j, reo_c_len)
        else {
          if (j!=1) printf "%s", OFS
          Reo(c_key, Row, 0) }}

      print "" }

    exit }

  for (i = 1; i <= length(ReoR); i++) {
    r_key = ReoR[i]
    if (pass_c && base_reo) print _[r_key]
    else {
      if (r_key ~ Re["int"]) {
        if (pass_c) print _[r_key]
        else {
          for (j = 1; j <= reo_c_len; j++) {
            c_key = ReoC[j]
            row = _[r_key]
            split(row, Row, FS)
            if (c_key ~ Re["int"])
              print_field(Row[c_key], j, reo_c_len)
            else {
              if (j!=1) printf "%s", OFS
              Reo(c_key, Row, 0) }}

          print "" }}
      else Reo(r_key, _, 1)
    }}
}



# FUNCTIONS

function Reo(key, CrossSpan, reo_row_call) {
  anchor_unset = 0
  token = TypeMap[key]
  if (token == "re") {
    search = key
    if (substr(search, 1, 1) ~ Re["num"]) {
      split(search, tmp, Re["nan"])
      base_search = substr(search, length(tmp[1])+1, length(search))
      anchor = CrossSpan[tmp[1]] }
    else { base_search = search; anchor_unset = 1 }}
  else if (token == "mat") {
    expr = key
    comp = "="; compval = 0
    if (substr(expr, 1, 1) ~ Re["num"]) {
      split(expr, tmp, Re["nan"])
      base_expr = substr(expr, length(tmp[1])+1, length(expr))
      anchor = CrossSpan[tmp[1]] }
    else anchor_unset = 1

    if (base_expr ~ Re["comp"]) {
      if (base_expr ~ ">") comp = ">"
      else if (base_expr ~ "<") comp = "<"
      else if (base_expr ~ "!=") comp = "!="
      else comp = "="

      split(base_expr, tmp, comp)
      base_expr = tmp[1]
      compval = tmp[2]
    }}
  
  if (reo_row_call) {
    if (token == "re")
      rows = SearchRO[search]
    else if (token == "mat")
      rows = ExprRO[expr]

    split(rows, PrintRows, ",")
    len_printr = length(PrintRows)
    len_printr--
    for (r = 1; r <= len_printr; r++) {
      if (pass_c) print _[r]
      else {
        for (j = 1; j <= reo_c_len; j++) {
          c_key = ReoC[j]
          row = CrossSpan[PrintRows[r]]
          split(row, Row, FS)
          if (c_key ~ Re["int"])
            print_field(Row[c_key], j, reo_c_len)
          else {
            if (j!=1) printf "%s", OFS
            Reo(c_key, Row, 0) }}}

      print "" }}

  else {
    if (token == "re")
      fields = SearchFO[search]
    else if (token == "mat")
      fields = ExprFO[expr]

    split(fields, PrintFields, ",")
    len_printf = length(PrintFields)
    len_printf--
    for (f = 1; f <= len_printf; f++) {
      print_field(CrossSpan[PrintFields[f]], f, len_printf) }}
}

function FieldBase() {
  if (pass_c) print $0
  else {
    for (i = 1; i < c_len; i++)
      printf "%s", $c_order[i] OFS

    print $c_order[c_len] }
}

function FieldRange() {
  if (pass_c) print $0
  else {
    for (i = 1; i < reo_c_count; i++)
      printf "%s", $ReoC[i] OFS

    print $ReoC[reo_c_count] }
}


function FillRange(range_arg, RangeArr, reo_count, ReoArr) {
  split(range_arg, RngAnc, TkMap["rng"])
  start = RngAnc[1]; end = RngAnc[2]

  if (debug) debug_print(2)

  if (start > end) { reo = 1
    for (k = start; k >= end; k--)
      reo_count = FillReoArr(k, RangeArr, reo_count, ReoArr) }
  else {
    for (k = start; k <= end; k++)
      reo_count = FillReoArr(k, RangeArr, reo_count, ReoArr) }

  return reo_count
}

function FillReoArr(val, KeyArr, count, ReoArray, type) {
  KeyArr[val] = 1
  count++
  ReoArray[count] = val
  if (type) TypeMap[val] = type

  return count
}

function StoreHeaders(Headers, row) {
  if (row) Headers[NR] = $1
  else {
    for (f = 1; f <= nf; f++)
      Headers[f] = $f }
}

function StoreRow(_) {
  _[NR] = $0
  row_os = 0
}

function StoreFieldRefs() {
  # Check each field for each expression and search pattern, if applicable and
  # not already positively linked. Fields can be made non-applicable by field 
  # filter within the first subarg of the reo arg.
  if (re) {
    for (search in RCSearches) {
      split(search, tmp, "~")
      base_search = tmp[2]
      if (tmp[1] ~ Re["num"]) {
        start = tmp[1]; end = start }
      else { start = 1; end = NF } # TODO: figure out short circuit for this case

      if (debug) debug_print(9) 

      for (f = start; f <= end; f++) {
        if (!(SearchFO[search] ~ f",") && $f ~ base_search) {
          SearchFO[search] = SearchFO[search] f","
        }}}}

  if (mat) {
    for (expr in RCExprs) {
      if (assume_constant_fields && RCExprFieldsSet[expr]) continue
      # ^ may result in missed fields unless the number of fields of first row
      # is gt or equal to number of fields in all other rows
      compval = 0; settable = 0
      if (substr(expr, 1, 1) ~ Re["intmat"]) { # TODO: put this type of check in TestArg
        split(expr, tmp, Re["nan"])
        if (tmp[1]) {
          if (NR != tmp[1]) continue
          else anchor_row = tmp[1] }
        else anchor_row = max_nr
        base_expr = substr(expr, length(tmp[1])+1, length(expr)) }
      else { base_expr = expr; settable = 1; anchor_row = max_nr
        RCExprFieldsSet[expr] = 1 }

      if (base_expr ~ Re["comp"]) {
        if (base_expr ~ ">") comp = ">"
        else if (base_expr ~ "<") comp = "<"
        else if (base_expr ~ "!=") comp = "!="
        else comp = "="

        split(base_expr, tmp, comp)
        base_expr = tmp[1]
        compval = tmp[2] }

      for (f = 1; f <= NF && !(ExprFO[expr] ~ f","); f++) {
        if (settable) anchor = f
        else if ($f ~ Re["decnum"]) anchor = $f
        else if (comp == "!=") anchor = ""
        else continue
        eval = EvalExpr(anchor base_expr)
        if (debug) debug_print(5)
        if (comp == "!=") {
          if (!ExcludeCol[expr, f]) {
            if (eval == compval) ExcludeCol[expr, f] = 1
            else if (NR == anchor_row) ExprFO[expr] = ExprFO[expr] f"," }
          continue }
        if ((comp == "="  && eval == compval) ||
            (comp == ">"  && eval > compval)  ||
            (comp == "<"  && eval < compval)) {
            ExprFO[expr] = ExprFO[expr] f","
        }}}}
}

function StoreRowRefs() {
  # Checks a single row for each expression and search pattern, if applicable,
  # and stores relevant row numbers. Rows can be made non-applicable by filter
  # within the first subarg of the reo arg.
  if (re) {
    for (search in RRSearches) {
      split(search, tmp, "~")
      base_search = tmp[2]
      if (tmp[1] ~ Re["num"]) test_field = tmp[1]
      else test_field = 0

      if (debug) debug_print(9) 

      if ($test_field ~ base_search)
        SearchRO[search] = SearchRO[search] NR"," }}

  if (mat) {
    for (expr in RRExprs) {
      compval = 0; position_test = 0
      if (substr(expr, 1, 1) ~ Re["intmat"]) { # TODO: put this type of check in TestArg
        split(expr, tmp, Re["nan"])
        if (tmp[1]) {
          start = tmp[1]; end = start }
        else { start = 1; end = NF }
        base_expr = substr(expr, length(tmp[1])+1, length(expr)) }
      else {
        base_expr = expr; position_test = 1 
        start = 1; end = NF }

      anchor_col = end

      if (base_expr ~ Re["comp"]) {
        if (base_expr ~ ">") comp = ">"
        else if (base_expr ~ "<") comp = "<"
        else if (base_expr ~ "!=") comp = "!="
        else comp = "="

        split(base_expr, tmp, comp)
        base_expr = tmp[1]
        compval = tmp[2] }

      for (f = start; f <= end && !(ExprRO[expr] ~ NR","); f++) {
        if (position_test) { if (f > 1) break; else anchor = NR }
        else if ($f ~ Re["decnum"]) anchor = $f
        else if (comp == "!=") anchor = ""
        else continue
        eval = EvalExpr(anchor base_expr)
        if (debug) debug_print(5)
        if (comp == "!=") {
          if (!ExcludeRow[expr, NR]) {
            if (eval == compval) ExcludeRow[expr, NR] = 1
            else if (f == anchor_col) ExprRO[expr] = ExprRO[expr] NR"," }
          continue }
        if ((comp == "="  && eval == compval) ||
            (comp == ">"  && eval > compval)  ||
            (comp == "<"  && eval < compval)) {
            ExprRO[expr] = ExprRO[expr] NR","
        }}}}
}

function TokenPrecedence(arg) {
  found_token = ""; loc_min = 100000
  for (tk in Tk) {
    tk_loc = index(arg, tk)
    if (debug) debug_print(3, arg)
    if (tk_loc && tk_loc < loc_min) {
      loc_min = tk_loc
      found_token = Tk[tk] }
    if (tk_loc == 1) break }
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
      max_i = ra2 }}

  else if (type == "mat") { reo = 1; mat = 1
    for (sa_i = 2; sa_i <= length(Subargv); sa_i++) {
      if (!(Subargv[sa_i] ~ Re["int"])) nonint_sarg = 1
    }
    if (nonint_sarg || !(arg ~ Re["matarg1"] || arg ~ Re["matarg2"])) {
      print "Invalid order expression arg " arg " - expression format examples include: NR%2  2%3=5  NF!=4  *6/8%2=1"
      exit 1 }}

  else if (type == "re") { reo = 1; re = 1
    re_test = substr(arg, length(sa1)+1, length(arg))
    if ("" ~ re_test) {
      print "Invalid order search range arg - search arg format examples include: ~search  2~search"
      exit 1 }}

  else if (type == "head") { reo = 1; head = 1
    if (arg ~ Re["headmat"]) {
      head = "mat"; mat = 1 }
    else if (arg ~ Re["headre"]) {
      head = "re"; re = 1 }
    else {
      print "Invalid order header search arg - search arg format examples include: [colheader~search  [rowheader!=30"
      exit 1 }}

  return max_i
}

function BuildRe(Re) {
  Re["num"] = "[0-9]+"
  Re["int"] = "^" Re["num"] "$"
  Re["decnum"] = "^[[:space:]]*(\\-)?(\\()?[0-9]+([\.][0-9]*)?(\\))?[[:space:]]*$"
  Re["intmat"] = "[0-9!\\+\\-\\*\/%\\^<>=]"
  Re["nan"] = "[^0-9]"
  Re["matarg1"] = "^[0-9\\+\\-\\*\\/%\\^]+((!=|[=<>])" Re["num"] ")?$"
  Re["matarg2"] = "^(NR|NF)?(!=|[=<>])" Re["num"] "$"
  Re["headmat"] = "\\[.+(!=|[=<>])" Re["num"] "$" #]
  Re["headre"] = "\\[.+~.+" #]
  Re["ordsep"] = "[ ,]+"
  Re["comp"] = "(<|>|!?=)"
  Re["alltokens"] = "[(\\.\\.)\\~\\+\\-\\*\\/%\\^<>(!=)=\\[]"
}

function BuildTokenMap(TkMap) {
  TkMap["rng"] = "\\.\\."
  TkMap["head"] = "\\[" #]
  TkMap["re"] = "!?\~"
  TkMap["mat"] = "(!=|[\\+\\-\\*\/%\\^<>=])"
}

function BuildTokens(Tk) {
  Tk[".."] = "rng"
  Tk["!~"] = "re"
  Tk["~"] = "re"
  Tk["["] = "head" #]]
  Tk["="] = "mat"
  Tk["!="] = "mat"
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

function print_field(field_val, field_no, end_field_no) {
  if (!(field_no == end_field_no)) field_val = field_val OFS
  printf "%s", field_val
}


function debug_print(case, arg) {
  if (case == -1) {
    print "----------- ARGS TESTS -------------" }
  else if (case == 0) {
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
    if (max_nr) print "max_nr: " max_nr }

  else if (case == 1) {
    print "i: " i, " r_i: " r_i, " r_len: " r_len, " token: " token }
  else if (case == 1.5) {
    print "i: " i, " c_i: " c_i, " c_len: " c_len, " token: " token }
  else if (case == 2) {
    print "FillRange start: " start, " end: " end }
  else if (case == 3) {
    print arg, tk, tk_loc }
  else if (case == 4) {
    print "----------- CASE MATCHES -----------"
    if (indx) print "index case"
    if (base) print "base case"
    else if (base_r) print "base row case"
    else if (base_c) print "base column case"
    if (reo) print "reorder case"
    if (base_reo) print "base reorder case"
    if (range) print "range case"
    if (mat) print "expression case"
    if (re) print "search case" 
    if (head) print "header case" }

  else if (case == 5) {
    print "f: " f, "anchor: " anchor, "apply to: " base_expr, "evals to:", eval, "compare:", comp, compval }
  else if (case == 6) {
    if (length(RRExprs)) { print "------------- RRExprs --------------"
      for (ex in RRExprs) print ex, ExprRO[ex] }
    if (length(RRSearches)) { print "------------- RRSearches -------------"
      for (se in RRSearches) print se, SearchRO[se] }
    if (length(RCExprs)) { print "------------- RCExprs --------------"
      for (ex in RCExprs) print ex, ExprFO[ex] }
    if (length(RCSearches)) { print "------------- RCSearches -------------"
      for (se in RCSearches) print se, SearchFO[se] }}
  else if (case == 7) {
    print "------ EVALS OR BASIC OUTPUT -------" }
  else if (case == 8) {
    print "------------- OUTPUT ---------------" }
  else if (case == 9) {
    print search, base_search, start, end  }

}
