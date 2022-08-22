#!/bin/bash

source commands.sh

# FC TESTS

echo -n "Running fieldcounts and uniq tests..."

expected='2 mozy,Mozy,26,web,American Fork,UT,1-May-05,1900000,USD,a
2 zoominfo,ZoomInfo,80,web,Waltham,MA,1-Jul-04,7000000,USD,a'
actual="$(ds:fieldcounts tests/data/company_funding_data.csv a 2)"
[ "$expected" = "$actual" ] || ds:fail 'fieldcounts failed all field case'
expected='54,1-Jan-08
54,1-Oct-07'
actual="$(ds:fieldcounts tests/data/company_funding_data.csv 7 50)"
[ "$expected" = "$actual" ] || ds:fail 'fieldcounts failed single field case'
expected='7,450,Palo Alto,facebook'
actual="$(ds:fieldcounts tests/data/company_funding_data.csv 3,5,1 6)"
[ "$expected" = "$actual" ] || ds:fail 'fieldcounts failed multifield case'

input='a\nb\nc\n1\ne\nc\nb\na\ni\nc\n55\n3'
expected='a
b
c
e
i
1
3
55'
[ "$(echo -e "$input" | ds:uniq)" = "$expected" ] || ds:fail 'uniq failed defaults case'

expected='a
b
c'
[ "$(echo -e "$input" | ds:uniq 0 2)" = "$expected" ] || ds:fail 'uniq failed min 2 case'

expected='c'
[ "$(echo -e "$input" | ds:uniq 1 3)" = "$expected" ] || ds:fail 'uniq failed min 3 case'

expected='55
3
1
i
e
c
b
a'
[ "$(echo -e "$input" | ds:uniq 1 1 d)" = "$expected" ] || ds:fail 'uniq failed descending case'

echo -e "${GREEN}PASS${NC}"
