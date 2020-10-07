#!/usr/bin/awk
#
# Script to print a histogram in terminal based on columnar data
#
# > awk -f hist.awk file

BEGIN {
  if (!n_bins) n_bins = 10
  if (!max_bar_len) max_bar_len = 15
  for (i = 1; i <= max_bar_len; i++)
    bar = bar "+"
  decnum_re = "^[[:space:]]*(\\-)?(\\()?(\\$)?[0-9,]+([\.][0-9]*)?(\\))?[[:space:]]*$"
}

{
  for (f = 1; f <= NF; f++) {
    fval = $f
    if (!(fval ~ decnum_re)) {
      if (NR == 1) {
        gsub("[[:space:]]+", "", fval)
        gsub(",", "", fval)
        Headers[f] = fval }
      continue }

    gsub("[[:space:]]+", "", fval)
    gsub("\\(", "-", fval)
    gsub("\\)", "", fval)
    gsub("\\$", "", fval)
    gsub(",", "", fval)
    fval = fval * 1

    Rec[f]++
    Counts[f, fval]++

    if (fval < Min[f] || !Min[f]) Min[f] = fval
    else if (fval > Max[f]) Max[f] = fval }
}

END {
  for (f in Rec) {
    if (!Max[f]) continue
    if (length(Max[f]) > max_len) max_len = length(Max[f])
    if (length(Min[f]) > max_len) max_len = length(Min[f])
    BuildBins(f, Bins, Max[f], Min[f], n_bins) }

  for (c in Counts) {
    split(c, CountDesc, SUBSEP)
    f = CountDesc[1]
    val = CountDesc[2]
    split(Bins[f], FBins, ",")
    for (b = 1; b <= n_bins; b++)
      if (val <= FBins[b]) {
        Bin[f, b]++
        if (Bin[f, b] > MaxBin[f]) MaxBin[f] = Bin[f, b]
        break }}

  edges_len = max_len * 2 + 6
  PrintBins(Rec, Bin, Bins, MaxBin, Min, n_bins, bar)
}

function BuildBins(f, Bins, max, min, n_bins) {
  bin_size = (max - min) / n_bins
  for (b = 1; b <= n_bins; b++) {
    bin_edge = min + b * bin_size
    Bins[f] = Bins[f] bin_edge"," }
}

function PrintBins(Rec, Bin, Bins, MaxBin, Min, n_bins, bar) {
  for (f in Rec) {
    if (!Bins[f]) continue
    print "Hist: field "f" ("Headers[f]"), cardinality "Rec[f]
    split(Bins[f], FBins, ",")
    len_mod = (MaxBin[f] > max_bar_len && MaxBin[f] != 0) ? max_bar_len / MaxBin[f] : 1
    for (b = 1; b <= n_bins; b++) {
      starting_edge = b == 1 ? Min[f] : FBins[b-1]
      printf "%"edges_len"s ", starting_edge"-"FBins[b]
      printf "%.*s\n", Bin[f, b] * len_mod, bar }
    print "" }
}
