#!/bin/bash

source commands.sh

# SORT TESTS

echo -n "Running sort tests..."

input="$(echo -e "1:3:a#\$:z\n:test:test:one two:2\n5r:test:2%f.:dew::")"
actual="$(echo "$input" | ds:sort -k3)"
expected='5r:test:2%f.:dew::
1:3:a#$:z
:test:test:one two:2'
[ "$actual" = "$expected" ] || ds:fail 'sort failed'

actual="$(cat tests/data/seps_test_base | ds:sortm 2,3,7 d -v deterministic=1)"
expected="$(cat tests/data/seps_test_sorted)"
[ "$actual" = "$expected" ] || ds:fail 'sortm failed multikey case'

input='d c a b f
f e c b a
f e d c b
e d c b a'
output='d c a b f
f e d c b
f e c b a
e d c b a'
[ "$(echo "$input" | ds:sortm -v k=5,1 -v order=d)" = "$output" ] || ds:fail 'sortm failed awkargs case'

input="1\nJ\n98\n47\n9\n05\nj2\n9ju\n9\n9d"
output='1
05
9
9
9d
9ju
47
98
J
j2'
[ "$(echo -e "$input" | ds:sortm 1 a n)" = "$output" ] || ds:fail 'sortm failed numeric sort case'

input='Test Header 1,Test Header 2,Header,Test
3,88,h,3
,5,Eq,:
,,,

,a,1,
Yh,4304,45900,H'
output='Test Header 1,Test Header 2,Header,Test
,,,
,5,Eq,:
3,88,h,3
Yh,4304,45900,H
,a,1,'
[ "$(echo -e "$input" | ds:sortm "Test.Header.2,Header,Test" a n)" = "$output" ] || ds:fail 'sortm failed numeric sort gen keys case'

input='Button-2
Control-e
Control-C
Control-Return
Control-Tab
Control-a
Control-b
Control-d
Control-g
Control-h
F11
Control-j
Control-k
Control-n
MouseWheel
Control-q
Control-r
Control-s
Control-t
Next
Control-x
Control-z
Button-3
Control-w
Shift-F
Shift-A
Escape
Shift-B
Shift-C
Shift-D
Shift-E
Shift-Escape
Shift-G
Control-m
Shift-H
Shift-I
Prior
Shift-J
Shift-K
Shift-L
Home
Shift-N
Shift-M
Shift-Q
Shift-T
Shift-R
Shift-S
Shift-U
End
Shift-V
Shift-Z
Shift-Y'
output='End
Escape
F11
Home
MouseWheel
Next
Prior
Button-2
Button-3
Control-a
Shift-A
Control-b
Shift-B
Control-C
Shift-C
Control-d
Shift-D
Control-e
Shift-E
Shift-Escape
Shift-F
Control-g
Shift-G
Control-h
Shift-H
Shift-I
Control-j
Shift-J
Control-k
Shift-K
Shift-L
Control-m
Shift-M
Control-n
Shift-N
Control-q
Shift-Q
Control-r
Shift-R
Control-Return
Control-s
Shift-S
Control-t
Shift-T
Control-Tab
Shift-U
Shift-V
Control-w
Control-x
Shift-Y
Control-z
Shift-Z'
[ "$(echo -e "$input" | ds:sortm 2,1 a ni -F'-')" = "$output" ] || ds:fail 'sortm failed case-insensitive keyfield 2 sort case'

expected='a b c d
b a d f
c d e f
h i o p'
actual="$(echo -e "b a c d\nd c e f\na b d f\ni h o p" | ds:sortm -v multisort=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'Multisort simple char case ascending failed'

expected='p o i h
f e d c
f d a b
d c b a'
actual="$(echo -e "b a c d\nd c e f\na b d f\ni h o p" | ds:sortm "" d -v multisort=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'Multisort simple char case descending failed'

expected='2f 1
4 30
3oi 409'
actual="$(echo -e "1 2f\n409 3oi\n30 4" | ds:sortm 1 a n -v multisort=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'Multisort number ascending case failed'

echo -e "${GREEN}PASS${NC}"
