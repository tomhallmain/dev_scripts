BEGIN {
    if (r_aggs && !("off" == r_aggs)) {
        r = 1
        row_aggs_count = split(r_aggs, RowAggs, /,/)
    }
  
    if (c_aggs) {
        c = 1
        column_aggs_count = split(c_aggs, ColumnAggs, /,/)
    }

    for (i in RowAggs) {
        RA[i] = AggregationExpr(RowAggs[i], 1, i)
        RAI[RA[i]] = i
        RowAggExpr[i] = RA[i]
    }
    for (i in ColumnAggs) {
        CA[i] = AggregationExpr(ColumnAggs[i], 0, i)
        CAI[CA[i]] = i
        ColumnAggAmort[i] = CA[i]
    }

    if (length(CrossAggs)) {
        x = 1
        x_base = 1

        for (j = 1; j <= row_aggs_count; j++) {
            if (XAShift[1, j]) {
                row_cross_aggs = 1
                delete RowAggs[j]
                delete RAI[RA[j]]
                delete RA[j]
                delete RowAggExpr[j]
            }
        }
    
        for (j = 1; j <= column_aggs_count; j++) {
            if (XAShift[0, j]) {
                delete ColumnAggs[j]
                delete CAI[CA[j]]
                delete CA[j]
                delete ColumnAggAmort[j]
            }
        }
    
        if (!(length(RowAggs) || length(ColumnAggs))) {
            cross_aggs_only = 1
        }
    }

    if (r || c || x) {
        row_column_aggs_basic = 1
    }

    if (length(AllAgg)) {
        gen = 1
    }

    if (og_off) {
        header = 1
    }
    else {
        print_og = 1
    }

    "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0
    if (gen) GenAllAggregationExpr(max_nr, 0)
  
    OFS = SetOFS()
    header_unset = 1
}

$0 ~ /^[[:space:]]*$/ {
    next
}

header_unset {
    header_unset = 0
    if (!fixed_nf) fixed_nf = NF
    if (gen) GenAllAggregationExpr(fixed_nf, 1)
  
    if (r) {
        for (i in RA) {
            if (KeyAgg[1, i]) SetRowAggKeyFields(i, RA[i])
        }
    }
  
    if (x) {
        StandardizeCrossAggregationExpr(XA, CrossAggForm, CrossAggExpr, max_nr, fixed_nf)
    }
}

{
    # Run cache cleanup
    cleanup_caches()
}

row_column_aggs_basic {
    _[NR] = $0
    RHeader[NR] = $1

    if (NF < fixed_nf) {
        NFPad[NR] = NF - fixed_nf
    }

    for (i in RA) {
        agg = RA[i]
    
        if (!RowAggResult[agg, NR]) {
            r_expr = GenRExpr(agg)
            if (r_expr) {
                val = EvalExpr(r_expr)
                RowAggResult[agg, NR] = val
                
                # Collect values for extended aggregations
                if (agg in AggType) {
                    collect_agg_values(agg, val, NR)
                }
            }
        }
    }

    for (i in CA) {
        agg = CA[i]
        agg_amort = ColumnAggAmort[i]

        if (ConditionalAgg[agg] && GetOrSetIndexNA(agg, NR, 0)) {
            continue
        }
        else if (!KeyAgg[0, i] && !SearchAgg[agg_amort] && !Indexed(agg_amort, NR)) {
            continue
        }

        ColumnAggResult[i] = AdvanceCarryVector(i, fixed_nf, agg_amort, ColumnAggResult[i])
        
        # Collect values for extended aggregations if needed
        if (agg in AggType) {
            collect_agg_values(agg, ColumnAggResult[i], NR)
        }
    }
}

x {
    for (compound_i in XA) {
        agg = XA[compound_i]
        agg_expr = CrossAggExpr[compound_i]
        call = GetCompoundKeyPart(compound_i, 1)
        cross_agg_i = CompoundKey[2]
    
        split(agg_expr, AggExprParts, /\|/)
        agg_op = AggExprParts[1]
        agg_index = AggExprParts[2]
        split(AggExprParts[3], AnchorFields, /\.\./)

        start = AnchorFields[1]
        end = AnchorFields[2] ? AnchorFields[2] : start
        if (end < start) { tmp = end; end = start; start = tmp }

        if (call) {
            agg_row = (NR == agg_index)
            
            if ((NR < start || NR > end) && !agg_row) {
                continue
            }

            if (!row_column_aggs_basic) _[NR] = $0
        }
        else {
            x_key = $start
      
            for (crossfield_i = start + 1; crossfield_i <= end; crossfield_i++) {
                if (agg_index == crossfield_i) continue
                x_key = x_key SUBSEP "::" $crossfield_i
            }

            if (!CrossAggKeySave[cross_agg_i, x_key]) {
                CrossAggLength[cross_agg_i]++
                CrossAggKeySave[cross_agg_i, x_key] = CrossAggLength[cross_agg_i]
                CrossAggKey[cross_agg_i, CrossAggLength[cross_agg_i]] = x_key
            }

            val = $agg_index
            if (val == "") continue
      
            extract_val = GetOrSetExtractVal(val)
            if (!extract_val && extract_val != 0) {
                continue
            }

            trunc_val = GetOrSetTruncVal(extract_val)
            key_id = CrossAggKeySave[cross_agg_i, x_key]

            if (XAggResult[cross_agg_i, key_id]) {
                XAggResult[cross_agg_i, key_id] = EvalExpr(XAggResult[cross_agg_i, key_id] agg_op trunc_val)
            }
            else {
                XAggResult[cross_agg_i, key_id] = trunc_val
            }

            if (cross_agg_i in MeanAgg) {
                CrossAggCounts[cross_agg_i, key_id]++
            }
        }
    }
}

