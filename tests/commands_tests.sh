#!/bin/bash
#
## TODO: Git tests

NC="\033[0m" # No Color
GREEN="\033[0;32m"
test_var=1
tmp=/tmp/ds_commands_tests
q=/dev/null
shell="$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')"
cmds="support/commands"
test_cmds="tests/data/commands"
png='assets/gcv_ex.png'
jnf1="tests/data/infer_join_fields_test1.csv"
jnf2="tests/data/infer_join_fields_test2.csv"
jnf3="tests/data/infer_join_fields_test3.scsv"
jnd1="tests/data/infer_jf_test_joined.csv"
jnd2="tests/data/infer_jf_joined_fit"
jnd3="tests/data/infer_jf_joined_fit_dz"
jnd4="tests/data/infer_jf_joined_fit_sn"
jnd5="tests/data/infer_jf_joined_fit_d2"
jnr1="tests/data/jn_repeats1"
jnr2="tests/data/jn_repeats2"
jnr3="tests/data/jn_repeats3"
jnr4="tests/data/jn_repeats4"
jnrjn1="tests/data/jn_repeats_jnd1"
jnrjn2="tests/data/jn_repeats_jnd2"
seps_base="tests/data/seps_test_base"
seps_sorted="tests/data/seps_test_sorted" 
simple_csv="tests/data/company_funding_data.csv"
simple_csv2="tests/data/testcrimedata.csv"
complex_csv1="tests/data/addresses.csv"
complex_csv3="tests/data/addresses_reordered"
complex_csv2="tests/data/Sample100.csv"
complex_csv4="tests/data/quoted_fields_with_newline.csv" 
complex_csv5="tests/data/taxables.csv"
complex_csv6="tests/data/quoted_multiline_fields.csv"
complex_csv6_prefield="tests/data/quoted_multiline_fields_prefield"
ls_sq="tests/data/ls_sq"
floats="tests/data/floats_test"
inferfs_chunks="tests/data/inferfs_chunks_test"
emoji="tests/data/emoji"
emojifit="tests/data/emojifit"
emoji_fit_gridlines="tests/data/emoji_fit_gridlines"
commands_fit_gridlines="tests/data/commands_shrink_fit_gridlines"
number_comma_format="tests/data/number_comma_format"

if [[ $shell =~ 'bash' ]]; then
    bsh=0
    cd "${BASH_SOURCE%/*}/.."
    source commands.sh
    $(ds:fail 'testfail' &> $tmp)
    testfail=$(cat $tmp)
    [[ $testfail =~ '_err_: testfail' ]] || echo 'fail command failed in bash case'
elif [[ $shell =~ 'zsh' ]]; then
    cd "$(dirname $0)/.."
    source commands.sh
    $(ds:fail 'testfail' &> $tmp)
    testfail=$(cat $tmp)
    [[ $testfail =~ '_err_: Operation intentionally failed' ]] || echo 'fail command failed in zsh case'
else
    echo 'unhandled shell detected - only zsh/bash supported at this time'
    exit 1
fi

# BASICS TESTS

echo -n "Running basic commands tests..."

[[ $(ds:sh | grep -c "") = 1 && $(ds:sh) =~ sh ]]    || ds:fail 'sh command failed'

ch="@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE"
ds:commands "" "" 0 > $q
cmp --silent $cmds $test_cmds && grep -q "$ch" $cmds || ds:fail 'commands listing failed'

ds:file_check "$png" f t &> /dev/null                || ds:fail 'file check disallowed binary files in allowed case'

output="COMMAND@@@DESCRIPTION@@@USAGE@@@
ds:help@@@Print help for a given command@@@ds:help ds_command@@@"
[ "$(ds:help 'ds:help')" = "$output" ]               || ds:fail 'help command failed'
ds:nset 'ds:nset' 1> $q                              || ds:fail 'nset command failed'
ds:searchn 'ds:searchn' 1> $q                        || ds:fail 'searchn failed on func search'
ds:searchn 'test_var' 1> $q                          || ds:fail 'searchn failed on var search'
[ "$(ds:ntype 'ds:ntype')" = 'FUNC' ]                || ds:fail 'ntype command failed'

# zsh trace output in subshell lists a file descriptor
if [[ $shell =~ 'zsh' ]]; then
    ds:trace 'echo test' &>$tmp
    grep -e "+ds:trace:8> eval 'echo test'" -e "+(eval):1> echo test" $tmp &>$q || ds:fail 'trace command failed'
elif [[ $shell =~ 'bash' ]]; then
    expected="++++ echo test\ntest"
    [ "$(ds:trace 'echo test' 2>$q)" = "$(echo -e "$expected")" ] || ds:fail 'trace command failed'
fi

# GIT COMMANDS TESTS

[ $(ds:git_recent_all | awk '{print $3}' | grep -c "") -gt 2 ] \
    || echo 'git recent all failed, possibly due to no git dirs in home'

echo -e "${GREEN}PASS${NC}"

# IFS TESTS

echo -n "Running inferfs and inferh tests..."

[ "$(ds:inferfs $jnf1)" = ',' ]                             || ds:fail 'inferfs failed extension case'
[ "$(ds:inferfs $seps_base)" = '\&\%\#' ]                   || ds:fail 'inferfs failed custom separator case 1'
[ "$(ds:inferfs $jnf3)" = '\;\;' ]                          || ds:fail 'inferfs failed custom separator case 2'
echo -e "wefkwefwl=21\nkwejf ekej=qwkdj\nTEST 349=|" > $tmp
[ "$(ds:inferfs $tmp)" = '\=' ]                             || ds:fail 'inferfs failed custom separator case 3'
[ "$(ds:inferfs $ls_sq)" = '[[:space:]]+' ]                 || ds:fail 'inferfs failed quoted fields case'
[ "$(ds:inferfs $complex_csv3)" = ',' ]                     || ds:fail 'inferfs failed quoted fields case'
[ "$(ds:inferfs $inferfs_chunks)" = ',' ]                   || ds:fail 'inferfs failed simple chunks case'

# INFERH TESTS

ds:inferh $seps_base 2>$q                                   && ds:fail 'inferh failed custom separator noheaders case'
ds:inferh $ls_sq 2>$q                                       && ds:fail 'inferh failed ls noheaders case'
ds:inferh $simple_csv 2>$q                                  || ds:fail 'inferh failed basic headers case'
ds:inferh $complex_csv3 2>$q                                || ds:fail 'inferh failed complex headers case'

echo -e "${GREEN}PASS${NC}"

# JOIN TESTS

echo -n "Running join tests..."

echo -e "a b c d\n1 2 3 4" > $tmp
expected='a b c d b c
1 2 3 4 3 2'
actual="$(echo -e "a b c d\n1 3 2 4" | ds:join $tmp inner 1,4)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed readme single keyset case'
actual="$(echo -e "a b c d\n1 3 2 4" | ds:join $tmp inner "a,d")"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed readme single keyset gen keys case'
expected='a c b d
1 2 3 4'
actual="$(echo -e "a b c d\n1 3 2 4" | ds:join $tmp right 1,2,3,4 1,3,2,4)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed readme multi-keyset case'
actual="$(echo -e "a b c d\n1 3 2 4" | ds:join $tmp right a,b,c,d "a,c,b,d")"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed readme multi-keyset gen keys case'
expected='a b c d
1 3 2 4
1 2 3 4'
actual="$(echo -e "a b c d\n1 3 2 4" | ds:join $tmp outer merge)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed readme merge case'
expected='a b c d d
1 3 2  4
1 2 3 4 '
actual="$(echo -e "a b c d\n1 3 2 4" | ds:join $tmp outer merge -v mf_max=3 -v null_off=1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed mf_max null_off case'

echo -e "a 1\na 2\nb 2\nc 1\nb 1" > /tmp/ds_join_test1
echo -e "a 1\na 2\na 3\na 4\na 3" > /tmp/ds_join_test2

expected='a 1 1
a 2 2
a <NULL> 3
a <NULL> 4
a <NULL> 3
b 2 <NULL>
b 1 <NULL>
c 1 <NULL>'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 o 1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed extra unmatched right join case'
expected='a 1 1
a 2 1
a 1 2
a 2 2
a 1 3
a 2 3
a 1 4
a 2 4
a 1 3
a 2 3
b 2 <NULL>
b 1 <NULL>
c 1 <NULL>'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 o 1 -v standard_join=1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed standard join case'
expected="$(join /tmp/ds_join_test1 /tmp/ds_join_test2 | sort)"
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 i 1 -v standard_join=1 | sort)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed inner join unix join case'

[ $(ds:join "$jnf1" "$jnf2" o 1 | grep -c "") -gt 15 ]        || ds:fail 'ds:join failed one-arg shell case'
[ $(ds:join "$jnf1" "$jnf2" r -v ind=1 | grep -c "") -gt 15 ] || ds:fail 'ds:join failed awkarg nonkey case'
[ $(ds:join "$jnf1" "$jnf2" l -v k=1 | grep -c "") -gt 15 ]   || ds:fail 'ds:join failed awkarg key case'
[ $(ds:join "$jnf1" "$jnf2" i 1 | grep -c "") -gt 15 ]        || ds:fail 'ds:join failed inner join case'

ds:join "$jnf1" "$jnf2" -v ind=1 > $tmp
cmp --silent $tmp $jnd1                                     || ds:fail 'ds:join failed base outer join case'
cat "$jnf2" | ds:join "$jnf1" -v ind=1 > $tmp
cmp --silent $tmp $jnd1                                     || ds:fail 'ds:join failed base outer join case piped infer key'
ds:join "$jnr1" "$jnr2" o 2,3,4,5 > $tmp
cmp --silent $tmp $jnrjn1                                   || ds:fail 'ds:join failed repeats partial keyset case'
ds:join "$jnr1" "$jnr2" o "h,j,f,total" > $tmp
cmp --silent $tmp $jnrjn1                                   || ds:fail 'ds:join failed repeats partial keyset gen keys case'
ds:join "$jnr3" "$jnr4" o merge -v merge_verbose=1 > $tmp
cmp --silent $tmp $jnrjn2                                   || ds:fail 'ds:join failed repeats merge case'

echo -e "a b d f\nd c e f" > /tmp/ds_join_test1
echo -e "a b d f\nd c e f\ne r t a\nt o y l" > /tmp/ds_join_test2
echo -e "a b l f\nd p e f\ne o t a\nt p y 6" > /tmp/ds_join_test3

expected='a b d f a d f a l f'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 i 2)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 2-join inner case'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 i b)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 2-join inner gen key case'

expected='a b l f
d p e f
e o t a
t p y 6
a b d f
d c e f
t o y l
e r t a'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 o merge)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 2-join merge case'

expected='a <NULL> l <NULL> <NULL> <NULL> b f
d c e f c f p f
e <NULL> t <NULL> r a o a
t <NULL> y <NULL> o l p 6
a b d f b f <NULL> <NULL>'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 o 1,3)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 2-join multikey case 1'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 o a,d -v inherit_keys=1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 2-join multikey case 1 - gen and inherit keys'

expected='a b d f b d b l
d c e f c e p e
e <NULL> <NULL> a r t o t
t <NULL> <NULL> 6 <NULL> <NULL> p y
t <NULL> <NULL> l o y <NULL> <NULL>'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 o 4,1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 2-join multikey case 2'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 o "f,a")"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 2-join multikey gen keys case 2'

echo -e "a b d 3\nd c e f" > /tmp/ds_join_test4

