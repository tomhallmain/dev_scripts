#!/usr/bin/awk
# DS:SHAPE
#
# NAME
#       ds:shape, shape.awk
#
# SYNOPSIS
#       ds:shape [-h|file*] [patterns] [fields] [chart_size=15ln] [awkargs]
#
# DESCRIPTION
#       shape.awk is a script to print the general shape of text-based data.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based 
#       systems it should be), and call it on a file along with the utils.awk helper file:
#
#           > awk -f support/utils.awk -f shape.awk -v measures=[patterns] -v fields=[fields] file
#
#       ds:shape is the caller function for the shape.awk script. To run any of the examples 
#       below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#           $ data_in | ds:shape [patterns] [fields] [chart=t] [chart_size=15ln] [awkargs]
#
# OPTIONS
#       -h                      Print this help
#       -v shape_marker=.       Set custom shape marker (overrides style)
#       -v style=blocks|dots    Set visualization style (default: blocks if wcwidth available, else plus)
#       -v color=1              Enable color output
#       -v normalize=1          Show normalized percentages
#       -v case_sensitive=1     Enable case-sensitive matching (default: 0, case-insensitive)
#       -v vertical=1           Show vertical histogram
#       -v stats=1     Show additional statistics
#       -v progress=1           Show progress during percentile computation (stats only)
#       -v streaming=1          Enable streaming mode for large files
#       -v simple=1             Skip histogram display (stats only)
#       -v header=1             Treat first row as header (shows header names in output)
#
# FIELD CONSIDERATIONS
#       When running ds:shape, an attempt is made to infer field separators of up to
#       three characters. If none found, FS will be set to default value, a single
#       space = " ". To override FS, add as a trailing awkarg. If the two files have
#       different FS, assign to vars fs1 and fs2. Be sure to escape and quote if needed. 
#       AWK's extended regex can be used as FS:
#
#           $ ds:shape file searchtext 2,3 t 15 -v fs1=',' -v fs2=':'
#
#           $ ds:shape file searchtext 2,3 t 15 -v FS=" {2,}"
#
#           $ ds:shape file searchtext 2,3 t 15 -F'\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#           $ ds:shape file searchtext 2,3 t 15 -v FS=""
#
# USAGE
#       If no patterns or fields are provided, ds:shape will test each line for length,
#       and generate statistics and a graphic from the findings. If only a single pattern 
#       is provided, each line will be searched for the pattern.
#
#           lines - total lines in source file
#           lines with [measure] - lines matching pattern or with length
#           occurrence - total counts of pattern (or chars with length)
#           average - occurrences / total lines
#           approx var - crude occurrence variance
#
#       The distribution chart shows gives a representation of the total number of
#       occurrences per bucket. By default there are 15 buckets - to run with custom 
#       [n] buckets set [chart_size] = [n].
#
#       Distribution chart is produced by default, to turn off set [chart_size] = 0
#
#       Separate [fields] with commas. Setting a field != 0 will limit the scope of 
#       measure tests to that field. Each field provided will generate a new chart set.
#
#       [patterns] (measures) can be any regex. Separate patterns with a comma. For easy 
#       comparison each pattern will create a new chart on the same set of lines as 
#       the first.
#
#       Depending on the output space, up to 10 patterns can be displayed per field 
#       section.
#
# OPTS AND AWKARG OPTS
#       Print this help:
#
#           -h
#
#       To set a custom pattern for the shape chart, set shape_marker to any string:
#
#           -v shape_marker=.
#
#       By default the style is "blocks" (using "█") if wcwidth is available, otherwise "plus" (using "+").
#
# VERSION
#       1.0
#
# AUTHORS
#       Tom Hall (tomhallmain@gmail.com)

