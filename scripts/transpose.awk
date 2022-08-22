#!/usr/bin/awk
#
# Transpose the field values of a text-based field-separated file
#
# > awk -f transpose.awk file
# > command | awk -f transpose.awk

BEGIN {
    if (OFS ~ "\\[:space:\\]\\{")
        OFS = "  "
    else if (OFS ~ "\\[:space:\\]")
        OFS = " "

    if (!VAR_OFS && !(FS ~ "\[.+\]")) {
        if (FS ~ "\\\\")
            FS = Unescape(OFS)
        else
            OFS = FS
    }
}

{
    if (NF > max_nf) max_nf = NF

    for (i = 1; i <= NF; i++)
        _[i, NR] = $i
}

END {
    for (i = 1; i <= max_nf; i++) {
        for (j = 1; j < NR; j++) {
            printf "%s", _[i, j] OFS
            delete _[i, j]
        }
        printf "%s\n", _[i, j]
    }
}
