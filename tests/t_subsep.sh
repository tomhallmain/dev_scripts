#!/bin/bash

source commands.sh

# SUBSEP TESTS

echo -n "Running subsep tests..."

actual="$(ds:subsep tests/data/subseps_test "SEP" | ds:reo 1,7 | cat)"
expected='A;A;A;A
G;G;G;G'
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed'

expected='cdatetime,,,address
1,1,06 0:00,3108 OCCIDENTAL DR
1,1,06 0:00,2082 EXPEDITION WAY
1,1,06 0:00,4 PALEN CT
1,1,06 0:00,22 BECKFORD CT'
actual="$(ds:reo tests/data/testcrimedata.csv 1..5 1,2 | ds:subsep '/' "" -F,)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed readme case'

echo -e "${GREEN}PASS${NC}"
