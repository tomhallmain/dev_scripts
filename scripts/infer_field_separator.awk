#!/usr/bin/awk
#
# Infers a field separator in a text data file based on
# likelihood of common field separators and commonly found
# substrings in the data of up to three characters.
# 
# The newline separator is not inferable via this script.
# Custom field separators containing alphanumeric characters 
# are also not supported.
#
# Run as:
# > awk -f infer_field_separator.awk "data_file"
#
# To infer a custom separator, set var `custom` to any value:
# > awk -f infer_field_separator.awk -v custom=true "data_file"
#
# TODO: Handle stray data that creates empty fields and can lead to custom
# novar pattern handling breaking (i.e. ,,, winning over , by creating two
# fields)
# TODO:mHandle escapes, null chars, SUBSEP

BEGIN {
  commonfs["s"] = " "
  commonfs["t"] = "\t"
  commonfs["p"] = "\|"
  commonfs["m"] = ";"
  commonfs["c"] = ":"
  commonfs["o"] = ","
  commonfs["w"] = "[[:space:]]+"
  commonfs["2w"] = "[[:space:]]{2,}"
  if (!max_rows) max_rows = 500
  custom = length(custom)
}

custom && NR == 1 {
  # Remove leading and trailing spaces
  gsub(/^[[:space:]]+|[[:space:]]+$/,"")
  line[NR] = $0
  split($0, nonwords, /[A-z0-9(\^\\)]+/)

  for (i in nonwords) {
    if (debug) print nonwords[i], length(nonwords[i])
    split(nonwords[i], chars, "")

    for (j in chars) {
      char = "\\" chars[j]

      # Exclude common fs chars
      if ( ! char ~ /[\s\|;:]/ ) {
        char_nf = split($0, chartest, char)
        if (debug) print "char:" char, char_nf
        if (char_nf > 1) charfs_count[char] = char_nf
      }

      if (j > 1) {
        prevchar = "\\" chars[j-1]
        twochar = prevchar char
        twochar_nf = split($0, twochartest, twochar)
        if (debug) print "twochar:" twochar, twochar_nf
        if (twochar_nf > 1) { twocharfs_count[twochar] = twochar_nf }
      }

      if (j > 2) {
        twoprevchar = "\\" chars[j-2]
        thrchar = twoprevchar prevchar char
        thrchar_nf = split($0, thrchartest, thrchar)
        if (debug) print "thrchar:" thrchar, thrchar_nf
        if (thrchar_nf > 1) thrcharfs_count[thrchar] = thrchar_nf
      }
    }
  }
}

custom && NR == 2 {
  gsub(/^[[:space:]]+|[[:space:]]+$/,"")
  line[NR] = $0

  for (i in nonwords) {
    split(nonwords[i], chars, "")
    for (j in chars) {
      if (chars[j]) char = "\\" chars[j]
      
      char_nf = split($0, chartest, char)
      if (charfs_count[char] == char_nf) {
        customfs[char] = 1
      }
      if (j > 1) {
        if (chars[j-1]) prevchar = "\\" chars[j-1]
        twochar = prevchar char
        twochar_nf = split($0, twochartest, twochar)
        if (twocharfs_count[twochar] == twochar_nf) {
          customfs[twochar] = 1
        }
      }
      if (j > 2) {
        if (chars[j-2]) twoprevchar = "\\" chars[j-2]
        thrchar = twoprevchar prevchar char
        thrchar_nf = split($0, thrchartest, thrchar)
        if (thrcharfs_count[thrchar] == thrchar_nf) {
          customfs[thrchar] = 1
        }
      }
    }
  }
}

