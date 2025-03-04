#!/usr/bin/awk
# DS:AGG_EXTENDED
#
# Extended statistical functions and optimizations for agg.awk
# Provides additional aggregation operations and memory management
#
# VERSION: 0.1
# DEPENDENCIES: utils.awk, agg.awk

# Cache management
function cleanup_caches(    i, j) {
    # Clean statistical caches periodically
    if (NR % 1000 == 0) {
        for (i in MedianCache) delete MedianCache[i]
        for (i in ModeCache) delete ModeCache[i]
        for (i in QuartileCache) delete QuartileCache[i]
        for (i in StatsCache) delete StatsCache[i]
    }
    
    # Clean expression cache more frequently
    if (NR % 100 == 0) {
        for (i in ExtractVal) if (++ExtractValAge[i] > 100) delete ExtractVal[i]
        for (i in TruncVal) if (++TruncValAge[i] > 100) delete TruncVal[i]
        for (i in FastSplitCache) if (++SplitAge[i] > 50) {
            delete FastSplitCache[i]
            for (j in FastSplitArrayCache) 
                if (j ~ "^" i) delete FastSplitArrayCache[j]
        }
    }
}

# Optimized string operations
function fast_split(str, arr, sep,    n, i, cache_key) {
    cache_key = str SUBSEP sep
    if (FastSplitCache[cache_key]) {
        n = FastSplitCache[cache_key]
        for (i = 1; i <= n; i++) 
            arr[i] = FastSplitArrayCache[cache_key SUBSEP i]
        return n
    }
    
    n = split(str, arr, sep)
    
    # Cache only if string is frequently used
    if (++SplitFrequency[cache_key] > 3) {
        FastSplitCache[cache_key] = n
        for (i = 1; i <= n; i++)
            FastSplitArrayCache[cache_key SUBSEP i] = arr[i]
    }
    
    return n
}

# Statistical functions
function stddev(sum_sq, sum, n) {
    return n > 1 ? sqrt((sum_sq - (sum * sum / n)) / (n - 1)) : 0
}

function median(arr, n,    i, k, l, m, r, pivot, tmp, cache_key) {
    cache_key = arr_hash(arr, n)
    if (MedianCache[cache_key]) return MedianCache[cache_key]
    
    # Copy to temp array to preserve original
    for (i = 1; i <= n; i++) tmp[i] = arr[i]
    
    k = int((n + 1) / 2)
    l = 1
    r = n
    
    while (l < r) {
        pivot = tmp[r]
        i = l - 1
        
        for (m = l; m < r; m++) {
            if (tmp[m] <= pivot) {
                i++
                pivot = tmp[i]
                tmp[i] = tmp[m]
                tmp[m] = pivot
            }
        }
        
        i++
        pivot = tmp[r]
        tmp[r] = tmp[i]
        tmp[i] = pivot
        
        if (i == k) break
        if (i > k) r = i - 1
        else l = i + 1
    }
    
    MedianCache[cache_key] = tmp[k]
    return tmp[k]
}

function mode(arr, n,    i, max_count, mode_val, count, cache_key) {
    cache_key = arr_hash(arr, n)
    if (ModeCache[cache_key]) return ModeCache[cache_key]
    
    for (i = 1; i <= n; i++) {
        count[arr[i]]++
        if (count[arr[i]] > max_count) {
            max_count = count[arr[i]]
            mode_val = arr[i]
        }
    }
    
    ModeCache[cache_key] = mode_val
    return mode_val
}

function quartile(arr, n, q,    sorted, i, pos, val, cache_key) {
    cache_key = arr_hash(arr, n) SUBSEP q
    if (QuartileCache[cache_key]) return QuartileCache[cache_key]
    
    # Copy and sort array
    for (i = 1; i <= n; i++) sorted[i] = arr[i]
    asort(sorted)
    
    pos = q * (n + 1) / 4
    i = int(pos)
    
    # Linear interpolation for non-integer positions
    if (i == pos) {
        val = sorted[i]
    } else {
        val = sorted[i] + (pos - i) * (sorted[i+1] - sorted[i])
    }
    
    QuartileCache[cache_key] = val
    return val
}

# Helper functions
function arr_hash(arr, n,    i, hash) {
    hash = n
    for (i = 1; i <= n; i++) 
        hash = hash SUBSEP arr[i]
    return hash
}

# Extended aggregation processing
function process_extended_agg(agg_expr, values, n,    type, result) {
    if (!(agg_expr in AggType)) return ""
    
    type = AggType[agg_expr]
    
    if (type == "median") {
        result = median(values, n)
    } else if (type == "mode") {
        result = mode(values, n)
    } else if (type == "quartile") {
        result = quartile(values, n, QuartileNum[agg_expr])
    } else if (type == "stddev") {
        result = stddev(StatsSumSq[agg_expr], StatsSum[agg_expr], n)
    }
    
    return result
}

# Aggregation type detection
function detect_agg_type(agg_expr,    type) {
    if (agg_expr ~ /^med/) {
        type = "median"
    } else if (agg_expr ~ /^q[1-3]/) {
        type = "quartile"
        QuartileNum[agg_expr] = substr(agg_expr, 2, 1)
    } else if (agg_expr ~ /^mode/) {
        type = "mode"
    } else if (agg_expr ~ /^sd/) {
        type = "stddev"
    }
    return type
}

# Value collection for statistical operations
function collect_agg_values(agg_expr, val, idx,    type) {
    type = AggType[agg_expr]
    
    if (type == "stddev") {
        StatsSum[agg_expr] += val
        StatsSumSq[agg_expr] += val * val
        StatsCount[agg_expr]++
    } else {
        AggValues[agg_expr, ++AggValuesCount[agg_expr]] = val
    }
}

BEGIN {
    # Initialize extended aggregation types
    ExtendedAggTypes["med"] = "median"
    ExtendedAggTypes["q1"] = "quartile"
    ExtendedAggTypes["q2"] = "quartile"
    ExtendedAggTypes["q3"] = "quartile"
    ExtendedAggTypes["mode"] = "mode"
    ExtendedAggTypes["sd"] = "stddev"
} 