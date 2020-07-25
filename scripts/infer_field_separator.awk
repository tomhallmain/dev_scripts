# Infers a field separator in a text data file based on
# likelihood of common field separators and commonly found
# substrings in the data.
# 
# The newline separator is not inferable via this script.
# Custom field separators containing alpha chars are also not
# supported.
#
# Run as:
# awk -f infer_field_separator.awk "data_file"
#
# Run and attempt to infer a custom separator, set var `custom` 
# to any value:
# awk -f infer_field_separator.awk -v custom=true "data_file"

BEGIN {
  commonfs["s"] = " "
  commonfs["t"] = "\t"
  commonfs["p"] = "|"
  commonfs["m"] = ";"
  commonfs["c"] = ":"
  max_rows = 500
  custom = length(custom)
}

custom && NR == 1 {
  line[NR] = $0

  split($0, nonwords, /[A-z0-9]+/)

  for (i in nonwords) {
    split(nonwords[i], chars, "")

    for (j in chars) {
      char = chars[j]
      
      # Exclude common fs chars
      if ( ! char ~ /[\s\|;:]/ ) {
        char_nf = split($0, chartest, char)
        if (char_nf > 1) charfs_count[char] = char_nf
      }

      if (j > 1) {
        prevchar = chars[j-1]
        twochar = prevchar char
        twochar_nf = split($0, twochartest, twochar)
        if (twochar_nf > 1) { twocharfs_count[twochar] = twochar_nf }
      }

      if (j > 2) {
        twoprevchar = chars[j-2]
        thrchar = twoprevchar prevchar char
        thrchar_nf = split($0, thrchartest, thrchar)
        if (thrchar_nf > 1) thrcharfs_count[thrchar] = thrchar_nf
      }
    }
  }
}

custom && NR == 2 {
  line[NR] = $0

  for (i in nonwords) {
    split(nonwords[i], chars, "")
    for (j in chars) {
      char = chars[j]
      
      char_nf = split($0, chartest, char)
      if (charfs_count[char] == char_nf) {
        customfs[char] = 1
      }
      if (j > 1) {
        prevchar = chars[j-1]
        twochar = prevchar char
        twochar_nf = split($0, twochartest, twochar)
        if (twocharfs_count[twochar] == twochar_nf) {
          customfs[twochar] = 1
        }
      }
      if (j > 2) {
        twoprevchar = chars[j-2]
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
  for (fst in commonfs) {
    fs = commonfs[fst]
    nf = split($0, _, fs)
    commonfs_count[fst, NR] = nf
    commonfs_total[fst] += nf
  }
  if (custom && NR > 2) {
    if (NR == 3) {
      for (i = 1; i < 3; i++) {
        for (fs in customfs) {
          print "> " fs " <"
          nf = split(line[i], _, fs)
          customfs_count[fs, NR] = nf
          customfs_total[fs] += nf 
        }
      }
    }
    for (fs in customfs) {
      print "> " fs " <"
      nf = split($0, _, fs)
      customfs_count[fs, NR] = nf
      customfs_total[fs] += nf 
    }
  }
}

END {
  if (max_rows > NR) max_rows = NR

  # Calculate variance for each separator
  for (fst in commonfs) {
    average_nf = commonfs_total[fst] / max_rows
    
    if (average_nf < 2) { continue }

    for (j = 1; j <= max_rows; j++) {
      point_var = (commonfs_count[fst, j] - average_nf)^2
      sum_var[fst] += point_var
    }
    
    fs_var[fst] = sum_var[fst] / max_rows

    if ( !winning_fs || fs_var[fst] < fs_var[winning_fs] ) {
      print "winning_fs changed from " winning_fs " to " fst " with var of " fs_var[fst]
      winning_fs = fst
    }

    if (fs_var[fst] == 0) {
      novar[fst] = commonfs[fst]
    }
  }

  if (custom) {
    for (fs in customfs) {
      average_nf = customfs_total[fs] / max_rows
      
      if (average_nf < 2) { continue }

      for (j = 3; j <= max_rows; j++) {
        point_var = (customfs_count[fs, j] - average_nf)^2
        sum_var[fs] += point_var
      }
      
      fs_var[fs] = sum_var[fs] / max_rows

      print fs, fs_var[fs]

      if ( !winning_fs || fs_var[fs] < fs_var[winning_fs]) {
        winning_fs = fs
        cfs[fs] = fs
      }

      if (fs_var[fs] == 0) {
        novar[fs] == fs
      }
    }    
  }
  
  # Handle cases of multiple separators with no variance
  if (length(novar) > 1) {
    for (fskey in novar) {
      seen[fskey] = 1
      for (fscomparekey in novar) {
        if (seen[fscomparekey]) continue
        novarfs1 = novar[fskey]
        novarfs2 = novar[fscomparekey]
        if (novarfs1 ~ novarfs2) {
          # If one separator with no field delineation variance is 
          # contained inside another, use the one with the longer 
          # length.
          if(length(winning_fs) < length(novarfs2) \
            && length(novarfs1) < length(novarfs1)) {
            winning_fs = novarfs2
          }
        }
      }
    }
  }

  if ( ! winning_fs ) { winning_fs = "s"; print "test" }

  print "> " cfs[winning_fs] " <"
}