BEGIN {
    SeedRandom()  # Seed random number generator for efficient quicksort
    
    if (!tty_size) tty_size = 100
    lineno_size = Max(length(lines), 5)
    buffer_str = "                        "
    output_space = tty_size - lineno_size - 2
    original_style = style
    if (!span) span = 15

    # Check if wcwidth functions are available
    # awksafe variable is set by the shell when wcwidth.awk is loaded
    WCWIDTH_AVAILABLE = (awksafe == 1) ? 1 : 0

    # Initialize new options with defaults
    if (!style) style = awksafe ? "blocks" : "plus"
    case_sensitive = case_sensitive ? 1 : 0
    color = color ? 1 : 0
    normalize = normalize ? 1 : 0
    vertical = vertical ? 1 : 0
    stats = stats ? 1 : 0
    progress = progress ? 1 : 0
    streaming = streaming ? 1 : 0
    simple = simple ? 1 : 0  # simple=1 skips histogram display

    # Define visualization styles
    Styles["stars"] = "*"
    Styles["plus"] = "+"
    Styles["equals"] = "="
    Styles["hash"] = "#"
    Styles["dash"] = "-"
    Styles["bar"] = "|"
    Styles["underscore"] = "_"
    # Unicode block and drawing characters
    Styles["blocks"] = "█"
    Styles["dots"] = "•"
    Styles["dark"] = "▓"
    Styles["medium"] = "▒"
    Styles["light"] = "░"
    Styles["full"] = Styles["blocks"]
    Styles["upper"] = "▀"
    Styles["lower"] = "▄"
    Styles["left"] = "▌"
    Styles["right"] = "▐"
    Styles["square"] = "■"
    Styles["circle"] = "●"
    Styles["diamond"] = "◆"
    
    # For multiple measures, default to "plus" style if using Unicode/color and wcwidth unavailable
    # This avoids spacing issues with Unicode characters or color codes in multi-column output
    if (measures_len > 1 && !WCWIDTH_AVAILABLE) {
        # Need wcwidth if using Unicode characters or color codes
        needs_wcwidth = 0
        if (style in Styles && Styles[style] !~ /^[ -~]$/) {
            needs_wcwidth = 1  # Multibyte Unicode characters need proper width calculation
        }
        if (color) {
            needs_wcwidth = 1  # Color codes affect string length but not display width
        }
        
        if (needs_wcwidth && (style == "blocks" || style == "dots" || style == "shade")) {
            style = "plus"
            printf "Warning: Overriding style '%s' to 'plus' for multi-measure output (wcwidth unavailable, Unicode/color may cause spacing issues)\n", original_style > "/dev/stderr"
        }
    }
    
    # Define colors if enabled
    if (color) {
        Colors[1] = "\033[31m" # Red
        Colors[2] = "\033[32m" # Green
        Colors[3] = "\033[34m" # Blue
        Colors[4] = "\033[35m" # Magenta
        Colors[5] = "\033[36m" # Cyan
        ColorReset = "\033[0m"
    }

    if (!measures) measures = "_length_"
    SetMeasures(measures, MeasureSet, MeasureTypes)

    if (!fields) fields = "0"
    split(fields, Fields, ",")
    for (f in Fields) {
        field = Fields[f]
        if (field != "0" && field + 0 == 0) {
            delete Fields[f]
        }
    }
    if (!length(Fields)) {
        Fields[1] = "0"
    }

    if (shape_marker) {
        marker_len = length(shape_marker)
        marker_len_mod = marker_len > 1 ? tty_size / marker_len : tty_size
        for (i = 1; i <= marker_len_mod; i++)
            shape_marker_string = shape_marker_string shape_marker
    }
    else
        for (i = 1; i <= tty_size; i++)
            shape_marker_string = shape_marker_string "+"

    measures_len = length(MeasureSet)
    fields_len = length(Fields)
}

