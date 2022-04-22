#!/usr/bin/awk
# DS:SUBSEP
#
# NAME
#       ds:subsep, subseparator.awk
#
# SYNOPSIS
#       ds:subsep [file] subsep_pattern [nomatch_handler= ]
#
# DESCRIPTION
#       subseparator.awk is a script to split files in a data stream or file using a
#       pattern. It will separate fields, effectively creating new fields for each 
#       subfield identified.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based
#       systems it should be), and call it on a file using aggregation expression.
#       Ensure utils.awk helper file is passed as well:
#
#          $ awk -f support/utils.awk -f subseparator.awk -v subsep_pattern=" " file{,}
#
#       ds:subsep is the caller function for the subseparator.awk script. To run any of 
#       the examples below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#          $ data_in | ds:agg subsep_pattern [nomatch_handler= ]
#
# FIELD_CONSIDERATIONS
#       When running ds:subsep, an attempt is made to infer field separators of up to three 
#       characters. If none found, FS will be set to default value, a single space = " ".
#       To override FS, add as a trailing awkarg. Be sure to escape and quote if needed.
#       AWK's extended regex can be used as FS if needed.
#
#          $ ds:subsep file " " "" -F':'
#
#          $ ds:subsep file ":" "" -v FS=" {2,}"
#
#          $ ds:subsep file "," "" -v FS='\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:subsep file -v FS=""
#
# USAGE
#      By default subsep_pattern and nomatch_handler are a single space.
#
#      Both subsep_pattern and nomatch_handler accept regex. nomatch_handler is only 
#      needed when there are certain lines with fields that may not have a match for 
#      given subsep_pattern.
#
#      Depending on if certain regex tokens are used as fixed strings, this means 
#      escapes may be needed. Eescapes should have two backslashes when passed to
#      ds:subsep (note that they are not necessary for below example):
#
#         $ ds:subsep tests/data/testcrimedata.csv '\\/' "" -v apply_to_fields=1
#
#      There may be instances where neither subsep_pattern nor nomatch_handler find a 
#      match. For these cases, it may be advisable to do a bit of data cleaning first.
#
# AWKARG OPTS
#      If only certain fields should be subseparated, pass them as a comma-separated 
#      list to apply_to_fields, corresponding to the index:
#
#         -v apply_to_fields=3,4,5
#
#
# VERSION
#      1.0
#
# AUTHORS
#      Tom Hall (tomhallmain@gmail.com)
#
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


function DebugPrint(_case) {
    if (_case == 1) {
        print "\nFNR: "FNR" f: "f" shift: "shift" nos: "n_outer_subfields" sf_part: "subfield_partitions" cofs: "conditional_ofs }
    else if (_case == 2) {
        print "\nFNR: "FNR" f: "f" shift: "shift" nos: "n_outer_subfields" sf_part: "subfield_partitions" cofs: "conditional_ofs" osf: "outer_subfield" k: "k
        print "num_subseps < n_outer_subfields - shift: "(num_subseps < n_outer_subfields - shift) }
    else if (_case == 3) {
        print "FNR: "FNR" f: "f" MaxSubseps set to: "num_subseps }
}
