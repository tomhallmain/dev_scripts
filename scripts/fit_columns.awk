#!/usr/bin/awk
#
# Unoptimized script to print a table of values with 
# dynamic column lengths. Requires passing file twice to Awk, 
# once to read the lengths and once to print the output - 
# within that there are for loops to look at each field 
# individually.
#
# Running on a single file "same_file":
# > awk -f fit_columns.awk samefile samefile
# 
# Variables to customize output listed below
#
# Running with a custom buffer (default is 1):
# -v buffer=5
#
# Running with a custom decimal setting (default is the max for 
# column value):
# -v d=4
#
# Running with custom decimal setting of zero:
# -v d=z (why? awk coerces 0 to false)
#
# Running with no color or warning:
# -v color=never
#
# Running without decimal transformations:
# -v dec_off=1
#
# Running with scientific notation:
# -v sn=1
#
# Custom character for buffer:
# -v bufferchar="|"


BEGIN {
  
  if (d < 0) {
    sn = -d
    d = "z"
  }
  
  sn0_len = 1 + 4 # e.g. 0e+00
  
  if (sn && d) {
    if (d == "z")
      sn_len = sn0_len
    else
      sn_len = 2 + d + 4 # e.g. 0.00e+00
  }

  if (!buffer) buffer = 2

  if (!(color == "never")) {
    yellow = "\033[1;93m"
    orange = "\033[38;2;255;165;1m"
    red = "\033[1;31m"
    no_color = "\033[0m"
  }

  decimal_re = "^[[:space:]]*[0-9]+[\.][0-9]+[[:space:]]*$"
  num_re = "^[[:space:]]*[0-9]+([\.][0-9]*)?[[:space:]]*$"

  if (!tty_size)
    "tput cols" | getline tty_size; tty_size += 0
}