NR <= max_rows { 
  gsub(/^[[:space:]]+|[[:space:]]+$/,"",$0)

  for (s in commonfs) {
    fs = commonfs[s]
    nf = split($0, _, fs)
    commonfs_count[s, NR] = nf
    commonfs_total[s] += nf
  }

  if (custom && NR > 2) {
    if (NR == 3) {
      for (i = 1; i < 3; i++) {
        for (fs in customfs) {
          nf = split(line[i], _, fs)
          customfs_count[fs, NR] = nf
          customfs_total[fs] += nf 
        }
      }
    }

    for (fs in customfs) {
      nf = split($0, _, fs)
      customfs_count[fs, NR] = nf
      customfs_total[fs] += nf 
    }
  }
}

END {
  if (max_rows > NR) max_rows = NR

  # Calculate variance for each separator
  for (s in commonfs) {
    average_nf = commonfs_total[s] / max_rows
    
    if (debug) print s, "average nf: " average_nf

    if (average_nf < 2) { continue }

    for (j = 1; j <= max_rows; j++) {
      point_var = (commonfs_count[s, j] - average_nf) ** 2
      sum_var[s] += point_var
    }
    
    fs_var[s] = sum_var[s] / max_rows

    if (debug) print s, "fs_var: " fs_var[s]

    if ( !winning_fs || fs_var[s] < fs_var[winning_fs] ) {
      winning_fs = s
      winners[s] = commonfs[s]
    }

    if (fs_var[s] == 0) {
      novar[s] = commonfs[s]
      winning_fs = s
      winners[s] = commonfs[s]
    }
  }

  if (custom) {
    for (s in customfs) {
      average_nf = customfs_total[s] / max_rows
      
      if (average_nf < 2) { continue }

      for (j = 3; j <= max_rows; j++) {
        point_var = (customfs_count[s, j] - average_nf) ** 2
        sum_var[s] += point_var
      }
      
      fs_var[s] = sum_var[s] / max_rows

      if (debug) print s, fs_var[s], average_nf
      
      if ( !winning_fs || fs_var[s] < fs_var[winning_fs]) {
        winning_fs = s
        winners[s] = s
      }

      if (fs_var[s] == 0) {
        novar[s] = s
        winning_fs = s
        winners[s] = s
      }
    }    
  }
  
  # Handle cases of multiple separators with no variance
  if (length(novar) > 1) {
    for (s in novar) {
      seen[s] = 1
      for (compare_s in novar) {
        if (seen[compare_s]) continue
        fs1 = novar[s]
        fs2 = novar[compare_s]

        fs1re = ""; fs2re = ""
        split(fs1, tmp, "")
        for (i = 1; i <= length(tmp); i++) {
          char = tmp[i]
          if (char == "\\")
            fs1re = fs1re "\\" char
          else
            fs1re = fs1re char }
        split(fs2, tmp, "")
        for (i = 1; i <= length(tmp); i++) {
          char = tmp[i]
          if (char == "\\" || char == "\|")
            fs2re = fs2re "\\" char
          else
            fs2re = fs2re char }

        if (debug) print "novar handling case", "s: " s, "fs1: " fs1, "compare_s: " compare_s, "fs2: " fs2, "matches:", fs1 ~ fs2
        if (debug) print "len winner: " length(winners[s]), "len fs1: " length(fs1), "len fs2 " length(fs2)

        if (fs1 ~ fs2re || fs2 ~ fs1re) {
          # If one separator with no field delineation variance is 
          # contained inside another, use the longer one
          if (length(winners[winning_fs]) < length(fs2) \
            && length(fs1) < length(fs2)) {
            winning_fs = fs2
            if (debug) print "s: " s, "winning fs switched to: " compare_s
          } else if (length(winners[winning_fs]) < length(fs1) \
            && length(fs1) > length(fs2)) {
            winning_fs = fs1
            if (debug) print "compare_s: " compare_s, "winning fs switched to: " s
          }
        }
      }
    }
  }

  if (high_certainty) {
    scaled_var = fs_var[winning_fs] * 10
    scaled_var_frac = scaled_var - int(scaled_var)
    winner_unsure = scaled_var_frac != 0
  }

  if ( ! winning_fs || winner_unsure ) 
    print commonfs["s"] # Space is default separator
  else
    print winners[winning_fs]
}

