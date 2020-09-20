#!/usr/bin/awk
#
# Reorder, repeat or slice the rows and columns of fielded data
#
# Index a field value:
# > awk -f reorder.awk -v r=1 -v c=1
#
# Specific rows and/or columns:
# > awk -f reorder.awk -v r="{1..100}" -v c=1,4,5
#
# Range (and/or individual rows and columns):
# > awk -f reorder.awk -v r=1,100..200 -v c=1..3,5
#
# Reorder/repeat:
# > awk -f reorder.awk -v r=3,3,5,1 -v c=4-1,1,3,5
#
# Index numbers evaluating to expression (if no comparison specified, compares 
# if expression equal to zero):
# > awk -f reorder.awk -v r="NR**3%2+2,NR**3%2+2=1" -v c="NF<10"
#    Row numbers evaluating to 0 from these ^          ^ Only print fields
#    expressions will be printed in given order          with index <10
#
# Filter records by field values and/or fields by record values:
#
# -- Using basic numerical expressions, across the entire opposite span:
# > awk -f reorder.awk -v r="=1,<1" -v c="/5<10"
#     Rows with field val =1 ^         ^ Columns with field vals less than 10
#  Followed by rows with a field <1      when divided by 5
#
# -- Using numerical expressions, across given span:
# > awk -f reorder.awk      -v r="1,8<0" -v c="6!=10"
#   Print the header row followed by ^       ^ Fields where vals in row 6 are
#   rows where field 8 is negative             not equal to 10
#
# -- Using regeular expressions, across the opposite span (full or specified):
# > awk -f reorder.awk -v r="~plant,~[A-z]" -v c="3~[0-9]+\.[0-9]"
#     Rows matching "plant" ^                  ^ Columns where vals in row 3
#     Followed by rows with alpha chars          match simple decimal pattern
#
# Alternatively filter the cross-span by a current-span frame pattern (headers --
# first row and first column -- is default)
# > awk -f reorder.awk -v r="[Plant~flower" -v c="3[Alps>10000"
#     Rows where column header matches ^          ^ Columns where vals in col
#     "Plant" and column value matches "flower"     3 match "Alps" and which
#                                                   have number vals greater
#                                                   than 10000 (ft presumably)
#
# If no expression or search given with frame, simple search is done on the cross
# span, not the current span (frame rows by column, columns by row)
# > awk -f reorder.awk -v r="[Alps" -v c="[Plant"
#       Rows where first col ^            ^ Columns where first row
#       matches 'Alps'                      matches 'Plant'
#
# Note the above args are equivalent to r="1~Alps" c="1~Plant"
#
# TODO: quoted fields handling (external)
# TODO: nomatch regex comparison
# TODO: ignore case regex
# TODO: and/or extended logic
# TODO: reverse, other basic sorts
# TODO: mechanism for 'all the others, unspecified' (records or fields -
#   reverse all operations and add to end of order list


# SETUP

