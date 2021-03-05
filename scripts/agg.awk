#!/usr/bin/awk
# DS:AGG
#
# NAME
#       ds:agg, agg.awk
#
# SYNOPSIS
#      ds:agg [file] [r_aggs=+] [c_aggs=+]
#
# DESCRIPTION
#       agg.awk is a script to aggregate values from a data stream or file using various
#       aggregation expressions.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based
#       systems it should be), and call it on a file using aggregation expression:
#
#         > awk -f agg.awk -v r_aggs=+ -v c_aggs=+ file
#
#       ds:agg is the caller function for the agg.awk script. To run any of the examples 
#       below, map AWK args as given in SYNOPSIS.
#
#       If no aggregation expressions are provided to ds:agg, sum agg will be run on all 
#       rows and columns.
#
#       When running with piped data, args are shifted:
#
#         $ data_in | ds:agg [r_aggs=+] [c_aggs=+]
#
# FIELD_CONSIDERATIONS
#       When running ds:agg, an attempt is made to infer field separators of up to three 
#       characters. If none found, FS will be set to default value, a single space = " ".
#       To override FS, add as a trailing awkarg. Be sure to escape and quote if needed.
#       AWK's extended regex can be used as FS if needed.
#
#         $ ds:agg file -F':'
#
#         $ ds:agg file -v FS=" {2,}"
#
#         $ ds:agg file -v FS='\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#         $ ds:agg file -v FS=""
#
#       If ds:agg detects it is connected to a terminal, it will attempt to fit the data
#       into the terminal width using the same field separator. If the data is being sent to
#       a file or a pipe, no attempt to fit will be made. One easy way to turn off fit is to
#       cat the output or redirect to a file.
#
#         $ ds:agg file > /tmp/tmpfile
#
# USAGE
#      Supported agg operators include:
#
#        + (addition)
#        - (subtraction)
#        * (multiplication)
#        / (division)
#
#      All row and column agg args take multiple aggregation expression types:
#
#        Range:       [agg_operator=+]|[index_scope]
#
#          +         -- sum all number field values over all cross indices
#          +|all     -- same as above
#          *|2..6    -- multiply all number field values over cross indices 2 - 6
#
#        Specific:  [agg_operator]|[field_or_numberval][agg_operator][field_or_numberval]..
#
#          $1+3      -- sum number values at cross index two and 3 (literal)
#          $1+$3     -- sum number values at cross indices two and three
#          pork+bean -- sum number values at cross indices with header matching "pork"
#                         and cross indices with header matching "bean"
#
#        Search:    [agg_operator=count]|[cross_index]~search_pattern
#
#          ~test    -- count all incidences of test in every index
#          +|~test  -- sum all number field values where cross index matches "test"
#          *|2~test -- return the product of all number field values from cross 
#                        index where the second cross index matches "test"
#
#        Compare:    [agg_operator=count]|[cross_index][comparison_operator]val
#
#          >4       -- count all fields where the field value is greater than 4
#          +|>4     -- sum all number field values on indices with a field
#                        value greater than 4
#          *|$2>4   -- return the product of all number field values from cross 
#                        index where the second cross index has a field value
#                        greater than 4
#
#           The following comparison operators are supported: =, <, >
#
#        Cross:     [agg_operator=+]|agg_field|[group_fields=all-agg_field]
#
#          $3        -- return the sum of the field values in index 3 grouped
#                         by the unique values from index 1 (header)
#          +|$3      -- same as above
#          +|$3|$4   -- return the sum of the field values in index 3 grouped
#                         by the unique values from index 4
#          +|$3|4..5 -- return the sum of the field values in index 3 grouped
#                         by the unique values from index 4 and 5 combined
#
# 
# AWKARG OPTS
#      By default agg.awk will not attempt to aggregate number values in fields unless
#      the field is formatted as a number. If a field does not follow a typical number
#      format, numbers in the field can still be aggregated using by setting arg:
#
#        -v extract_vals=1 
#
#      Set a fixed maximum column value for processing:
#
#        -v fixed_nf=25
#
#      Force printing of all agg expression headers in output:
#
#        -v og_off=1
#
#
## TODO: Header/key Caggs improvements - agg more than just the first instance of match
## TODO: Central tendency agg operators

