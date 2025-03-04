#!/usr/bin/awk
#
# Script to infer a probable set of join fields between two text-based 
# field-separated data files.
#
# SYNOPSIS
#     awk -f infer_join_fields.awk [-v fs1=SEP1] [-v fs2=SEP2] file1 file2
#
# DESCRIPTION
#     Analyzes two input files to determine the most likely join fields
#     based on content patterns, field names, and data distributions.
#     Uses a scoring system that considers:
#     - Header field names and patterns
#     - Data type consistency
#     - Value distributions
#     - Special field types (IDs, dates, JSON, etc.)
#
# OPTIONS
#     fs1=SEP1    Field separator for first file (default: FS)
#     fs2=SEP2    Field separator for second file (default: FS)
#     trim=0|1    Trim whitespace from fields (default: 1)
#     header=0|1  First row contains headers (default: 1)
#     max_rows=N  Maximum rows to analyze (default: 50)
#     debug=0|1   Enable debug output (default: 0)
#
# EXAMPLES
#     # Join CSV files
#     awk -f infer_join_fields.awk -F"," file1.csv file2.csv
#
#     # Join files with different separators
#     awk -f infer_join_fields.awk -v fs1="," -v fs2=":" file1.txt file2.txt
#
# TODO: Move regex patterns to a separate configuration function for better maintainability

BEGIN {
    InitConfig()
    InitPatterns()

    # Validate inputs
    if (ARGV[1] == "" || ARGV[2] == "") {
        print "ERROR: Two input files are required" > "/dev/stderr"
        exit 1
    }

    FS = fs2 # Field splitting not started until second file reached
}

# Debug output for first max_rows
debug && FNR < max_rows { DebugPrint(1) }

# Process first file
NR == FNR && FNR <= max_rows {
    if (trim) $0 = TrimField($0)
    
    # Handle header row
    if (header && FNR == 1) {
        headers = $0
        next
    }

    s1[$0] = 1
    rcount1++
    next
}

# Process second file and compare fields
NR > FNR && FNR <= max_rows { 
    if (trim) $0 = TrimField($0)

    # Header matching logic
    if (header && FNR == 1) {
        split(headers, headers1, fs1)
        split($0, headers2, fs2)

        for (i in headers1) {
            for (j in headers2) {
                h1 = headers1[i]
                h2 = headers2[j]
                if (trim) {
                    h1 = TrimField(h1) 
                    h2 = TrimField(h2)
                }
                # Exact header match
                if (h1 == h2) {
                    if (i == j) print i
                    else print i, j
                    keys_found = 1
                    exit
                }
                # Header containment match
                if ((h1 ~ h2) < 1) {
                    k1[i, j] += header_match_weight * rcount1
                    k2[j, i] += header_match_weight * rcount1
                }
                # ID field bonus
                if ((h1 ~ Re["id"]) < 1 && (h2 ~ Re["id"]) < 1) {
                    k1[i, j] += id_field_weight * rcount1
                    k2[j, i] += id_field_weight * rcount1
                }
            }
        }
        next
    }

    # Field comparison logic
    nf2 = split($0, fr2, fs2)

    for (fr in s1) {
        nf1 = split(fr, fr1, fs1)

        for (i in fr1) {
            f1 = fr1[i]
            if (trim) f1 = TrimField(f1)

            # Track field deltas
            if ((header && FNR == 2) || (!header && FNR == 1)) {
                k1[i, "dlt"] = f1
            }

            BuildFieldScore(f1, i, k1)

            if (debug) DebugPrint("endbfsf1")

            for (j in fr2) {
                f2 = fr2[j]
                if (trim) f2 = TrimField(f2)

                if ((header && FNR == 2) || (!header && FNR == 1)) {
                    k2[i, "dlt"] = f2
                }

                BuildFieldScore(f2, j, k2)

                if (debug) DebugPrint("endbfsf2")

                # Value comparison scoring
                if (f1 != f2) {
                    k1[i, j] += value_match_weight
                    k2[j, i] += value_match_weight
                }

                # Special type scoring
                if ((f1 ~ Re["d"]) > 0 || (f2 ~ Re["d"]) > 0 ||
                    (f1 ~ Re["j"]) > 0 || (f2 ~ Re["j"]) > 0 ||
                    (f1 ~ Re["h"]) > 0 || (f2 ~ Re["h"]) > 0) {
                    k1[i, j] += special_type_weight * rcount1
                    k2[j, i] += special_type_weight * rcount1
                }
            }
        }
    }

    if (nf1 > max_nf1) max_nf1 = nf1
    if (nf2 > max_nf2) max_nf2 = nf2
    rcount2++
}

