#!/usr/bin/awk
# DS:AGG_EXTENDED
#
# Extended statistical helpers for ds:agg (median, mode, quartile, stddev).
# Load order: utils.awk → agg_functions_extended.awk → agg_functions.awk → agg_program.awk
#
# VERSION: 0.2
# DEPENDENCIES: support/utils.awk
#

function DetectAggType(agg_expr,    type) {
    if (agg_expr ~ /^med/) {
        type = "median"
    } else if (agg_expr ~ /^q[1-3]/) {
        type = "quartile"
        if (match(agg_expr, /^q([1-3])/)) {
            QuartileNum[agg_expr] = substr(agg_expr, 2, 1)
        }
    } else if (agg_expr ~ /^mode/) {
        type = "mode"
    } else if (agg_expr ~ /^sd/) {
        type = "stddev"
    }
    return type
}

# Extended aggregation processing (AggType[agg_expr] holds median|mode|quartile|stddev)
function ProcessExtendedAgg(agg_expr, values, n) {
    if (!(agg_expr in AggType)) return ""
    return ComputeStat(AggType[agg_expr], values, n, QuartileNum[agg_expr])
}

# Same stats by explicit type (cross aggs key by CrossAggType, not AggType)
function ComputeStat(type, values, n, q,    result, i, sum, sum_sq) {
    if (n < 1 || type == "") return ""
    if (type == "median") return Median(values, n)
    if (type == "mode") return Mode(values, n)
    if (type == "quartile") return Quartile(values, n, q)
    if (type == "stddev") {
        sum = 0
        sum_sq = 0
        for (i = 1; i <= n; i++) {
            sum += values[i]
            sum_sq += values[i] * values[i]
        }
        return StdDev(sum_sq, sum, n)
    }
    return ""
}

# Statistical functions
function Mode(arr, n,    i, max_count, mode_val, count) {
    max_count = 0
    mode_val = ""
    
    for (i = 1; i <= n; i++) {
        count[arr[i]]++
        if (count[arr[i]] > max_count) {
            max_count = count[arr[i]]
            mode_val = arr[i]
        }
    }
    
    return mode_val
}

function SortCopy(arr, n, sorted,    i, j, key) {
    for (i = 1; i <= n; i++) sorted[i] = arr[i] + 0
    for (i = 2; i <= n; i++) {
        key = sorted[i]
        j = i - 1
        while (j >= 1 && sorted[j] > key) {
            sorted[j + 1] = sorted[j]
            j--
        }
        sorted[j + 1] = key
    }
}

function Median(arr, n,    sorted, mid) {
    if (n < 1) return ""
    SortCopy(arr, n, sorted)
    if (n % 2) return sorted[int((n + 1) / 2)]
    mid = n / 2
    return (sorted[mid] + sorted[mid + 1]) / 2
}

function Quartile(arr, n, q,    sorted, pos, i, frac) {
    if (n < 1 || q < 1 || q > 3) return ""
    SortCopy(arr, n, sorted)
    pos = q * (n + 1) / 4
    if (pos < 1) return sorted[1]
    if (pos >= n) return sorted[n]
    i = int(pos)
    frac = pos - i
    if (frac == 0) return sorted[i]
    return sorted[i] + frac * (sorted[i + 1] - sorted[i])
}

function StdDev(sum_sq, sum, n) {
    return n > 1 ? sqrt((sum_sq - (sum * sum / n)) / (n - 1)) : 0
}