BEGIN {
  BuildRe(Re); BuildTokens(Tk); BuildTokenMap(TkMap)
  assume_constant_fields = 0
  base_r = 1; base_c = 1
  min_guar_print_nf = 1000
  min_guar_print_nr = 100000000

  if (debug) debug_print(-1)
  if (r) {
    split(r, r_order, Re["ordsep"])
    r_len = length(r_order)

    for (i = 1; i <= r_len; i++) {
      r_i = r_order[i]
      if (!r_i) continue

      token = r_i ~ Re["alltokens"] ? TokenPrecedence(r_i) : ""
      if (debug) debug_print(1)

      if (!token) {
        # Add reverse/sort cases here
        if (!(r_i ~ Re["int"])) continue
        reo_r_count = FillReoArr(1, r_i, R, reo_r_count, ReoR)
        if (!reo && r_i > max_r_i)
          max_r_i = r_i
        else
          reo = 1 }
      else {
        max_r_i = TestArg(r_i, max_r_i, token)
        base_r = 0

        if (token == "rng")
          reo_r_count = FillRange(1, r_i, R, reo_r_count, ReoR)
        else {
          if (token == "mat")
            reo_r_count = FillReoArr(1, r_i, RRExprs, reo_r_count, ReoR, token)
          else if (token == "re")
            reo_r_count = FillReoArr(1, r_i, RRSearches, reo_r_count, ReoR, token)
          else if (token == "fr") {
            RRFrames[r_i] = 1
            if (fr_ext) row_fr_ext = 1
            if (fr == "mat")
              reo_r_count = FillReoArr(1, r_i, RRExprs, reo_r_count, ReoR, fr)
            else if (fr == "re" && fr_idx)
              reo_r_count = FillReoArr(1, r_i, RRIdxSearches, reo_r_count, ReoR, fr)
            else if (fr == "re")
              reo_r_count = FillReoArr(1, r_i, RRSearches, reo_r_count, ReoR, fr)
          }
        }}}}
  else { pass_r = 1 }

  if (!reo_r_count) pass_r = 1

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
        # Add reverse/sort cases here
        if (!(c_i ~ Re["int"])) continue
        reo_c_count = FillReoArr(0, c_i, RangeC, reo_c_count, ReoC)
        if (!reo && c_i > max_c_i)
          max_c_i = c_i
        else {
          reo = 1; base_c = 0 }}
      else {
        delete c_order[i]
        max_c_i = TestArg(c_i, max_c_i, token)
        base_c = 0

        if (token == "rng")
          reo_c_count = FillRange(0, c_i, C, reo_c_count, ReoC)
        else {
          if (token == "mat")
            reo_c_count = FillReoArr(0, c_i, RCExprs, reo_c_count, ReoC, token)
          else if (token == "re")
            reo_c_count = FillReoArr(0, c_i, RCSearches, reo_c_count, ReoC, token)
          else if (token == "fr") {
            RCFrames[c_i] = 1
            if (fr == "mat")
              reo_c_count = FillReoArr(0, c_i, RCExprs, reo_c_count, ReoC, fr)
            else if (fr == "re" && fr_idx)
              reo_c_count = FillReoArr(0, c_i, RCIdxSearches, reo_c_count, ReoC, fr)
            else if (fr == "re")
              reo_c_count = FillReoArr(0, c_i, RCSearches, reo_c_count, ReoC, fr)
          }}}}}
  else { pass_c = 1 }

  if (!reo_c_count) pass_c = 1
  if (pass_r && pass_c) pass = 1
  if (r_len == 1 && c_len == 1 && !pass_r && !pass_c && !range && !reo)
    indx = 1
  else if (!range && !reo)
    base = 1
  else if (reo && !mat && !re)
    base_reo = 1

  if (mat && ARGV[1]) {
    "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0 }
  if (!(FS ~ "[.+]")) OFS = BuildOFSFromUnescapedFS()
  reo_r_len = length(ReoR)
  reo_c_len = length(ReoC)
  if (debug) { debug_print(0); debug_print(7) }
}



# SIMPLE PROCESSING/DATA GATHERING

indx { if (NR == r) { print $c; exit } next }

base { if (pass_r || NR in R) FieldsPrint(c_order, c_len); next }

range && !reo { if (pass_r || NR in R) FieldsPrint(ReoC, reo_c_len); next }

