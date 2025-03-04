#!/usr/bin/awk
#
# DS:PLOT - Terminal-based data visualization
#
# SYNOPSIS
#     ds:plot [file] [-v options]
#
# DESCRIPTION
#     Create terminal-based plots from columnar data. Supports scatter plots,
#     line plots, histograms, and heatmaps with customizable styling.
#
# OPTIONS
#     x=N            X-axis column number (default: 1)
#     y=N            Y-axis column number (default: 2)
#     type=TYPE      Plot type: scatter, line, hist, heatmap (default: scatter)
#     width=N        Plot width in characters (default: 80)
#     height=N       Plot height in characters (default: 24)
#     header=1       Data has header row
#     style=STYLE    Plot style: dots, blocks, braille, ascii (default: dots)
#     color=1        Enable color output
#     grid=1         Show grid lines
#     labels=1       Show axis labels
#     title=STR      Plot title
#     xlab=STR       X-axis label
#     ylab=STR       Y-axis label
#     format=STR     Number format (e.g., "%.2f")
#     range=STR      Custom axis range "xmin,xmax,ymin,ymax"
#
# STYLES
#     dots:    • · ⋅     (default)
#     blocks:  █ ▄ ▀ ░ ▒ ▓
#     braille: ⠁ ⠂ ⠃ ⠄ ⠅
#     ascii:   # * + .
#
# EXAMPLES
#     # Basic scatter plot
#     $ cat data.csv | ds:plot -v x=1 -v y=2
#
#     # Colored line plot with title
#     $ ds:plot data.csv -v type=line -v color=1 -v title="Sales Trend"
#
#     # Heatmap with custom range
#     $ ds:plot data.csv -v type=heatmap -v range="0,100,0,50"
#

BEGIN {
    # Initialize parameters
    if (!x) x = 1
    if (!y) y = 2
    if (!type) type = "scatter"
    if (!style) style = "dots"
    if (!width) width = 80
    if (!height) height = 24
    if (!format) format = "%.2f"
    
    # Validate parameters
    type = tolower(type)
    style = tolower(style)
    if (!(type ~ /^(scatter|line|hist|heatmap)$/)) {
        print "ERROR: Invalid plot type. Use: scatter, line, hist, or heatmap"
        exit 1
    }
    
    # Set up plot characters based on style
    setup_plot_chars()
    
    # Set up color codes if enabled
    if (color) setup_colors()
    
    # Initialize data structures
    num_re = "^[[:space:]]*\\$?-?\\$?[0-9]*\\.?[0-9]+[[:space:]]*$"
    decimal_re = "^[[:space:]]*\\$?-?\\$?[0-9]*\\.[0-9]+[[:space:]]*$"
    float_re = "^[[:space:]]*-?[0-9]\\.[0-9]+(E|e)(\\+|-)?[0-9]+[[:space:]]*$"
    
    start_unset = 1
    if (header) header_unset = 1
    
    # Parse custom range if provided
    if (range) {
        split(range, RangeParts, ",")
        if (length(RangeParts) == 4) {
            CustomRange = 1
            MinX = RangeParts[1]
            MaxX = RangeParts[2]
            MinY = RangeParts[3]
            MaxY = RangeParts[4]
        }
    }
}

# Data collection phase
{
    if (NR == 1 && header) {
        Headers[x] = clean_field($x)
        Headers[y] = clean_field($y)
        next
    }
    
    # Process X value
    xval = clean_field($x)
    xval = normalize_value(xval)
    store_value("x", xval)
    
    # Process Y value
    yval = clean_field($y)
    yval = normalize_value(yval)
    store_value("y", yval)
    
    # Store raw data point
    Points[NR-header, "x"] = xval
    Points[NR-header, "y"] = yval
    NumPoints++
}

END {
    if (NumPoints == 0) {
        print "ERROR: No valid data points found"
        exit 1
    }
    
    # Calculate plot boundaries
    calculate_boundaries()
    
    # Draw plot elements
    if (title) draw_title()
    draw_plot()
    if (labels) {
        draw_x_axis()
        draw_y_axis()
    }
    print_stats()
}

# Helper Functions

function setup_plot_chars() {
    if (style == "dots") {
        PLOT_CHARS[1] = "⋅"; PLOT_CHARS[2] = "·"; PLOT_CHARS[3] = "•"
    } else if (style == "blocks") {
        PLOT_CHARS[1] = "░"; PLOT_CHARS[2] = "▒"; PLOT_CHARS[3] = "█"
    } else if (style == "braille") {
        PLOT_CHARS[1] = "⠁"; PLOT_CHARS[2] = "⠃"; PLOT_CHARS[3] = "⠿"
    } else {
        PLOT_CHARS[1] = "."; PLOT_CHARS[2] = "+"; PLOT_CHARS[3] = "#"
    }
    GRID_CHAR = "·"
    AXIS_CHAR = "─"
}

