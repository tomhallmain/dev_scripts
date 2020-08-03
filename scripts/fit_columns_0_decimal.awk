#!/usr/bin/awk
#
# Unoptimized script to print a table of values with 
# dynamic column lengths. Unfortunately this requires 
# passing the file twice to Awk, once to read the lengths
# and once to print the output - and within that there are
# for loops to look at each field individually.
#
# Running on a single file "same_file":
# > awk -f fit_columns.awk samefile samefile
# 
# Variables to customize output listed below
#
# Running with a custom buffer (default is 1):
# -v buffer=5
#
# Running with a custom decimal setting (default is the max for the column
# values):
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

BEGIN {

  if (!(color == "never")) {
    yellow = "\033[1;93m"
    orange = "\033[38;2;255;165;1m"
    red = "\033[1;31m"
    no_color = "\033[0m"
  }

  decimal_re = "^[[:space:]]*[0-9]+[\.][0-9]+[[:space:]]*$"
  num_re = "^[[:space:]]*[0-9]+([\.][0-9]*)?[[:space:]]*$"

  "tput cols" | getline TTY_SIZE; TTY_SIZE += 0
  if (!buffer) buffer = 1

}


NR == FNR {

  for (i = 1; i <= NF; i++) {
    len = length($i)
    if (len < 1) continue
    orig_max = f_max[i]
    l_diff = len - orig_max
    d_diff = 0
    f_diff = 0

    # If column unconfirmed as decimal and the current field is decimal
    # set decimal for column and handle field length changes
    #
    # Else if column confirmed as decimal and current field is decimal
    # handle field length adjustments
    #
    # Otherwise just handle simple field length increases and store number
    # columns for later justification

    if (! dec_off && ! d_set[i] && $i ~ decimal_re) {
      d_set[i] = 1
      split($i, n_parts, "\.")
      int_len = length(int(n_parts[1]))
      sub("0*$", "", n_parts[2]) # Remove trailing zeros in decimal part
      d_len = length(n_parts[2])
      int_diff = int_len + 1 + d_len - len
      d_max[i] = d_len

      if (d == "z") {
        d_len++ # Removing dot
        d_diff = -1 * d_len 
      } else {
        d_diff = (d ? d - d_len : 0)
      }

      f_diff = max(l_diff + int_diff + d_diff, 0)

      if (debug && f_diff) debug_print(2)

    } else if (! dec_off && d_set[i] && $i ~ num_re) {
      split($i, n_parts, "\.")
      int_len = length(int(n_parts[1]))
      sub("0*$", "", n_parts[2]) # Remove trailing zeros in decimal part
      d_len = length(n_parts[2])
      dot = (d_len == 0 ? 0 : 1)
      int_diff = int_len + dot + d_len - len
      if (d_len > d_max[i]) d_max[i] = d_len
 
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

      if (debug && f_diff) debug_print(3)

    } else if (l_diff > 0) {
      if ( FNR < 3 && $i ~ num_re) {
        n_set[i] = 1
        if (debug) print "Number pattern set for col:", i
      }

      f_diff = l_diff

      if (debug) debug_print(1)
    }

    if (n_set[i] && ! n_overset[i] && ($i ~ num_re) == 0) {
      n_overset[i] = 1
      if (debug) print "Number pattern overset for col:" NR, i
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
    for (i = 1; i <= max_nf; i++)
      if (f_max[i]) { max_f_len[i] = f_max[i]; total_f_len += buffer }

    shrink = TTY_SIZE && total_f_len > TTY_SIZE

    if (shrink) {
      if (!(color == "never")) print_warning()
      reduction_scaler = 12
      
      while (total_f_len > TTY_SIZE && reduction_scaler > 0) {
        avg_f_len = total_f_len / max_nf
        cut_len = int(avg_f_len/10)
        scaled_cut = cut_len * reduction_scaler
        if (debug) debug_print(4)
        
        for (i = 1; i <= max_nf; i++) {
          if (! d_set[i] \
              && ! (n_set[i] && ! n_overset[i]) \
              && f_max[i] > scaled_cut \
              && f_max[i] - cut_len > buffer) {
            f_max[i] -= cut_len
            total_f_len -= cut_len
            shrinkf[i] = 1
            if (debug) debug_print(5)
          }
          max_f_len[i] = f_max[i]
        }
        reduction_scaler--
      }
    }

    if (debug) debug_print(6)
  }

  for (i = 1; i <= NF; i++) {
    if (f_max[i]) {
      if (d_set[i] || (n_set[i] && ! n_overset[i])) {
        
        if (d_set[i]) {
          if ($i ~ num_re) {
            if (d == "z") {
              type_str = "s"
              value = int($i)
            } else {
              dec = (d ? d : d_max[i])
              type_str = "." dec "f"
              value = $i
            }
          } else {
            type_str = "s"
            value = $i
          }
        } else {
          type_str = "s"
          value = $i
        }

        justify_str = "%" # Right-align
        fmt_str = justify_str f_max[i] type_str
        printf fmt_str, value; print_buffer()
      
      } else {
        
        if (shrinkf[i]) { 
          color = yellow; end_color = no_color
          value = substr($i, 1, max_f_len[i])
        } else {
          color = ""; end_color = ""; value = $i
        }

        justify_str = "%-" # Left-align
        fmt_str = color justify_str max_f_len[i] "s" end_color
        printf fmt_str, value; print_buffer()
      
      }
    }
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
function round(x, ival, aval, fraction) {
   ival = int(x)    # integer part, int() truncates

   # see if fractional part
   if (ival == x)   # no fraction
      return ival   # ensure no decimals

   if (x < 0) {
      aval = -x     # absolute value
      ival = int(aval)
      fraction = aval - ival
      if (fraction >= .5)
         return int(x) - 1   # -2.5 --> -3
      else
         return int(x)       # -2.3 --> -2
   } else {
      fraction = x - ival
      if (fraction >= .5)
         return ival + 1
      else
         return ival
   }
}
function print_warning() {
  print orange "WARNING: Total max field lengths larger than display width!" no_color
  print "Columns cut printed in " yellow "YELLOW" no_color
  print ""
}
function print_buffer() {
  printf "%.*s", buffer, "                                         "
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
    printf "%-15s%10s%5s%5s%5s%5s", "shrink step: ", avg_f_len, max_nf, reduction_scaler, total_f_len, TTY_SIZE
  else if (case == 5)
    printf "%-15s%5s%5s", "shrink field: ", i, f_max[i]
  else if (case == 6) {
    for (i=1; i<=NF; i++) {
      if (f_max[i]) {
        if (d_set[i]) {
          if ($i ~ num_re) {
            if (d == "z") {
              type_str = ".14g"
            } else {
              dec = (d ? d : d_max[i])
              type_str = "." dec "f"
            }
          } else {
            type_str = "s"
          }
          justify_str = "%" # Right-align
          fmt_str = justify_str f_max[i] type_str
          print i, "decimal", fmt_str, $i
        } else {
          if (shrinkf[i]) value = substr($i, 1, max_f_len[i])
          justify_str = "%-" # Left-align
          fmt_str = justify_str max_f_len[i] "s"
          print i, "string", fmt_str, value
        }
      }
    }
  }
  
  print ""
}
