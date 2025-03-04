#!/bin/bash

source commands.sh

# SUBSEP TESTS

echo -n "Running subsep tests..."

# Basic subseparator test
actual="$(ds:subsep tests/data/subseps_test "SEP" | ds:reo 1,7 | cat)"
expected='A;A;A;A
G;G;G;G'
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed'

# CSV field separation test
expected='cdatetime,,,address
1,1,06 0:00,3108 OCCIDENTAL DR
1,1,06 0:00,2082 EXPEDITION WAY
1,1,06 0:00,4 PALEN CT
1,1,06 0:00,22 BECKFORD CT'
actual="$(ds:reo tests/data/testcrimedata.csv 1..5 1,2 | ds:subsep '/' "" -F,)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed readme case'

# Test empty field handling
echo -e "a::b:c\nd::e:f" > "${tmp}_empty"
expected="a  b c
d  e f"
actual="$(ds:subsep "${tmp}_empty" ":" | cat)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed empty field test'

# Test regex pattern with nomatch handler
echo -e "a[1]b[2]c\nd[3]e[4]f" > "${tmp}_regex"
expected="a 1 b 2 c
d 3 e 4 f"
actual="$(ds:subsep "${tmp}_regex" "\\[|\\]" " " | cat)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed regex pattern test'

# Test selective field processing
echo -e "a:b,c:d,e:f\n1:2,3:4,5:6" > "${tmp}_selective"
expected="a b,c:d,e f
1 2,3:4,5 6"
actual="$(ds:subsep "${tmp}_selective" ":" "" -v apply_to_fields=1,3 | cat)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed selective field test'

# Test pattern escaping
echo -e "a.b.c\nd.e.f" > "${tmp}_escape"
expected="a b c
d e f"
actual="$(ds:subsep "${tmp}_escape" "." "" -v escape=1 | cat)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed pattern escape test'

# Test whitespace handling with custom nomatch handler
echo -e "a  b\tc\nd\t\te  f" > "${tmp}_whitespace"
expected="a-b-c
d-e-f"
actual="$(ds:subsep "${tmp}_whitespace" "[[:space:]]+" "-" | cat)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed whitespace test'

# Test pattern retention
echo -e "key=val|key=val" > "${tmp}_retain"
expected="key val key val"
actual="$(ds:subsep "${tmp}_retain" "=" "" -v retain_pattern=0 | cat)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed pattern retention test'

# Test complex nested patterns
echo -e "a[x:y]b[p:q]c" > "${tmp}_nested"
expected="a x y b p q c"
actual="$(ds:subsep "${tmp}_nested" "\\[|\\]|:" " " | cat)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed nested pattern test'

# Test error handling for invalid field indices
expected="ERROR: No valid fields specified in apply_to_fields"
actual="$(ds:subsep "${tmp}_nested" ":" "" -v apply_to_fields=abc 2>&1)"
[[ "$actual" =~ "$expected" ]] || ds:fail 'sbsp failed invalid field index test'

# Test missing subsep_pattern handling
expected="ERROR: subsep_pattern must be set"
actual="$(ds:subsep "${tmp}_nested" "" 2>&1)"
[[ "$actual" =~ "$expected" ]] || ds:fail 'sbsp failed missing pattern test'

echo -e "${GREEN}PASS${NC}"
