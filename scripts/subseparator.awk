#!/usr/bin/awk
# DS:SUBSEP
#
# NAME
#       ds:subsep, subseparator.awk - Advanced field subseparation for data processing
#
# SYNOPSIS
#       ds:subsep [file] subsep_pattern [nomatch_handler= ]
#
# DESCRIPTION
#       subseparator.awk splits fields in data streams or files using a pattern,
#       creating new subfields. It's particularly useful for:
#       - Breaking down complex fields into components
#       - Handling nested delimiters
#       - Processing hierarchical data in flat files
#
#       Basic Usage:
#          $ awk -f support/utils.awk -f subseparator.awk -v subsep_pattern=" " file
#
#       Pipeline Usage:
#          $ data_in | ds:subsep subsep_pattern [nomatch_handler= ]
#
# PARAMETERS
#       subsep_pattern    Pattern to use for subseparation (required)
#                        Can be a fixed string or regex pattern
#
#       nomatch_handler   Pattern to use when subsep_pattern doesn't match
#                        Defaults to whitespace ([[:space:]]+)
#
#       apply_to_fields   Comma-separated list of field indices to process
#                        Example: -v apply_to_fields=3,4,5
#
#       escape           Set to 1 to escape all patterns as fixed strings
#                       Default: 0 (preserve regex patterns)
#
#       debug            Set to 1 to enable debug output
#                       Default: 0
#
# ALGORITHM
#   First Pass (Analysis):
#   1. For each specified field (or all fields if not specified):
#      - Split field by subsep_pattern
#      - Track maximum number of subfields found
#      - Calculate necessary field shifts for alignment
#
#   Second Pass (Processing):
#   1. For each field:
#      - If field needs subseparation:
#        * Split by subsep_pattern or nomatch_handler
#        * Output subfields with proper spacing
#      - Otherwise:
#        * Output field as-is
#
# EXAMPLES
#   Basic Field Splitting:
#      $ echo "a/b c/d" | ds:subsep "/"
#      a b c d
#
#   Selective Field Processing:
#      $ echo "a/b,c,d/e" | ds:subsep "/" "" -v apply_to_fields=1,3
#      a b,c,d e
#
#   Complex Pattern with Nomatch Handler:
#      $ echo "a:b c-d" | ds:subsep ":" "-"
#      a b c d
#
# PERFORMANCE NOTES
#   - Makes two passes through data for analysis and processing
#   - Uses arrays to cache subseparator information
#   - Minimizes string operations where possible
#   - Memory usage scales with number of unique field patterns
#
# VERSION
#      2.0
#
# AUTHORS
#      Tom Hall (tomhallmain@gmail.com)
#      Enhanced by the development team

# Initialize global variables and validate input
BEGIN {
    # Validate required parameters
    if (!subsep_pattern) {
        print "ERROR: subsep_pattern must be set"
        exit 1
    }
    
    # Set up pattern handling
    unescaped_pattern = Unescape(subsep_pattern)
    subsep_pattern = escape ? Escape(subsep_pattern) : EscapePreserveRegex(subsep_pattern)
    
    # Configure nomatch handler
    if (length(nomatch_handler) == 0) {
        nomatch_handler = "[[:space:]]+"
        if (debug) print "DEBUG: Using whitespace as nomatch handler"
    } else {
        nomatch_handler = escape ? Escape(nomatch_handler) : EscapePreserveRegex(nomatch_handler)
        if (debug) print "DEBUG: Using custom nomatch handler: " nomatch_handler
    }
    
    # Process field specifications
    if (apply_to_fields) {
        split(apply_to_fields, Fields, ",")
        for (f = 1; f <= length(Fields); f++) {
            field_index = Fields[f]
            if (field_index ~ "^[0-9]+$") {
                RelevantFields[field_index] = 1
            }
        }
        if (length(RelevantFields) < 1) {
            print "ERROR: No valid fields specified in apply_to_fields"
            exit 1
        }
    }
    
    OFS = SetOFS()
}

# First pass: Analyze field patterns and calculate shifts
NR == FNR {
    analyze_fields()
}

# Second pass: Process and output fields
NR > FNR {
    process_fields()
}

# Helper Functions

# Analyzes fields to determine subseparation patterns
function analyze_fields() {
    if (apply_to_fields) {
        for (field_idx in RelevantFields) {
            analyze_single_field(field_idx)
        }
    } else {
        for (field_idx = 1; field_idx <= NF; field_idx++) {
            analyze_single_field(field_idx)
        }
    }
}

# Analyzes a single field for subseparation
function analyze_single_field(field_idx) {
    num_subseps = split($field_idx, SubseparatedLine, subsep_pattern)
    
    if (num_subseps > 1 && num_subseps > MaxSubseps[field_idx]) {
        if (debug) print "DEBUG: Field " field_idx " has " num_subseps " subfields"
        MaxSubseps[field_idx] = num_subseps
        
        # Calculate shifts for empty subfields
        for (j = 1; j <= num_subseps; j++) {
            if (!Trim(SubseparatedLine[j])) {
                SubfieldShifts[field_idx]--
            }
        }
    }
}

# Processes all fields and outputs results
function process_fields() {
    for (f = 1; f <= NF; f++) {
        process_single_field(f)
    }
    print ""
}

# Processes and outputs a single field
function process_single_field(field_idx,    last_field, shift, n_subfields, partitions) {
    last_field = field_idx == NF
    shift = SubfieldShifts[field_idx]
    n_subfields = MaxSubseps[field_idx] + shift
    partitions = n_subfields * 2 - 1 - shift
    
    if (partitions > 0) {
        output_subseparated_field(field_idx, last_field, shift, n_subfields, partitions)
    } else {
        printf "%s%s", Trim($field_idx), (last_field ? "" : OFS)
    }
}

# Outputs a subseparated field with proper formatting
function output_subseparated_field(field_idx, last_field, shift, n_subfields, partitions,    k) {
    num_subseps = split($field_idx, SubseparatedLine, subsep_pattern)
    k = 0
    
    for (j = 1; j <= partitions; j++) {
        conditional_ofs = (last_field && j == partitions) ? "" : OFS
        outer_subfield = j % 2 + shift
        
        if (outer_subfield) k++
        
        if (num_subseps < n_subfields - shift) {
            output_nomatch_handler(field_idx, k, outer_subfield, conditional_ofs)
        } else {
            output_subsep_pattern(k, shift, outer_subfield, conditional_ofs)
        }
    }
}

# Outputs field using nomatch handler
function output_nomatch_handler(field_idx, k, outer_subfield, conditional_ofs) {
    split($field_idx, HandlingLine, nomatch_handler)
    if (outer_subfield) {
        printf "%s%s", Trim(HandlingLine[k]), conditional_ofs
    } else if (retain_pattern) {
        printf "%s", conditional_ofs
    }
}

# Outputs field using subseparator pattern
function output_subsep_pattern(k, shift, outer_subfield, conditional_ofs) {
    if (outer_subfield) {
        printf "%s%s", Trim(SubseparatedLine[k-shift]), conditional_ofs
    } else if (retain_pattern) {
        printf "%s%s", unescaped_pattern, OFS
    }
}

# Debug output function with structured logging
function debug_log(message, details) {
    if (debug) {
        printf "DEBUG [%d:%d]: %s", NR, FNR, message
        if (details) printf " (%s)", details
        print ""
    }
}
