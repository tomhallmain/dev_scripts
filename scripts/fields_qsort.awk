#!/usr/bin/awk
#
# Quicksort by a given field order
# Adapted from http://www.netlib.org/research/awkbookcode/ch7
#
# Example sorting with custom FS on field 3 then 2 in descending order:
# > awk -F||| -f fields_qsort.awk -v k=3,2 -v order=d file
#
# TODO: Multikey numeric sort

BEGIN {
  if (k)
    split(k, keys, /[[:punct:]]+/)
  else
    keys[1] = 0

  n_keys = length(keys)
  if (!order) order = "a"
}

{
  _[NR] = $0

  for (i = 1; i <= n_keys; i++) {
    kf = keys[i]
    if (i == 1) { sort_key = $kf }
    else { sort_key = sort_key FS $kf }
  }

  A[NR] = sort_key
}

END {
  if (order == "d" || order == "desc")
    QsortDesc(A, 1, NR)
  else
    QsortAsc(A, 1, NR)

  for (i = 1; i <= NR; i++)
    print _[i]
}

function QsortAsc(A,left,right,    i,last) {
  if (left >= right) return

  Swap(A, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++)
    if (A[i] < A[left])
      Swap(A, ++last, i)

  Swap(A, left, last)
  QsortAsc(A, left, last-1)
  QsortAsc(A, last+1, right)
}

function QsortDesc(A,left,right,    i,last) {
  if (left >= right) return

  Swap(A, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++)
    if (A[i] > A[left])
      Swap(A, ++last, i)

  Swap(A, left, last)
  QsortDesc(A, left, last-1)
  QsortDesc(A, last+1, right)
}

function Swap(A,i,j,t) {
  t = A[i]; A[i] = A[j]; A[j] = t
  t = _[i]; _[i] = _[j]; _[j] = t
}
