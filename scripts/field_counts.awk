#!/usr/bin/awk
#
# Count and list occurrences of values for a field or combination of fields in
# a data file or stream
#
# > awk -f field_counts.awk -v fields=1,2,3 file

BEGIN {
    if (fields) {
        if (fields ~ "[A-z]+")
            Fields[1] = 0
        else
            split(fields, Fields, "[ ,\|\:\;\.\_]+")
    }
    else Fields[1] = 1

    len_f = length(Fields)
    fs = "\|\|\|"
    fsre = "\\|\\|\\|"
}

{
    key = $Fields[1]
  
    for (i = 2; i <= len_f; i++)
        key = key fs $Fields[i]
  
    _[key]++
    next
}

{
    _[$0]++
}

END { 
    for (i in _) {
        if (_[i] > min) {
            printf "%s", _[i] OFS
      
            if (!Fields[1])
                print i
            else {
                split(i, Vals, fsre)
                for (j = 1; j < len_f; j++)
                    printf "%s", Vals[j] OFS
                print Vals[len_f]
            }
        }
    }
}