{
    # Capture headers from first row if header variable is set
    if (NR == 1 && header) {
        for (i = 1; i <= NF; i++) {
            # Clean header field (remove leading/trailing whitespace)
            header_val = $i
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", header_val)
            Headers[i] = header_val
        }
        next  # Skip first row if header is set
    }
    
    bucket_discriminant = NR % span
    if (bucket_discriminant == 0) buckets++

    for (f_i = 1; f_i <= fields_len; f_i++) {
        for (m_i = 1; m_i <= measures_len; m_i++) {
            key = f_i SUBSEP m_i
            field = Fields[f_i]
            measure = MeasureSet[m_i]

            # Use case-insensitive matching if enabled
            if (case_sensitive) {
                value = MeasureTypes[m_i] ? split($Fields[f_i], Tmp, measure) - 1 : length($field)
            }
            else {
                value = MeasureTypes[m_i] ? (split(tolower($Fields[f_i]), Tmp, tolower(measure)) - 1) : length($field)
            }
            occurrences = Max(value, 0)

            # Store values for extended statistics
            if (stats) {
                Values[key, ++ValueCount[key]] = occurrences
            }

            if (occurrences > MaxOccurrences[key]) MaxOccurrences[key] = occurrences
            TotalOccurrences[key] += occurrences
            SumSqOccurrences[key] += occurrences * occurrences
            m = Max(Measure(MeasureTypes[m_i], field, occurrences), 0)
            J[key] += m
            if (m) MatchLines[key]++

            if (bucket_discriminant == 0) {
                if (J[key] > MaxJ[key]) MaxJ[key] = J[key]
                _[key, NR/span] = J[key]
                J[key] = 0
            }
        }
    }
}