expected='a b d f b d f b l f b d 3
d c e f c e f p e f c e f'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 /tmp/ds_join_test4 i 1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 3-join inner case'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 /tmp/ds_join_test4 i a)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 3-join inner gen key case'

expected='a b d f b f <NULL> <NULL> b 3
d c e f c f p f c f
t <NULL> y <NULL> o l p 6 <NULL> <NULL>
e <NULL> t <NULL> r a o a <NULL> <NULL>
a <NULL> l <NULL> <NULL> <NULL> b f <NULL> <NULL>'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 /tmp/ds_join_test4 o 1,3)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 3-join outer case'

echo -e "a,b,c,d\n1,2,3,4\n1,2,2,5" > /tmp/ds_join_test1
echo -e "a b c d\n1 3 2 4" > /tmp/ds_join_test2
echo -e "a b c d\n1 3 2\n1 2 3 7" > /tmp/ds_join_test3

expected='a,b,c,d
1,3,2,4
1,2,3,7
1,2,2,5'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 outer merge -v bias_merge_keys=4)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 3-join bias merge default case'

expected='a,b,c,d
1,3,2,<NULL>
1,2,3,7
1,2,2,<NULL>'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 outer merge -v bias_merge_keys=4 -v full_bias=1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 3-join bias merge full_bias case'

expected='a,b,c,d
1,3,2,
1,2,3,7
1,2,2,'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 outer merge -v bias_merge_keys=4 -v full_bias=1 -v null_off=1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 3-join bias merge full_bias null_off case'
actual="$(ds:join /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 outer merge -v bias_merge_exclude_keys=1,2,3 -v full_bias=1 -v null_off=1)"
[ "$actual" = "$expected" ]                                 || ds:fail 'ds:join failed 3-join bias merge exclude keys full_bias null_off case'

rm /tmp/ds_join_test1 /tmp/ds_join_test2 /tmp/ds_join_test3 /tmp/ds_join_test4

cat "$jnf1" > $tmp
ds:comps $jnf1 $tmp                                         || ds:fail 'comps failed no complement case'
[ $(ds:comps $jnf1 $tmp -v verbose=1 | grep -c "") -eq 7 ]  || ds:fail 'comps failed no complement verbose case'
[ "$(ds:comps $jnf1{,})" = 'Files are the same!' ]          || ds:fail 'comps failed no complement samefile case'
[ $(ds:comps $jnf1 $jnf2 -v k1=2 -v k2=3,4 -v verbose=1 | grep -c "") -eq 196 ] \
                                                            || ds:fail 'comps failed complments case'

[ "$(ds:matches $jnf1 $jnf2 -v k1=2 -v k2=2)" = "NO MATCHES FOUND" ] \
                                                            || ds:fail 'matches failed no matches case'
[ $(ds:matches $jnf1 $jnf2 -v k=1 | grep -c "") = 167 ]     || ds:fail 'matches failed matches case'
[ $(ds:matches $jnf1 $jnf2 -v k=1 -v verbose=1 | grep -c "") = 169 ] \
                                                            || ds:fail 'matches failed matches case'

echo -e "${GREEN}PASS${NC}"

# SORT TESTS

echo -n "Running sort tests..."

input="$(echo -e "1:3:a#\$:z\n:test:test:one two:2\n5r:test:2%f.:dew::")"
actual="$(echo "$input" | ds:sort -k3)"
expected='5r:test:2%f.:dew::
1:3:a#$:z
:test:test:one two:2'
[ "$actual" = "$expected" ] || ds:fail 'sort failed'

actual="$(cat $seps_base | ds:sortm 2,3,7 d -v deterministic=1)"
expected="$(cat $seps_sorted)"
[ "$actual" = "$expected" ] || ds:fail 'sortm failed multikey case'

input='d c a b f
f e c b a
f e d c b
e d c b a'
output='d c a b f
f e d c b
f e c b a
e d c b a'
[ "$(echo "$input" | ds:sortm -v k=5,1 -v order=d)" = "$output" ] || ds:fail 'sortm failed awkargs case'

input="1\nJ\n98\n47\n9\n05\nj2\n9ju\n9\n9d" 
output='1
05
9
9
9d
9ju
47
98
J
j2'
[ "$(echo -e "$input" | ds:sortm 1 a n)" = "$output" ] || ds:fail 'sortm failed numeric sort case'

input='Test Header 1,Test Header 2,Header,Test
3,88,h,3
,5,Eq,:
,,,

,a,1,
Yh,4304,45900,H'
output='Test Header 1,Test Header 2,Header,Test
,,,
,5,Eq,:
3,88,h,3
Yh,4304,45900,H
,a,1,'
[ "$(echo -e "$input" | ds:sortm "Test.Header.2,Header,Test" a n)" = "$output" ] || ds:fail 'sortm failed numeric sort gen keys case'

expected='a b c d
b a d f
c d e f
h i o p'
actual="$(echo -e "b a c d\nd c e f\na b d f\ni h o p" | ds:sortm -v multisort=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'Multisort simple char case ascending failed'

expected='p o i h
f e d c
f d a b
d c b a'
actual="$(echo -e "b a c d\nd c e f\na b d f\ni h o p" | ds:sortm "" d -v multisort=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'Multisort simple char case descending failed'

expected='2f 1
4 30
3oi 409'
actual="$(echo -e "1 2f\n409 3oi\n30 4" | ds:sortm 1 a n -v multisort=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'Multisort number ascending case failed'

echo -e "${GREEN}PASS${NC}"


# PREFIELD TESTS

echo -n "Running prefield tests..."

expected='Last Name@@@Street Address@@@First Name
Doe@@@120 jefferson st.@@@John
McGinnis@@@220 hobo Av.@@@Jack
Repici@@@120 Jefferson St.@@@"John ""Da Man"""
Tyler@@@"7452 Terrace ""At the Plaza"" road"@@@Stephen
Blankman@@@@@@
Jet@@@"9th, at Terrace plc"@@@"Joan ""the bone"", Anne"'
actual="$(ds:prefield $complex_csv3 , 1)"
[ "$expected" = "$actual" ] || ds:fail 'prefield failed base dq case'

expected='-rw-r--r--@@@1@@@tomhall@@@4330@@@Oct@@@12@@@11:55@@@emoji
-rw-r--r--@@@1@@@tomhall@@@0@@@Oct@@@3@@@17:30@@@file with space, and: commas & colons \ slashes
-rw-r--r--@@@1@@@tomhall@@@12003@@@Oct@@@3@@@17:30@@@infer_jf_test_joined.csv
-rw-r--r--@@@1@@@tomhall@@@5245@@@Oct@@@3@@@17:30@@@infer_join_fields_test1.csv
-rw-r--r--@@@1@@@tomhall@@@6043@@@Oct@@@3@@@17:30@@@infer_join_fields_test2.csv'
actual="$(ds:prefield $ls_sq '[[:space:]]+')"
[ "$expected" = "$actual" ] || ds:fail 'prefield failed base sq case'

expected='Conference room 1@@@John,  \n  Please bring the M. Mathers file for review   \n  -J.L.@@@10/18/2002@@@test, field
Conference room 1@@@John \n  Please bring the M. Mathers file for review \n  -J.L.@@@10/18/2002@@@
Conference room 1@@@@@@10/18/2002'
actual="$(ds:prefield $complex_csv4 ,)"
[ "$expected" = "$actual" ] || ds:fail 'prefield failed newline lossy quotes case'

expected='Conference room 1@@@"John,   \n  Please bring the M. Mathers file for review   \n  -J.L."@@@10/18/2002@@@"test, field"
"Conference room 1"@@@"John, \n  Please bring the M. Mathers file for review \n  -J.L."@@@10/18/2002@@@""
"Conference room 1"@@@""@@@10/18/2002'
actual="$(ds:prefield $complex_csv4 , 1)"
[ "$expected" = "$actual" ] || ds:fail 'prefield failed newline retain outer quotes case'

ds:prefield $complex_csv6 , > $tmp
cmp $complex_csv6_prefield $tmp || ds:fail 'prefield failed complex newline quoted case'

echo -e "${GREEN}PASS${NC}"

# REO TEST

echo -n "Running reorder tests..."

input='d c a b f
f e c b a
f e d c b
e d c b a'
output='f e c b a'
[ "$(echo "$input" | ds:reo 2)" = "$output" ] || ds:fail 'reo failed base row case'

output='c
e
e
d'
[ "$(echo "$input" | ds:reo a 2)" = "$output" ] || ds:fail 'reo failed base column case'

output='a c d e b
f a c d b'
[ "$(echo "$input" | ds:reo 4,1 5,3..1,4)" = "$output" ] || ds:fail 'reo failed base compound range reo case'
[ "$(echo "$input" | ds:reo 4,1 5,3..1,4 -v FS="[[:space:]]")" = "$output" ] || ds:fail 'reo failed FS arg case'
[ "$(echo "$PATH" | ds:reo 1 5,3..1,4 -F: | ds:transpose | grep -c "")" -eq 5 ] || ds:fail 'reo failed F arg case'

output='f b'
[ "$(echo "$input" | ds:reo '4!~b' '!~c')" = "$output" ] || ds:fail 'reo failed exclusive search case'

input='1:2:3:4:5
5:4:3:2:1
::6::
:3::2:1'

actual="$(echo "$input" | ds:reo '>5' off)"
[ "$actual" = "::6::" ]         || ds:fail 'reo failed c off case'

actual="$(echo "$input" | ds:reo '~6' off)"
[ "$actual" = "::6::" ]         || ds:fail 'reo failed c off case'

actual="$(echo "$input" | ds:reo '6##2' '3##' | cat)"
expected='6::
3:2:1
3:4:5'
[ "$actual" = "$expected" ] || ds:fail 'reo failed anchor case'

actual="$(echo "$input" | ds:reo '/6/../2/' '/3/..' | cat)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed anchor_re case'

actual="$(echo "$input" | ds:reo '6##2' '##3' | cat)"
expected='::6
5:4:3
1:2:3'
[ "$actual" = "$expected" ] || ds:fail 'reo failed anchor case'
actual="$(echo "$input" | ds:reo '/6/../2/' '../3/' | cat)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed anchor_re case'

expected=':3
3:6'
actual="$(echo "$input" | ds:reo 3 3 -v idx=1)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed indx idx case'

expected=':4:3
4:2:
3::6'
actual="$(echo "$input" | ds:reo 4..3 4..3 -v idx=1)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed rev range idx case'

expected=':5:4:3:2:1
4:1:2::3:
3:::6::
2:1:2:3:4:5
1:5:4:3:2:1'
actual="$(echo "$input" | ds:reo rev rev -v idx=1)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed rev idx case'

actual="$(ds:commands | grep 'ds:' | ds:reo 'len()>130' off)"
expected='**@@@ds:diff_fields@@@ds:df@@@Get elementwise diff of two datasets@@@ds:df file [file*] [op=-] [exc_fields=0] [prefield=f] [awkargs]'
[ "$actual" = "$expected" ] || ds:fail 'reo failed full row len case'

actual="$(ds:commands | grep 'ds:' | ds:reo 'len(4)>46' 2)"
expected='ds:dups
ds:insert
ds:jira
ds:path_elements'
[ "$actual" = "$expected" ] || ds:fail 'reo failed basic len case'

actual="$(ds:commands | grep 'ds:' | ds:reo 'len(2)%11 || len(2)=13' 'length()<5 && len()>2')"
expected='@@@
ds:gb@@@
@@@
ds:gr@@@
ds:gsq@@@
ds:gs@@@
@@@' # probably a false field here.
[ "$actual" = "$expected" ] || ds:fail 'reo failed extended len case'

