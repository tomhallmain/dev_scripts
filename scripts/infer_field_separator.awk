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
  split(cfs_str, cfs, x)
  split(cfst_str, cfst, x)
  max_rows = 500
}

NR <= max_rows { 
  for (i in cfs) {
    fs = cfs[i]
    fst = cfst[i]
    nf = split($0, _, fs)
    cfs_count[fst, NR] = nf
    cfs_total[fst] += nf
  } 
}

END {
  if (max_rows > NR) { max_rows = NR }

  # Calculate variance for each separator
  for (i in cfst) {
    fst = cfst[i]
    average_nf = cfs_total[fst] / max_rows
    
    if (average_nf < 2) { continue }

    for (i = 1; i <= max_rows; i++) {
      point_var = (cfs_count[fst, i] - average_nf)^2
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

  print winning_fs
}

# TODO: Test common patterns in a couple lines to try
# to grab unique separators

