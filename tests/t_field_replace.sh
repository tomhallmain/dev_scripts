#!/bin/bash

source commands.sh

# FIELD_REPLACE TESTS

echo -n "Running field replace tests..."

input='1:2:3:4:
4:3:2:5:6
::::
4:6:2:4'
expected='11:2:3:4:
-1:3:2:5:6
11::::
-1:6:2:4'
actual="$(echo "$input" | ds:field_replace 'val > 2 ? -1 : 11')"
[ "$expected" = "$actual" ] || ds:fail 'field_replace failed only replacement_func case'

expected='1:11:3:4:
4:-1:2:5:6
::::
4:-1:2:4'
actual="$(echo "$input" | ds:field_replace 'val > 2 ? -1 : 11' 2 '[0-9]')"
[ "$expected" = "$actual" ] || ds:fail 'field_replace failed all args case'

echo -e "${GREEN}PASS${NC}"
