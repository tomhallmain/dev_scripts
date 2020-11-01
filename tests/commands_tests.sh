#!/bin/bash
# This test script should produce no output if test run is successful
# TODO: Negative tests, Git tests

test_var=1; tmp=/tmp/ds_commands_tests; q=/dev/null
shell=$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')
jnf1="tests/data/infer_join_fields_test1.csv" jnf2="tests/data/infer_join_fields_test2.csv"
jnd1="tests/data/infer_jf_test_joined.csv" jnd2="tests/data/infer_jf_joined_fit"
jnd3="tests/data/infer_jf_joined_fit_dz" jnd4="tests/data/infer_jf_joined_fit_sn"
seps_base="tests/data/seps_test_base" seps_sorted="tests/data/seps_test_sorted" 
simple_csv="tests/data/company_funding_data.csv"
complex_csv1="tests/data/addresses.csv" complex_csv3="tests/data/addresses_reordered"
complex_csv2="tests/data/Sample100.csv" complex_csv4="tests/data/quoted_fields_with_newline.csv" 
complex_csv5="tests/data/taxables.csv"
ls_sq="tests/data/ls_sq" emoji="tests/data/emoji" emojifit="tests/data/emojifit"

if [[ $shell =~ 'bash' ]]; then
  bsh=0
  cd "${BASH_SOURCE%/*}/.."; source commands.sh
  $(ds:fail 'testfail' &> $tmp); testfail=$(cat $tmp)
  [[ $testfail =~ '_err_: testfail' ]] || echo 'fail command failed in bash case'
elif [[ $shell =~ 'zsh' ]]; then
  cd "$(dirname $0)/.."; source commands.sh
  $(ds:fail 'testfail' &> $tmp); testfail=$(cat $tmp)
  [[ $testfail =~ '_err_: Operation intentionally failed' ]] || echo 'fail command failed in zsh case'
else
  echo 'unhandled shell detected - only zsh/bash supported at this time'
  exit 1
fi

# BASICS TESTS

[[ $(ds:sh | grep -c "") = 1 && $(ds:sh) =~ sh ]] || ds:fail 'sh command failed'

cmds="tests/data/commands_output" ch="@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE"
ds:commands > $tmp
cmp --silent $cmds $tmp && grep -q "$ch" $tmp     || ds:fail 'commands listing failed'

ds_help_output="@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE
@@@ds:help@@@@@@Print help for a given command@@@ds:help ds_command"
[ "$(ds:help 'ds:help')" = "$ds_help_output" ]    || ds:fail 'help command failed'
ds:nset 'ds:nset' 1> $q                           || ds:fail 'nset command failed'
ds:searchn 'ds:searchn' 1> $q                     || ds:fail 'searchn failed on func search'
ds:searchn 'test_var' 1> $q                       || ds:fail 'searchn failed on var search'
[ "$(ds:ntype 'ds:ntype')" = 'FUNC' ]             || ds:fail 'ntype commmand failed'

# zsh trace output in subshell lists a file descriptor
if [[ $shell =~ 'zsh' ]]; then
  ds:trace 'echo test' &>$tmp
  grep -e "+ds:trace:8> eval 'echo test'" -e "+(eval):1> echo test" $tmp &>/dev/null || ds:fail 'trace command failed'
elif [[ $shell =~ 'bash' ]]; then
  trace_expected_bash="++++ echo test\ntest"
  [ "$(ds:trace 'echo test' 2>/dev/null)" = "$(echo -e "$trace_expected_bash")" ] || ds:fail 'trace command failed'
fi

# GIT COMMANDS TESTS

[ $(ds:git_recent_all | awk '{print $3}' | grep -c "") -gt 2 ] \
  || echo 'git recent all failed, possibly due to no git dirs in home'

# JN, PC, PM, IFS TESTS

[ "$(ds:inferfs $jnf1)" = ',' ]                             || ds:fail 'inferfs failed extension case'
[ "$(ds:inferfs $seps_base)" = '\&\%\#' ]                   || ds:fail 'inferfs failed custom separator case'
[ "$(ds:inferfs $ls_sq)" = '[[:space:]]+' ]                 || ds:fail 'inferfs failed quoted fields case'
[ "$(ds:inferfs $complex_csv3)" = ',' ]                     || ds:fail 'inferfs failed quoted fields case'

