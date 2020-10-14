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
## TODO: Handle stray data that creates empty fields and can lead to custom NoVar 
## pattern handling breaking (i.e. ,,, winning over , by creating two fields)
## TODO: Optional smart inference based on a set of lines with common separator
## variance (probably external)
## TODO: Handle escapes, null Chars, SUBSEP
## TODO: Regex FS length handling

BEGIN {
  CommonFS["s"] = " "; FixedStringFS["s"] = "\\"
  CommonFS["t"] = "\t"; FixedStringFS["t"] = "\\"
  CommonFS["p"] = "\|"; FixedStringFS["p"] = "\\"
  CommonFS["m"] = ";"; FixedStringFS["m"] = "\\"
  CommonFS["c"] = ":"; FixedStringFS["c"] = "\\"
  CommonFS["o"] = ","; FixedStringFS["o"] = "\\"
  CommonFS["w"] = "[[:space:]]+"
  CommonFS["2w"] = "[[:space:]]{2,}"
  DS_SEP = "@@@"
  sq = "\'"
  dq = "\""
  if (!max_rows) max_rows = 500
  custom = length(custom)
}

NR > max_rows { exit }

NR < 10 {
  if ($0 ~ DS_SEP) {
    ds_sep = 1
    print DS_SEP
    exit }
}

custom && NR == 1 {
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
      if ( ! char ~ /[\s\|;:]/ ) {
        char_nf = split($0, chartest, char)
        if (debug) DebugPrint(1)
        if (char_nf > 1) CharFSCount[char] = char_nf }

      if (j > 1) {
        prevchar = "\\" Chars[j-1]
        twochar = prevchar char
        twochar_nf = split($0, twochartest, twochar)
        if (debug) DebugPrint(2)
        if (twochar_nf > 1) { TwoCharFSCount[twochar] = twochar_nf }}

      if (j > 2) {
        twoprevchar = "\\" Chars[j-2]
        thrchar = twoprevchar prevchar char
        thrchar_nf = split($0, thrchartest, thrchar)
        if (debug) DebugPrint(3)
        if (thrchar_nf > 1) ThrCharFSCount[thrchar] = thrchar_nf }}}
}

custom && NR == 2 {
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
          CustomFS[twochar] = 1 }

      if (j > 2) {
        if (Chars[j-2]) twoprevchar = "\\" Chars[j-2]
        thrchar = twoprevchar prevchar char
        thrchar_nf = split($0, thrchartest, thrchar)
        if (ThrCharFSCount[thrchar] == thrchar_nf) {
          CustomFS[thrchar] = 1 }}}}
}

{
  gsub(/^[[:space:]]+|[[:space:]]+$/,"",$0)

  for (s in CommonFS) {
    fs = CommonFS[s]
    qf_line = 0
    q = GetFieldsQuote($0, FixedStringFS[s] fs)
    if (q) {
      nf = 0
      len_nqf = split($0, NonquotedField, QuotedFieldsRe(fs, q))
      for (nqf_i = 1; nqf_i <= len_nqf; nqf_i++) {
        nqf = NonquotedField[nqf_i]
        nf += split(nqf, Tmp, fs)
        if (nqf_i < len_nqf) nf++ }}
    else
      nf = split($0, _, fs)
    CommonFSCount[s, NR] = nf
    CommonFSTotal[s] += nf }

  if (custom && NR > 2) {
    if (NR == 3) {
      for (i = 1; i < 3; i++) {
        for (fs in CustomFS) {
          nf = split(Line[i], _, fs)
          CustomFSCount[fs, NR] = nf
          CustomFSTotal[fs] += nf }}}

    for (fs in CustomFS) {
      nf = split($0, _, fs)
      CustomFSCount[fs, NR] = nf
      CustomFSTotal[fs] += nf }}
}

