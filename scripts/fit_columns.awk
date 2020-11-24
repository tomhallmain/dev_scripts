#!/usr/bin/awk
# DS:FIT
# 
# NAME
#       ds:fit, fit_columns.awk
#
# SYNOPSIS
#       ds:fit [-h|--help|file] [prefield=t] [awkargs]
#
# DESCRIPTION
#       fit_columns.awk is a sript to fit a table of values with dynamic column 
#       lengths. If running with AWK, data must be passed twice.
#
#       Running on a single file:
#    > awk -f fit_columns.awk file{,}
#
#       ds:fit is the caller function for the fit_columns.awk script. To run with 
#       any of the overrides below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#    $ data_in | ds:fit [awkargs]
#
#       When running with ds:fit, an attempt will be made to infer a field separator 
#       of up to three characters. If none is found, FS will be set to default value,
#       a single space = " ". To override the FS, add as a trailing awkarg. Be sure 
#       to escape and quote if needed. AWK's extended regex can be used as FS:
#
#    $ ds:fit datafile -v FS=" {2,}"
#
#       When running ds:fit, an attempt is made to extract relevant instances of field
#       separators in the case that a field separator appears in field values. This is 
#       currently a persistent setting.
#
#       ds:fit will also attempt to detect whether AWK is multibyte safe to handle 
#       cases of multibyte characters with a width that does not match its awk length.
#       If a limited version of AWK is installed, the fit for multibyte characters 
#       such as emoji may be incorrect.
#
# FUNCTIONS
#    -h Print help
#
#       Run with custom buffer (default is 1):
#    -v buffer=5
#
#       Run with custom decimal setting (default is the max for column value):
#    -v d=4
#
#       Run with custom decimal setting of zero (why? awk coerces 0 to false):
#    -v d=z
#
#       Run with no color or warning:
#    -v color=never
#
#       Run without decimal transformations:
#    -v dec_off=1
#
#       Run with scientific notation on decimal/number-valued fields:
#    -v d=-1
#
#       Custom character for buffer/separator:
#    -v bufferchar="|"
#
#       Do not fit, but still fit rows matching pattern:
#    -v nofit=pattern
#
#       Fit only rows matching pattern, print rest normally:
#    -v onlyfit=pattern
#
#       Start fit at pattern, end fit at pattern:
#    -v startfit=startpattern
#    -v endfit=endpattern
#
#       Start fit at row number, end fit at row number:
#    -v startrow=100
#    -v endrow=200
## TODO: Resolve lossy multibyte char output
## TODO: Fit newlines in fields
## TODO: Fix rounding in some cases (see test reo output fit)
## TODO: Pagination
## TODO: dec_off > no_tf_num
## TODO: Variant float output for normal sized nums
## TODO: SetType function checking field against relevant re one time at start

BEGIN {
  WCW_FS = " "
  FIT_FS = FS
  partial_fit = nofit || onlyfit || startfit || endfit || startrow || endrow
  prefield = FS == "@@@"

  if (d != "z" && !(d ~ /-?[0-9]+/)) {
    d = 0 }
  else if (d < 0) {
    sn = -d
    d = "z" }
  
  if (d)
    fix_dec = d == "z" ? 0 : d

  sn0_len = 1 + 4 # e.g. 0e+00
  
  if (sn && d) {
    if (d == "z")
      sn_len = sn0_len
    else
      sn_len = 2 + d + 4 } # e.g. 0.00e+00

  if (!buffer) buffer = 2
  if (!(color == "never")) {
    color_on = 1; color_pending = 1 }

  if (!(color == "never")) {
    hl = "\033[1;93m"
    white = "\033[1:37m"
    orange = "\033[38;2;255;165;1m"
    red = "\033[1;31m"
    no_color = "\033[0m" }

  # TODO: Support more complex color defs like orange above
  color_re = "\x1b\[((0|1);)?(3|4)?[0-7](;(0|1))?m"
  trailing_color_re = "[^^]\x1b\[((0|1);)?(3|4)?[0-7](;(0|1))?m"
  null_re = "^\<?NULL\>?$"
  int_re = "^[[:space:]]*-?\\$?[0-9]+[[:space:]]*$"
  num_re = "^[[:space:]]*\\$?-?\\$?[0-9]*\\.?[0-9]+[[:space:]]*$"
  decimal_re = "^[[:space:]]*\\$?-?\\$?[0-9]*\\.[0-9]+[[:space:]]*$"
  float_re = "^[[:space:]]*-?[0-9]\.[0-9]+(E|e)(\\+|-)?[0-9]+[[:space:]]*$"

  if (!tty_size)
    "tput cols" | getline tty_size; tty_size += 0
}