reo {
  if (NF > max_nf) max_nf = NF
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

  if (!pass_c && max_nf < min_guar_print_nf) {
    will_print = 0
    for (expr in ExprFO) {
      if (ExprFO[expr]) { will_print = 1; break }}
    for (search in SearchFO) {
      if (SearchFO[search]) { will_print = 1; break }}
    if (!will_print) {
      print "No matches found"
      exit 1 }}

  if (!pass_r && NR < min_guar_print_nr) {
    will_print = 0
    for (expr in ExprRO) {
      if (ExprRO[expr]) { will_print = 1; break }}  
    for (search in SearchRO) {
      if (SearchRO[search]) { will_print = 1; break }}
    if (!will_print) {
      print "No matches found"
      exit 1 }}

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
  token = TypeMap[key]
  if (token == "re") search = key
  else if (token == "mat") expr = key 

  if (reo_row_call) {
    if (token == "re") rows = SearchRO[search]
    else if (token == "mat") rows = ExprRO[expr]

    split(rows, PrintRows, ",")
    len_printr = length(PrintRows) - 1
    for (r = 1; r <= len_printr; r++) {
      if (pass_c) print CrossSpan[PrintRows[r]]
      else {
        for (j = 1; j <= reo_c_len; j++) {
          c_key = ReoC[j]
          row = CrossSpan[PrintRows[r]]
          split(row, Row, FS)
          if (c_key ~ Re["int"])
            print_field(Row[c_key], j, reo_c_len)
          else {
            if (j!=1) printf "%s", OFS
            Reo(c_key, Row, 0) }}

        print "" }}}

  else {
    if (token == "re") fields = SearchFO[search]
    else if (token == "mat") fields = ExprFO[expr]

    split(fields, PrintFields, ",")
    len_printf = length(PrintFields) - 1
    for (f = 1; f <= len_printf; f++) {
      print_field(CrossSpan[PrintFields[f]], f, len_printf) }}
}

function FieldsPrint(Order, ord_len) {
  if (pass_c) print $0
  else {
    for (i = 1; i < ord_len; i++)
      printf "%s", $Order[i] OFS

    print $Order[ord_len] }
}

function FillRange(row_call, range_arg, RangeArr, reo_count, ReoArr) {
  split(range_arg, RngAnc, TkMap["rng"])
  start = RngAnc[1]; end = RngAnc[2]

  if (debug) debug_print(2)

  if (start > end) { reo = 1
    for (k = start; k >= end; k--)
      reo_count = FillReoArr(row_call, k, RangeArr, reo_count, ReoArr) }
  else {
    for (k = start; k <= end; k++)
      reo_count = FillReoArr(row_call, k, RangeArr, reo_count, ReoArr) }

  return reo_count
}