[ $(ds:jn "$jnf1" "$jnf2" o 1 | grep -c "") -gt 15 ]        || ds:fail 'ds:jn failed one-arg shell case'
[ $(ds:jn "$jnf1" "$jnf2" r -v ind=1 | grep -c "") -gt 15 ] || ds:fail 'ds:jn failed awkarg nonkey case'
[ $(ds:jn "$jnf1" "$jnf2" l -v k=1 | grep -c "") -gt 15 ]   || ds:fail 'ds:jn failed awkarg key case'
[ $(ds:jn "$jnf1" "$jnf2" i 1 | grep -c "") -gt 15 ]        || ds:fail 'ds:jn failed inner join case'
ds:jn "$jnf1" "$jnf2" -v ind=1 > $tmp
cmp --silent "$tmp" "$jnd1"                                 || ds:fail 'ds;jn failed base outer join case'

[ $(ds:print_comps $jnf1{,} | grep -c "") -eq 7 ]           || ds:fail 'print_comps failed no complement case'
[ $(ds:print_comps -v k1=2 -v k2=3,4 $jnf1 $jnf2 | grep -c "") -eq 197 ] \
  || ds:fail 'print_comps failed complments case'

[ "$(ds:print_matches -v k1=2 -v k2=2 $jnf1 $jnf2)" = "NO MATCHES FOUND" ] \
  || ds:fail 'print_matches failed no matches case'
[ $(ds:print_matches -v k=1 $jnf1 $jnf2 | grep -c "") = 167 ] \
  || ds:fail 'print_matches failed matches case'


# SORT TESTS

sort_input="$(echo -e "1:3:a#\$:z\n:test:test:one two:2\n5r:test:2%f.:dew::")"
sort_actual="$(echo "$sort_input" | ds:sort -k3)"
sort_expected='5r:test:2%f.:dew::
1:3:a#$:z
:test:test:one two:2'
[ "$sort_actual" = "$sort_expected" ] || ds:fail 'sort command failed'

sortm_actual="$(cat $seps_base | ds:sortm 2,3,7 d)"
sortm_expected="$(cat $seps_sorted)"
[ "$sortm_actual" = "$sortm_expected" ] || ds:fail 'sortm command failed'

sort_input='d c a b f
f e c b a
f e d c b
e d c b a'
sort_output='d c a b f
f e d c b
f e c b a
e d c b a'
[ "$(echo "$sort_input" | ds:sortm -v k=5,1 -v order=d)" = "$sort_output" ] || ds:fail 'sortm command failed'


# REO TESTS

reo_input='d c a b f
f e c b a
f e d c b
e d c b a'
reo_output='f e c b a'
[ "$(echo "$reo_input" | ds:reo 2)" = "$reo_output" ] || ds:fail 'reo command failed base row case'
reo_output='c
e
e
d'
[ "$(echo "$reo_input" | ds:reo a 2)" = "$reo_output" ] || ds:fail 'reo command failed base column case'

reo_output='a c d e b
f a c d b'
[ "$(echo "$reo_input" | ds:reo 4,1 5,3..1,4)" = "$reo_output" ] || ds:fail 'reo command failed base compound range reo case'
[ "$(echo "$reo_input" | ds:reo 4,1 5,3..1,4 -v FS="[[:space:]]")" = "$reo_output" ] || ds:fail 'reo command failed FS arg case'
[ "$(echo "$PATH" | ds:reo 1 5,3..1,4 -F: | ds:transpose | grep -c "")" -eq 5 ] || ds:fail 'reo command failed F arg case'

reo_output='f b'
[ "$(echo "$reo_input" | ds:reo '4!~b' '!~c')" = "$reo_output" ] || ds:fail 'reo command failed exclusive search case'

reo_input='1:2:3:4:5
5:4:3:2:1
::6::
:3::2:1'

reo_actual="$(echo "$reo_input" | ds:reo '>5' off)"
[ "$reo_actual" = "::6::" ] || ds:fail 'reo command failed c off case'

