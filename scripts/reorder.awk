#!/usr/bin/awk
# DS:REO
#
# NAME
#       ds:reo, reorder.awk
#
# SYNOPSIS
#       ds:reo [-h|--help|file] [r_args_str] [c_args_str] [prefield=true] [awkargs]
#
# DESCRIPTION
#       reorder.awk is a script that reorders, repeats, or slices the rows and columns of 
#       fielded data. It can also be used on non-fielded data but its usefulness may be 
#       limited to rows in that case.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based 
#       systems it should be), and call it on a file:
#
#          > awk -f reorder.awk -v r=1 -v c=1 file
#
#       r and c refer to row and column order args respectively.
#
#       Comma is the order arg separator. To escape a comma, it must have two backslashes 
#       when passed to AWK, so it must have three backslashes if in double quotes, or two 
#       in single quotes:
#
#          > awk -f reorder.awk -v r="~\\\," c='~\\,'
#
#       ds:reo is the caller function for the reorder.awk script. To run any of the 
#       examples below, map AWK args as given in SYNOPSIS. For example, to print columns 
#       where the header matches "ZIP" on the first row where rows match "Main St":
#
#          $ ds:reo addresses.csv "1,~Main St" "[ZIP" -v cased=1
#
#       When running with piped data, args are shifted:
#
#          $ data_in | ds:reo [r_args_str] [c_args_str] [prefield=true] [awkargs]
#
# FIELD CONSIDERATIONS
#       When running ds:reo, an attempt is made to infer a field separator of up to
#       three characters. If none is found, FS will be set to default value, a single 
#       space = " ". To override the FS, add as a trailing awkarg. Be sure to escape 
#       and quote if needed. AWK's extended regex can be used as FS:
#
#          $ ds:reo a 1,4 -v FS=" {2,}"
#
#          $ ds:reo 7..1 1..4 -v FS='[A-z]+'
#
#          $ ds:reo a rev -F'\\\|\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:reo addresses.csv '[ZIP%3' a -v FS=""
#
#       When running ds:reo, an attempt is made to extract relevant instances of field 
#       separators in the case that a field separator appears in field values. To turn this 
#       off set prefield to false in the positional arg.
#
#          $ ds:reo simple_data.csv 1,500..2 a [f|false]
#
#       If ds:reo detects it is connected to a terminal, it will attempt to fit the data 
#       into the terminal width using the same field separator. If the data is being sent to 
#       a file or a pipe, no attempt to fit will be made. One easy way to turn off fit is to 
#       cat the output or redirect to a file.
#
#          $ echo "data" | ds:reo 1,2,3 | cat
#
# SIMPLE USAGE
#       Print help:
#
#          $ ds:reo -h
#
#       Index a field value (Print the field value at row 1 col 1):
#
#          $ ds:reo 1 1
#
#       Print multiple specific rows and/or columns:
#
#          $ ds:reo 1,1000 1,4,5
#
#         (Print row 1 then 1000, only cols 1, 4 and 5)
#
#       Print rows/column index numbers relative to maximum index value:
#
#          $ ds:reo -1,-2 -3
#
#       Pass all rows / columns for given index - don't set arg or set arg=[a|all]:
#
#          $ ds:reo a 4
#
#         (Example: Print all rows, only column 4)
#
#       Print index range (ranges are inclusive of ending indices):
#
#          $ ds:reo 1,100..200 1..3,5
#
#       Print index range with endpoints relative to maximum index val:
#
#          $ ds:reo -3..-1 -5..1
#
#       Reorder/repeat rows and fields, duplicate as many times as desired:
#
#          $ ds:reo 3,3,5,1 4..1,1,3,5
#
#       Print a range by defining inclusive pattern anchors. If one of the anchors is not 
#       given, it will default to the first or last row for start or end anchor respectively:
#
#          $ ds:reo '1,5, startrow_match##endrow_match'  ##endfield_match
#
#          $ ds:reo /start/.. /start/../end/
#
#       Turn off field separation for calculation and output - set c to "off":
#
#          $ ds:reo start## off
#
#       Reverse indices by adding the string r[everse] anywhere in the order:
#
#          $ ds:reo 1,r all,rev
#
#       Index numbers evaluating to expression. If no comparison specified, compares if 
#       expression equal to zero. NR and NF refer to the index number and must be used on 
#       the left side of the expression:
#
#          $ ds:reo 'NR%2,NR%2=1' 'NF<10'
#
#       Output with row and column index numbers from source:
#
#          $ ds:reo rev rev -v idx=1
#
# ADVANCED USAGE
#       Filter records by field values and/or fields by record values:
#
#       -- Using basic math expressions, across the entire opposite span:
#
#          $ ds:reo '=1, <1' '/5<11'
#
#         (Example: Print rows with field value =1, followed by rows with value <1, and 
#          fields with values less than 11 when divided by 5)
#
#
#       -- Using basic math expressions, across given span:
#
#          $ ds:reo '1, 8<0' '6!=10'
#
#         (Example: Print the header row followed by rows where field 8 is negative, only
#          fields with values in row 6 not equal to 10)
#
#
#       -- Using len() / length() function. The parameter is the index number of row or 
#          column respectively. If no parameter given, all fields are searched for condition:
#
#          $ ds:reo 'len(3)<100' 'length()>50'
#
#
#       -- Using regular expressions across the opposite span, full or specified:
#
#          $ ds:reo '~plant , !~[A-z]' '3~[0-9]+\.[0-9]' -v cased=1
#
#         (Example: Print Rows matching "plant" followed by rows without alpha chars, only 
#          fields with values in row 3 that match simple decimal pattern)
#
#
#       Alternatively filter the cross-span by a current-span frame pattern. Headers --
#       first row and first column -- are the default if not specified:
#
#          $ ds:reo '[plant~flower' '3[alps>10000'
#
#         (Example: Print rows where column header matches "plant" and column value matches 
#          "flower", cols where values in row 3 match "alps" and which have number values 
#          greater than 10000
#
#
#       If no expression or search given with frame, simple search is done on the cross
#       span, not the current span -- frame rows by column, columns by row:
#
#          $ ds:reo file '[europe' '[plant'
#
#         (Example: Print rows where first col matches 'europe' (any case), fields where
#          first row matches 'plant' (any case))
#
#          Note the above args are equivalent to '1~europe' '1~plant'.
#
#
#       Combine filters using && and || for more selective or expansive queries (|| is 
#       currently calculated first):
#
#          $ ds:reo '[plant~flower || [plant~tree && [country~italy' rev
#
#         (Example: Print rows where field vals in fields with headers matching "plant" match
#          "flower" OR where the same match tree and field vals in fields in the same row with
#          headers matching "country" match "italy"; print all fields in reverse order)
#
#
#       Case is ignored globally by default in regex searches. To enable cased matching set 
#       variable cased to any value. To search a case insensitive value while cased is set,
#       append "/i" to the end of the pattern:
#
#          $ ds:reo '[europe/i' '[Plant' -v cased=1
#
#         (Example: Print rows where first col matches "europe" in any case, fields where 
#          first row matches "Plant" exactly)
#
#
#       Print any columns or rows that did not match filter args, add o[thers] anywhere in 
#       either order:
#
#          $ ds:reo '3, 4, others, 1' '[Tests,oth'
#
#         (Example: Print rows 3, 4, then any not in the set 1,3,4, then row 1; fields where 
#          header matches "tests", then any remaining fields):
#
#
#       Constrain output to unique indices on searches, expressions, reverses:
#
#          $ ds:reo a 'len()>0,len()<100000' -v uniq=1
#
#
# VERSION
#       0.2
#
# AUTHORS
#       Tom Hall (tomhallmain@gmail.com)
#
## TODO: Option (or default?) for preserving original order if possible
## TODO: Basic sorts and multisort
## TODO: String equality / sorting
## TODO: Remove frame print if already indexed, and don't print if no match?
## TODO: Expressions and comparisons against cross-index total
## TODO: Expressions and comparisons between fields (standard awk)
## TODO: Range support for index number and pattern endpoints combined
## TODO: Full line regex check for field non-specific searches

