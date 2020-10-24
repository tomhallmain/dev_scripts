#!/usr/bin/awk
# DS:FIT
# 
# NAME
#       ds:fit, fit_columns.awk
#
# SYNOPSIS
#       ds:fit [-h|--help|file] [awkargs]
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
## TODO: 'Apply to rows / ignore rows' logic
## TODO: Resolve lossy multibyte char output
## TODO: Fit newlines in fields
## TODO: Fix rounding in some cases (see test reo output fit)

BEGIN {
  WCW_FS = " "
  FIT_FS = FS

  if (d < 0) {
    sn = -d
    d = "z" }
  
  sn0_len = 1 + 4 # e.g. 0e+00
  
  if (sn && d) {
    if (d == "z")
      sn_len = sn0_len
    else
      sn_len = 2 + d + 4 } # e.g. 0.00e+00

  if (!buffer) buffer = 2

  if (!(color == "never")) {
    hl = "\033[1;93m"
    orange = "\033[38;2;255;165;1m"
    red = "\033[1;31m"
    no_color = "\033[0m" }

  # TODO: Support more complex color defs like orange above
  color_re = "\x1b\[((0|1);)?(3|4)?[0-7](;(0|1))?m"
  trailing_color_re = "[^^]\x1b\[((0|1);)?(3|4)?[0-7](;(0|1))?m"
  decimal_re = "^[[:space:]]*$?-?$?[0-9]+[\.][0-9]+[[:space:]]*$"
  num_re = "^[[:space:]]*$?-?$?[0-9]+([\.][0-9]*)?[[:space:]]*$"
  null_re = "^\<?NULL\>?$"

  if (!tty_size)
    "tput cols" | getline tty_size; tty_size += 0
}

NR == FNR { # First pass, gather field info
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
    
    if (NSet[i] && !DSet[i] && !NOverset[i] && !(f ~ num_re) && !(f ~ null_re) && len > 0) {
      NOverset[i] = 1
      if (debug) DebugPrint(8)
      if (SaveNMax[i] > FMax[i] && SaveNMax[i] > SaveSMax[i]) {
        recap_n_diff = Max(SaveNMax[i] - FMax[i], 0)
        FMax[i] += recap_n_diff
        total_f_len += recap_n_diff }}

    if (FNR < 30 && f ~ num_re) {
      if (debug && !NSet[i]) DebugPrint(7)
      NSet[i] = 1
      if (len > NMax[i]) NMax[i] = len }

    if (!dec_off && !DSet[i] && f ~ decimal_re) {
      DSet[i] = 1
      split(f, NParts, "\.")
      sub("0*$", "", NParts[2]) # Remove trailing zeros in decimal part
      d_len = length(NParts[2])
      DMax[i] = d_len

      if (sn) {
        if (!d) sn_len = 2 + d_len + 4
        sn_diff = sn_len - orig_max
        f_diff = Max(sn_diff, 0) }
      else {
        gsub("[^0-9]", "", NParts[i])
        int_len = length(int(NParts[1]))
        int_diff = int_len + 1 + d_len - len
        if (d == "z") {
          d_len++ # Removing dot
          d_diff = -1 * d_len }
        else {
          d_diff = (d ? d - d_len : 0) }

        f_diff = Max(l_diff + int_diff + d_diff, 0) }

      if (debug && f_diff) DebugPrint(2) }

    else if (!dec_off && DSet[i] && f ~ num_re) {
        split(f, NParts, "\.")
        sub("0*$", "", NParts[2]) # Remove trailing zeros in decimal part
        d_len = length(NParts[2])
        if (d_len > DMax[i]) {
          dmax_diff = d_len - DMax[i]
          DMax[i] = d_len }

        if (sn) {
          if (!d) sn_len = 2 + DMax[i] + 4
          sn_diff = sn_len - orig_max
          f_diff = Max(sn_diff, 0) }
        else {
          gsub("[^0-9]", "", NParts[1])
          int_len = length(int(NParts[1]))
          dot = (d_len == 0 ? 0 : 1)
          int_diff = int_len + dot + d_len - len

          if (d == "z") {
            d_len + dot 
            d_diff = -1 * d_len
            f_diff = Max(l_diff + int_diff + d_diff, 0) }
          else {
            dot = (!dot)
            dec = (d ? d : DMax[i])
            if (l_diff + dec + dot > 0) {
              d_diff = dec - d_len + dot
              f_diff = Max(l_diff + int_diff + d_diff + dmax_diff, 0) }}}

      if (debug && f_diff) DebugPrint(3) }

    else if (l_diff > 0) {
      if (sn && NSet[i] && ! NOverset[i] && NMax[i] > sn0_len && f ~ num_re) {
        if (len > SaveNMax[i]) SaveNMax[i] = len
        sn_diff = sn0_len - orig_max
        
        l_diff = sn_diff }
      if (sn && (f ~ num_re) == 0) if (len > SaveSMax[i]) save_s_max[i] = len

      f_diff = l_diff

      if (debug) DebugPrint(1) }

    if (f_diff) { FMax[i] += f_diff; total_f_len += f_diff }}

  if (NF > max_nf) max_nf = NF
}

