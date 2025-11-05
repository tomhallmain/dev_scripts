#!/bin/bash

source commands.sh

# PIVOT TESTS

echo -n "Running pivot tests..."

[ -z "$tmp" ] && tmp=/tmp/ds_commands_tests

input='1 2 3 4
5 6 7 5
4 6 5 8'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@1@@@@@@@@@
6@@@@@@1@@@1@@@'
actual="$(echo "$input" | ds:pivot 2 1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: count aggregation (z=_) failed'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@3::4@@@@@@@@@
6@@@@@@5::8@@@7::5@@@'
actual="$(echo "$input" | ds:pivot 2 1 0)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: use remaining fields (z=0) failed'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@3@@@@@@@@@
6@@@@@@5@@@7@@@'
actual="$(echo "$input" | ds:pivot 2 1 3)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: specified z field failed'

expected='2 \ 4@@@5@@@8@@@
6@@@1@@@1@@@'
actual="$(echo "$input" | ds:pivot 2 4 -v header=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed basic header case'

expected='PIVOT@@@@@@4@@@d@@@
1@@@2@@@3@@@@@@
a@@@b@@@@@@c@@@'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot 1,2 4 3)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: multiple y keys failed'

expected='Fields not found for both x and y dimensions with given key params'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot 1,2 4 3 -v gen_keys=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: failed basic header case no number matching (gen_keys=1)'

expected='1::2 \ 4@@@@@@d@@@
a@@@b@@@c@@@'
actual="$(echo -e "1 2 3 4\na b c d" | ds:pivot 1,2 4 3 -v gen_keys=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: header key generation with numeric headers (gen_keys=1) failed'

expected='a::b \ d@@@@@@4@@@
1@@@2@@@3@@@'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot a,b d c)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: header key pattern matching failed'

input='halo wing top wind
1 2 3 4
5 6 7 5
4 6 5 8'
expected='Fields not found for both x and y dimensions with given key params'
actual="$(echo "$input" | ds:pivot halo twef)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys negative case'

expected='halo \ wing@@@2@@@6@@@
1@@@1@@@@@@
4@@@@@@1@@@
5@@@@@@1@@@'
actual="$(echo "$input" | ds:pivot halo win)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: header pattern matching multiple fields failed'

expected='halo \ wing::wind@@@2::4@@@6::5@@@6::8@@@
1@@@1@@@@@@@@@
4@@@@@@@@@1@@@
5@@@@@@1@@@@@@'
actual="$(echo "$input" | ds:pivot halo win,win)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: duplicate header pattern matching failed'

# Test data setup
cat > "$tmp" << EOF
Region,Product,Sales
North,Widget,100
North,Gadget,200
South,Widget,150
South,Gadget,300
East,Widget,125
East,Gadget,275
West,Widget,175
West,Gadget,325
EOF

# Basic pivot test (baseline)
expected='Region \ Product@@@Gadget@@@Widget@@@
East@@@275@@@125@@@
North@@@200@@@100@@@
South@@@300@@@150@@@
West@@@325@@@175@@@'
actual="$(ds:pivot "$tmp" Region Product Sales sum)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: basic sum aggregation failed'

# Test HAVING-like filters with min_count
expected='Region \ Product@@@Gadget@@@Widget@@@
East@@@1@@@1@@@
North@@@1@@@1@@@
South@@@1@@@1@@@
West@@@1@@@1@@@'
actual="$(ds:pivot "$tmp" Region Product Sales count -v min_count=2)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: min_count filter failed'

# Test HAVING-like filters with min_sum
expected='Region \ Product@@@Gadget@@@Widget@@@
East@@@275@@@125@@@
North@@@200@@@100@@@
South@@@300@@@150@@@
West@@@325@@@175@@@'
actual="$(ds:pivot "$tmp" Region Product Sales sum -v min_sum=200)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: min_sum filter failed'

# Test running totals
expected='Region \ Product@@@Gadget@@@Running@@@Widget@@@Running@@@
East@@@275@@@275@@@125@@@400@@@
North@@@200@@@200@@@100@@@300@@@
South@@@300@@@300@@@150@@@450@@@
West@@@325@@@325@@@175@@@500@@@'
actual="$(ds:pivot "$tmp" Region Product Sales sum -v show_running=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: show_running failed'

# Test percentages
expected='Region \ Product@@@Gadget@@@%@@@Widget@@@%@@@
East@@@275@@@68.8%@@@125@@@31.2%@@@
North@@@200@@@66.7%@@@100@@@33.3%@@@
South@@@300@@@66.7%@@@150@@@33.3%@@@
West@@@325@@@65.0%@@@175@@@35.0%@@@'
actual="$(ds:pivot "$tmp" Region Product Sales sum -v show_percentages=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: show_percentages failed'

# Test subtotals
expected='Region \ Product@@@Gadget@@@Widget@@@Total@@@
East@@@275@@@125@@@400@@@
North@@@200@@@100@@@300@@@
South@@@300@@@150@@@450@@@
West@@@325@@@175@@@500@@@
TOTAL@@@1100@@@550@@@1650@@@'
actual="$(ds:pivot "$tmp" Region Product Sales sum -v show_subtotals=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: show_subtotals failed'

# Test combined features
expected='Region \ Product@@@Gadget@@@Running@@@%@@@Widget@@@Running@@@%@@@Total@@@
East@@@275@@@275@@@68.8%@@@125@@@400@@@31.2%@@@400@@@
North@@@200@@@200@@@66.7%@@@100@@@300@@@33.3%@@@300@@@
South@@@300@@@300@@@66.7%@@@150@@@450@@@33.3%@@@450@@@
West@@@325@@@325@@@65.0%@@@175@@@500@@@35.0%@@@500@@@
TOTAL@@@1100@@@1100@@@66.7%@@@550@@@550@@@33.3%@@@1650@@@'
actual="$(ds:pivot "$tmp" Region Product Sales sum -v show_running=1 -v show_percentages=1 -v show_subtotals=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot: combined statistical features failed'

# Expected output format examples:
#
# Basic pivot:
# Region \ Product  Widget  Gadget
# North            100     200
# South            150     300
# East             125     275
# West             175     325
#
# With running totals:
# Region \ Product  Widget  Running  Gadget  Running
# North            100     100      200     300
# South            150     250      300     550
#
# With percentages:
# Region \ Product  Widget    %    Gadget    %
# North            100     33.3    200    66.7
# South            150     33.3    300    66.7
#
# With subtotals:
# Region \ Product  Widget  Gadget  Total
# North            100     200     300
# South            150     300     450
# East             125     275     400
# West             175     325     500
# Total            550    1100    1650

echo -e "${GREEN}PASS${NC}"