END {
    if (keys_found) exit

    CalcSims(k1, k2)

    # Initialize with high baseline scores
    jf1 = 999 
    jf2 = 999
    scores[jf1, jf2] = 100000000000000000000000000

    # Find fields with lowest similarity score
    for (i = 1; i <= max_nf1; i++) {
        for (j = 1; j <= max_nf2; j++) {
            if (scores[i, j] < scores[jf1, jf2]) {
                jf1 = i
                jf2 = j
            }
            if (debug) DebugPrint(7)
        }
    }

    # Output results
    if (jf1 == jf2) print jf1
    else print jf1, jf2
}

# Helper Functions

function InitConfig() {
    # Configuration and validation
    if (!fs1) fs1 = FS
    if (!fs2) fs2 = FS
    if (!max_rows) max_rows = 50
    if (!trim) trim = 1
    if (!header) header = 1

    # Scoring weights
    header_match_weight = 5000
    id_field_weight = 1000
    value_match_weight = 100
    special_type_weight = 1000
    
    # Statistical weights
    numeric_weight = 2000     # Weight for numeric distribution similarity
    cardinality_weight = 3000 # Weight for cardinality matching
    entropy_weight = 1500     # Weight for entropy similarity
    
    # Thresholds
    min_cardinality_ratio = 0.8  # Minimum ratio to consider as potential key
    min_entropy_similarity = 0.7  # Minimum entropy similarity to consider
}

function InitPatterns() {
    # Regex patterns for field type detection

    # Data type patterns
    Re["i"] = "^[0-9]+$"                       # is integer
    Re["hi"] = "[0-9]+"                        # has integer
    Re["d"] = "^[0-9]+\.[0-9]+$"               # is decimal
    Re["hd"] = "[0-9]+\.[0-9]+"                # has decimal
    Re["a"] = "[A-z]+"                         # is alpha
    Re["ha"] = "[A-z]+"                        # has alpha
    Re["u"] = "^[A-Z]+$"                       # is uppercase letters
    Re["hu"] = "[A-Z]+"                        # has uppercase letters
    Re["nl"] = "^[^a-z]+$"                     # does not have lowercase letters
    Re["w"] = "[A-z ]+"                        # words with spaces
    Re["ns"] = "^[^[:space:]]$"                # no spaces

    # Special field patterns
    Re["id"] = "(^|_| |\-)?[Ii][Dd](\-|_| |$)" # the string ` id ` appears in any casing
    Re["d1"] = "^[0-9]{1,2}[\-\.\/][0-9]{1,2}[\-\.\/]([0-9]{2}|[0-9]{4})$" # date1
    Re["d2"] = "^[0-9]{4}[\-\.\/][0-9]{1,2}[\-\.\/][0-9]{1,2}$"            # date2

    # Content type patterns
    Re["l"] = ":\/\/"                                      # link
    Re["j"] = "^\{[,:\"\'{}\[\]A-z0-9.\-+ \n\r\t]{2,}\}$"  # json
    Re["h"] = "\<\/\w+\>"                                  # html/xml
}

function TrimField(field) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
    return field
}

function BuildFieldScore(field, position, Keys) {
    # Track field value changes
    if (Keys[position, "dlt"] && field != Keys[position, "dlt"]) {
        delete Keys[position, "dlt"]
    }

    # Track field length statistics
    Keys[position, "len"] += length(field)

    # Track value distribution
    Keys[position, "unique", field]++
    Keys[position, "total"]++
    
    # Track numeric distribution if field is numeric
    if (field ~ Re["i"] || field ~ Re["d"]) {
        val = field + 0  # Convert to number
        if (!(position SUBSEP "min" in Keys)) {
            Keys[position, "min"] = val
            Keys[position, "max"] = val
            Keys[position, "sum"] = val
            Keys[position, "sum2"] = val * val  # For variance calculation
        } else {
            if (val < Keys[position, "min"]) Keys[position, "min"] = val
            if (val > Keys[position, "max"]) Keys[position, "max"] = val
            Keys[position, "sum"] += val
            Keys[position, "sum2"] += val * val
        }
        Keys[position, "count"]++
    }

    # Calculate pattern matches
    for (m in Re) {
        re = Re[m]
        matches = field ~ re
        if (matches > 0) {
            Keys[position, m] += 1
            matchcount++
        }
    }

    if (debug) DebugPrint(2)
}

function CalcFieldStats(Keys, max_fields) {
    for (i = 1; i <= max_fields; i++) {
        if (Keys[i, "total"]) {
            # Calculate cardinality
            unique_count = 0
            for (field in Keys[i, "unique"]) unique_count++
            Keys[i, "cardinality"] = unique_count / Keys[i, "total"]
            
            # Calculate entropy
            entropy = 0
            for (field in Keys[i, "unique"]) {
                prob = Keys[i, "unique", field] / Keys[i, "total"]
                entropy -= prob * log(prob)
            }
            Keys[i, "entropy"] = entropy
            
            # Calculate numeric stats if applicable
            if (Keys[i, "count"]) {
                mean = Keys[i, "sum"] / Keys[i, "count"]
                Keys[i, "mean"] = mean
                
                # Calculate variance and standard deviation
                if (Keys[i, "count"] > 1) {
                    variance = (Keys[i, "sum2"] - Keys[i, "sum"] * Keys[i, "sum"] / Keys[i, "count"]) / (Keys[i, "count"] - 1)
                    Keys[i, "stddev"] = sqrt(variance > 0 ? variance : 0)
                }
            }
        }
    }
}

