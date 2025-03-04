## SETUP

BEGIN {
    BuildRe(Re)
    BuildTokens(Tk)
    BuildTokenMap(TkMap)
    assume_constant_fields = 0
    base_r = 1
    base_c = 1
    min_guar_print_nf = 1000
    min_guar_print_nr = 100000000
    chunk_size = 10000  # Process data in chunks to manage memory
    current_chunk = 1
    comma_escape_string = "#_ECSOCMAMPA_#"
    if (!cased) ignore_case_global = 1
    if (ARGV[1]) {
        # Get file size and estimate memory requirements
        "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0
        if (max_nr > chunk_size) {
            chunked_processing = 1
            chunks_total = int((max_nr + chunk_size - 1) / chunk_size)
        }
    }

    # Pre-allocate arrays for better memory efficiency
    split("", _)          # Data storage
    split("", Row)        # Row processing
    split("", PrintRows)  # Output processing
    split("", PrintFields)# Field processing

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

    if (r_len == 1 && c_len == 1 && !pass_r && !pass_c && !range && !reo) {
        indx = 1
    }
    else if (!pass && !range && !reo) {
        base = 1
    }
    else if (range && !reo) {
        base_range = 1
    }
    else if (reo && !mat && !re && !anc && !rev && !oth && !c_nidx && !c_nidx_rng) {
        base_reo = 1
    }

    if (OFS ~ "\\\\") OFS = Unescape(OFS)
    if (OFS ~ "\\[:space:\\]\{") OFS = "  "
    else if (OFS ~ "\\[:space:\\]\+") OFS = " "
  
    reo_r_len = length(ReoR)
    reo_c_len = length(ReoC)
  
    if (debug) { DebugPrint(0); DebugPrint(7) }
  
    if (idx && !pass && (!reo || base_reo && pass_r)) {
        if (base_range || base_reo) {
            FieldsIndexPrint(ReoC, reo_c_len)
        }
        else {
            FieldsIndexPrint(COrder, c_len)
        }
    }
}



## SIMPLE PROCESSING/DATA GATHERING

# Add chunk management
function ProcessChunk() {
    if (chunked_processing && NR % chunk_size == 0) {
        # Process current chunk
        ProcessStoredData()
        
        # Clear chunk data
        for (i in _) delete _[i]
        for (i in Row) delete Row[i]
        for (i in PrintRows) delete PrintRows[i]
        for (i in PrintFields) delete PrintFields[i]
        
        current_chunk++
    }
}

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
    else if (base_reo && NR in R) {
        StoreRow(_)
        if (NF > max_nf) max_nf = NF
    }
    else {
        StoreRow(_)
        if (!base_c) StoreFieldRefs()
        if (!base_r) StoreRowRefs()
    }

    if (NF > max_nf) max_nf = NF
    
    ProcessChunk()
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

    if (c_nidx) {
        SetNegativeIndexFieldOrder(0, CNidx, max_nf)
    }
    if (c_nidx_rng) {
        SetNegativeIndexFieldOrder(1, CNidxRanges, max_nf)
    }
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

    if (!pass_c && !q && !rev_c && !oth_c && !c_anc_found && max_nf < min_guar_print_nf) {
        MatchCheck(ExprFO, SearchFO, AnchorFO, CNidx, CNidxRanges)
    }
    if (!pass_r && !q && !rev_r && !oth_r && !r_anc_found && NR < min_guar_print_nr) {
        MatchCheck(ExprRO, SearchRO, AnchorRO)
    }

    if (idx) {
        if (reo_c_len) {
            FieldsIndexPrint(ReoC, reo_c_len)
        }
        else {
            FieldsIndexPrint(Empty, max_nf)
        }
    }

    if (pass_r) {
        for (rr = 1; rr <= NR; rr++) {
            if (idx) printf "%s", rr OFS
            for (rc = 1; rc <= reo_c_len; rc++) {
                c_key = ReoC[rc]
                if (!c_key) continue
                
                row = _[rr]
                split(row, Row, FS)
                
                if (c_key ~ Re["int"]) {
                    PrintField(Row[c_key], rc, reo_c_len)
                }
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
        
        if (pass_c && base_reo) {
            FieldsPrint(_[r_key])
        }
        else {
            if (r_key ~ Re["int"]) {
                if (idx) printf "%s", r_key OFS
                
                if (pass_c) {
                    FieldsPrint(_[r_key])
                }
                else {
                    for (rc = 1; rc <= reo_c_len; rc++) {
                        c_key = ReoC[rc]
                        if (!c_key) continue
            
                        row = _[r_key]
                        split(row, Row, FS)
            
                        if (c_key ~ Re["int"]) {
                            PrintField(Row[c_key], rc, reo_c_len)
                        }
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