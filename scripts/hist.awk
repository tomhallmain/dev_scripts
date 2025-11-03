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
    # Seed random number generator for efficient quicksort
    SeedRandom()
    
    # Initialize parameters
    if (!n_bins) n_bins = 10
    if (!max_bar_len) max_bar_len = 15
    if (!style) style = "plus"
    if (!format) format = "%.2g"
    
    # Track if header was explicitly set
    header_set_externally = (header == 1)
    
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
    # Store headers from first row if header option is explicitly enabled
    if (NR == 1 && header_set_externally) {
        for (f = 1; f <= NF; f++) {
            Headers[f] = $f
            # Clean header name (remove whitespace, but keep original for display)
            gsub(/[[:space:]]+/, " ", Headers[f])
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", Headers[f])
        }
        next  # Skip header row for data processing
    }
    
    # Auto-detect header row if not explicitly set
    if (NR == 1 && !header_set_externally) {
        # Store first row for later processing
        for (f = 1; f <= NF; f++) {
            FirstRow[f] = $f
        }
        FirstRowNF = NF
        
        # Check if all fields in first row are non-numeric
        all_non_numeric = 1
        for (f = 1; f <= NF; f++) {
            fval = clean_field($f)
            if (AnyFmtNum(fval)) {
                all_non_numeric = 0
                break
            }
        }
        
        # Skip processing first row until we see second row
        next
    }
    
    # On second row, check if we should auto-detect headers
    if (NR == 2 && !header_set_externally && all_non_numeric) {
        # Check if at least one field in second row is numeric
        has_numeric = 0
        for (f = 1; f <= NF; f++) {
            fval = clean_field($f)
            if (AnyFmtNum(fval)) {
                has_numeric = 1
                break
            }
        }
        
        # If second row has numeric fields, first row was likely headers
        if (has_numeric) {
            header = 1
            # Process first row as headers
            for (f = 1; f <= FirstRowNF; f++) {
                Headers[f] = FirstRow[f]
                # Clean header name (remove whitespace, but keep original for display)
                gsub(/[[:space:]]+/, " ", Headers[f])
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", Headers[f])
            }
        }
        # Continue to process this row (NR == 2) as data
    }
    
    for (f = 1; f <= NF; f++) {
        if (fields && !SelectedFields[f]) continue
        
        fval = clean_field($f)
        if (!AnyFmtNum(fval)) {
            continue  # Skip non-numeric field, but continue with other fields
        }
        
        # Check if original value is an integer BEFORE normalization
        # An integer value matches: optional sign, digits only, no decimal point
        is_integer = (fval ~ /^-?[0-9]+$/)
        
        # Convert to numeric before normalization to preserve precision
        # Use the actual numeric value for binning, not the truncated display value
        numeric_fval = fval + 0
        fval = normalize_value(fval)  # Keep for statistics if needed
        
        # Store the actual numeric value for accurate binning
        store_value(f, numeric_fval, is_integer)
        
        # Collect data for statistics (use actual numeric value, not normalized)
        if (stats) {
            Sum[f] += numeric_fval
            SumSq[f] += numeric_fval * numeric_fval
        }
    }
}