function FillReoArr(row_call, val, KeyArr, count, ReoArray, type) {
  KeyArr[val] = 1
  count++
  ReoArray[count] = val
  if (type)
    TypeMap[val] = type
  else if (row_call && val < min_guar_print_nr)
    min_guar_print_nr = val
  else if (!row_call && val < min_guar_print_nf)
    min_guar_print_nf = val
  
  return count
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
    for (search in RCIdxSearches) {
      split(search, Fr, "[")
      if (fr_ext) { test_row = Fr[1] ? Fr[1] : 1 }
      else test_row = 1
      if (NR != test_row) continue
      base_search = Fr[2]
      for (f = 1; f <= NF; f++) {
        if ($f ~ base_search) SearchFO[search] = SearchFO[search] f","
      }}

    for (search in RCSearches) {
      split(search, Tmp, "~")
      base_search = Tmp[2]
      if (search in RCFrames) {
        split(Tmp[1], Fr, "[")
        if (fr_ext) { test_field = Fr[1] ? Fr[1] : 1 }
        else test_field = 1
        if (!($test_field ~ Fr[2])) continue
        if (!base_search) {
            print test_field, $test_field, Fr[2]
          searchkey = SUBSEP search
          if (!FrRowIdxSet[search]) {
            FrRowIdxSet[search] = 1; reo_r_count++
            ReoR[reo_r_count] = searchkey }
          SearchRO[searchkey] = SearchRO[searchkey] NR","
          continue }
        else if (!Indexed(SearchFO[search], test_field)) {
          SearchFO[search] = SearchFO[search] test_field"," }}
      else if (Tmp[1] ~ Re["num"]) { 
        if (NR != Tmp[1]) continue }

      for (f = 1; f <= NF; f++) {
        if (Indexed(SearchFO[search], f)) continue
        if (debug) debug_print(9) 
        if ($f ~ base_search) SearchFO[search] = SearchFO[search] f","
        }}}

  if (mat) {
    for (expr in RCExprs) {
      if (assume_constant_fields && RCExprFieldsSet[expr]) continue
      # ^ may result in missed fields unless the number of fields of first row
      # is gt or equal to number of fields in all other rows
      compval = 0; settable = 0
      if (expr in RCFrames) {
        split(expr, Tmp, TkMap["mat"])
        split(Tmp[1], Fr, "[")
        if (fr_ext) { test_field = Fr[1] ? Fr[1] : 1 }
        else test_field = 1
        if (!($test_field ~ Fr[2])) continue
        if (!Indexed(ExprFO[expr], test_field)) {
          ExprFO[expr] = ExprFO[expr] test_field"," } 
        base_expr = substr(expr, length(Tmp[1])+1)
        anchor_row = max_nr }
      else if (substr(expr, 1, 1) ~ Re["intmat"]) { # TODO: put this type of check in TestArg
        split(expr, Tmp, Re["nan"])
        if (Tmp[1]) {
          if (NR != Tmp[1]) continue
          else anchor_row = Tmp[1] }
        else anchor_row = max_nr
        base_expr = substr(expr, length(Tmp[1])+1) }
      else { base_expr = expr; settable = 1; anchor_row = max_nr
        RCExprFieldsSet[expr] = 1 }

      if (base_expr ~ Re["comp"]) { GetComp(base_expr)
        comp = Tmp[0]; base_expr = Tmp[1]; compval = Tmp[2] }
      
      for (f = 1; f <= NF; f++) {
        if (Indexed(ExprFO[expr], f)) continue
        if (settable) anchor = f
        else if ($f ~ Re["decnum"]) {
          anchor = $f; gsub(",", "", anchor) }
        else if (comp == "!=") anchor = ""
        else continue
        eval = EvalExpr(anchor base_expr)
        if (debug) debug_print(5)
        if (comp == "!=") {
          if (!ExcludeCol[expr, f]) {
            if (eval == compval) ExcludeCol[expr, f] = 1
            else if (NR == anchor_row) ExprFO[expr] = ExprFO[expr] f"," }
          continue }
        if (EvalCompExpr(eval, compval, comp))
            ExprFO[expr] = ExprFO[expr] f","
      }}}
}

