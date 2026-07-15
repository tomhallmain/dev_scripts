#!/usr/bin/awk
#
# Identify dependecies in a shell function based on namespace data

FNR == 1 { f++ }

f == 1 {
    split($0, L, "([^A-z:_]+|\\[|\\]|\\\\)")

    for (i in L) {
        e = L[i]
        if (!(e ~ filter)) next
        if (e) Deps[e] = 1
    }

    next
}

f == 2 {
    NData[$0] = 1
}

END {
    # Collect matching deps first, then sort -- printing straight from a
    # `for (e in Deps)` loop depends on awk's native (unordered,
    # implementation-defined) array iteration, which differs across awk
    # implementations and made this output's order non-deterministic.
    n = 0
    for (e in Deps) {
        if (e in NData) out[++n] = e
    }

    # Manual insertion sort (n is always small -- a function's direct
    # dependency count) rather than gawk-only asort(), for portability with
    # any POSIX awk.
    for (i = 2; i <= n; i++) {
        key = out[i]
        j = i - 1
        while (j >= 1 && out[j] > key) {
            out[j + 1] = out[j]
            j--
        }
        out[j + 1] = key
    }

    for (i = 1; i <= n; i++) {
        if (calling_func)
            print calling_func, out[i]
        else
            print out[i]
    }
}