END {
    for (f in Rec) {
        if (!MaxFSet[f]) continue
        
        # Build bins
        bin_edges = build_bins(f, FieldMax[f], FieldMin[f], n_bins)
        # Split into temporary array, then copy to Edges using composite keys
        split(bin_edges, TmpEdges, ",")
        # Use actual number of bins (may be reduced for integer fields)
        actual_n_bins = (f in ActualBins) ? ActualBins[f] : n_bins
        for (b = 1; b <= actual_n_bins; b++)
            Edges[f, b] = TmpEdges[b]
        
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

function store_value(f, val, is_integer_val) {
    if (!Counts[f, val]) Rec[f]++
    Counts[f, val]++
    
    # Track if field contains only integer values
    # Check based on the original string value, not the normalized numeric value
    # Initialize on first value, set to false if we find any non-integer
    if (!MaxFSet[f]) {
        FieldMax[f] = val
        FieldMin[f] = val
        MaxFSet[f] = 1
        IsIntegerField[f] = is_integer_val ? 1 : 0
    } else {
        if (val < FieldMin[f]) FieldMin[f] = val
        if (val > FieldMax[f]) FieldMax[f] = val
        # If any value is not an integer, mark the field as non-integer
        if (IsIntegerField[f] && !is_integer_val) {
            IsIntegerField[f] = 0
        }
    }
}

function build_bins(f, max, min, n_bins,    bin_size, b, bin_edge, range, actual_n_bins) {
    # If field contains only integers, use integer binning
    if (IsIntegerField[f]) {
        range = max - min
        # Reduce n_bins if range is smaller than requested bins
        actual_n_bins = (range < n_bins) ? range + 1 : n_bins
        
        # For integer fields, create bins that align to integer boundaries
        if (range == 0) {
            # Single value case - create one bin
            bins = (max + 0.5)","
            actual_n_bins = 1
        } else if (actual_n_bins == 1) {
            # Single bin covering the range
            bins = (max + 0.5)","
        } else {
            # Create integer-aligned bins
            # For integer fields with small range, create bins that cover integer ranges
            # e.g., if range is 5 (values 1-6), create bins: [1,2), [2,3), [3,4), [4,5), [5,6)
            # Bin edges are at half-integers to separate integers cleanly
            bins = ""
            # Distribute bins across the integer range
            int_range = int(max) - int(min) + 1
            if (actual_n_bins >= int_range) {
                # More bins than integers: create one bin per integer (or fewer bins)
                actual_n_bins = int_range  # Use actual integer range
                for (b = 1; b <= actual_n_bins; b++) {
                    bin_edge = int(min) + b - 1 + 0.5
                    bins = bins bin_edge","
                }
            } else {
                # Fewer bins than integers: group integers into bins
                bin_size = range / actual_n_bins
                for (b = 1; b <= actual_n_bins; b++) {
                    bin_edge = min + b * bin_size
                    # Round to nearest half-integer for clean integer separation
                    bin_edge = int(bin_edge) + 0.5
                    bins = bins bin_edge","
                }
            }
        }
        # Store actual number of bins used for this field
        ActualBins[f] = actual_n_bins
        return bins
    }
    
    # Non-integer fields: use standard binning
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
    ActualBins[f] = n_bins
    return bins
}

function assign_to_bins(f,    c, val, b, actual_n_bins) {
    actual_n_bins = (f in ActualBins) ? ActualBins[f] : n_bins
    for (c in Counts) {
        split(c, CountDesc, SUBSEP)
        if (CountDesc[1] != f) continue
        
        val = CountDesc[2]
        for (b = 1; b <= actual_n_bins; b++) {
            if (val <= Edges[f, b]) {
                Bin[f, b] += Counts[c]
                if (Bin[f, b] > MaxBin[f]) MaxBin[f] = Bin[f, b]
                break
            }
        }
    }
    
    # Calculate cumulative counts if requested
    if (cumulative) {
        CumSum[f, 1] = Bin[f, 1]
        for (b = 2; b <= actual_n_bins; b++) {
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
    if (count > 0) {
        SortArray(vals, 1, count)
    }
    
    # Return median
    if (count == 0) return 0
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
    if (count > 0) {
        SortArray(vals, 1, count)
    }
    
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
    if (Headers[f]) {
        header = "Hist: " Headers[f] " (field " f ")"
    } else {
        header = "Hist: field " f
    }
    header = header ", cardinality " Rec[f]
    print header
    
    # Print statistics if requested
    if (stats) {
        printf "Mean: %.4g, Median: %.4g\n", Stats[f, "mean"], Stats[f, "median"]
        printf "StdDev: %.4g, Variance: %.4g\n", Stats[f, "stddev"], Stats[f, "variance"]
        
        # Check if skewness was calculated (composite key exists)
        skew_key = f SUBSEP "skewness"
        if (skew_key in Stats) {
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
    # Use actual number of bins for this field
    actual_n_bins = (f in ActualBins) ? ActualBins[f] : n_bins
    
    # Determine appropriate precision for bin edges based on bin size
    bin_precision = determine_precision_for_bins(f, actual_n_bins)
    
    # Use a generous fixed width for range display to ensure consistent alignment
    # across all histograms. Right-align the entire range string as a single unit.
    edges_len = 25  # Fixed width - generous enough for most ranges
    len_mod = (MaxBin[f] > max_bar_len && MaxBin[f] != 0) ? max_bar_len / MaxBin[f] : 1
    
    # Print bins
    for (b = 1; b <= actual_n_bins; b++) {
        # Format bin edges
        # For integer fields, adjust display to show integer ranges
        if (IsIntegerField[f]) {
            # For integer bins, edges are at half-integers (e.g., 1.5, 2.5, 3.5)
            # Bin 1 contains values < 1.5 (i.e., value 1)
            # Bin 2 contains values >= 1.5 and < 2.5 (i.e., value 2)
            # So we extract the integer value represented by each bin
            if (b == 1) {
                # First bin: from FieldMin[f] to first edge (e.g., < 1.5 → value 1)
                start_int = int(FieldMin[f])
                end_int = int(Edges[f, b] - 0.5)
            } else {
                # Subsequent bins: previous edge to current edge
                # Previous edge was, e.g., 1.5, so this bin starts at 2 (int(1.5 - 0.5) + 1)
                prev_edge = Edges[f, b-1]
                start_int = int(prev_edge - 0.5) + 1
                end_int = int(Edges[f, b] - 0.5)
            }
            
            # Display format: single integer if start == end, range otherwise
            if (start_int == end_int) {
                range_str = sprintf("%.0f", start_int)
            } else {
                range_str = sprintf("%.0f", start_int) " - " sprintf("%.0f", end_int)
            }
        } else {
            start_edge = b == 1 ? FieldMin[f] : Edges[f, b-1]
            end_edge = Edges[f, b]
            range_str = format_number(start_edge, bin_precision) " - " format_number(end_edge, bin_precision)
        }
        
        # Right-align the entire range string within the fixed width
        bin_label = sprintf("%"edges_len"s", range_str)
        
        # Calculate bar length
        count = cumulative ? CumSum[f, b] : Bin[f, b]
        bar_len = int(count * len_mod)
        
        # Print bin label (right-aligned) followed by space and bar (left-aligned)
        printf "%s ", bin_label
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
            # Print bar character by character for proper Unicode handling
            for (i = 1; i <= bar_len; i++)
                printf "%s", BAR_CHAR
        }
        
        if (color) printf "%s", COLORS["reset"]
        
        # Print count
        printf " (%d)\n", count
    }
    print ""
}

function format_number(val, precision) {
    # Use decimal notation for reasonable ranges, scientific notation for extreme values
    abs_val = val < 0 ? -val : val
    
    # If precision is explicitly provided, use it
    if (precision != "") {
        return sprintf("%." precision "f", val)
    }
    
    # For values between -10000 and 10000, use decimal notation
    if (abs_val < 10000 && abs_val >= 0.001) {
        # Determine appropriate decimal places based on value size
        if (abs_val >= 1000) {
            return sprintf("%.0f", val)
        } else if (abs_val >= 100) {
            return sprintf("%.1f", val)
        } else if (abs_val >= 10) {
            return sprintf("%.2f", val)
        } else if (abs_val >= 1) {
            return sprintf("%.3f", val)
        } else {
            return sprintf("%.4f", val)
        }
    }
    # For extreme values, use scientific notation
    return sprintf("%.2g", val)
}

function determine_precision_for_bins(f,    range, bin_size, magnitude, precision, actual_n_bins) {
    # Determine appropriate precision for bin edge display
    # based on the bin size and magnitude of values
    range = FieldMax[f] - FieldMin[f]
    actual_n_bins = (f in ActualBins) ? ActualBins[f] : n_bins
    bin_size = range / actual_n_bins
    
    magnitude = FieldMax[f] < 0 ? -FieldMax[f] : FieldMax[f]
    
    if (magnitude == 0 || bin_size == 0) {
        return 2
    }
    
    # Calculate precision needed to distinguish bin edges
    # We need enough decimal places so that bin_size is visible
    # For example, if bin_size is 0.02, we need at least 2 decimal places
    
    # Calculate decimal places needed using logarithm
    # If bin_size is 0.02, log10(0.02) ≈ -1.699, so -log10(0.02) ≈ 1.699, int(1.699)+1 = 2
    # If bin_size is 0.002, log10(0.002) ≈ -2.699, so -log10(0.002) ≈ 2.699, int(2.699)+1 = 3
    bin_log = -log(bin_size) / log(10)
    precision = int(bin_log) + 1
    if (precision < 1) precision = 1
    if (precision > 6) precision = 6  # Cap at reasonable limit
    
    return precision
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

function SortArray(arr, left, right,    i, last, pivot_idx) {
    if (left >= right) return
    
    # For small subarrays, use simple insertion sort (more efficient)
    if ((right - left) < 10) {
        InsertionSort(arr, left, right)
        return
    }
    
    # Use random pivot for better average performance
    pivot_idx = left + int((right-left+1)*rand())
    Swap(arr, left, pivot_idx)
    last = left
    
    for (i = left+1; i <= right; i++) {
        if (arr[i] < arr[left]) {
            Swap(arr, ++last, i)
        }
    }
    
    Swap(arr, left, last)
    SortArray(arr, left, last-1)
    SortArray(arr, last+1, right)
}

function InsertionSort(arr, left, right,    i, j, key) {
    for (i = left+1; i <= right; i++) {
        key = arr[i]
        j = i - 1
        while (j >= left && arr[j] > key) {
            arr[j+1] = arr[j]
            j--
        }
        arr[j+1] = key
    }
}

function Swap(arr, i, j,    t) {
    t = arr[i]; arr[i] = arr[j]; arr[j] = t
}

