# Infers a field separator in a text data file based on
# likelihood of common field separators and commonly found
# substrings in the data.
# 
# The newline separator is not inferable via this script.
#
# Run as:
# awk -f infer_field_separator.awk "data_file"

BEGIN {

  x = SUBSEP
  cfs_str = " " x "\t" x "|" x ";" x ":"
  cfst_str = "s" x "t" x "p" x "m" x "c"
  n_cfs = split(cfs_str, cfs, x)
  split(cfst_str, cfst, x)
  max_rows = 500

}

NR <= max_rows { line[NR] = $0; line_count++ }

END {

  if (max_rows > line_count) { max_rows = line_count }

  for (i = 1; i <= n_cfs; i++) {
    for (j = 1; j <= max_rows; j++) {
      fs = cfs[i]
      fst = cfst[i]
      nf = split(line[j], tmp, fs)
      cfs_count[fst, j] = nf
      cfs_total[fst] += nf
    }
  }
  
  winning_fs = "s"

  # Calculate variance for each separator
  for (i = 1; i <= n_cfs; i++) {
    fs = cfs[i]
    fst = cfst[i]
    average_nf = cfs_total[fst] / max_rows

    if (average_nf < 2) { continue }

    for (j = 1; j <= max_rows; j++) {
      point_var = (cfs_count[fst, j] - average_nf)^2
      sum_var[fst] += point_var
    }
    
    fs_score[fst] = sum_var[fst] / max_rows

    if (fs_score[fst] < fs_score[winning_fs]) {
      winning_fs = fst
    }
  }

  print winning_fs
}

# TODO: Test common patterns in a couple lines to try
# to grab unique separators

# Unfortunately there is no way to change the FS after a line 
# has been read into the normal program space in AWK. To not 
# store all line data in a single array would mean we would 
# have to pass the script over the number of field separators 
# to test, and we also couldn't check for patterns beyond that 
# as easily.