END {
    if (err) exit err
    if (conditional_row_aggs) ResolveConditionalRowAggs()
    if (row_cross_aggs) ResolveRowCrossAggs()

    totals = length(Totals)

    if (!cross_aggs_only) {
        for (i = 1; i <= NR; i++) {
            if (header && column_aggs_count) printf "%s", OFS
      
            if (print_og) {
                split(_[i], Row, FS)
                for (j = 1; j <= fixed_nf; j++) {
                    printf "%s", Row[j]
                    if (j < fixed_nf || row_aggs_count) {
                        printf "%s", OFS
                    }
                }
            }
            else if (i == 1 && header) {
                printf "%s", RHeader[i] OFS
            }
      
            for (j = 1; j <= row_aggs_count; j++) {
                agg = RA[j]
                if (!agg) continue

                print_header = (header || !RowAggResult[agg, i]) && i < 2
                
                if (print_header) {
                    print_str = RowAggs[j]
                }
                else {
                    if (agg in AggType) {
                        # Process extended aggregation
                        aggregation = process_extended_agg(agg, AggValues[agg], AggValuesCount[agg])
                    } else {
                        aggregation = RowAggResult[agg, i]
                        if (MeanAgg[agg]) {
                            aggregation /= RowAggCounts[agg, i]
                        }
                    }
                    print_str = aggregation
                }

                printf "%s", print_str
                if (j < row_aggs_count) {
                    printf "%s", OFS
                }
            }

            print ""
        }

        for (i = 1; i <= column_aggs_count; i++) {
            if (!ColumnAggs[i]) continue
            agg = CA[i]
            skip_first = ColumnAggResult[i] ~ /^0?,/
      
            if (header || skip_first) {
                printf "%s", ColumnAggs[i] OFS
            }
      
            if (!ColumnAggResult[i]) { print ""; continue } 
            split(ColumnAggResult[i], ColumnAggVec, ",")
     
            start = skip_first && !header ? 2 : 1

            for (j = start; j <= fixed_nf; j++) {
                if (ColumnAggVec[j]) {
                    aggregation = EvalExpr(ColumnAggVec[j])
                    if (MeanAgg[agg]) {
                        aggregation /= ColumnAggCounts[agg, j]
                    }
                    printf "%s", aggregation
                }

                if (j < fixed_nf) {
                    printf "%s", OFS
                }
            }
            if (totals) {
                printf "%s", OFS
        
                for (j = 1; j <= row_aggs_count; j++) {
                    aggregation_total = Totals[i, j]
                    
                    if (MeanAgg[agg]) {
                        aggregation_total /= ColumnAggCounts[agg, j]
                    }

                    printf "%s", aggregation_total

                    if (j < row_aggs_count) {
                        printf "%s", OFS
                    }
                }
            }
      
            print ""
        }
    }
  
    if (length(XA)) {
        if (!cross_aggs_only) print ""

        for (compound_i in XA) {
            agg = XA[compound_i]
            agg_expr = CrossAggExpr[compound_i]
      
            split(agg_expr, AggExprParts, /\|/)
            agg_op = cross_agg_i in MeanAgg ? "mean()" : AggExprParts[1]
            agg_index = AggExprParts[2]
            agg_group_scope = AggExprParts[3]

            call = GetCompoundKeyPart(compound_i, 1)
            cross_agg_i = CompoundKey[2]
            rel_len = CrossAggLength[cross_agg_i]

            if (call) {
                print "Cross Aggregation: "agg_op" on row "agg_index" grouped by row "agg_group_scope
            }
            else {
                print "Cross Aggregation: "agg_op" on field "agg_index" grouped by field "agg_group_scope
            }

            if (cross_agg_i in MeanAgg) {
                for (j = 1; j <= rel_len; j++) {
                    base_result = XAggResult[cross_agg_i, j]
                    
                    if (j == 1 && !base_result) {
                        base_result = agg_op
                    }
                    
                    if (CrossAggCounts[cross_agg_i, j] == 0) {
                        print CrossAggKey[cross_agg_i, j], base_result
                    }
                    else {
                        print CrossAggKey[cross_agg_i, j], base_result / CrossAggCounts[cross_agg_i, j]
                    }
                }
            }
            else {
                for (j = 1; j <= rel_len; j++) {
                    base_result = XAggResult[cross_agg_i, j]
                    
                    if (j == 1 && !base_result) {
                        base_result = agg_op
                    }

                    print CrossAggKey[cross_agg_i, j], base_result
                }
            }

            if (length(XA) > 1) print ""
        }
    }

    if (debug) {
        if (length(RA)) print "\nRow Aggregations"
        for (i in RA) {
            print "\n"i" "RowAggs[i]" "RA[i]
            if (KeyAgg[1, i]) print "(KeyAgg)"
            if (SearchAgg[RA[i]]) print "(SearchAgg)"
            if (ConditionalAgg[RA[i]]) print "(ConditionalAgg)"
            if (AllAgg[RA[i]]) print "(AllAgg)"
            if (MeanAgg[RA[i]]) print "(MeanAgg)"
        }
        if (length(CA)) print "\nColumn Aggregations"
        for (i in CA) {
            print "\n"i" "ColumnAggs[i]" "CA[i]
            if (KeyAgg[0, i]) print "(KeyAgg)"
            if (SearchAgg[CA[i]]) print "(SearchAgg)"
            if (ConditionalAgg[CA[i]]) print "(ConditionalAgg)"
            if (AllAgg[CA[i]]) print "(AllAgg)"
            if (MeanAgg[CA[i]]) print "(MeanAgg)"
        }
    }
}