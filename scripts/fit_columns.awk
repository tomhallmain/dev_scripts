#!/usr/bin/awk
#
# Unoptimized script to print a table of values with 
# dynamic column lengths. Unfortunately this requires 
# passing the file twice to Awk, once to read the lengths
# and once to print the output - and within that there are
# for loops to look at each field individually.
#
# Calling the script on a single file "same_file":
# > awk -f max_field_lengths.awk same_file same_file
# 
# Calling the script with a custom buffer (default is 1):
# > awk -f max_field_lengths.awk -v buffer=5 same_file same_file
#
# Calling the script with a custom decimal setting (default is 2):
# > awk -f max_field_lengths.awk -v d=4 same_file same_file

BEGIN {
  yellow = "\033[1;93m"
  orange = "\033[38;2;255;165;1m"
  red = "\033[1;31m"
  no_color = "\033[0m"

  decimal_re = "^[[:space:]]*[0-9]+[\.][0-9]+[[:space:]]*$"
  num_re = "^[[:space:]]*[0-9]+([\.][0-9]*)?[[:space:]]*$"

  "tput cols" | getline TTY_SIZE; TTY_SIZE += 0
  if (!d) d = 1 # TODO: Make the decimal length dynamic based on max in col
}

NR == FNR {
  for (i=1; i<=NF; i++) {
    len = length($i)
    orig_max = f_max[i]
    l_diff = len - orig_max
    
    if (len && l_diff > 0) {
      f_max[i] = len
      total_f_len += l_diff
      if (debug) debug_print(1)
    }

    # If column unconfirmed as decimal and the current field is decimal
    # set decimal for column and handle field length changes
    #
    # Else if column confirmed as decimal and current field is decimal
    # handle field length adjustments
    
    if (d && ! d_set[i] && $i ~ decimal_re) {
      d_set[i] = 1
      split($i, n_parts, "\.")
      d_len = length(n_parts[2])
      d_diff = d - d_len
      f_diff = max(d_diff + l_diff, 0)
      
      if (debug) debug_print(2)

      f_max[i] += f_diff
      total_f_len += f_diff
      d_max[i] = d_len

    } else if (d_set[i] && $i ~ num_re) {
      split($i, n_parts, "\.")
      d_len = length(n_parts[2])

      if (d_len > d_max[i] || l_diff + d + 1 > 0) {
        d_diff = d - d_len - d_max[i]
        l_diff = max(l_diff, 0)
        f_diff = max(d_diff + l_diff, 0)

        if (debug) debug_print(3)
 
        f_max[i] += f_diff
        total_f_len += f_diff
        if (d_len > d_max[i]) d_max[i] = d_len
      }
    }
  }

  if (NF > max_nf) max_nf = NF
}

NR > FNR {

  if (FNR == 1) {
    for (i=1; i <= max_nf; i++)
      if (f_max[i]) { max_f_len[i] = f_max[i]; total_f_len += buffer }

    shrink = TTY_SIZE && total_f_len > TTY_SIZE

    if (shrink) {
      print_warning()
      reduction_scaler = 12
      
      while (total_f_len > TTY_SIZE && reduction_scaler > 0) {
        avg_f_len = total_f_len / max_nf
        cut_len = int(avg_f_len/10)
        scaled_cut = cut_len * reduction_scaler
        if (debug) debug_print(4)
        
        for (i=1; i <= max_nf; i++) {
          if (! d_set[i] && f_max[i] > scaled_cut && f_max[i] - cut_len > buffer) {
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
  }

  for (i=1; i<=NF; i++) {
    if (f_max[i]) {
      if (d_set[i]) {
        
        if ($i ~ num_re)
          type_str = "." d "f"
        else
          type_str = "s"

        justify_str = "%" # Right-align
        fmt_str = justify_str f_max[i] type_str
        printf fmt_str, $i; print_buffer()
      
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
      if (i == NF) { printf "\n" }
    }
  }
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
  printf "%.*s", buffer, "                                        "
}


function debug_print(case) {
  # Switch statement not supported in all Awk implementations
  if (case == 1)
    printf "%-20s%5s%5s%5s%5s%5s%5s", "max change: ", FNR, i, len, orig_max, f_max[i], l_diff
  else if (case == 2)
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s", "decimal setting: ", FNR, i, d, d_len, orig_max, len, d_diff, l_diff, f_diff
  else if (case == 3)
    printf "%-20s%5s%5s%5s%5s%5s%5s%5s%5s%5s", "decimal adjustment: ", FNR, i, d, d_len, orig_max, len, d_diff, l_diff, f_diff
  else if (case == 4)
    printf "%-15s%10s%5s%5s%5s%5s", "shrink step: ", avg_f_len, max_nf, reduction_scaler, total_f_len, TTY_SIZE
  else if (case == 5)
    printf "%-15s%5s%5s", "shrink field: ", i, f_max[i]
  
  print ""
}
