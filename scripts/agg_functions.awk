function AggregationExpr(agg_expr, call, call_idx, reparse) {
    orig_agg_expr = agg_expr
    gsub(/[[:space:]]+/, "", agg_expr)
    all_agg = 0
    mean_agg = 0
    spec_agg = 0
    conditional_agg = 0
    
    if (agg_expr ~ /^([\+\-\*\/]|m(ean)?)/) {
        if (agg_expr ~ /^([\+\-\*\/]|m(ean?))(\|all)?$/) {
            if (match(agg_expr, /^m/)) {
                mean_agg = 1
            }
            
            if (!(agg_expr ~ /\|all$/)) {
                agg_expr = agg_expr "|all"
            }

            all_agg = 1
            AllAgg[agg_expr] = 1
            
            if (mean_agg) {
                MeanAgg[agg_expr] = 1
            }
        }
        else if (agg_expr ~ /^([\+\-\*\/]|m(ean)?)\|(\$)?[0-9]+\.\.(\$)?[0-9]+/) {
            if (gsub(/^m[^\|]*\|/, "+|", agg_expr)) {
                mean_agg = 1
            }
            split(agg_expr, AggBase, /\|/)
            operation = AggBase[1] ? AggBase[1] : "+"
            gsub(/\$/, "", AggBase[2])
            split(AggBase[2], AggAnchor, /\.\./)

            if (!AggAnchor[1]) AggAnchor[1] = 1

            if (!AggAnchor[2]) {
                AggAnchor[2] = call > 0 ? max_nr : 100
            }

            agg_expr = operation "$" AggAnchor[1]

            for (j = AggAnchor[1] + 1; j < AggAnchor[2]; j++) {
                agg_expr = agg_expr operation "$" j
            }

            agg_expr = agg_expr operation "$" AggAnchor[2]
        }
        else if (agg_expr ~ /^([\+\-\*\/]|m(ean)?)\|(\$)?[0-9]+(\|(\$)?[0-9]+(\.\.(\$)?[0-9]+)?)?$/) {
            gsub(/\$/, "", agg_expr)
            if (gsub(/^m[^\|]*\|/, "+|", agg_expr)) {
                mean_agg = 1
            }
            CrossAggs[call, ++cross_agg_i] = orig_agg_expr
            XA[call, cross_agg_i] = agg_expr
            XAI[call, agg_expr] = cross_agg_i
            CrossAggExpr[call, cross_agg_i] = agg_expr
 
            if (agg_expr ~ /^([\+\-\*\/]|m(ean)?)\|(\$)?[0-9]+$/) {
                CrossAggForm[call, cross_agg_i] = 2
            }
            else if (agg_expr ~ /^([\+\-\*\/]|m(ean)?)\|(\$)?[0-9]+\|(\$)?[0-9]+$/) {
                CrossAggForm[call, cross_agg_i] = 3
            }
            else {
                CrossAggForm[call, cross_agg_i] = 4
            }
            
            if (mean_agg) {
                MeanAgg[cross_agg_i] = 1
            }

            XAShift[call, call_idx] = cross_agg_i
            return ""
        }
        else if (agg_expr ~ /^([\+\-\*\/]|m(ean)?)|((\$)?[0-9]+)?([<>=][0-9]+|[~])/) {
            if (gsub(/^m[^\|]*\|/, "+|", agg_expr)) {
                mean_agg = 1
            }
            gsub(/\|\|/, "___OR___", agg_expr)
            ConditionalAgg[agg_expr] = SetConditionalAgg(agg_expr)
            AllAgg[agg_expr] = 1
            
            if (mean_agg) {
                MeanAgg[agg_expr] = 1
            }
            
            conditional_agg = 1
            if (call) conditional_row_aggs = 1
        }
        else if (agg_expr ~ /^(med|q[1-3]|mode|sd)/) {
            # Handle extended aggregation types
            type = detect_agg_type(agg_expr)
            if (type) {
                AggType[agg_expr] = type
                # Convert to sum for initial processing
                if (type == "stddev") {
                    StdDevAgg[agg_expr] = 1
                    agg_expr = "+|" substr(agg_expr, match(agg_expr, /\|/) ? RSTART : length(agg_expr) + 1)
                } else {
                    CollectVals[agg_expr] = 1
                    agg_expr = "+|" substr(agg_expr, match(agg_expr, /\|/) ? RSTART : length(agg_expr) + 1)
                }
            } else {
                print "Unable to parse aggregation expression " agg_expr
                exit 1
            }
        }
        else {
            print "Unable to parse aggregation expression " agg_expr
            exit 1
        }
    }
    else if (agg_expr ~ /^~/ && !(agg_expr ~ /[^\|]+\|[^\|]+/)) {
        SearchAgg[agg_expr] = substr(agg_expr, 2, length(agg_expr))
    }
    else if (agg_expr ~ /[A-z]/) {
        KeyAgg[call, call_idx] = 1
    }
    else if (agg_expr ~ /^(\$[0-9]+|[0-9\.]+)([\+\-\*\/][\+\-\*\/]?(\$[0-9]+|[0-9\.]+))+$/) {
        spec_agg = 1
    }
    else if (agg_expr ~ /^(\$)?[0-9]+$/) {
        gsub(/\$/, "", agg_expr)
        CrossAggs[call, ++cross_agg_i] = orig_agg_expr
        XA[call, cross_agg_i] = agg_expr
        XAI[call, agg_expr] = cross_agg_i
        CrossAggExpr[call, cross_agg_i] = agg_expr
        CrossAggForm[call, cross_agg_i] = 1
        XAShift[call, call_idx] = cross_agg_i
        return ""
    }
    else {
        print "Unable to parse aggregation expression " agg_expr
        exit 1
    }

    if (!(all_agg || conditional_agg || SearchAgg[agg_expr])) {
        match(agg_expr, /^[\+\-\*\/]/)
        if (agg_expr ~ /^[\+]/) {
            agg_expr = "0+" substr(agg_expr, RLENGTH + 1, length(agg_expr))
        }
        else if (agg_expr ~ /^[\-]/) {
            agg_expr = "0-" substr(agg_expr, RLENGTH + 1, length(agg_expr))
        }
        else if (agg_expr ~ /^[\*\/]/) {
            agg_expr = "1*" substr(agg_expr, RLENGTH + 1, length(agg_expr))
        }
        
        if (mean_agg && !reparse) {
            MeanAgg[agg_expr] = 1
        }
    }

    return agg_expr
}