FNR < 2 && NR > FNR { # Reconcile lengths with term width after first pass
  for (i = 1; i <= max_nf; i++) {
    if (FMax[i]) {
      MaxFLen[i] = FMax[i]
      total_f_len += buffer

      if (FMax[i] / total_f_len > 0.4 ) { 
        GMax[i] = FMax[i] + buffer
        g_max_len += GMax[i]
        g_count++ }}}

  shrink = tty_size && total_f_len > tty_size

  if (shrink) {
    if (color_on) PrintWarning()

    if (length(GMax)) {
      while (g_max_len / total_f_len / length(GMax) > Min(length(GMax) / max_nf * 2, 1) \
              && total_f_len > tty_size) {
        for (i in GMax) {
          cut_len = int(FMax[i]/30)
          FMax[i] -= cut_len
          total_f_len -= cut_len
          g_max_len -= cut_len
          ShrinkF[i] = 1
          MaxFLen[i] = FMax[i]
          if (debug) DebugPrint(9) }}}

    reduction_scaler = 14
    
    while (total_f_len > tty_size && reduction_scaler > 0) {
      avg_f_len = total_f_len / max_nf
      cut_len = int(avg_f_len/10)
      scaled_cut = cut_len * reduction_scaler
      if (debug) DebugPrint(4)
      
      for (i = 1; i <= max_nf; i++) {
        if (! DSet[i] \
            && ! (NSet[i] && ! NOverset[i]) \
            && FMax[i] > scaled_cut \
            && FMax[i] - cut_len > buffer) {
          mod_cut_len = int((cut_len*2) ^ (FMax[i] / total_f_len))
          FMax[i] -= cut_len
          total_f_len -= cut_len
          ShrinkF[i] = 1
          MaxFLen[i] = FMax[i]
          if (debug) DebugPrint(5) }}

      reduction_scaler-- }}
}

partial_fit {
  if (FNR < 2) {
    fit_complete = 0
    in_fit = 0 }
  if (in_fit) {
    if ((endfit && $0 ~ endfit) \
      || (endrow && FNR == endrow)) {
      in_fit = 0
      fit_complete = 1 }}
  else {
    if (fit_complete \
      || (nofit && $0 ~ nofit) \
      || (onlyfit && !($0 ~ onlyfit)) \
      || (startrow && FNR < startrow) \
      || (startfit && !($0 ~ startfit))) {
      if (NR == FNR)
        next
      else {
        if (prefield) gsub(FS, OFS) # Need to add to prefield too to ensure this isn't lossy
        print; next }}
    else if ((startfit && $0 ~ startfit) \
      || (startrow && FNR == startrow) \
      || (!startfit && endfit) \
      || (!startrow && endrow))
      in_fit = 1 }
}

