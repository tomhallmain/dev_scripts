#!/bin/bash

source commands.sh

# PREFIELD TESTS

echo -n "Running prefield tests..."

expected='Last Name@@@Street Address@@@First Name
Doe@@@120 jefferson st.@@@John
McGinnis@@@220 hobo Av.@@@Jack
Repici@@@120 Jefferson St.@@@"John ""Da Man"""
Tyler@@@"7452 Terrace ""At the Plaza"" road"@@@Stephen
Blankman@@@@@@
Jet@@@"9th, at Terrace plc"@@@"Joan ""the bone"", Anne"'
actual="$(ds:prefield tests/data/addresses_reordered , 1)"
[ "$expected" = "$actual" ] || ds:fail 'prefield failed base dq case'

expected='-rw-r--r--@@@1@@@tomhall@@@4330@@@Oct@@@12@@@11:55@@@emoji
-rw-r--r--@@@1@@@tomhall@@@0@@@Oct@@@3@@@17:30@@@file with space, and: commas & colons \ slashes
-rw-r--r--@@@1@@@tomhall@@@12003@@@Oct@@@3@@@17:30@@@infer_jf_test_joined.csv
-rw-r--r--@@@1@@@tomhall@@@5245@@@Oct@@@3@@@17:30@@@infer_join_fields_test1.csv
-rw-r--r--@@@1@@@tomhall@@@6043@@@Oct@@@3@@@17:30@@@infer_join_fields_test2.csv'
actual="$(ds:prefield tests/data/ls_sq '[[:space:]]+')"
[ "$expected" = "$actual" ] || ds:fail 'prefield failed base sq case'

expected='Conference room 1@@@John,  \n  Please bring the M. Mathers file for review   \n  -J.L.@@@10/18/2002@@@test, field
Conference room 1@@@John \n  Please bring the M. Mathers file for review \n  -J.L.@@@10/18/2002@@@
Conference room 1@@@@@@10/18/2002'
actual="$(ds:prefield tests/data/quoted_fields_with_newline.csv ,)"
[ "$expected" = "$actual" ] || ds:fail 'prefield failed newline lossy quotes case'

expected='Conference room 1@@@"John,   \n  Please bring the M. Mathers file for review   \n  -J.L."@@@10/18/2002@@@"test, field"
"Conference room 1"@@@"John, \n  Please bring the M. Mathers file for review \n  -J.L."@@@10/18/2002@@@""
"Conference room 1"@@@""@@@10/18/2002'
actual="$(ds:prefield tests/data/quoted_fields_with_newline.csv , 1)"
[ "$expected" = "$actual" ] || ds:fail 'prefield failed newline retain outer quotes case'

if ds:awksafe; then
    ds:prefield tests/data/quoted_multiline_fields.csv , > $tmp
    cmp tests/data/quoted_multiline_fields_prefield $tmp || ds:fail 'prefield failed complex newline quoted case'
else
    echo "Skipping complex newline quoted case - AWK configuration is not multibyte-character-safe"
fi

echo -e "${GREEN}PASS${NC}"