## SETUP

BEGIN {
  BuildRe(Re); BuildTokens(Tk); BuildTokenMap(TkMap)
  assume_constant_fields = 0; base_r = 1; base_c = 1
  min_guar_print_nf = 1000; min_guar_print_nr = 100000000
  comma_escape_string = "#_ECSOCMAMPA_#"
  if (!cased) ignore_case_global = 1
  if (ARGV[1]) {
    # TODO: Handle unsupported cases if file arg not present
    "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0
  }

  if (debug) DebugPrint(-1)
  
  if (r) {
    gsub("\\\\,", comma_escape_string, r) # Unescape comma searches
    ReoR[0] = 1
    Setup(1, r, reo_r_count, R, RangeR, ReoR, base_r, rev_r, oth_r, RRExprs, RRSearches, RRIdxSearches, RRFrames, RAnchors, RExtensions)
    r_len = SetupVars["len"]
    reo_r_count = SetupVars["count"]
    base_r = SetupVars["base_status"]
    rev_r = SetupVars["rev"]
    oth_r = SetupVars["oth"];
    delete ReoR[0]
  }
  if (!reo_r_count) pass_r = 1

  if (c == "off") c_off = 1
  else if (c) {
    gsub("\\\\,", comma_escape_string, c) # Unescape comma searches
    ReoC[0] = 1
    Setup(0, c, reo_c_count, C, RangeC, ReoC, base_c, rev_c, oth_c, RCExprs, RCSearches, RCIdxSearches, RCFrames, CAnchors, CExtensions)
    c_len = SetupVars["len"]
    reo_c_count = SetupVars["count"]
    base_c = SetupVars["base_status"]
    rev_c = SetupVars["rev"]
    oth_c = SetupVars["oth"] 
    delete ReoC[0]
  }
  if (!reo_c_count) pass_c = 1

  if (pass_r && pass_c) pass = 1
  if (r_len == 1 && c_len == 1 && !pass_r && !pass_c && !range && !reo)
    indx = 1
  else if (!pass && !range && !reo)
    base = 1
  else if (range && !reo)
    base_range = 1
  else if (reo && !mat && !re && !anc && !rev && !oth && !c_nidx && !c_nidx_rng)
    base_reo = 1

  if (OFS ~ "\\\\") OFS = Unescape(OFS)
  if (OFS ~ "\\[:space:\\]\{") OFS = "  "
  else if (OFS ~ "\\[:space:\\]\+") OFS = " "
  
  reo_r_len = length(ReoR)
  reo_c_len = length(ReoC)
  
  if (debug) { DebugPrint(0); DebugPrint(7) }
  
  if (idx && !pass && (!reo || base_reo && pass_r)) {
    if (base_range || base_reo)
      FieldsIndexPrint(ReoC, reo_c_len)
    else
      FieldsIndexPrint(COrder, c_len)
  }
}



## SIMPLE PROCESSING/DATA GATHERING

indx {
  if (NR == r) {
    if (idx) printf "%s", NR OFS
    print $c
    exit
  }
  next
}

base {
  if (pass_r || NR in R) {
    if (idx) printf "%s", NR OFS
    FieldsPrint(COrder, c_len, 1)
  }
  next
}

base_range {
  if (pass_r || NR in R) {
    if (idx) printf "%s", NR OFS
    FieldsPrint(ReoC, reo_c_len, 1)
  }
  next
}

reo {
  if (pass_r) {
    if (base_reo) {
      if (idx) printf "%s", NR OFS
      FieldsPrint(ReoC, reo_c_len, 1)
    }
    else {
      StoreRow(_)
      StoreFieldRefs()
    }
  }
  else {
    if (base_reo && NR in R) {
      StoreRow(_)
      if (NF > max_nf) max_nf = NF
    }
    else {
      StoreRow(_)
      if (!base_c) StoreFieldRefs()
      if (!base_r) StoreRowRefs()
    }
  }

  if (NF > max_nf) max_nf = NF

  next
}

pass { 
  if (idx) { 
    if (NR == 1) FieldsIndexPrint(Empty, NF)
    printf "%s", NR OFS
  }
  FieldsPrint($0, 0, 1)
}



## FINAL PROCESSING FOR REORDER CASES

END {
  if (debug) DebugPrint(4)
  if (err || !reo || (base_reo && pass_r)) exit err

  if (c_nidx)
    SetNegativeIndexFieldOrder(0, CNidx, max_nf)
  if (c_nidx_rng)
    SetNegativeIndexFieldOrder(1, CNidxRanges, max_nf)
  if (anc) {
    FillAnchorRange(1, RAnchors, AnchorRO)
    FillAnchorRange(0, CAnchors, AnchorFO)
  }
  if (oth) {
    if (debug) DebugPrint(10)
    if (oth_r) remaining_ro = GenRemainder(1, ReoR, NR)
    if (oth_c) remaining_fo = GenRemainder(0, ReoC, max_nf)
  }
  if (ext) {
    ResolveFilterExtensions(1, RExtensions, ReoR, ExtRO, NR)
    ResolveFilterExtensions(0, CExtensions, ReoC, ExtFO, max_nf)
    if (debug) DebugPrint(12)
  }
  if (uniq) {
    if(!base_r) EnforceUnique(1, ReoR, reo_r_len)
    if(!base_c) EnforceUnique(0, ReoC, reo_c_len)
  }
  if (debug) { if (!pass_c) DebugPrint(6); DebugPrint(8) }

  if (!pass_c && !q && !rev_c && !oth_c && !c_anc_found && max_nf < min_guar_print_nf)
    MatchCheck(ExprFO, SearchFO, AnchorFO, CNidx, CNidxRanges)
  if (!pass_r && !q && !rev_r && !oth_r && !r_anc_found && NR < min_guar_print_nr)
    MatchCheck(ExprRO, SearchRO, AnchorRO)

  if (idx) {
    if (reo_c_len)
      FieldsIndexPrint(ReoC, reo_c_len)
    else
      FieldsIndexPrint(Empty, max_nf)
  }

  if (pass_r) {
    for (rr = 1; rr <= NR; rr++) {
      if (idx) printf "%s", rr OFS
      for (rc = 1; rc <= reo_c_len; rc++) {
        c_key = ReoC[rc]
        if (!c_key) continue
        row = _[rr]
        split(row, Row, FS)
        if (c_key ~ Re["int"])
          PrintField(Row[c_key], rc, reo_c_len)
        else {
          Reo(c_key, Row, 0)
          if (rc!=reo_c_len) printf "%s", OFS
        }
      }
      print ""
    }
    exit
  }

  for (rr = 1; rr <= reo_r_len; rr++) {
    r_key = ReoR[rr]
    if (!r_key) continue
    if (pass_c && base_reo) FieldsPrint(_[r_key])
    else {
      if (r_key ~ Re["int"]) {
        if (idx) printf "%s", r_key OFS
        if (pass_c) FieldsPrint(_[r_key])
        else {
          for (rc = 1; rc <= reo_c_len; rc++) {
            c_key = ReoC[rc]
            if (!c_key) continue
            
            row = _[r_key]
            split(row, Row, FS)
            
            if (c_key ~ Re["int"])
              PrintField(Row[c_key], rc, reo_c_len)
            else {
              Reo(c_key, Row, 0)
              if (rc!=reo_c_len) printf "%s", OFS
            }
          }

          print ""
        }
      }

      else Reo(r_key, _, 1)
    }
  }
}