NR > FNR { # Second pass, scale down fields if length > tty_size and print
  if (FNR == 1) {
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
      if (!(color == "never")) PrintWarning()

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

        reduction_scaler-- }}}

  for (i = 1; i <= max_nf; i++) {
    not_last_f = i < max_nf;
    if (FMax[i]) {
      if (DSet[i] || (NSet[i] && ! NOverset[i])) {
        
        if ($i ~ num_re) {
          if (DSet[i]) {
            if (d == "z") {
              type_str = (sn ? ".0e" : "s")
              value = int($i) }
            else {
              dec = (d ? d : DMax[i])
              type_str = (sn ? "." dec "e" : "." dec "f")
              value = $i }}
          else {
            type_str = (sn ? ".0e" : "s")
            value = $i }}
        else { type_str = "s"; value = $i }

        #if (not_last_f)
        print_len = FMax[i] + COLOR_DIFF[FNR, I] + WCWIDTH_DIFF[FNR, i]
        #else print_len = length(value)

        justify_str = "%" # Right-align
        fmt_str = justify_str print_len type_str

        printf fmt_str, value
        if (not_last_f) PrintBuffer(buffer)
      }
      else {
        if (ShrinkF[i]) {
          color = hl; color_off = no_color
          value = CutStringByVisibleLen($i, MaxFLen[i] + WCWIDTH_DIFF[FNR, i]) }
        else {
          color = ""; color_off = ""
          value = $i }

        if (not_last_f)
          print_len = MaxFLen[i] + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]
        else
          print_len = length(value) + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]

        justify_str = "%-" # Left-align
        fmt_str = color justify_str print_len "s" color_off

        printf fmt_str, value
        if (not_last_f) PrintBuffer(buffer)
      }}
    if (debug && FNR < 4) DebugPrint(6) }

  print ""
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
          if (FNR==15 && i == 1) print p, "PCUR:" p_cur, "ADD:" add, "REMSTR" rem_str
      red_str = red_str add next_color
      red_str_len += length(add) }}
  else {
    red_str = substr(str, 1, red_len) }

  return red_str
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
    if (!title_printed) { title_printed=1
      printf "%-20s%5s%5s%5s%5s%5s%5s\n", "", "FNR", "i", "len", "ogmx", "fmxi", "ldf" }
    printf "%-20s%5s%5s%5s%5s%5s%5s", "max change: ", FNR, i, len, orig_max, FMax[i], l_diff }
  else if (case == 2)
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s", "decimal setting: ", FNR, i, d, d_len, d_len,  orig_max, len, int_diff, d_diff, l_diff, f_diff
  else if (case == 3)
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s", "decimal adjustment: ", FNR, i, d, d_len, DMax[i],  orig_max, len, int_diff, d_diff, l_diff, f_diff
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
