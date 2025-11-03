#!/usr/bin/awk
#
# DS:PLOT - Terminal-based data visualization
#
# SYNOPSIS
#     ds:plot [file] [-v options]
#
# DESCRIPTION
#     Create terminal-based scatter plots from columnar data. Displays data points
#     as characters in a terminal grid. Points are represented by style characters
#     with intensity based on point density at each location. Multiple points at
#     the same grid location are shown with progressively darker/higher intensity
#     characters.
#
#     NOTE: This command currently supports only scatter plots. Line plots, histograms,
#     heatmaps, color output, grid lines, and axis labels are not available.
#
# OPTIONS
#     x=N            X-axis column number (default: 1)
#     y=N            Y-axis column number (default: 2)
#     width=N        Plot width in characters (default: 80)
#     height=N       Plot height in characters (default: 24)
#     header=1       Data has header row (first row is skipped as column names)
#     style=STYLE    Plot style: dots, blocks, braille, ascii (default: dots)
#     format=STR     Number format for internal processing (e.g., "%.2f")
#     range=STR      Custom axis range "xmin,xmax,ymin,ymax"
#
# STYLES
#     dots:    • · ⋅     (default, light to dark)
#     blocks:  ░ ▒ ▓ █   (shade gradient)
#     braille: ⠁ ⠂ ⠃ ⠄ ⠅ ⠿ (braille dots pattern)
#     ascii:   . + #     (simple ASCII)
#
# OUTPUT
#     The plot displays data points mapped to a character grid. After the plot
#     visualization, statistics are displayed:
#     - Points: Number of data points plotted
#     - X range: Minimum and maximum X values
#     - Y range: Minimum and maximum Y values
#     - X cardinality: Number of unique X values
#     - Y cardinality: Number of unique Y values
#
# EXAMPLES
#     # Basic scatter plot from stdin
#     $ cat data.csv | ds:plot -v x=1 -v y=2
#
#     # Plot with custom dimensions
#     $ ds:plot data.csv -v width=60 -v height=20
#
#     # Plot with blocks style
#     $ ds:plot data.csv -v style=blocks
#
#     # Plot with custom axis range
#     $ ds:plot data.csv -v range="0,100,0,50"
#

BEGIN {
    # Initialize parameters
    if (!x) x = 1
    if (!y) y = 2
    # Only scatter plots are supported
    type = "scatter"
    if (!style) style = "dots"
    if (!width) width = 80
    if (!height) height = 24
    if (!format) format = "%.2f"
    
    # Validate parameters
    style = tolower(style)
    # Other plot types are not available
    if (type && type != "scatter" && type != "") {
        print "ERROR: Only scatter plots are supported"
        exit 1
    }
    
    # Set up plot characters based on style
    setup_plot_chars()
    
    # Color and other advanced features are disabled
    color = 0
    grid = 0
    labels = 0
    title = ""
    xlab = ""
    ylab = ""
    
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
    
    # Draw plot elements (title and labels are disabled)
    draw_plot()
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
        PlotMax[dim] = val
        PlotMin[dim] = val
        MaxSet[dim] = 1
    } else {
        if (val < PlotMin[dim]) PlotMin[dim] = val
        if (val > PlotMax[dim]) PlotMax[dim] = val
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
        range_x = PlotMax["x"] - PlotMin["x"]
        range_y = PlotMax["y"] - PlotMin["y"]
        PlotMinX = PlotMin["x"] - range_x * padding
        PlotMaxX = PlotMax["x"] + range_x * padding
        PlotMinY = PlotMin["y"] - range_y * padding
        PlotMaxY = PlotMax["y"] + range_y * padding
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
    printf "X range: [%g, %g]\n", PlotMin["x"], PlotMax["x"]
    printf "Y range: [%g, %g]\n", PlotMin["y"], PlotMax["y"]
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

