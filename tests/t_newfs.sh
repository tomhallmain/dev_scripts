#!/bin/bash

source commands.sh

# NEWFS TESTS

echo -n "Running newfs tests..."

expected='Joan "the bone", Anne::Jet::9th, at Terrace plc::Desert City::CO::00123'
actual="$(ds:newfs tests/data/addresses.csv :: | grep -h Joan)"
[ "$expected" = "$actual" ] || ds:fail 'newfs command failed'

echo -e "${GREEN}PASS${NC}"
