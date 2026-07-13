#!/bin/bash

source commands.sh

# Solo runs need the same scratch path commands_tests.sh exports.
[ -n "${tmp:-}" ] || tmp=/tmp/ds_commands_tests

# EXTENDED REORDER TESTS
# -v knobs must follow rows/cols so they are not swallowed as the column arg.

echo -n "Running extended reorder tests..."

# chunk_size: wide single-row field slice (chunking is line-based; result parity)
input=$(seq 1 1000 | tr '\n' ' ')
actual="$(echo "$input" | ds:reo a 1..100 -v chunk_size=10)"
[ "$(echo "$actual" | wc -w)" -eq 100 ] || ds:fail 'reo failed chunk_size performance case'

# buffer_size: batch print threshold for wide rows
input=$(seq 1 500 | tr '\n' ' ')
actual="$(echo "$input" | ds:reo a 1..100 -v buffer_size=10)"
[ "$(echo "$actual" | wc -w)" -eq 100 ] || ds:fail 'reo failed buffer_size performance case'

# Empty fields
input='a,,c
,b,
c,,'
expected='a,,c
,b,
c,,'
actual="$(echo "$input" | ds:reo 1..3)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed empty fields case'

# Single-character rows reversed
input='a
b
c'
expected='c
b
a'
actual="$(echo "$input" | ds:reo 3..1)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed single char fields case'

# Unicode with explicit FS
input='α,β,γ
δ,ε,ζ'
expected='γ,β,α
ζ,ε,δ'
actual="$(echo "$input" | ds:reo a 3..1 -v FS=',')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed unicode handling case'

# Pattern caching (anchor the digit class; bare ^[1-5] also matches 10..)
input=$(seq 1 100 | tr '\n' ' ')
expected='1 2 3 4 5'
actual="$(echo "$input" | ds:reo a '[1~^[1-5]$' -v cache_patterns=1 | tr '\n' ' ' | xargs)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed pattern caching case'

# Exclusive row filter
input='start middle end
begin center finish'
expected='start middle end'
actual="$(echo "$input" | ds:reo '!~begin')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed exclusive row filter case'

# Field search (compound &&/|| filters remain deferred product work)
input='1,2,3
4,5,6
7,8,9'
expected='4,5,6'
actual="$(echo "$input" | ds:reo '2~5' a -v FS=',')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed field search case'

# Out-of-range index: no stdout
input='test'
actual="$(echo "$input" | ds:reo 999 2>/dev/null)"
[ -z "$actual" ] || ds:fail 'reo failed invalid range error case'

# Malformed frame: MatchCheck message (not silent pass-through of input)
actual="$(echo "$input" | ds:reo '[invalid' 2>/dev/null)"
[ "$actual" = "No matches found" ] || ds:fail 'reo failed malformed expression error case'

# Invalid chunk_size aborts with empty stdout
actual="$(echo "$input" | ds:reo 1 a -v chunk_size=-1 2>/dev/null)"
[ -z "$actual" ] || ds:fail 'reo failed invalid chunk size error case'

# Mixed types column reorder
input='123,abc,456
def,789,ghi
012,jkl,345'
expected='abc,123,456
789,def,ghi
jkl,012,345'
actual="$(echo "$input" | ds:reo a 2,1,3 -v FS=',')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed mixed data types case'

# Compound ranges must not wipe earlier Reo* slots (large second span)
input=$(seq 1 5 | awk '{print $1,$1*10,$1*100}')
# rows 1,2 then a descending span; both prefixes must appear
actual="$(echo "$input" | ds:reo '1,2,5..3' a)"
expected="$(echo "$input" | awk 'NR==1 || NR==2 || NR==5 || NR==4 || NR==3')"
# Compare via modular vs ensuring 5 lines in that order
[ "$(echo "$actual" | wc -l | tr -d ' ')" -eq 5 ] || ds:fail 'reo failed compound range length case'
line1="$(echo "$actual" | sed -n '1p')"
line2="$(echo "$actual" | sed -n '2p')"
line3="$(echo "$actual" | sed -n '3p')"
[ "$line1" = "$(echo "$input" | sed -n '1p')" ] || ds:fail 'reo failed compound range first row case'
[ "$line2" = "$(echo "$input" | sed -n '2p')" ] || ds:fail 'reo failed compound range second row case'
[ "$line3" = "$(echo "$input" | sed -n '5p')" ] || ds:fail 'reo failed compound range third row case'

echo -e "${GREEN}PASS${NC}"
