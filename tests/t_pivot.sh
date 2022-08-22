#!/bin/bash.sh

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

echo -e "${GREEN}PASS${NC}"
