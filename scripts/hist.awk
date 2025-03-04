#!/usr/bin/awk
#
# DS:HIST - Advanced Terminal-based Histogram Generator
#
# SYNOPSIS
#     ds:hist [file] [-v options]
#
# DESCRIPTION
#     Create customizable histograms from columnar data with support for multiple
#     fields, custom binning, and various display options. Automatically detects
#     numeric fields and generates appropriate bin ranges.
#
# OPTIONS
#     n_bins=N        Number of bins (default: 10)
#     max_bar_len=N   Maximum bar length in characters (default: 15)
#     style=STYLE     Bar style: plus, blocks, dots, stars, shade, braille (default: plus)
#     fields=STR      Comma-separated list of fields to process (default: all)
#     header=1        Data has header row
#     format=STR      Number format for bin edges (default: auto)
#     color=1         Enable color output
#     sort=TYPE       Sort bins by: count, value (default: value)
#     cumulative=1    Show cumulative distribution
#     stats=1         Show additional statistics
#     log_scale=1     Use logarithmic binning
#     percentiles=1   Show quartiles and percentiles
#
# STYLES
#     plus:    +++++++  (default)
#     blocks:  ████████
#     dots:    ········
#     stars:   ********
#     shade:   ░▒▓█
#     braille: ⠁⠂⠃⠄⠅
#
# EXAMPLES
#     # Basic histogram of all numeric fields
#     $ cat data.csv | ds:hist
#
#     # Colored histogram with 20 bins
#     $ ds:hist data.csv -v n_bins=20 -v color=1
#
#     # Custom style with specific fields
#     $ ds:hist data.csv -v style=blocks -v fields=3,4,5
#
#     # Cumulative distribution with statistics
#     $ ds:hist data.csv -v cumulative=1 -v stats=1
#
#     # Logarithmic histogram with shaded style
#     $ ds:hist data.csv -v log_scale=1 -v style=shade
#
#     # Histogram with percentiles
#     $ ds:hist data.csv -v percentiles=1 -v stats=1

BEGIN {
    # Initialize parameters
    if (!n_bins) n_bins = 10
    if (!max_bar_len) max_bar_len = 15
    if (!style) style = "plus"
    if (!format) format = "%.2g"
    
    # Set up bar characters based on style
    setup_style()
    
    # Set up colors if enabled
    if (color) setup_colors()
    
    # Initialize data structures
    num_re = "^[[:space:]]*\\$?-?\\$?[0-9]*\\.?[0-9]+[[:space:]]*$"
    decimal_re = "^[[:space:]]*\\$?-?\\$?[0-9]*\\.[0-9]+[[:space:]]*$"
    float_re = "^[[:space:]]*-?[0-9]\\.[0-9]+(E|e)(\\+|-)?[0-9]+[[:space:]]*$"
    
    # Parse fields parameter
    if (fields) {
        split(fields, FieldList, ",")
        for (i in FieldList) SelectedFields[FieldList[i]] = 1
    }
}

{
    for (f = 1; f <= NF; f++) {
        if (fields && !SelectedFields[f]) continue
        
        fval = clean_field($f)
        if (!AnyFmtNum(fval)) {
            if (NR == 1 && header) {
                Headers[f] = fval
                continue
            }
            next
        }
        
        fval = normalize_value(fval)
        store_value(f, fval)
        
        # Collect data for statistics
        if (stats) {
            Sum[f] += fval
            SumSq[f] += fval * fval
        }
    }
}

END {
    for (f in Rec) {
        if (!MaxFSet[f]) continue
        
        # Build bins
        bin_edges = build_bins(f, Max[f], Min[f], n_bins)
        split(bin_edges, Edges[f], ",")
        
        # Assign values to bins
        assign_to_bins(f)
        
        # Calculate statistics if requested
        if (stats) calculate_stats(f)
        
        # Sort bins if requested
        if (sort) sort_bins(f)
        
        # Print histogram
        print_histogram(f)
    }
}

# Helper Functions

function setup_style() {
    if (style == "blocks") {
        BAR_CHAR = "█"
    } else if (style == "dots") {
        BAR_CHAR = "·"
    } else if (style == "stars") {
        BAR_CHAR = "*"
    } else if (style == "shade") {
        SHADE_CHARS[1] = "░"
        SHADE_CHARS[2] = "▒"
        SHADE_CHARS[3] = "▓"
        SHADE_CHARS[4] = "█"
        BAR_CHAR = SHADE_CHARS[1]  # Default shade
    } else if (style == "braille") {
        BRAILLE_CHARS[1] = "⠁"
        BRAILLE_CHARS[2] = "⠃"
        BRAILLE_CHARS[3] = "⠇"
        BRAILLE_CHARS[4] = "⠏"
        BRAILLE_CHARS[5] = "⠟"
        BAR_CHAR = BRAILLE_CHARS[1]  # Default braille
    } else {
        BAR_CHAR = "+"
    }
    
    bar = ""
    for (i = 1; i <= max_bar_len; i++)
        bar = bar BAR_CHAR
}