BEGIN {
  if (r_aggs && !("off" == r_aggs)) {
    r = 1
    ra_count = split(r_aggs, RAggs, /,/)
  }
  if (c_aggs) {
    c = 1
    ca_count = split(c_aggs, CAggs, /,/)
  }

  for (i in RAggs) {
    RA[i] = AggExpr(RAggs[i], 1, i)
    RAI[RA[i]] = i
    RAggExpr[i] = RA[i]
  }
  for (i in CAggs) {
    CA[i] = AggExpr(CAggs[i], 0, i)
    CAI[CA[i]] = i
    CAggAmort[i] = CA[i]
  }

  if (length(XAggs)) {
    x = 1
    x_base = 1

    for (j = 1; j <= ra_count; j++) {
      if (XAShift[1, j]) {
        r_x_aggs = 1
        delete RAggs[j]
        delete RAI[RA[j]]
        delete RA[j]
        delete RAggExpr[j]
      }
    }
    for (j = 1; j <= ca_count; j++) {
      if (XAShift[0, j]) {
        delete CAggs[j]
        delete CAI[CA[j]]
        delete CA[j]
        delete CAggAmort[j]
      }
    }
    if (!(length(RAggs) || length(CAggs)))
      x_only = 1
  }

  if (r || c || x)
    r_c_base = 1

  if (length(AllAgg))
    gen = 1

  if (og_off)
    header = 1
  else
    print_og = 1

  "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0
  if (gen)
    GenAllAggExpr(max_nr, 0)
  
  OFS = SetOFS()
}

NR < 2 {
  if (!fixed_nf) fixed_nf = NF
  if (header) GenHeaderCAggExpr(HeaderAggs)
  if (gen) GenAllAggExpr(fixed_nf, 1)
  if (r) {
    for (i in RA) {
      if (KeyAgg[1, i]) SetRAggKeyFields(i, RA[i])
    }
  }
  if (x)
    StandardizeXAggExpr(XA, XAForm, XAggExpr, max_nr, fixed_nf)
}

r_c_base {
  _[NR] = $0
  RHeader[NR] = $1

  if (NF < fixed_nf)
    NFPad[NR] = NF - fixed_nf

  for (i in RA) {
    agg = RA[i]
    if (!RAggResult[agg, NR]) {
      r_expr = GenRExpr(agg)
      if (r_expr) RAggResult[agg, NR] = EvalExpr(r_expr)
    }
  }

  for (i in CA) {
    agg = CA[i]
    agg_amort = CAggAmort[i]
    if (ConditionalAgg[agg] && GetOrSetIndexNA(agg, NR, 0))
      continue
    else if (!KeyAgg[0, i] && !SearchAgg[agg_amort] && !Indexed(agg_amort, NR))
      continue
    CAggResult[i] = AdvCarryVec(i, NF, agg_amort, CAggResult[i])
  }
}

x {
  for (compound_i in XA) {
    agg = XA[compound_i]
    agg_expr = XAggExpr[compound_i]
    call = GetCompoundKeyPart(compound_i, 1)
    x_agg_i = CompoundKey[2]
    split(agg_expr, AggExprParts, /\|/)
    agg_op = AggExprParts[1]
    agg_index = AggExprParts[2]
    split(AggExprParts[3], AnchorFields, /\.\./)

    start = AnchorFields[1]
    end = AnchorFields[2] ? AnchorFields[2] : start
    if (end < start) { tmp = end; end = start; start = tmp }

    if (call) {
      agg_row = (NR == agg_index)
      if ((NR < start || NR > end) && !agg_row)
        continue

      if (!r_c_base) _[NR] = $0
    }
    else {
      x_key = $start
      for (xf_i = start + 1; xf_i <= end; xf_i++) {
        if (agg_index == xf_i) continue
        x_key = x_key SUBSEP "::" $xf_i
      }

      if (!XAggKeySave[x_agg_i, x_key]) {
        XAggLength[x_agg_i]++
        XAggKeySave[x_agg_i, x_key] = XAggLength[x_agg_i]
        XAggKey[x_agg_i, XAggLength[x_agg_i]] = x_key
      }

      val = $agg_index
      if (val == "") continue
      extract_val = GetOrSetExtractVal(val)
      if (!extract_val && extract_val != 0)
        continue
      trunc_val = GetOrSetTruncVal(extract_val)
      key_id = XAggKeySave[x_agg_i, x_key]

      if (XAggResult[x_agg_i, key_id])
        XAggResult[x_agg_i, key_id] = EvalExpr(XAggResult[x_agg_i, key_id] agg_op trunc_val)
      else
        XAggResult[x_agg_i, key_id] = trunc_val
    }
  }
}


