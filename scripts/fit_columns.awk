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
#       fit_columns.awk is a sript to print a table of values with dynamic column 
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
#    $ ds:fit datafile a 1,4 -v FS=" {2,}"
#
#       When running ds:reo, an attempt is made to extract relevant instances of field
#       separators in the case that a field separator appears in field values. This is 
#       currently a persistent setting.
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


BEGIN {
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

    orig_max = f_max[i]
    l_diff = len - orig_max
    d_diff = 0
    f_diff = 0

    f_wcw = StripStandardASCII(f)
    wcw_diff = length(f_wcw)
    if (wcw_diff) {
      WCWIDTH_DIFF[NR, i] = wcw_diff
      if (debug) DebugPrint(10) }

    # If column unconfirmed as decimal and the current field is decimal
    # set decimal for column and handle field length changes

    # Else if column confirmed as decimal and current field is decimal
    # handle field length adjustments

    # Otherwise just handle simple field length increases and store number
    # columns for later justification
    
    if (n_set[i] && ! d_set[i] && ! n_overset[i] && ($i ~ num_re) == 0 && len > 0) {
      n_overset[i] = 1
      if (debug) DebugPrint(8)
      if (save_n_max[i] > f_max[i] && save_n_max[i] > save_s_max[i]) {
        recap_n_diff = Max(save_n_max[i] - f_max[i], 0)
        f_max[i] += recap_n_diff
        total_f_len += recap_n_diff }}

    if (FNR < 30 && f ~ num_re) {
      n_set[i] = 1
      if (len > n_max[i]) n_max[i] = len
      if (debug) DebugPrint(7) }

    if (!dec_off && !d_set[i] && $i ~ decimal_re) {
      d_set[i] = 1
      split(f, n_parts, "\.")
      sub("0*$", "", n_parts[2]) # Remove trailing zeros in decimal part
      d_len = length(n_parts[2])
      d_max[i] = d_len

      if (sn) {
        if (!d) sn_len = 2 + d_len + 4
        sn_diff = sn_len - orig_max
        f_diff = Max(sn_diff, 0) }
      else {
        int_len = length(int(n_parts[1]))
        int_diff = int_len + 1 + d_len - len
        if (d == "z") {
          d_len++ # Removing dot
          d_diff = -1 * d_len }
        else {
          d_diff = (d ? d - d_len : 0) }

        f_diff = Max(l_diff + int_diff + d_diff, 0) }

      if (debug && f_diff) debug_print(2) }

    else if (!dec_off && d_set[i] && f ~ num_re) {
        split(f, n_parts, "\.")
        sub("0*$", "", n_parts[2]) # Remove trailing zeros in decimal part
        d_len = length(n_parts[2])
        if (d_len > d_max[i]) d_max[i] = d_len
        
        if (sn) {
          if (!d) sn_len = 2 + d_max[i] + 4
          sn_diff = sn_len - orig_max
          f_diff = Max(sn_diff, 0) }
        else {
          int_len = length(int(n_parts[1]))
          dot = (d_len == 0 ? 0 : 1)
          int_diff = int_len + dot + d_len - len
  
        if (d == "z") {
          d_len + dot 
          d_diff = -1 * d_len
          f_diff = Max(l_diff + int_diff + d_diff, 0) }
        else {
          dot = (!dot)
          dec = (d ? d : d_max[i])
          if (l_diff + dec + dot > 0) {
            d_diff = dec - d_len + dot
            f_diff = Max(l_diff + int_diff + d_diff, 0) }}}

      if (debug && f_diff) DebugPrint(3) }

    else if (l_diff > 0) {
      if (sn && n_set[i] && ! n_overset[i] && n_max[i] > sn0_len && f ~ num_re) {
        if (len > save_n_max[i]) save_n_max[i] = len
        sn_diff = sn0_len - orig_max
        
        l_diff = sn_diff }
      if (sn && (f ~ num_re) == 0) if (len > save_s_max[i]) save_s_max[i] = len

      f_diff = l_diff

      if (debug) DebugPrint(1) }

    if (f_diff) { f_max[i] += f_diff; total_f_len += f_diff }}

  if (NF > max_nf) max_nf = NF
}

