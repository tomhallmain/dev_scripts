#!/usr/bin/awk
#
# Infers a field separator in a text data file based on likelihood of common field
# separators and commonly found substrings in the data of up to three characters.
#
# The newline separator is not inferable via this script. Custom field separators
# containing alphanumeric characters are also not supported.
#
# Run as:
# > awk -f infer_field_separator.awk "data_file"
#
# To infer a custom separator, set var `custom` to any value:
# > awk -f infer_field_separator.awk -v custom=true "data_file"
#
## TODO: Regex FS length handling in winner determination
## TODO: Infer absence of separator (output low confidence true)

BEGIN {
    CommonFSOrder[1] = "s"; CommonFS["s"] = " "; FixedStringFS["s"] = "\\"
    CommonFSOrder[2] = "t"; CommonFS["t"] = "\t"; FixedStringFS["t"] = "\\"
    CommonFSOrder[3] = "p"; CommonFS["p"] = "\|"; FixedStringFS["p"] = "\\"
    CommonFSOrder[4] = "m"; CommonFS["m"] = ";"; FixedStringFS["m"] = "\\"
    CommonFSOrder[5] = "c"; CommonFS["c"] = ":"; FixedStringFS["c"] = "\\"
    CommonFSOrder[6] = "o"; CommonFS["o"] = ","; FixedStringFS["o"] = "\\"
    CommonFSOrder[7] = "w"; CommonFS["w"] = "[[:space:]]+"
    CommonFSOrder[8] = "2w"; CommonFS["2w"] = "[[:space:]]{2,}"

    n_common = length(CommonFS)
    DS_SEP = "@@@"
    sq = "\'"
    dq = "\""
    n_valid_rows = 0

    if (!max_rows) max_rows = 500
    custom = length(custom)
}

$0 ~ /^ *$/ { next }

{ n_valid_rows++ }

n_valid_rows > max_rows { exit }

n_valid_rows < 10 {
    if ($0 ~ DS_SEP) {
        ds_sep = 1
        print DS_SEP
        exit
    }
}

