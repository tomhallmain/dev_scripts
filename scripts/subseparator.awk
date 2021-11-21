#!/usr/bin/awk
#
# Separates a text file by an implied pattern given in addition to existing field 
# separators, effectively creating new fields for each subfield identified.
#
# Running:
# > awk -f subseparator.awk -v subsep_pattern=" " file file
## TODO: Fix output of subseparated files with quoted fields
## TODO: Manpage

BEGIN {
    if (!subsep_pattern) {
        print "Variable subsep pattern must be set"
        exit 1
    }
  
    if (length(nomatch_handler) == 0) {
        nomatch_handler = "[[:space:]]+"
        if (debug) print "splitting lines on "FS" then on "subsep_pattern" with whitespace tiebreaker"
    }
    else {
        if (debug) print "splitting lines on "FS" then on "subsep_pattern" with tiebreaker "nomatch_handler 
        if (escape) {
            nomatch_handler = Escape(nomatch_handler)
        }
        else {
            nomatch_handler = EscapePreserveRegex(nomatch_handler)
        }
    }
  
    unescaped_pattern = Unescape(subsep_pattern)
    if (escape) {
        subsep_pattern = Escape(subsep_pattern)
    }
    else {
        subsep_pattern = EscapePreserveRegex(subsep_pattern)
    }
  
    if (apply_to_fields) {
        split(apply_to_fields, Fields, ",")
        len_af = length(Fields) 
    
        for (f = 1; f <= len_af; f++) {
            af = Fields[f]
            if (!(af ~ "^[0-9]+$")) continue
            RelevantFields[af] = 1
        }

        if (length(RelevantFields) < 1) exit 1
    }

    OFS = SetOFS()
}

NR == FNR {
    if (apply_to_fields) {
        for (f in RelevantFields) {
            num_subseps = split($f, SubseparatedLine, subsep_pattern)
      
            if (num_subseps > 1 && num_subseps > MaxSubseps[f]) {
                if (debug) DebugPrint(3)
                MaxSubseps[f] = num_subseps

                for (j = 1; j <= num_subseps; j++)
                    if (!Trim(SubseparatedLine[j]))
                        SubfieldShifts[f]--
            }
        }
    }
    else {
        for (f = 1; f <= NF; f++) {
            num_subseps = split($f, SubseparatedLine, subsep_pattern)
      
            if (num_subseps > 1 && num_subseps > MaxSubseps[f]) {
                if (debug) DebugPrint(3)
                MaxSubseps[f] = num_subseps
        
                for (j = 1; j <= num_subseps; j++)
                    if (!Trim(SubseparatedLine[j]))
                        SubfieldShifts[f]--
            }
        }
    }
}

NR > FNR {
    for (f = 1; f <= NF; f++) {
        last_field = f == NF
        shift = SubfieldShifts[f]
        n_outer_subfields = MaxSubseps[f] + shift
        subfield_partitions = n_outer_subfields * 2 - 1 - shift
    
        if (subfield_partitions > 0) {
            if (debug) DebugPrint(1)
      
            num_subseps = split($f, SubseparatedLine, subsep_pattern)
            k = 0
      
            for (j = 1; j <= subfield_partitions; j++) {
                conditional_ofs = (last_field && j == subfield_partitions) ? "" : OFS
                outer_subfield = j % 2 + shift
        
                if (outer_subfield) k++
        
                if (debug && (retain_pattern || outer_subfield)) DebugPrint(2)
        
                if (num_subseps < n_outer_subfields - shift) {
                    split($f, HandlingLine, nomatch_handler)
          
                    if (outer_subfield)
                        printf Trim(HandlingLine[k]) conditional_ofs
                    else if (retain_pattern)
                        printf conditional_ofs
                }
                else {
                    if (outer_subfield)
                        printf Trim(SubseparatedLine[k-shift]) conditional_ofs
                    else if (retain_pattern)
                        printf unescaped_pattern OFS
                }
            }
        }
        else {
            conditional_ofs = last_field ? "" : OFS
            printf Trim($f) conditional_ofs
        }
    }

    print ""
}


function DebugPrint(case) {
    if (case == 1) {
        print "\nFNR: "FNR" f: "f" shift: "shift" nos: "n_outer_subfields" sf_part: "subfield_partitions" cofs: "conditional_ofs }
    else if (case == 2) {
        print "\nFNR: "FNR" f: "f" shift: "shift" nos: "n_outer_subfields" sf_part: "subfield_partitions" cofs: "conditional_ofs" osf: "outer_subfield" k: "k
        print "num_subseps < n_outer_subfields - shift: "(num_subseps < n_outer_subfields - shift) }
    else if (case == 3) {
        print "FNR: "FNR" f: "f" MaxSubseps set to: "num_subseps }
}
