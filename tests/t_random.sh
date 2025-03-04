#!/bin/bash

source commands.sh

# RANDOM TESTS

echo -n "Running random tests..."

# Test default mode (number generation)
result="$(ds:random)"
[[ "$result" =~ ^[0-9]+\.[0-9]+$ ]] || ds:fail 'random number generation failed'

# Test number mode with range
result="$(ds:random -v mode=number -v range=1,10)"
[[ "$result" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ds:fail 'random range failed'
(( $(echo "$result >= 1 && $result <= 10" | bc -l) )) || ds:fail 'random range bounds failed'

# Test number mode with format
result="$(ds:random -v mode=number -v format='%.2f')"
[[ "$result" =~ ^[0-9]+\.[0-9]{2}$ ]] || ds:fail 'random format failed'

# Test text mode pattern preservation
input="Test123!@#"
result="$(echo "$input" | ds:random -v mode=text)"
[[ "${#result}" == "${#input}" ]] || ds:fail 'text length preservation failed'
[[ "$result" =~ ^[A-Z][a-z][a-z][a-z][0-9][0-9][0-9]!@#$ ]] || ds:fail 'text pattern preservation failed'

# Test text mode with preserve option
input="Name: John123"
result="$(echo "$input" | ds:random -v mode=text -v preserve=': ')"
[[ "$result" =~ ^[A-Z][a-z][a-z][a-z]: [A-Z][a-z][a-z][a-z][0-9][0-9][0-9]$ ]] || ds:fail 'text preserve failed'

# Test password generation
result="$(ds:random -v mode=password -v length=12)"
[[ "${#result}" == 12 ]] || ds:fail 'password length failed'
[[ "$result" =~ [A-Z] ]] || ds:fail 'password uppercase failed'
[[ "$result" =~ [a-z] ]] || ds:fail 'password lowercase failed'
[[ "$result" =~ [0-9] ]] || ds:fail 'password number failed'
[[ "$result" =~ [!@#\$%^&*\(\)_+\-=\[\]\{\}\|;:,\.<>\?] ]] || ds:fail 'password special failed'

# Test password strength levels
result="$(ds:random -v mode=password -v strength=1 -v length=8)"
[[ "$result" =~ ^[A-Za-z0-9]{8}$ ]] || ds:fail 'password strength 1 failed'

# Test UUID generation
result="$(ds:random -v mode=uuid)"
[[ "$result" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]] || ds:fail 'uuid generation failed'

# Test pattern generation
result="$(ds:random -v mode=pattern -v pattern='LL-DD-SS')"
[[ "$result" =~ ^[A-Za-z]{2}-[0-9]{2}-[!@#\$%^&*\(\)_+\-=\[\]\{\}\|;:,\.<>\?]{2}$ ]] || ds:fail 'pattern generation failed'

# Test case options
result="$(ds:random -v mode=pattern -v pattern='LLLL' -v case=upper)"
[[ "$result" =~ ^[A-Z]{4}$ ]] || ds:fail 'uppercase pattern failed'

result="$(ds:random -v mode=pattern -v pattern='LLLL' -v case=lower)"
[[ "$result" =~ ^[a-z]{4}$ ]] || ds:fail 'lowercase pattern failed'

# Test custom charset
result="$(ds:random -v mode=pattern -v pattern='LLLL' -v charset='XYZ')"
[[ "$result" =~ ^[XYZ]{4}$ ]] || ds:fail 'custom charset failed'

# Test error handling
error="$(ds:random -v mode=invalid 2>&1)"
[[ "$error" =~ "ERROR: Invalid mode" ]] || ds:fail 'invalid mode error handling failed'

# Test multiple runs for consistency in length and pattern
for i in {1..5}; do
    result="$(ds:random -v mode=password -v length=10)"
    [[ "${#result}" == 10 ]] || ds:fail 'password consistency failed'
done

# Test randomization distribution
declare -A counts
for i in {1..100}; do
    digit="$(ds:random -v mode=pattern -v pattern='D')"
    ((counts[$digit]++))
done

# Check if each digit appears at least once (basic distribution test)
for i in {0..9}; do
    [[ "${counts[$i]}" -gt 0 ]] || ds:fail "random distribution failed for digit $i"
done

echo -e "${GREEN}PASS${NC}" 