function StoreRowRefs() {
  # Checks a single row for each expression and search pattern, if applicable,
  # and stores relevant row numbers. Rows can be made non-applicable by filters
  # within the first subargs of the reo arg.
  if (re) {
    for (search in RRIdxSearches) {
      split(search, Fr, "[")
      if (fr_ext) { test_field = Fr[1] ? Fr[1] : 1 }
      else test_field = 1
      if (!($test_field ~ Fr[2])) continue
      SearchRO[search] = SearchRO[search] NR"," }}

    for (search in RRSearches) {
      fr_search = 0
      split(search, Tmp, "~")
      base_search = Tmp[2]
      if (search in RRFrames) {
        if (ExcludeFrame[search]) continue
        start = 1; end = NF; fr_search = 1
        split(Tmp[1], Fr, "[")
        if (row_fr_ext) { test_row = Fr[1] ? Fr[1] : 1 }
        else test_row = 1
        frame_re = Fr[2] }
      else if (Tmp[1] ~ Re["num"]) { start = Tmp[1]; end = start }
      else { start = 1; end = NF }

      for (f = start; f <= end; f++) {
        if (fr_search) {
          if (FrameSet[search]) {
            if (!Indexed(FrameFields[search], f)) continue }
          else if (NR == test_row) {
            if ($f ~ frame_re) {
              if (!Indexed(SearchRO[search], NR))
                FrameFields[search] = FrameFields[search] f"," }
            if (f == end) {
              if (FrameFields[search]) # TODO: Should this be kept as a flag setting or default behavior?
                SearchRO[search] = SearchRO[search] NR","
              ResolveRowFilterFrame(search) }
          else {
            if (!Indexed(FrameRowFields[search], f) && $f ~ base_search)
              FrameRowFields[search] = FrameRowFields[search] NR":"f","
            continue }}}
        if (Indexed(SearchRO[search], NR)) continue
        if (debug) debug_print(9)
        if ($f ~ base_search) SearchRO[search] = SearchRO[search] NR","
        }}

  if (mat) {
    for (expr in RRExprs) {
      compval = 0; position_test = 0; fr_expr = 0
      if (expr in RRFrames) {
        if (ExcludeFrame[expr]) continue
        split(expr, Tmp, TkMap["mat"])
        split(Tmp[1], Fr, "[")
        if (row_fr_ext) { test_row = Fr[1] ? Fr[1] : 1 }
        else test_row = 1
        base_expr = substr(expr, length(Tmp[1])+1)
        start = 1; end = NF; fr_expr = 1
        frame_re = Fr[2] }
      else if (substr(expr, 1, 1) ~ Re["intmat"]) { # TODO: put this type of check in TestArg
        split(expr, Tmp, Re["nan"])
        if (Tmp[1]) {
          start = Tmp[1]; end = start }
        else { start = 1; end = NF }
        base_expr = substr(expr, length(Tmp[1])+1) }
      else {
        base_expr = expr; position_test = 1 
        start = 1; end = NF }

      anchor_col = end

      if (base_expr ~ Re["comp"]) { GetComp(base_expr)
        comp = Tmp[0]; base_expr = Tmp[1]; compval = Tmp[2] }

      for (f = start; f <= end; f++) {
        if (fr_expr) {
          frame_set = FrameSet[expr]
          if (frame_set) {
            if (!Indexed(FrameFields[expr], f)) continue }
          else if (NR == test_row) {
            if ($f ~ frame_re) {
              if (!Indexed(ExprRO[expr], NR))
                FrameFields[expr] = FrameFields[expr] f"," }
            if (f == end) {
              if (FrameFields[expr]) # TODO: Should this be kept as a flag setting or default behavior?
                ExprRO[expr] = ExprRO[expr] NR","
              ResolveRowFilterFrame(expr) 
            }}}
        if (Indexed(ExprRO[expr], NR)) continue
        if (position_test) { if (f > 1) break; else anchor = NR }
        else if ($f ~ Re["decnum"]) {
          anchor = $f; gsub(",", "", anchor) }
        else if (comp == "!=") anchor = ""
        else continue
        eval = EvalExpr(anchor base_expr)
        if (debug) debug_print(5)
        if (comp == "!=") {
          if (!ExcludeRow[expr, NR]) {
            if (eval == compval) ExcludeRow[expr, NR] = 1
            else if (f == anchor_col) ExprRO[expr] = ExprRO[expr] NR"," }
          continue }
        if (EvalCompExpr(eval, compval, comp)) {
          if (fr_expr && !frame_set) {
            if (!Indexed(FrameRowFields[search], f))
              FrameRowFields[search] = FrameRowFields[search] NR":"f"," }
          else
            ExprRO[expr] = ExprRO[expr] NR","
        }}}}
}