## FUNCTIONS

function Reo(key, CrossSpan, row_call) {
  if (row_call) {
    rows = GetOrder(1, key)
    split(rows, PrintRows, ",")
    len_printr = length(PrintRows) - 1

    for (pr = 1; pr <= len_printr; pr++) {
      pr_key = PrintRows[pr]
      if (idx) printf "%s", pr_key OFS
      if (pass_c) FieldsPrint(CrossSpan[pr_key])
      else {
        for (rc = 1; rc <= reo_c_len; rc++) {
          c_key = ReoC[rc]
          if (!c_key) continue
          row = CrossSpan[pr_key]
          split(row, Row, FS)
          if (c_key ~ Re["int"])
            PrintField(Row[c_key], rc, reo_c_len)
          else {
            Reo(c_key, Row, 0)
            if (rc!=reo_c_len) printf "%s", OFS
          }
        }
        print ""
      }
    }
  }

  else {
    fields = GetOrder(0, key)
    split(fields, PrintFields, ",")
    len_printf = length(PrintFields) - 1

    for (f = 1; f <= len_printf; f++)
      PrintField(CrossSpan[PrintFields[f]], f, len_printf)
  }
}

function FieldsPrint(Order, ord_len, run_call) {
  if (pass_c) {
    if (c_off) {
      if (run_call)
        print $0
      else
        print Order
    }
    else if (run_call) {
      for (pf = 1; pf < NF; pf++)
        printf "%s", $pf OFS
      print $NF
    }
    else {
      split(Order, PrintFields, FS)
      len_printf = length(PrintFields)
      for (pf = 1; pf < len_printf; pf++)
        printf "%s", PrintFields[pf] OFS
      print PrintFields[len_printf]
    }
  }
  else {
    for (pf = 1; pf < ord_len; pf++)
      printf "%s", $Order[pf] OFS
    print $Order[ord_len]
  }
}

function FieldsIndexPrint(Order, ord_len) {
  PrintField("", 0, 1)
  if (reo && !pass_c && !base_reo) {
    for (rc = 1; rc <= ord_len; rc++) {
      c_key = Order[rc]
      if (!c_key) continue
      if (c_key ~ Re["int"])
        PrintField(c_key, rc, ord_len)
      else {
        fields = GetOrder(0, c_key)
        split(fields, PrintFields, ",")
        len_printf = length(PrintFields) - 1
        for (f = 1; f <= len_printf; f++)
          PrintField(PrintFields[f], f, len_printf)
      }
    }
    print ""
  }
  else if (length(Order)) {
    for (idx_pf = 1; idx_pf < ord_len; idx_pf++)
      printf "%s", Order[idx_pf] OFS
    print Order[ord_len]
  }
  else {
    for (f = 1; f < ord_len; f++)
      printf "%s", f OFS
    print ord_len
  }
}

function FillRange(row_call, range_arg, RangeArr, reo_count, ReoArr) {
  split(range_arg, RngAnc, TkMap["rng"])
  start = RngAnc[1]; end = RngAnc[2]
  if (range_arg ~ Re["nidx_rng"]) {
    if (start ~ /^-/) start = max_nr + start + 1
    if (end ~ /^-/) end = max_nr + end + 1 }
  if (debug) DebugPrint(2)

  if (start > end) {
    reo = 1
    for (k = start; k >= end; k--)
      reo_count = FillReoArr(row_call, k, RangeArr, reo_count, ReoArr)
  }
  else {
    for (k = start; k <= end; k++)
      reo_count = FillReoArr(row_call, k, RangeArr, reo_count, ReoArr)
  }

  return reo_count
}

function FillReoArr(row_call, val, KeyArr, count, ReoArr, type) {
  count++
  KeyArr[val] = 1
  ReoArr[count] = val
  if (type)
    TypeMap[val] = type
  else if (row_call) {
    R[val] = 1
    if (val < min_guar_print_nr)
      min_guar_print_nr = val
  }
  else {
    C[val] = 1
    if (val > 0 && val < min_guar_print_nf)
      min_guar_print_nf = val
  }

  return count
}

function StoreRow(_) {
  _[NR] = $0
}

