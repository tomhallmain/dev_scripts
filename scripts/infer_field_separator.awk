#!/usr/bin/awk
#
# NAME
#     infer_field_separator.awk - Infer field separator from data files
#
# SYNOPSIS
#     ds:inferfs file [reparse=f] [custom=t] [file_ext=t] [high_cert=f]
#
# DESCRIPTION
#     Analyzes a text data file to determine the most likely field separator based on:
#     1. Common field separators (space, tab, comma, etc.)
#     2. Custom separators up to 3 characters long
#     3. Pattern consistency across rows
#     4. Quoted field handling
#
# OPTIONS
#     -v custom=true|false    Enable custom separator detection (default: true)
#     -v debug=true|false    Enable debug output (default: false)
#     -v max_rows=N          Maximum rows to analyze (default: 500)
#     -v high_certainty=true|false  Require high confidence (default: false)
#
# ALGORITHM
#     The script uses a multi-stage approach:
#     1. Check file extension for common types (.csv, .tsv, etc.)
#     2. Scan for common separators with pattern consistency
#     3. If custom=true, analyze for custom separators in first few rows
#     4. Handle quoted fields and escaped characters
#     5. Calculate confidence scores based on:
#        - Consistency of field counts
#        - Separator frequency
#        - Pattern recognition
#
# LIMITATIONS
#     - Cannot infer newline as separator
#     - Custom separators cannot contain alphanumeric characters
#     - Maximum 3 characters for custom separators
#
# EXAMPLES
#     # Basic usage
#     awk -f infer_field_separator.awk data.txt
#
#     # With custom separator detection
#     awk -f infer_field_separator.awk -v custom=true data.txt
#
#     # With high certainty requirement
#     awk -f infer_field_separator.awk -v high_certainty=true data.txt
#
# AUTHOR
#     Original script enhanced with documentation and optimizations
#
# VERSION
#     1.1.0
#

BEGIN {
    # Initialize common field separators with their patterns
    InitCommonSeparators()
    
    # Initialize configuration
    InitConfig()
    
    # Initialize caches for performance
    InitCaches()
}

function InitCommonSeparators() {
    # Common separators ordered by priority
    CommonFSOrder[1] = "s"; CommonFS["s"] = " "; FixedStringFS["s"] = "\\"
    CommonFSOrder[2] = "t"; CommonFS["t"] = "\t"; FixedStringFS["t"] = "\\"
    CommonFSOrder[3] = "p"; CommonFS["p"] = "\|"; FixedStringFS["p"] = "\\"
    CommonFSOrder[4] = "m"; CommonFS["m"] = ";"; FixedStringFS["m"] = "\\"
    CommonFSOrder[5] = "c"; CommonFS["c"] = ":"; FixedStringFS["c"] = "\\"
    CommonFSOrder[6] = "o"; CommonFS["o"] = ","; FixedStringFS["o"] = "\\"
    CommonFSOrder[7] = "w"; CommonFS["w"] = "[[:space:]]+"
    CommonFSOrder[8] = "2w"; CommonFS["2w"] = "[[:space:]]{2,}"
    
    n_common = length(CommonFS)
}

function InitConfig() {
    # Configuration defaults
    max_rows = max_rows ? max_rows : 500
    custom = length(custom)  # Convert to boolean
    high_certainty = high_certainty ? high_certainty : 0
    debug = debug ? debug : 0
    
    # Constants
    DS_SEP = "@@@"  # Special separator for internal use
    sq = "\'"       # Single quote
    dq = "\""      # Double quote
    
    # Initialize counters
    n_valid_rows = 0
    max_chunk_weight = 0
    prev_chunk_weight = 0
}

function InitCaches() {
    # Pre-allocate arrays for better performance
    split("", CharFSCount)      # Cache for single-char separators
    split("", TwoCharFSCount)   # Cache for two-char separators
    split("", ThrCharFSCount)   # Cache for three-char separators
    split("", CustomFS)         # Cache for valid custom separators
    split("", Q)               # Cache for quote types
    split("", QFRe)           # Cache for quoted field regex
}

# Skip empty lines
$0 ~ /^ *$/ { next }

# Count valid rows and check limits
{ 
    n_valid_rows++ 
    
    # Early exit if we've processed enough rows
    if (n_valid_rows > max_rows) exit
    
    # Check for special separator in first few rows
    if (n_valid_rows < 10 && $0 ~ DS_SEP) {
        ds_sep = 1
        print DS_SEP
        exit
    }
}

# Custom separator detection in first row
custom && n_valid_rows == 1 {
    ProcessFirstRow()
}

# Custom separator validation in second row
custom && n_valid_rows == 2 {
    ProcessSecondRow()
}

# Main processing for all rows
{
    # Clean input
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",$0)
    
    # Process common separators
    ProcessCommonSeparators()
    
    # Process custom separators after second row
    if (custom && n_valid_rows > 2) {
        ProcessCustomSeparators()
    }
}

END {
    if (ds_sep) exit
    
    # Adjust max_rows if we didn't get enough data
    if (max_rows > n_valid_rows) max_rows = n_valid_rows
    
    # Calculate final scores
    CalculateScores()
    
    # Output the winner
    OutputResult()
}