END {
  if (err) exit err

  if (r_conditional_aggs)
    ResolveConditionalRAggs()
  if (r_x_aggs)
    ResolveRXAggs()

  totals = length(Totals)

  if (!x_only) {
    for (i = 1; i <= NR; i++) {
      if (header && ca_count) printf "%s", OFS
      if (print_og) {
        split(_[i], Row, FS)
        for (j = 1; j <= fixed_nf; j++) {
          printf "%s", Row[j]
          if (j < fixed_nf || ra_count)
            printf "%s", OFS
        }
      }
      else if (i == 1 && header) {
        printf "%s", RHeader[i] OFS
      }
      for (j = 1; j <= ra_count; j++) {
        agg = RA[j]
        if (!agg) continue
        print_header = (header || !RAggResult[agg, i]) && i < 2
        print_str = print_header ? RAggs[j] : RAggResult[agg, i]
        printf "%s", print_str
        if (j < ra_count)
          printf "%s", OFS
      }

      print ""
    }

    for (i = 1; i <= ca_count; i++) {
      if (!CAggs[i]) continue
      skip_first = CAggResult[i] ~ /^0?,/
      if (header || skip_first) printf "%s", CAggs[i] OFS
      if (!CAggResult[i]) { print ""; continue }
      split(CAggResult[i], CAggVec, ",")
      start = skip_first && !header ? 2 : 1

      for (j = start; j <= fixed_nf; j++) {
        if (CAggVec[j]) printf "%s", EvalExpr(CAggVec[j])
        if (j < fixed_nf)
          printf "%s", OFS
      }
      if (totals) {
        printf "%s", OFS
        for (j = 1; j <= ra_count; j++) {
          printf "%s", Totals[i, j]
          if (j < ra_count)
            printf "%s", OFS
        }
      }
      
      print ""
    }
  }

  n_x = length(XA)
  if (n_x) {
    if (!x_only) print ""
    for (compound_i in XA) {
      agg = XA[compound_i]
      agg_expr = XAggExpr[compound_i]
      split(agg_expr, AggExprParts, /\|/)
      agg_op = AggExprParts[1]
      agg_index = AggExprParts[2]
      agg_group_scope = AggExprParts[3]
      call = GetCompoundKeyPart(compound_i, 1)
      x_agg_i = CompoundKey[2]
      rel_len = XAggLength[x_agg_i]

      if (call)
        print "Cross Aggregation: "agg_op" on row "agg_index" grouped by row "agg_group_scope
      else
        print "Cross Aggregation: "agg_op" on field "agg_index" grouped by field "agg_group_scope

      for (j = 1; j <= rel_len; j++) {
        print XAggKey[x_agg_i, j], XAggResult[x_agg_i, j] }
      if (n_x > 1) print ""
    }
  }

  if (debug) {
    for (i in RA) {
      print i" "RAggs[i]" "RA[i]
      print "KeyAgg? "KeyAgg[1, i]
      print "SearchAgg? "SearchAgg[RA[i]]
      print "ConditionalAgg? "ConditionalAgg[RA[i]]
      print "AllAgg? "AllAgg[RA[i]]
    }
    for (i in CA) {
      print i" "CAggs[i]" "CA[i]
      print "KeyAgg? "KeyAgg[0, i]
      print "SearchAgg? "SearchAgg[CA[i]]
      print "ConditionalAgg? "ConditionalAgg[CA[i]]
      print "AllAgg? "AllAgg[CA[i]]
    }
  }
}

