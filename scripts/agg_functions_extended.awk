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
# group_key (optional): identifies the underlying value collection this call
# draws from, e.g. "R" SUBSEP row-number SUBSEP selector for row scope. When
# non-empty, median/quartile calls that share a group_key (i.e. med|all,
# q1|all, q2|all, q3|all requested together for the same row/column) reuse
# one sorted array instead of each re-sorting the same values from scratch.
function ProcessExtendedAgg(agg_expr, values, n, group_key) {
    if (!(agg_expr in AggType)) return ""
    return ComputeStat(AggType[agg_expr], values, n, QuartileNum[agg_expr], group_key)
}

# Strips the stat-type prefix (med/mode/qN/sd) from an agg string, leaving
# the selector suffix (e.g. "|all", "|~pattern", "|1..5") that identifies
# which underlying values it draws from. Two agg strings with the same
# scope + group index + selector suffix collect identical value sets.
function StatGroupKey(scope, group_idx, agg,    selector) {
    selector = agg
    sub(/^(med|mode|q[1-3]|sd)/, "", selector)
    return scope SUBSEP group_idx SUBSEP selector
}

# Same stats by explicit type (cross aggs key by CrossAggType, not AggType).
# group_key is optional; omit it (as the cross-agg call site does) to always
# sort fresh with no cross-call caching.
function ComputeStat(type, values, n, q, group_key,    result, i, sum, sum_sq) {
    if (n < 1 || type == "") return ""
    if (type == "median") return Median(values, n, group_key)
    if (type == "mode") return Mode(values, n)
    if (type == "quartile") return Quartile(values, n, q, group_key)
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

function SortCopy(arr, n, sorted,    i) {
    for (i = 1; i <= n; i++) sorted[i] = arr[i] + 0
    SortNumeric(sorted, 1, n)
}

# Hybrid quicksort/insertion-sort, O(n log n) average case (values are
# already cast with + 0 above, so this is numeric-only comparison — no
# KeyLt-style string/numeric branching needed). Kept local to this module
# rather than shared: ds:agg's load chain never co-loads shape.awk/hist.awk/
# reorder_functions.awk, which already define their own same-named sort
# helpers, so there's no single shared file all of them load together.
function SortNumeric(A, left, right,    i, last) {
    if (left >= right) return

    if (right - left < 10) {
        InsertionSortNumeric(A, left, right)
        return
    }

    SwapNumeric(A, left, left + int((right - left + 1) * rand()))
    last = left
    for (i = left + 1; i <= right; i++) {
        if (A[i] < A[left]) SwapNumeric(A, ++last, i)
    }
    SwapNumeric(A, left, last)

    SortNumeric(A, left, last - 1)
    SortNumeric(A, last + 1, right)
}

function InsertionSortNumeric(A, left, right,    i, j, key) {
    for (i = left + 1; i <= right; i++) {
        key = A[i]
        j = i - 1
        while (j >= left && A[j] > key) {
            A[j + 1] = A[j]
            j--
        }
        A[j + 1] = key
    }
}

function SwapNumeric(A, i, j,    t) {
    t = A[i]; A[i] = A[j]; A[j] = t
}

# Populates sorted[1..n] ascending. When group_key is non-empty, reuses a
# previously-sorted array for the same group_key instead of re-sorting (see
# ProcessExtendedAgg) — falls back to a fresh SortCopy whenever the cache is
# empty, missing, or its cached count doesn't match n.
function GetSortedStats(arr, n, group_key, sorted,    i) {
    if (group_key != "" && (group_key in SortedStatsCacheN) && SortedStatsCacheN[group_key] == n) {
        for (i = 1; i <= n; i++) sorted[i] = SortedStatsCache[group_key, i]
        return
    }

    SortCopy(arr, n, sorted)

    if (group_key != "") {
        SortedStatsCacheN[group_key] = n
        for (i = 1; i <= n; i++) SortedStatsCache[group_key, i] = sorted[i]
    }
}

function Median(arr, n, group_key,    sorted, mid) {
    if (n < 1) return ""
    GetSortedStats(arr, n, group_key, sorted)
    if (n % 2) return sorted[int((n + 1) / 2)]
    mid = n / 2
    return (sorted[mid] + sorted[mid + 1]) / 2
}

function Quartile(arr, n, q, group_key,    sorted, pos, i, frac) {
    if (n < 1 || q < 1 || q > 3) return ""
    GetSortedStats(arr, n, group_key, sorted)
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