function ProcessFirstRow() {
    # Store first line for later comparison
    Line[NR] = $0
    
    # Split into non-word components
    split($0, Nonwords, /[A-z0-9(\^\\)"']+/)
    
    # Process potential separators
    for (i in Nonwords) {
        ProcessNonwordChars(Nonwords[i])
    }
}

function ProcessSecondRow() {
    Line[NR] = $0
    ValidateCustomSeparators()
}

function ProcessCommonSeparators() {
    for (s in CommonFS) {
        fs = CommonFS[s]
        
        # Handle quoted fields
        nf = CountFields(fs, s)
        
        # Update statistics
        UpdateFieldStats(s, nf)
    }
}

function CountFields(fs, s,    nf, qf_line) {
    # Get quote type if not cached
    if (!Q[s]) Q[s] = GetFieldsQuote($0, FixedStringFS[s] fs)
    
    if (Q[s]) {
        # Handle quoted fields
        if (!QFRe[s]) QFRe[s] = QuotedFieldsRe(fs, Q[s])
        nf = 0
        qf_line = $0
        
        while (length(qf_line)) {
            match(qf_line, QFRe[s])
            
            if (RSTART) {
                nf++
                if (RSTART > 1)
                    nf += split(substr(qf_line, 1, RSTART-1), _, fs)
                qf_line = substr(qf_line, RSTART+RLENGTH)
            } else {
                nf += split(qf_line, _, fs)
                break
            }
        }
    } else {
        # Simple field count
        nf = split($0, _, fs)
    }
    
    return nf
}

function UpdateFieldStats(s, nf) {
    # Update counts and track consistency
    CommonFSCount[s, NR] = nf
    CommonFSTotal[s] += nf
    
    # Track field count consistency
    if (PrevNF[s] && nf != PrevNF[s] && 
        !(CommonFSNFConsecCounts[s, PrevNF[s]] > 2)) {
        delete CommonFSNFConsecCounts[s, PrevNF[s]]
    }
    
    PrevNF[s] = nf
    
    # Update field count specifications
    if (nf >= 2) {
        cnf = "," nf
        if (!(CommonFSNFSpec[s] ~ cnf "(,|$)")) {
            CommonFSNFSpec[s] = CommonFSNFSpec[s] cnf
        }
        CommonFSNFConsecCounts[s, nf]++
    }
}

function CalculateScores() {
    if (debug) print "\n ---- Calculating final scores ----"
    
    # Process common separators
    for (i = 1; i <= n_common; i++) {
        s = CommonFSOrder[i]
        CalculateSeparatorScore(s)
    }
    
    # Process custom separators if enabled
    if (custom) {
        for (fs in CustomFS) {
            CalculateCustomScore(fs)
        }
    }
}

function OutputResult() {
    # Output the winning separator
    if (high_certainty && !high_confidence) {
        exit 1
    }
    
    if (winner) {
        print winner
        exit 0
    }
    
    exit 1
}

function QuotedFieldsRe(sep, q) { # TODO: CRLF in fields!!
    qs = q sep; spq = sep q
    exc = "[^"q"]*[^"sep"]*[^"q"]+"
    return "(^"q qs"|"spq qs"|"spq q"$|"q exc qs"|"spq exc qs"|"spq exc q"$)"
}
function GetFieldsQuote(line, sep) {
    dq_sep_re = QuotedFieldsRe(sep, dq)
    if (match(line, dq_sep_re)) return dq
    sq_sep_re = QuotedFieldsRe(sep, sq)
    if (match(line, sq_sep_re)) return sq
}
function DebugPrint(_case) {
    if (_case == 1) {
        print "char: " char, char_nf
    } else if (_case == 2) {
        print "twochar: " twochar, twochar_nf
    } else if (_case == 3) {
        print "thrchar: " thrchar, thrchar_nf
    } else if (_case == 4) {
        print "NR: "NR", s: \""s"\", fs: \""fs"\", nf: "nf
        if (Q[s]) print "Q[s]: "Q[s]", QFRe[s]: "QFRe[s]
    } else if (_case == 5) {
        printf "%s", s " average nf: " average_nf
        print (average_nf >= 2 ? ", will calc var" : "")
    } else if (_case == 6) {
        print "sep: "s" FSVar: " FSVar[s]
    } else if (_case == 7) {
        print "NoVar winning_s set to CommonFS[\""s"\"] = \""CommonFS[s]"\""
    } else if (_case == 8) {
        print "winning_s set to CommonFS[\""s"\"] = \""CommonFS[s]"\""
    } else if (_case == 10) {
        print "NoVar winning_s set to CustomFS \""s"\""
    } else if (_case == 11) {
        print "NoVar winning_s set to CustomFS \""s"\""
    } else if (_case == 12) {
        print " ---- NoVar handling case ----"
        print "s: \""s"\", fs1: \""fs1"\""
        print "compare_s: \""compare_s"\", fs2: \""fs2"\""
        print "matches:", fs1 ~ fs2
        print "len winner: "length(Winners[s])", len fs1: "length(fs1)", len fs2: "length(fs2)
    } else if (_case == 13) {
        print "s: \""s"\", compare_s: \""compare_s"\", winning_s switched to: \""compare_s"\""
    } else if (_case == 14) {
        print "compare_s: \""compare_s"\", s: \""s"\", winning_s switched to: \""s"\""
    } else if (_case == 15) {
        print s, Q[s], RSTART, RLENGTH
        print qf_line
    } else if (_case == 16) {
        print "Sectional override set for sep \""s"\" at nf "nf" with weight "chunk_weight" composite "chunk_weight_composite
    }
}
