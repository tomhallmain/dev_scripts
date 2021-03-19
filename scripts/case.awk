#!/usr/bin/awk
#
# SYNOPSIS
#      ds:case [string|file] [tocase=proper] [filter]
#
# DESCRIPTION
#      Recase text data.
#
#      Send data to ds:case via pipe, in a text file or a string.
#
#      For the purposes of camel, snake, and variable case, each line
#      is treated as a single joined output.
#
#      If set, [filter] is regex used to only case rows that match.
#
# CASE OUTPUT OPTIONS
#      lowercase      l[ower][case][c] || d[own][case]
#
#      UPPERCASE      u[pper][case][u]
#
#      Proper Case    p[roper][case][c]
#
#      camelCase      c[amel][case][c]
# 
#      snake_case     s[nake][case][c]
#
#      VARIABLE_CASE  v[ar][ariable][case][c]
#
#      Object.Case    o[bject][case][c]
#

BEGIN {
  if (!tocase)
    pass = 1
  else if ("lowercase" ~ "^"tocase || "downcase" ~ "^"tocase || tocase ~ "^lc(ase)?$")
    lc = 1
  else if ("uppercase" ~ "^"tocase || tocase ~ "^uc(ase)?$")
    uc = 1
  else if ("propercase" ~ "^"tocase || tocase ~ "^pc(ase)?$")
    pc = 1
  else if ("camelcase" ~ "^"tocase || tocase ~ "^cc(ase)?$")
    cc = 1
  else if ("snakecase" ~ "^"tocase || tocase ~ "^sc(ase)?$")
    sc = 1
  else if ("varcase" ~ "^"tocase || "variablecase" ~ "^"tocase || tocase ~ "^vc(ase)?$")
    vc = 1
  else if ("objectcase" ~ "^"tocase || tocase ~ "^oc(ase)?$")
    oc = 1
}

filter && !($0 ~ filter) { next }

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
    printf "%s", GenPC(Words[i], i) " "
  print GenPC(Words[n_wds]); next
}

cc {
  for (i = 1; i < n_wds; i++)
    printf "%s", GenCC(Words[i], i)
  print GenCC(Words[n_wds], n_wds); next
}

sc {
  for (i = 1; i < n_wds; i++)
    printf "%s", L(Words[i]) "_"
  print L(Words[n_wds]); next
}

vc {
  for (i = 1; i < n_wds; i++)
    printf "%s", U(Words[i]) "_"
  print U(Words[n_wds]); next
}

oc {
  for (i = 1; i < n_wds; i++)
    printf "%s", GenPC(Words[i]) "."
  print GenPC(Words[n_wds])
}

function U(s) { return toupper(s) }
function L(s) { return tolower(s) }
function SS(str, start, end) { return substr(str, start, end) }

function PrepareLine(line) {
  gsub(/_/, " ", line)
  gsub(/\./, " ", line)
  gsub(/ +/, " ", line) # tentative
  return SpaceCasevars(line)
}

function SpaceCasevars(s) {
  while (match(s, /[a-z][A-Z]/)) {
    s = SS(s, 1, RSTART) " " SS(s, RSTART + 1, length(s) - RSTART)
  }
  
  return s
}

function GenPC(word, idx) {
  if (idx < 2)
    return U(SS(word, 1, 1)) L(SS(word, 2, length(word)))
  else if (word ~ /^(and|as|but|for|if|nor|or|so|yet|a|an|the|upon|from|as|at|by|for|in|of|off|on|per|to|up|via)$/)
    return word
  else
    return U(SS(word, 1, 1)) L(SS(word, 2, length(word))) 
}

function GenCC(word, idx) {
  if (idx == 1)
    start_char = L(SS(word, 1, 1))
  else
    start_char = U(SS(word, 1, 1))
  
  return start_char L(SS(word, 2, length(word)))
}