function AggExpr(agg_expr, call, call_idx) {
  orig_agg_expr = agg_expr
  gsub(/[[:space:]]+/, "", agg_expr)
  all_agg = 0
  spec_agg = 0
  conditional_agg = 0

  if (agg_expr ~ /^[\+\-\*\/]/) {
    if (agg_expr ~ /^[\+\-\*\/](\|all)?$/) {
      if (!(agg_expr ~ /\|all$/))
        agg_expr = agg_expr "|all"
      all_agg = 1
      AllAgg[agg_expr] = 1
    }

    else if (agg_expr ~ /^[\+\-\*\/]\|(\$)?[0-9]+\.\.(\$)?[0-9]+/) {
      split(agg_expr, AggBase, /\|/)
      op = AggBase[1] ? AggBase[1] : "+"
      gsub(/\$/, "", AggBase[2])
      split(AggBase[2], AggAnchor, /\.\./)
      if (!AggAnchor[1]) AggAnchor[1] = 1
      if (!AggAnchor[2])
        AggAnchor[2] = call > 0 ? max_nr : 100
      agg_expr = op "$" AggAnchor[1]
      for (j = AggAnchor[1] + 1; j < AggAnchor[2]; j++)
        agg_expr = agg_expr op "$" j
      agg_expr = agg_expr op "$" AggAnchor[2]
    }

    else if (agg_expr ~ /^[\+\-\*\/]\|(\$)?[0-9]+(\|(\$)?[0-9]+(\.\.(\$)?[0-9]+)?)?$/) {
      gsub(/\$/, "", agg_expr)
      XAggs[call, ++x_agg_i] = orig_agg_expr
      XA[call, x_agg_i] = agg_expr
      XAI[call, agg_expr] = x_agg_i
      XAggExpr[call, x_agg_i] = agg_expr
      
      if (agg_expr ~ /^[\+\-\*\/]\|(\$)?[0-9]+$/)
        XAForm[call, x_agg_i] = 2
      else if (agg_expr ~ /^[\+\-\*\/]\|(\$)?[0-9]+\|(\$)?[0-9]+$/)
        XAForm[call, x_agg_i] = 3
      else
        XAForm[call, x_agg_i] = 4

      XAShift[call, call_idx] = x_agg_i
      return ""
    }

    else if (agg_expr ~ /^[\+\-\*\/]|((\$)?[0-9]+)?([<>=][0-9]+|[~])/) {
      gsub(/\|\|/, "___OR___", agg_expr)
      ConditionalAgg[agg_expr] = SetConditionalAgg(agg_expr)
      AllAgg[agg_expr] = 1
      conditional_agg = 1
      if (call) r_conditional_aggs = 1
    }

    else {
      print "Unable to parse aggregation expression " agg_expr
      exit 1
    }
  }

  else if (agg_expr ~ /^~/ && !(agg_expr ~ /[^\|]+\|[^\|]+/))
    SearchAgg[agg_expr] = substr(agg_expr, 2, length(agg_expr))

  else if (agg_expr ~ /[A-z]/)
    KeyAgg[call, call_idx] = 1

  else if (agg_expr ~ /^(\$)?[0-9]+([\+\-\*\/][\+\-\*\/]?(\$)?[0-9]+)+$/)
    spec_agg = 1

  else if (agg_expr ~ /^(\$)?[0-9]+$/) {
    gsub(/\$/, "", agg_expr)
    XAggs[call, ++x_agg_i] = orig_agg_expr
    XA[call, x_agg_i] = agg_expr
    XAI[call, agg_expr] = x_agg_i
    XAggExpr[call, x_agg_i] = agg_expr
    XAForm[call, x_agg_i] = 1
    XAShift[call, call_idx] = x_agg_i
    return ""
  }

  else {
    print "Unable to parse aggregation expression " agg_expr
    exit 1
  }

  if (!(all_agg || conditional_agg || SearchAgg[agg_expr])) {
    match(agg_expr, /^[\+\-\*\/]/)
    if (agg_expr ~ /^[\+]/)
      agg_expr = "0+" substr(agg_expr, RLENGTH + 1, length(agg_expr))
    else if (agg_expr ~ /^[\-]/)
      agg_expr = "0-" substr(agg_expr, RLENGTH + 1, length(agg_expr))
    else if (agg_expr ~ /^[\*\/]/)
      agg_expr = "1*" substr(agg_expr, RLENGTH + 1, length(agg_expr))
  }

  return agg_expr
}