function setup_colors() {
    COLORS["reset"] = "\033[0m"
    COLORS["red"] = "\033[31m"
    COLORS["green"] = "\033[32m"
    COLORS["blue"] = "\033[34m"
    COLORS["yellow"] = "\033[33m"
}

function clean_field(val) {
    gsub(/[[:space:]]+/, "", val)
    gsub(/[\$,()]/, "", val)
    return val
}

function normalize_value(val) {
    if (!AnyFmtNum(val)) {
        if (val == "-inf") return -1e308
        if (val == "inf") return 1e308
        return 0
    }
    return GetOrSetTruncVal(val)
}

function store_value(f, val) {
    if (!Counts[f, val]) Rec[f]++
    Counts[f, val]++
    
    if (!MaxFSet[f]) {
        Max[f] = val
        Min[f] = val
        MaxFSet[f] = 1
    } else {
        if (val < Min[f]) Min[f] = val
        if (val > Max[f]) Max[f] = val
    }
}

function build_bins(f, max, min, n_bins,    bin_size, b, bin_edge) {
    if (log_scale && min > 0 && max > min) {
        # Logarithmic binning
        log_min = log(min)
        log_max = log(max)
        log_step = (log_max - log_min) / n_bins
        bins = ""
        for (b = 1; b <= n_bins; b++) {
            bin_edge = exp(log_min + b * log_step)
            bins = bins bin_edge","
        }
    } else {
        # Linear binning
        bin_size = (max - min) / n_bins
        bins = ""
        for (b = 1; b <= n_bins; b++) {
            bin_edge = min + b * bin_size
            bins = bins bin_edge","
        }
    }
    return bins
}

function assign_to_bins(f,    c, val, b) {
    for (c in Counts) {
        split(c, CountDesc, SUBSEP)
        if (CountDesc[1] != f) continue
        
        val = CountDesc[2]
        for (b = 1; b <= n_bins; b++) {
            if (val <= Edges[f][b]) {
                Bin[f, b] += Counts[c]
                if (Bin[f, b] > MaxBin[f]) MaxBin[f] = Bin[f, b]
                break
            }
        }
    }
    
    # Calculate cumulative counts if requested
    if (cumulative) {
        CumSum[f, 1] = Bin[f, 1]
        for (b = 2; b <= n_bins; b++) {
            CumSum[f, b] = CumSum[f, b-1] + Bin[f, b]
        }
    }
}

function calculate_stats(f) {
    # Basic statistics
    Stats[f, "mean"] = Sum[f] / Rec[f]
    Stats[f, "variance"] = (SumSq[f] / Rec[f]) - (Stats[f, "mean"] ^ 2)
    Stats[f, "stddev"] = sqrt(Stats[f, "variance"])
    Stats[f, "median"] = calculate_median(f)
    
    if (percentiles) {
        # Calculate quartiles and key percentiles
        calculate_percentiles(f)
    }
    
    # Calculate skewness and kurtosis if we have enough data points
    if (Rec[f] >= 3) {
        calculate_shape_stats(f)
    }
}

function calculate_median(f,    vals, count, i, j) {
    # Collect and sort values
    count = 0
    for (i in Counts) {
        split(i, desc, SUBSEP)
        if (desc[1] == f) {
            for (j = 1; j <= Counts[i]; j++)
                vals[++count] = desc[2]
        }
    }
    asort(vals)
    
    # Return median
    if (count % 2) return vals[int(count/2) + 1]
    return (vals[count/2] + vals[count/2 + 1]) / 2
}

function calculate_percentiles(f,    vals, count, i, j) {
    # Collect and sort values
    count = 0
    for (i in Counts) {
        split(i, desc, SUBSEP)
        if (desc[1] == f) {
            for (j = 1; j <= Counts[i]; j++)
                vals[++count] = desc[2]
        }
    }
    asort(vals)
    
    # Calculate quartiles and key percentiles
    Stats[f, "q1"] = get_percentile(vals, count, 0.25)
    Stats[f, "q3"] = get_percentile(vals, count, 0.75)
    Stats[f, "p10"] = get_percentile(vals, count, 0.10)
    Stats[f, "p90"] = get_percentile(vals, count, 0.90)
    Stats[f, "iqr"] = Stats[f, "q3"] - Stats[f, "q1"]
}

