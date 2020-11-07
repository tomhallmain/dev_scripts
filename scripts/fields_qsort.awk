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
    split(k, Keys, /[[:punct:]]+/)
  else
    Keys[1] = 0

  if (type && "numeric" ~ "^"type) {
    n = 1
    n_re = "^ *\$? ?([0-9]{,3},)*[0-9]+\.?[0-9]*" }
  n_keys = length(Keys)
  if (order && "desc" ~ "^"order)
    desc = 1
  else
    asc = 1
}

{
  _[NR] = $0

  for (i = 1; i <= n_keys; i++) {
    kf = Keys[i]
    if (kf == "NF") kf = NF
    if (i == 1) { sort_key = $kf }
    else { sort_key = sort_key FS $kf }
  }

  A[NR] = sort_key
}

END {
  if (n) {
    if (desc)
      QSDN(A, 1, NR)
    else
      QSAN(A, 1, NR) }
  else {
    if (desc)
      QSD(A, 1, NR)
    else
      QSA(A, 1, NR) }

  for (i = 1; i <= NR; i++)
    print _[i]
}

function QSA(A,left,right,    i,last) {
  if (left >= right) return

  S(A, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++)
    if (A[i] < A[left])
      S(A, ++last, i)

  S(A, left, last)
  QSA(A, left, last-1)
  QSA(A, last+1, right)
}

function QSD(A,left,right,    i,last) {
  if (left >= right) return

  S(A, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++)
    if (A[i] > A[left])
      S(A, ++last, i)

  S(A, left, last)
  QSD(A, left, last-1)
  QSD(A, last+1, right)
}

function QSAN(A,left,right,    i,last) {
  if (left >= right) return

  S(A, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++) {
    if (GetN(A[i]) < GetN(A[left]))
      S(A, ++last, i)
    else if (GetN(A[i]) == GetN(A[left]) && Ext[A[i]] && NExt[A[i]] < NExt[A[left]])
      S(A, ++last, i) }

  S(A, left, last)
  QSAN(A, left, last-1)
  QSAN(A, last+1, right)
}

function QSDN(A,left,right,    i,last) {
  if (left >= right) return

  S(A, left, left + int((right-left+1)*rand()))
  last = left

  for (i = left+1; i <= right; i++) {
    if (GetN(A[i]) > GetN(A[left]))
      S(A, ++last, i)
    else if (GetN(A[i]) == GetN(A[left]) && Ext[A[i]] && NExt[A[i]] < NExt[A[left]])
      S(A, ++last, i) }

  S(A, left, last)
  QSDN(A, left, last-1)
  QSDN(A, last+1, right)
}

function S(A,i,j,t) {
  t = A[i]; A[i] = A[j]; A[j] = t
  t = _[i]; _[i] = _[j]; _[j] = t
}

function GetN(str) {
  if (NS[str])
    return NS[str]
  else if (match(str, n_re)) {
    ext = 0; n_end = RSTART + RLENGTH
    n_str = substr(str, RSTART, n_end)
    if (n_str != str) ext = 1
    gsub(/[^0-9\.]+/, "", n_str)
    gsub(/^0*/, "", n_str)
    if (ext) {
      NExt[str] = substr(str, n_end+1, length(str))
      n_str = n_str + 0.000000000001 }
    NS[str] = n_str
    return n_str }
  else
    return str
}
