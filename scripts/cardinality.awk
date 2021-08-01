#!/usr/bin/awk
#
# Script to print the cardinality of fields in field-separated data.
#
# > awk -f cardinality.awk file

{
    for (i = 1; i <= NF; i++) {
        if (!_[i, $i]) {
            _[i, $i] = 1
            __[i]++
        }
    }

    if (NF > max_nf)
        max_nf = NF
}

END {
    for (i = 1; i <= max_nf; i++) {
        print i, __[i]
    }
}
