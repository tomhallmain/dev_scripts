#!/usr/bin/awk
#
# Aggregate values by expressions
#
#

BEGIN {
  if (r_aggs) {
    r = 1
    ra_count = split(r_aggs, RAggs, /,/) }
  if (c_aggs) { print "This utility still under construction - only r_aggs is currently functional."
    c = 1
    exit c
    ca_count = split(c_aggs, CAggs, /,/) }
  if (x_aggs) { print "This utility still under construction - only r_aggs is currently functional."
    x = 1
    exit x
    xa_count = split(x_aggs, XAggs, /,/) }
  for (i in RAggs) {
    RA[i] = AggExpr(RAggs[i])
    RAI[RA[i]] = i }
  for (i in CAggs) {
    CA[i] = AggExpr(CAggs[i])
    CAI[CA[i]] = i }
  for (i in XAggs) {
    XA[i] = AggExpr(XAggs[i])
    XAI[XA[i]] = i }

  if (r && !c && !x)
    r_base = 1
  if (c || x)
    c_base = 1
  if (x)
    x_base = 1
  if (!og_off)
    print_og = 1
  if (length(AllAggs))
    ge = 1

  "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0

  if (ge)
    GenAllExpr(max_nr, 0)
}

NR < 2 {
  if (header) do_thing = 1
  if (ge) GenAllExpr(NF, 1)
  init_nf = NF
}

r_base {
  if (print_og) {
    printf "%s", $0 FS
    if (NF < init_nf)
      for (i = NF + 1; i < init_nf; i++)
        printf "%s", FS }
  for (i = 1; i <= ra_count; i++) {
    agg = RA[i]
    if (!Agg[agg, NR])
      Agg[agg, NR] = EvalExpr(GenRExpr(agg))
    print_str = header && NR < 2 ? RAggs[i] : Agg[agg, NR]
    printf "%s", print_str
    if (i < ra_count)
      printf "%s", FS }
  print ""
  next
}

c_base { # TODO
  if (NF < init_nf)
    NFPad[NR] = NF - init_nf
  for (i in RA) {
    agg = RA[i]
    if (!Agg[agg, NR])
      Agg[agg, NR] = EvalExpr(GenRExpr(agg)) }
  for (i in CA) {
    agg = CA[i]
    }
}

x { # TODO
  for (i in XA) {
    agg = XA[i]
    }
}

END {
  if (r_base) exit
}

function Max(a, b) {
  if (a > b) return a
  else if (a < b) return b
  else return a
}

function Min(a, b) {
  if (a > b) return b
  else if (a < b) return a
  else return a
}

function AggExpr(agg_expr) {
  gsub(/[[:space:]]+/, "", agg_expr)
  if (agg_expr ~ "all")
    AllAggs[agg_expr] = 1
  else if(agg_expr ~ /\.\./) {
    split(agg_expr, Agg, /\|/)
    op = Agg[1]
    gsub(/\$/, "", Agg[2])
    split(Agg[2], AggAnchor, /\.\./)
    agg_expr = "$" AggAnchor[1]
    for (j = AggAnchor[1] + 1; j < AggAnchor[2]; j++)
      agg_expr = agg_expr op "$" j
    agg_expr = agg_expr op "$" AggAnchor[2] }
  return agg_expr
}

function GenAllExpr(max, row_call) {
  for (agg in AllAggs) {
    split(agg, Agg, /\|/)
    if (row_call && agg in RAI)
      RA[RAI[agg]] = AggExpr(Agg[1]"|1.."max)
    if (!row_call && agg in CAI)
      CA[CAI[agg]] = AggExpr(Agg[1]"|1.."max)
    if (agg in XAI)
      XA[XAI[agg]] = AggExpr(Agg[i]"|1.."max) }
}

function GenRExpr(agg) {
  expr = ""
  fs = split(agg, Fs, /[\+\*\-\/]/)
  ops = split(agg, Ops, /\$([0-9]+|NF)/)
  for (j = 1; j <= fs; j++) {
    f = Fs[j]; op = Ops[j+1]
    gsub(/(\$|[[:space:]]+)/, "", f)
    val = $f 
    gsub(/(\$|^[[:space:]]+|[[:space:]]+$)/, "", val)
    if (val && val ~ /^[0-9]+\.?[0-9]*$/)
      expr = expr $f op }
  return expr
}

function EvalExpr(expr) {
  res = 0
  split(expr, a, "+")
  for(a_i in a){
    split(a[a_i], s, "-")
    for(s_i in s){
      split(s[s_i], m, "*")
      for(m_i in m){
        split(m[m_i], d, "/")
        for(d_i in d){
          split(d[d_i], u, "%")
          for(u_i in u){
            split(u[u_i], e, "(\\^|\\*\\*)")
            for(e_i in e){
              if (e_i > 1) e[1] = e[1] ** e[e_i] }
            u[u_i] = e[1]; delete e
            if (u_i > 1) u[1] = u[1] % u[u_i] }
          d[d_i] = u[1]; delete u
          if (d_i > 1) d[1] /= d[d_i] }
        m[m_i] = d[1]; delete d
        if (m_i > 1) m[1] *= m[m_i] }
      s[s_i] = m[1]; delete m
      if (s_i > 1) s[1] -= s[s_i] }
    a[a_i] = s[1]; delete s }

  for (a_i in a)
    res += a[a_i]
  return res
}

function EvalCompExpr(left, right, comp) {
  return (comp == "=" && left == right) ||
         (comp == ">" && left > right) ||
         (comp == "<" && left < right)
}
