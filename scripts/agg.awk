#!/usr/bin/awk
#
# Aggregate values by expressions
#
#
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
    if (RAggs[i] == "off") { delete RAggs[i]; continue }
    RA[i] = AggExpr(RAggs[i], 1, i)
    RAI[RA[i]] = i }
  for (i in CAggs) {
    CA[i] = AggExpr(CAggs[i], 0, i)
    CAI[CA[i]] = i
    AggAmort[i] = CA[i] }
  for (i in XAggs) {
    XA[i] = AggExpr(XAggs[i], -1, i)
    XAI[XA[i]] = i }

  if (r || c || x)
    r_c_base = 1
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
    GenAllAggExpr(max_nr, 0)

  OFS = (FS ~ "\\[:space:\\]") ? " " : FS
}


NR < 2 {
  if (header) GenHeaderCAggExpr(HeaderAggs)
  if (gen) GenAllAggExpr(NF, 1)
  if (!fixed_nf) fixed_nf = NF
  if (r) {
    for (i in RA) {
      if (KeyAgg[1, i]) SetRAggKeyFields(i, RA[i]) }}
}

r_c_base {
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
    if (!KeyAgg[0, i] && !SearchAggs[agg_amort] && !Indexed(agg_amort, NR)) continue
    CAgg[i] = AdvCarryVec(i, NF, agg_amort, CAgg[i]) }
}

x && NR in XRs { # 3 arrs, one for row indices, one for col indices, one to tie back the keys from NR
  for (i in XA) {
    agg = XA[i]
    if (NR i in XCRs) {
      todo = 1 }}
}


END {
  totals = length(Totals)

  for (i = 1; i <= NR; i++) {
    if (header && ca_count) printf "%s", OFS
    if (print_og) {
      split(_[i], Row, FS)
      for (j = 1; j <= fixed_nf; j++) {
        printf "%s", Row[j]
        if (j < fixed_nf || ra_count)
          printf "%s", OFS }}
    else if (i == 1 && header) {
      printf "%s", RHeader[i] OFS }
    for (j = 1; j <= ra_count; j++) {
      agg = RA[j]
      print_header = (header || !RAgg[agg, i]) && i < 2
      print_str = print_header ? RAggs[j] : RAgg[agg, i]
      printf "%s", print_str
      if (j < ra_count)
        printf "%s", OFS }
    print "" }

  for (i = 1; i <= ca_count; i++) {
    skip_first = CAgg[i] ~ /^0?,/
    if (header || skip_first) printf "%s", CAggs[i] OFS
    if (!CAgg[i]) { print ""; continue }
    split(CAgg[i], CAggVec, ",")
    start = skip_first && !header ? 2 : 1

    for (j = start; j <= fixed_nf; j++) {
      if (CAggVec[j]) printf "%s", EvalExpr(CAggVec[j])
      if (j < fixed_nf)
        printf "%s", OFS }
    if (totals) {
      printf "%s", OFS
      for (j = 1; j <= ra_count; j++) {
        printf "%s", Totals[i, j]
        if (j < ra_count)
          printf "%s", OFS }}
    print "" }

  if (debug) {
    for (i in RA) {
      print i" "RAggs[i]" "RA[i]
      print "KeyAgg? "KeyAgg[1, i]
      print "SearchAgg? "SearchAgg[RA[i]]
      print "AllAgg? "AllAggs[RA[i]] }
    for (i in CA) {
      print i" "CAggs[i]" "CA[i]
      print "KeyAgg? "KeyAgg[0, i]
      print "SearchAgg? "SearchAgg[CA[i]]
      print "AllAgg? "AllAggs[CA[i]] }}
}



