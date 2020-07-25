# Infers a field separator in a text data file based on
# likelihood of common field separators and commonly found
# substrings in the data.
# 
# The newline separator is not inferable via this script.
#
# Run as:
# awk -f infer_field_separator.awk "data_file"

BEGIN {
  cfs["s"] = " "
  cfs["t"] = "\t"
  cfs["p"] = "|"
  cfs["m"] = ";"
  cfs["c"] = ":"
  max_rows = 500
}

NR <= max_rows { 
  for (fst in cfs) {
    fs = cfs[fst]
    nf = split($0, _, fs)
    cfs_count[fst, NR] = nf
    cfs_total[fst] += nf
  } 
}

END {
  if (max_rows > NR) { max_rows = NR }

  # Calculate variance for each separator
  for (fst in cfs) {
    average_nf = cfs_total[fst] / max_rows
    
    if (average_nf < 2) { continue }

    for (j = 1; j <= max_rows; j++) {
      point_var = (cfs_count[fst, j] - average_nf)^2
      sum_var[fst] += point_var
    }
    
    fs_score[fst] = sum_var[fst] / max_rows

    if ( ! winning_fs ) {
      winning_fs = fst
    } else if (fs_score[fst] < fs_score[winning_fs]) {
      winning_fs = fst
    }
  }

  if ( ! winning_fs ) winning_fs = "s"

  print cfs[winning_fs]
}

# TODO: Test common patterns in a couple lines to try
# to grab unique separators