NR == FNR { # First pass, gather field info
  fitrows++
  for (i = 1; i <= NF; i++) {
    init_f = $i
    init_len = length(init_f)
    if (init_len < 1) continue

    f_ntc = StripTrailingColors(init_f)
    len_ntc = length(f_ntc)
    tc_diff = init_len - len_ntc
    if (tc_diff > 0) {
      color_detected = 1
      COLOR_DIFF[NR, i] = tc_diff }

    f = StripColors(init_f)
    len = length(f)
    if (len < 1) continue

    orig_max = FMax[i]
    l_diff = len - orig_max
    d_diff = 0
    dmax_diff = 0
    f_diff = 0

    if (awksafe && f != 0) {
      FS = WCW_FS
      wcw = wcscolumns(f)
      FS = FIT_FS
      wcw_diff = len - wcw
      if (wcw_diff == 0) {
        f_wcw_kludge = StripBasicASCII(f)
        len_wcw_kludge = length(f_wcw_kludge)
        wcw_diff += len_wcw_kludge }
      if (wcw_diff) {
        WCWIDTH_DIFF[NR, i] = wcw_diff
        if (debug) DebugPrint(10) }}

    # If column unconfirmed as decimal and the current field is decimal
    # set decimal for column and handle field length changes

    # Else if column confirmed as decimal and current field is decimal
    # handle field length adjustments

    # Otherwise just handle simple field length increases and store number
    # columns for later justification

    if (len > 0 && NSet[i] && !DSet[i] && !NOverset[i] && !AnyFmtNum(f) && !(f ~ null_re)) {
      NOverset[i] = 1
      if (debug) DebugPrint(8)
      if (SaveNMax[i] > FMax[i] && SaveNMax[i] > SaveSMax[i]) {
        recap_n_diff = Max(SaveNMax[i] - FMax[i], 0)
        FMax[i] += recap_n_diff
        total_f_len += recap_n_diff }}

    if (f ~ num_re) {
      if (fitrows < 30) {
        if (debug && !NSet[i]) DebugPrint(7)
        NSet[i] = 1 }
      if (NSet[i] && !NOverset[i]) {
        if (f ~ int_re) {
          if (len > IMax[i]) IMax[i] = len
          if (!DSet[i] && len > DecPush[i] && f ~ /^(\$|-)/) {
            DecPush[i] = len }}
        if (f ~ /^0+[1-9]/) {
          f = sprintf("%f", f)
          if (f ~ /\.[0-9]+0+/)
            sub(/0*$/, "", f) # Remove trailing zeros in decimal part
          len = length(f); l_diff = len - orig_max }
        if (len > NMax[i]) NMax[i] = len }}

    if (NSet[i] && !NOverset[i] && !LargeVals[i] && (f+0 > 9999)) LargeVals[i] = 1

    if (!dec_off && !DSet[i] && ComplexFmtNum(f)) {
      DSet[i] = 1
      float = f ~ float_re
      tval = TruncVal(f, 0, LargeVals[i])
      if (tval ~ /\.[0-9]+0+/)
        sub(/0*$/, "", tval) # Remove trailing zeros in decimal part
      sub(/\.0*$/, "", tval) # Remove decimal part if equal to zero
      t_len = length(tval)
      t_diff = 0
      l_diff = t_len - orig_max
      split(tval, NParts, /\./)
      d_len = length(NParts[2])
      DMax[i] = d_len
      apply_decimal = (d != "z" && (d || DMax[i]))

      if (sn) {
        if (!d) sn_len = 2 + d_len + 4
        sn_diff = sn_len - orig_max
        f_diff = Max(sn_diff, 0) }
      else {
        gsub(/[^0-9\-]/, "", NParts[1])
        int_len = length(NParts[1])
        if (int_len > 4) LargeVals[i] = 1

        if (DecPush[i] && !(NParts[1] ~ /^($|-)/)) {
          int_len = Max(DecPush[i] + apply_decimal, int_len)
          dec_push = 1
          delete DecPush[i] }
        if (int_len > NMax[i]) NMax[i] = int_len
        int_diff = int_len - t_len

        if (int_len > IMax[i])
          IMax[i] = int_len
        else
          int_diff += IMax[i] - int_len

        if (l_diff > 0) {
          if (apply_decimal) {
            dot = (fix_dec || d_len ? 1 : 0)
            dec = (float || !d_len ? dot : 0)
            d_diff = dec + (d ? fix_dec : d_len) }

          f_diff = Max(l_diff + int_diff + d_diff - t_diff, 0) }}

      if (debug) DebugPrint(2) }

    else if (!dec_off && DSet[i] && AnyFmtNum(f)) {
        float = f ~ float_re
        tval = TruncVal(f, 0, LargeVals[i])
        if (tval ~ /\.[0-9]+0+/)
          sub(/0*$/, "", tval) # Remove trailing zeros in decimal part
        sub(/\.0*$/, "", tval) # Remove decimal part if equal to zero
        t_len = length(tval)
        t_diff = float ? 0 : Max(len - t_len, 0)
        l_diff = t_len - orig_max
        split(tval, NParts, /\./)
        d_len = length(NParts[2])
        if (d_len > DMax[i]) {
          dmax_diff = float ? d_len - DMax[i] : 0
          DMax[i] = d_len }
        apply_decimal = (d != "z" && (d || DMax[i]))

        if (sn) {
          if (!d) sn_len = 2 + DMax[i] + 4
          sn_diff = sn_len - orig_max
          f_diff = Max(sn_diff, 0) }
        else {
          gsub(/[^0-9\-]/, "", NParts[1])
          int_len = length(int(NParts[1]))
          if (int_len > 4) LargeVals[i] = 1

          if (orig_max) {
            if (DecPush[i] && !(NParts[1] ~ /^($|-)/)) {
              int_len = Max(DecPush[i], int_len)
              dec_push = 1
              delete DecPush[i] }
            if (int_len > NMax[i]) NMax[i] = int_len
            int_diff = len - t_len

            if (int_len > IMax[i])
              IMax[i] = int_len
            else if (!float)
              int_diff += IMax[i] - int_len

            if (apply_decimal) {
              dot = (fix_dec || d_len ? 1 : 0)
              dec = (d ? fix_dec : DMax[i])
              d_diff = (float || !d_len ? dot : 0) + dec - d_len
              f_diff = Max(l_diff + int_diff + d_diff + dmax_diff - t_diff, 0) }
            else {
              f_diff = Max(l_diff + int_diff + d_diff + dmax_diff - t_diff, 0) }}

          else {
            if (int_len > NMax[i]) NMax[i] = int_len
            f_diff = l_diff }}

      if (debug && f_diff) DebugPrint(3) }

    else if (l_diff > 0) {
      if (NSet[i] && !NOverset[i] && f ~ num_re) {
        if (len > SaveNMax[i]) {
          SaveNMax[i] = len }
        if (sn && NMax[i] > sn0_len) {
          sn_diff = sn0_len - orig_max
          l_diff = sn_diff }}

      if (sn && !(f ~ num_re))
        if (len > SaveSMax[i]) SaveSMax[i] = len

      f_diff = l_diff

      if (debug) DebugPrint(1) }

    if (f_diff) { FMax[i] += f_diff; total_f_len += f_diff }}

  if (NF > max_nf) max_nf = NF
}