function SetConditionalAgg(conditional_agg_expr) {
    fast_split(conditional_agg_expr, ConditionalAggParts, /\|/)

    conditions = ConditionalAggParts[2]
    n_ors = split(conditions, Ors, /[[:space:]]*___OR___[[:space:]]*/)

    for (or_i = 1; or_i <= n_ors; or_i++) {
        Condition[conditional_agg_expr, or_i] = Ors[or_i]
    }

    return n_ors
}

function GenAllAggregationExpr(max, call) {
    for (agg in AllAgg) {
        fast_split(agg, Agg, /\|/)
        temp_agg = Agg[1]"|1.."max

        if (call > 0 && agg in RAI) {
            RowAggExpr[RAI[agg]] = AggregationExpr(temp_agg, 1, 0, 1)
        }
        else if (!call && agg in CAI) {
            ColumnAggAmort[CAI[agg]] = AggregationExpr(temp_agg, 0, 0, 1)
        }
    }
}

function SetRowAggKeyFields(row_agg_i, agg_expr) {
    initial_agg_expr = agg_expr
    keys = fast_split(agg_expr, Keys, /[\+\*\-\/]/)
  
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
    RA[row_agg_i] = agg_expr
    RowAggExpr[row_agg_i] = agg_expr
    KeySwap(RAI, initial_agg_expr, agg_expr)
}

