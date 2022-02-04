#!/usr/bin/awk
#
# List unique occurrences of values for a field or combination of fields in
# a data file or stream
#
# > awk -f field_uniques.awk -v fields=1,2,3 file

BEGIN {
    if (fields) {
        if (fields ~ "[A-z]+")
            Fields[1] = 0
        else
            split(fields, Fields, "[ ,\|\:\;\.\_]+")
    }
    else Fields[1] = 0

    len_f = length(Fields)
}

{
    val = $Fields[1]
  
    for (i = 2; i <= len_f; i++)
        val = val OFS $Fields[i]
  
    _[val]++
    
    if (!(val in HasPrintedVals) && _[val] > min) {
        print val
        HasPrintedVals[val] = 1
    }
}