NR > FNR { # Second pass, print formatted if applicable
  for (i = 1; i <= max_nf; i++) {
    not_last_f = i < max_nf;
    if (FMax[i]) {
      if (DSet[i] || (NSet[i] && ! NOverset[i])) {
        
        if (AnyFmtNum($i)) {
          if (DSet[i]) {
            if (d == "z") {
              type_str = (sn ? ".0e" : "s")
              value = int($i) }
            else {
              dec = (d ? fix_dec : DMax[i])
              type_str = (sn ? "." dec "e" : "." dec "f")
              value = TruncVal($i, dec, LargeVals[i]) }}
          else {
            type_str = (sn ? ".0e" : "s")
            value = $i }}
        else { type_str = "s"; value = $i }

        #if (not_last_f)
        print_len = FMax[i] + COLOR_DIFF[FNR, I] + WCWIDTH_DIFF[FNR, i]
        #else print_len = length(value)

        justify_str = "%" # Right-align
        fmt_str = justify_str print_len type_str

        if (color_on && color_pending) fmt_str = white fmt_str no_color

        printf fmt_str, value
        if (not_last_f) PrintBuffer(buffer)
      }
      else {
        if (ShrinkF[i]) {
          if (color_on) {
            a_color = hl; color_off = no_color }
          value = CutStringByVisibleLen($i, MaxFLen[i] + WCWIDTH_DIFF[FNR, i]) }
        else {
          if (color_on) {
            a_color = color_pending ? white : ""
            color_off = color_pending ? no_color : "" }
          value = $i }

        if (not_last_f)
          print_len = MaxFLen[i] + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]
        else
          print_len = length(value) + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]

        justify_str = "%-" # Left-align
        fmt_str = a_color justify_str print_len "s" color_off

        printf fmt_str, value
        if (not_last_f) PrintBuffer(buffer)
      }}
    if (debug && FNR < 2) DebugPrint(6) }

  print ""

  if (color_pending) color_pending = 0
}