reo_actual="$(echo "$reo_input" | ds:reo '6##2' '3##' | cat)"
reo_expected='6::
3:2:1
3:4:5'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed anchor case'
reo_actual="$(echo "$reo_input" | ds:reo '/6/../2/' '/3/..' | cat)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed anchor_re case'
reo_actual="$(echo "$reo_input" | ds:reo '6##2' '##3' | cat)"
reo_expected='::6
5:4:3
1:2:3'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed anchor case'
reo_actual="$(echo "$reo_input" | ds:reo '/6/../2/' '../3/' | cat)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed anchor_re case'

reo_expected=':3
3:6'
reo_actual="$(echo "$reo_input" | ds:reo 3 3 -v idx=1)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed indx idx case'
reo_expected=':4:3
4:2:
3::6'
reo_actual="$(echo "$reo_input" | ds:reo 4..3 4..3 -v idx=1)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed rev range idx case'
reo_expected=':5:4:3:2:1
4:1:2::3:
3:::6::
2:1:2:3:4:5
1:5:4:3:2:1'
reo_actual="$(echo "$reo_input" | ds:reo rev rev -v idx=1)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed rev idx case'

reo_actual="$(ds:commands | grep 'ds:' | ds:reo 'len()>130' off)"
reo_expected='@@@ds:gexec@@@@@@Generate a script from pieces of another and run it@@@ds:gexec run=f srcfile outputdir reo_r_args [clean] [verbose]'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed full row len case'

reo_actual="$(ds:commands | grep 'ds:' | ds:reo 'len(4)>50' 2)"
reo_expected='ds:asgn
ds:enti
ds:gexec
ds:jn
ds:nset
ds:path_elements
ds:searchx
ds:srg'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed basic len case'

reo_actual="$(ds:commands | grep 'ds:' | ds:reo 'len(2)%11 || len(2)=13' 'length()<5 && len()>2')"
reo_expected='@@@
ds:gb@@@
ds:gr@@@
ds:gs@@@
@@@' # probably a false field here.
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed extended len case'

reo_actual="$(echo "$reo_input" | ds:reo 1 'len()>0,len()<2' -v uniq=1)"
reo_expected='1:2:3:4:5:'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed uniq col case'
reo_actual="$(echo "$reo_input" | ds:reo 'len(1)>0,len(1)<2' 3 -v uniq=1)"
reo_expected='3
3
6'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed uniq row case'


reo_input=$(for i in $(seq -16 16); do
    printf "%s " $i; printf "%s " $(echo "-1*$i" | bc)
    if [ $(echo "$i%5" | bc) -eq 0 ]; then echo test; else echo nah; fi; done)
reo_output='-1 nah
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
[ "$(echo "$reo_input" | ds:reo "2<0, 3~test" "31!=14")" = "$reo_output" ] || ds:fail 'reo command failed extended cases'

reo_input="$(for i in $(seq -10 20); do 
    [ $i -eq -10 ] && ds:iter test 23 && echo && ds:iter _TeST_ 20 && echo
    for j in $(seq -2 20); do 
      [ $i -ne 0 ] && printf "%s " "$(echo "scale=2; $j/$i" | bc -l)"; done
    [ $i -ne 0 ] && echo; done)"
