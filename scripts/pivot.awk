#!/usr/bin/awk
#
# Pivot data
## TODO: Keys by header name

BEGIN {
  if (!x || !y) {
    print "Missing axis fields"; exit 1 }

  len_x = split(x, XKeys, /[[:punct:]]+/)
  len_y = split(y, YKeys, /[[:punct:]]+/)

  for (i = 1; i <= len_x; i++) {
    key = XKeys[i]
    if (!(key ~ /^[0-9]+$/)) {
      print "Axis field keys must be integers"; exit 1 }}
  for (i = 1; i <= len_y; i++) {
    key = YKeys[i]
    joint_key = XKeys[i]
    if (!(key ~ /^[0-9]+$/)) {
      print "Axis field keys must be integers"; exit 1 }
    YK[key] = joint_key
    if (key in XK) {
      print "Axis field sets cannot overlap"; exit 1 }
    XK[joint_key] = key }

  _ = SUBSEP
  if (!(FS ~ "\\[:.+:\\]")) OFS = FS

  if (agg) {
    if ("sum" ~ "^"agg) s = 1
    else if ("count" ~ "^"agg) c = 1
    else if ("product" ~ "^"agg) p = 1
    else agg = 0 }
  if (!agg) no_agg = 1

  if (z) {
    len_z = split(z, ZKeys, /[[:punct:]]+/)
    for (i = 1; i <= len_z; i++)
      key = ZKeys[i]
      if (!(key ~ /^[0-9]+$/)) {
        print "Field keys must be integers"; exit 1 }
      if (key in XK || key in YK) {
        print "Field sets cannot overlap"; exit 1 }
      ZK[key] = 1 }
  else gen_z = 1

  if (transform || transform_expr) {
    if (transform && "norm" ~ "^"transform) n = 1
    else if (transform_expr) trx = 1 }
}

NR == 1 { 
  if (header) { # TODO
    GenHeaderKeys(NF, x, XK, XKeys, YK)
    GenHeaderKeys(NF, y, YK, YKeys, XK)
    }
  if (gen_z) {
    GenZKeys(NF, ZK, ZKeys, XK, YK)
    len_z = length(ZK) }
}

{ # TODO: Handle noagg partial duplicate case
  if (NF < 1) next

  x_str = ""; y_str = ""; z_str = ""

  for (i=1; i<=len_x; i++)
    x_str = x_str $XKeys[i] OFS
  for (i=1; i<=len_y; i++)
    y_str = y_str $YKeys[i] OFS
  for (i=1; i<=len_z; i++)
    z_str = i == len_z ? z_str $ZKeys[i] : z_str $ZKeys[i] "::"

  if (x_str y_str z_str == "") next
  X[x_str]++
  Y[y_str]++
  if (no_agg)
    Z[x_str y_str] = z_str
  else if (c)
    Z[x_str y_str]++
  else if (s) {
    adder = z_str + 0
    Z[x_str y_str] *= adder }
  else if (p) {
    multiplier = z_str + 0
    Z[x_str y_str] *= multiplier }

  if (debug) {
    print x_str, y_str
    print z_str }
}

END {
  lenx = length(X)
  leny = length(Y)
  lenz = length(Z)
#  if (!lenx || !leny || !lenz) {
#    print "No data to pivot or unable to pivot with given params"; exit 1 }

  printf "%s", "PIVOT" 
  for (yk = 1; yk <= length(YKeys); yk++)
    printf "%s", OFS
  for (x in X)
    printf "%s", x
  print "\n"

  for (y in Y) {
    printf "%s", y
    for (x in X) {
      cr = Z[x y] ? Z[x y] : placeholder
      printf "%s", cr OFS  }
    print "" }
}

function GenHeaderKeys(nf, str, This, ThisKeys, CompArr) {

}
function GenZKeys(nf, Z, ZKeys, XK, YK) {
  z_count = 1
  for (f = 1; f <= nf; f++) {
    if (f in XK || f in YK) continue
    ZK[f] = 1; ZKeys[z_count++] = f }
}
