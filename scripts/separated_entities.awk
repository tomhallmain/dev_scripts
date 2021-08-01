#!/usr/bin/awk
#
# Script to return a population of text entities from a text file
# separated by a given separator pattern
#
# > awk -f separated_entities.awk file

BEGIN {
    if (!min) min = 0
    if (!sep) FS = "[[:space:]]+"
    else FS = sep
}

{
    for (i = 1; i <= NF; i++)
    _[$i]++
}

END {
    for (i in _)
    if (_[i] > min) print _[i], i
}