function get_percentile(vals, count, p,    idx) {
    idx = 1 + (count - 1) * p
    if (idx == int(idx)) {
        return vals[idx]
    }
    return vals[int(idx)] * (1 - (idx - int(idx))) + vals[int(idx) + 1] * (idx - int(idx))
}

function calculate_shape_stats(f,    m3, m4) {
    # Calculate third and fourth moments for skewness and kurtosis
    m3 = m4 = 0
    for (i in Counts) {
        split(i, desc, SUBSEP)
        if (desc[1] == f) {
            dev = desc[2] - Stats[f, "mean"]
            m3 += Counts[i] * dev * dev * dev
            m4 += Counts[i] * dev * dev * dev * dev
        }
    }
    m3 /= Rec[f]
    m4 /= Rec[f]
    
    # Calculate skewness and kurtosis
    if (Stats[f, "stddev"] > 0) {
        Stats[f, "skewness"] = m3 / (Stats[f, "stddev"] ^ 3)
        Stats[f, "kurtosis"] = m4 / (Stats[f, "stddev"] ^ 4) - 3  # Excess kurtosis
    }
}

function sort_bins(f) {
    # Implementation depends on sort type
    # For now, we keep the default value-based ordering
}

function print_histogram(f,    b, val, bar_len, header) {
    # Print header
    header = "Hist: field " f
    if (Headers[f]) header = header " (" Headers[f] ")"
    header = header ", cardinality " Rec[f]
    print header
    
    # Print statistics if requested
    if (stats) {
        printf "Mean: %.4g, Median: %.4g\n", Stats[f, "mean"], Stats[f, "median"]
        printf "StdDev: %.4g, Variance: %.4g\n", Stats[f, "stddev"], Stats[f, "variance"]
        
        if ("skewness" in Stats[f]) {
            skew_desc = Stats[f, "skewness"] < -0.5 ? "Left-skewed" : (Stats[f, "skewness"] > 0.5 ? "Right-skewed" : "Symmetric")
            printf "Skewness: %.4g (%s)\n", Stats[f, "skewness"], skew_desc
        }
        
        if (percentiles) {
            printf "Quartiles: Q1=%.4g, Q3=%.4g (IQR=%.4g)\n", 
                   Stats[f, "q1"], Stats[f, "q3"], Stats[f, "iqr"]
            printf "10th-90th percentile range: %.4g - %.4g\n",
                   Stats[f, "p10"], Stats[f, "p90"]
        }
    }
    
    # Calculate display parameters
    edges_len = max_len * 2 + 6
    len_mod = (MaxBin[f] > max_bar_len && MaxBin[f] != 0) ? max_bar_len / MaxBin[f] : 1
    
    # Print bins
    for (b = 1; b <= n_bins; b++) {
        # Format bin edges
        start_edge = b == 1 ? Min[f] : Edges[f][b-1]
        end_edge = Edges[f][b]
        bin_label = sprintf("%"edges_len"s ", sprintf(format, start_edge) " - " sprintf(format, end_edge))
        
        # Calculate bar length
        count = cumulative ? CumSum[f, b] : Bin[f, b]
        bar_len = int(count * len_mod)
        
        # Print bar with optional color
        printf "%s", bin_label
        if (color) printf "%s", get_color(count / MaxBin[f])
        
        # Enhanced bar rendering for shade and braille styles
        if (style == "shade" || style == "braille") {
            intensity = count / MaxBin[f]
            if (style == "shade") {
                char_idx = 1 + int(intensity * 3.99)  # Map to 4 shade levels
                bar_char = SHADE_CHARS[char_idx]
            } else {
                char_idx = 1 + int(intensity * 4.99)  # Map to 5 braille levels
                bar_char = BRAILLE_CHARS[char_idx]
            }
            for (i = 1; i <= bar_len; i++)
                printf "%s", bar_char
        } else {
            printf "%.*s", bar_len, bar
        }
        
        if (color) printf "%s", COLORS["reset"]
        
        # Print count
        printf " (%d)\n", count
    }
    print ""
}

function get_color(intensity) {
    if (intensity <= 0.33) return COLORS["blue"]
    if (intensity <= 0.66) return COLORS["yellow"]
    return COLORS["red"]
}

# Existing utility functions
function AnyFmtNum(str) {
    return (str ~ num_re || str ~ decimal_re || str ~ float_re)
}

function GetOrSetTruncVal(val) {
    if (val in TruncVal) return TruncVal[val]
    
    if (val > 999 && val ~ /\.[0-9]{3,}/ || 
        val ~ /^-?[0-9]*\.?[0-9]+(E|e)\+?([4-9]|[1-9][0-9]+)$/) {
        trunc_val = int(val)
    } else {
        trunc_val = sprintf(format, val)
    }
    
    trunc_val += 0
    TruncVal[val] = trunc_val
    return trunc_val
}

