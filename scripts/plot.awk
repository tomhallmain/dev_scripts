#!/usr/bin/awk
#
# Script to print a scatter plot in terminal based on columnar data
#
# > awk -f hist.awk file

BEGIN {
    if (!x) x = 1
    if (!y) y = 1
    if (x == y) {
        index_dim = 1
        x = -1
        MaxFSet[x] = 1
    }
    if (!width) width = 80
    if (!height) height = 80
    if (!plot_char) plot_char = "\xe2\x80\xa2" # Bullet character

    num_re = "^[[:space:]]*\\$?-?\\$?[0-9]*\\.?[0-9]+[[:space:]]*$"
    decimal_re = "^[[:space:]]*\\$?-?\\$?[0-9]*\\.[0-9]+[[:space:]]*$"
    float_re = "^[[:space:]]*-?[0-9]\.[0-9]+(E|e)(\\+|-)?[0-9]+[[:space:]]*$"
    
    start_unset = 1
    if (header) {
        header_unset = 1
    }
}

start_unset && !($0 ~ /^[ ]*$/) {
    start_unset = 0
    start_index = NR
}

{
    if (index_dim) {
        xval = NR
        Max[x] = xval
    }
    else {
        xval = $x

        if (!AnyFmtNum(xval)) {
            if (NR == 1) {
                gsub("[[:space:]]+", "", xval)
                gsub(",", "", xval)
                Headers[f] = xval
            }
            else {
                xval = 0
            }
        }

        gsub("[[:space:]]+", "", xval)
        gsub("\\(", "-", xval)
        gsub("\\)", "", xval)
        gsub("\\$", "", xval)
        gsub(",", "", xval)
        xval = GetOrSetTruncVal(xval)

        if (!Counts[x, xval]) Rec[x]++
        Counts[x, xval]++

        if (!MaxFSet[x]) {
            Max[x] = xval
            MaxFSet[x] = 1
        }

        if (xval < Min[x] || !Min[x]) Min[x] = xval
        else if (xval > Max[x]) Max[x] = xval
    }

    yval = $y
    if (!AnyFmtNum(yval)) {
        if (NR == 1 && header) {
            gsub("[[:space:]]+", "", yval)
            gsub(",", "", yval)
            Headers[f] = yval
        }
        else if (yval == "-inf" || yval == "inf") {
            yval = -1
        }
        else {
            yval = 0
        }
    }

    gsub("[[:space:]]+", "", yval)
    gsub("\\(", "-", yval)
    gsub("\\)", "", yval)
    gsub("\\$", "", yval)
    gsub(",", "", yval)
    yval = GetOrSetTruncVal(yval)

    if (!Counts[y, yval]) Rec[y]++
    Counts[y, yval]++

    if (!MaxFSet[y]) {
        Max[y] = yval
        MaxFSet[y] = 1
    }

    if (yval < Min[y] || !Min[y]) Min[y] = yval
    else if (yval > Max[y]) Max[y] = yval

    PlotRaw[xval, yval] = 1
}

END {
    if (!Max[x] || !Max[y]) {
        print "No max value found for one or more dimensions."
    }

    if (index_dim) {
        Min[x] = start_index
    }
    
    if (length(Max[x]) > max_len) max_len = length(Max[x])
    if (length(Min[x]) > max_len) max_len = length(Min[x])
    if (length(Max[y]) > max_len) max_len = length(Max[y])
    if (length(Min[y]) > max_len) max_len = length(Min[y])
    
    BuildBins(x, Bins, Max[x], Min[x], width / 10)
    BuildBins(y, Bins, Max[y], Min[y], height / 10)
    split(Bins[x], FBins, ",")
    NormalizeValues(Plot, PlotRaw, Max[x], Min[x], Max[y], Min[y])

    for (point_y = height; point_y >= 0; point_y--) {
        for (point_x = 1; point_x <= width; point_x++) {
            if (Plot[point_x, point_y]) {
                printf "%s", plot_char
            }
            else {
                printf " "
            }
        }
        print ""
    }
    
    for (b = 1; b <= width; b++) {
        printf "–"
    }

    print ""

    for (b = 1; b < length(FBins); b++) {
        axis_label = b == 1 ? Min[x] : FBins[b-1]
        printf "%-"(int(width/20))"s", int(axis_label)
    }

    print ""
    
    print "Cardinality X: " (index_dim ? Max[x] : Rec[x])
    print "Cardinality Y: " Rec[y]

}

function NormalizeValues(Plot, PlotRaw, max_x, min_x, max_y, min_y,   x,y) {
    for (x_y in PlotRaw) {
        split(x_y, X_Y, SUBSEP)
        x = X_Y[1]
        y = X_Y[2]
        new_x = x - min_x + 1
        new_x /= max_x
        new_x *= width
        new_x = Round(new_x)
        new_y = y - min_y + 1
        new_y /= max_y
        new_y *= height
        new_y = Round(new_y)
        #print x, y
        #print new_x, new_y
        Plot[new_x, new_y] = 1
    }
}

function BuildBins(f, Bins, max, min, n_bins) {
    bin_size = (max - min) / n_bins
    for (b = 1; b <= n_bins; b++) {
        bin_edge = min + b * bin_size
        Bins[f] = Bins[f] bin_edge","
    }
}

function AnyFmtNum(str) {
    return (str ~ num_re || str ~ decimal_re || str ~ float_re)
}

function GetOrSetTruncVal(val) {
    if (TruncVal[val]) return TruncVal[val]

    large_val = val > 999
    large_dec = val ~ /\.[0-9]{3,}/
  
    if ((large_val && large_dec) || val ~ /^-?[0-9]*\.?[0-9]+(E|e)\+?([4-9]|[1-9][0-9]+)$/)
        trunc_val = int(val)
    else
        trunc_val = sprintf("%f", val) # Small floats flow through this logic

    trunc_val += 0
    TruncVal[val] = trunc_val
    return trunc_val
}

function Round(val) {
    int_val = int(val)
  
    if (val - int_val >= 0.5)
        return int_val++
    else
        return int_val
}