actual="$(echo "$input" | ds:reo 1 'len()>0,len()<2' -v uniq=1)"
expected='1:2:3:4:5:'
[ "$actual" = "$expected" ] || ds:fail 'reo failed uniq col case'

actual="$(echo "$input" | ds:reo 'len(1)>0,len(1)<2' 3 -v uniq=1)"
expected='3
3
6'
[ "$actual" = "$expected" ] || ds:fail 'reo failed uniq row case'


input=$(for i in $(seq -16 16); do
    printf "%s " $i; printf "%s " $(echo "-1*$i" | bc)
    if [ $(echo "$i%5" | bc) -eq 0 ]; then echo test; else echo nah; fi; done)
expected='-1 nah
-2 nah
-3 nah
-4 nah
-5 test
-6 nah
-7 nah
-8 nah
-9 nah
-10 test
-11 nah
-12 nah
-13 nah
-14 nah
-15 test
-16 nah
15 test
10 test
5 test
0 test
-5 test
-10 test
-15 test'
[ "$(echo "$input" | ds:reo "2<0, 3~test" "31!=14")" = "$expected" ] || ds:fail 'reo failed extended cases'

input="$(for i in $(seq -10 20); do 
      [ $i -eq -10 ] && ds:iter test 23 " " && echo && ds:iter _TeST_ 20 " " && echo
      for j in $(seq -2 20); do 
          [ $i -ne 0 ] && printf "%s " "$(echo "scale=2; $j/$i" | bc -l)"
      done
      [ $i -ne 0 ] && echo; done)"