function ResolveRowFilterFrame(frame) {
  fr_type = TypeMap[frame]
  if (!FrameFields[frame]) {
    ExcludeFrame[frame] = 1
    if (fr_type == "re") SearchRO[frame] = ""
    else if (fr_type == "mat") ExprRO[frame] = ""
    return }
  FrameFieldsTest = FrameFields[frame]
  split(FrameRowFields[frame], FrameRowsTest, ",")
  for (i in FrameRowsTest) {
    split(i, RowField, ":")
    row = RowField[1]
    field = RowField[2]
    if (Indexed(FrameFieldsTest, field)) {
      if (fr_type == "re") SearchRO[frame] = SearchRO[frame] row","
      else if (fr_type == "mat" ) ExprRO[frame] = ExprRO[frame] row"," }}
  FrameSet[frame] = 1
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
      print "Invalid order expression arg " arg " - expression format examples include: "
      print "NR%2  2%3=5  NF!=4  *6/8%2=1"
      exit 1 }}

  else if (type == "re") { reo = 1; re = 1
    re_test = substr(arg, length(sa1)+1, length(arg))
    if ("" ~ re_test) {
      print "Invalid order search range arg - search arg format examples include: ~search  2~search"
      exit 1 }}

  else if (type == "fr") { reo = 1; fr_idx = 0
    split(arg, Tmp, "[")
    if (Tmp[1]) fr_ext = 1
    if (arg ~ Re["frmat"]) {
      fr = "mat"; mat = 1 }
    else if (arg ~ Re["frre"]) {
      fr = "re"; re = 1 }
    else if (Tmp[2]) {
      fr = "re"; re = 1; fr_idx = 1; FrIdx[arg] = 1 }
    else {
      print "Invalid order frame arg - frame arg format examples include: "
      print "[RowHeaderPattern 5[Index5Pattern~search  [HeaderPattern!=30"
      exit 1 }}

  return max_i
}

function Indexed(idx_ord, test_idx) {
  test_re = "^" test_idx ",|," test_idx ",|:" test_idx ","
  return idx_ord ~ test_re
}

function BuildRe(Re) {
  Re["num"] = "[0-9]+"
  Re["int"] = "^[0-9]+$"
  Re["decnum"] = "^[[:space:]]*(\\-)?(\\()?[0-9,]+([\.][0-9]*)?(\\))?[[:space:]]*$"
  Re["intmat"] = "[0-9!\\+\\-\\*\/%\\^<>=]"
  Re["nan"] = "[^0-9]"
  Re["matarg1"] = "^[0-9\\+\\-\\*\\/%\\^]+((!=|[=<>])[0-9]+)?$"
  Re["matarg2"] = "^(NR|NF)?(!=|[=<>])[0-9]+$"
  Re["frmat"] = "\\[.+(!=|[=<>])[0-9]+$" #]
  Re["frre"] = "\\[.+~.+" #]
  Re["ordsep"] = ",+"
  Re["comp"] = "(<|>|!?=)"
  Re["alltokens"] = "[(\\.\\.)\\~\\+\\-\\*\\/%\\^<>(!=)=\\[]"
  Re["ws"] = "^[:space:]+$"
}

function BuildTokenMap(TkMap) {
  TkMap["rng"] = "\\.\\."
  TkMap["fr"] = "\\[" #]
  TkMap["re"] = "!?\~"
  TkMap["mat"] = "(!=|[\\+\\-\\*\/%\\^<>=])"
}

function BuildTokens(Tk) {
  Tk[".."] = "rng"
  Tk["!~"] = "re"
  Tk["~"] = "re"
  Tk["["] = "fr" #]]
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

function EvalCompExpr(left, right, comp) {
  return (comp == "="  && left == right) ||
         (comp == ">"  && eval > compval) ||
         (comp == "<"  && eval < compval)
}

function GetComp(string) {
  if (string ~ ">") comp = ">"
  else if (string ~ "<") comp = "<"
  else if (string ~ "!=") comp = "!="
  else comp = "="

  split(string, Tmp, comp)
  Tmp[0] = comp
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
    if (fr) print "header/frame base case"
    if (fr_ext) print "frame extended case" }

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
    print "f: " f, "search: " search, "base search: " base_search, "startf: " start, "endf: " end, "fieldval: " $f }

}
