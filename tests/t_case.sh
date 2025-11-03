#!/bin/bash

source commands.sh

# CASE TESTS

echo -n "Running case tests..."

# Basic case tests
[ "$(echo "hello WORLD" | ds:case lc)" = "hello world" ] || ds:fail "lowercase failed"
[ "$(echo "hello WORLD" | ds:case uc)" = "HELLO WORLD" ] || ds:fail "uppercase failed"
[ "$(echo "hello WORLD" | ds:case pc)" = "Hello World" ] || ds:fail "proper case failed"

# New case types
[ "$(echo "hello world file.txt" | ds:case pathc)" = "hello/world/file/txt" ] || ds:fail "path case failed"
[ "$(echo "Hello World Test" | ds:case dc)" = "hello.world.test" ] || ds:fail "dot case failed"

# Smart casing tests
# TODO: Add smart casing tests

# Compound word tests
# [ "$(echo "pre-processing" | ds:case pc)" = "Pre-Processing" ] || ds:fail "compound word failed"
# [ "$(echo "cross-platform e-mail" | ds:case pc)" = "Cross-Platform E-Mail" ] || ds:fail "multiple compound words failed"

# Boundary detection tests
[ "$(echo "myVariableName" | ds:case sc -v boundary=1)" = "my_variable_name" ] || ds:fail "camel to snake failed"
# [ "$(echo "MyXMLParser" | ds:case pc -v boundary=1 -v smart=1)" = "My XML Parser" ] || ds:fail "complex boundary failed"
# [ "$(echo "version2.1testing" | ds:case pc -v boundary=1)" = "Version 2.1 Testing" ] || ds:fail "number boundary failed"

# Title case with strict rules
[ "$(echo "the quick brown fox" | ds:case tc -v strict=1)" = "The Quick Brown Fox" ] || ds:fail "title case failed"
[ "$(echo "a tale of two cities" | ds:case tc -v strict=1)" = "A Tale of Two Cities" ] || ds:fail "title case articles failed"

# Sentence case
[ "$(echo "THE QUICK BROWN FOX" | ds:case senc)" = "The quick brown fox" ] || ds:fail "sentence case failed"
# [ "$(echo "hello. world. test." | ds:case senc)" = "Hello. World. Test." ] || ds:fail "multiple sentence case failed"

# Alternating case
[ "$(echo "test string" | ds:case ac)" = "tEsT StRiNg" ] || ds:fail "alternating case failed"

# Preservation tests
# [ "$(echo "testing pH levels" | ds:case pc -v preserve="pH")" = "Testing pH Levels" ] || ds:fail "preserve case failed"
# [ "$(echo "mySQL database" | ds:case tc -v preserve="MySQL")" = "MySQL Database" ] || ds:fail "preserve brand failed"

# Complex mixed tests
# input="pre-processing XMLdata[v2.1] with 128KB"
# expected="Pre-Processing XML Data [v2.1] with 128KB"
# [ "$(echo "$input" | ds:case pc -v smart=1 -v boundary=1)" = "$expected" ] || ds:fail "complex mixed case failed"

# Edge cases
[ "$(echo "a.b-c_d/e" | ds:case pc)" = "A B C D E" ] || ds:fail "separator handling failed"
[ "$(echo "" | ds:case pc)" = "" ] || ds:fail "empty string failed"
# [ "$(echo "   " | ds:case pc)" = "   " ] || ds:fail "whitespace only failed"

# Multiple line tests
# input="hello world
# XML processing
# pre-formatted text"
# expected="Hello World
# XML Processing
# Pre-Formatted Text"
# [ "$(echo "$input" | ds:case pc -v smart=1)" = "$expected" ] || ds:fail "multiline failed"

echo -e "${GREEN}PASS${NC}"
