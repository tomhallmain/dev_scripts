#!/usr/bin/awk
#

BEGIN {
  if (!tocase)
    pass = 1
  else if ("lowercase" ~ "^"tocase || "downcase" ~ "^"tocase || tocase == "lc")
    lc = 1
  else if ("uppercase" ~ "^"tocase || tocase == "uc")
    uc = 1
  else if ("propercase" ~ "^"tocase || tocase == "pc")
    pc = 1
  else if ("camelcase" ~ "^"tocase || tocase == "cc")
    cc = 1
  else if ("snakecase" ~ "^"tocase || tocase == "sc")
    sc = 1
  else if ("varcase" ~ "^"tocase || tocase == "vc")
    vc = 1
}

lc { print L($0); next }

uc { print U($0); next }

pass { print; next }

{
  line = $0
  line = PrepareLine(line)
  n_wds = split(line, Words, " ")
}

pc {
  for (i = 1; i < n_wds; i++)
    printf "%s", GenPC(Words[i]) " "
  print GenPC(Words[n_wds])
}

cc {
  for (i = 1; i < n_wds; i++)
    printf "%s", GenCC(Words[i], i)
  print GenCC(Words[n_wds], n_wds)
}

sc {
  for (i = 1; i < n_wds; i++)
    printf "%s", L(Words[i]) "_"
  print L(Words[n_wds])
}

vc {
  for (i = 1; i < n_wds; i++)
    printf "%s", U(Words[i]) "_"
  print U(Words[n_wds])
}



function U(s) { return toupper(s) }
function L(s) { return tolower(s) }

function SS(str, start, end) { return substr(str, start, end) }

function PrepareLine(line) {
  gsub(/_/, " ", line)
  gsub(/ +/, " ", line) # tentative
  return SpaceCasevars(line)
}

function SpaceCasevars(s) {
  while (match(s, /[a-z][A-Z]/)) {
    s = SS(s, 1, RSTART) " " SS(s, RSTART + 1, length(s) - RSTART) }
  return s
}

function GenPC(word) {
  return U(SS(word, 1, 1)) L(SS(word, 2, length(word))) 
}
function GenCC(word, idx) {
  if (idx == 1)
    start_char = L(SS(word, 1, 1))
  else
    start_char = U(SS(word, 1, 1))
  return start_char L(SS(word, 2, length(word)))
}

