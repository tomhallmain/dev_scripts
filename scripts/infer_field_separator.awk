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
  cfst = "s" x "t" x "p" x "m" x "c"
  cfs = " " x "\t" x "|" x ";" x ":"
  n_cfs = split(cfs, cfs_array, x)
  split(cfst, cfst_array, x)
  max_rows = 500
}

NR <= max_rows {
  line[NR] = $0 
}

END {

  for (i = 1; i <= n_cfs; i++) {
    for (j = 1; j <= max_rows; j++) {
      fs = cfs_array[i]
      fst = cfst_array[i]
      nf = split(line[j], tmp, fs)
      cfs_count[fst, j] = nf
      cfs_total[fst] += nf
    }
  }
  
  winning_separator = "s"

  # Calculate variance for each separator
  for (i = 1; i <= n_cfs; i++) {
    fs = cfs_array[i]
    fst = cfst_array[i]
    average_nf = cfs_total[fst] / max_rows

    for (j = 1; j <= max_rows; j++) {
      point_var = (cfs_count[fst, j] - average_nf)^2
      sum_var[fst] += point_var
    }
    
    fs_score[fst] = sum_var[fst] / max_rows

    if (average_nf >= 2 && fs_score[fst] < fs_score[winning_separator]) {
      winning_separator = fst
    }
  }

  print winning_separator
}

# TODO: Test common patterns in a couple lines to try
# to grab unique separators

# Unfortunately there is no way to change the FS after a line 
# has been read. To not store all line data in a single array 
# would mean we would have to pass the script over the number
# of field separators to test, and we also couldn't check for 
# patterns beyond that as easily.