function GetOrSetIndexNA(agg, idx, call) {
    if (IndexNA[agg, idx, call]) return IndexNA[agg, idx, call]
    
    n_ors = ConditionalAgg[agg]
    idx_na = 1
    
    for (or_i = 1; or_i <= n_ors; or_i++) {
        condition = Condition[agg, or_i]
        split(condition, Ands, /&&/)
        and_conditions_met = 1
    
        for (a_i = 1; a_i <= length(Ands); a_i++) {
            and_condition = Ands[a_i]
            
            # Search case
            if (and_condition ~ /^[(\$)?0-9]*~/) {
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

            # Compare case
            else {
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
                            val = f ? CleanVal(call ? _[f, idx] : $f) : ""
                        }
                        else {
                            val = f # Expects a static number value
                        }

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

function ResolveConditionalRowAggs() {
    for (i in RA) {
        agg = RA[i]
        if (agg in ConditionalAgg) {
            split(agg, ConditionalAggParts, /\|/)
            cond_op = ConditionalAggParts[1]
      
            for (j = 1; j <= NR; j++) {
                expr = ""
        
                for (k = 1; k <= fixed_nf; k++) {
                    f_val = _[j, k]
                    if (GetOrSetIndexNA(agg, k, 1)) {
                        continue
                    }
                    if (f_val) {
                        expr = expr cond_op f_val
                        
                        if (MeanAgg[agg]) {
                            RowAggCounts[agg, j]++
                        }
                    }
                    else if (MeanAgg[agg] && length(f_val) > 0) {
                        RowAggCounts[agg, j]++
                    }
                }
 
                RowAggResult[agg, j] = EvalExpr(expr)
            }
        }
    }
}

function GenRExpr(agg) {
    expr = ""
    agg_expr = RowAggExpr[RAI[agg]]
    
    if (SearchAgg[agg]) {
        agg_search = SearchAgg[agg]
    
        for (f = 1; f <= fixed_nf; f++) {
            if ($f ~ agg_search) expr = expr "1+"
        }

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
            f = Fs[j]
            op = Ops[j+1]

            if (f ~ /\$[0-9]+/) {
                gsub(/(\$|[[:space:]]+)/, "", f)
                val = f ? CleanVal($f) : ""
            }
            else {
                val = f # Expects a static number value
            }

            if (debug2) print agg " :: GENREXPR: " expr val op
            if (val == "") continue

            extract_val = GetOrSetExtractVal(val)
            if (!extract_val && !(extract_val == 0)) continue

            expr = expr GetOrSetTruncVal(extract_val) op
            
            if (MeanAgg[agg] && j < fs) {
                RowAggCounts[agg, NR]++
            }
        }
    }

    return expr
}

function CleanVal(val) {
    if (awksafe) {
        gsub(/(\$|\£|\(|\)|^[[:space:]]+|[[:space:]]+$)/, "", val)
    }
    else {
        gsub(/(\$|\(|\)|^[[:space:]]+|[[:space:]]+$)/, "", val)
    }
    return val
}

function AdvanceCarryVector(column_agg_i, nf, agg_amort, carry) { # TODO: This is wildly inefficient
    split(carry, CarryVec, ",")
    t_carry = ""
    active_key = ""
    search = 0
    
    if (SearchAgg[agg_amort]) {
        search = SearchAgg[agg_amort]
    }
    else {
        if (!agg_amort) return carry
        if (!carry) {
            pre_seeded_agg = agg_amort ~ /^0[\+\*\-\/]/
        }
        match(agg_amort, /[^\+\*\-\/]+/)

        if (KeyAgg[0, column_agg_i]) {
            row = $0; gsub(/[[:space:]]+/, "", row)
            active_key = substr(agg_amort, RSTART, RLENGTH)
      
            if (!(row ~ active_key)) {
                return carry
            }
        }

        right = substr(agg_amort, RSTART + RLENGTH, length(agg_amort))
        ColumnAggAmort[column_agg_i] = right
        match(agg_amort, /[\+\*\-\/]+/)
        margin_operator = substr(agg_amort, RSTART, RLENGTH)
    }

    if (debug) print column_agg_i, agg_amort, carry, margin_operator
    
    for (f = 1; f <= nf; f++) {
        sep = f < 2 ? "" : ","
        val = $f
    
        if (search) { 
            if (!CarryVec[f]) CarryVec[f] = "0"
            margin_operator = val ~ search ? "+1" : "" 
            t_carry = t_carry sep CarryVec[f] margin_operator
        }
        else {
            val = CleanVal(val)
            extract_val = GetOrSetExtractVal(val)
      
            if (!extract_val && extract_val != 0) {
                t_carry = t_carry sep CarryVec[f]
            }
            else {
                if (!CarryVec[f]) {
                    if (margin_operator == "*") {
                        CarryVec[f] = "1"
                    }
                    else if (margin_operator == "/") {
                        margin_operator = ""
                    }
                    else {
                        CarryVec[f] = "0"
                        if ((active_key || !pre_seeded_agg) && margin_operator == "-") margin_operator = "+"
                    }
                }
        
                t_carry = t_carry sep CarryVec[f] margin_operator GetOrSetTruncVal(extract_val)

                agg = CA[column_agg_i]

                if (MeanAgg[agg]) {
                    ColumnAggCounts[agg, f]++
                }
            }
        }

        if (debug2) {
            print CA[column_agg_i]" :: ADVCARRYVEC: " t_carry sep CarryVec[f] margin_operator val
        }
    }

    if (!search && (!header || NR > 1)) {
        for (j = 1; j <= row_aggs_count; j++) {
            if (RowAggResult[RA[j], NR] == "" || (NR == 1 && RowAggResult[RA[j], NR] == 0)) {
                continue
            }
            else if (margin_operator == "*" && Totals[column_agg_i, j] == "") {
                Totals[column_agg_i, j] = 1
            }
      
            if (debug2) {
                print NR" TOTALADV: RA "RA[j]", CA "CA[column_agg_i]" -- "Totals[column_agg_i, j] margin_operator RowAggResult[RA[j], NR]
            }
      
            Totals[column_agg_i, j] = EvalExpr(Totals[column_agg_i, j] margin_operator RowAggResult[RA[j], NR])
        }
    }

    return t_carry
}

function StandardizeCrossAggregationExpr(XA, CrossAggForm, CrossAggExpr, max_rows, max_cols) {
    for (compound_i in XA) {
        call = GetCompoundKeyPart(compound_i, 1)
        agg = XA[compound_i]
        max = call ? max_rows : max_cols
    
        if (CrossAggForm[compound_i] < 2) {
            CrossAggExpr[compound_i] = "+|"agg"|1"
        }
        else if (CrossAggForm[i] < 3) {
            CrossAggExpr[compound_i] = agg"|1.."max
        }
        else if (CrossAggForm[i] < 4) {
            CrossAggExpr[compound_i] = agg
        }
    }
}

function ResolveRowCrossAggs() {
    for (compound_i in XA) {
        call = GetCompoundKeyPart(compound_i, 1)
        if (!call) continue

        agg = XA[compound_i]
        agg_expr = CrossAggExpr[compound_i]
        cross_agg_i = CompoundKey[2]

        split(agg_expr, AggExprParts, /\|/)
        agg_op = AggExprParts[1]
        agg_index = AggExprParts[2]
        split(AggExprParts[3], AnchorFields, /\.\./)

        start = AnchorFields[1]
        end = AnchorFields[2] ? AnchorFields[2] : start

        if (end < start) {
            tmp = end
            end = start
            start = tmp
        }

        agg_row = (NR == agg_index)

        for (crossfield_i = start; crossfield_i <= end; crossfield_i++) {
            if (agg_index == crossfield_i) continue
            split(_[crossfield_i], Row, FS)

            for (f = 1; f <= fixed_nf; f++) {
                if (crossfield_i == start) {
                    CrossKey[f] = Row[f]
                }
                else {
                    tmp = CrossKey[f]
                    delete CrossAggKey[cross_agg_i, CrossAggKeySave[cross_agg_i, tmp]]
                    delete CrossAggKeySave[cross_agg_i, tmp]
                    CrossKey[f] = tmp SUBSEP "::" Row[f]
                }
            }
        }

        for (f = 1; f <= fixed_nf; f++) {
            if (!CrossAggKeySave[cross_agg_i, CrossKey[f]]) {
                CrossAggLength[cross_agg_i]++
                CrossAggKeySave[cross_agg_i, CrossKey[f]] = CrossAggLength[cross_agg_i]
                CrossAggKey[cross_agg_i, CrossAggLength[cross_agg_i]] = CrossKey[f]
            }
        }

        split(_[agg_index], AggRow, FS)
        agg_row_len = length(AggRow)

        for (f = 1; f <= agg_row_len; f++) {
            val = AggRow[f]
            if (val == "") continue
            extract_val = GetOrSetExtractVal(val)

            if (!extract_val && extract_val != 0) {
                continue
            }

            trunc_val = GetOrSetTruncVal(extract_val)
            key_id = CrossAggKeySave[cross_agg_i, CrossKey[f]]

            if (XAggResult[cross_agg_i, key_id]) {
                XAggResult[cross_agg_i, key_id] = EvalExpr(XAggResult[cross_agg_i, key_id] agg_op trunc_val)
            } else {
                XAggResult[cross_agg_i, key_id] = trunc_val
            }

            if (cross_agg_i in MeanAgg) {
                CrossAggCounts[cross_agg_i, key_id]++
            }
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

    if ((large_val && large_dec) \
        || val ~ /^-?[0-9]*\.?[0-9]+(E|e)\+?([4-9]|[1-9][0-9]+)$/) {
        trunc_val = int(val)
    }
    else {
        trunc_val = sprintf("%f", val) # Small floats flow through this logic
    }

    trunc_val += 0
    TruncVal[val] = trunc_val
    return trunc_val
}

function GetOrSetExtractVal(val) {
    if (ExtractVal[val]) return ExtractVal[val]
    if (NoVal[val]) return ""

    cleaned_val = val
    gsub(",", "", cleaned_val)
    
    if (ExtractVal[cleaned_val]) return ExtractVal[cleaned_val]
    if (NoVal[cleaned_val]) return ""
    
    if (match(cleaned_val, /-?[0-9]*\.?[0-9]+((E|e)(\+|-)[0-9]+)?/)) {
        if (extract_vals) {
            extract_val = substr(cleaned_val, RSTART, RSTART+RLENGTH)
        }
        else if (RSTART > 1 || RLENGTH < length(cleaned_val)) {
            NoVal[val] = 1
            return ""
        }
        else {
            extract_val = cleaned_val
        }
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