#!/usr/bin/awk
#
# Identify dependecies in a shell function based on namespace data

FNR == 1 { f++ }

f == 1 {
  split($0, L, "([^A-z:_]+|\\[|\\]|\\\\)")

  for (i in L) {
    e = L[i]
    if (!(e ~ filter)) next
    if (e) Deps[e] = 1 }

  next }

f == 2 { NData[$0] = 1 }

END {
  for (e in Deps) {
    if (e in NData) {
      if (calling_func)
        print calling_func, e
      else
        print e }}}
