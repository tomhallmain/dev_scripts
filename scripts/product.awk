#!/usr/bin/awk
#
# Return a product multiset from smaller multisets stored in separate files

BEGIN {
}

{
  if (FILENAME != PFILE) {
    ++set_base
  }
  PFILE = FILENAME
}

{
  MSets[set_base, FNR] = $0
  MSetLen[set_base]++
}

END {
  msets_len = set_base
  SimplePrintForMultiplier(1, MSetLen[1], msets_len, msets_len)
}

function SimplePrintForMultiplier(start, max_val, mult, max_mult, advance_val,  i, dec_mult, iter, init_adv) {
  iter = max_mult - mult + 1
  init_adv = advance_val
  dec_mult = mult - 1
  for (i = start; i <= max_val; i++) {
    if (iter < 2) {
      advance_val = MSets[iter, i]
    } else {
      advance_val = init_adv OFS MSets[iter, i]
    }
    if (mult > 1) {
      SimplePrintForMultiplier(1, MSetLen[iter + 1], dec_mult, max_mult, advance_val)
    } else {
      print advance_val
    }
  }
}