function StoreFieldRefs() {
  # Check each field for each expression and search pattern, if applicable and
  # not already positively linked. Fields can be made non-applicable by field 
  # filter within the first subarg of the reo arg.
  if (re) {
    for (search in RCIdxSearches) {
      split(search, Fr, "[")
      test_row = (fr_ext && Fr[1]) ? Fr[1] : 1
      if (NR != test_row) continue
      base_search = Fr[2]
      ignore_case = (ignore_case_global || IgnoreCase[search])
      if (ignore_case) base_search = tolower(base_search)
      for (f = 1; f <= NF; f++) {
        field = ignore_case ? tolower($f) : $f
        if (field ~ base_search) SearchFO[search] = SearchFO[search] f","
      }
    }

    for (search in RCSearches) {
      ignore_case = (ignore_case_global || IgnoreCase[search])
      split(search, Tmp, "~")
      gsub(/!$/, "", Tmp[1])
      base_search = Tmp[2]
      if (ignore_case) base_search = tolower(base_search)
      if (search in RCFrames) {
        split(Tmp[1], Fr, "[")
        test_field = (fr_ext && Fr[1]) ? Fr[1] : 1
        field = ignore_case ? tolower($test_field) : $test_field
        frame_re = ignore_case ? tolower(Fr[2]) : Fr[2]
        if (!(field ~ frame_re)) continue
        else if (!Indexed(SearchFO[search], test_field)) {
          SearchFO[search] = SearchFO[search] test_field","
        }
      }
      else if (Tmp[1] ~ Re["num"]) { 
        if (NR != Tmp[1]) continue
      }

      for (f = 1; f <= NF; f++) {
        if (Indexed(SearchFO[search], f)) continue
        field = ignore_case ? tolower($f) : $f
        if (debug) DebugPrint(9) 
        if (ExcludeRe[search]) {
          if (ExcludeField[search, f]) continue
          if (field ~ base_search) ExcludeField[search, f] = 1
          if (NR == max_nr)
            SearchFO[search] = SearchFO[search] f","
        }
        else {
          if (field ~ base_search)
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
      compval = 0; comp = "="; settable = 0; len_expr = LenExpr[expr]
      if (expr in RCFrames) {
        ignore_case = (ignore_case_global || IgnoreCase[expr])
        split(expr, Tmp, TkMap["mat"])
        split(Tmp[1], Fr, "[")
        test_field = (fr_ext && Fr[1]) ? Fr[1] : 1
        field = ignore_case ? tolower($test_field) : $test_field
        frame_re = ignore_case ? tolower(Fr[2]) : Fr[2]
        if (!(field ~ frame_re)) continue
        if (!Indexed(ExprFO[expr], test_field)) {
          ExprFO[expr] = ExprFO[expr] test_field","
        }
        base_expr = substr(expr, length(Tmp[1])+1)
        anchor_row = max_nr }
      else if (SpecExpr[expr]) {
        split(expr, Tmp, Re["nan"])
        if (Tmp[1]) {
          if (NR != Tmp[1]) continue
          else anchor_row = Tmp[1] }
        else anchor_row = max_nr
        base_expr = substr(expr, length(Tmp[1])+1) }
      else if (len_expr) {
        split(len_expr, Tmp, Re["nan"])
        if (Tmp[1]) {
          if (NR != Tmp[1]) continue
          else anchor_row = Tmp[1] }
        else anchor_row = max_nr
        base_expr = substr(len_expr, length(Tmp[1])+1) }
      else { base_expr = expr; settable = 1; anchor_row = max_nr
        RCExprFieldsSet[expr] = 1 }

      if (base_expr ~ Re["comp"]) { GetComp(base_expr)
        comp = Tmp[0]; base_expr = Tmp[1]; compval = Tmp[2] }
      
      for (f = 1; f <= NF; f++) {
        if (Indexed(ExprFO[expr], f)) continue

        if (settable)
          anchor = f
        else if (len_expr)
          anchor = length($f)
        else if ($f ~ Re["decnum"] || $f ~ Re["float"]) {
          anchor = $f; gsub("[\$,\"]", "", anchor)
          anchor += 0
          if (anchor ~ Re["float"]) anchor = int(anchor)
        }
        else if (comp == "!=")
          anchor = ""
        else continue

        eval = EvalExpr(anchor base_expr)
        if (debug) DebugPrint(5)
        if (comp == "!=") {
          if (!ExcludeCol[expr, f]) {
            if (eval == compval) ExcludeCol[expr, f] = 1
            else if (NR == anchor_row) ExprFO[expr] = ExprFO[expr] f","
          }
          continue
        }
        if (EvalCompExpr(eval, compval, comp))
            ExprFO[expr] = ExprFO[expr] f","
      }
    }
  }

  if (anc && !c_anc_found && NF > 1) {
    for (anchor in CAnchors) {
      if (CAnchorSet[anchor]) continue
      split(anchor, Anchors, TkMap["anc"])
      ignore_case = (ignore_case_global || IgnoreCase[anchor])
      for (f = 1; f <= NF; f++) {
        field = ignore_case ? tolower($f) : $f
        if (Anchors[1] && !CAnchorStart[anchor] && field ~ Anchors[1]) {
          CAnchorStart[anchor] = f
          if (!CAnchorEnd[anchor]) continue
        }
        if (Anchors[2] && !CAnchorEnd[anchor] && field ~ Anchors[2])
          CAnchorEnd[anchor] = f 
        if (CAnchorStart[anchor] && CAnchorEnd[anchor])
          CAnchorSet[anchor] = 1
      }
      if (CAnchorSet[anchor]) c_ancs++
    }
    if (c_ancs == length(CAnchors))
      c_anc_found = 1
  }

  if (rev_c)
    for (f = max_nf + 1; f <= NF; f++) rev_fo = f"," rev_fo
}

function StoreRowRefs() {
  # Checks a single row for each expression and search pattern, if applicable,
  # and stores relevant row numbers. Rows can be made non-applicable by filters
  # within the first subargs of the reo arg.
  if (re) {
    for (search in RRIdxSearches) {
      split(search, Fr, "[")
      test_field = (fr_ext && Fr[1]) ? Fr[1] : 1
      ignore_case = (ignore_case_global || IgnoreCase[search])
      field = ignore_case ? tolower($test_field) : $test_field
      if (!(field ~ Fr[2])) continue
      SearchRO[search] = SearchRO[search] NR","
    }

    for (search in RRSearches) {
      fr_search = 0; exclude = 0
      ignore_case = (ignore_case_global || IgnoreCase[search])
      split(search, Tmp, "~")
      gsub(/!$/, "", Tmp[1])
      base_search = Tmp[2]
      if (search in RRFrames) {
        if (ExcludeFrame[search]) continue
        start = 1; end = NF; fr_search = 1
        split(Tmp[1], Fr, "(\\[|!$)")
        test_row = (fr_ext && Fr[1]) ? Fr[1] : 1
        frame_re = Fr[2]
      }
      else if (c_off) {
        start = 0
        end = 0
      }
      else if (Tmp[1] ~ Re["int"]) {
        start = Tmp[1]
        end = start
      }
      else {
        start = 1
        end = NF
      }

      for (f = start; f <= end; f++) {
        if (fr_search) {
          if (FrameSet[search]) {
            if (!Indexed(FrameFields[search], f))
              continue
          }
          else if (NR == test_row) {
            field = ignore_case ? tolower($f) : $f
            if (!Indexed(SearchRO[search], NR) && field ~ frame_re)
                FrameFields[search] = FrameFields[search] f","
            if (f == end) {
              if (FrameFields[search]) # TODO: Should this be a flag setting or default behavior?
                SearchRO[search] = SearchRO[search] NR","
              MaxFrameField[search] = ResolveRowFilterFrame(search)
            }
            continue
          }
          else {
            field = ignore_case ? tolower($f) : $f
            rel_match = field ~ base_search
            if (ExcludeRe[search]) {
              if (!rel_match)
                FrameRowFields[search] = FrameRowFields[search] NR":"f","
            }
            else if (rel_match)
              FrameRowFields[search] = FrameRowFields[search] NR":"f","
            continue
          }
        }
        if (Indexed(SearchRO[search], NR)) continue
        field = ignore_case ? tolower($f) : $f
        if (debug) DebugPrint(9)
        if (ExcludeRe[search]) {
          if (field ~ base_search) exclude = 1
          last_f = fr_search ? MaxFrameField[search] : end
          if (f == last_f && !exclude)
            SearchRO[search] = SearchRO[search] NR","
        }
        else if (!exclude) {
          if (field ~ base_search)
            SearchRO[search] = SearchRO[search] NR","
        }
      }
    }
  }

  if (mat) {
    for (expr in RRExprs) {
      compval = 0; comp = "="; position_test = 0; len_expr = LenExpr[expr]
      fr_expr = 0; exclude = 0; frame_set = 0; open_frame = 0

      if (expr in RRFrames) {
        if (ExcludeFrame[expr]) continue
        ignore_case = (ignore_case_global || IgnoreCase[expr])
        split(expr, Tmp, TkMap["mat"])
        split(Tmp[1], Fr, "[")
        test_row = (fr_ext && Fr[1]) ? Fr[1] : 1
        base_expr = substr(expr, length(Tmp[1])+1)
        start = 1
        end = NF
        fr_expr = 1
        frame_re = Fr[2]
      }
      else if (SpecExpr[expr]) {
        split(expr, Tmp, Re["nan"])
        if (Tmp[1]) {
          start = Tmp[1]
          end = start
        }
        else {
          start = 1
          end = NF
        }
        base_expr = substr(expr, length(Tmp[1])+1) }
      else if (len_expr) {
        split(len_expr, Tmp, Re["nan"])
        if (c_off) {
          start = 1
          end = 1
        }
        else if (Tmp[1]) {
          start = Tmp[1]
          end = start
        }
        else {
          start = 1
          end = NF
        }
        base_expr = substr(len_expr, length(Tmp[1])+1)
      }
      else {
        base_expr = expr
        position_test = 1 
        start = 1
        end = NF
      }

      if (base_expr ~ Re["comp"]) { 
        GetComp(base_expr)
        comp = Tmp[0]
        base_expr = Tmp[1]
        compval = Tmp[2]
      }

      for (f = start; f <= end; f++) {
        if (fr_expr) {
          frame_set = FrameSet[expr]
          open_frame = !frame_set
          if (frame_set) {
            if (!Indexed(FrameFields[expr], f))
              continue
          }
          else if (NR == test_row) {
            field = ignore_case ? tolower($f) : $f
            if (field ~ frame_re) {
              if (!Indexed(ExprRO[expr], NR))
                FrameFields[expr] = FrameFields[expr] f"," }
            if (f == end) {
              if (FrameFields[expr]) # TODO: Should this be a flag setting or default behavior?
                ExprRO[expr] = ExprRO[expr] NR","
              MaxFrameField[expr] = ResolveRowFilterFrame(expr)
            }
            continue
          }
        }

        if (Indexed(ExprRO[expr], NR)) continue
        if (exclude && !open_frame) continue

        if (position_test) {
          if (f > 1) break
          else anchor = NR
        }
        else if (len_expr)
          anchor = c_off ? length($0) : length($f)
        else if ($f ~ Re["decnum"] || $f ~ Re["float"]) {
          anchor = $f; gsub("[\$,\"]", "", anchor)
          anchor += 0
          if (anchor ~ Re["float"]) anchor = int(anchor) }
        else if (comp == "!=")
          anchor = ""
        else continue
        
        eval = EvalExpr(anchor base_expr)
        
        if (debug) DebugPrint(5)
        
        if (comp == "!=") {
          if (!exclude)
            exclude = eval == compval
          
          last_f = frame_set ? MaxFrameField[expr] : end
          
          if (!exclude) {
            if (open_frame) {
              FrameRowFields[expr] = FrameRowFields[expr] NR":"f","
            }
            else if (f == last_f)
              ExprRO[expr] = ExprRO[expr] NR","
          }
          continue
        }
        if (EvalCompExpr(eval, compval, comp)) {
          if (fr_expr && !frame_set)
            FrameRowFields[expr] = FrameRowFields[expr] NR":"f","
          else
            ExprRO[expr] = ExprRO[expr] NR","
        }
      }
    }
  }

  if (anc && !r_anc_found) {
    for (anchor in RAnchors) {
      if (RAnchorSet[anchor])
        continue

      split(anchor, Anchors, TkMap["anc"])
      ignore_case = (ignore_case_global || IgnoreCase[anchor])
      row_test = ignore_case ? tolower($0) : $0

      if (debug) print anchor", "Anchors[1]", "Anchors[2]", "RAnchorStart[anchor]", "RAnchorEnd[anchor]" "r_ancs

      if (Anchors[1] && !RAnchorStart[anchor] && row_test ~ Anchors[1]) {
        RAnchorStart[anchor] = NR
        if (!RAnchorEnd[anchor]) continue
      }
      if (Anchors[2] && !RAnchorEnd[anchor] && row_test ~ Anchors[2])
        RAnchorEnd[anchor] = NR
      if (RAnchorStart[anchor] && RAnchorEnd[anchor])
        RAnchorSet[anchor] = 1
      if (RAnchorSet[anchor]) r_ancs++
    }
    if (r_ancs == length(RAnchors))
      r_anc_found = 1
  }

  if (rev_r) rev_ro = NR"," rev_ro
}

function ResolveRowFilterFrame(frame) {
  fr_type = TypeMap[frame]
  if (debug) DebugPrint(13)
  
  if (!FrameFields[frame]) {
    ExcludeFrame[frame] = 1
    if (fr_type == "re") SearchRO[frame] = ""
    else if (fr_type == "mat") ExprRO[frame] = ""
    return
  }

  FrameFieldsTest = FrameFields[frame]
  split(FrameRowFields[frame], FrameRowsTest, ",")

  for (rf_i in FrameRowsTest) {
    split(FrameRowsTest[rf_i], RowField, ":")
    row = RowField[1]
    field = RowField[2]
    if (debug) DebugPrint(14)
    if (Indexed(FrameFieldsTest, field)) {
      if (field > max_frame_f) max_frame_f = field
      if (fr_type == "re") SearchRO[frame] = SearchRO[frame] row","
      else if (fr_type == "mat" ) ExprRO[frame] = ExprRO[frame] row","
    }
  }

  FrameSet[frame] = 1
  return max_frame_f
}

function ResolveFilterExtensions(row_call, Extensions, ReoArr, OrdArr, max_val) {
  if (length(Extensions)) {
    for (ext_i in Extensions) {
      if (!Extensions[ext_i]) continue
      split(Extensions[ext_i], DeleteKeys, ",")
      OrdArr[ext_i] = ResolveMultisetLogic(row_call, ext_i, max_val)
      ReoArr[DeleteKeys[1]] = ext_i; TypeMap[ext_i] = "ext"; delete DeleteKeys[1]
      for (del_key_i in DeleteKeys)
        delete ReoArr[DeleteKeys[del_key_i]]
    }
  }
}

function ResolveMultisetLogic(row_call, key, max_val) {
  combin_idx = ""; break2 = 0
  split(key, Ands, "&&")
  for (and_i in Ands) {
    ors_idx = ""
    split(Ands[and_i], Ors, "\\|\\|")
    
    for (ors_i in Ors)
      ors_idx = ors_idx GetOrder(row_call, Ors[ors_i])
    
    AndOrder[and_i] = ors_idx
  }

  for (i = 1; i <= max_val; i++) {
    continue2 = 0
    for (and_i in Ands) {
      if (AndOrder[and_i] == "") {
        break2 = 1
        break
      }
      else if (!Indexed(AndOrder[and_i], i)) {
        continue2 = 1
        break
      }
    }
    if (continue2) continue
    if (break2) break
    combin_idx = combin_idx i","
  }
  return combin_idx
}

function SetNegativeIndexFieldOrder(range_call, ArgArr, max_val) {
  if (!max_val) {
    for (arg in ArgArr) delete ArgArr[arg]
    return
  }
  if (range_call) {
    for (range_arg in ArgArr) {
      ord = ""
      split(range_arg, RngAnc, TkMap["rng"])
      start = RngAnc[1]; end = RngAnc[2]
      if (start ~ /^-/) start = max_val + start + 1
      if (end ~ /^-/) end = max_val + end + 1
      if (start < 1 && end < 1) continue
      else if (start < 1) start = 1
      else if (end < 1) end = 1

      if (start > end)
        for (k = start; k >= end; k--)
          ord = ord k","
      else
        for (k = start; k <= end; k++)
          ord = ord k","
      ArgArr[range_arg] = ord
    }
  }
  else {
    for (arg in ArgArr) {
      val = max_val + arg + 1
      if (val < 1) delete ArgArr[arg]
      else ArgArr[arg] = val","
    }
  }
}

function FillAnchorRange(row_call, AncArr, AncOrder) {
  for (anchor in AncArr) {
    anc_order = ""
    if (row_call) {
      if (!RAnchorStart[anchor] && !RAnchorEnd[anchor]) continue
      start = RAnchorStart[anchor] ? RAnchorStart[anchor] : 1
      end = RAnchorEnd[anchor] ? RAnchorEnd[anchor] : NR }
    else {
      if (!CAnchorStart[anchor] && !CAnchorEnd[anchor]) continue
      start = CAnchorStart[anchor] ? CAnchorStart[anchor] : 1
      end = CAnchorEnd[anchor] ? CAnchorEnd[anchor] : max_nf }
    if (end < start)
      for (a_f = start; a_f >= end; a_f--)
        anc_order = anc_order a_f","
    else
      for (a_f = start; a_f <= end; a_f++)
        anc_order = anc_order a_f","
    AncOrder[anchor] = anc_order
  }
}

function GenRemainder(row_call, ReoArr, max_val) {
  all_reo = ""; rem_idx = ""
  for (i in ReoArr)
    all_reo = all_reo GetOrder(row_call, ReoArr[i])
  for (i = 1; i <= max_val; i++)
    if (!Indexed(all_reo, i))
      rem_idx = rem_idx i","

  if (debug) DebugPrint(11)
  return rem_idx
}

function EnforceUnique(row_call, Order, ord_len) {
  uniq_o = ""; uniq_override = 0
  for (o_i = 1; o_i <= ord_len; o_i++) {
    o_key = Order[o_i]
    if (o_key ~ Re["int"]) {
      #if (Indexed(uniq_o, o_key)) { uniq_override = 1; continue }
      uniq_o = uniq_o o_i","
      continue
    }
    order = GetOrder(row_call, o_key)
    if (!order) continue
    key_o_len = split(order, KeyOrder, ",")

    for (ko_i = 1; ko_i < key_o_len; ko_i++) {
      _o = KeyOrder[ko_i]
      if (Indexed(uniq_o, _o)) {
        uniq_override = 1
        continue
      }
      uniq_o = uniq_o _o","
    }
  }

  if (uniq_override) {
    TypeMap["oth"] = "oth"
    if (row_call) {
      for (rr in ReoR) delete ReoR[rr]
      remaining_ro = uniq_o
      ReoR[1] = "oth"
    }
    else {
      for (rc in ReoC) delete ReoC[rc]
      remaining_fo = uniq_o
      ReoC[1] = "oth"
    }
  }
}

function GetOrder(row_call, key) {
  if (key ~ Re["int"]) return key","

  type = TypeMap[key]

  if (row_call) {
    if (type == "rev") return rev_ro
    else if (type == "oth") return remaining_ro
    else if (type == "re") return SearchRO[key]
    else if (type == "mat") return ExprRO[key]
    else if (type == "anc") return AnchorRO[key]
    else if (type == "ext") return ExtRO[key]
  }
  else {
    if (type == "rev") return rev_fo
    else if (type == "oth") return remaining_fo
    else if (type == "nidx") return CNidx[key]
    else if (type == "re") return SearchFO[key]
    else if (type == "mat") return ExprFO[key]
    else if (type == "anc") return AnchorFO[key]
    else if (type == "ext") return ExtFO[key]
    else if (type == "nidx_rng") return CNidxRanges[key]
  }
}

function Setup(row_call, order_arg, reo_count, OArr, RangeArr, ReoArr, base_o, rev_o, oth_o, ExprArr, SearchArr, IdxSearchArr, FramesArr, AncArr, ExtArr) {
  max_o_i = 0; prior_count = 0
  split(order_arg, Order, Re["ordsep"])
  o_len = length(Order)

  for (i = 1; i <= o_len; i++) {
    base_i = Order[i]
    gsub(comma_escape_string, ",", base_i) # Replace commas
    if (!base_i) {
      delete Order[i]
      continue
    }
    if (base_i ~ Re["ext"]) {
      ExtArr[base_i] = 1
      ext = 1
    }
    split(base_i, ExtOrder, Re["ext"])
    split(base_i, Operators, Re["extcomp"])
    ext_len = length(ExtOrder)
    for (j = 1; j <= ext_len; j++) {
      o_i = ExtOrder[j]

      token = o_i ~ Re["alltokens"] ? TokenPrecedence(o_i) : ""

      if (debug) { row_call ? DebugPrint(1) : DebugPrint(1.5) }

      if (o_i ~ Re["int"] || token == "nidx") {
        if (token == "nidx") {
          if (row_call)
            o_i = max_nr + o_i + 1
          else {
            reo = 1; c_nidx = 1
            reo_count = FillReoArr(0, o_i, CNidx, reo_count, ReoArr, token)
            continue
          }
        }
        reo_count = FillReoArr(row_call, o_i, RangeArr, reo_count, ReoArr)
        if (!reo && o_i > max_o_i)
          max_o_i = o_i
        else {
          reo = 1
          base_o = 0
        }
      }
      else if (!token) {
        if ("reverse" ~ "^"tolower(o_i)) {
          o_i = "rev"; base_o = 0; reo = 1; rev = 1; rev_o = 1
          reo_count = FillReoArr(row_call, o_i, OArr, reo_count, ReoArr, "rev")
          continue
        }
        else if ("others" ~ "^"tolower(o_i)) {
          o_i = "oth"; base_o = 0; reo = 1; oth = 1; oth_o = 1
          reo_count = FillReoArr(row_call, o_i, OArr, reo_count, ReoArr, "oth")
          continue
        }
      }
      else {
        if (!row_call) delete Order[i]
        max_o_i = TestArg(o_i, max_o_i, token)
        base_o = 0
        if (IgnoreCase[o_i]) {
          o_i = tolower(o_i)
          gsub("/[Ii]$", "", o_i)
          gsub("/[Ii]~", "~", o_i)
          IgnoreCase[o_i] = 1
          ExtOrder[j] = o_i
        }

        if (token == "rng" || (token == "nidx_rng" && row_call))
          reo_count = FillRange(row_call, o_i, OArr, reo_count, ReoArr)
        else if (token == "nidx_rng")
          reo_count = FillReoArr(row_call, o_i, CNidxRanges, reo_count, ReoArr, token)
        else if (token == "mat")
          reo_count = FillReoArr(row_call, o_i, ExprArr, reo_count, ReoArr, token)
        else if (token == "re")
          reo_count = FillReoArr(row_call, o_i, SearchArr, reo_count, ReoArr, token)
        else if (token == "anc" || token == "anc_re") {
          if (token == "anc_re") {
            split(o_i, Anchors, TkMap["anc_re"])
            gsub(/(^\/|\/$)/, "", Anchors[1]); gsub(/(^\/|\/$)/, "", Anchors[2])
            o_i = Anchors[1] "##" Anchors[2]; ExtOrder[j] = o_i
          }
          reo_count = FillReoArr(row_call, o_i, AncArr, reo_count, ReoArr, "anc")
        }
        else if (token == "fr") {
          FramesArr[o_i] = 1
          if (fr == "mat")
            reo_count = FillReoArr(row_call, o_i, ExprArr, reo_count, ReoArr, fr)
          else if (fr == "re" && fr_idx)
            reo_count = FillReoArr(row_call, o_i, IdxSearchArr, reo_count, ReoArr, fr)
          else if (fr == "re")
            reo_count = FillReoArr(row_call, o_i, SearchArr, reo_count, ReoArr, fr)
        }
      }
    }

    if (ExtArr[base_i]) {
      delete ExtArr[base_i]
      base_i = ""

      for (k = 1; k <= length(ExtOrder); k++)
        base_i = base_i ExtOrder[k] Operators[k+1]

      for (l = prior_count+1; l <= reo_count; l++)
        ExtArr[base_i] = ExtArr[base_i] l","

      delete ExtOrder
      delete Operators
    }
    
    prior_count = reo_count
  }

  if (row_call) {
    for (ord in Order) ROrder[ord] = Order[ord] 
    for (ord in ExtOrder) RExtOrder[ord] = ExtOrder[ord]
  }
  else {
    for (ord in Order) COrder[ord] = Order[ord]
    for (ord in ExtOrder) RExtOrder[ord] = ExtOrder[ord]
  }

  SetupVars["len"] = o_len
  SetupVars["count"] = reo_count
  SetupVars["base_status"] = base_o
  SetupVars["rev"] = rev_o
  SetupVars["oth"] = oth_o
}

function TokenPrecedence(arg) {
  if (arg ~ Re["nidx_rng"])
    return "nidx_rng"
  else if (arg ~ Re["n_int"])
    return "nidx"
  else if (arg ~ Re["anc"])
    return "anc"
  else if (arg ~ Re["anc_re"])
    return "anc_re"

  found_token = ""; loc_min = 100000
  for (tk in Tk) {
    tk_loc = index(arg, tk)
    if (debug) DebugPrint(3, arg)
    if (tk_loc && tk_loc < loc_min) {
      loc_min = tk_loc
      found_token = Tk[tk]
      if (tk_loc == 1) break
    }
  }

  return found_token
}

function TestArg(arg, max_i, type, row_call) {
  split(arg, Subargv, TkMap[type])
  sa1 = Subargv[1]; sa2 = Subargv[2]
  len_sargv = length(Subargv)

  if (type == "rng") { range = 1
    if (len_sargv != 2 || !(sa1 ~ Re["int"]) || !(sa2 ~ Re["int"])) {
      print "Invalid range order arg "arg" - range formats include:"
      print "1..9 600..1"
      exit 1
    }
    if (reo || sa1 >= sa2 || sa1 <= max_i)
      reo = 1
    else
      max_i = sa2
  }

  else if (type == "nidx_rng") {
    range = 1
    nidx_rng = 1
    if (!row_call) c_nidx_rng = 1
    if (len_sargv != 2 || !(sa1 ~ Re["n_int"]) || !(sa2 ~ Re["n_int"])) {
      print "Invalid negative index range order arg "arg" - negative index range formats include:"
      print "1..-1  -5..-3  -10..1"
      exit 1 }
    if (sa1 ~ /^-/) sa1 = max_nr + sa1 + 1
    if (sa2 ~ /^-/) sa1 = max_nr + sa2 + 1
    if (reo || !row_call || sa1 >= sa2 || sa1 <= max_i)
      reo = 1
    else
      max_i = sa2
  }

  else if (type == "mat") {
    reo = 1
    mat = 1
    if (arg ~ Re["len"]) { len = 1
      len_arg = arg
      gsub(Re["len"], "", len_arg); sub("\\)", "", len_arg)
      LenExpr[arg] = len_arg
    }
    if (substr(arg, 1, 1) ~ Re["intmat"]) SpecExpr[arg] = 1
    if (!(arg ~ Re["matarg1"] || arg ~ Re["matarg2"])) {
      print "Invalid expression order arg "arg" - expression format examples include:"
      print "NR%2  2%3=5  NF!=4  *6/8%2=1  length(6)>20"
      exit 1
    }
  }

  else if (type == "re") {
    reo = 1
    re = 1
    if (arg ~ "!~") ExcludeRe[arg] = 1
    if (ignore_case_global || arg ~ "\/[Ii](~|$)") IgnoreCase[arg] = 1
    re_test = substr(arg, length(sa1)+2, length(arg))
    if ("" ~ re_test) {
      print "Invalid search order arg "arg" - search arg format examples include:"
      print "~search  2~pattern/i  4!~[0-9]+"
      exit 1
    }
  }

  else if (type == "anc" || type == "anc_re") {
    anc = 1
    reo = 1
    if (!(sa1 || sa2)) {
      print "Invalid anchor order arg "arg" - anchor arg formats include:"
      print "start_anchor##  start##end  ##end_anchor  /start/../end/"
    }
    if (ignore_case_global || arg ~ "\/[Ii](~|$)") IgnoreCase[arg] = 1
    if (type == "anc_re") {
      gsub(/(^\/|\/$)/, "", sa1); gsub(/(^\/|\/$)/, "", sa2)
    }
    "" ~ sa1; "" ~ sa2
  }

  else if (type == "fr") {
    reo = 1
    fr_idx = 0
    if (c == "off") {
      print "Frame args cannot be used without column traversal"
      exit 1
    }
    if (sa1) fr_ext = 1
    if (ignore_case_global || arg ~ "\/[iI]") IgnoreCase[arg] = 1
    if (arg ~ Re["frmat"]) {
      fr = "mat"
      mat = 1
    }
    else if (arg ~ Re["frre"]) {
      fr = "re"
      re = 1
      if (arg ~ "!~") ExcludeRe[arg] = 1
    }
    else if (sa2) {
      fr = "re"
      re = 1
      fr_idx = 1
      FrIdx[arg] = 1
    }
    else {
      print "Invalid frame order arg "arg" - frame arg format examples include: "
      print "[RowHeaderPattern  5[Index5Pattern~search  [HeaderPattern!=30"
      exit 1
    }
  }

  return max_i
}

function MatchCheck(ExprOrder, SearchOrder, AncOrder, CNidx, CNidxRanges) {
  will_print = 0
  for (cnidx in CNidx)
    if (CNidx[cnidx]) { will_print = 1; return }
  for (cnidxrng in CNidxRanges)
    if (CNidxRanges[cnidxrng]) { will_print = 1; return }
  for (expr in ExprOrder)
    if (ExprOrder[expr]) { will_print = 1; return }
  for (search in SearchOrder)
    if (SearchOrder[search]) { will_print = 1; return }
  for (anchor in AncOrder) 
    if (AncOrder[anchor]) { will_print = 1; return }
  
  if (!will_print) {
    print "No matches found"
    exit 1
  }
}

function Indexed(idx_ord, test_idx) {
  test_re = "^" test_idx ",|," test_idx ",|:" test_idx ","
  return idx_ord ~ test_re
}

function BuildRe(Re) {
  Re["ordsep"] = "[[:space:]]*,+[[:space:]]*"
  Re["ws"] = "^[:space:]+$"
  Re["num"] = "[0-9]+"
  Re["int"] = "^[0-9]+$"
  Re["n_int"] = "^-?[0-9]+$"
  Re["nan"] = "[^0-9]"
  Re["decnum"] = "^[[:space:]]*\"?-?\\(?\\$?[0-9,]*\\.?[0-9]+\\)?\"?[[:space:]]*$"
  Re["float"] = "^[[:space:]]*\"?-?[0-9]\\.[0-9]+(E|e\\+)[0-9]+\"?[[:space:]]*$"
  Re["intmat"] = "[0-9!\\+\\-\\*\/%\\^<>=]"
  Re["comp"] = "(<|>|!?=)"
  Re["ext"] = "[[:space:]]*(&&|\\|\\|)[[:space:]]*"
  Re["extcomp"] = "[^&\|]*[^&\|]"
  Re["matarg1"] = "^(NR|NF|len(gth)?\\([0-9]*\\))?[0-9\\+\\-\\*\\/%\\^]+((!=|[=<>])-?[0-9]+([\.][0-9]*)?)?$"
  Re["matarg2"] = "^(NR|NF|len(gth)?\\([0-9]*\\))?(!=|[=<>%])-?[0-9]+([\.][0-9]*)?$"
  Re["frmat"] = "\\[[^~]+[0-9\\+\\-\\*\\/%\\^]+((!=|[=<>])[0-9]+)?$" #]
  Re["frre"] = "\\[.+!?~.+" #]
  Re["alltokens"] = "[(\\.\\.)\\~\\+\\-\\*\\/%\\^<>(!=)=\\[(##)]"
  Re["anc"] = "^(.+##.*|.*##.+)$"
  Re["anc_re"] = "^(/.+/\\.\\.(/.+/)?|(/.+/)?\\.\\./.+/)$"
  Re["nidx_rng"] = "^(-?[0-9]+\\.\\.-[0-9]+|-[0-9]+\\.\\.-?[0-9]+)$"
  Re["len"] = "len(gth)?\\("
}

function BuildTokenMap(TkMap) {
  TkMap["rng"] = "\\.\\."
  TkMap["nidx_rng"] = "\\.\\."
  TkMap["fr"] = "\\[" #]
  TkMap["re"] = "!?\~"
  TkMap["mat"] = "(!=|[\\+\\-\\*\/%\\^<>=])"
  TkMap["anc"] = "(##|\\.\\.)"
  TkMap["anc_re"] = "\\.\\."
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

function EvalCompExpr(left, right, comp) {
  return (comp == "=" && left == right) ||
         (comp == ">" && left > right) ||
         (comp == "<" && left < right)
}

function GetComp(string) {
  if (string ~ ">") comp = ">"
  else if (string ~ "<") comp = "<"
  else if (string ~ "!=") comp = "!="
  else comp = "="

  split(string, Tmp, comp)
  Tmp[0] = comp
}

function PrintField(field_val, field_no, end_field_no) {
  if (!(field_no == end_field_no)) field_val = field_val OFS
  printf "%s", field_val
}

function QsortAsc(A,lft,rght,    x,last) {
  if (lft >= rght) return

  Swap(A, lft, lft + int((rght-lft+1)*rand()))
  last = lft

  for (x = lft+1; x <= rght; x++)
    if (A[x] < A[lft])
      Swap(A, ++last, x)

  Swap(A, left, last)
  QsortAsc(A, left, last-1)
  QsortAsc(A, last+1, right)
}
function QsortDesc(A,lft,rght,    x,last) {
  if (lft >= rght) return

  Swap(A, lft, lft + int((rght-lft+1)*rand()))
  last = lft

  for (x = lft+1; x <= rght; x++)
    if (A[x] > A[lft])
      Swap(A, ++last, x)

  Swap(A, lft, last)
  QsortDesc(A, lft, last-1)
  QsortDesc(A, last+1, rght)
}
function Swap(A,B,x,y,z) {
  z = A[x]; A[x] = A[y]; A[y] = z
  z = B[x]; B[x] = B[y]; B[y] = z
}


function DebugPrint(case, arg) {
  if (case == -1) {
    print "----------- ARGS TESTS -------------" }
  else if (case == 0) {
    print "---------- ARGS FINDINGS -----------"
    print_reo_r_count = pass_r ? "all/undefined" : reo_r_count
    print "Reorder count (row): " print_reo_r_count
    printf "Reorder vals (row):  "
    if (pass_r) print "all"
    else {
      for (i = 1; i < reo_r_len; i++) printf "%s", ReoR[i] ","
      print ReoR[reo_r_count]
    }
    print_reo_c_count = pass_c ? "all/undefined" : reo_c_count
    print "Reorder count (col): " print_reo_c_count
    printf "Reorder vals (col):  "
    if (pass_c) print "all"
    else {
      for (i = 1; i < reo_c_len; i++) printf "%s", ReoC[i] ","
      print ReoC[reo_c_count]
    }
    if (max_nr) print "max_nr: " max_nr
  }
  else if (case == 1) {
    print "i: "i ", r_i: "o_i ", r_len: "len ", token: "token }
  else if (case == 1.5) {
    print "i: "i ", c_i: "o_i ", c_len: "len ", token: "token }
  else if (case == 2) {
    print "FillRange start: " start ", end: " end }
  else if (case == 3) {
    print "arg: "arg", tk: "tk", tk_loc: "tk_loc }
  else if (case == 4) {
    print "----------- CASE MATCHES -----------"
    if (indx) print "index case"
    if (base) print "base case"
    if (base_r) print "base row case"
    if (base_c) print "base column case"
    if (range) print "range case"
    if (base_range) print "base range case"
    if (num) print "line number case"
    if (reo) print "reorder case"
    if (rev) print "reverse case"
    if (sort) print "sort case"
    if (oth) print "remainder case"
    if (base_reo) print "base reorder case"
    if (mat) print "expression case"
    if (re) print "search case"
    if (ext) print "extended logic case"
    if (fr) print "header/frame base case"
    if (fr_ext) print "frame extended case" 
    if (anc) print "anchor search case"
    if (nidx) print "negative index case"
    if (c_nidx) print "column negative index case"
    if (nidx_rng) print "negative index range case"
    if (c_nidx_rng) print "column negative index range case"
    if (len) print "length test case"
    if (idx) print "index number case"
    if (uniq) print "unique output case" }

  else if (case == 5) {
    print "NR: "NR ", f: "f", anchor: "anchor", apply to: "base_expr", evals to: "eval", compare: "comp, compval }
  else if (case == 6) {
    if (length(RRExprs)) { print "------------- RRExprs --------------"
      for (ex in RRExprs) print ex " " ExprRO[ex] }
    if (length(RRSearches)) { print "------------- RRSearches -------------"
      for (se in RRSearches) print se " " SearchRO[se] }
    if (length(RRFrames)) { print "------------- RRFrames ---------------"
      for (fr in RRFrames) print fr }
    if (length(RCExprs)) { print "------------- RCExprs --------------"
      for (ex in RCExprs) print ex " " ExprFO[ex] }
    if (length(RCSearches)) { print "------------- RCSearches -------------"
      for (se in RCSearches) print se " " SearchFO[se] }
    if (length(RCFrames)) { print "------------- RCFrames ---------------"
      for (fr in RCFrames) print fr }
  }
  else if (case == 7) {
    print "------ EVALS OR BASIC OUTPUT -------" }
  else if (case == 8) {
    print "------------- OUTPUT ---------------" }
  else if (case == 9) {
    print "NR: "NR ", f: "f ", search: "search ", base search: "base_search ", startf: "start ", endf: "end ", fieldval: "field }
  else if (case == 10) {
    print "----------- REMAINDERS ------------" }
  else if (case == 11) {
    print "all_reo: " all_reo " rem_idx: " rem_idx }
  else if (case == 12) {
    print "----- RESOLVING EXTENDED LOGIC -----"
    for (ex in RExtensions) print "RowExt: "ex", Reorder span: "RExtensions[ex]" ExtRowOrder: "ExtRO[ex]
    for (ex in CExtensions) print "ColExt: "ex", Reorder span: "CExtensions[ex]" ExtFieldOrder: "ExtFO[ex] }
  else if (case == 13) {
    print "-------- RESOLVE ROW FRAME --------"
    frame = fr_type == "re" ? search : expr
    print "frame: "frame", fr_type: "fr_type", FrameFields[frame]: "FrameFields[frame]", FrameRowFields[frame]: "FrameRowFields[frame] }
  else if (case == 14) {
    print "rf: "rf, "row: "row, "field: "field }
}
