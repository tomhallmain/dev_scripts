# Script to infer a probable set of join fields between two data files.
#
# With a field separator common to both files (for example comma) run as:
# > awk -f infer_join_fields.awk -v fs="," file1 file2
#
# With a field separator unique to each file, run as:
# > awk -f infer_join_fields.awk -v fs1="," -v fs2 =":" file1 file2

BEGIN {
  if (fs) {
    fs1 = fs
    fs2 = fs
  } else {
    if (!fs1) fs1 = FS
    if (!fs2) fs2 = FS
  }

  FS = fs1
}

# Save first stream
NR==FNR {
  if ( header && FNR == 1 ) {
    headers1 = $0
    next
  }
  s1[$1] = 1
  ns1 = FNR
  next
}

