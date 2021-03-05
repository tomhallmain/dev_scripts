#!/usr/bin/awk
#
# Script to print characteristic combinations of values in
# field-separated data
#
# > awk -f power.awk file
#
# TODO: Link between fields and combination sets
# TODO: Refactor as set, not as left->right ordered combination (may not be
# feasible performance wise
# TODO: Add functionality to remove combinations intersecting with
# low-variance fields as these do not add more info - this would have to be
# done BEFORE or WHILE permorming exclusions relating to contained fields
# TODO: Output single fields based on their interaction characteristic value
# TODO: Set combinations once as a list then iterate over the list

BEGIN {
  if (!min) min = 10
  min_floor = min - 1

  OFS = SetOFS()
  len_ofs = length(OFS)

  if (choose) {
    if (choose < 1) {
      print "choose cannot be less than 1"
      exit 1
    }
    else if (choose != int(choose)) {
      print "choose must be an integer"
      exit 1
    }
    choose_fact = Fact(choose)
  }
}

invert && NR== 1 && c_counts {
  i_max = GetOrSetIMax(NF, choose);
  for (i = 1; i <= i_max; i++) {
    header_str = ""
    count_str = ""

    for (j = 1; j <= NF; j++) {
      if (GetOrSetCombinationDiscriminant(i, j, choose, NF)) {
        header_str = header_str $j OFS
        count_str = count_str j OFS
      }
    }

    header_str = substr(header_str, 1, length(header_str) - len_ofs)
    count_str = substr(count_str, 1, length(count_str) - len_ofs)
    CombinPatterns[count_str] = 1
    CombinHeaders[count_str] = h_str
  }
}

{
  i_max = GetOrSetIMax(NF, choose);
  for (i = 1; i <= i_max; i++) {
    combin_str = ""
    count_str = ""

    for (j = 1; j <= NF; j++) {
      if ($j ~ "^[[:space:]]*$") continue
      if (GetOrSetCombinationDiscriminant(i, j, choose, NF)) {
        combin_str = combin_str $j OFS
        count_str = count_str j OFS
      }
    }

    RC[count_str]++
    if (combin_str ~ "^[[:space:]]*$" || RC[count_str] > 1) continue
    if (debug) DebugPrint(0.5)

    if (c_counts) {
      count_str = substr(count_str, 1, length(count_str) - len_ofs)
      Combins[count_str ":::: " combin_str]++
    }
    else {
      combin_str = substr(combin_str, 1, length(combin_str) - len_ofs)
      Combins[combin_str]++
    }
  }

  if (!choose) {
    gsub(FS, OFS)
    Combins[$0]++
  }
  delete RC
}

END {

  if (c_counts) {
    for (combin in Combins) {
      combin_count = Combins[combin]

      if (combin_count < min) { 
        delete Combins[combin]
        continue
      }

      combin_pattern = substr(combin, 1, match(combin, ":::: ") - 1)
      if (invert) delete CombinHeaders[combin_pattern]
      CCount[combin_pattern] += combin_count
    }

    if (!invert) {
      for (combin_header in CombinHeaders)
        if (!(combin_header in CCount)) delete CombinHeaders[combin_header]
    }
  }

  else {
    for (combin in Combins) {
      combin_count = Combins[combin]

      if (combin_count < min) { 
        delete Combins[combin]
        continue
      }

      CombinCounts[combin_count]++
      metakey = combin_count SUBSEP CombinCounts[combin_count]
      M[metakey] = combin
    }

    for (combin_count in CombinCounts) {
      combin_count_count = CombinCounts[combin_count]
      for (j = 1; j <= combin_count_count; j++) {
        for (k = 1; k <= combin_count_count; k++) {
          if (k <= j) continue

          metakey1 = combin_count SUBSEP j
          metakey2 = combin_count SUBSEP k
          t1 = M[metakey1]
          t2 = M[metakey2]

          if (!(Combins[t1] && Combins[t2])) continue

          if (debug) DebugPrint(3)
          split(t1, Tmp1, OFS)
          split(t2, Tmp2, OFS)
          matchcount = 0

          for (l in Tmp1)
            for (m in Tmp2)
              if (Tmp1[l] == Tmp2[m]) matchcount++

          l1 = length(Tmp1)
          l2 = length(Tmp2)
          if (matchcount >= l1 || matchcount >= l2) {
            if (l1 > l2)
              delete Combins[t2]
            else if (l2 > l1)
                delete Combins[t1]
          }}}}}

  if (c_counts) {
    if (invert) {
      if (length(CombinHeaders)) {
        for (h in CombinHeaders)
          print CCount[h]/NR, CombinHeaders[h]
      }
      else
        print "No combinations identified with current parameters"
    }
    else {
      if (length(CCount)) {
        for (c in CCount)
          print CCount[c]/NR, c
      }
      else
        print "No combinations identified with current parameters"
    }
  }
  else {
    if (length(Combins)) {
      for (combin in Combins)  {
        if (Combins[combin])
          print Combins[combin], combin
      }
    }
    else
      print "No combinations identified with current parameters"
  }
}