NR == FNR {

  for (i = 1; i <= NF; i++) {
    gsub(/\0\[((1|0);)?3?[0-9]m/, "", $i)
    len = length($i)
    if (len < 1) continue
    orig_max = f_max[i]
    l_diff = len - orig_max
    d_diff = 0
    f_diff = 0
    
    if (n_set[i] && ! d_set[i] && ! n_overset[i] && ($i ~ num_re) == 0 && len > 0) {
      n_overset[i] = 1
      if (debug) debug_print(8)
      if (save_n_max[i] > f_max[i] && save_n_max[i] > save_s_max[i]) {
        recap_n_diff = max(save_n_max[i] - f_max[i], 0)
        f_max[i] += recap_n_diff
        total_f_len += recap_n_diff
      }
    }

    # If column unconfirmed as decimal and the current field is decimal
    # set decimal for column and handle field length changes
    #
    # Else if column confirmed as decimal and current field is decimal
    # handle field length adjustments
    #
    # Otherwise just handle simple field length increases and store number
    # columns for later justification, but scientific notation makes things 
    # more complex

    if (! dec_off && ! d_set[i] && $i ~ decimal_re) {
      d_set[i] = 1
      split($i, n_parts, "\.")
      sub("0*$", "", n_parts[2]) # Remove trailing zeros in decimal part
      d_len = length(n_parts[2])
      d_max[i] = d_len

      if (sn) {
        if (!d) sn_len = 2 + d_len + 4
        sn_diff = sn_len - orig_max
        f_diff = max(sn_diff, 0)
      
      } else {
        int_len = length(int(n_parts[1]))
        int_diff = int_len + 1 + d_len - len
        if (d == "z") {
          d_len++ # Removing dot
          d_diff = -1 * d_len 
        } else {
          d_diff = (d ? d - d_len : 0)
        }

        f_diff = max(l_diff + int_diff + d_diff, 0)
      }

      if (debug && f_diff) debug_print(2)

    } else if (! dec_off && d_set[i] && $i ~ num_re) {
        split($i, n_parts, "\.")
        sub("0*$", "", n_parts[2]) # Remove trailing zeros in decimal part
        d_len = length(n_parts[2])
        if (d_len > d_max[i]) d_max[i] = d_len
        
        if (sn) {
          if (!d) sn_len = 2 + d_max[i] + 4
          sn_diff = sn_len - orig_max
          f_diff = max(sn_diff, 0)

        } else {
          int_len = length(int(n_parts[1]))
          dot = (d_len == 0 ? 0 : 1)
          int_diff = int_len + dot + d_len - len
  
        if (d == "z") {
          d_len + dot 
          d_diff = -1 * d_len
          f_diff = max(l_diff + int_diff + d_diff, 0)
        } else {
          dot = (!dot)
          dec = (d ? d : d_max[i])
          if (l_diff + dec + dot > 0) {
            d_diff = dec - d_len + dot
            f_diff = max(l_diff + int_diff + d_diff, 0)
          }
        }
      }

      if (debug && f_diff) debug_print(3)

    } else if (l_diff > 0) {
      if ( FNR < 3 && $i ~ num_re) {
        n_set[i] = 1
        if (len > n_max[i]) n_max[i] = len
        if (debug) debug_print(7)
      }
      if (sn && n_set[i] && ! n_overset[i] && n_max[i] > sn0_len && $i ~ num_re) {
        if (len > save_n_max[i]) save_n_max[i] = len
        sn_diff = sn0_len - orig_max
        
        l_diff = sn_diff
      }
      if (sn && ($i ~ num_re) == 0) if (len > save_s_max[i]) save_s_max[i] = len

      f_diff = l_diff

      if (debug) debug_print(1)
    }

    if (f_diff) {
      f_max[i] += f_diff
      total_f_len += f_diff
    }
  }

  if (NF > max_nf) max_nf = NF

}


NR > FNR {
  
  if (FNR == 1) {
    for (i = 1; i <= max_nf; i++) {
      if (f_max[i]) { max_f_len[i] = f_max[i]; total_f_len += buffer
        if (f_max[i] / total_f_len > 0.4 ) { 
          g_max[i] = f_max[i] + buffer
          g_max_len += g_max[i]
          g_count++ }}}

    shrink = tty_size && total_f_len > tty_size

    if (shrink) {
      if (!(color == "never")) print_warning()

      while (g_max_len / total_f_len > 0.5) {
        for (i in g_max) {
          cut_len = int(f_max[i]/10)
          f_max[i] -= cut_len
          total_f_len -= cut_len
          g_max_len -= cut_len
          shrink_f[i] = 1
          max_f_len[i] = f_max[i]
          if (debug) print "g_max_cut: " cut_len, "max_f_len: " max_f_len[i]
        }
      }

      reduction_scaler = 14
      
      while (total_f_len > tty_size && reduction_scaler > 0) {
        avg_f_len = total_f_len / max_nf
        cut_len = int(avg_f_len/10)
        scaled_cut = cut_len * reduction_scaler
        if (debug) debug_print(4)
        
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
            if (debug) debug_print(5)
          }}
        reduction_scaler--
      }}}

  for (i = 1; i <= max_nf; i++) {
    not_last_f = (i < max_nf);
    if (f_max[i]) {
      if (d_set[i] || (n_set[i] && ! n_overset[i])) {
        
        if (d_set[i]) {
          if ($i ~ num_re) {
            if (d == "z") {
              type_str = (sn ? ".0e" : "s")
              value = int($i)
            } else {
              dec = (d ? d : d_max[i])
              type_str = (sn ? "." dec "e" : "." dec "f")
              value = $i
            }
          } else { type_str = "s"; value = $i }
        } else {
          type_str = (sn ? ".0e" : "s")
          value = $i }

        #if (not_last_f)
        print_len = f_max[i]
        #else print_len = length(value)

        justify_str = "%" # Right-align
        fmt_str = justify_str print_len type_str
        printf fmt_str, value
        if (not_last_f) print_buffer()
      } else {
        
        if (shrink_f[i]) {
          color = yellow
          value = substr($i, 1, max_f_len[i])
        } else {
          color = ""
          value = $i
        }

        if (not_last_f) print_len = max_f_len[i]
        else print_len = length(value)

        justify_str = "%-" # Left-align
        fmt_str = color justify_str print_len "s" no_color
        printf fmt_str, value
        if (not_last_f) print_buffer()
      }}
    if (debug && FNR < 4) debug_print(6)
  }
  print ""
}


function max(a, b) {
  if (a > b) return a
  else if (a < b) return b
  else return a
}
function min(a, b) {
  if (a > b) return b
  else if (a < b) return a
  else return a
}
function print_warning() {
  print orange "WARNING: Total max field lengths larger than display width!" no_color
  print "Columns cut printed in " yellow "YELLOW" no_color
  print ""
}
function print_buffer() {
  space_str = bufferchar "                                                               "
  printf "%.*s", buffer, space_str
}
function debug_print(case) {
  # Switch statement not supported in all Awk implementations
  if (debug_col && i != debug_col) return
  if (case == 1)
    printf "%-20s%5s%5s%5s%5s%5s%5s", "max change: ", FNR, i, len, orig_max, f_max[i], l_diff
  else if (case == 2)
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s", "decimal setting: ", FNR, i, d, d_len, d_len,  orig_max, len, int_diff, d_diff, l_diff, f_diff
  else if (case == 3)
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s%5s", "decimal adjustment: ", FNR, i, d, d_len, d_max[i],  orig_max, len, int_diff, d_diff, l_diff, f_diff
  else if (case == 4)
    printf "%-15s%10s%5s%5s%5s%5s", "shrink step: ", avg_f_len, max_nf, reduction_scaler, total_f_len, tty_size
  else if (case == 5)
    printf "%-15s%5s%5s", "shrink field: ", i, f_max[i]
  else if (case == 6)
    { print ""; print i, fmt_str, $i, value; print "" }
  else if (case == 7)
    print "Number pattern set for col:", NR, i
  else if (case == 8) 
    print "Number pattern overset for col:" NR, i

  print ""
}