NR > FNR { # Second pass, scale down fields if length > tty_size and print
  if (FNR == 1) {
    for (i = 1; i <= max_nf; i++) {
      if (f_max[i]) {
        max_f_len[i] = f_max[i]
        total_f_len += buffer

        if (f_max[i] / total_f_len > 0.4 ) { 
          g_max[i] = f_max[i] + buffer
          g_max_len += g_max[i]
          g_count++ }}}

    shrink = tty_size && total_f_len > tty_size

    if (shrink) {
      if (!(color == "never")) PrintWarning()

      while (g_max_len / total_f_len / length(g_max) > Min(length(g_max) / max_nf * 2, 1) \
              && total_f_len > tty_size) {
        for (i in g_max) {
          cut_len = int(f_max[i]/30)
          f_max[i] -= cut_len
          total_f_len -= cut_len
          g_max_len -= cut_len
          shrink_f[i] = 1
          max_f_len[i] = f_max[i]
          if (debug) DebugPrint(9) }
      }

      reduction_scaler = 14
      
      while (total_f_len > tty_size && reduction_scaler > 0) {
        avg_f_len = total_f_len / max_nf
        cut_len = int(avg_f_len/10)
        scaled_cut = cut_len * reduction_scaler
        if (debug) DebugPrint(4)
        
        for (i = 1; i <= max_nf; i++) {
          if (! d_set[i] \
              && ! (n_set[i] && ! n_overset[i]) \
              && f_max[i] > scaled_cut \
              && f_max[i] - cut_len > buffer) {
            mod_cut_len = int((cut_len*2) ^ (f_max[i] / total_f_len))
            f_max[i] -= cut_len
            total_f_len -= cut_len
            shrink_f[i] = 1
            max_f_len[i] = f_max[i]
            if (debug) DebugPrint(5) }}

        reduction_scaler-- }}}

  for (i = 1; i <= max_nf; i++) {
    not_last_f = i < max_nf;
    if (f_max[i]) {
      if (d_set[i] || (n_set[i] && ! n_overset[i])) {
        
        if (d_set[i]) {
          if ($i ~ num_re) {
            if (d == "z") {
              type_str = (sn ? ".0e" : "s")
              value = int($i) }
            else {
              dec = (d ? d : d_max[i])
              type_str = (sn ? "." dec "e" : "." dec "f")
              value = $i }}
          else { type_str = "s"; value = $i }}
        else {
          type_str = (sn ? ".0e" : "s")
          value = $i }

        #if (not_last_f)
        print_len = f_max[i] + COLOR_DIFF[FNR, I] + WCWIDTH_DIFF[FNR, i]
        #else print_len = length(value)

        justify_str = "%" # Right-align
        fmt_str = justify_str print_len type_str

        printf fmt_str, value
        if (not_last_f) PrintBuffer()
      }
      else {
        if (shrink_f[i]) {
          color = hl; color_off = no_color
          value = CutStringByVisibleLen($i, max_f_len[i] + WCWIDTH_DIFF[FNR, i]) }
        else {
          color = ""; color_off = ""
          value = $i }

        if (not_last_f)
          print_len = max_f_len[i] + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]
        else
          print_len = length(value) + COLOR_DIFF[FNR, i] + WCWIDTH_DIFF[FNR, i]

        justify_str = "%-" # Left-align
        fmt_str = color justify_str print_len "s" color_off

        printf fmt_str, value
        if (not_last_f) PrintBuffer()
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
function StripStandardASCII(str) {
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
          #print p, PrintStr[p], rem_str
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
function PrintBuffer() {
  space_str = bufferchar "                                                               "
  printf "%.*s", buffer, space_str
}
function DebugPrint(case) {
  # Switch statement not supported in all Awk implementations
  if (debug_col && i != debug_col) return
  if (case == 1) {
    if (!title_printed) { title_printed=1
      printf "%-20s%5s%5s%5s%5s%5s%5s\n", "", "FNR", "i", "len", "ogmx", "fmxi", "ldf" }
    printf "%-20s%5s%5s%5s%5s%5s%5s", "max change: ", FNR, i, len, orig_max, f_max[i], l_diff }
  else if (case == 2)
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s", "decimal setting: ", FNR, i, d, d_len, d_len,  orig_max, len, int_diff, d_diff, l_diff, f_diff
  else if (case == 3)
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s", "decimal adjustment: ", FNR, i, d, d_len, d_max[i],  orig_max, len, int_diff, d_diff, l_diff, f_diff
  else if (case == 4) {
    if (!s_title_printed) { s_title_printed=1
      printf "%-15s%5s%5s%5s%5s%5s%5s%5s\n", "", "i", "fmxi", "avfl", "mxnf", "rdsc", "tfl", "ttys" }
    printf "%-15s%15s%5s%5s%5s%5s", "shrink step: ", avg_f_len, max_nf, reduction_scaler, total_f_len, tty_size }
  else if (case == 5)
    printf "%-15s%5s%5s", "shrink field: ", i, f_max[i]
  else if (case == 6)
    { print ""; print i, fmt_str, $i, value; print "" }
  else if (case == 7)
    printf "%s %s %s" "Number pattern set for col:", NR, i
  else if (case == 8) 
    printf "%s %s %s" "Number pattern overset for col:" NR, i
  else if (case == 9) 
    printf "%s %s %s" "g_max_cut: "cut_len, "max_f_len: "max_f_len[i], "total_f_len: "total_f_len
  else if (case == 10)
    printf "%s %s %s %s %s %s %s %s" "wcwdiff: " NR, i, init_len, len, wcw_diff, cs, f, f_wcw

  print ""
}
