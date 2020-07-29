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
# Calling the script with a custom buffer:
# > awk -f max_field_lengths.awk -v buffer=5 same_file same_file
#
# Calling the script with a custom buffer:
# > awk -f max_field_lengths.awk -v buffer=5 same_file same_file

# TODO: Buffer getting set twice in non shrink case
# TODO: Shrink case buffer/spacing max field len missing
# TODO: Index row not being shrunk?
# TODO: Too many chars in terminal width compare string

function get_max(a, b) {
  if (a > b) return a
  else if (a < b) return b
  else if (a == b) return a
  else return "bad input"
}

BEGIN {
  yellow = "\033[1;93m"
  orange = "\033[38;2;255;165;1m"
  red = "\033[1;31m"
  no_color = "\033[0m"
  "tput cols" | getline TTY_SIZE; TTY_SIZE += 0
}

NR == FNR {
  for (i=1; i<=NF; i++) {
    len = length($i)
    orig_max = max[i]
    l_diff = len - orig_max
    
    if (len && l_diff > 0) max[i] = len

    if (d && ! d_set[i] && ($i ~ "^[0-9]+[\.][0-9]*$") == 1) {
      d_set[i] = 1
      
      split($i, n_parts, "\.")
      d_len = length(n_parts[2])
      d_max[i] = d_len
      
      d_diff = d - d_len
      f_diff = d_diff + l_diff
      print i, d, d_len, orig_max, len, d_diff, l_diff, f_diff
      max[i] += f_diff

    } else if (d_set[i] && ($i ~ "^[0-9]+[\.][0-9]*$") == 1) {
      split($i, n_parts, "\.")
      d_len = length(n_parts[2])
      
      if (d_len > d_max[i] || l_diff + d > 0) {
        print i, FNR
        d_diff = d - d_len - d_max[i]
        l_diff = get_max(l_diff, 0)
        f_diff = d_diff + l_diff
        max[i] += f_diff
        print i, d, d_len, orig_max, len, d_diff, l_diff, f_diff
        d_max[i] = d_len
      }
    }
  }

  if (NF > max_nf) max_nf = NF
}

NR > FNR {

  if (FNR == 1) {
    for (i=1; i <= max_nf; i++) {
      if (max[i]) { 
        max[i] += buffer
        max_f_len[i] = max[i]
        if (TTY_SIZE) {
          total_f_len += max[i]
          #if (d_set[i]) total_f_len += d
        }
      }
    }

    shrink = TTY_SIZE && total_f_len > TTY_SIZE

    if (shrink) {
      reduction_scaler = 12
      
      while (total_f_len > TTY_SIZE && reduction_scaler > 0) {
        avg_f_len = total_f_len / max_nf
        cut_len = int(avg_f_len/10)
        print avg_f_len, max_nf, reduction_scaler
        print total_f_len, TTY_SIZE
        
        for (i=1; i <= max_nf; i++) {
          if (! d_set[i] && max[i] > cut_len * reduction_scaler) {
            if (max[i] - cut_len > buffer + 1) {
              max[i] -= cut_len
              total_f_len -= cut_len
              shrinkf[i] = 1
            }
            print max[i]
          }

          max_f_len[i] = max[i] - buffer - d
        }

        reduction_scaler--
      }

      print orange "WARNING: Max field lengths larger than display width!" no_color
      print "Columns cut printed in " yellow "YELLOW" no_color
      print ""
    }
  }

  for (i=1; i<=NF; i++) {
    if (max[i]) {
      value = (shrinkf[i] ? substr($i, 1, max_f_len[i]) : $i)

      if (d_set[i]) {

        justify_str = "%"

        if (($i ~ "^[0-9]+\.?[0-9]*$") == 1)
          type_str = "." d "f"
        else
          type_str = "s"

        fmt_str = justify_str max[i] type_str
        
        printf fmt_str, $i
        printf "%.*s", buffer, "                                  "
      
      } else {
        if (shrinkf[i])
          { color = yellow; end_color = no_color } 
        else
          { color = ""; end_color = "" }

        justify_str = "%-"
        
        fmt_str = color justify_str max_f_len[i] "s" end_color
        
        printf fmt_str, value
        printf "%.*s", buffer, "                                  "

      }
    }

    if (i == NF) { printf "\n" }
  }
}
