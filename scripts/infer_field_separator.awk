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
#     2. Custom separators up to max_custom_sep_len characters long
#     3. Pattern consistency across rows
#     4. Quoted field handling
#
# OPTIONS
#     -v custom=true|false    Enable custom separator detection (default: true)
#     -v debug=true|false    Enable debug output (default: false)
#     -v max_rows=N          Maximum rows to analyze (default: 500)
#     -v max_custom_sep_len=N  Max custom separator length (default: 4)
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
#     - Maximum max_custom_sep_len characters for custom separators (default: 4)
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
    InitCommonSeparators()
    InitConfig()
    InitCaches()
}

function InitCommonSeparators() {
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
    max_rows = max_rows ? max_rows : 500
    max_custom_sep_len = max_custom_sep_len ? max_custom_sep_len : 4
    custom = length(custom)
    high_certainty = high_certainty ? high_certainty : 0
    debug = debug ? debug : 0

    DS_SEP = "@@@"
    sq = "\'"
    dq = "\""

    n_valid_rows = 0
    max_chunk_weight = 0
}

function InitCaches() {
    split("", CustomFSCount)
    split("", CustomFS)
    split("", Q)
    split("", QFRe)
}

$0 ~ /^ *$/ { next }

{
    n_valid_rows++

    if (n_valid_rows > max_rows) exit

    if (n_valid_rows < 10 && $0 ~ DS_SEP) {
        ds_sep = 1
        print DS_SEP
        exit
    }
}

custom && n_valid_rows == 1 {
    ProcessFirstRow()
}

custom && n_valid_rows == 2 {
    ProcessSecondRow()
}

{
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",$0)

    ProcessCommonSeparators()

    if (custom && n_valid_rows > 2) {
        ProcessCustomSeparators()
    }
}

END {
    if (ds_sep) exit

    if (max_rows > n_valid_rows) max_rows = n_valid_rows

    CalculateScores()
    OutputResult()
}