function setup_colors() {
    COLORS["reset"] = "\033[0m"
    COLORS["red"] = "\033[31m"
    COLORS["green"] = "\033[32m"
    COLORS["blue"] = "\033[34m"
    COLORS["yellow"] = "\033[33m"
    COLORS["magenta"] = "\033[35m"
    COLORS["cyan"] = "\033[36m"
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

function store_value(dim, val) {
    if (!MaxSet[dim]) {
        Max[dim] = val
        Min[dim] = val
        MaxSet[dim] = 1
    } else {
        if (val < Min[dim]) Min[dim] = val
        if (val > Max[dim]) Max[dim] = val
    }
    Values[dim, val]++
    Cardinality[dim]++
}

function calculate_boundaries() {
    if (CustomRange) {
        PlotMinX = MinX; PlotMaxX = MaxX
        PlotMinY = MinY; PlotMaxY = MaxY
    } else {
        # Add small padding to ranges
        padding = 0.05
        range_x = Max["x"] - Min["x"]
        range_y = Max["y"] - Min["y"]
        PlotMinX = Min["x"] - range_x * padding
        PlotMaxX = Max["x"] + range_x * padding
        PlotMinY = Min["y"] - range_y * padding
        PlotMaxY = Max["y"] + range_y * padding
    }
}

function map_to_plot(val, min, max, size) {
    if (max == min) return int(size/2)
    return int((val - min) / (max - min) * (size-1))
}

function draw_title() {
    padding = int((width - length(title))/2)
    printf "%*s%s\n", padding, "", title
}

function draw_plot() {
    # Clear plot area
    delete Plot
    
    # Map points to plot coordinates
    for (i = 1; i <= NumPoints; i++) {
        px = map_to_plot(Points[i, "x"], PlotMinX, PlotMaxX, width)
        py = map_to_plot(Points[i, "y"], PlotMinY, PlotMaxY, height)
        Plot[px, py]++
        
        if (type == "line" && i > 1) {
            draw_line(last_px, last_py, px, py)
        }
        last_px = px
        last_py = py
    }
    
    # Draw plot
    for (y = height-1; y >= 0; y--) {
        if (grid && y % 2 == 0) draw_grid_line(y)
        for (x = 0; x < width; x++) {
            if (Plot[x, y]) {
                intensity = min(Plot[x, y], 3)
                if (color) printf "%s", COLORS[get_color(Plot[x, y])]
                printf "%s", PLOT_CHARS[intensity]
                if (color) printf "%s", COLORS["reset"]
            }
            else if (grid && x % 5 == 0) printf "%s", GRID_CHAR
            else printf " "
        }
        printf "\n"
    }
}

function draw_grid_line(y) {
    for (x = 0; x < width; x++) {
        if (!Plot[x, y]) Plot[x, y] = -1  # Mark as grid
    }
}

function draw_line(x1, y1, x2, y2,    dx, dy, x, y) {
    dx = x2 - x1
    dy = y2 - y1
    steps = max(abs(dx), abs(dy))
    if (steps == 0) return
    
    x_inc = dx / steps
    y_inc = dy / steps
    
    x = x1; y = y1
    for (i = 0; i <= steps; i++) {
        Plot[int(x), int(y)]++
        x += x_inc
        y += y_inc
    }
}

function draw_x_axis() {
    # Draw axis line
    for (i = 0; i < width; i++) printf "%s", AXIS_CHAR
    printf "\n"
    
    # Draw labels
    labels = 5
    for (i = 0; i <= labels; i++) {
        pos = i * (width-1) / labels
        val = PlotMinX + (PlotMaxX - PlotMinX) * (i/labels)
        printf "%-*s", (i < labels ? pos : 0), sprintf(format, val)
    }
    printf "\n"
    if (xlab) printf "%s\n", xlab
}

function draw_y_axis() {
    # Draw labels on the left
    labels = 5
    for (i = 0; i < height; i++) {
        if (i % int(height/labels) == 0) {
            val = PlotMaxY - (PlotMaxY - PlotMinY) * (i/height)
            printf "%8s ", sprintf(format, val)
        }
    }
}

function print_stats() {
    printf "\nStatistics:\n"
    printf "Points: %d\n", NumPoints
    printf "X range: [%g, %g]\n", Min["x"], Max["x"]
    printf "Y range: [%g, %g]\n", Min["y"], Max["y"]
    printf "X cardinality: %d\n", Cardinality["x"]
    printf "Y cardinality: %d\n", Cardinality["y"]
}

# Utility Functions

function get_color(intensity) {
    if (intensity <= 1) return "blue"
    if (intensity <= 2) return "yellow"
    return "red"
}

function min(a, b) { return a < b ? a : b }
function max(a, b) { return a > b ? a : b }
function abs(x) { return x < 0 ? -x : x }

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