custom && n_valid_rows == 1 {
    # Remove leading and trailing spaces
    gsub(/^[[:space:]]+|[[:space:]]+$/,"")

    Line[NR] = $0
    split($0, Nonwords, /[A-z0-9(\^\\)"']+/)

    for (i in Nonwords) {
        if (debug) print Nonwords[i], length(Nonwords[i])
        split(Nonwords[i], Chars, "")

        for (j in Chars) {
            char = "\\" Chars[j]

            # Exclude common fs Chars
            if (!(char ~ /[\s\|;:,]/)) {
                char_nf = split($0, chartest, char)
                if (debug) DebugPrint(1)
                if (char_nf > 1) CharFSCount[char] = char_nf
            }

            if (j > 1) {
                prevchar = "\\" Chars[j-1]
                twochar = prevchar char
                twochar_nf = split($0, twochartest, twochar)

                if (debug) DebugPrint(2)

                if (twochar_nf > 1) {
                    TwoCharFSCount[twochar] = twochar_nf
                }
            }

            if (j > 2) {
                twoprevchar = "\\" Chars[j-2]
                thrchar = twoprevchar prevchar char
                thrchar_nf = split($0, thrchartest, thrchar)

                if (debug) DebugPrint(3)

                if (thrchar_nf > 1) ThrCharFSCount[thrchar] = thrchar_nf
            }
        }
    }
}

custom && n_valid_rows == 2 {
    gsub(/^[[:space:]]+|[[:space:]]+$/,"")
    Line[NR] = $0

    for (i in Nonwords) {
        split(Nonwords[i], Chars, "")
        for (j in Chars) {
            if (Chars[j]) char = "\\" Chars[j]

            char_nf = split($0, chartest, char)
            if (CharFSCount[char] == char_nf)
                CustomFS[char] = 1

            if (j > 1) {
                if (Chars[j-1]) prevchar = "\\" Chars[j-1]
                twochar = prevchar char
                twochar_nf = split($0, twochartest, twochar)
                if (TwoCharFSCount[twochar] == twochar_nf)
                    CustomFS[twochar] = 1
            }

            if (j > 2) {
                if (Chars[j-2]) twoprevchar = "\\" Chars[j-2]
                thrchar = twoprevchar prevchar char
                thrchar_nf = split($0, thrchartest, thrchar)
                if (ThrCharFSCount[thrchar] == thrchar_nf) {
                    CustomFS[thrchar] = 1
                }
            }
        }
    }
}

{
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",$0)

    for (s in CommonFS) {
        fs = CommonFS[s]

        if (!Q[s]) Q[s] = GetFieldsQuote($0, FixedStringFS[s] fs)

        if (Q[s]) {
            if (!QFRe[s]) QFRe[s] = QuotedFieldsRe(fs, Q[s])
            nf = 0; qf_line = $0

            while (length(qf_line)) {
                match(qf_line, QFRe[s])

                if (debug2) DebugPrint(15)

                if (RSTART) {
                    nf++
                    if (RSTART > 1)
                        nf += split(substr(qf_line, 1, RSTART-1), _, fs)
                }
                else {
                    nf += split(qf_line, _, fs)
                    break
                }

                qf_line = substr(qf_line, RSTART+RLENGTH, length(qf_line))
            }
        }
        else {
            nf = split($0, _, fs)
        }

        if (debug2) DebugPrint(4)

        CommonFSCount[s, NR] = nf
        CommonFSTotal[s] += nf

        if (PrevNF[s] && nf != PrevNF[s] \
                    && !(CommonFSNFConsecCounts[s, PrevNF[s]] > 2)) {
            delete CommonFSNFConsecCounts[s, PrevNF[s]]
        }

        PrevNF[s] = nf

        if (nf < 2) continue
        if (debug) print NR, s, nf, CommonFSNFConsecCounts[s, nf]
        cnf = ","nf

        if (!(CommonFSNFSpec[s] ~ cnf"(,|$)")) {
            CommonFSNFSpec[s] = CommonFSNFSpec[s] cnf
        }

        CommonFSNFConsecCounts[s, nf]++
    }

    if (custom && n_valid_rows > 2) {
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
}

END {
    if (ds_sep) exit

    if (max_rows > n_valid_rows) max_rows = n_valid_rows

    # Calculate variance for each separator
    if (debug) print "\n ---- common sep variance calcs ----"

    for (i = 1; i <= n_common; i++) {

        s = CommonFSOrder[i]
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
        if (average_nf < 2 && !SectionalOverride[s]) continue

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
        else if ( !winning_s || FSVar[s] < FSVar[winning_s] ) {
            winning_s = s
            Winners[s] = CommonFS[s]

            if (debug) DebugPrint(8)
        }
    }

    if (debug && length(CustomFS)) print " ---- custom sep variance calcs ----"

    if (custom) {
        for (s in CustomFS) {

            average_nf = CustomFSTotal[s] / max_rows

            if (debug) DebugPrint(5)
            if (average_nf < 2) continue

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
            else if ( !winning_s || FSVar[s] < FSVar[winning_s]) {
                winning_s = s
                Winners[s] = s

                if (debug) DebugPrint(11)
            }
        }
    }

    if (max_chunk_sep && !length(NoVar)) {
        if (debug) print "No zero var seps and sectional novar sep exists, override with sep "max_chunk_sep
        print CommonFS[max_chunk_sep]
        exit
    }

    # Handle cases of multiple separators with no variance -- TODO Refactor into
    # new chunky logic above and add customFS chunks calcs
    if (length(NoVar) > 1) {
        if (debug) print ""

        for (s in NoVar) {
            Seen[s] = 1

            for (compare_s in NoVar) {
                if (Seen[compare_s]) continue

                fs1 = NoVar[s]
                fs2 = NoVar[compare_s]

                fs1re = ""
                fs2re = ""
                split(fs1, Tmp, "")

                for (i = 1; i <= length(Tmp); i++) {
                    char = Tmp[i]
                    fs1re = (char == "\\" || char == "\|") ? fs1re "\\" char : fs1re char
                }

                split(fs2, Tmp, "")

                for (i = 1; i <= length(Tmp); i++) {
                    char = Tmp[i]
                    fs2re = (char == "\\" || char == "\|") ? fs2re "\\" char : fs2re = fs2re char
                }

                if (debug) DebugPrint(12)

                # If one separator with no variance is contained inside another, use the longer one
                if (fs1 ~ fs2re || fs2 ~ fs1re) {
                    if (length(Winners[winning_s]) < length(fs2) \
                            && length(fs1) < length(fs2)) {
                        winning_s = compare_s

                        if (debug) DebugPrint(13)
                    }
                    else if (length(Winners[winning_s]) < length(fs1) \
                            && length(fs1) > length(fs2)) {
                        winning_s = s

                        if (debug) DebugPrint(14)
                    }
                }
            }
        }
    }

    if (high_certainty) { # TODO: add this check in chunks comparison
        scaled_var = FSVar[winning_s] * 10
        scaled_var_frac = scaled_var - int(scaled_var)
        winner_unsure = scaled_var_frac != 0
    }

    if ( ! winning_s || winner_unsure ) {
        print CommonFS["s"] # Space is default separator
    }
    else if (Winners[winning_s] ~ /(\\ )*\\,(\\ )+/) {
        print ","
    }
    else {
        print Winners[winning_s]
    }
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
