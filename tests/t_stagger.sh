#!/bin/bash

source commands.sh

# STAGGER TESTS

echo -n "Running stagger tests..."

# Create test data
cat > "${tmp}_stagger_basic" << EOL
short,medium value,very long value that needs wrapping
1,2,3
a,b,c with some extra text
EOL

# Test basic stagger format
expected='short
     medium value
          very long value that needs wrapping

1
     2
          3

a
     b
          c with some extra text'
actual="$(ds:stagger "${tmp}_stagger_basic" -F, | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger basic format test failed'

# Test box style
expected='┌──────────────────────────────────────────┐
│ short                                    │
│      medium value                        │
│           very long value that needs     │
│           ↪ wrapping                     │
│                                         │
│ 1                                       │
│      2                                  │
│           3                             │
│                                         │
│ a                                       │
│      b                                  │
│           c with some extra text        │
└──────────────────────────────────────────┘'
actual="$(ds:stagger "${tmp}_stagger_basic" -F, -v style=box -v wrap=smart -v tty_size=45 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger box style test failed'

# Test compact style
expected='short
  medium value
    very long value
    ↪ that needs
    ↪ wrapping

1
  2
    3

a
  b
    c with some
    ↪ extra text'
actual="$(ds:stagger "${tmp}_stagger_basic" -F, -v style=compact -v wrap=smart -v max_width=15 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger compact style test failed'

# Test character wrapping
cat > "${tmp}_stagger_long" << EOL
abcdefghijklmnopqrstuvwxyz,ABCDEFGHIJKLMNOPQRSTUVWXYZ
EOL

expected='abcdefghij
          klmnopqrs
          tuvwxyz

          ABCDEFGHI
          JKLMNOPQR
          STUVWXYZ'
actual="$(ds:stagger "${tmp}_stagger_long" -F, -v wrap=char -v max_width=10 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger character wrap test failed'

# Test with line numbers
expected='1     short
      medium value
           very long value that needs wrapping

2     1
      2
           3

3     a
      b
           c with some extra text'
actual="$(ds:stagger "${tmp}_stagger_basic" -F, -v numbers=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger line numbers test failed'

# Test alignment options
cat > "${tmp}_stagger_align" << EOL
left,center,right
short,medium,long value here
1,2,3
EOL

expected='left
     center
          right

short
       medium
               long value here

1
     2
          3'
actual="$(ds:stagger "${tmp}_stagger_align" -F, -v align=c | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger alignment test failed'

# Test empty fields and edge cases
cat > "${tmp}_stagger_edge" << EOL
,field2,
field1,,field3
,,
EOL

expected='
     field2
          

field1
     
          field3


     
          '
actual="$(ds:stagger "${tmp}_stagger_edge" -F, | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger empty fields test failed'

# Test single field
expected='single'
actual="$(echo "single" | ds:stagger | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger single field test failed'

# Test very wide fields with ellipsis
cat > "${tmp}_stagger_wide" << EOL
short,$(printf 'very%.0s' {1..50})long,last
EOL

expected='short
     veryveryveryveryveryveryveryveryveryvery...
          last'
actual="$(ds:stagger "${tmp}_stagger_wide" -F, -v max_width=40 -v ellipsis=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger ellipsis test failed'

# Test custom wrap character
expected='short
     medium value
          very long
          → value that
          → needs
          → wrapping'
actual="$(echo "short,medium value,very long value that needs wrapping" | ds:stagger -F, -v wrap_char="→" -v max_width=15 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger custom wrap character test failed'

# Test with no input
expected=''
actual="$(echo -n "" | ds:stagger | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger empty input test failed'

# Test with multiple delimiters
cat > "${tmp}_stagger_delim" << EOL
field1:field2;field3,field4
EOL

expected='field1
     field2
          field3
               field4'
actual="$(ds:stagger "${tmp}_stagger_delim" -F'[;,:]' | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'stagger multiple delimiters test failed'

echo -e "${GREEN}PASS${NC}" 