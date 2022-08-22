#!/bin/bash

source commands.sh

# DIFF FIELDS TESTS

echo -n "Running diff fields tests..."

echo -e 'a 1 2 3 4\nb 3 4 2 1\nc 22 # , 2' > /tmp/ds_df_tests1
echo -e 'a 1 5 60 5\nb 3 7 2 7\nc 22 # , 2' > /tmp/ds_df_tests2
echo -e 'a 1 2 3 4\nb 3 4 2 1\nc 3 # , 2' > /tmp/ds_df_tests3

expected=' 0 -3 -57 -1
 0 -3 0 -6
 0   0'
actual="$(ds:diff_fields /tmp/ds_df_tests1 /tmp/ds_df_tests2)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed base case'

expected='a 0 1.5 19 0.25
b 0 0.75 0 6
c 0   0



ROW FIELD /tmp/ds_df_tests1 /tmp/ds_df_tests2 DIFF
a 4 3 60 19
b 5 1 7 6
a 3 2 5 1.5
b 3 4 7 0.75
a 5 4 5 0.25'
actual="$(ds:diff_fields /tmp/ds_df_tests1 /tmp/ds_df_tests2 % 1 -v diff_list=1)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed percent diff list case'

expected='ROW FIELD /tmp/ds_df_tests1 /tmp/ds_df_tests2 DIFF
a 5 4 5 0.8
b 3 4 7 0.571429
a 3 2 5 0.4
b 5 1 7 0.142857
a 4 3 60 0.05'
actual="$(ds:diff_fields /tmp/ds_df_tests1 /tmp/ds_df_tests2 / 1 -v diff_list=only)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed divide diff list only case'

expected='a 1 5 60 5
 0 0.75 0 6
 0   0



ROW FIELD /tmp/ds_df_tests1 /tmp/ds_df_tests2 DIFF
2 5 1 7 6
2 3 4 7 0.75'
actual="$(ds:diff_fields /tmp/ds_df_tests1 /tmp/ds_df_tests2 % -v header=1 -v diff_list=1)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed percent diff list header case'

expected='a 1 5 60 5
b 9 7 4 7
c 484 #  4'
actual="$(ds:diff_fields /tmp/ds_df_tests1 /tmp/ds_df_tests2 '*' 1,3 -v header=1)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed multiply fields header case'

expected='a 1 0.2 0.0166667 0.2
b 0.333333 0.142857 0.5 0.142857
c 0.333333 1 ,



ROW FIELD LEFTDATA /tmp/ds_df_tests3 DIFF
a 4 0.05 3 0.0166667
b 3 0.571429 4 0.142857
b 5 0.142857 1 0.142857
a 3 0.4 2 0.2
a 5 0.8 4 0.2
c 2 1 3 0.333333
b 2 1 3 0.333333
b 4 1 2 0.5'
actual="$(ds:diff_fields /tmp/ds_df_tests1 /tmp/ds_df_tests2 \
        /tmp/ds_df_tests3 / 1 -v diff_list=1 -v diff_list_sort=a \
        -v deterministic=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed multiple file diff list case'

rm /tmp/ds_df_tests1 /tmp/ds_df_tests2 /tmp/ds_df_tests3

echo -e "${GREEN}PASS${NC}"