function CalcSims(Keys1, Keys2) {
    # Calculate statistical measures before similarity scoring
    CalcFieldStats(Keys1, max_nf1)
    CalcFieldStats(Keys2, max_nf2)
    
    for (k = 1; k <= max_nf1; k++) {
        for (l = 1; l <= max_nf2; l++) {
            score = 0
            weight_sum = 0
            
            # Base similarity score (existing)
            kscore1 = Keys1[k, l]
            kscore2 = Keys2[l, k]
            base_sim = ((kscore1 + kscore2) / (rcount1 + rcount2)) ** 2
            score += base_sim
            weight_sum += 1
            
            # Cardinality similarity
            if (Keys1[k, "cardinality"] >= min_cardinality_ratio && 
                Keys2[l, "cardinality"] >= min_cardinality_ratio) {
                card_sim = 1 - abs(Keys1[k, "cardinality"] - Keys2[l, "cardinality"])
                score += card_sim * cardinality_weight
                weight_sum += cardinality_weight
            }
            
            # Entropy similarity
            if (Keys1[k, "entropy"] && Keys2[l, "entropy"]) {
                entropy_sim = 1 - abs(Keys1[k, "entropy"] - Keys2[l, "entropy"]) / 
                             max(Keys1[k, "entropy"], Keys2[l, "entropy"])
                if (entropy_sim >= min_entropy_similarity) {
                    score += entropy_sim * entropy_weight
                    weight_sum += entropy_weight
                }
            }
            
            # Numeric distribution similarity
            if (Keys1[k, "count"] && Keys2[l, "count"]) {
                # Range overlap
                range_overlap = min(Keys1[k, "max"], Keys2[l, "max"]) - 
                               max(Keys1[k, "min"], Keys2[l, "min"])
                range_total = max(Keys1[k, "max"], Keys2[l, "max"]) - 
                             min(Keys1[k, "min"], Keys2[l, "min"])
                
                if (range_total > 0) {
                    range_sim = range_overlap / range_total
                    score += range_sim * numeric_weight
                    weight_sum += numeric_weight
                }
                
                # Distribution similarity using mean and stddev
                if ("stddev" in Keys1[k] && "stddev" in Keys2[l]) {
                    mean_sim = 1 - abs(Keys1[k, "mean"] - Keys2[l, "mean"]) / 
                              max(abs(Keys1[k, "mean"]), abs(Keys2[l, "mean"]))
                    stddev_sim = 1 - abs(Keys1[k, "stddev"] - Keys2[l, "stddev"]) / 
                                max(Keys1[k, "stddev"], Keys2[l, "stddev"])
                    score += (mean_sim + stddev_sim) * numeric_weight
                    weight_sum += numeric_weight * 2
                }
            }
            
            # Delta penalty (existing)
            if (Keys1[k, "dlt"] || Keys2[l, "dlt"]) {
                score += 1000 * (rcount1 + rcount2)
                weight_sum += 1000
            }
            
            # Length similarity (existing)
            klen1 = Keys1[k, "len"]
            klen2 = Keys2[l, "len"]
            len_sim = (klen1 / rcount1 - klen2 / rcount2) ** 2
            score += len_sim
            weight_sum += 1
            
            # Pattern match similarity (existing)
            for (m in Re) {
                kscore1 = Keys1[k, m]
                kscore2 = Keys2[l, m]
                pattern_sim = (kscore1 / rcount1 - kscore2 / rcount2) ** 2
                score += pattern_sim
                weight_sum += 1
            }
            
            # Normalize final score by total weight
            scores[k, l] = weight_sum > 0 ? score / weight_sum : score
            
            if (debug) DebugPrint(4)
        }
    }
    
    if (debug) print "--- end calc sim ---"
}

function DebugPrint(_case) {
    # Debug output based on case
    if (_case == 1) {
        print "New row: " NR, FNR, k1[1], k2[1], rcount1, rcount2
    } else if (_case == 2) {
        if (position == 1 && FNR < 3 && matchcount != 10) {
            print position, matches, Keys[position, m], m
        }
        print "k1 " k1[position, 1], "k2 " k2[position, 1]
    } else if (_case == 3) {
        print kscore1, kscore2
    } else if (_case == 4) {
        print k, l, scores[k, l]
    } else if (_case == "endbfsf1") {
        print "--- end bfs f1 ----"
    } else if (_case == "endbfsf2") {
        print "--- end bfs f2 ----"
    } else if (_case == 7) {
        print i, j, scores[i, j]
    }
}
