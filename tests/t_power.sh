#!/bin/bash

source commands.sh

# POWER TESTS

echo -n "Running power tests..."

expected="23,ACK,0
24,Mark,0
25,ACK
27,ACER PRESS,0
28,ACER PRESS
28,Mark
74,0"
actual="$(ds:pow tests/data/Sample100.csv 20 | cat)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed base case'

expected="0.22,3,5
0.26,3
0.5,4,5
0.53,4
0.74,5"
actual="$(ds:pow tests/data/Sample100.csv 20 t | cat)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed combin counts case'

expected='1 a b
1 e a
1 e d
1 q b
1 q d
2 a d
2 b d'
actual="$(echo -e "a b d\ne a d\nq b d" | ds:pow 1 f f -v choose=2)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 2 3-base case'


expected='1 a b
1 a c
1 b c
1 c d
1 e a
1 e b
1 e d
1 q a
1 q b
1 q d
2 b a
3 a d
3 b d'
actual="$(echo -e "a b c d\ne b a d\nq b a d" | ds:pow 1 f f -v choose=2)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 2 4-base case'

expected='1 1 2
1 1 3
1 1 4
1 1 5
1 1 6
1 1 7
1 2 3
1 2 4
1 2 5
1 2 6
1 2 7
1 3 4
1 3 5
1 3 6
1 3 7
1 4 5
1 4 6
1 4 7
1 5 6
1 5 7
1 6 7'
actual="$(echo 1 2 3 4 5 6 7 | ds:pow 1 f f -v choose=2 | sort -n)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 2 7-base case'

expected='1 a b d c
1 a d b c
2 a b c d
3 a b d
4 a b c
4 a d'
actual="$(echo -e "a b c d\na b c d\na b d c\na d b c" | ds:pow)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed combinations discrimination case'

expected='1 a b c
1 a b d
1 a c d
1 b c d'
actual="$(echo "a b c d" | ds:pow 1 f f -v choose=3)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 3 4-base case'

expected='1 a b c
1 a b d
1 a b e
1 a c d
1 a c e
1 a d e
1 b c d
1 b c e
1 b d e
1 c d e'
actual="$(echo "a b c d e" | ds:pow 1 f f -v choose=3)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 3 5-base case'

expected='1 a b c
1 a b d
1 a b e
1 a b f
1 a c d
1 a c e
1 a c f
1 a d e
1 a d f
1 a e f
1 b c d
1 b c e
1 b c f
1 b d e
1 b d f
1 b e f
1 c d e
1 c d f
1 c e f
1 d e f'
actual="$(echo "a b c d e f" | ds:pow 1 f f -v choose=3)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 3 6-base case'

expected='1 a b c d
1 a b c e
1 a b c f
1 a b d e
1 a b d f
1 a b e f
1 a c d e
1 a c d f
1 a c e f
1 a d e f
1 b c d e
1 b c d f
1 b c e f
1 b d e f
1 c d e f'
actual="$(echo -e "a b c d e f" | ds:pow 1 f f -v choose=4)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 4 6-base case'

echo -e "${GREEN}PASS${NC}"
