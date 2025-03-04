#!/bin/bash

source commands.sh

# EXTENDED REORDER TESTS

echo -n "Running extended reorder tests..."

# Performance Tests
input=$(seq 1 1000 | tr '\n' ' ')
expected=$(seq 1 100 | tr '\n' ' ')
actual="$(echo "$input" | ds:reo 1..100 -v chunk_size=10)"
[ "$(echo "$actual" | wc -w)" -eq 100 ] || ds:fail 'reo failed chunk_size performance case'

# Large Field Tests
input=$(seq 1 500 | tr '\n' ' ')
expected=$(seq 1 100 | tr '\n' ' ')
actual="$(echo "$input" | ds:reo 1..100 -v buffer_size=10)"
[ "$(echo "$actual" | wc -w)" -eq 100 ] || ds:fail 'reo failed buffer_size performance case'

# Empty Field Tests
input='a,,c
,b,
c,,'
expected='a,,c
,b,
c,,'
actual="$(echo "$input" | ds:reo 1..3)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed empty fields case'

# Single Character Field Tests
input='a
b
c'
expected='c
b
a'
actual="$(echo "$input" | ds:reo 3..1)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed single char fields case'

# Unicode Tests
input='α,β,γ
δ,ε,ζ'
expected='γ,β,α
ζ,ε,δ'
actual="$(echo "$input" | ds:reo 3..1)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed unicode handling case'

# Pattern Caching Tests
input=$(seq 1 100 | tr '\n' ' ')
expected='1 2 3 4 5'
actual="$(echo "$input" | ds:reo '[1~^[1-5]' -v cache_patterns=1 | tr '\n' ' ' | xargs)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed pattern caching case'

# Multiple Anchor Tests
input='start,middle,end
begin,center,finish'
expected='start,middle,end'
actual="$(echo "$input" | ds:reo '/start/../end/ && !~begin')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed multiple anchors case'

# Complex Expression Tests
input='1,2,3
4,5,6
7,8,9'
expected='4,5,6'
actual="$(echo "$input" | ds:reo '(len(1)>0 && [2~5) || [3~6')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed complex expression case'

# Error Handling Tests
input='test'
actual="$(echo "$input" | ds:reo 999 2>/dev/null)"
[ -z "$actual" ] || ds:fail 'reo failed invalid range error case'

actual="$(echo "$input" | ds:reo '[invalid' 2>/dev/null)"
[ -z "$actual" ] || ds:fail 'reo failed malformed expression error case'

actual="$(echo "$input" | ds:reo 1 -v chunk_size=-1 2>/dev/null)"
[ -z "$actual" ] || ds:fail 'reo failed invalid chunk size error case'

# Mixed Data Type Tests
input='123,abc,456
def,789,ghi
012,jkl,345'
expected='abc,123,456
789,def,ghi
jkl,012,345'
actual="$(echo "$input" | ds:reo 2,1,3)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed mixed data types case'

echo -e "${GREEN}PASS${NC}" 