function AggExpr(agg_expr, call, call_idx) {
  gsub(/[[:space:]]+/, "", agg_expr)
  all_agg = 0

  if (agg_expr ~ /^[\+\-\*\/]\|all$/) {
    all_agg = 1
    AllAggs[agg_expr] = 1 }

  else if (agg_expr ~ /^[\+\-\*\/]$/) {
    agg_expr = agg_expr "|all"
    all_agg = 1
    AllAggs[agg_expr] = 1 }

  else if (agg_expr ~ /^[\+\-\*\/]\|.*\.\./) {
    split(agg_expr, AggBase, /\|/)
    op = AggBase[1] ? AggBase[1] : "+"
    gsub(/\$/, "", AggBase[2])
    split(AggBase[2], AggAnchor, /\.\./)
    if (!AggAnchor[1]) AggAnchor[1] = 1
    if (!AggAnchor[2])
      AggAnchor[2] = call > 0 ? max_nr : 100
    agg_expr = op "$" AggAnchor[1]
    for (j = AggAnchor[1] + 1; j < AggAnchor[2]; j++)
      agg_expr = agg_expr op "$" j
    agg_expr = agg_expr op "$" AggAnchor[2] }

  else if (agg_expr ~ /^~/) {
    SearchAggs[agg_expr] = substr(agg_expr, 2, length(agg_expr)) }

  else if (agg_expr ~ /[A-z]/) {
    KeyAgg[call, call_idx] = 1 }

  if (!(all_agg || SearchAggs[agg_expr])) {
    match(agg_expr, /^[\+\-\*\/]/)
    if (agg_expr ~ /^[\+]/)
      agg_expr = "0+" substr(agg_expr, RLENGTH + 1, length(agg_expr))
    else if (agg_expr ~ /^[\-]/)
      agg_expr = "0-" substr(agg_expr, RLENGTH + 1, length(agg_expr))
    else if (agg_expr ~ /^[\*\/]/)
      agg_expr = "1*" substr(agg_expr, RLENGTH + 1, length(agg_expr)) }

  return agg_expr
}

function GenHeaderCAggExpr(HeaderAggs) { # TODO
  for (agg in HeaderAggs) {
    split(agg, Agg, /\|/)
    if (agg in CAI)
      CA[CAI[agg]] = AggExpr(Agg[1]"|1.."max, 0)
    if (agg in XAI)
      XA[XAI[agg]] = AggExpr(Agg[i]"|1.."max, -1) }
}

function GenAllAggExpr(max, call) {
  for (agg in AllAggs) {
    split(agg, Agg, /\|/)
    if (call > 0 && agg in RAI)
      RA[RAI[agg]] = AggExpr(Agg[1]"|1.."max, 1)
    if (!call && agg in CAI) {
      CA[CAI[agg]] = AggExpr(Agg[1]"|1.."max, 0)
      AggAmort[CAI[agg]] = CA[CAI[agg]] }
    if (call < 0 && agg in XAI)
      XA[XAI[agg]] = AggExpr(Agg[i]"|1.."max, -1) }
}

