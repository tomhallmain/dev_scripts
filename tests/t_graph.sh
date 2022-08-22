#!/bin/bash

source commands.sh

# GRAPH TESTS

echo -n "Running graph tests..."

input="1:2\n2:3\n3:4"
expected='4:3:2:1'
actual="$(echo -e "$input" | ds:graph -v FS=:)"
[ "$actual" = "$expected" ] || ds:fail 'graph failed base case (non bases)'
expected='4
4:3
4:3:2
4:3:2:1'
actual="$(echo -e "$input" | ds:graph -v FS=: -v print_bases=1)"
[ "$actual" = "$expected" ] || ds:fail 'graph failed print_bases case 1'
input="2:1\n3:2\n4:3"
expected='1
1:2
1:2:3
1:2:3:4'
actual="$(echo -e "$input" | ds:graph -v print_bases=1)"
[ "$actual" = "$expected" ] || ds:fail 'graph failed print_bases case 2'

echo -e "${GREEN}PASS${NC}"