END {
  if (ds_sep) exit

  if (max_rows > NR) max_rows = NR

  # Calculate variance for each separator
  if (debug) print "\n ---- common sep variance calcs ----"
  for (s in CommonFS) {
    average_nf = CommonFSTotal[s] / max_rows
    
    if (debug) DebugPrint(5)
    if (average_nf < 2) { continue }

    for (j = 1; j <= max_rows; j++) {
      point_var = (CommonFSCount[s, j] - average_nf) ** 2
      SumVar[s] += point_var }
    
    FSVar[s] = SumVar[s] / max_rows

    if (debug) DebugPrint(6)

    if (FSVar[s] == 0) {
      NoVar[s] = CommonFS[s]
      winning_s = s
      Winners[s] = CommonFS[s]
      if (debug) DebugPrint(7) }
    else if ( !winning_s || FSVar[s] < FSVar[winning_s] ) {
      winning_s = s
      Winners[s] = CommonFS[s]
      if (debug) DebugPrint(8) }}

  if (debug && length(CustomFS)) print " ---- custom sep variance calcs ----"
  if (custom) {
    for (s in CustomFS) {
      average_nf = CustomFSTotal[s] / max_rows

      if (debug) DebugPrint(5)
      if (average_nf < 2) { continue }

      for (j = 3; j <= max_rows; j++) {
        point_var = (CustomFSCount[s, j] - average_nf) ** 2
        SumVar[s] += point_var }

      FSVar[s] = SumVar[s] / max_rows

      if (debug) DebugPrint(6)

      if (FSVar[s] == 0) {
        NoVar[s] = s
        winning_s = s
        Winners[s] = s
        if (debug) DebugPrint(10) }
      else if ( !winning_s || FSVar[s] < FSVar[winning_s]) {
        winning_s = s
        Winners[s] = s 
        if (debug) DebugPrint(11) }}}
  
  # Handle cases of multiple separators with no variance
  if (length(NoVar) > 1) {
    if (debug) print ""
    for (s in NoVar) {
      Seen[s] = 1
      for (compare_s in NoVar) {
        if (Seen[compare_s]) continue
        fs1 = NoVar[s]
        fs2 = NoVar[compare_s]

        fs1re = ""; fs2re = ""
        split(fs1, Tmp, "")
        for (i = 1; i <= length(Tmp); i++) {
          char = Tmp[i]
          fs1re = (char == "\\") ? fs1re "\\" char : fs1re char }
        split(fs2, Tmp, "")
        for (i = 1; i <= length(Tmp); i++) {
          char = Tmp[i]
          fs2re = (char == "\\" || char == "\|") ? fs2re "\\" char : fs2re = fs2re char }

        if (debug) DebugPrint(12)

        # If one separator with no variance is contained inside another, use the longer one
        if (fs1 ~ fs2re || fs2 ~ fs1re) {
          if (length(Winners[winning_s]) < length(fs2) && length(fs1) < length(fs2)) {
            winning_s = compare_s
            if (debug) DebugPrint(13) }
          else if (length(Winners[winning_s]) < length(fs1) && length(fs1) > length(fs2)) {
            winning_s = s
            if (debug) DebugPrint(14) }}}}}

  if (high_certainty) { # TODO: add this check in NoVar comparison
    scaled_var = FSVar[winning_s] * 10
    scaled_var_frac = scaled_var - int(scaled_var)
    winner_unsure = scaled_var_frac != 0 }

  if ( ! winning_s || winner_unsure ) 
    print CommonFS["s"] # Space is default separator
  else
    print Winners[winning_s]
}

function QuotedFieldsRe(sep, quote) {
  return "(^|" sep ")" quote ".+" quote "(" sep "|$)"
}
function GetFieldsQuote(line, sep) { # TODO: Set as state machine in array per sep
  dq_sep_re = QuotedFieldsRe(sep, dq)
  if (line ~ dq_sep_re) return dq
  sq_sep_re = QuotedFieldsRe(sep, sq)
  if (line ~ sq_sep_re) return sq
}
function DebugPrint(case) {
  if (case == 1)
    print "char:" char, char_nf
  else if (case == 2)
    print "twochar:" twochar, twochar_nf
  else if (case == 3)
    print "thrchar:" thrchar, thrchar_nf
  else if (case == 5) {
    printf "%s", s " average nf: " average_nf
    print (average_nf >= 2 ? ", will calc var" : "") }
  else if (case == 6) 
    print s " FSVar: " FSVar[s]
  else if (case == 7)
    print "NoVar winning_s set to CommonFS[\""s"\"] = \"" CommonFS[s] "\""
  else if (case == 8)
    print "winning_s set to CommonFS[\""s"\"] = \"" CommonFS[s] "\""
  else if (case == 10)
    print "NoVar winning_s set to CustomFS \""s"\""
  else if (case == 11)
    print "NoVar winning_s set to CustomFS \""s"\""
  else if (case == 12) {
    print " ---- NoVar handling case ----"
    print "s: \""s"\", fs1: \""fs1"\""
    print "compare_s: \""compare_s"\", fs2: \""fs2"\""
    print "matches:", fs1 ~ fs2
    print "len winner: "length(Winners[s])", len fs1: "length(fs1)", len fs2: "length(fs2) }
  else if (case -- 13)
    print "s: \""s"\", compare_s: \""compare_s"\", winning_s switched to: \""compare_s"\""
  else if (case == 14)
    print "compare_s: \""compare_s"\", s: \""s"\", winning_s switched to: \""s"\""
}
