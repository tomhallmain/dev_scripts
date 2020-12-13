#!/usr/bin/awk
#
# Use-specific script to color differences between two lines
#
# > echo "test line 1\ntest line 2" | awk -f scripts/line_diff.awk

BEGIN {
  red = "\033[1;31m"
  cyan = "\033[1;36m"
  mag = "\033[1;35m"
  coloroff = "\033[0m"
}

{
  if (NR == 1)
    left = $0
  else if (NR == 2)
    right = $0
  else
    exit
}

END{
    split(left, lchars, "")
    split(right, rchars, "")
    l_len = length(lchars)
    r_len = length(rchars)

    j = 1
    recap = 0

    for (i = 1; i <= l_len; i++) {
      if (lchars[i] == rchars[j]) {
        if (coloron) {
          coloron = 0
          printf coloroff }
        j++ }

      else {
        tmp_j = j
        for (k = j; k <= l_len; k++) { #TODO: May want to refactor using substr
          mtch = lchars[i] == rchars[k]
          mtch1 = lchars[i+1] == rchars[k+1]
          mtch2 = lchars[i+2] == rchars[k+2]
          mtch3 = lchars[i+3] == rchars[k+3]
          if (mtch && mtch1 && mtch2 && mtch3) {
            recap = 1
            j = k
            coloron = 0
            printf coloroff
            break }
          j = tmp_j }
        if (!recap && !coloron) {
          printf cyan
          coloron = 1 }}
      printf "%s", lchars[i] }

    print ""

    j = 1
    recap = 0
    for (i=1; i <= r_len; i++) {
      if (rchars[i] == lchars[j]) {
        if (coloron) {
          coloron = 0
          printf coloroff }
        j++ }

      else {
        tmp_j = j
        for (k = j; k <= r_len; k++) {
          mtch = rchars[i] == lchars[k]
          mtch1 = rchars[i+1] == lchars[k+1]
          mtch2 = rchars[i+2] == lchars[k+2]
          mtch3 = rchars[i+3] == lchars[k+3]
          if (mtch && mtch1 && mtch2 && mtch3) {
            recap = 1
            j = k
            coloron = 0
            printf coloroff
            break }
          j = tmp_j }

        if (!recap && !coloron) {
          coloron = 1
          printf red }}
      printf "%s", rchars[i] }

    print ""
}