actual="$(echo "$input" | ds:reo "1,1,>4, [test, [test/i~ST" ">4, [test~T" -v cased=1)"
expected='test test test test test test test test test test test test test test test test test
test test test test test test test test test test test test test test test test test
5.00 6.00 7.00 8.00 9.00 10.00 11.00 12.00 13.00 14.00 15.00 16.00 17.00 18.00 19.00 20.00 -2.00
2.50 3.00 3.50 4.00 4.50 5.00 5.50 6.00 6.50 7.00 7.50 8.00 8.50 9.00 9.50 10.00 -1.00
1.66 2.00 2.33 2.66 3.00 3.33 3.66 4.00 4.33 4.66 5.00 5.33 5.66 6.00 6.33 6.66 -.66
1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00 -.50
test test test test test test test test test test test test test test test test test
test test test test test test test test test test test test test test test test test
_TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_    _TeST_'
[ "$actual" = "$expected" ] || ds:fail 'reo failed extended cases'

input='d c a b f
f e c b a
f e d c b
e d c b a'
actual="$(echo "$input" | ds:reo "1,1, others, [a" ">4, rev, [f~d")"
expected=' f b a c d d a
 f b a c d d a
 a b c e f f c
 b c d e f f d
 a b c d e e c'
[ "$actual" = "$expected" ] || ds:fail 'reo failed extended others or reverse cases'

actual="$(echo "$input" | ds:reo "1,1,others,[a" ">4,rev,[f~d")"
expected=' f b a c d d a
 f b a c d d a
 a b c e f f c
 b c d e f f d
 a b c d e e c'
[ "$actual" = "$expected" ] || ds:fail 'reo failed extended others or reverse cases'

actual="$(echo "$input" | ds:reo "[a~c && 5~a" "[f~d || [e~a && NF>3")"
expected='a
a'
[ "$(echo -e "$actual" | tr -d " ")" = "$expected" ] || ds:fail 'reo failed extended logic cases'

actual="$(ds:reo $seps_base ">100&&%7" "%7")"
expected='7&%#2
420&%#1'
[ "$actual" = "$expected" ] || ds:fail 'reo failed extended logic cases'

actual="$(ds:reo $seps_base '5[2!~2' | grep -h "^1")"
[ "$(ds:reo $seps_base '5[2!=2 && 5[2!=23' | grep -h "^1")" = "$actual" ] || ds:fail 'reo failed comparison case'

head -n5 tests/data/company_funding_data.csv > $tmp

expected='company,category,city,raisedAmt,raisedCurrency,round
Facebook,web,Palo Alto,300000000,USD,c
ZeniMax,web,Rockville,300000000,USD,a'
actual="$(ds:reo $simple_csv '1, >200000000' '[^c, [^r')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed readme case 1'
expected='b,1-May-07
a,1-Oct-06
c,1-Jan-08'
actual="$(ds:reo $tmp '[lifelock' '[round,[funded')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed readme case 2'
expected='LifeLock,1-Jan-08
MyCityFaces,1-Jan-08
LifeLock,1-Oct-06
LifeLock,1-May-07
company,fundedDate'
actual="$(ds:reo $tmp '~Jan-08 && NR<6, 3..1' '[company,~Jan-08')"
[ "$actual" = "$expected" ] || ds:fail 'reo failed readme case 3'
expected='b,USD,6850000,1-May-07,AZ,Tempe,web,,LifeLock,lifelock
a,USD,6000000,1-Oct-06,AZ,Tempe,web,,LifeLock,lifelock
c,USD,25000000,1-Jan-08,AZ,Tempe,web,,LifeLock,lifelock
seed,USD,50000,1-Jan-08,AZ,Scottsdale,web,7,MyCityFaces,mycityfaces
c,USD,25000000,1-Jan-08,AZ,Tempe,web,,LifeLock,lifelock
a,USD,6000000,1-Oct-06,AZ,Tempe,web,,LifeLock,lifelock
b,USD,6850000,1-May-07,AZ,Tempe,web,,LifeLock,lifelock
round,raisedCurrency,raisedAmt,fundedDate,state,city,category,numEmps,company,permalink'
actual="$(ds:reo $tmp '!~permalink && !~mycity,rev' rev)"
[ "$actual" = "$expected" ] || ds:fail 'reo failed extended logic + rev cases'

echo -e "${GREEN}PASS${NC}"


# FIT TESTS

echo -n "Running fit tests..."

fit_var_present="$(echo -e "t 1\nte 2\ntes 3\ntest 4" | ds:fit -v color=never | awk '{cl=length($0);if(pl && pl!=cl) {print 1;exit};pl=cl}')"
[ "$fit_var_present" = 1 ]                          && ds:fail 'fit failed pipe case'

expected='Desert City' actual="$(ds:fit "$complex_csv1" | ds:reo 7 4 '-F {2,}')"
[ "$expected" = "$actual" ]                         || ds:fail 'fit failed base case'

expected='Company Name                            Employee Markme       Description
INDIAN HERITAGE ,ART & CULTURE          MADHUKAR              ACCESS PUBLISHING INDIA PVT.LTD
ETHICS, INTEGRITY & APTITUDE ( 3RD/E)   P N ROY ,G SUBBA RAO  ACCESS PUBLISHING INDIA PVT.LTD
PHYSICAL, HUMAN AND ECONOMIC GEOGRAPHY  D R KHULLAR           ACCESS PUBLISHING INDIA PVT.LTD'
actual="$(ds:reo "$complex_csv2" 1,35,37,42 2..4 | ds:fit -F, -v color=never)"
[ "$(echo -e "$expected")" = "$actual" ]            || ds:fail 'fit failed quoted field case'

ds:fit $emoji > $tmp; cmp --silent $emojifit $tmp   || ds:fail 'fit failed emoji case'

expected='-rw-r--r--  1  tomhall   4330  Oct  12  11:55  emoji
-rw-r--r--  1  tomhall      0  Oct   3  17:30  file with space, and: commas & colons \ slashes
-rw-r--r--  1  tomhall  12003  Oct   3  17:30  infer_jf_test_joined.csv
-rw-r--r--  1  tomhall   5245  Oct   3  17:30  infer_join_fields_test1.csv
-rw-r--r--  1  tomhall   6043  Oct   3  17:30  infer_join_fields_test2.csv'
[ "$(ds:fit $ls_sq -v color=never)" = "$expected" ] || ds:fail 'fit failed ls sq case'

ds:fit $jnd1 -v bufferchar="|" -v no_zero_blank=1 > $tmp
cmp --silent $jnd2 $tmp || ds:fail 'fit failed bufferchar/decimal case'
ds:fit $jnd1 -v bufferchar="|" -v d=z -v no_zero_blank=1 > $tmp
cmp --silent $jnd3 $tmp || ds:fail 'fit failed const decimal case'
ds:fit $jnd1 -v bufferchar="|" -v d=-2 -v no_zero_blank=1 > $tmp
cmp --silent $jnd4 $tmp || ds:fail 'fit failed scientific notation / float output case'
ds:fit $jnd1 -v bufferchar="|" -v d=2 -v no_zero_blank=1 > $tmp
cmp --silent $jnd5 $tmp || ds:fail 'fit failed fixed 2-place decimal case'

#add dec_off check

expected="Index  Item                              Cost   Tax  Total
    1  Fruit of the Loom Girl's Socks    7.97  0.60   8.57
    2  Rawlings Little League Baseball   2.97  0.22   3.19
    3  Secret Antiperspirant             1.29  0.10   1.39
    4  Deadpool DVD                     14.96  1.12  16.08
    5  Maxwell House Coffee 28 oz        7.28  0.55   7.83
    6  Banana Boat Sunscreen, 8 oz       6.68  0.50   7.18
    7  Wrench Set, 18 pieces            10.00  0.75  10.75
    8  M and M, 42 oz                    8.98  0.67   9.65
    9  Bertoli Alfredo Sauce             2.12  0.16   2.28"
[ "$(ds:fit $complex_csv5 -v color=never | head)" = "$expected" ] || ds:fail 'fit failed spaced quoted field case'

expected="┌─────┬─────────────────────────────────┬───────┬──────┬───────┐
│Index│  Item                           │   Cost│   Tax│  Total│
├─────┼─────────────────────────────────┼───────┼──────┼───────┤
│    1│  Fruit of the Loom Girl's Socks │   7.97│  0.60│   8.57│
├─────┼─────────────────────────────────┼───────┼──────┼───────┤
│    2│  Rawlings Little League Baseball│   2.97│  0.22│   3.19│
├─────┼─────────────────────────────────┼───────┼──────┼───────┤
│    3│  Secret Antiperspirant          │   1.29│  0.10│   1.39│
├─────┼─────────────────────────────────┼───────┼──────┼───────┤
│    4│  Deadpool DVD                   │  14.96│  1.12│  16.08│
└─────┴─────────────────────────────────┴───────┴──────┴───────┘"
actual="$(head -n5 tests/data/taxables.csv | ds:fit -v gridlines=1 -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed README case'

input='# Test comment 1
1,2,3,4,5,100
a,b,c,d,e,f
g,h,i,j,k,l,m,f,o
,,2,3,5,1
# Test comment 2
// Diff style comment'

expected='# Test comment 1
1,2,3,4,5,100
a                      b  c  d  e  f
g                      h  i  j  k  l  m  f  o
                          2  3  5  1
# Test comment 2
// Diff style comment'
actual="$(echo -e "$input" | ds:fit -F, -v startfit=a -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed startfit case'

expected='# Test comment 1
1  2  3  4  5  100
a  b  c  d  e  f
g,h,i,j,k,l,m,f,o
,,2,3,5,1
# Test comment 2
// Diff style comment'
actual="$(echo -e "$input" | ds:fit -F, -v startfit=2 -v endfit=f -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed startfit endfit case'

expected='# Test comment 1
1  2  3  4  5  100
a  b  c  d  e  f
g  h  i  j  k  l    m  f  o
      2  3  5  1
# Test comment 2
// Diff style comment'
actual="$(echo -e "$input" | ds:fit -F, -v startrow=2 -v endrow=5 -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed startrow endrow case'

expected='# Test comment 1
1,2,3,4,5,100
a  b  c  d  e  f
g  h  i  j  k  l  m  f  o
,,2,3,5,1
# Test comment 2
// Diff style comment'
actual="$(echo -e "$input" | ds:fit -F, -v onlyfit='^[a-z]' -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed onlyfit case'

expected='# Test comment 1
1,2,3,4,5,100
a  b  c  d  e  f
g,h,i,j,k,l,m,f,o
      2  3  5  1
# Test comment 2
// Diff style comment'
actual="$(echo -e "$input" | ds:fit -F, -v nofit='(^1|^#|^//|o$)' -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed nofit case'

expected="# Test comment 1
┌─┬───┬───┬───┬───┬─────┬───┬───┬───┐
│1│  2│  3│  4│  5│  100│   │   │   │
├─┼───┼───┼───┼───┼─────┼───┼───┼───┤
│a│  b│  c│  d│  e│  f  │   │   │   │
├─┼───┼───┼───┼───┼─────┼───┼───┼───┤
│g│  h│  i│  j│  k│  l  │  m│  f│  o│
├─┼───┼───┼───┼───┼─────┼───┼───┼───┤
│ │   │  2│  3│  5│  1  │   │   │   │
└─┴───┴───┴───┴───┴─────┴───┴───┴───┘
# Test comment 2
// Diff style comment"
actual="$(echo -e "$input" | ds:fit -F, -v startrow=2 -v endrow=5 -v color=never -v gridlines=1 | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed startrow endrow gridlines case'

expected="# Test comment 1
┌─────────────────────┬───┬───┬───┬───┬─────┬───┬───┬───┐
│1                    │  2│  3│  4│  5│  100│   │   │   │
├─────────────────────┼───┼───┼───┼───┼─────┼───┼───┼───┤
│a                    │  b│  c│  d│  e│  f  │   │   │   │
├─────────────────────┼───┼───┼───┼───┼─────┼───┼───┼───┤
│g                    │  h│  i│  j│  k│  l  │  m│  f│  o│
├─────────────────────┼───┼───┼───┼───┼─────┼───┼───┼───┤
│                     │   │  2│  3│  5│  1  │   │   │   │
├─────────────────────┼───┼───┼───┼───┼─────┼───┼───┼───┤
│# Test comment 2     │   │   │   │   │     │   │   │   │
├─────────────────────┼───┼───┼───┼───┼─────┼───┼───┼───┤
│// Diff style comment│   │   │   │   │     │   │   │   │
└─────────────────────┴───┴───┴───┴───┴─────┴───┴───┴───┘"
actual="$(echo -e "$input" | ds:fit -F, -v startrow=2 -v color=never -v gridlines=1 | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed startrow only gridlines case'

expected="┌────────────────┬───┬───┬───┬───┬─────┐
│# Test comment 1│   │   │   │   │     │
├────────────────┼───┼───┼───┼───┼─────┤
│1               │  2│  3│  4│  5│  100│
├────────────────┼───┼───┼───┼───┼─────┤
│a               │  b│  c│  d│  e│  f  │
└────────────────┴───┴───┴───┴───┴─────┘
g,h,i,j,k,l,m,f,o
,,2,3,5,1
# Test comment 2
// Diff style comment"
actual="$(echo -e "$input" | ds:fit -F, -v endrow=3 -v color=never -v gridlines=1 | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed endrow only gridlines case'

expected="# Test comment 1
┌─┬───┬───┬───┬───┬─────┐
│1│  2│  3│  4│  5│  100│
├─┼───┼───┼───┼───┼─────┤
│a│  b│  c│  d│  e│  f  │
└─┴───┴───┴───┴───┴─────┘
g,h,i,j,k,l,m,f,o
,,2,3,5,1
# Test comment 2
// Diff style comment"
actual="$(echo -e "$input" | ds:fit -F, -v startfit=2 -v endfit=f -v color=never -v gridlines=1 | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed startfit endfit gridlines case'

input="one two three four + *\n-7 -5 -7 -1 -20 -48\n0.0833 0.1667 0.0938 1.333 0.01 0.0017"
expected='    one      two    three    four       +         *
-7.0000  -5.0000  -7.0000  -1.000  -20.00  -48.0000
 0.0833   0.1667   0.0938   1.333    0.01    0.0017'
actual="$(echo -e "$input" | ds:fit -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed negative decimal case 1'

input='a@@@1@@@-2@@@3@@@4@@@-0.0416667@@@6@@@-24@@@-6
b@@@0@@@-3@@@4@@@1@@@0@@@2@@@0@@@-2
c@@@3@@@6@@@2.5@@@4@@@0.05@@@15.5@@@180@@@-15.5
-@@@-4@@@-1@@@-9.5@@@-9@@@-0.0083333@@@-23.5@@@-156@@@23.5
/@@@0@@@1@@@4.8@@@1@@@0@@@0.774194@@@0@@@-0.774194
*@@@0@@@36@@@30@@@16@@@0@@@186@@@0@@@-186
+@@@4@@@1@@@9.5@@@9@@@0.0083333@@@23.5@@@156@@@-23.5'
expected='a   1  -2   3.0   4   -0.0417    6.0000   -24    -6.0000
b   0  -3   4.0   1    0.0000    2.0000     0    -2.0000
c   3   6   2.5   4    0.0500   15.5000   180   -15.5000
-  -4  -1  -9.5  -9   -0.0083  -23.5000  -156    23.5000
/   0   1   4.8   1    0.0000    0.7742     0    -0.7742
*   0  36  30.0  16    0.0000  186.0000     0  -186.0000
+   4   1   9.5   9    0.0083   23.5000   156   -23.5000'
actual="$(echo -e "$input" | ds:fit -v color=never -v no_zero_blank=1 | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed negative decimal case 2'

expected='Ints     2020    2021   2022  2023.000000       2024  2025.000000  2026.000000  2027.000000  2028.000000  2029.000000  2030.00000  2031.00000  2032.000000
Nums       70      71    -72    73.000000        -74    75.000000    76.000000    77.000000    78.000000    79.000000    80.00000    81.00000    82.000000
Floats  10550  -11130  11742    -0.000124  -13069600     0.000001    -0.000145     0.000153     0.000162     0.000171     0.00018     0.00019     0.000201'
actual="$(ds:fit $floats -v color=never -v no_zero_blank=1 | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed float ingestion case'

ps aux | ds:fit -F'[[:space:]]+' -v color=never -v endfit_col=10 | awk '{print length($0)}' > $tmp
tty_width="$(tput cols)"
for fit_length in $(cat $tmp); do
    [ "$fit_length" -lt "$tty_width" ] || ds:fail 'fit failed endfit_col case'
done

expected='Spetnixvbi lej Bkapf Giawgg             2166631  114957
Vgrrhfhb ul Wkuu                           7563       0
Ivfubovmpm Svvsud                         82809   75629
Brjtlras Tvgqicmq (xrmbi)                     0       0
Kox-spetnixv Bilejbka (pfgia)                 0       0
Xggvgrr Hfhbulv Luuiv                         0       0
Fubovmp Nsvvsu & Dbrjtlrassv             190142       0
Gqicmqx Smbiko                           163178       0
YXJ                                       26964       0
Vuspe Unixvbil Ejbkap Fgiawg                  0       0
HVGS Shfhbulvkuuiv                            0       0
Fubovmp Nsvvsud Brjtlras Tvgqicmqxrmbi    16101       0
Kox Xivudrxflj Awcbqvxx                       0     962
Ohbcabs Qetnix                          2431044  189624'
actual="$(ds:fit "$number_comma_format" -v color=never)"
[ "$expected" = "$actual" ] || ds:fail 'fit failed number comma format case'

expected="┌──────────┬───────────┬──────┬───────────┬───────────┬────────────┐
│<NULL>    │          H│     J│         FE│      TOTAL│            │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│SETS      │           │      │           │           │  TIFS      │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│N-R       │           │      │           │           │  N-ré      │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│J i       │          -│     -│   10000.00│   10000.00│  J i       │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T N-R     │          -│     -│   10000.00│   10000.00│  T N-eré   │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│R         │           │      │           │           │  Eré       │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│rkljg     │          -│     -│    2000.00│    2000.00│  rkljg     │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│Test      │    5555.00│     -│          -│    5555.00│  Test      │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T R       │    5555.00│     -│    2000.00│    7555.00│  T Eré     │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│C A       │           │      │           │           │  A d’ent   │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│525 345 44│  250000.00│     -│          -│  250000.00│  525 345 44│
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T C A     │  250000.00│     -│          -│  250000.00│  T A d’e   │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│N-L       │           │      │           │           │  N-l       │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T m h     │          -│     -│  175000.00│  175000.00│  T m h     │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T N-L     │          -│     -│  175000.00│  175000.00│  T N-l     │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T A       │  255555.00│     -│  187000.00│  442555.00│  T d a     │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│L         │           │      │           │           │  P         │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T D       │           │      │           │           │  T d d     │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│wfrw      │   10542.00│     -│          -│   10542.00│  wfrw      │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T M       │          -│     -│  234233.00│  234233.00│  T M       │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│T L       │   10542.00│     -│  234233.00│  244775.00│  T d p     │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│TOTAL     │  245013.00│     -│  -47233.00│  197780.00│  TOTAL     │
├──────────┼───────────┼──────┼───────────┼───────────┼────────────┤
│          │          H│     J│         FY│      TOTAL│  <NULL>    │
└──────────┴───────────┴──────┴───────────┴───────────┴────────────┘"
actual="$(ds:fit "$jnrjn1" -v gridlines=1 -v d=2 -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$expected" = "$actual" ] || ds:fail 'fit failed gridlines decimals multibyte_chars case'

ds:fit $emoji -v gridlines=1 -v color=never > $tmp
cmp $tmp $emoji_fit_gridlines || ds:fail 'fit failed gridlines emoji case'

ds:fit $cmds -v gridlines=1 -v color=never -v tty_size=120 | sed -E 's/[[:space:]]+$//g' > $tmp
cmp $tmp $commands_fit_gridlines || ds:fail 'fit failed gridlines shrink field case'

echo -e "${GREEN}PASS${NC}"

# FC TESTS

echo -n "Running fieldcounts and uniq tests..."

expected='2 mozy,Mozy,26,web,American Fork,UT,1-May-05,1900000,USD,a
2 zoominfo,ZoomInfo,80,web,Waltham,MA,1-Jul-04,7000000,USD,a'
actual="$(ds:fieldcounts $simple_csv a 2)"
[ "$expected" = "$actual" ] || ds:fail 'fieldcounts failed all field case'
expected='54,1-Jan-08
54,1-Oct-07'
actual="$(ds:fieldcounts $simple_csv 7 50)"
[ "$expected" = "$actual" ] || ds:fail 'fieldcounts failed single field case'
expected='7,450,Palo Alto,facebook'
actual="$(ds:fieldcounts $simple_csv 3,5,1 6)"
[ "$expected" = "$actual" ] || ds:fail 'fieldcounts failed multifield case'

input='a\nb\nc\n1\ne\nc\nb\na\ni\nc\n55\n3'
expected='a
b
c
e
i
1
3
55'
[ "$(echo -e "$input" | ds:uniq)" = "$expected" ] || ds:fail 'uniq failed defaults case'

expected='a
b
c'
[ "$(echo -e "$input" | ds:uniq 0 2)" = "$expected" ] || ds:fail 'uniq failed min 2 case'

expected='c'
[ "$(echo -e "$input" | ds:uniq 1 3)" = "$expected" ] || ds:fail 'uniq failed min 3 case'

expected='55
3
1
i
e
c
b
a'
[ "$(echo -e "$input" | ds:uniq 1 1 d)" = "$expected" ] || ds:fail 'uniq failed descending case'

echo -e "${GREEN}PASS${NC}"

# NEWFS TESTS

echo -n "Running newfs tests..."

expected='Joan "the bone", Anne::Jet::9th, at Terrace plc::Desert City::CO::00123'
actual="$(ds:newfs $complex_csv1 :: | grep -h Joan)"
[ "$expected" = "$actual" ] || ds:fail 'newfs command failed'

echo -e "${GREEN}PASS${NC}"

# SUBSEP TESTS

echo -n "Running subsep tests..."

actual="$(ds:subsep tests/data/subseps_test "SEP" | ds:reo 1,7 | cat)"
expected='A;A;A;A
G;G;G;G'
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed'
expected='cdatetime,,,address
1,1,06 0:00,3108 OCCIDENTAL DR
1,1,06 0:00,2082 EXPEDITION WAY
1,1,06 0:00,4 PALEN CT
1,1,06 0:00,22 BECKFORD CT'
actual="$(ds:reo tests/data/testcrimedata.csv 1..5 1,2 | ds:subsep '/' "" -F,)"
[ "$expected" = "$actual" ] || ds:fail 'sbsp failed readme case'

echo -e "${GREEN}PASS${NC}"

# POW TESTS

echo -n "Running power tests..."

expected="23,ACK,0
24,Mark,0
25,ACK
27,ACER PRESS,0
28,ACER PRESS
28,Mark
74,0"
actual="$(ds:pow $complex_csv2 20 | cat)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed base case'

expected="0.22,3,5
0.26,3
0.5,4,5
0.53,4
0.74,5"
actual="$(ds:pow $complex_csv2 20 t | cat)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed combin counts case'

expected='1 a b
1 e a
1 e d
1 q b
1 q d
2 a d
2 b d'
actual="$(echo -e "a b d\ne a d\nq b d" | ds:pow 1 f f -v choose=2)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 2 3-base case'


expected='1 a b
1 a c
1 b c
1 c d
1 e a
1 e b
1 e d
1 q a
1 q b
1 q d
2 b a
3 a d
3 b d'
actual="$(echo -e "a b c d\ne b a d\nq b a d" | ds:pow 1 f f -v choose=2)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 2 4-base case'

expected='1 1 2
1 1 3
1 1 4
1 1 5
1 1 6
1 1 7
1 2 3
1 2 4
1 2 5
1 2 6
1 2 7
1 3 4
1 3 5
1 3 6
1 3 7
1 4 5
1 4 6
1 4 7
1 5 6
1 5 7
1 6 7'
actual="$(echo 1 2 3 4 5 6 7 | ds:pow 1 f f -v choose=2 | sort -n)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 2 7-base case'

expected='1 a b d c
1 a d b c
2 a b c d
3 a b d
4 a b c
4 a d'
actual="$(echo -e "a b c d\na b c d\na b d c\na d b c" | ds:pow)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed combinations discrimination case'

expected='1 a b c
1 a b d
1 a c d
1 b c d'
actual="$(echo "a b c d" | ds:pow 1 f f -v choose=3)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 3 4-base case'

expected='1 a b c
1 a b d
1 a b e
1 a c d
1 a c e
1 a d e
1 b c d
1 b c e
1 b d e
1 c d e'
actual="$(echo "a b c d e" | ds:pow 1 f f -v choose=3)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 3 5-base case'

expected='1 a b c
1 a b d
1 a b e
1 a b f
1 a c d
1 a c e
1 a c f
1 a d e
1 a d f
1 a e f
1 b c d
1 b c e
1 b c f
1 b d e
1 b d f
1 b e f
1 c d e
1 c d f
1 c e f
1 d e f'
actual="$(echo "a b c d e f" | ds:pow 1 f f -v choose=3)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 3 6-base case'

expected='1 a b c d
1 a b c e
1 a b c f
1 a b d e
1 a b d f
1 a b e f
1 a c d e
1 a c d f
1 a c e f
1 a d e f
1 b c d e
1 b c d f
1 b c e f
1 b d e f
1 c d e f'
actual="$(echo -e "a b c d e f" | ds:pow 1 f f -v choose=4)"
[ "$expected" = "$actual" ] || ds:fail 'pow failed choose 4 6-base case'

echo -e "${GREEN}PASS${NC}"

# FIELD_REPLACE TESTS

echo -n "Running field replace tests..."

input='1:2:3:4:
4:3:2:5:6
::::
4:6:2:4'
expected='11:2:3:4:
-1:3:2:5:6
11::::
-1:6:2:4'
actual="$(echo "$input" | ds:field_replace 'val > 2 ? -1 : 11')"
[ "$expected" = "$actual" ] || ds:fail 'field_replace failed only replacement_func case'

expected='1:11:3:4:
4:-1:2:5:6
::::
4:-1:2:4'
actual="$(echo "$input" | ds:field_replace 'val > 2 ? -1 : 11' 2 '[0-9]')"
[ "$expected" = "$actual" ] || ds:fail 'field_replace failed all args case'

echo -e "${GREEN}PASS${NC}"

# PIVOT TESTS

echo -n "Running pivot tests..."

input='1 2 3 4
5 6 7 5
4 6 5 8'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@1@@@@@@@@@
6@@@@@@1@@@1@@@'
actual="$(echo "$input" | ds:pivot 2 1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed count z case'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@3::4@@@@@@@@@
6@@@@@@5::8@@@7::5@@@'
actual="$(echo "$input" | ds:pivot 2 1 0)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen z case'

expected='PIVOT@@@1@@@4@@@5@@@
2@@@3@@@@@@@@@
6@@@@@@5@@@7@@@'
actual="$(echo "$input" | ds:pivot 2 1 3)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed spec z case'

expected='2 \ 4@@@5@@@8@@@
6@@@1@@@1@@@'
actual="$(echo "$input" | ds:pivot 2 4 -v header=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed basic header case'

expected='PIVOT@@@@@@4@@@d@@@
1@@@2@@@3@@@@@@
a@@@b@@@@@@c@@@'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot 1,2 4 3)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed readme multi-y case'

expected='Fields not found for both x and y dimensions with given key params'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot 1,2 4 3 -v gen_keys=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed basic header case no number matching'

expected='1::2 \ 4@@@@@@d@@@
a@@@b@@@c@@@'
actual="$(echo -e "1 2 3 4\na b c d" | ds:pivot 1,2 4 3 -v gen_keys=1)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys case number matching'

expected='a::b \ d@@@@@@4@@@
1@@@2@@@3@@@'
actual="$(echo -e "a b c d\n1 2 3 4" | ds:pivot a,b d c)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys case'

input='halo wing top wind
1 2 3 4
5 6 7 5
4 6 5 8'
expected='Fields not found for both x and y dimensions with given key params'
actual="$(echo "$input" | ds:pivot halo twef)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys negative case'

expected='halo \ wing@@@2@@@6@@@
1@@@1@@@@@@
4@@@@@@1@@@
5@@@@@@1@@@'
actual="$(echo "$input" | ds:pivot halo win)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys two matching case'

expected='halo \ wing::wind@@@2::4@@@6::5@@@6::8@@@
1@@@1@@@@@@@@@
4@@@@@@@@@1@@@
5@@@@@@1@@@@@@'
actual="$(echo "$input" | ds:pivot halo win,win)"
[ "$actual" = "$expected" ] || ds:fail 'pivot failed gen header keys double same-pattern case'

echo -e "${GREEN}PASS${NC}"


# AGG TESTS

echo -n "Running aggregation tests..."

echo -e "one two three four\n1 2 3 4\n4 3 2 1\n1 2 4 3\n3 2 4 1" > $tmp

expected='one two three four $3+$2
1 2 3 4 5
4 3 2 1 5
1 2 4 3 6
3 2 4 1 6'
[ "$(ds:agg $tmp '$3+$2')" = "$expected" ] || ds:fail 'agg failed R specific agg base case'

expected='one two three four
1 2 3 4
4 3 2 1
1 2 4 3
3 2 4 1
-3 -1 1 3'
[ "$(ds:agg $tmp 0 '$2-$3')" = "$expected" ] || ds:fail 'agg failed C specific agg base case'

expected='one two three four
1 2 3 4
4 3 2 1
1 2 4 3
3 2 4 1
6 7 9 8'
[ "$(ds:agg $tmp 0 '$2+$3+$4')" = "$expected" ] || ds:fail 'agg failed C specific agg base case'

expected='one,two,three,four,*|2..4
1,2,3,4,24
4,3,2,1,6
1,2,4,3,24
3,2,4,1,8'
actual="$(echo -e "one,two,three,four\n1,2,3,4\n4,3,2,1\n1,2,4,3\n3,2,4,1" | ds:agg '*|2..4')"
[ "$actual" = "$expected" ]        || ds:fail 'agg failed R specific range agg base case'

expected='one,two,three,four,mean|2..4
1,2,3,4,3
4,3,2,1,2
1,2,4,3,3
3,2,4,1,2.33333'
actual="$(echo -e "one,two,three,four\n1,2,3,4\n4,3,2,1\n1,2,4,3\n3,2,4,1" | ds:agg 'mean|2..4')"
[ "$actual" = "$expected" ]        || ds:fail 'agg failed R specific range agg means case'

expected='one,two,three,four
1,2,3,4
4,3,2,1
1,2,4,3
3,2,4,1
-5,-5,-6,-4'
actual="$(echo -e "one,two,three,four\n1,2,3,4\n4,3,2,1\n1,2,4,3\n3,2,4,1" | ds:agg 0 '-|3..4')"
[ "$actual" = "$expected" ]        || ds:fail 'agg failed C specific range agg base case'

expected='one,two,three,four
1,2,3,4
4,3,2,1
1,2,4,3
3,2,4,1
2.66667,2.33333,3.33333,1.66667'
actual="$(echo -e "one,two,three,four\n1,2,3,4\n4,3,2,1\n1,2,4,3\n3,2,4,1" | ds:agg 0 'mean|3..5')"
[ "$actual" = "$expected" ]        || ds:fail 'agg failed C specific range agg means case'

expected='one:two:three:four:+|all
1:2:3:4:10
4:3:2:1:10
1:2:4:3:10
3:2:4:1:10'
actual="$(echo -e "one:two:three:four\n1:2:3:4\n4:3:2:1\n1:2:4:3\n3:2:4:1" | ds:agg '+|all')"
[ "$actual" = "$expected" ]        || ds:fail 'agg failed R all agg base case'

expected='one:two:three:four:mean|all
1:2:3:4:2.5
4:3:2:1:2.5
1:2:4:3:2.5
3:2:4:1:2.5'
actual="$(echo -e "one:two:three:four\n1:2:3:4\n4:3:2:1\n1:2:4:3\n3:2:4:1" | ds:agg 'mean|all')"
[ "$actual" = "$expected" ]        || ds:fail 'agg failed R all agg mean case'

expected='one;two;three;four
1;2;3;4
4;3;2;1
1;2;4;3
3;2;4;1
9;9;13;9'
actual="$(echo -e "one;two;three;four\n1;2;3;4\n4;3;2;1\n1;2;4;3\n3;2;4;1" | ds:agg 0 '+|all')"
[ "$actual" = "$expected" ]        || ds:fail 'agg failed C all agg base case'

expected='one two three four +|all
1 2 3 4 10
4 3 2 1 10
1 2 4 3 10
3 2 4 1 10
9 9 13 9 40'
[ "$(ds:agg $tmp)" = "$expected" ] || ds:fail 'agg failed R+C all agg base case'
expected=' one two three four +|all
 1 2 3 4 10
 4 3 2 1 10
 1 2 4 3 10
 3 2 4 1 10
+|all 9 9 13 9 40'
[ "$(ds:agg $tmp '+|all' '+|all' -v header=1)" = "$expected" ] || ds:fail 'agg failed R+C all agg header case'

expected=' one two three four +|all *|2..4 /|all
 1 2 3 4 10 24 0.0416667
 4 3 2 1 10 6 0.666667
 1 2 4 3 10 24 0.0416667
 3 2 4 1 10 8 0.375
$2/$3 0.25 0.666667 1.5 4 1 4 0.0625
+|all 9 9 13 9 40 62 1.125'
[ "$(ds:agg $tmp '+|all,*|2..4,/|all' '$2/$3,+|all' -v header=1)" = "$expected" ] || ds:fail 'agg failed C+R multiple aggs header case'

echo -e "a 1 -2 3 4\nb 0 -3 4 1\nc 3 6 2.5 4" > $tmp
expected='a 1 -2 3 4 6
b 0 -3 4 1 2
c 3 6 2.5 4 15.5
+|all 4 1 9.5 9 23.5'
[ "$(ds:agg $tmp)" = "$expected" ]                                || ds:fail 'agg failed readme case'
expected='a 1 -2 3 4 -24 -6
b 0 -3 4 1 0 -12
c 3 6 2.5 4 180 15
+|all 4 1 9.5 9 156 -3
*|all 0 36 30 16 0 1080'
[ "$(ds:agg $tmp '*|all,$4*$3' '+|all,*|all')" = "$expected" ]    || ds:fail 'agg failed readme negatives multiples case'
expected='a 1 -2 3 4 -24 -6 ~b
b 0 -3 4 1 0 -12 1
c 3 6 2.5 4 180 15 0
+|all 4 1 9.5 9 156 -3 1
*|all 0 36 30 16 0 1080 0'
[ "$(ds:agg $tmp '*|all,$4*$3,~b' '+|all,*|all')" = "$expected" ] || ds:fail 'agg failed readme kitchen sink case'

echo -e "one two three four\nakk 2 3 4\nblah 3 2 1\nyuge 2 4 3\ngoal 2 4 1" > $tmp
expected='one two three four / + * -
akk 2 3 4 0.166667 9 24 -9
blah 3 2 1 1.5 6 6 -6
yuge 2 4 3 0.166667 9 24 -9
goal 2 4 1 0.5 7 8 -7
- -9 -13 -9 -2.33334 -31 -62 31
/ 0.166667 0.09375 1.33333 1.33333 0.0238096 0.0208334 0.0238096
* 24 96 12 0.0208334 3402 27648 3402
+ 9 13 9 2.33334 31 62 -31'
[ "$(ds:agg $tmp '/,+,*,-' '\-,/,*,+')" = "$expected" ]           || ds:fail 'agg failed all shortforms case'

expected='Spetnixvbi lej Bkapf Giawgg  $2,166,631  $114,957  $2281588
Vgrrhfhb ul Wkuu  $7,563  $0  $7563
Ivfubovmpm Svvsud  $82,809  $75,629  $158438
Brjtlras Tvgqicmq (xrmbi)  $0  $0  $0
Kox-spetnixv Bilejbka (pfgia)  $0  $0  $0
Xggvgrr Hfhbulv Luuiv  $0  $0  $0
Fubovmp Nsvvsu & Dbrjtlrassv  $190,142  $0  $190142
Gqicmqx Smbiko  $163,178  $0  $163178
YXJ  $26,964  $0  $26964
Vuspe Unixvbil Ejbkap Fgiawg  $0  $0  $0
HVGS Shfhbulvkuuiv  $0  $0  $0
Fubovmp Nsvvsud Brjtlras Tvgqicmqxrmbi  $16,101  $0  $16101
Kox Xivudrxflj Awcbqvxx  $0  $962  $962
Ohbcabs Qetnix  $2,431,044  $189,624  $2620668
$1+$2+$3+$4+$5+$6+$7+$10-$11-$12-$13  $2431044  $189624  $2620668'
[ "$(ds:agg $number_comma_format '+' '$1+$2+$3+$4+$5+$6+$7+$10-$11-$12-$13')" = "$expected" ] || ds:fail 'agg failed number comma format case'

expected='one two three four three+two -
akk 2 3 4 5 -9
blah 3 2 1 5 -6
yuge 2 4 3 6 -9
goal 2 4 1 6 -7
akk-goal 0 -1 3 -1 -2
blah/yuge 1.5 0.5 0.333333 0.833333 0.666667'
[ "$(ds:agg $tmp 'three+two,-' 'akk-goal,blah/yuge')" = "$expected" ] || ds:fail 'agg failed keysearch cases'

echo -e "a 2 3 4\nb 3 4 5\na 4 5 2\nc 7 7 7" > $tmp
expected='a 2 3 4
b 3 4 5
a 4 5 2
c 7 7 7
+|~a 6 8 6
+ 16 19 18'
[ "$(ds:agg $tmp 0 '+|~a,+')" = "$expected" ] || ds:fail 'agg failed conditional C agg case'
expected='a 2 3 4
b 3 4 5
a 4 5 2
c 7 7 7
mean|~a 3 4 3
+ 16 19 18'
[ "$(ds:agg $tmp 0 'mean|~a,+')" = "$expected" ] || ds:fail 'agg failed conditional C agg mean case'

echo -e "one:two:three:four\n1:2:3:4\n4:3:2:1\n1:2:4:3\n3:2:4:1" > $tmp
expected='one:two:three:four:+|$4>3||$4<2
1:2:3:4:4
4:3:2:1:6
1:2:4:3:5
3:2:4:1:7'
[ "$(ds:agg $tmp '+|$4>3||$4<2')" = "$expected" ] || ds:fail 'agg failed conditional R agg case'
expected='one:two:three:four:mean|$4>3||$4<2
1:2:3:4:2
4:3:2:1:3
1:2:4:3:2.5
3:2:4:1:3.5'
[ "$(ds:agg $tmp 'mean|$4>3||$4<2')" = "$expected" ] || ds:fail 'agg failed conditional R agg mean case'

expected='USER +
user 2059788916
root 557934576
_driverkit 57665820
_spotlight 13249992
_fpsd 13221780
_gamecontrollerd 4395696
_ctkd 4387972
_applepay 13206848
_datadetectors 4388328
_assetcache 8857156
_nsurlstoraged 4357112
_locationd 26462608
_windowserver 18898844
_netbios 4397460
_appleevents 4425400
_captiveagent 4397764
_coreaudiod 13179300
_atsserver 4426392
_softwareupdate 8938436
_cmiodalassistants 4459716
_nsurlsessiond 4436820
_networkd 4436988
_mdnsresponder 4426516
_analyticsd 4431416
_distnote 4396688
_hidd 4428040
_displaypolicyd 4398396
_usbmuxd 4423984
_timed 4423572
_iconservices 4397076'
actual="$(ds:agg tests/data/ps_aux 0 5 | ds:decap 1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'agg failed cross agg simple field case'

ds:transpose tests/data/ps_aux > $tmp
actual="$(ds:agg $tmp 5 | ds:decap 1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'agg failed cross agg simple row case'

expected='USER::STARTED +
user::4:56PM 66904232
user::4:29PM 17910632
root::Thu11PM 479285720
user::11:22PM 51518368
user::Thu11PM 835332556
user::1:04PM 8958804
user::12:56PM 8963396
root::12:49PM 4431616
user::12:09PM 4365536
user::11:27AM 4357336
root::11:27AM 4345892
_driverkit::11:26AM 28829064
root::4:47AM 4295916
user::2:47AM 4458792
user::1:46AM 8658308
root::1:46AM 4345892
user::1:30AM 94777988
user::12:52AM 4372696
root::12:52AM 4362276
user::11:26PM 4658916
user::11:25PM 4823592
user::11:24PM 13622944
user::11:23PM 14674620
root::11:22PM 4322148
root::10:31PM 4382212
root::8:34PM 4423564
user::6:17PM 4985040
root::6:17PM 4530472
user::6:15PM 9975064
root::6:15PM 4341920
user::6:14PM 4867292
user::5:54PM 4884860
user::5:20PM 4430752
user::5:01PM 9026804
user::4:30PM 76183564
user::Fri01PM 142261376
user::Fri12PM 8898132
user::Fri11AM 32800340
root::Fri11AM 4314416
user::Fri10AM 17531488
user::Fri09AM 4985392
user::Fri01AM 134776268
user::Fri12AM 203251976
root::Fri12AM 21920112
_spotlight::Fri12AM 4425740
_fpsd::Fri12AM 4398440
_spotlight::Thu11PM 8824252
_gamecontrollerd::Thu11PM 4395696
_ctkd::Thu11PM 4387972
_applepay::Thu11PM 13206848
_datadetectors::Thu11PM 4388328
_fpsd::Thu11PM 8823340
_assetcache::Thu11PM 8857156
_nsurlstoraged::Thu11PM 4357112
_locationd::Thu11PM 26462608
_windowserver::Thu11PM 18898844
_netbios::Thu11PM 4397460
_appleevents::Thu11PM 4425400
_captiveagent::Thu11PM 4397764
_driverkit::Thu11PM 28836756
_coreaudiod::Thu11PM 13179300
_atsserver::Thu11PM 4426392
_softwareupdate::Thu11PM 8938436
_cmiodalassistants::Thu11PM 4459716
_nsurlsessiond::Thu11PM 4436820
_networkd::Thu11PM 4436988
_mdnsresponder::Thu11PM 4426516
_analyticsd::Thu11PM 4431416
_distnote::Thu11PM 4396688
_hidd::Thu11PM 4428040
_displaypolicyd::Thu11PM 4398396
_usbmuxd::Thu11PM 4423984
_timed::Thu11PM 4423572
_iconservices::Thu11PM 4397076
user::3:10PM 12939632
root::3:10PM 4299084
user::3:08PM 4358940
root::3:08PM 4333336
user::2:58PM 4308104
user::1:40PM 8919832
user::1:33PM 222045344'
actual="$(ds:agg tests/data/ps_aux 0 '+|5|1..2' | ds:decap 1 | sed -E 's/[[:space:]]+$//g' | awk '{gsub("\034","");print}')"
[ "$actual" = "$expected" ] || ds:fail 'agg failed cross agg range field case'
actual="$(ds:agg $tmp '+|5|1..2' | ds:decap 1 | sed -E 's/[[:space:]]+$//g' | awk '{gsub("\034","");print}')"
[ "$actual" = "$expected" ] || ds:fail 'agg failed cross agg range row case'

expected='USER::STARTED mean()
user::4:56PM 9.55775e+06
user::4:29PM 17910632
root::Thu11PM 4.43783e+06
user::11:22PM 5.15184e+06
user::Thu11PM 4.74621e+06
user::1:04PM 8958804
user::12:56PM 8963396
root::12:49PM 4431616
user::12:09PM 4365536
user::11:27AM 4357336
root::11:27AM 4345892
_driverkit::11:26AM 4804844
root::4:47AM 4295916
user::2:47AM 4458792
user::1:46AM 4329154
root::1:46AM 4345892
user::1:30AM 47388994
user::12:52AM 4372696
root::12:52AM 4362276
user::11:26PM 4658916
user::11:25PM 4823592
user::11:24PM 4.54098e+06
user::11:23PM 4891540
root::11:22PM 4322148
root::10:31PM 4382212
root::8:34PM 4423564
user::6:17PM 4985040
root::6:17PM 4530472
user::6:15PM 4987532
root::6:15PM 4341920
user::6:14PM 4867292
user::5:54PM 4884860
user::5:20PM 4430752
user::5:01PM 9026804
user::4:30PM 8.46484e+06
user::Fri01PM 1.18551e+07
user::Fri12PM 4449066
user::Fri11AM 4.68576e+06
root::Fri11AM 4314416
user::Fri10AM 4382872
user::Fri09AM 4985392
user::Fri01AM 1.92538e+07
user::Fri12AM 7.81738e+06
root::Fri12AM 4.38402e+06
_spotlight::Fri12AM 4425740
_fpsd::Fri12AM 4398440
_spotlight::Thu11PM 4412126
_gamecontrollerd::Thu11PM 4395696
_ctkd::Thu11PM 4387972
_applepay::Thu11PM 4.40228e+06
_datadetectors::Thu11PM 4388328
_fpsd::Thu11PM 4411670
_assetcache::Thu11PM 4428578
_nsurlstoraged::Thu11PM 4357112
_locationd::Thu11PM 4.41043e+06
_windowserver::Thu11PM 6.29961e+06
_netbios::Thu11PM 4397460
_appleevents::Thu11PM 4425400
_captiveagent::Thu11PM 4397764
_driverkit::Thu11PM 4806126
_coreaudiod::Thu11PM 4393100
_atsserver::Thu11PM 4426392
_softwareupdate::Thu11PM 4469218
_cmiodalassistants::Thu11PM 4459716
_nsurlsessiond::Thu11PM 4436820
_networkd::Thu11PM 4436988
_mdnsresponder::Thu11PM 4426516
_analyticsd::Thu11PM 4431416
_distnote::Thu11PM 4396688
_hidd::Thu11PM 4428040
_displaypolicyd::Thu11PM 4398396
_usbmuxd::Thu11PM 4423984
_timed::Thu11PM 4423572
_iconservices::Thu11PM 4397076
user::3:10PM 4.31321e+06
root::3:10PM 4299084
user::3:08PM 4358940
root::3:08PM 4333336
user::2:58PM 4308104
user::1:40PM 8919832
user::1:33PM 55511336'
actual="$(ds:agg tests/data/ps_aux 0 'mean|5|1..2' | ds:decap 1 | sed -E 's/[[:space:]]+$//g' | awk '{gsub("\034","");print}')"
[ "$actual" = "$expected" ] || ds:fail 'agg failed cross agg range field mean case'
actual="$(ds:agg $tmp 'mean|5|1..2' | ds:decap 1 | sed -E 's/[[:space:]]+$//g' | awk '{gsub("\034","");print}')"
[ "$actual" = "$expected" ] || ds:fail 'agg failed cross agg range row mean case'

echo -e "${GREEN}PASS${NC}"


# DIFF_FIELDS TESTS

echo -n "Running diff fields tests..."

echo -e 'a 1 2 3 4\nb 3 4 2 1\nc 22 # , 2' > /tmp/ds_difffields_tests1
echo -e 'a 1 5 60 5\nb 3 7 2 7\nc 22 # , 2' > /tmp/ds_difffields_tests2
echo -e 'a 1 2 3 4\nb 3 4 2 1\nc 3 # , 2' > /tmp/ds_difffields_tests3

expected=' 0 -3 -57 -1
 0 -3 0 -6
 0   0'
actual="$(ds:diff_fields /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed base case'

expected='a 0 1.5 19 0.25
b 0 0.75 0 6
c 0   0



ROW FIELD /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 DIFF
a 4 3 60 19
b 5 1 7 6
a 3 2 5 1.5
b 3 4 7 0.75
a 5 4 5 0.25'
actual="$(ds:diff_fields /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 % 1 -v diff_list=1)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed percent diff list case'

expected='ROW FIELD /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 DIFF
a 5 4 5 0.8
b 3 4 7 0.571429
a 3 2 5 0.4
b 5 1 7 0.142857
a 4 3 60 0.05'
actual="$(ds:diff_fields /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 / 1 -v diff_list=only)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed divide diff list only case'

expected='a 1 5 60 5
 0 0.75 0 6
 0   0



ROW FIELD /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 DIFF
2 5 1 7 6
2 3 4 7 0.75'
actual="$(ds:diff_fields /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 % -v header=1 -v diff_list=1)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed percent diff list header case'

expected='a 1 5 60 5
b 9 7 4 7
c 484 #  4'
actual="$(ds:diff_fields /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 '*' 1,3 -v header=1)"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed multiply fields header case'

expected='a 1 0.2 0.0166667 0.2
b 0.333333 0.142857 0.5 0.142857
c 0.333333 1 ,



ROW FIELD LEFTDATA /tmp/ds_difffields_tests3 DIFF
a 4 0.05 3 0.0166667
b 3 0.571429 4 0.142857
b 5 0.142857 1 0.142857
a 3 0.4 2 0.2
a 5 0.8 4 0.2
c 2 1 3 0.333333
b 2 1 3 0.333333
b 4 1 2 0.5'
actual="$(ds:diff_fields /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 \
        /tmp/ds_difffields_tests3 / 1 -v diff_list=1 -v diff_list_sort=a \
        -v deterministic=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'diff_fields failed multiple file diff list case'

rm /tmp/ds_difffields_tests1 /tmp/ds_difffields_tests2 /tmp/ds_difffields_tests3

echo -e "${GREEN}PASS${NC}"


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

# SHAPE TESTS

echo -n "Running shape tests..."

expected='       lines: 7585
       lines with "AUBURN": 75
       occurrence: 76
       average: 0.0100198
       approx var: 3.96002
lineno distribution of "AUBURN"
   758 +++++++++++
  1516 +++++++
  2274 ++++++
  3032 +++++++
  3790 ++++++
  4548 ++++++++
  5306 ++++++++
  6064 +++++++++
  6822 ++++++++
  7580 ++++++
  8338'
[ "$(ds:shape "$simple_csv2" AUBURN 0 10 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'shape command failed'
[ "$(ds:shape "$simple_csv2" AUBURN wfwe 10 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'shape command failed'

expected='       lines: 7585
       stats from field: $6
       lines with "AUTO": 237                                   lines with "INDECE": 2                                   lines with "PUBLI": 31                                   lines with "BURGL": 986
       occurrence: 237                                          occurrence: 2                                            occurrence: 31                                           occurrence: 986
       average: 0.0312459                                       average: 0.000263678                                     average: 0.00408701                                      average: 0.129993
       approx var: 0.938485                                     approx var: 0.999473                                     approx var: 0.991843                                     approx var: 0.756911
lineno distribution of "AUTO"                                   distribution of "INDECE"                                 distribution of "PUBLI"                                  distribution of "BURGL"
   252 +++                                                                                                               ++++                                                     +++++++++++++++++++++++++++++++++
   504 ++++++++++++++++                                         +                                                        ++                                                       +++++++++++++++++++++++++++++++++++++
   756 +++++++++++++                                                                                                     +                                                        +++++++++++++++++++++++++++++++++++++++++++++++
  1008 +++++                                                                                                                                                                      ++++++++++++++++++++
  1260 +++++                                                                                                             +                                                        ++++++++++++++++++++++++++++++++++++++++
  1512 ++++                                                                                                              ++++                                                     ++++++++++++++++++++++++++++++++++++
  1764 ++++++++                                                                                                                                                                   +++++++++++++++++++++++++++++++++++++++++++++++++
  2016 +++++                                                                                                                                                                      ++++++++++++++++++++++++++++++
  2268 ++++++++++                                                                                                                                                                 ++++++++++++++++++++++++++++++++++
  2520 ++++++                                                                                                                                                                     +++++++++++++++++++++++++++++++++++++
  2772 ++++++                                                                                                            +                                                        ++++++++++++++++++++++++++++++++++++
  3024 +++++++                                                                                                           +                                                        +++++++++++++++++++++++++++++++++++
  3276 ++                                                                                                                +                                                        ++++++++++++++++++++++++++++++++++++
  3528 ++++                                                                                                                                                                       ++++++++++++++++++++++++++++++
  3780 ++++++++                                                                                                                                                                   +++++++++++++++++++++++
  4032 +++++++++                                                                                                                                                                  ++++++++++++++++++++++++++++++
  4284 ++++++++++++++++                                                                                                                                                           ++++++++++++++++++++++++++++++++
  4536 ++++++                                                                                                            ++                                                       +++++++++++++++++++++++++++++
  4788 +++++++++                                                                                                                                                                  +++++++++++++++++++++++++++++++++++++++
  5040 +++++                                                                                                             +++                                                      +++++++++++++++++++++++++++++++++++++++++
  5292 +++++                                                                                                                                                                      ++++++++++++++++++++++++++++++
  5544 +++++++++++++++                                                                                                   +++                                                      ++++++++++++++++++++++++++++
  5796 ++++++++++                                                                                                                                                                 +++++++++++++++++++++++
  6048 +++++++++                                                                                                         +                                                        +++++++++++++++++++++++++++++++++
  6300 +++++++++                                                                                                                                                                  ++++++++++++++++++++++++++++++++++
  6552 +++++++++++                                                                                                       ++                                                       ++++++++++++++++++++++++++++++++
  6804 ++++++                                                                                                            +                                                        ++++++++++++++++++++++++++++++++
  7056 +                                                        +                                                                                                                 ++++++++++++++++++++++++++++++++
  7308 ++++++++++++++                                                                                                    +++                                                      +++++++++++++++++
  7560 ++++++++++                                                                                                        +                                                        ++++++++++++++++++++++++++++
  7812'
actual="$(ds:shape "$simple_csv2" 'AUTO,INDECE,PUBLI,BURGL' 6 30 -v tty_size=238 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command failed'

echo -e "${GREEN}PASS${NC}"

# ASSORTED COMMANDS TESTS

echo -n "Running assorted commands tests..."

[ "$(echo 1 2 3 | ds:join_by ', ')" = "1, 2, 3" ] || ds:fail 'join_by failed on pipe case'
[ "$(ds:join_by ', ' 1 2 3)" = "1, 2, 3" ]        || ds:fail 'join_by failed on pipe case'

[ "$(ds:embrace 'test')" = '{test}' ]             || ds:fail 'embrace failed'

path_el_arr=( tests/data/ infer_join_fields_test1 '.csv' )
[ -z $bsh ] && let count=1 || let count=0
for el in $(IFS='\t' ds:path_elements $jnf1); do
    test_el=${path_el_arr[count]}
    [ $el = $test_el ] || ds:fail "path_elements failed on $test_el"
    let count+=1
done

actual="$(echo -e "5\n2\n4\n3\n1" | ds:index)"
expected='1 5
2 2
3 4
4 3
5 1'
[ "$actual" = "$expected" ] || ds:fail 'idx failed'

[ "$(ds:filename_str $jnf1 '-1' "" t)" = 'tests/data/infer_join_fields_test1-1.csv' ] \
  || ds:fail 'filename_str command failed'

[ "$(ds:iter "a" 3)" = 'aaa' ] || ds:fail 'iter failed'

[ "$(printf "%s\n" a b c d | ds:rev | tr -d '\n')" = "dcba" ] || ds:fail 'rev failed'

echo > $tmp; for i in $(seq 1 10); do echo test$i >> $tmp; done; ds:sedi $tmp 'test'
[[ ! "$(head -n1 $tmp)" =~ "test" ]] || ds:fail 'sedi command failed'

output="1;2;3;4;5;6;7;8;9;10"
[ "$(cat $tmp | ds:mini)" = "$output" ]                                  || ds:fail 'mini failed'

[ "$(ds:unicode "cats😼😻")" = '\U63\U61\U74\U73\U1F63C\U1F63B' ]        || ds:fail 'unicode command failed base case'
[ "$(echo "cats😼😻" | ds:unicode)" = '\U63\U61\U74\U73\U1F63C\U1F63B' ] || ds:fail 'unicode command failed pipe case'
[ "$(ds:unicode "cats😼😻" hex)" = '%63%61%74%73%F09F98BC%F09F98BB' ]    || ds:fail 'unicode command failed hex case'

expected='tests/commands_tests.sh:## TODO: Git tests'
[ "$(ds:todo tests/commands_tests.sh | head -n1)" = "$expected" ]        || ds:fail 'todo command failed'

[ "$(ds:substr "TEST" "T" "ST")" = "E" ]                                 || ds:fail 'substr failed base case'
[ "$(echo "TEST" | ds:substr "T" "ST")" = "E" ]                          || ds:fail 'substr failed pipe case'
actual="$(ds:substr "1/2/3/4" "[0-9]+\\/[0-9]+\\/[0-9]+\\/")"
[ "$(ds:substr "1/2/3/4" "[0-9]+\\/[0-9]+\\/[0-9]+\\/")" = 4 ]           || ds:fail 'substr failed extended regex case'

if [[ $shell =~ 'zsh' ]]; then
    expected="33 !;34 \";35 #;36 $;37 %;38 &;39 ';40 (;41 );42 *;43 +;44 ,;45 -;46 .;47 /;48 0;49 1;50 2;51 3;52 4;53 5;54 6;55 7;56 8;57 9;58 :;59 ;;60 <;61 =;62 >;63 ?;64 @;65 A;66 B;67 C;68 D;69 E;70 F;71 G;72 H;73 I;74 J;75 K;76 L;77 M;78 N;79 O;80 P;81 Q;82 R;83 S;84 T;85 U;86 V;87 W;88 X;89 Y;90 Z;91 [;92 \;93 ];94 ^;95 _;96 \`;97 a;98 b;99 c;100 d;101 e;102 f;103 g;104 h;105 i;106 j;107 k;108 l;109 m;110 n;111 o;112 p;113 q;114 r;115 s;116 t;117 u;118 v;119 w;120 x;121 y;122 z;123 {;124 |;125 };126 ~;"
    [ "$(ds:ascii 33 126 | awk '{_=_$0";"}END{print _}')" = "$expected" ]    || ds:fail 'ascii failed base case'
    expected="200 È;201 É;202 Ê;203 Ë;204 Ì;205 Í;206 Î;207 Ï;208 Ð;209 Ñ;210 Ò;211 Ó;212 Ô;213 Õ;214 Ö;215 ×;216 Ø;217 Ù;218 Ú;219 Û;220 Ü;221 Ý;222 Þ;223 ß;224 à;225 á;226 â;227 ã;228 ä;229 å;230 æ;231 ç;232 è;233 é;234 ê;235 ë;236 ì;237 í;238 î;239 ï;240 ð;241 ñ;242 ò;243 ó;244 ô;245 õ;246 ö;247 ÷;248 ø;249 ù;250 ú;"
    [ "$(ds:ascii 200 250 | awk '{_=_$0";"}END{print _}')" = "$expected" ]   || ds:fail 'ascii failed accent case'
else
    expected='support/utils.sh'
    [[ "$(ds:fsrc ds:noawkfs | head -n1)" =~ "$expected" ]]                || ds:fail 'fsrc failed'
fi

help_deps='ds:sortm
ds:agg
ds:diff_fields
ds:fail
ds:pow
ds:fit
ds:subsep
ds:reo
ds:nset
ds:pivot
ds:commands
ds:shape
ds:join'
[[ "$(ds:deps ds:help)" = "$help_deps" ]]                                || ds:fail 'deps failed'
[ "$(ds:websel https://www.google.com title)" = Google ]                 || ds:fail 'websel failed or internet is out'

expected='Hist: field 3 (district), cardinality 6
               1-1.5 +
               1.5-2 +
               2-2.5
               2.5-3 +
               3-3.5
               3.5-4 +
               4-4.5
               4.5-5 +
               5-5.5
               5.5-6 +

Hist: field 5 (grid), cardinality 539
           102-257.9 ++++++++
         257.9-413.8 ++++++
         413.8-569.7 ++++++++++++++
         569.7-725.6 +++++++
         725.6-881.5 +++++++++++++++
        881.5-1037.4 ++++++++++++++
       1037.4-1193.3 +++++++++
       1193.3-1349.2 +++++++++++++
       1349.2-1505.1 ++++++++++
         1505.1-1661 ++++++

Hist: field 7 (ucr_ncic_code), cardinality 88
          909-1628.3 +++++++++++
       1628.3-2347.6 ++++++++++++++
       2347.6-3066.9 ++++++++++++++
       3066.9-3786.2 ++++++++++++++
       3786.2-4505.5 +++++
       4505.5-5224.8 ++++++++++++++
       5224.8-5944.1 +++++++++++
       5944.1-6663.4
       6663.4-7382.7 ++
         7382.7-8102 +++

Hist: field 8 (latitude), cardinality 1905
      38.438-38.4626 +++++++
     38.4626-38.4872 +++++++++++++
     38.4872-38.5117 +++++++++++++
     38.5117-38.5363 ++++++++++++++
     38.5363-38.5609 ++++++++++++++
     38.5609-38.5855 ++++++++++++++
     38.5855-38.6101 +++++++++
     38.6101-38.6346 ++++++++++++++
     38.6346-38.6592 +++++++++++
     38.6592-38.6838 ++++++'
[ "$(ds:hist "$simple_csv2" | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'hist command failed'

echo -e "${GREEN}PASS${NC}"


# INTEGRATION TESTS

echo -n "Running integration tests..."

# Integration Case 1 - Sum of all crimes by day of the month, only select a certain day 
# of the week and the total where the total is greater than 300 crimes.

expected='@@@PIVOT@@@7@@@14@@@21@@@28@@@+|all@@@
@@@459 PC  BURGLARY RESIDENCE@@@12@@@10@@@7@@@13@@@356@@@
@@@TOWED/STORED VEHICLE@@@9@@@15@@@8@@@9@@@434@@@
@@@459 PC  BURGLARY VEHICLE@@@23@@@15@@@22@@@15@@@462@@@
@@@TOWED/STORED VEH-14602.6@@@11@@@9@@@8@@@11@@@463@@@
@@@10851(A)VC TAKE VEH W/O OWNER@@@21@@@15@@@24@@@23@@@653@@@
+|all@@@@@@249@@@221@@@234@@@279@@@7585@@@'
actual="$(ds:subsep tests/data/testcrimedata.csv '/' "" -v apply_to_fields=1 \
    | ds:reo a '2,NF>3' \
    | ds:pivot 6 1 4 c \
    | ds:agg '+|all' '+|all' -v header=1 \
    | ds:sortm NF n \
    | ds:reo '2~PIVOT, >300' '1,2[PIVOT%7,2[PIVOT~all' -v uniq=1 | cat)"
[ "$actual" = "$expected" ] || ds:fail 'integration case 1 failed'



# Integration Case 2 - Reorder and fit multibyte chars

expected='emoji  Generating_code_base10  init_awk_len  len_simple_extract  len_remaining
❎     10062                              3                   1              2
🚧     unknown                            4                   1              3
❓     10067                              3                   1              2
❔     10068                              3                   1              2'
actual="$(cat $emoji | ds:reo '1, NR%2 && NR>80 && NR<90' '[emoji,others' | ds:fit -v color=never)"
[ "$actual" = "$expected" ] || ds:fail 'integration readme emoji case failed'



# Integration Case 3 - Mean day of the month for crimes per beat, with full mean,
# those crimes with mean day of the month greater than 17.

expected='243.4(A) SEXUAL BATTERY                     24.0        28.0        17.3
245(A)(2) AWDW/FIREARM/CIVILIA  20.7   6.7  29.0  26.5  18.7  19.0  17.2
451(D) PC  ARSON OF PROPERTY          13.0  27.0  27.0  18.5  25.0  18.4
484 PETTY THEFT-PURSE SNATCH          28.0                    27.0  18.3
603  FORCED ENTRY/PROP DAMAGE         28.0  30.0                    19.3
653K PC POSS/SELL SWITCHBLADE         17.0  26.0        30.0        18.2
1203.2 PC VIOLATION OF PROBATI        18.0  31.0        28.0  12.2  17.8
12316(B)(1)FELON POSSESS AMMO                           30.0  24.0  18.0
23222(B)POSSESS MARIJ IN VEH    30.0  28.0  21.5  21.0  23.7        20.7
CHILD WELFARE - I RPT           16.0  27.0  27.0  23.5  16.8  23.7  19.1
FRAUDULENT DOCUMENTS- I RPT           20.0              30.0  24.0  18.5
HIT AND RUN /SUSPECTS- I RPT    30.0  18.3  21.0        24.0        18.7
POSSIBLE FINANCIAL CRIME-I RPT  19.2  29.0        18.2  22.0        17.7
WANTED SUBJ-O/S WANT/ I RPT                 27.0        31.0        19.3'
actual="$(ds:subsep tests/data/testcrimedata.csv '/' "" -v apply_to_fields=1 \
    | ds:reo a '2,NF>3' \
    | ds:newfs $DS_SEP \
    | ds:pivot 6 3 1 mean -v header=1 \
    | ds:agg mean mean \
    | ds:reo '9>17' \
    | ds:fit -v d=1 -v color=never)"
[ "$actual" = "$expected" ] || ds:fail 'integration case 3 failed'



# Integration Case 4 - Various agregation to fit negative decimals

expected='    one      two     three     four         +         *
 1.0000   2.0000    3.0000   4.0000   10.0000   24.0000
 4.0000   3.0000    2.0000   1.0000   10.0000   24.0000
 1.0000   2.0000    4.0000   3.0000   10.0000   24.0000
 3.0000   2.0000    4.0000   1.0000   10.0000   24.0000
-9.0000  -9.0000  -13.0000  -9.0000  -40.0000  -96.0000
 0.0833   0.1667    0.0938   1.3333    0.0100    0.0017'
actual="$(echo -e "one two three four\n1 2 3 4\n4 3 2 1\n1 2 4 3\n3 2 4 1" | ds:agg '+,*' '\-,/' | ds:fit -v d=4 -v color=never)"
[ "$actual" = "$expected" ] || ds:fail 'integration agg fit negative decimals case 1 failed'


# Integration Case 5 - Various agregation to fit negative decimals

input='a  1  -2  3.0  4
b  0  -3  4.0  1
c  3   6  2.5  4'
expected='a   1  -2   3.0   4    6.0000   -24
b   0  -3   4.0   1    2.0000     0
c   3   6   2.5   4   15.5000   180
-  -4  -1  -9.5  -9  -23.5000  -156
/   0   1   4.8   1    0.7742     0'
actual="$(echo -e "$input" | ds:agg '+,*' '\-,/' | ds:fit -v color=never)"
[ "$actual" = "$expected" ] || ds:fail 'integration agg fit negative decimals case 2 failed'

echo -e "${GREEN}PASS${NC}"

# CLEANUP

rm $tmp
