#!/bin/bash

source commands.sh

# PIVOT TESTS

echo -n "Running pivot tests..."

input='1 2 3 4
5 6 7 5
4 6 5 8'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@1@@@@@@@@@
6@@@@@@1@@@1@@@'
actual="$(echo "$input" | ds:pivot 2 1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed count z case'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@3::4@@@@@@@@@
6@@@@@@5::8@@@7::5@@@'
actual="$(echo "$input" | ds:pivot 2 1 0)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen z case'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@3@@@@@@@@@
6@@@@@@5@@@7@@@'
actual="$(echo "$input" | ds:pivot 2 1 3)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed spec z case'

expected='2 \ 4@@@5@@@8@@@
6@@@1@@@1@@@'
actual="$(echo "$input" | ds:pivot 2 4 -v header=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed basic header case'

expected='PIVOT@@@@@@4@@@d@@@
1@@@2@@@3@@@@@@
a@@@b@@@@@@c@@@'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot 1,2 4 3)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed readme multi-y case'

expected='Fields not found for both x and y dimensions with given key params'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot 1,2 4 3 -v gen_keys=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed basic header case no number matching'

expected='1::2 \ 4@@@@@@d@@@
a@@@b@@@c@@@'
actual="$(echo -e "1 2 3 4\na b c d" | ds:pivot 1,2 4 3 -v gen_keys=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys case number matching'

expected='a::b \ d@@@@@@4@@@
1@@@2@@@3@@@'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot a,b d c)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys case'

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
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys two matching case'

expected='halo \ wing::wind@@@2::4@@@6::5@@@6::8@@@
1@@@1@@@@@@@@@
4@@@@@@@@@1@@@
5@@@@@@1@@@@@@'
actual="$(echo "$input" | ds:pivot halo win,win)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys double same-pattern case'

# Test data setup
cat > test.csv << EOF
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
echo "Testing basic pivot functionality..."
ds:pivot test.csv Region Product Sales sum

# Test HAVING-like filters with min_count
echo -e "\nTesting min_count filter..."
ds:pivot test.csv Region Product Sales count -v min_count=2

# Test HAVING-like filters with min_sum
echo -e "\nTesting min_sum filter..."
ds:pivot test.csv Region Product Sales sum -v min_sum=200

# Test running totals
echo -e "\nTesting running totals..."
ds:pivot test.csv Region Product Sales sum -v show_running=1

# Test percentages
echo -e "\nTesting percentages..."
ds:pivot test.csv Region Product Sales sum -v show_percentages=1

# Test subtotals
echo -e "\nTesting subtotals..."
ds:pivot test.csv Region Product Sales sum -v show_subtotals=1

# Test combined features
echo -e "\nTesting combined statistical features..."
ds:pivot test.csv Region Product Sales sum -v show_running=1 -v show_percentages=1 -v show_subtotals=1

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

# Cleanup
rm test.csv

echo -e "${GREEN}PASS${NC}"