function GetOrSetIMax(nf, choose) {
  if (IMax[nf]) return IMax[nf]

  if (choose) {
    if (choose > nf)
      i_max = 0
    else if (choose == nf)
      i_max = 1
    else
      i_max = Fact(nf) / (choose_fact * Fact(nf - choose))
  }
  else
    i_max = 2^nf - 2

  IMax[nf] = i_max
  return i_max
}

function Fact(n,   f) {
  if (F[n]) return F[n]

  f = n

  for (i = n - 1; i > 1; i--)
    f *= i

  F[n] = f
  return f
}

function Tri(n,   t) {
  if (T[n]) return T[n]

  t = SumRange(0, n)

  T[n] = t
  return t
}

function SumRange(start, end) {
  for (a = start + 1; a < end; a++)
    start += a

  return start + end
}

function GetOrSetCombinationDiscriminant(i, j, choose, nf) {
  if (debug) DebugPrint(6)
  
  if (CDSet[i,j])
    return Discriminant[i,j]

  if (choose) {
    if (choose == nf)
      discriminant = 1
    else if (choose == 2)
      discriminant = GetChooseTwoState(nf, i, j)
    else
      discriminant = 0
  }
  else {
    discriminant = i % (2^j) < 2^(j - 1)
  }

  CDSet[i,j] = 1
  Discriminant[i,j] = discriminant
  return discriminant
}

function GetChooseTwoState(nf, i_idx, j_idx) {
  diff = j_idx - i_idx

  if (i_idx < nf) {
    return diff == 0 || diff == 1
  }
  else {
    counter = 0
    t_state = 0
    rev_tri = 1
    state_base = nf - 1

    while (rev_tri > 0) {
      t_state++
      rev_tri = RevTri(nf, nf - t_state - 1)

      if (i_idx > state_base && i_idx < rev_tri) { 

        state_diff = diff + t_state * nf - Tri(t_state)

        return (state_diff == 0 || (state_diff == (t_state + 1)))
      }

      state_base = rev_tri - 1
    }

    return 0
  }
}

function RevTri(base, n,   t) {
  if (RT[base, n]) return RT[base, n]

  t = base

  for (rt_i = base - 2; rt_i >= n; rt_i--)
    t += rt_i

  RT[base, n] = t
  return t
}

function DebugPrint(case) {
  if (case == 0) {
    print "----------- NEW RECORD ------------"
    print $0
    printf "%5s%5s%7s%15s%15s  %s\n", "[i]", "[j]", "[2*j]", "[i % (2*j)]", "[2^(j-1)]", "[str]" }
  else if (case == 1) {
    printf "%5s%5s%7s%15s%15s  %s\n", i, j, 2*j, i % (2*j), 2^(j-1), str }
  else if (case == 0.5) {
    printf "%s\n\n", "SAVE COMBIN:  " combin_str }
  else if (case == 1.5) {
    printf "%5s  %-80s%10s%10s  %-80s\n", "[combin_count]", "[combin]", "CombinCounts[combin_count]", "[metakey]", "M[metakey]" }
  else if (case == 2) {
    printf "%5s  %-80s%10s%10s  %-80s\n", combin_count, combin, CombinCounts[combin_count], metakey, M[metakey] }
  else if (case == 3) {
    print "------- COMBIN COMP --------"
    printf "%-12s%-10s%-10s%-10s%s\n", "[iOFSj] " j, metakey1, " [l1] " l1, " Combins[t1] " Combins[t1], " [t1] " t1
    printf "%-12s%-10s%-10s%-10s%s\n", "[iOFSk] " k, metakey2, " [l2] " l2, " Combins[t2] " Combins[t2], " [t2] " t2 }
  else if (case == 4) {
    print "<< delete [t2] "t2
    print ">> keep   [t1] "t1"\n" }
  else if (case == 5) {
    print "<< delete [t1] "t1
    print ">> keep   [t2] "t2"\n" }
  else if (case == 6) {
    print "[ " i, j " ]" }
}

