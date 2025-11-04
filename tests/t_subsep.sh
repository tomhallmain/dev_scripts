#!/bin/bash

source commands.sh

# SUBSEP TESTS

# Set up temporary file if not already set
[ -z "$tmp" ] && tmp=/tmp/ds_commands_tests

echo -n "Running subsep tests..."

# Basic subseparator test
actual="$(ds:subsep tests/data/subseps_test "SEP" | ds:reo 1,7 | cat)"
expected='A;A;A;A
G;G;G;G'
[ "$expected" = "$actual" ] || ds:fail 'subsep failed basic test'

# CSV field separation test - README example: preserves comma field separator
expected='cdatetime,,,address
1,1,06 0:00,3108 OCCIDENTAL DR
1,1,06 0:00,2082 EXPEDITION WAY
1,1,06 0:00,4 PALEN CT
1,1,06 0:00,22 BECKFORD CT'
actual="$(ds:reo tests/data/testcrimedata.csv 1..5 1,2 | ds:subsep '/' "" -F,)"
[ "$expected" = "$actual" ] || ds:fail 'subsep failed readme case'

# Test CSV with selective field processing - preserves comma field separator
echo -e "a:b,c:d,e:f\n1:2,3:4,5:6" > "$tmp"
expected="a,b,c:d,e,f
1,2,3:4,5,6"
actual="$(ds:subsep "$tmp" ":" "" -F, -v apply_to_fields=1,3 | cat)"
[ "$expected" = "$actual" ] || ds:fail 'subsep failed selective field test with CSV'

# Test basic field splitting with space separator (piped input)
expected="a b c d"
actual="$(echo -e "a/b c/d" | ds:subsep "/" "" | cat)"
[ "$expected" = "$actual" ] || ds:fail 'subsep failed basic field splitting with pipe'

# Test empty subfield handling with space separator
echo -e "a::b:c\nd::e:f" > "$tmp"
expected="a::b:c
d::e:f"
actual="$(ds:subsep "$tmp" ":" | cat)"
[ "$expected" = "$actual" ] || ds:fail 'subsep failed empty subfield test'

# Test regex pattern with nomatch handler - uses regex flag for explicit regex matching
echo -e "a[1]b[2]c\nd[3]e[4]f" > "$tmp"
expected="a 1 b 2 c
d 3 e 4 f"
actual="$(ds:subsep "$tmp" "\\[|\\]" " " -v regex=1 | cat)"
[ "$expected" = "$actual" ] || ds:fail 'subsep failed regex pattern test'

# Test pattern escaping
echo -e "a.b.c\nd.e.f" > "$tmp"
expected="a b c
d e f"
actual="$(ds:subsep "$tmp" "." "" -v escape=1 | cat)"
[ "$expected" = "$actual" ] || ds:fail 'subsep failed pattern escape test'

# Test error handling for invalid field indices
echo -e "a:b:c" > "$tmp"
expected="ERROR: No valid fields specified in apply_to_fields"
actual="$(ds:subsep "$tmp" ":" "" -v apply_to_fields=abc 2>&1)"
[[ "$actual" =~ "$expected" ]] || ds:fail 'subsep failed invalid field index test'

# Test missing subsep_pattern handling
echo -e "a:b:c" > "$tmp"
expected="ERROR: subsep_pattern must be set"
actual="$(ds:subsep "$tmp" "" 2>&1)"
[[ "$actual" =~ "$expected" ]] || ds:fail 'subsep failed missing pattern test'

echo -e "${GREEN}PASS${NC}"