END {
    for (f_i = 1; f_i <= fields_len; f_i++) {
        for (m_i = 1; m_i <= measures_len; m_i++) {
            key = f_i SUBSEP m_i

            if (bucket_discriminant) {
                J[key] = J[key] / bucket_discriminant * span
                if (J[key] > MaxJ[key]) MaxJ[key] = J[key]
                l = (NR - J[key] + span) / span
                _[f_i, m_i, l] = J[f_i, m_i]
            }

            AvgOccurrences[key] = TotalOccurrences[key] / NR
            # Calculate approximate variance: E[X^2] - (E[X])^2
            ApproxVar[key] = (SumSqOccurrences[key] / NR) - (AvgOccurrences[key] * AvgOccurrences[key])
            if (MaxJ[key]) match_found = 1
        }
    }

    if (!match_found) {
        print "Data not found with given parameters"
        exit
    }

    output_column_len = int(output_space / measures_len) - 1
    output_column_len_1 = output_column_len + lineno_size + 2
    column_fmt = "%-"output_column_len"s "

    PrintLineNoBuffer()
    print "lines: "NR

    for (f_i = 1; f_i <= fields_len; f_i++) {
        field = Fields[f_i]
        if (fields_len > 1 || field) {
            PrintLineNoBuffer()
            # Use header name if available, otherwise use field index
            if (Headers[field + 0]) {
                print "stats from field: $"field" ("Headers[field + 0]")"
            }
            else {
                print "stats from field: $"field
            }
        }

        PrintLineNoBuffer()
        for (m_i = 1; m_i <= measures_len; m_i++) {
            key = f_i SUBSEP m_i
            lines_with = MatchLines[key]
            if (stats) {
                pct_lines = lines_with > 0 ? (lines_with / NR * 100) : 0
                PrintColumnVal("lines with \""MeasureSet[m_i]"\": "lines_with" ("sprintf("%.2f", pct_lines)"%)")
            } else {
                PrintColumnVal("lines with \""MeasureSet[m_i]"\": "lines_with)
            }
        }
        print ""

        PrintLineNoBuffer()
        for (m_i = 1; m_i <= measures_len; m_i++)
            PrintColumnVal("occurrence: "TotalOccurrences[f_i, m_i])
        print ""

        PrintLineNoBuffer()
        for (m_i = 1; m_i <= measures_len; m_i++) {
            key = f_i SUBSEP m_i
            avg = AvgOccurrences[key]
            if (stats) {
                pct_prob = avg * 100
                PrintColumnVal("average: "avg" ("sprintf("%.2f", pct_prob)"% probability)")
            } else {
                PrintColumnVal("average: "avg)
            }
        }
        print ""

        if (stats) {
            PrintLineNoBuffer()
            for (m_i = 1; m_i <= measures_len; m_i++)
                PrintColumnVal("approx var: "ApproxVar[f_i, m_i])
            print ""
            # Pre-compute percentiles for all measures first
            # Track if any measure has records with zero occurrences (so we know if filtering occurred)
            has_zero_occurrences = 0
            total_measures = 0
            for (m_i = 1; m_i <= measures_len; m_i++) {
                key = f_i SUBSEP m_i
                if (ValueCount[key] > 0) {
                    total_measures++
                    if (!has_zero_occurrences) {
                        # Check if all values are non-zero by comparing total count with non-zero count
                        count = ValueCount[key]
                        non_zero_count = 0
                        for (i = 1; i <= count; i++) {
                            if (Values[key, i] > 0) non_zero_count++
                        }
                        if (non_zero_count < count) has_zero_occurrences = 1
                    }
                }
            }
            # Compute percentiles with progress indicator
            measure_idx = 0
            for (m_i = 1; m_i <= measures_len; m_i++) {
                key = f_i SUBSEP m_i
                if (ValueCount[key] > 0) {
                    measure_idx++
                    if (progress && total_measures > 0) {
                        ShowProgress(measure_idx-1, total_measures)
                    }
                    SortAndComputePercentiles(key)
                    if (progress && total_measures > 0) {
                        ShowProgress(measure_idx, total_measures)
                    }
                }
            }
            if (progress && total_measures > 0) {
                print "" > "/dev/stderr"  # Newline after progress
            }
            
            # Print explanatory note only if some records had zero occurrences
            if (has_zero_occurrences) {
                PrintLineNoBuffer()
                print "(percentiles computed from records with occurrences)"
            }
            
            # Print percentiles in columns for all measures
            PrintLineNoBuffer()
            for (m_i = 1; m_i <= measures_len; m_i++) {
                key = f_i SUBSEP m_i
                if (ValueCount[key] > 0) {
                    PrintColumnVal("25th percentile: " PercentileCache[key, 25])
                } else {
                    PrintColumnVal("25th percentile: N/A")
                }
            }
            print ""
            
            PrintLineNoBuffer()
            for (m_i = 1; m_i <= measures_len; m_i++) {
                key = f_i SUBSEP m_i
                if (ValueCount[key] > 0) {
                    PrintColumnVal("median: " PercentileCache[key, 50])
                } else {
                    PrintColumnVal("median: N/A")
                }
            }
            print ""
            
            PrintLineNoBuffer()
            for (m_i = 1; m_i <= measures_len; m_i++) {
                key = f_i SUBSEP m_i
                if (ValueCount[key] > 0) {
                    PrintColumnVal("75th percentile: " PercentileCache[key, 75])
                } else {
                    PrintColumnVal("75th percentile: N/A")
                }
            }
            print ""
        }

        if (!simple) {
            printf "%"lineno_size"s ", "lineno"

            for (m_i = 1; m_i <= measures_len; m_i++) {
                key = f_i SUBSEP m_i
                ModJ[key] = MaxJ[key] <= output_column_len ? 1 : output_column_len / MaxJ[key]
            }

            for (m_i = 1; m_i <= measures_len; m_i++) {
                measure_desc = MeasureTypes[m_i] ? "\""MeasureSet[m_i]"\"" : "length"
                PrintColumnVal("distribution of "measure_desc)
            }
            print ""

            buckets++

            # Apply selected style and color
            # Build marker string based on style for horizontal histograms
            if (style in Styles) {
                marker_char = Styles[style]
                current_marker = ""
                for (i = 1; i <= output_column_len; i++)
                    current_marker = current_marker marker_char
            }
            else {
                current_marker = shape_marker_string
                # For vertical histogram, use first char of shape_marker or default "+"
                marker_char = shape_marker ? substr(shape_marker, 1, 1) : "+"
            }
            
            for (i = 1; i <= buckets; i++) {
                if (!vertical) {
                    printf " %"lineno_size"s ", i * span

                    for (m_i = 1; m_i <= measures_len; m_i++) {
                        key = f_i SUBSEP m_i
                        value = _[key, i] * ModJ[key]
                        # Avoid division by zero if MaxJ[key] is 0
                        if (normalize && MaxJ[key] > 0) {
                            value = (value / MaxJ[key]) * output_column_len
                        }
                        
                        # Convert value to integer for string length
                        bar_length = int(value + 0.5)  # Round to nearest integer
                        if (bar_length < 0) bar_length = 0
                        if (bar_length > output_column_len) bar_length = output_column_len
                        
                        # Build bar string using substr for proper character handling
                        if (style in Styles) {
                            # For style markers, build string character by character
                            shape_marker = ""
                            for (j = 1; j <= bar_length; j++)
                                shape_marker = shape_marker marker_char
                            
                        } else {
                            # For default markers, use substr
                            shape_marker = substr(current_marker, 1, bar_length)
                        }
                        
                        # Build final string with color codes inside to maintain column alignment
                        if (color) {
                            shape_marker = Colors[(m_i-1) % 5 + 1] shape_marker ColorReset
                        }
                        
                        # Adjust padding for Unicode characters or color codes using wcwidth
                        # PrintColumnVal pads based on string length (bytes), not display width (columns)
                        # For Unicode/color: string_length > display_width, causing under-padding
                        # Solution: Add spaces to shape_marker to reach target display width
                        # This ensures PrintColumnVal's padding results in correct total display width
                        if (WCWIDTH_AVAILABLE && (marker_char !~ /^[ -~]$/ || color)) {
                            display_width = wcscolumns(shape_marker)
                            if (display_width < output_column_len) {
                                spaces_to_add = output_column_len - display_width
                                for (pad = 0; pad < spaces_to_add; pad++) {
                                    shape_marker = shape_marker " "
                                }
                            }
                        }
                        
                        PrintColumnVal(shape_marker)
                    }
                    print ""
                }
            }

            # Add vertical histogram if enabled
            if (vertical) {
                # Calculate maximum height
                max_height = 10  # Default height for vertical display
                for (i = max_height; i > 0; i--) {
                    printf "%3d%% |", (i/max_height) * 100
                    for (m_i = 1; m_i <= measures_len; m_i++) {
                        key = f_i SUBSEP m_i
                        for (b = 1; b <= buckets; b++) {
                            # Avoid division by zero if MaxJ[key] is 0
                            if (MaxJ[key] > 0) {
                                normalized = (_[key, b] * ModJ[key] / MaxJ[key])
                            } else {
                                normalized = 0
                            }
                            if (normalized >= i/max_height) {
                                if (color) printf "%s", Colors[(m_i-1) % 5 + 1]
                                printf "%s", marker_char
                                if (color) printf "%s", ColorReset
                            } else {
                                printf " "
                            }
                        }
                        printf "  "
                    }
                    print ""
                }
                # Print x-axis
                printf "     +"
                for (m_i = 1; m_i <= measures_len; m_i++) {
                    for (b = 1; b <= buckets; b++) printf "-"
                    printf "  "
                }
                print ""
            }
        }
    }
}

