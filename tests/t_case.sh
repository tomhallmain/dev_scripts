#!/bin/bash

source commands.sh

# CASE TESTS

echo -n "Running case tests..."

input='test_vAriANt Case'

expected='test_variant case'
actual="$(echo "$input" | ds:case down)"
[ "$actual" = "$expected" ] || ds:fail 'case failed lower/down case'
expected='TEST_VARIANT CASE'
actual="$(echo "$input" | ds:case uc)"
[ "$actual" = "$expected" ] || ds:fail 'case failed upper case'
expected='Test V Ari Ant Case'
actual="$(echo "$input" | ds:case proper)"
[ "$actual" = "$expected" ] || ds:fail 'case failed proper case'
expected='testVAriAntCase'
actual="$(echo "$input" | ds:case cc)"
[ "$actual" = "$expected" ] || ds:fail 'case failed camel case'
expected='test_v_ari_ant_case'
actual="$(ds:case "$input" sc)"
[ "$actual" = "$expected" ] || ds:fail 'case failed snake case'
expected='TEST_V_ARI_ANT_CASE'
actual="$(ds:case "$input" var)"
[ "$actual" = "$expected" ] || ds:fail 'case failed variable case'
expected='Test.V.Ari.Ant.Case'
actual="$(ds:case "$input" ocase)"
[ "$actual" = "$expected" ] || ds:fail 'case failed object case'

echo -e "${GREEN}PASS${NC}"
