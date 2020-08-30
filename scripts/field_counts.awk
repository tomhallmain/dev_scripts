#!/usr/bin/awk
#
# Count and list occurrences of values for a field or combination of fields in
# a data file or stream
#
# > awk -f field_counts.awk file

BEGIN {
  split(fields, Fields, "[ ,\|\:\;\.\_]+")
  len_f = length(Fields)
}

len_f {
  key = $Fields[1]
  for (i = 2; i <= len_f; i++) {
    key = key OFS $Fields[i]}
  _[key]++
  next
}

{ _[$0]++ }

END { 
  for (i in _)
    if (_[i] > min)
      print _[i], i }