function SetMeasures(measures, MeasureSet, MeasureTypes) {
    split(measures, MeasureSet, ",")
    for (i = 1; i <= length(MeasureSet); i++) {
        measure = MeasureSet[i]
        if ("_length_" ~ "^"measure) {
            MeasureSet[i] = "length"
            MeasureTypes[i] = 0
        }
        else {
            MeasureTypes[i] = 1
        }
    }
}

function Measure(measure, field, occurrences) {
    if (measure) {
        if (measure == 1) return occurrences
    }
    else return length($field)
}

function PrintLineNoBuffer() {
    if (simple) return
    printf "%.*s", lineno_size + 2, buffer_str
}

function PrintColumnVal(print_string) {
    printf column_fmt, print_string
}


function SortArray(arr, left, right,    i, last, pivot_idx) {
    if (left >= right) return
    
    # For small subarrays, use simple insertion sort (more efficient)
    if ((right - left) < 10) {
        InsertionSort(arr, left, right)
        return
    }
    
    # Use random pivot like QSA in utils.awk for better average performance
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

function SortAndComputePercentiles(key,    sorted_arr, non_zero_arr, i, count, non_zero_count, p, percentiles, sum_vals) {
    # Collect all values from Values[key, *] into arrays
    # Values is indexed as Values[key, ValueCount[key]]
    count = ValueCount[key]
    if (debug_sort) printf "SortAndComputePercentiles: key=%s count=%d\n", key, count > "/dev/stderr"
    
    if (count == 0) return
    
    non_zero_count = 0
    sum_vals = 0
    for (i = 1; i <= count; i++) {
        if (Values[key, i] > 0) {
            non_zero_arr[++non_zero_count] = Values[key, i]
        }
        sum_vals += Values[key, i]
        if (debug_sort && i <= 10) printf "SortAndComputePercentiles: Values[%s,%d]=%d\n", key, i, Values[key, i] > "/dev/stderr"
    }
    if (debug_sort) printf "SortAndComputePercentiles: total=%d non_zero=%d\n", sum_vals, non_zero_count > "/dev/stderr"
    
    # If no non-zero values, all percentiles are 0
    if (non_zero_count == 0) {
        PercentileCache[key, 25] = 0
        PercentileCache[key, 50] = 0
        PercentileCache[key, 75] = 0
        return
    }
    
    if (non_zero_count == 1) {
        PercentileCache[key, 25] = non_zero_arr[1]
        PercentileCache[key, 50] = non_zero_arr[1]
        PercentileCache[key, 75] = non_zero_arr[1]
        return
    }
    
    if (debug_sort) printf "SortAndComputePercentiles: starting sort of %d non-zero elements\n", non_zero_count > "/dev/stderr"
    
    # Sort only the non-zero values using QSA-style quicksort
    SortArray(non_zero_arr, 1, non_zero_count)
    
    if (debug_sort) {
        printf "SortAndComputePercentiles: sort completed, sample of sorted: " > "/dev/stderr"
        for (i = 1; i <= 10 && i <= non_zero_count; i++) {
            printf "%d ", non_zero_arr[i] > "/dev/stderr"
        }
        if (non_zero_count > 10) {
            printf "... " > "/dev/stderr"
            for (i = non_zero_count - 9; i <= non_zero_count && i > 10; i++) {
                printf "%d ", non_zero_arr[i] > "/dev/stderr"
            }
        }
        printf "\n" > "/dev/stderr"
    }
    
    # Compute percentiles only from non-zero values (more meaningful for sparse data)
    split("25,50,75", percentiles, ",")
    for (p_idx = 1; p_idx <= length(percentiles); p_idx++) {
        p = percentiles[p_idx]
        i = p * non_zero_count / 100
        if (i != int(i)) {
            PercentileCache[key, p] = non_zero_arr[int(i) + 1]
        } else if (i == 0) {
            PercentileCache[key, p] = non_zero_arr[1]
        } else if (i >= non_zero_count) {
            PercentileCache[key, p] = non_zero_arr[non_zero_count]
        } else {
            PercentileCache[key, p] = (non_zero_arr[i] + non_zero_arr[i + 1]) / 2
        }
        if (debug_sort) printf "SortAndComputePercentiles: p=%d idx=%d result=%d\n", p, i, PercentileCache[key, p] > "/dev/stderr"
    }
}

function Percentile(key, p) {
    # Return cached value if available, otherwise compute on demand
    if (key SUBSEP p in PercentileCache) {
        return PercentileCache[key, p]
    }
    # Fallback for percentiles not pre-computed (shouldn't happen with stats)
    SortAndComputePercentiles(key)
    return PercentileCache[key, p]
}

function Median(key) {
    return Percentile(key, 50)
}

function SmartMatch(str, pattern) {
    if (case_sensitive) return str ~ pattern
    return tolower(str) ~ tolower(pattern)
}

function ShowProgress(current, total) {
    if (progress && total > 0 && (current % 1000 == 0 || current == total)) {
        printf "\rProcessing percentiles for measure: %d/%d (%d%%)", current, total, (current/total)*100 > "/dev/stderr"
    }
}