function SetRAggKeyFields(r_agg_i, agg_expr) {
  keys = split(agg_expr, Keys, /[\+\*\-\/]/)
  gsub(/\+/, "____+____", agg_expr)
  gsub(/\-/, "____-____", agg_expr)
  gsub(/\*/, "____*____", agg_expr)
  gsub(/\//, "____/____", agg_expr)
  for (k = 1; k <= length(Keys); k++) {
    for (f = 1; f <= NF; f++)
      if ($f ~ Keys[k]) gsub("(____)?"Keys[k]"(____)?", "$"f, agg_expr) }
  gsub(/[^\+\*\-\/0-9\$]/, "", agg_expr)
  RA[r_agg_i] = agg_expr
  RAI[agg_expr] = r_agg_i
}

function GenRExpr(agg) {
  expr = ""

  if (SearchAggs[agg]) {
    agg_search = SearchAggs[agg]
    for (f = 1; f <= fixed_nf; f++)
      if ($f ~ agg_search) expr = expr "1+" }

  else {
    fs = split(agg, Fs, /[\+\*\-\/]/)
    ops = split(agg, Ops, /[^\+\*\-\/]+/)
    for (j = 1; j <= fs; j++) {
      f = Fs[j]; op = Ops[j+1]
    if (f ~ /\$[0-9]+/) {
      gsub(/(\$|[[:space:]]+)/, "", f)
      val = f ? $f : ""
      gsub(/(\$|\(|\)|^[[:space:]]+|[[:space:]]+$)/, "", val) }
    else
      val = f

    if (debug) print agg " :: GENREXPR: " expr val op
    if (val != "" && val ~ /^-?[0-9]*\.?[0-9]+((E|e)(\+|-)[0-9]+)?$/)
      expr = expr TruncVal(val) op }}

  return expr
}

function AdvCarryVec(c_agg_i, nf, agg_amort, carry) { # TODO: This is probably wildly inefficient
  split(carry, CarryVec, ",")
  t_carry = ""
  active_key = ""
  search = 0
  if (SearchAggs[agg_amort]) {
    search = SearchAggs[agg_amort] }
  else {
    if (!agg_amort) return carry
    match(agg_amort, /[^\+\*\-\/]+/)
    if (KeyAgg[0, c_agg_i]) {
      row = $0; gsub(/[[:space:]]+/, "", row)
      active_key = substr(agg_amort, RSTART, RLENGTH)
      if (!(row ~ active_key))
        return carry }
    right = substr(agg_amort, RSTART + RLENGTH, length(agg_amort))
    AggAmort[c_agg_i] = right
    match(agg_amort, /[\+\*\-\/]+/)
    margin_op = substr(agg_amort, RSTART, RLENGTH) }

  if (debug) print c_agg_i, agg_amort, carry

  for (f = 1; f <= nf; f++) {
    sep = f == 1 ? "" : ","
    val = $f
    if (search) { 
      if (!CarryVec[f]) CarryVec[f] = "0"
      margin_op = val ~ search ? "+1" : "" 
      t_carry = t_carry sep CarryVec[f] margin_op }
    else {
      gsub(/(\$|\(|\)|^[[:space:]]+|[[:space:]]+$)/, "", val)
      if (val != "" && val ~ /^-?[0-9]*\.?[0-9]+((E|e)(\+|-)?[0-9]+)?$/) {
        if (!CarryVec[f]) {
          if (margin_op == "*")
            CarryVec[f] = "1"
          else if (margin_op == "/")
            margin_op = ""
          else {
            CarryVec[f] = "0"
            if (active_key && margin_op == "-") margin_op = "+" }}
        t_carry = t_carry sep CarryVec[f] margin_op TruncVal(val) }
      else {
        t_carry = t_carry sep CarryVec[f] }}
    if (debug) print CA[c_agg_i]" :: ADVCARRYVEC: " t_carry sep CarryVec[f] margin_op val }

  if (!search && (!header || NR > 1)) {
    for (j = 1; j <= ra_count; j++) {
      if (RAgg[RA[j], NR] == "" || (NR == 1 && RAgg[RA[j], NR] == 0)) continue
      if (margin_op == "*" && Totals[c_agg_i, j] == "") Totals[c_agg_i, j] = 1
      if (debug)
        print NR" TOTALADV: RA "RA[j]", CA "CA[c_agg_i]" -- "Totals[c_agg_i, j] margin_op RAgg[RA[j], NR]
      Totals[c_agg_i, j] = EvalExpr(Totals[c_agg_i, j] margin_op RAgg[RA[j], NR]) }}

  return t_carry
}

function GenXExpr() { #TODO
  expr = ""
  return expr
}

function EvalExpr(expr) {
  res = 0
  nm = gsub(/\*-/, "*", expr)
  nm += gsub(/\/-/, "/", expr)
  gsub(/--/, "+", expr)
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
          if (d_i > 1 && d[d_i] != 0) d[1] /= d[d_i] }
        m[m_i] = d[1]; delete d
        if (m_i > 1) m[1] *= m[m_i] }
      s[s_i] = m[1]; delete m
      if (s_i > 1) s[1] -= s[s_i] }
    a[a_i] = s[1]; delete s }

  for (a_i in a)
    res += a[a_i]
  return nm % 2 ? -res : res
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

function TruncVal(val) {
  large_val = val > 999
  large_dec = val ~ /\.[0-9]{3,}/
  if ((large_val && large_dec) || /^-?[0-9]*\.?[0-9]+(E|e)\+?([4-9]|[1-9][0-9]+)$/)
    return int(val)
  else
    return sprintf("%f", val) # Small floats flow through this logic
}