function SetConditionalAgg(conditional_agg_expr) {
  split(conditional_agg_expr, ConditionalAggParts, /\|/)

  conditions = ConditionalAggParts[2]
  n_ors = split(conditions, Ors, /[[:space:]]*___OR___[[:space:]]*/)
  for (o_i = 1; o_i <= n_ors; o_i++)
    Condition[conditional_agg_expr, o_i] = Ors[o_i]

  return n_ors
}

function GenHeaderCAggExpr(HeaderAggs) { # TODO remove
  for (agg in HeaderAggs) {
    split(agg, Agg, /\|/)
    if (agg in CAI)
      CA[CAI[agg]] = AggExpr(Agg[1]"|1.."max, 0)
    if (agg in XAI)
      XA[XAI[agg]] = AggExpr(Agg[1]"|1.."max, -1)
  }
}

function GenAllAggExpr(max, call) {
  for (agg in AllAgg) {
    split(agg, Agg, /\|/)
    temp_agg = Agg[1]"|1.."max
    if (call > 0 && agg in RAI)
      RAggExpr[RAI[agg]] = AggExpr(temp_agg, 1)
    else if (!call && agg in CAI)
      CAggAmort[CAI[agg]] = AggExpr(temp_agg, 0)
  }
}

function SetRAggKeyFields(r_agg_i, agg_expr) {
  initial_agg_expr = agg_expr
  keys = split(agg_expr, Keys, /[\+\*\-\/]/)
  gsub(/\+/, "____+____", agg_expr)
  gsub(/\-/, "____-____", agg_expr)
  gsub(/\*/, "____*____", agg_expr)
  gsub(/\//, "____/____", agg_expr)
  for (k = 1; k <= length(Keys); k++) {
    for (f = 1; f <= NF; f++)
      if ($f ~ Keys[k])
        gsub("(____)?"Keys[k]"(____)?", "$"f, agg_expr)
  }
  gsub(/[^\+\*\-\/0-9\$]/, "", agg_expr)
  RA[r_agg_i] = agg_expr
  KeySwap(RAI, initial_agg_expr, agg_expr)
}

function GetOrSetIndexNA(agg, idx, call) {
  if (IndexNA[agg, idx, call]) return IndexNA[agg, idx, call]

  n_ors = ConditionalAgg[agg]
  idx_na = 1

  for (o_i = 1; o_i <= n_ors; o_i++) {
    condition = Condition[agg, o_i]
    split(condition, Ands, /&&/)
    and_conditions_met = 1
    for (a_i = 1; a_i <= length(Ands); a_i++) {
      and_condition = Ands[a_i]
      if (and_condition ~ /^[(\$)?0-9]*~/) { # Search case
        split (and_condition, AndCondition, /~/)
        condition_search_scope = AndCondition[1] # May be blank
        condition_search = AndCondition[2]
        spec_search = match(condition_search_scope, /^[(\$)?0-9]+$/)

        if (call) {
          col_confirmed = 0
          start = spec_search ? condition_search_scope : 1
          end = spec_search ? condition_search_scope : NR
          for (r_i = start; r_i <= end; r_i++) {
            if (_[r_i, idx] ~ condition_search) {
              col_confirmed = 1
              break
            }
          }
          if (!col_confirmed) and_conditions_met = 0
        }
        else {
          if (spec_search) {
            if (!($condition_search_scope ~ condition_search)) {
              and_conditions_met = 0
              break
            }
          }
          else if (!($0 ~ condition_search)) {
            and_conditions_met = 0
            break
          }
        }
      }

      else { # Compare case
        eval_expr = ""
        GetComp(and_condition)
        comp = CompExpr[0]
        test_expr = CompExpr[1] # May be blank
        comp_val = CompExpr[2]

        if (!call && !test_expr) {
          row_confirmed = 0
          for (f_i = 1; f_i <= NF; f_i++) {
            val = $f_i
            if (val == "") continue
            extract_val = GetOrSetExtractVal(val)
            if (!extract_val && extract_val != 0) continue
            if (debug) print and_condition " :: COMP: " extract_val comp comp_val

            if (EvalCompExpr(GetOrSetTruncVal(extract_val), comp_val, comp)) {
              row_confirmed = 1
              break
            }
          }
          if (!row_confirmed) {
            and_conditions_met = 0
            break
          }
        }
        else {
          fs = split(test_expr, Fs, /[\+\*\-\/%]/)
          ops = split(test_expr, Ops, /[^\+\*\-\/%]+/)

          for (f_i = 1; f_i <= fs; f_i++) {
            f = Fs[f_i]; op = Ops[f_i+1]
            if (f ~ /\$[0-9]+/) {
              gsub(/(\$|[[:space:]]+)/, "", f)
              val = f ? (call ? _[f, idx] : $f) : ""
              gsub(/(\$|\(|\)|^[[:space:]]+|[[:space:]]+$)/, "", val)
            }
            else
              val = f # Expects a static number value

            if (val == "") continue
            extract_val = GetOrSetExtractVal(val)
            if (!extract_val && extract_val != 0) continue
            if (debug) print and_condition " :: COMP: " eval_expr val op

            eval_expr = eval_expr GetOrSetTruncVal(extract_val) op
          }

          if (!EvalCompExpr(EvalExpr(eval_expr), comp_val, comp)) {
            and_conditions_met = 0
            break
          }
        }
      }
    }

    if (and_conditions_met) {
      idx_na = 0
      break
    }
  }

  IndexNA[agg, idx, call] = idx_na
  return idx_na
}

function ResolveConditionalRAggs() {
  for (i in RA) {
    agg = RA[i]
    if (agg in ConditionalAgg) {
      split(agg, ConditionalAggParts, /\|/)
      cond_op = ConditionalAggParts[1]
      for (j = 1; j <= NR; j++) {
        expr = ""
        for (k = 1; k <= fixed_nf; k++) {
          f_val = _[j, k]
          if (GetOrSetIndexNA(agg, k, 1))
            continue
          if (f_val) {
            expr = expr cond_op f_val
          }
        }
 
        RAggResult[agg, j] = EvalExpr(expr) }}}
}

function GenRExpr(agg) {
  expr = ""
  agg_expr = RAggExpr[RAI[agg]]

  if (SearchAgg[agg]) {
    agg_search = SearchAgg[agg]
    for (f = 1; f <= fixed_nf; f++)
      if ($f ~ agg_search) expr = expr "1+"
    if (!expr) expr = "0"
  }

  else if (ConditionalAgg[agg]) {
    for (f = 1; f <= fixed_nf; f++) {
      if (RowSet[NR]) break
      _[NR, f] = $f
    }
    RowSet[NR] = 1
  }

  else {
    fs = split(agg_expr, Fs, /[\+\*\-\/]/)
    ops = split(agg_expr, Ops, /[^\+\*\-\/]+/)
    for (j = 1; j <= fs; j++) {
      f = Fs[j]; op = Ops[j+1]
      if (f ~ /\$[0-9]+/) {
        gsub(/(\$|[[:space:]]+)/, "", f)
        val = f ? $f : ""
        gsub(/(\$|\(|\)|^[[:space:]]+|[[:space:]]+$)/, "", val)
      }
      else
        val = f # Expects a static number value

      if (debug2) print agg " :: GENREXPR: " expr val op
      if (val == "") continue

      extract_val = GetOrSetExtractVal(val)
      if (!extract_val && !(extract_val == 0)) continue

      expr = expr GetOrSetTruncVal(extract_val) op
    }
  }

  return expr
}

function AdvCarryVec(c_agg_i, nf, agg_amort, carry) { # TODO: This is wildly inefficient
  split(carry, CarryVec, ",")
  t_carry = ""
  active_key = ""
  search = 0
  if (SearchAgg[agg_amort]) {
    search = SearchAgg[agg_amort]
  }
  else {
    if (!agg_amort) return carry
    match(agg_amort, /[^\+\*\-\/]+/)
    if (KeyAgg[0, c_agg_i]) {
      row = $0; gsub(/[[:space:]]+/, "", row)
      active_key = substr(agg_amort, RSTART, RLENGTH)
      if (!(row ~ active_key))
        return carry }
    right = substr(agg_amort, RSTART + RLENGTH, length(agg_amort))
    CAggAmort[c_agg_i] = right
    match(agg_amort, /[\+\*\-\/]+/)
    margin_op = substr(agg_amort, RSTART, RLENGTH)
  }

  if (debug) print c_agg_i, agg_amort, carry

  for (f = 1; f <= nf; f++) {
    sep = f < 2 ? "" : ","
    val = $f
    if (search) { 
      if (!CarryVec[f]) CarryVec[f] = "0"
      margin_op = val ~ search ? "+1" : "" 
      t_carry = t_carry sep CarryVec[f] margin_op
    }
    else {
      gsub(/(\$|\(|\)|^[[:space:]]+|[[:space:]]+$)/, "", val)
      extract_val = GetOrSetExtractVal(val)
      if (!extract_val && extract_val != 0) {
        t_carry = t_carry sep CarryVec[f]
      }
      else {
        if (!CarryVec[f]) {
          if (margin_op == "*")
            CarryVec[f] = "1"
          else if (margin_op == "/")
            margin_op = ""
          else {
            CarryVec[f] = "0"
            if (active_key && margin_op == "-") margin_op = "+"
          }
        }
        t_carry = t_carry sep CarryVec[f] margin_op GetOrSetTruncVal(extract_val)
      }
    }

    if (debug2) print CA[c_agg_i]" :: ADVCARRYVEC: " t_carry sep CarryVec[f] margin_op val
  }

  if (!search && (!header || NR > 1)) {
    for (j = 1; j <= ra_count; j++) {
      if (RAggResult[RA[j], NR] == "" || (NR == 1 && RAggResult[RA[j], NR] == 0)) continue
      if (margin_op == "*" && Totals[c_agg_i, j] == "") Totals[c_agg_i, j] = 1
      if (debug2)
        print NR" TOTALADV: RA "RA[j]", CA "CA[c_agg_i]" -- "Totals[c_agg_i, j] margin_op RAggResult[RA[j], NR]
      Totals[c_agg_i, j] = EvalExpr(Totals[c_agg_i, j] margin_op RAggResult[RA[j], NR])
    }
  }

  return t_carry
}

function StandardizeXAggExpr(XA, XAForm, XAggExpr, max_rows, max_cols) {
  for (compound_i in XA) {
    call = GetCompoundKeyPart(compound_i, 1)
    agg = XA[compound_i]
    max = call ? max_rows : max_cols
    if (XAForm[compound_i] < 2)
      XAggExpr[compound_i] = "+|"agg"|1"
    else if (XAForm[i] < 3)
      XAggExpr[compound_i] = agg"|1.."max
    else if (XAForm[i] < 4)
      XAggExpr[compound_i] = agg }
}

function ResolveRXAggs() {
  for (compound_i in XA) {
    call = GetCompoundKeyPart(compound_i, 1)
    if (!call) continue

    agg = XA[compound_i]
    agg_expr = XAggExpr[compound_i]
    x_agg_i = CompoundKey[2]

    split(agg_expr, AggExprParts, /\|/)
    agg_op = AggExprParts[1]
    agg_index = AggExprParts[2]
    split(AggExprParts[3], AnchorFields, /\.\./)

    start = AnchorFields[1]
    end = AnchorFields[2] ? AnchorFields[2] : start
    if (end < start) { tmp = end; end = start; start = tmp }

    agg_row = (NR == agg_index)
    for (xf_i = start; xf_i <= end; xf_i++) {
      if (agg_index == xf_i) continue
      split(_[xf_i], Row, FS)
      for (f = 1; f <= fixed_nf; f++) {
        if (xf_i == start)
          XKey[f] = Row[f]
        else {
          tmp = XKey[f]
          delete XAggKey[x_agg_i, XAggKeySave[x_agg_i, tmp]]
          delete XAggKeySave[x_agg_i, tmp]
          XKey[f] = tmp SUBSEP "::" Row[f]
        }
      }
    }

    for (f = 1; f <= fixed_nf; f++) {
      if (!XAggKeySave[x_agg_i, XKey[f]]) {
        XAggLength[x_agg_i]++
        XAggKeySave[x_agg_i, XKey[f]] = XAggLength[x_agg_i]
        XAggKey[x_agg_i, XAggLength[x_agg_i]] = XKey[f]
      }
    }

    split(_[agg_index], AggRow, FS)
    agg_row_len = length(AggRow)

    for (f = 1; f <= agg_row_len; f++) {
      val = AggRow[f]
      if (val == "") continue
      extract_val = GetOrSetExtractVal(val)
      if (!extract_val && extract_val != 0)
        continue
      trunc_val = GetOrSetTruncVal(extract_val)
      key_id = XAggKeySave[x_agg_i, XKey[f]]

      if (XAggResult[x_agg_i, key_id])
        XAggResult[x_agg_i, key_id] = EvalExpr(XAggResult[x_agg_i, key_id] agg_op trunc_val)
      else
        XAggResult[x_agg_i, key_id] = trunc_val
    }
  }
}

function GetComp(string) {
  if (string ~ ">") comp = ">"
  else if (string ~ "<") comp = "<"
  else if (string ~ "!=") comp = "!="
  else comp = "="
  split(string, CompExpr, comp)
  CompExpr[0] = comp
}

function EvalCompExpr(left, right, comp) {
  return (comp == "=" && left == right) ||
         (comp == ">" && left > right) ||
         (comp == "<" && left < right)
}

function Indexed(expr, test_idx) {
  return expr ~ "\\$" test_idx "([^0-9]|$)"
}

function GetOrSetTruncVal(val) {
  if (TruncVal[val]) return TruncVal[val]

  large_val = val > 999
  large_dec = val ~ /\.[0-9]{3,}/
  if ((large_val && large_dec) || val ~ /^-?[0-9]*\.?[0-9]+(E|e)\+?([4-9]|[1-9][0-9]+)$/)
    trunc_val = int(val)
  else
    trunc_val = sprintf("%f", val) # Small floats flow through this logic

  trunc_val += 0
  TruncVal[val] = trunc_val
  return trunc_val
}

function GetOrSetExtractVal(val) {
  if (ExtractVal[val]) return ExtractVal[val]
  if (NoVal[val]) return ""

  if (match(val, /-?[0-9]*\.?[0-9]+((E|e)(\+|-)[0-9]+)?/)) {
    if (extract_vals)
      extract_val = substr(val, RSTART, RSTART+RLENGTH)
    else if (RSTART > 1 || RLENGTH < length(val)) {
      NoVal[val] = 1
      return ""
    }
    else
      extract_val = val
    }
  else {
    NoVal[val] = 1
    return ""
  }

  extract_val += 0  
  ExtractVal[val] = extract_val
  return extract_val
}

function KeySwap(Arr, orig_key, new_key) {
  if (!Arr[orig_key]) return
  if (Arr[new_key] && Arr[orig_key] != Arr[new_key]) {
    print "WARNING: Array value at key "new_key"="Arr[new_key]" overwritten with new value "Arr[orig_key]
  }
  Arr[new_key] = Arr[orig_key]
  delete Arr[orig_key]
}

function GetCompoundKeyPart(key_string, idx) {
  split(key_string, CompoundKey, SUBSEP)
  return CompoundKey[idx]
}
