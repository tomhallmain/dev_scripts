#!/usr/bin/awk
#
# Aggregate values by expressions
#
#
## TODO: Fix CAggs multiply, divide case
##   (for some reason divide specific rows case works when +| is prepended)
## TODO: XAggs
## TODO: CAggs / Raggs scoping
## TODO: og_off case - use indices?

BEGIN {
  if (r_aggs) {
    r = 1
    ra_count = split(r_aggs, RAggs, /,/) }
  if (c_aggs) {
    c = 1
    ca_count = split(c_aggs, CAggs, /,/) }
  if (x_aggs) {
    print "This utility is still under construction - only r_aggs and c_aggs are currently functional."
    x = 1
    exit x
    xa_count = split(x_aggs, XAggs, /,/) }
  for (i in RAggs) {
    RA[i] = AggExpr(RAggs[i], 1)
    RAI[RA[i]] = i }
  for (i in CAggs) {
    CA[i] = AggExpr(CAggs[i], -1)
    CAI[CA[i]] = i
    AggAmort[i] = CA[i] }
  for (i in XAggs) {
    XA[i] = AggExpr(XAggs[i], 0)
    XAI[XA[i]] = i }

  if (r && !c && !x)
    r_base = 1
  if (c || x)
    c_base = 1
  if (x)
    x_base = 1
  if (length(AllAggs))
    gen = 1
  if (og_off)
    header = 1
  else
    print_og = 1

  "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0

  if (gen)
    GenAllAggExpr(max_nr, -1)

  OFS = (FS ~ "\\[:space:\\]") ? " " : FS
}


NR < 2 {
  if (header) GenHeaderCAggExpr(HeaderAggs)
  if (gen) GenAllAggExpr(NF, 1)
  if (!fixed_nf) fixed_nf = NF
}

r_base {
  if (print_og) {
    printf "%s", $0 OFS
    if (NF < fixed_nf)
      for (i = NF + 1; i < fixed_nf; i++)
        printf "%s", FS }

  for (i = 1; i <= ra_count; i++) {
    agg = RA[i]
    if (!RAgg[agg, NR])
      RAgg[agg, NR] = EvalExpr(GenRExpr(agg))
    print_str = header && NR < 2 ? RAggs[i] : RAgg[agg, NR]
    printf "%s", print_str
    if (i < ra_count)
      printf "%s", OFS }

  print ""; next
}

c_base {
  _[NR] = $0
  RHeader[NR] = $1

  if (NF < fixed_nf)
    NFPad[NR] = NF - fixed_nf

  for (i in RA) {
    agg = RA[i]
    if (!RAgg[agg, NR])
      RAgg[agg, NR] = EvalExpr(GenRExpr(agg)) }

  for (i in CA) {
    agg_amort = AggAmort[i]
    if (!Indexed(agg_amort, NR)) continue
    CAgg[i] = AdvCarryVec(i, NF, agg_amort, CAgg[i]) }
}

x { # TODO
  for (i in XA) {
    agg = XA[i]
    }
}


END {
  if (r_base) exit

  totals = length(Totals)

  for (i = 1; i <= NR; i++) {
    if (header && ca_count) printf "%s", OFS
    if (print_og) {
      split(_[i], Row, FS)
      for (j = 1; j <= fixed_nf; j++) {
        if (Row[j]) printf "%s", Row[j]
        if (j < fixed_nf || ra_count)
          printf "%s", OFS }}
    else if (i == 1 && header) {
      printf "%s", RHeader[i] OFS }
    for (j = 1; j <= ra_count; j++) {
      agg = RA[j]
      print_str = header && i < 2 ? RAggs[j] : RAgg[agg, i]
      printf "%s", print_str
      if (j < ra_count)
        printf "%s", OFS }
    print "" }

  for (i = 1; i <= ca_count; i++) {
    if (header) printf "%s", CAggs[i] OFS
    if (!CAgg[i]) { print ""; continue }
    split(CAgg[i], CAggVec, ",")
    for (j = 1; j <= fixed_nf; j++) {
      if (CAggVec[j]) printf "%s", CAggVec[j]
      if (j < fixed_nf)
        printf "%s", OFS }
    if (totals) {
      printf "%s", OFS
      for (j = 1; j <= ra_count; j++) {
        printf "%s", Totals[i, j]
        if (j < ra_count)
          printf "%s", OFS }}
    print "" }
}



function AggExpr(agg_expr, call) {
  gsub(/[[:space:]]+/, "", agg_expr)
  if (agg_expr ~ /all$/)
    AllAggs[agg_expr] = 1
  else if(agg_expr ~ /\.\./) {
    split(agg_expr, Agg, /\|/)
    op = Agg[1] ? Agg[1] : "+"
    gsub(/\$/, "", Agg[2])
    split(Agg[2], AggAnchor, /\.\./)
    agg_expr = "$" AggAnchor[1]
    for (j = AggAnchor[1] + 1; j < AggAnchor[2]; j++)
      agg_expr = agg_expr op "$" j
    agg_expr = agg_expr op "$" AggAnchor[2] }
  return agg_expr
}

function GenHeaderCAggExpr(HeaderAggs) { # TODO
  for (agg in HeaderAggs) {
    split(agg, Agg, /\|/)
    if (agg in CAI)
      CA[CAI[agg]] = AggExpr(Agg[1]"|1.."max, -1)
    if (agg in XAI)
      XA[XAI[agg]] = AggExpr(Agg[i]"|1.."max, 0) }
}

function GenAllAggExpr(max, call) {
  for (agg in AllAggs) {
    split(agg, Agg, /\|/)
    if (call > 0 && agg in RAI)
      RA[RAI[agg]] = AggExpr(Agg[1]"|1.."max, 1)
    if (call < 0 && agg in CAI) {
      CA[CAI[agg]] = AggExpr(Agg[1]"|1.."max, -1)
      AggAmort[CAI[agg]] = CA[CAI[agg]] }
    if (!call && agg in XAI)
      XA[XAI[agg]] = AggExpr(Agg[i]"|1.."max, 0) }
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
      expr = expr val op }
  return expr
}

function AdvCarryVec(c_agg_i, nf, agg_amort, carry) { # TODO: This is probably wildly inefficient
  split(carry, CarryVec, ",")
  carry = ""
  vec_expr = ""
  match(agg_amort, /\$([0-9]+|NR)/)
  right = substr(agg_amort, RSTART + RLENGTH, length(agg_amort))
  match(agg_amort, /[\+\*\-\/]+/)
  margin_op = substr(agg_amort, RSTART, RLENGTH)
  for (f = 1; f <= nf; f++) {
    if (!CarryVec[f]) CarryVec[f] = "0"
    sep = f == 1 ? "" : ","
    val = $f
    gsub(/(\$|^[[:space:]]+|[[:space:]]+$)/, "", val)
    if (val && val ~ /^[0-9]+\.?[0-9]*$/)
      carry = carry sep EvalExpr(CarryVec[f] margin_op val)
    else
      carry = carry sep CarryVec[f] }
  AggAmort[c_agg_i] = right
  for (j = 1; j <= ra_count; j++) {
    Totals[c_agg_i, j] = EvalExpr(Totals[c_agg_i, j] margin_op RAgg[RA[j], NR]) }
  return carry
}

function GenXExpr() {
  expr = ""
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

function Indexed(expr, field) {
  return expr ~ "\\$" field
}