function ProcessFirstRow() {
    gsub(/^[[:space:]]+|[[:space:]]+$/,"")

    Line[NR] = $0
    split($0, Nonwords, /[A-z0-9(\^\\)"']+/)

    for (i in Nonwords) {
        ProcessNonwordChars(Nonwords[i])
    }
}

function HasHighByte(str,    i) {
    for (i = 1; i <= length(str); i++)
        if (substr(str, i, 1) >= "\200") return 1
    return 0
}

function ProcessNonwordChars(nonword,    Chars, j, len, start, sep, nf) {
    if (debug) print nonword, length(nonword)

    if (HasHighByte(nonword)) {
        sep = "\\" nonword
        if (!IsExcludedCustomSep(sep)) {
            nf = split($0, chartest, sep)
            if (debug) DebugPrint(18)
            if (nf > 1) CustomFSCount[sep] = nf
        }
        return
    }

    split(nonword, Chars, "")

    for (j in Chars) {
        for (len = 1; len <= max_custom_sep_len && len <= j; len++) {
            start = j - len + 1
            sep = EscapedChars(Chars, start, j)
            if (IsExcludedCustomSep(sep)) continue

            nf = split($0, chartest, sep)
            if (debug) DebugPrint(18)
            if (nf > 1) CustomFSCount[sep] = nf
        }
    }
}

function ProcessSecondRow() {
    gsub(/^[[:space:]]+|[[:space:]]+$/,"")
    Line[NR] = $0
    ValidateCustomSeparators()
}

function ValidateCustomSeparators(    i, Chars, j, len, start, sep, nf, nonword) {
    for (i in Nonwords) {
        nonword = Nonwords[i]

        if (HasHighByte(nonword)) {
            sep = "\\" nonword
            nf = split($0, chartest, sep)
            if (CustomFSCount[sep] == nf)
                CustomFS[sep] = 1
            continue
        }

        split(nonword, Chars, "")
        for (j in Chars) {
            for (len = 1; len <= max_custom_sep_len && len <= j; len++) {
                start = j - len + 1
                sep = EscapedChars(Chars, start, j)

                nf = split($0, chartest, sep)
                if (CustomFSCount[sep] == nf)
                    CustomFS[sep] = 1
            }
        }
    }
}

function ProcessCommonSeparators(    s, fs, nf) {
    for (s in CommonFS) {
        fs = CommonFS[s]
        nf = CountFields(fs, s)
        UpdateFieldStats(s, nf)
    }
}

function ProcessCustomSeparators(    fs, nf, i) {
    if (n_valid_rows == 3) {
        for (i = 1; i < 3; i++) {
            for (fs in CustomFS) {
                nf = split(Line[i], _, fs)
                CustomFSCount[fs, NR] = nf
                CustomFSTotal[fs] += nf
            }
        }
    }

    for (fs in CustomFS) {
        nf = split($0, _, fs)
        CustomFSCount[fs, NR] = nf
        CustomFSTotal[fs] += nf
    }
}

function CountFields(fs, s,    nf, qf_line) {
    if (!Q[s]) Q[s] = GetFieldsQuote($0, FixedStringFS[s] fs)

    if (Q[s]) {
        if (!QFRe[s]) QFRe[s] = QuotedFieldsRe(LiteralSepForQuotes(s, fs), Q[s])
        nf = 0
        qf_line = $0

        while (length(qf_line)) {
            match(qf_line, QFRe[s])

            if (debug2) DebugPrint(15)

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
        nf = split($0, _, fs)
    }

    if (debug2) DebugPrint(4)

    return nf
}

function UpdateFieldStats(s, nf,    cnf) {
    CommonFSCount[s, NR] = nf
    CommonFSTotal[s] += nf

    if (PrevNF[s] && nf != PrevNF[s] &&
        !(CommonFSNFConsecCounts[s, PrevNF[s]] > 2)) {
        delete CommonFSNFConsecCounts[s, PrevNF[s]]
    }

    PrevNF[s] = nf

    if (nf < 2) return

    if (debug) print NR, s, nf, CommonFSNFConsecCounts[s, nf]

    cnf = "," nf
    if (!(CommonFSNFSpec[s] ~ cnf "(,|$)")) {
        CommonFSNFSpec[s] = CommonFSNFSpec[s] cnf
    }

    CommonFSNFConsecCounts[s, nf]++
}

function CalculateScores() {
    if (debug) print "\n ---- common sep variance calcs ----"

    for (i = 1; i <= n_common; i++) {
        CalculateSeparatorScore(CommonFSOrder[i])
    }

    if (debug && length(CustomFS)) print " ---- custom sep variance calcs ----"

    if (custom) {
        for (fs in CustomFS) {
            CalculateCustomScore(fs)
        }
    }
}

function CalculateSeparatorScore(s,    average_nf, nf_chunks, NFChunks, nf_i, nf, chunk_weight, chunk_weight_composite, j, point_var) {
    average_nf = CommonFSTotal[s] / max_rows
    nf_chunks = CommonFSNFSpec[s]

    if (nf_chunks) {
        split(nf_chunks, NFChunks, ",")

        for (nf_i in NFChunks) {
            nf = NFChunks[nf_i]
            chunk_weight = CommonFSNFConsecCounts[s, nf] / max_rows

            if (chunk_weight < 0.6) {
                delete CommonFSNFConsecCounts[s, nf]
                continue
            }

            SectionalOverride[s] = 1
            chunk_weight_composite = chunk_weight * nf

            if (!max_chunk_weight) {
                max_chunk_weight = chunk_weight_composite
            }

            if (debug) DebugPrint(16)

            if (chunk_weight_composite >= max_chunk_weight) {
                max_chunk_sep = s
            }
        }
    }

    if (debug) DebugPrint(5)
    if (average_nf < 2 && !SectionalOverride[s]) return

    for (j = 1; j <= max_rows; j++) {
        point_var = (CommonFSCount[s, j] - average_nf) ** 2
        SumVar[s] += point_var
    }

    FSVar[s] = SumVar[s] / max_rows

    if (debug) DebugPrint(6)

    if (FSVar[s] == 0) {
        NoVar[s] = CommonFS[s]
        winning_s = s
        Winners[s] = CommonFS[s]
        if (debug) DebugPrint(7)
    }
    else if (!winning_s || FSVar[s] < FSVar[winning_s]) {
        winning_s = s
        Winners[s] = CommonFS[s]
        if (debug) DebugPrint(8)
    }
}

function CalculateCustomScore(s,    average_nf, j, point_var) {
    average_nf = CustomFSTotal[s] / max_rows

    if (debug) DebugPrint(5)
    if (average_nf < 2) return

    for (j = 3; j <= max_rows; j++) {
        point_var = (CustomFSCount[s, j] - average_nf) ** 2
        SumVar[s] += point_var
    }

    FSVar[s] = SumVar[s] / max_rows

    if (debug) DebugPrint(6)

    if (FSVar[s] == 0) {
        NoVar[s] = s
        winning_s = s
        Winners[s] = s
        if (debug) DebugPrint(10)
    }
    else if (!winning_s || FSVar[s] < FSVar[winning_s]) {
        winning_s = s
        Winners[s] = s
        if (debug) DebugPrint(11)
    }
}

function ResolveNoVarTies() {
    if (length(NoVar) <= 1) return

    if (debug) print ""

    for (s in NoVar) {
        Seen[s] = 1

        for (compare_s in NoVar) {
            if (Seen[compare_s]) continue

            fs1 = NoVar[s]
            fs2 = NoVar[compare_s]

            fs1re = EscapeForRegexMatch(fs1)
            fs2re = EscapeForRegexMatch(fs2)

            if (debug) DebugPrint(12)

            if (fs1 ~ fs2re || fs2 ~ fs1re) {
                k1 = CommonFSKeyForSep(fs1)
                k2 = CommonFSKeyForSep(fs2)

                if (k1 && k1 == k2) {
                    winning_s = k1
                    if (debug) DebugPrint(17)
                }
                else if (length(Winners[winning_s]) < length(fs2) &&
                        length(fs1) < length(fs2)) {
                    winning_s = compare_s
                    if (debug) DebugPrint(13)
                }
                else if (length(Winners[winning_s]) < length(fs1) &&
                        length(fs1) > length(fs2)) {
                    winning_s = s
                    if (debug) DebugPrint(14)
                }
            }
        }
    }
}

function EscapeForRegexMatch(fs,    re, i, char) {
    re = ""
    for (i = 1; i <= length(fs); i++) {
        char = substr(fs, i, 1)
        re = (char == "\\" || char == "|") ? re "\\" char : re char
    }
    return re
}

function OutputResult(    k, scaled_var, scaled_var_frac, winner_unsure) {
    if (max_chunk_sep && !length(NoVar)) {
        if (debug) print "No zero var seps and sectional novar sep exists, override with sep "max_chunk_sep
        print FormatOutputFS(CommonFS[max_chunk_sep])
        exit
    }

    ResolveNoVarTies()

    if (winning_s) {
        k = CommonFSKeyForSep(Winners[winning_s])
        if (k) winning_s = k
    }

    if (high_certainty) {
        scaled_var = FSVar[winning_s] * 10
        scaled_var_frac = scaled_var - int(scaled_var)
        winner_unsure = scaled_var_frac != 0
        if (winner_unsure) exit 1
    }

    if (!winning_s) {
        print CommonFS["s"]
        exit 0
    }

    print FormatOutputFS(Winners[winning_s])

    exit 0
}

function LiteralSepForQuotes(s, fs) {
    if (FixedStringFS[s] != "") return FixedStringFS[s] fs
    return fs
}

function FormatOutputFS(winner,    k) {
    if (winner ~ /(\\ )*\\,(\\ )+/) return ","

    k = CommonFSKeyForSep(winner)
    if (k == "o") return ","
    if (k && FixedStringFS[k] != "" && CommonFS[k] !~ /^\[/)
        return FixedStringFS[k] CommonFS[k]
    if (k && CommonFS[k] ~ /^\[/) return CommonFS[k]

    return winner
}

function CommonFSKeyForSep(fs,   i, s, bare) {
    for (i = 1; i <= n_common; i++) {
        s = CommonFSOrder[i]
        if (fs == CommonFS[s]) return s
        bare = substr(fs, 2)
        if (substr(fs, 1, 1) == "\\" && bare == CommonFS[s] \
                && length(fs) == length(bare) + 1)
            return s
    }
    return ""
}

function EscapedChars(Chars, start, end,    s, k) {
    s = ""
    for (k = start; k <= end; k++)
        s = s "\\" Chars[k]
    return s
}

function IsExcludedCustomSep(sep) {
    return (length(sep) == 2 && sep ~ /\\[[:space:]\|;:,]/)
}

function QuotedFieldsRe(sep, q) {
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
    } else if (_case == 17) {
        print "NoVar tie resolved to common FS key \""winning_s"\" = \""CommonFS[winning_s]"\""
    } else if (_case == 18) {
        print "custom sep len " len ": " sep, nf
    }
}
