#!/usr/bin/awk
#
# Script to print characteristic combinations of values in
# field-separated data
#
# > awk -f power.awk file

BEGIN {

  len_ofs = length(OFS)
}

{
  _[$0]++
  
  if (debug && FNR < 3) debug_print(0)

  for (i = 1; i <= 2^NF - 2; i++) {
    str = ""

    for (j = 1; j <= NF; j++)
      if (i % (2^j) < 2^(j-1)) {
        if (debug && FNR < 3) debug_print(1)
        str = str $j OFS
      }

    str = substr(str, 1, length(str) - len_ofs)
    C[str]++
  }
  
  if (!(NR % 100)) printf "."
}

END {

  for (i in C) {
    j = C[i]
    if (j < 2) { 
      delete C[i]
      continue
    }
    N[j]++
    metakey = j OFS N[j]
    M[metakey] = i
    if (debug) debug_print(2)
  }

  printf "..."

  for (i in N) {
    n_n = N[i]
    for (j = 1; j <= n_n; j++) {
      for (k = 1; k <= n_n; k++) {
        if (j == k) continue
        #print "post continue", i, j, k
        metakey1 = i OFS j
        metakey2 = i OFS k
        t1 = M[metakey1]
        t2 = M[metakey2]
        if (!(C[t1] && C[t2])) continue
        if (debug) debug_print(3)
        split(t1, tmp1, FS)
        split(t2, tmp2, FS)
        matchcount = 0
        for (l in tmp1) {
          for (m in tmp2) {
            if (tmp1[l] == tmp2[m]) matchcount++
          }
        }
        l1 = length(tmp1)
        l2 = length(tmp2)
        if (matchcount >= l1 || matchcount >= l2) {
          if (l1 > l2) {
            if (debug) debug_print(4)
            delete C[t2]
          } else if (l2 > l1) {
            if (debug) debug_print(5)
            delete C[t1]
          }
        }
      }
    }
    printf "."
  }

  print ""
  
  for (i in _) { if (_[i] > 1) { print _[i], i } }
  
  for (i in C) { if (C[i]) print C[i], i }
}

function debug_print(case) {
  if (case == 0) {
    print "i", "j", "2*j", "i % (2*j)", "2^(j-1)"
  } else if (case == 1) {
    print i, j, 2*j, i % (2*j), 2^(j-1)
  } else if (case == 2) {
    print j, "", i, "", N[j], "", metakey, "", M[metakey]
  } else if (case == 3) {
    print "iOFSj " j, metakey1, " t1 " t1, " l1 " l1, " C[t1] " C[t1] "  | " " iOFSk" k, metakey2, " t2 " t2, " l2 " l2, " C[t2] " C[t2]
  } else if (case == 4) {
    print "deleting t2 " t2 " and keeping t1 " t1
  } else if (case == 5) {
    print "deleting t1 " t1 " and keeping t2 " t2
  }
}