function StripTrailingColors(str) {
  gsub(trailing_color_re, "", str) # Remove ANSI color codes
  return str
}
function StripColors(str) {
  gsub(color_re, "", str) # Remove ANSI color codes
  return str
}
function StripBasicASCII(str) {
  # TODO: Strengthen cases where not multibyte-safe
  gsub(/[ -~ -¬®-˿Ͱ-ͷͺ-Ϳ΄-ΊΌΎ-ΡΣ-҂Ҋ-ԯԱ-Ֆՙ-՟ա-և։֊־׀׃׆א-תװ-״]+/, "", str)
  return str
}
function CutStringByVisibleLen(str, red_len) {
  if (str ~ trailing_color_re) {
    rem_str = str; red_str = ""; red_str_len = 0; next_color = ""
    split(str, PrintStr, trailing_color_re)
    p_len = length(PrintStr)
    for (p = 1; p <= p_len && red_str_len <= red_len; p++) {
      p_cur = p == 1 ? PrintStr[p] : substr(PrintStr[p], 2)
      add = substr(p_cur, 1, Max(red_len - red_str_len, 0))
      rem_str = substr(rem_str, index(rem_str, p_cur) + length(p_cur) + 1)
      next_color = p == p_len ? rem_str : substr(rem_str, 1, index(rem_str, PrintStr[p+1]))
      if (debug && FNR==15 && i == 1) print p, "PCUR:" p_cur, "ADD:" add, "REMSTR" rem_str
      red_str = red_str add next_color
      red_str_len += length(add) }}
  else {
    red_str = substr(str, 1, red_len) }

  return red_str
}
function TruncVal(val, dec, large_vals) {
  if (large_vals || (val+0 > 9999) || val ~ /-?[0-9]\.[0-9]+(E|e\+)([4-9]|[1-9][0-9]+)$/) {
    dec_f = d ? fix_dec : Max(dec, 0)
    full_f = length(int(val))
    if (dec_f) full_f += dec_f + 1
    return sprintf("%"full_f"."dec_f"f", val) }
  else if (val ~ /\.[0-9]{5,}$/) {
    dec_f = d ? fix_dec : Max(dec, 4)
    full_f = length(int(val)) + dec_f + 1
    return sprintf("%"full_f"."dec_f"f", val) }
  else {
    return sprintf("%f", val) } # Small floats flow through this logic
}
function AnyFmtNum(str) {
  return (str ~ num_re || str ~ decimal_re || str ~ float_re)
}
function ComplexFmtNum(str) {
  return (str ~ decimal_re || str ~ float_re)
}
function Max(a, b) {
  if (a > b) return a
  else if (a < b) return b
  else return a
}
function Min(a, b) {
  if (a > b) return b
  else if (a < b) return a
  else return a
}
function PrintWarning() {
  print orange "WARNING: Total max field lengths larger than display width!" no_color
  if (!color_detected) print "Columns cut printed in " hl "HIGHLIGHT" no_color
  print ""
}
function PrintBuffer(buffer) {
  space_str = bufferchar "                                                               "
  printf "%.*s", buffer, space_str
}
function DebugPrint(case) {
  # Switch statement not supported in all Awk implementations
  if (debug_col && i != debug_col) return
  if (case == 1) {
    if (!debug1_title_printed) { debug1_title_printed=1
      printf "%-20s%5s%5s%5s%5s%5s%5s\n", "", "FNR", "i", "len", "ogmx", "fmxi", "ldf" }
    printf "%-20s%5s%5s%5s%5s%5s%5s", "max change: ", FNR, i, len, orig_max, FMax[i], l_diff }
  else if (case == 2) {
    if (!debug2_title_printed) { debug2_title_printed=1
      printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s\n", "", "FNR", "i", "d", "i_ln", "d_ln", "t_ln", "nmax", "dmax", "omax", "len", "i_df", "d_df", "l_df", "t_df", "f_df", "tval" }
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s", "decimal setting: ", FNR, i, d, int_len, d_len, t_len, NMax[i], 0, orig_max, len, int_diff, d_diff, l_diff, t_diff, f_diff, tval }
  else if (case == 3) {
    if (!debug3_title_printed) { debug3_title_printed=1
      printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s\n", "", "FNR", "i", "d", "i_ln", "d_ln", "t_ln", "nmax", "dmax", "omax", "len", "i_df", "d_df", "l_df", "t_df", "f_df", "tval" }
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s %-s", "decimal adjustment: ", FNR, i, d, int_len, d_len, t_len, NMax[i], DMax[i], orig_max, len, int_diff, d_diff, l_diff, t_diff, f_diff, tval }
  else if (case == 4) {
    if (!s_title_printed) { s_title_printed=1
      printf "%-15s%5s%5s%5s%5s%5s%5s%5s\n", "", "i", "fmxi", "avfl", "mxnf", "rdsc", "tfl", "ttys" }
    printf "%-15s%15s%5s%5s%5s%5s", "shrink step: ", avg_f_len, max_nf, reduction_scaler, total_f_len, tty_size }
  else if (case == 5)
    printf "%-15s%5s%5s", "shrink field: ", i, FMax[i]
  else if (case == 6)
    { print ""; print i, fmt_str, $i, value; print "" }
  else if (case == 7)
    printf "%s %s %s", "Number pattern set for col:", NR, i
  else if (case == 8) 
    printf "%s %s %s", "Number pattern overset for col:", NR, i
  else if (case == 9) 
    printf "%s %s %s", "g_max_cut: "cut_len, "MaxFLen[i]: "MaxFLen[i], "total_f_len: "total_f_len
  else if (case == 10)
    printf "%s %s %s %s %s %s %s %s", "wcwdiff! NR: " NR, " f: "f, "i: "i, " init_len: "init_len, "len: "len, "wcw_diff: "wcw_diff, " wcw: "wcw, " f_wcw_kludge: "len_wcw_kludge

  print ""
}
