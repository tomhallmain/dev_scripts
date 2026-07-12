#!/bin/bash

source commands.sh

# Solo runs need the same scratch path commands_tests.sh exports.
[ -n "${tmp:-}" ] || tmp=/tmp/ds_commands_tests

# JOIN ORDER TESTS
# Locks deterministic unmatched-left key order (GetSortedKeys) and stable
# compound-key assembly. Matched rows still follow right-file stream /
# recordwise join order — goldens reflect that live contract (not a full
# re-sort of all output by join key).

echo -n "Running join order tests..."

odir=$(mktemp -d /tmp/ds_join_order.XXXXX) || ds:fail 'join order tmp dir failed'

cat > "$odir/order1.csv" << 'EOD'
id,value
1,a
2,b
2,c
1,d
EOD

cat > "$odir/order2.csv" << 'EOD'
id,data
1,x
2,y
2,z
1,w
EOD

# Duplicate keys: recordwise pairing in right-file order (1,2,2,1), not
# grouped by key as in the original draft expectation.
expected='id,value,data
1,a,x
2,b,y
2,c,z
1,d,w'
actual="$(ds:join "$odir/order1.csv" "$odir/order2.csv" outer 1)"
[ "$actual" = "$expected" ] || ds:fail 'ds:join order failed duplicate keys case'

# Pipe vs file: same inputs must match file-file output.
actual_pipe="$(cat "$odir/order2.csv" | ds:join "$odir/order1.csv" outer 1)"
[ "$actual_pipe" = "$expected" ] || ds:fail 'ds:join order failed pipe vs file smoke'

cat > "$odir/merge1.csv" << 'EOD'
id,val1,val2
1,a,b
2,c,d
3,e,f
EOD

cat > "$odir/merge2.csv" << 'EOD'
id,val1,val2
2,x,y
3,m,n
4,p,q
EOD

# Merge+bias: right/inner rows first in stream order; unmatched left (id=1)
# last via sorted END walk.
expected='id,val1,val2
2,x,y
3,m,n
4,p,q
1,a,b'
actual="$(ds:join "$odir/merge1.csv" "$odir/merge2.csv" outer merge -v bias_merge_keys=2,3)"
[ "$actual" = "$expected" ] || ds:fail 'ds:join order failed merge bias case'

cat > "$odir/multi1.csv" << 'EOD'
region,year,value
East,2020,100
West,2020,200
East,2021,300
West,2021,400
EOD

cat > "$odir/multi2.csv" << 'EOD'
region,year,target
East,2020,110
West,2020,220
East,2021,330
West,2021,440
EOD

# Multi-key: right-file stream order (not region-grouped draft order).
expected='region,year,value,target
East,2020,100,110
West,2020,200,220
East,2021,300,330
West,2021,400,440'
actual="$(ds:join "$odir/multi1.csv" "$odir/multi2.csv" outer 1,2)"
[ "$actual" = "$expected" ] || ds:fail 'ds:join order failed multi-key case'

cat > "$odir/null1.csv" << 'EOD'
id,value
1,
2,b
,c
3,d
EOD

cat > "$odir/null2.csv" << 'EOD'
id,data
1,x
,y
3,z
4,w
EOD

# Null/empty keys: matches in right-file order; unmatched left id=2 sorted in END.
expected='id,value,data
1,,x
<NULL>,c,y
3,d,z
4,<NULL>,w
2,b,<NULL>'
actual="$(ds:join "$odir/null1.csv" "$odir/null2.csv" outer 1)"
[ "$actual" = "$expected" ] || ds:fail 'ds:join order failed null/empty keys case'

# Cross-awk stability when a second awk binary is available (branch goal).
_join_order_run_awk() {
    local awkbin="$1" left="$2" right="$3"
    LC_ALL=C "$awkbin" -v FS=',' -v OFS=',' -v fs1=',' -v fs2=',' \
        -v join=outer -v k=1 \
        -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/join.awk" \
        "$left" "$right" 2>/dev/null
}

_base_out=""
_base_awk=""
for _a in awk gawk nawk mawk; do
    command -v "$_a" >/dev/null 2>&1 || continue
    _out="$(_join_order_run_awk "$_a" "$odir/order1.csv" "$odir/order2.csv")"
    if [ -z "$_base_out" ]; then
        _base_out="$_out"
        _base_awk="$_a"
    elif [ "$_out" != "$_base_out" ]; then
        ds:fail "ds:join order differs across awks ($_base_awk vs $_a)"
    fi
done

rm -rf "$odir"

echo -e "${GREEN}PASS${NC}"