reo_actual="$(echo "$reo_input" | ds:reo "1,1,>4, [test, [test/i~ST" ">4, [test~T" -v cased=1)"
reo_expected='test test test test test test test test test test test test test test test test test
test test test test test test test test test test test test test test test test test
5.00 6.00 7.00 8.00 9.00 10.00 11.00 12.00 13.00 14.00 15.00 16.00 17.00 18.00 19.00 20.00 -2.00
2.50 3.00 3.50 4.00 4.50 5.00 5.50 6.00 6.50 7.00 7.50 8.00 8.50 9.00 9.50 10.00 -1.00
1.66 2.00 2.33 2.66 3.00 3.33 3.66 4.00 4.33 4.66 5.00 5.33 5.66 6.00 6.33 6.66 -.66
1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00 -.50
test test test test test test test test test test test test test test test test test
test test test test test test test test test test test test test test test test test
_TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_ _TeST_    _TeST_'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed extended cases'

reo_input='d c a b f
f e c b a
f e d c b
e d c b a'
reo_actual="$(echo "$reo_input" | ds:reo "1,1, others, [a" ">4, rev, [f~d")"
reo_expected=' f b a c d d a
 f b a c d d a
 a b c e f f c
 b c d e f f d
 a b c d e e c'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed extended others or reverse cases'

reo_actual="$(echo "$reo_input" | ds:reo "1,1,others,[a" ">4,rev,[f~d")"
reo_expected=' f b a c d d a
 f b a c d d a
 a b c e f f c
 b c d e f f d
 a b c d e e c'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed extended others or reverse cases'

reo_actual="$(echo "$reo_input" | ds:reo "[a~c && 5~a" "[f~d || [e~a && NF>3")"
reo_expected='a 
a '
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed extended logic cases'

reo_actual="$(ds:reo $seps_base ">100&&%7" "%7" | ds:fit -v FS="\\\&\\\%\\\#")"
reo_expected='2    7
1  420'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo command failed extended logic cases'

reo_actual="$(ds:reo $seps_base '5[2!~2' | grep -h "^1")"
[ "$(ds:reo $seps_base '5[2!=2 && 5[2!=23' | grep -h "^1")" = "$reo_actual" ] || ds:fail 'reo command failed comparison case'


# FIT TESTS

fit_var_present="$(echo -e "t 1\nte 2\ntes 3\ntest 4" | ds:fit | awk '{cl=length($0);if(pl && pl!=cl) {print 1;exit};pl=cl}')"
[ "$fit_var_present" = 1 ]                        && ds:fail 'fit command failed pipe case'

fit_expected='Desert City' fit_actual="$(ds:fit "$complex_csv1" | ds:reo 7 4 '-F {2,}')"
[ "$fit_expected" = "$fit_actual" ]               || ds:fail 'fit command failed base case'

fit_expected='Company Name                            Employee Markme       Description
INDIAN HERITAGE ,ART & CULTURE          MADHUKAR              ACCESS PUBLISHING INDIA PVT.LTD
ETHICS, INTEGRITY & APTITUDE ( 3RD/E)   P N ROY ,G SUBBA RAO  ACCESS PUBLISHING INDIA PVT.LTD
PHYSICAL, HUMAN AND ECONOMIC GEOGRAPHY  D R KHULLAR           ACCESS PUBLISHING INDIA PVT.LTD'
fit_actual="$(ds:reo "$complex_csv2" 1,35,37,42 2..4 | ds:fit -F,)"
[ "$(echo -e "$fit_expected")" = "$fit_actual" ]  || ds:fail 'fit command failed quoted field case'

ds:fit $emoji > $tmp; cmp --silent $emojifit $tmp || ds:fail 'fit command failed emoji case'

fit_expected='-rw-r--r--  1  tomhall   4330  Oct  12  11:55  emoji
-rw-r--r--  1  tomhall      0  Oct   3  17:30  file with space, and: commas & colons \ slashes
-rw-r--r--  1  tomhall  12003  Oct   3  17:30  infer_jf_test_joined.csv
-rw-r--r--  1  tomhall   5245  Oct   3  17:30  infer_join_fields_test1.csv
-rw-r--r--  1  tomhall   6043  Oct   3  17:30  infer_join_fields_test2.csv'
[ "$(ds:fit $ls_sq)" = "$fit_expected" ] || ds:fail 'fit command failed ls sq case'

ds:fit $jnd1 -v bufferchar="|" > $tmp
cmp --silent $jnd2 $tmp || ds:fail 'fit command failed bufferchar/decimal complex csv case'
ds:fit $jnd1 -v bufferchar="|" -v d=z > $tmp
cmp --silent $jnd3 $tmp || ds:fail 'fit command failed const decimal complex csv case'
ds:fit $jnd1 -v bufferchar="|" -v d=-2 > $tmp
cmp --silent $jnd4 $tmp || ds:fail 'fit command failed scientific notation complex csv case'

fit_expected="Index  Item                              Cost    Tax  Total
    1  Fruit of the Loom Girl's Socks    7.97   0.60   8.57
    2  Rawlings Little League Baseball   2.97   0.22   3.19
    3  Secret Antiperspirant             1.29   0.10   1.39
    4  Deadpool DVD                     14.96   1.12  16.08
    5  Maxwell House Coffee 28 oz        7.28   0.55   7.83
    6  Banana Boat Sunscreen, 8 oz       6.68   0.50   7.18
    7  Wrench Set, 18 pieces            10.00   0.75  10.75
    8  M and M, 42 oz                    8.98   0.67   9.65
    9  Bertoli Alfredo Sauce             2.12   0.16   2.28"
[ "$(ds:fit $complex_csv5 | head)" = "$fit_expected" ] || ds:fail 'fit command failed spaced quoted field case'


# FC TESTS

fc_expected='2 mozy,Mozy,26,web,American Fork,UT,1-May-05,1900000,USD,a
2 zoominfo,ZoomInfo,80,web,Waltham,MA,1-Jul-04,7000000,USD,a'
fc_actual="$(ds:fieldcounts $simple_csv a 2)"
[ "$fc_expected" = "$fc_actual" ] || ds:fail 'fieldcounts command failed all field case'
fc_expected='54,1-Jan-08
54,1-Oct-07'
fc_actual="$(ds:fieldcounts $simple_csv 7 50)"
[ "$fc_expected" = "$fc_actual" ] || ds:fail 'fieldcounts command failed single field case'
fc_expected='7,450,Palo Alto,facebook'
fc_actual="$(ds:fieldcounts $simple_csv 3,5,1 6)"
[ "$fc_expected" = "$fc_actual" ] || ds:fail 'fieldcounts command failed multifield case'


# NEWFS TESTS

nfs_expected='Joan "the bone", Anne::Jet::9th, at Terrace plc::Desert City::CO::00123'
nfs_actual="$(ds:newfs $complex_csv1 :: | grep -h Joan)"
[ "$nfs_expected" = "$nfs_actual" ] || ds:fail 'newfs command failed'


# PREFIELD TESTS

prefield_expected='Last Name@@@Street Address@@@First Name
Doe@@@120 jefferson st.@@@John
McGinnis@@@220 hobo Av.@@@Jack
Repici@@@120 Jefferson St.@@@"John ""Da Man"""
Tyler@@@"7452 Terrace ""At the Plaza"" road"@@@Stephen
Blankman@@@@@@
Jet@@@"9th, at Terrace plc"@@@"Joan ""the bone"", Anne"'
prefield_actual="$(ds:prefield $complex_csv3 , 1)"
[ "$prefield_expected" = "$prefield_actual" ] || ds:fail 'prefield command failed base dq case'

prefield_expected='-rw-r--r--@@@1@@@tomhall@@@4330@@@Oct@@@12@@@11:55@@@emoji
-rw-r--r--@@@1@@@tomhall@@@0@@@Oct@@@3@@@17:30@@@file with space, and: commas & colons \ slashes
-rw-r--r--@@@1@@@tomhall@@@12003@@@Oct@@@3@@@17:30@@@infer_jf_test_joined.csv
-rw-r--r--@@@1@@@tomhall@@@5245@@@Oct@@@3@@@17:30@@@infer_join_fields_test1.csv
-rw-r--r--@@@1@@@tomhall@@@6043@@@Oct@@@3@@@17:30@@@infer_join_fields_test2.csv'
prefield_actual="$(ds:prefield $ls_sq '[[:space:]]+')"
[ "$prefield_expected" = "$prefield_actual" ] || ds:fail 'prefield command failed base sq case'

prefield_expected='Conference room 1@@@John,  \n  Please bring the M. Mathers file for review   \n  -J.L.@@@10/18/2002@@@test, field
Conference room 1@@@John \n  Please bring the M. Mathers file for review \n  -J.L.@@@10/18/2002@@@"
Conference room 1@@@"@@@10/18/2002'
prefield_actual="$(ds:prefield $complex_csv4 ,)"
[ "$prefield_expected" = "$prefield_actual" ] || ds:fail 'prefield command failed newline lossy quotes case'

prefield_expected='Conference room 1@@@"John,   \n  Please bring the M. Mathers file for review   \n  -J.L."@@@10/18/2002@@@"test, field"
"Conference room 1"@@@"John, \n  Please bring the M. Mathers file for review \n  -J.L."@@@10/18/2002@@@""
"Conference room 1"@@@""@@@10/18/2002'
prefield_actual="$(ds:prefield $complex_csv4 , 1)"
[ "$prefield_expected" = "$prefield_actual" ] || ds:fail 'prefield command failed newline retain outer quotes case'


# ASSORTED COMMANDS TESTS

[ "$(echo 1 2 3 | ds:join_by ', ')" = "1, 2, 3" ] || ds:fail 'join_by command failed on pipe case'

[ "$(ds:join_by ', ' 1 2 3)" = "1, 2, 3" ]        || ds:fail 'join_by command failed on pipe case'

[ "$(ds:embrace 'test')" = '{test}' ]             || ds:fail 'embrace command failed'

path_el_arr=( tests/data/ infer_join_fields_test1 '.csv' )
[ -z $bsh ] && let count=1 || let count=0
for el in $(IFS='\t' ds:path_elements $jnf1); do
  test_el=${path_el_arr[count]}
  [ $el = $test_el ] || ds:fail "path_elements command failed on $test_el"
  let count+=1
done

idx_actual="$(echo -e "5\n2\n4\n3\n1" | ds:idx)"
idx_expected='1 5
2 2
3 4
4 3
5 1'
[ "$idx_actual" = "$idx_expected" ] || ds:fail 'idx command failed'

[ "$(ds:filename_str $jnf1 '-1')" = 'tests/data/infer_join_fields_test1-1.csv' ] \
  || ds:fail 'filename_str command failed'

[ "$(ds:iter "a" 3)" = 'a a a' ] || ds:fail 'iter command failed'

echo $(ds:root) 1> $q || ds:fail 'root command failed'

[ "$(printf "%s\n" a b c d | ds:rev | tr -d '\n')" = "dcba" ] || ds:fail 'rev command failed'

echo > $tmp; for i in $(seq 1 10); do echo test$i >> $tmp; done; ds:sedi $tmp 'test'
[[ ! "$(head -n1 $tmp)" =~ "test" ]] || ds:fail 'sedi command failed'

mini_output="1;2;3;4;5;6;7;8;9;10"
[ "$(cat $tmp | ds:mini)" = "$mini_output" ]                             || ds:fail 'mini command failed'

[ "$(ds:unicode "cats😼😻")" = '\U63\U61\U74\U73\U1F63C\U1F63B' ]        || ds:fail 'unicode command failed base case'
[ "$(echo "cats😼😻" | ds:unicode)" = '\U63\U61\U74\U73\U1F63C\U1F63B' ] || ds:fail 'unicode command failed pipe case'

sbsp_actual="$(ds:sbsp tests/data/subseps_test "SEP" | ds:reo 1,7 | cat)"
sbsp_expected='A;A;A;A
G;G;G;G'
[ "$sbsp_expected" = "$sbsp_actual" ] || ds:fail 'sbsp command failed'

todo_expected='tests/commands_tests.sh:# TODO: Negative tests, Git tests'
[ "$(ds:todo tests/commands_tests.sh | head -n1)" = "$todo_expected" ] || ds:fail 'todo command failed'

[ "$(ds:substr "TEST" "T" "ST")" = "E" ]        || ds:fail 'substr command failed base case'
[ "$(echo "TEST" | ds:substr "T" "ST")" = "E" ] || ds:fail 'substr command failed pipee case'
substr_actual="$(ds:substr "1/2/3/4" "[0-9]+\\/[0-9]+\\/[0-9]+\\/")"
[ "4" = "$substr_actual" ]                      || ds:fail 'substr command failed extended regex case'

pow_expected="
23,ACK,0
24,Mark,0
25,ACK
27,ACER PRESS,0
28,Mark
28,ACER PRESS
74,0"
pow_actual="$(ds:pow $complex_csv2 20 | cat)"
[ "$pow_expected" = "$pow_actual" ] || ds:fail 'pow command failed base case'

pow_expected="
0.22,3,5
0.26,3
0.5,4,5
0.53,4
0.74,5"
pow_actual="$(ds:pow $complex_csv2 20 t | cat)"
[ "$pow_expected" = "$pow_actual" ] || ds:fail 'pow command failed combin counts case'

if [[ $shell =~ 'bash' ]]; then
  fsrc_expected='support/utils.sh'
  [[ "$(ds:fsrc ds:noawkfs | head -n1)" =~ "$fsrc_expected" ]] || ds:fail 'fsrc command failed'
fi

help_deps='ds:stag
ds:fail
ds:fit
ds:reo
ds:nset
ds:commands'
[[ "$(ds:deps ds:help)" = "$help_deps" ]]                    || ds:fail 'deps command failed'
[ "$(ds:websel https://www.google.com title)" = Google ]    || ds:fail 'webpage title command failed or internet is out'

# CLEANUP

rm $tmp
