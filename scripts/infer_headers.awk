#!/usr/bin/awk
#
# NAME
#     infer_headers.awk - Infer if headers are present in a file
#
# SYNOPSIS
#     ds:inferh file [awkargs]
#
# DESCRIPTION
#     Analyzes the first row of a file to determine if it contains headers by comparing
#     patterns and characteristics with subsequent rows. Returns exit code 0 if headers
#     are detected, 1 otherwise.
#
# OPTIONS
#     -v trim=true|false     Trim whitespace from fields before analysis (default: true)
#     -v debug=true|false    Enable debug output (default: false)
#     -v max_rows=N          Maximum number of rows to analyze (default: 100)
#
# ALGORITHM
#     The script uses a scoring system based on:
#     1. Pattern matching against common header and data patterns
#     2. Statistical comparison between first row and subsequent rows
#     3. Field length and character type analysis
#     4. Special case detection (IDs, dates, JSON, etc.)
#
#     Positive scores indicate header presence, negative scores indicate data.
#
# EXAMPLES
#     # Basic usage
#     ds:inferh data.csv
#
#     # With custom field separator
#     ds:inferh data.tsv -v FS="\t"
#
#     # With debug output
#     ds:inferh data.csv -v debug=true
#
# AUTHOR
#     Original script enhanced with documentation and features
#
# VERSION
#     1.0.0
#

BEGIN {
    InitConfig()
    InitPatterns()
    headerScore = 0  # Initialize score
}

NR == 1 {
    if (NF < 2) headerScore -= 100  # Penalize single column files

    # Evaluate first row field values
    for (i = 1; i <= NF; i++) {
        field = trim == "true" ? TrimField($i) : $i
        BuildFirstRowScore(field, i)
        
        # Additional header heuristics
        if (IsLikelyHeader(field)) headerScore += 20
    }

    next
}

NR <= max_rows {
    if (NF != FirstRowNF) headerScore -= 50  # Penalize inconsistent field counts
    
    for (i = 1; i <= NF; i++) {
        field = trim == "true" ? TrimField($i) : $i
        BuildControlRowScore(field, i)
    }
}

END {
    if (NR < max_rows) {
        max_rows = NR
        control_rows = max_rows - potential_header_rows
    }

    if (control_rows < 1) {
        if (debug) print "Not enough data rows for analysis"
        exit 1
    }

    CalcSims(FirstRow, ControlRows)
    
    if (debug) {
        print "Final header score: " headerScore
        print "Number of fields: " NF
        print "Control rows analyzed: " control_rows
    }
    
    exit (headerScore > 0) ? 0 : 1
}

function InitConfig() {
    # Patterns that strongly suggest non-header content
    NonHeaderRe = " i d d1 d2 l j "
    # Patterns that suggest header content
    HeaderRe = " a u w id "

    # Configuration
    max_rows = max_rows ? max_rows : 100
    potential_header_rows = 1
    control_rows = max_rows - potential_header_rows
    trim = trim ? trim : "true"
    debug = debug ? debug : "false"
    FirstRowNF = 0  # Store first row field count
}

function InitPatterns() {
    # Regex patterns for field type detection
    Re["i"] = "^[0-9]+$"                     # integer
    Re["d"] = "^[0-9]+\.[0-9]+$"             # decimal
    Re["a"] = "[A-Za-z]+"                    # alpha
    Re["u"] = "^[A-Z]+$"                     # uppercase
    Re["hi"] = "[0-9]+"                      # has integer
    Re["hd"] = "[0-9]+\.[0-9]+"              # has decimal
    Re["ha"] = "[A-Za-z]+"                   # has alpha
    Re["hu"] = "[A-Z]+"                      # has uppercase
    Re["nl"] = "^[^a-z]+$"                   # no lowercase
    Re["w"] = "[A-Za-z ]+"                   # words with spaces
    Re["ns"] = "^[^[:space:]]$"              # no spaces
    Re["id"] = "(^|_| |\-)?[Ii][Dd](\-|_| |$)"                # ID pattern
    Re["d1"] = "^[0-9]{1,2}[\-\.\/][0-9]{1,2}[\-\.\/]([0-9]{2}|[0-9]{4})$"    # date MM/DD/YYYY
    Re["d2"] = "^[0-9]{4}[\-\.\/][0-9]{1,2}[\-\.\/][0-9]{1,2}$"               # date YYYY/MM/DD
    Re["l"] = ":\/\/"                                         # URL/link
    Re["j"] = "^\{[,:\"\'{}\[\]A-z0-9.\-+ \n\r\t]{2,}\}$"     # JSON
    Re["x"] = "<[^>]+>"                                       # HTML/XML
}

function TrimField(field) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
    return field
}

function IsLikelyHeader(field) {
    # Additional heuristics for header detection
    if (field ~ /^[A-Z][a-z]+([A-Z][a-z]+)*$/) return 1  # CamelCase
    if (field ~ /^[a-z]+(_[a-z]+)*$/) return 1           # snake_case
    if (field ~ /^[A-Z_]+$/) return 1                    # CONSTANT_CASE
    if (field ~ /^(sum|avg|count|total|min|max|mean|median)_?/i) return 1  # Statistical terms
    if (field ~ /(date|time|timestamp|created|updated|modified)/i) return 1 # Time-related
    return 0
}

function BuildFirstRowScore(field, position) {
    FirstRow[position, "len"] = length(field)
    FirstRowNF = NF
    
    for (m in Re) {
        re = Re[m]
        if (field ~ re) {
            FirstRow[position, m] = 1
            if (NonHeaderRe ~ " " m " ") headerScore -= 100
            if (HeaderRe ~ " " m " ") headerScore += 30
            
            if (debug == "true") 
                print "First row match:", NR, position, m, field, headerScore
        }
    }
}

function BuildControlRowScore(field, position) {
    # Compare field lengths with first row
    headerScore += sqrt((FirstRow[position, "len"] - length(field))**2) / control_rows
    
    for (m in Re) {
        if (field ~ Re[m]) {
            ControlRows[position, m] += 1
            
            if (debug == "true")
                print "Control row match:", NR, position, m, field, headerScore
        }
    }
}

function CalcSims(first, control) {
    if (debug == "true") print "--- Calculating similarity scores ---"
    
    for (i = 1; i <= NF; i++) {
        for (m in Re) {
            first_score = first[i, m]
            ctrl_score = control[i, m]
            
            # Calculate similarity score
            if (ctrl_score > 0) {
                similarity = sqrt((first_score - ctrl_score / control_rows)**2)
                headerScore += similarity
                
                if (debug == "true")
                    print "Similarity:", i, m, first_score, \
                          ctrl_score/control_rows, similarity, headerScore
            }
        }
    }
    
    if (debug == "true") print "--- End similarity calculation ---"
}
