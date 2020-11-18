#!/bin/bash
# This test script should produce no output if test run is successful
# TODO: Negative tests, Git tests

test_var=1
tmp=/tmp/ds_commands_tests
q=/dev/null
shell="$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')"
jnf1="tests/data/infer_join_fields_test1.csv"
jnf2="tests/data/infer_join_fields_test2.csv"
jnf3="tests/data/infer_join_fields_test3.scsv"
jnd1="tests/data/infer_jf_test_joined.csv"
jnd2="tests/data/infer_jf_joined_fit"
jnd3="tests/data/infer_jf_joined_fit_dz"
jnd4="tests/data/infer_jf_joined_fit_sn"
jnr1="tests/data/jn_repeats1"
jnr2="tests/data/jn_repeats2"
jnr3="tests/data/jn_repeats3"
jnr4="tests/data/jn_repeats4"
jnrjn1="tests/data/jn_repeats_jnd1"
jnrjn2="tests/data/jn_repeats_jnd2"
seps_base="tests/data/seps_test_base"
seps_sorted="tests/data/seps_test_sorted" 
simple_csv="tests/data/company_funding_data.csv"
complex_csv1="tests/data/addresses.csv"
complex_csv3="tests/data/addresses_reordered"
complex_csv2="tests/data/Sample100.csv"
complex_csv4="tests/data/quoted_fields_with_newline.csv" 
complex_csv5="tests/data/taxables.csv"
ls_sq="tests/data/ls_sq"
inferfs_chunks="tests/data/inferfs_chunks_test"
emoji="tests/data/emoji"
emojifit="tests/data/emojifit"

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

[[ $(ds:sh | grep -c "") = 1 && $(ds:sh) =~ sh ]] || ds:fail 'sh command failed'

cmds="tests/data/commands_output"
ch="@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE"
ds:commands > $tmp
cmp --silent $cmds $tmp && grep -q "$ch" $tmp     || ds:fail 'commands listing failed'

ds_help_output="@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE
@@@ds:help@@@@@@Print help for a given command@@@ds:help ds_command"
[ "$(ds:help 'ds:help')" = "$ds_help_output" ]    || ds:fail 'help command failed'
ds:nset 'ds:nset' 1> $q                           || ds:fail 'nset command failed'
ds:searchn 'ds:searchn' 1> $q                     || ds:fail 'searchn failed on func search'
ds:searchn 'test_var' 1> $q                       || ds:fail 'searchn failed on var search'
[ "$(ds:ntype 'ds:ntype')" = 'FUNC' ]             || ds:fail 'ntype command failed'

# zsh trace output in subshell lists a file descriptor
if [[ $shell =~ 'zsh' ]]; then
  ds:trace 'echo test' &>$tmp
  grep -e "+ds:trace:8> eval 'echo test'" -e "+(eval):1> echo test" $tmp &>$q || ds:fail 'trace command failed'
elif [[ $shell =~ 'bash' ]]; then
  trace_expected_bash="++++ echo test\ntest"
  [ "$(ds:trace 'echo test' 2>$q)" = "$(echo -e "$trace_expected_bash")" ] || ds:fail 'trace command failed'
fi

# GIT COMMANDS TESTS

[ $(ds:git_recent_all | awk '{print $3}' | grep -c "") -gt 2 ] \
  || echo 'git recent all failed, possibly due to no git dirs in home'

# IFS TESTS

[ "$(ds:inferfs $jnf1)" = ',' ]                             || ds:fail 'inferfs failed extension case'
[ "$(ds:inferfs $seps_base)" = '\&\%\#' ]                   || ds:fail 'inferfs failed custom separator case 1'
[ "$(ds:inferfs $jnf3)" = '\;\;' ]                          || ds:fail 'inferfs failed custom separator case 2'
[ "$(ds:inferfs $ls_sq)" = '[[:space:]]+' ]                 || ds:fail 'inferfs failed quoted fields case'
[ "$(ds:inferfs $complex_csv3)" = ',' ]                     || ds:fail 'inferfs failed quoted fields case'
[ "$(ds:inferfs $inferfs_chunks)" = ',' ]                   || ds:fail 'inferfs failed simple chunks case'

# INFERH TESTS

ds:inferh $seps_base 2>$q                                   && ds:fail 'inferh failed custom separator noheaders case'
ds:inferh $ls_sq 2>$q                                       && ds:fail 'inferh failed ls noheaders case'
ds:inferh $simple_csv 2>$q                                  || ds:fail 'inferh failed basic headers case'
ds:inferh $complex_csv3 2>$q                                || ds:fail 'inferh failed complex headers case'

# JN TESTS

echo -e "a b c d\n1 2 3 4" > $tmp
jn_expected='a b c d b c
1 2 3 4 3 2'
jn_actual="$(echo -e "a b c d\n1 3 2 4" | ds:jn $tmp inner 1,4)"
[ "$jn_actual" = "$jn_expected" ]                           || ds:fail 'ds:jn failed readme single keyset case'
jn_expected='a c b d
1 2 3 4'
jn_actual="$(echo -e "a b c d\n1 3 2 4" | ds:jn $tmp right 1,2,3,4 1,3,2,4)"
[ "$jn_actual" = "$jn_expected" ]                           || ds:fail 'ds:jn failed readme multi-keyset case'
jn_expected='a b c d
1 3 2 4
1 2 3 4'
jn_actual="$(echo -e "a b c d\n1 3 2 4" | ds:jn $tmp outer merge)"
[ "$jn_actual" = "$jn_expected" ]                           || ds:fail 'ds:jn failed readme merge case'

[ $(ds:jn "$jnf1" "$jnf2" o 1 | grep -c "") -gt 15 ]        || ds:fail 'ds:jn failed one-arg shell case'
[ $(ds:jn "$jnf1" "$jnf2" r -v ind=1 | grep -c "") -gt 15 ] || ds:fail 'ds:jn failed awkarg nonkey case'
[ $(ds:jn "$jnf1" "$jnf2" l -v k=1 | grep -c "") -gt 15 ]   || ds:fail 'ds:jn failed awkarg key case'
[ $(ds:jn "$jnf1" "$jnf2" i 1 | grep -c "") -gt 15 ]        || ds:fail 'ds:jn failed inner join case'

ds:jn "$jnf1" "$jnf2" -v ind=1 > $tmp
cmp --silent $tmp $jnd1                                     || ds:fail 'ds:jn failed base outer join case'
ds:jn "$jnr1" "$jnr2" o 2,3,4,5 > $tmp
cmp --silent $tmp $jnrjn1                                   || ds:fail 'ds:jn failed repeats partial keyset case'
ds:jn "$jnr3" "$jnr4" o merge -v merge_verbose=1 > $tmp
cmp --silent $tmp $jnrjn2                                   || ds:fail 'ds:jn failed repeats merge case'


cat "$jnf1" > $tmp
[ $(ds:print_comps $jnf1 $tmp | grep -c "") -eq 7 ]         || ds:fail 'print_comps failed no complement case'
[ "$(ds:print_comps $jnf1{,})" = 'Files are the same!' ]    || ds:fail 'print_comps failed no complement samefile case'
[ $(ds:print_comps $jnf1 $jnf2 -v k1=2 -v k2=3,4 | grep -c "") -eq 197 ] \
  || ds:fail 'print_comps failed complments case'

[ "$(ds:print_matches $jnf1 $jnf2 -v k1=2 -v k2=2)" = "NO MATCHES FOUND" ] \
  || ds:fail 'print_matches failed no matches case'
[ $(ds:print_matches $jnf1 $jnf2 -v k=1 | grep -c "") = 167 ] \
  || ds:fail 'print_matches failed matches case'


# SORT TESTS

sort_input="$(echo -e "1:3:a#\$:z\n:test:test:one two:2\n5r:test:2%f.:dew::")"
sort_actual="$(echo "$sort_input" | ds:sort -k3)"
sort_expected='5r:test:2%f.:dew::
1:3:a#$:z
:test:test:one two:2'
[ "$sort_actual" = "$sort_expected" ] || ds:fail 'sort failed'

sortm_actual="$(cat $seps_base | ds:sortm 2,3,7 d)"
sortm_expected="$(cat $seps_sorted)"
[ "$sortm_actual" = "$sortm_expected" ] || ds:fail 'sortm failed multikey case'

sort_input='d c a b f
f e c b a
f e d c b
e d c b a'
sort_output='d c a b f
f e d c b
f e c b a
e d c b a'
[ "$(echo "$sort_input" | ds:sortm -v k=5,1 -v order=d)" = "$sort_output" ] || ds:fail 'sortm failed awkargs case'

sort_input="1\nj\n98\n47\n9\n05\nj2\n9ju\n9\n9d" 
sort_output='1
47
05
9
9
9d
9ju
98
j
j2'
[ "$(echo -e "$sort_input" | ds:sortm 1 a n)" = "$sort_output" ] || ds:fail 'sortm failed numeric sort case'

# PREFIELD TESTS

prefield_expected='Last Name@@@Street Address@@@First Name
Doe@@@120 jefferson st.@@@John
McGinnis@@@220 hobo Av.@@@Jack
Repici@@@120 Jefferson St.@@@"John ""Da Man"""
Tyler@@@"7452 Terrace ""At the Plaza"" road"@@@Stephen
Blankman@@@@@@
Jet@@@"9th, at Terrace plc"@@@"Joan ""the bone"", Anne"'
prefield_actual="$(ds:prefield $complex_csv3 , 1)"
[ "$prefield_expected" = "$prefield_actual" ] || ds:fail 'prefield failed base dq case'

prefield_expected='-rw-r--r--@@@1@@@tomhall@@@4330@@@Oct@@@12@@@11:55@@@emoji
-rw-r--r--@@@1@@@tomhall@@@0@@@Oct@@@3@@@17:30@@@file with space, and: commas & colons \ slashes
-rw-r--r--@@@1@@@tomhall@@@12003@@@Oct@@@3@@@17:30@@@infer_jf_test_joined.csv
-rw-r--r--@@@1@@@tomhall@@@5245@@@Oct@@@3@@@17:30@@@infer_join_fields_test1.csv
-rw-r--r--@@@1@@@tomhall@@@6043@@@Oct@@@3@@@17:30@@@infer_join_fields_test2.csv'
prefield_actual="$(ds:prefield $ls_sq '[[:space:]]+')"
[ "$prefield_expected" = "$prefield_actual" ] || ds:fail 'prefield failed base sq case'

prefield_expected='Conference room 1@@@John,  \n  Please bring the M. Mathers file for review   \n  -J.L.@@@10/18/2002@@@test, field
Conference room 1@@@John \n  Please bring the M. Mathers file for review \n  -J.L.@@@10/18/2002@@@"
Conference room 1@@@"@@@10/18/2002'
prefield_actual="$(ds:prefield $complex_csv4 ,)"
[ "$prefield_expected" = "$prefield_actual" ] || ds:fail 'prefield failed newline lossy quotes case'

prefield_expected='Conference room 1@@@"John,   \n  Please bring the M. Mathers file for review   \n  -J.L."@@@10/18/2002@@@"test, field"
"Conference room 1"@@@"John, \n  Please bring the M. Mathers file for review \n  -J.L."@@@10/18/2002@@@""
"Conference room 1"@@@""@@@10/18/2002'
prefield_actual="$(ds:prefield $complex_csv4 , 1)"
[ "$prefield_expected" = "$prefield_actual" ] || ds:fail 'prefield failed newline retain outer quotes case'

# REO TESTS

reo_input='d c a b f
f e c b a
f e d c b
e d c b a'
reo_output='f e c b a'
[ "$(echo "$reo_input" | ds:reo 2)" = "$reo_output" ] || ds:fail 'reo failed base row case'
reo_output='c
e
e
d'
[ "$(echo "$reo_input" | ds:reo a 2)" = "$reo_output" ] || ds:fail 'reo failed base column case'

reo_output='a c d e b
f a c d b'
[ "$(echo "$reo_input" | ds:reo 4,1 5,3..1,4)" = "$reo_output" ] || ds:fail 'reo failed base compound range reo case'
[ "$(echo "$reo_input" | ds:reo 4,1 5,3..1,4 -v FS="[[:space:]]")" = "$reo_output" ] || ds:fail 'reo failed FS arg case'
[ "$(echo "$PATH" | ds:reo 1 5,3..1,4 -F: | ds:transpose | grep -c "")" -eq 5 ] || ds:fail 'reo failed F arg case'

reo_output='f b'
[ "$(echo "$reo_input" | ds:reo '4!~b' '!~c')" = "$reo_output" ] || ds:fail 'reo failed exclusive search case'

reo_input='1:2:3:4:5
5:4:3:2:1
::6::
:3::2:1'

reo_actual="$(echo "$reo_input" | ds:reo '>5' off)"
[ "$reo_actual" = "::6::" ]         || ds:fail 'reo failed c off case'
reo_actual="$(echo "$reo_input" | ds:reo '~6' off)"
[ "$reo_actual" = "::6::" ]         || ds:fail 'reo failed c off case'

reo_actual="$(echo "$reo_input" | ds:reo '6##2' '3##' | cat)"
reo_expected='6::
3:2:1
3:4:5'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed anchor case'
reo_actual="$(echo "$reo_input" | ds:reo '/6/../2/' '/3/..' | cat)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed anchor_re case'
reo_actual="$(echo "$reo_input" | ds:reo '6##2' '##3' | cat)"
reo_expected='::6
5:4:3
1:2:3'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed anchor case'
reo_actual="$(echo "$reo_input" | ds:reo '/6/../2/' '../3/' | cat)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed anchor_re case'

reo_expected=':3
3:6'
reo_actual="$(echo "$reo_input" | ds:reo 3 3 -v idx=1)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed indx idx case'
reo_expected=':4:3
4:2:
3::6'
reo_actual="$(echo "$reo_input" | ds:reo 4..3 4..3 -v idx=1)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed rev range idx case'
reo_expected=':5:4:3:2:1
4:1:2::3:
3:::6::
2:1:2:3:4:5
1:5:4:3:2:1'
reo_actual="$(echo "$reo_input" | ds:reo rev rev -v idx=1)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed rev idx case'

reo_actual="$(ds:commands | grep 'ds:' | ds:reo 'len()>130' off)"
reo_expected='**@@@ds:jn@@@@@@Join two files or a file and STDIN with any keyset@@@ds:jn file1 [file2] [jointype] [k|merge] [k2] [prefield=f] [awkargs]'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed full row len case'

reo_actual="$(ds:commands | grep 'ds:' | ds:reo 'len(4)>48' 2)"
reo_expected='ds:agg
ds:jn
ds:nset'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed basic len case'

reo_actual="$(ds:commands | grep 'ds:' | ds:reo 'len(2)%11 || len(2)=13' 'length()<5 && len()>2')"
reo_expected='@@@
ds:gb@@@
ds:gr@@@
ds:gsq@@@
ds:gs@@@
@@@' # probably a false field here.
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed extended len case'

reo_actual="$(echo "$reo_input" | ds:reo 1 'len()>0,len()<2' -v uniq=1)"
reo_expected='1:2:3:4:5:'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed uniq col case'
reo_actual="$(echo "$reo_input" | ds:reo 'len(1)>0,len(1)<2' 3 -v uniq=1)"
reo_expected='3
3
6'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed uniq row case'


reo_input=$(for i in $(seq -16 16); do
    printf "%s " $i; printf "%s " $(echo "-1*$i" | bc)
    if [ $(echo "$i%5" | bc) -eq 0 ]; then echo test; else echo nah; fi; done)
reo_expected='-1 nah
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
[ "$(echo "$reo_input" | ds:reo "2<0, 3~test" "31!=14")" = "$reo_expected" ] || ds:fail 'reo failed extended cases'

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
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed extended cases'

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
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed extended others or reverse cases'

reo_actual="$(echo "$reo_input" | ds:reo "1,1,others,[a" ">4,rev,[f~d")"
reo_expected=' f b a c d d a
 f b a c d d a
 a b c e f f c
 b c d e f f d
 a b c d e e c'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed extended others or reverse cases'

reo_actual="$(echo "$reo_input" | ds:reo "[a~c && 5~a" "[f~d || [e~a && NF>3")"
reo_expected='a
a'
[ "$(echo -e "$reo_actual" | tr -d " ")" = "$reo_expected" ] || ds:fail 'reo failed extended logic cases'

reo_actual="$(ds:reo $seps_base ">100&&%7" "%7")"
reo_expected='7&%#2
420&%#1'
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed extended logic cases'

reo_actual="$(ds:reo $seps_base '5[2!~2' | grep -h "^1")"
[ "$(ds:reo $seps_base '5[2!=2 && 5[2!=23' | grep -h "^1")" = "$reo_actual" ] || ds:fail 'reo failed comparison case'

head -n5 tests/data/company_funding_data.csv > $tmp

reo_expected='company,category,city,raisedAmt,raisedCurrency,round
Facebook,web,Palo Alto,300000000,USD,c
ZeniMax,web,Rockville,300000000,USD,a'
reo_actual="$(ds:reo $simple_csv '1, >200000000' '[^c, [^r')"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed readme case 1'
reo_expected='b,1-May-07
a,1-Oct-06
c,1-Jan-08'
reo_actual="$(ds:reo $tmp '[lifelock' '[round,[funded')"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed readme case 2'
reo_expected='LifeLock,1-Jan-08
MyCityFaces,1-Jan-08
LifeLock,1-Oct-06
LifeLock,1-May-07
company,fundedDate'
reo_actual="$(ds:reo $tmp '~Jan-08 && NR<6, 3..1' '[company,~Jan-08')"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed readme case 3'
reo_expected='b,USD,6850000,1-May-07,AZ,Tempe,web,,LifeLock,lifelock
a,USD,6000000,1-Oct-06,AZ,Tempe,web,,LifeLock,lifelock
c,USD,25000000,1-Jan-08,AZ,Tempe,web,,LifeLock,lifelock
seed,USD,50000,1-Jan-08,AZ,Scottsdale,web,7,MyCityFaces,mycityfaces
c,USD,25000000,1-Jan-08,AZ,Tempe,web,,LifeLock,lifelock
a,USD,6000000,1-Oct-06,AZ,Tempe,web,,LifeLock,lifelock
b,USD,6850000,1-May-07,AZ,Tempe,web,,LifeLock,lifelock
round,raisedCurrency,raisedAmt,fundedDate,state,city,category,numEmps,company,permalink'
reo_actual="$(ds:reo $tmp '!~permalink && !~mycity,rev' rev)"
[ "$reo_actual" = "$reo_expected" ] || ds:fail 'reo failed extended logic + rev cases'



# FIT TESTS

fit_var_present="$(echo -e "t 1\nte 2\ntes 3\ntest 4" | ds:fit -v color=never | awk '{cl=length($0);if(pl && pl!=cl) {print 1;exit};pl=cl}')"
[ "$fit_var_present" = 1 ]                        && ds:fail 'fit failed pipe case'

fit_expected='Desert City' fit_actual="$(ds:fit "$complex_csv1" | ds:reo 7 4 '-F {2,}')"
[ "$fit_expected" = "$fit_actual" ]               || ds:fail 'fit failed base case'

fit_expected='Company Name                            Employee Markme       Description
INDIAN HERITAGE ,ART & CULTURE          MADHUKAR              ACCESS PUBLISHING INDIA PVT.LTD
ETHICS, INTEGRITY & APTITUDE ( 3RD/E)   P N ROY ,G SUBBA RAO  ACCESS PUBLISHING INDIA PVT.LTD
PHYSICAL, HUMAN AND ECONOMIC GEOGRAPHY  D R KHULLAR           ACCESS PUBLISHING INDIA PVT.LTD'
fit_actual="$(ds:reo "$complex_csv2" 1,35,37,42 2..4 | ds:fit -F, -v color=never)"
[ "$(echo -e "$fit_expected")" = "$fit_actual" ]  || ds:fail 'fit failed quoted field case'

ds:fit $emoji > $tmp; cmp --silent $emojifit $tmp || ds:fail 'fit failed emoji case'

fit_expected='-rw-r--r--  1  tomhall   4330  Oct  12  11:55  emoji
-rw-r--r--  1  tomhall      0  Oct   3  17:30  file with space, and: commas & colons \ slashes
-rw-r--r--  1  tomhall  12003  Oct   3  17:30  infer_jf_test_joined.csv
-rw-r--r--  1  tomhall   5245  Oct   3  17:30  infer_join_fields_test1.csv
-rw-r--r--  1  tomhall   6043  Oct   3  17:30  infer_join_fields_test2.csv'
[ "$(ds:fit $ls_sq -v color=never)" = "$fit_expected" ] || ds:fail 'fit failed ls sq case'

ds:fit $jnd1 -v bufferchar="|" > $tmp
cmp --silent $jnd2 $tmp || ds:fail 'fit failed bufferchar/decimal complex csv case'
ds:fit $jnd1 -v bufferchar="|" -v d=z > $tmp
cmp --silent $jnd3 $tmp || ds:fail 'fit failed const decimal complex csv case'
ds:fit $jnd1 -v bufferchar="|" -v d=-2 > $tmp
cmp --silent $jnd4 $tmp || ds:fail 'fit failed scientific notation complex csv case'

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
[ "$(ds:fit $complex_csv5 -v color=never | head)" = "$fit_expected" ] || ds:fail 'fit failed spaced quoted field case'

fit_input='# Test comment 1
1,2,3,4,5,100
a,b,c,d,e,f
g,h,i,j,k,l,m,f,o
,,2,3,5,1
# Test comment 2
// Diff style comment'

fit_expected='# Test comment 1
1,2,3,4,5,100
a                      b  c  d  e  f
g                      h  i  j  k  l  m  f  o
                          2  3  5  1
# Test comment 2
// Diff style comment'
fit_actual="$(echo -e "$fit_input" | ds:fit -F, -v startfit=a -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$fit_expected" = "$fit_actual" ] || ds:fail 'fit failed startfit case'

fit_expected='# Test comment 1
1  2  3  4  5  100
a  b  c  d  e  f
g,h,i,j,k,l,m,f,o
,,2,3,5,1
# Test comment 2
// Diff style comment'
fit_actual="$(echo -e "$fit_input" | ds:fit -F, -v startfit=2 -v endfit=f -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$fit_expected" = "$fit_actual" ] || ds:fail 'fit failed startfit endfit case'

fit_expected='# Test comment 1
1  2  3  4  5  100
a  b  c  d  e  f
g  h  i  j  k  l    m  f  o
      2  3  5  1
# Test comment 2
// Diff style comment'
fit_actual="$(echo -e "$fit_input" | ds:fit -F, -v startrow=2 -v endrow=5 -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$fit_expected" = "$fit_actual" ] || ds:fail 'fit failed startrow endrow case'

fit_expected='# Test comment 1
1,2,3,4,5,100
a  b  c  d  e  f
g  h  i  j  k  l  m  f  o
,,2,3,5,1
# Test comment 2
// Diff style comment'
fit_actual="$(echo -e "$fit_input" | ds:fit -F, -v onlyfit='^[a-z]' -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$fit_expected" = "$fit_actual" ] || ds:fail 'fit failed onlyfit case'

fit_expected='# Test comment 1
1,2,3,4,5,100
a  b  c  d  e  f
g,h,i,j,k,l,m,f,o
      2  3  5  1
# Test comment 2
// Diff style comment'
fit_actual="$(echo -e "$fit_input" | ds:fit -F, -v nofit='(^1|^#|^//|o$)' -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$fit_expected" = "$fit_actual" ] || ds:fail 'fit failed nofit case'

fit_input="one two three four + *\n-7 -5 -7 -1 -20 -48\n0.0833 0.1667 0.0938 1.333 0.01 0.0017"
fit_expected='    one      two    three    four       +         *
-7.0000  -5.0000  -7.0000  -1.000  -20.00  -48.0000
 0.0833   0.1667   0.0938   1.333    0.01    0.0017'
fit_actual="$(echo -e "$fit_input" | ds:fit -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$fit_expected" = "$fit_actual" ] || ds:fail 'fit failed negative decimal case 1'

fit_input='a@@@1@@@-2@@@3@@@4@@@-0.0416667@@@6@@@-24@@@-6
b@@@0@@@-3@@@4@@@1@@@0@@@2@@@0@@@-2
c@@@3@@@6@@@2.5@@@4@@@0.05@@@15.5@@@180@@@-15.5
-@@@-4@@@-1@@@-9.5@@@-9@@@-0.0083333@@@-23.5@@@-156@@@23.5
/@@@0@@@1@@@4.8@@@1@@@0@@@0.774194@@@0@@@-0.774194
*@@@0@@@36@@@30@@@16@@@0@@@186@@@0@@@-186
+@@@4@@@1@@@9.5@@@9@@@0.0083333@@@23.5@@@156@@@-23.5'
fit_expected='a   1  -2   3.0   4  -0.0416667       6.000000   -24      -6.000000
b   0  -3   4.0   1   0.0000000       2.000000     0      -2.000000
c   3   6   2.5   4   0.0500000      15.500000   180     -15.500000
-  -4  -1  -9.5  -9  -0.0083333     -23.500000  -156      23.500000
/   0   1   4.8   1   0.0000000       0.774194     0      -0.774194
*   0  36  30.0  16   0.0000000     186.000000     0    -186.000000
+   4   1   9.5   9   0.0083333      23.500000   156     -23.500000'
fit_actual="$(echo -e "$fit_input" | ds:fit -v color=never | sed -E 's/[[:space:]]+$//g')"
[ "$fit_expected" = "$fit_actual" ] || ds:fail 'fit failed negative decimal case 2'


# FC TESTS

fc_expected='2 mozy,Mozy,26,web,American Fork,UT,1-May-05,1900000,USD,a
2 zoominfo,ZoomInfo,80,web,Waltham,MA,1-Jul-04,7000000,USD,a'
fc_actual="$(ds:fieldcounts $simple_csv a 2)"
[ "$fc_expected" = "$fc_actual" ] || ds:fail 'fieldcounts failed all field case'
fc_expected='54,1-Jan-08
54,1-Oct-07'
fc_actual="$(ds:fieldcounts $simple_csv 7 50)"
[ "$fc_expected" = "$fc_actual" ] || ds:fail 'fieldcounts failed single field case'
fc_expected='7,450,Palo Alto,facebook'
fc_actual="$(ds:fieldcounts $simple_csv 3,5,1 6)"
[ "$fc_expected" = "$fc_actual" ] || ds:fail 'fieldcounts failed multifield case'


# NEWFS TESTS

nfs_expected='Joan "the bone", Anne::Jet::9th, at Terrace plc::Desert City::CO::00123'
nfs_actual="$(ds:newfs $complex_csv1 :: | grep -h Joan)"
[ "$nfs_expected" = "$nfs_actual" ] || ds:fail 'newfs command failed'


# SUBSEP TESTS

sbsp_actual="$(ds:sbsp tests/data/subseps_test "SEP" | ds:reo 1,7 | cat)"
sbsp_expected='A;A;A;A
G;G;G;G'
[ "$sbsp_expected" = "$sbsp_actual" ] || ds:fail 'sbsp failed'
sbsp_expected='cdatetime,,,address
1,1,06 0:00,3108 OCCIDENTAL DR
1,1,06 0:00,2082 EXPEDITION WAY
1,1,06 0:00,4 PALEN CT
1,1,06 0:00,22 BECKFORD CT'
sbsp_actual="$(ds:reo tests/data/testcrimedata.csv 1..5 1,2 | ds:sbsp '\\/' "" -F,)"
[ "$sbsp_expected" = "$sbsp_actual" ] || ds:fail 'sbsp failed readme case'

# POW TESTS

pow_expected="23,ACK,0
24,Mark,0
25,ACK
27,ACER PRESS,0
28,Mark
28,ACER PRESS
74,0"
pow_actual="$(ds:pow $complex_csv2 20 | cat)"
[ "$pow_expected" = "$pow_actual" ] || ds:fail 'pow failed base case'

pow_expected="0.22,3,5
0.26,3
0.5,4,5
0.53,4
0.74,5"
pow_actual="$(ds:pow $complex_csv2 20 t | cat)"
[ "$pow_expected" = "$pow_actual" ] || ds:fail 'pow failed combin counts case'

# PVT TESTS

pvt_input='1 2 3 4
5 6 7 5
4 6 5 8'
pvt_expected='PIVOT@@@1@@@5@@@4@@@
2@@@3::4@@@@@@@@@
6@@@@@@7::5@@@5::8@@@'
pvt_actual="$(echo "$pvt_input" | ds:pvt 2 1)"
[ "$pvt_actual" = "$pvt_expected" ] || ds:fail 'pvt failed gen z case'
pvt_expected='PIVOT@@@1@@@5@@@4@@@
2@@@3@@@@@@@@@
6@@@@@@7@@@5@@@'
pvt_actual="$(echo "$pvt_input" | ds:pvt 2 1 3)"
[ "$pvt_actual" = "$pvt_expected" ] || ds:fail 'pvt failed spec z case'
pvt_expected='PIVOT@@@@@@d@@@4@@@
a@@@b@@@c@@@@@@
1@@@2@@@@@@3@@@'
pvt_actual="$(echo -e "a b c d\n1 2 3 4" | ds:pvt 1,2 4 3)"
[ "$pvt_actual" = "$pvt_expected" ] || ds:fail 'pvt failed readme multi-y case'


# AGG TESTS

echo -e "one two three four\n1 2 3 4\n4 3 2 1\n1 2 4 3\n3 2 4 1" > $tmp
agg_expected='one@@@two@@@three@@@four@@@$3+$2
1@@@2@@@3@@@4@@@5
4@@@3@@@2@@@1@@@5
1@@@2@@@4@@@3@@@6
3@@@2@@@4@@@1@@@6'
[ "$(ds:agg $tmp '$3+$2')" = "$agg_expected" ] || ds:fail 'agg failed R specific agg base case'
agg_expected='one@@@two@@@three@@@four
1@@@2@@@3@@@4
4@@@3@@@2@@@1
1@@@2@@@4@@@3
3@@@2@@@4@@@1
6@@@7@@@9@@@8'
[ "$(ds:agg $tmp 0 '$2+$3+$4')" = "$agg_expected" ] || ds:fail 'agg failed C specific agg base case'

agg_expected='one@@@two@@@three@@@four@@@*|2..4
1@@@2@@@3@@@4@@@24
4@@@3@@@2@@@1@@@6
1@@@2@@@4@@@3@@@24
3@@@2@@@4@@@1@@@8'
agg_actual="$(echo -e "one,two,three,four\n1,2,3,4\n4,3,2,1\n1,2,4,3\n3,2,4,1" | ds:agg '*|2..4')"
[ "$agg_actual" = "$agg_expected" ] || ds:fail 'agg failed R specific range agg base case'

# add base specific range case for c aggs here

agg_expected='one@@@two@@@three@@@four@@@+|all
1@@@2@@@3@@@4@@@10
4@@@3@@@2@@@1@@@10
1@@@2@@@4@@@3@@@10
3@@@2@@@4@@@1@@@10'
agg_actual="$(echo -e "one:two:three:four\n1:2:3:4\n4:3:2:1\n1:2:4:3\n3:2:4:1" | ds:agg '+|all')"
[ "$agg_actual" = "$agg_expected" ] || ds:fail 'agg failed R all agg base case'
agg_expected='one@@@two@@@three@@@four
1@@@2@@@3@@@4
4@@@3@@@2@@@1
1@@@2@@@4@@@3
3@@@2@@@4@@@1
9@@@9@@@13@@@9'
agg_actual="$(echo -e "one;two;three;four\n1;2;3;4\n4;3;2;1\n1;2;4;3\n3;2;4;1" | ds:agg 0 '+|all')"
[ "$agg_actual" = "$agg_expected" ] || ds:fail 'agg failed C all agg base case'

agg_expected='one@@@two@@@three@@@four@@@+|all
1@@@2@@@3@@@4@@@10
4@@@3@@@2@@@1@@@10
1@@@2@@@4@@@3@@@10
3@@@2@@@4@@@1@@@10
9@@@9@@@13@@@9@@@40'
[ "$(ds:agg $tmp '+|all' '+|all')" = "$agg_expected" ] || ds:fail 'agg failed R+C all agg base case'
agg_expected='@@@one@@@two@@@three@@@four@@@+|all
@@@1@@@2@@@3@@@4@@@10
@@@4@@@3@@@2@@@1@@@10
@@@1@@@2@@@4@@@3@@@10
@@@3@@@2@@@4@@@1@@@10
+|all@@@9@@@9@@@13@@@9@@@40'
[ "$(ds:agg $tmp '+|all' '+|all' -v header=1)" = "$agg_expected" ] || ds:fail 'agg failed R+C all agg header case'

agg_expected='@@@one@@@two@@@three@@@four@@@+|all@@@*|2..4@@@/|all
@@@1@@@2@@@3@@@4@@@10@@@24@@@0.0416667
@@@4@@@3@@@2@@@1@@@10@@@6@@@0.666667
@@@1@@@2@@@4@@@3@@@10@@@24@@@0.0416667
@@@3@@@2@@@4@@@1@@@10@@@8@@@0.375
$2/$3@@@0.25@@@0.666667@@@1.5@@@4@@@1@@@4@@@0.0625
+|all@@@9@@@9@@@13@@@9@@@40@@@62@@@1.125'
[ "$(ds:agg $tmp '+|all,*|2..4,/|all' '$2/$3,+|all' -v header=1)" = "$agg_expected" ] || ds:fail 'agg failed C+R multiple aggs header case'

echo -e "a 1 -2 3 4\nb 0 -3 4 1\nc 3 6 2.5 4" > $tmp
agg_expected='a@@@1@@@-2@@@3@@@4@@@6
b@@@0@@@-3@@@4@@@1@@@2
c@@@3@@@6@@@2.5@@@4@@@15.5
+|all@@@4@@@1@@@9.5@@@9@@@23.5'
[ "$(ds:agg $tmp)" = "$agg_expected" ] || ds:fail 'agg failed readme case'
agg_expected='a@@@1@@@-2@@@3@@@4@@@-24@@@-6
b@@@0@@@-3@@@4@@@1@@@0@@@-12
c@@@3@@@6@@@2.5@@@4@@@180@@@15
+|all@@@4@@@1@@@9.5@@@9@@@156@@@-3
*|all@@@0@@@36@@@30@@@16@@@0@@@1080'
[ "$(ds:agg $tmp '*|all,$4*$3' '+|all,*|all')" = "$agg_expected" ] || ds:fail 'agg failed readme negatives multiples case'
agg_expected='a@@@1@@@-2@@@3@@@4@@@-24@@@-6@@@~b
b@@@0@@@-3@@@4@@@1@@@0@@@-12@@@1
c@@@3@@@6@@@2.5@@@4@@@180@@@15@@@0
+|all@@@4@@@1@@@9.5@@@9@@@156@@@-3@@@1
*|all@@@0@@@36@@@30@@@16@@@0@@@1080@@@0'
[ "$(ds:agg $tmp '*|all,$4*$3,~b' '+|all,*|all')" = "$agg_expected" ] || ds:fail 'agg failed readme kitchen sink case'

echo -e "one two three four\nakk 2 3 4\nblah 3 2 1\nyuge 2 4 3\ngoal 2 4 1" > $tmp
agg_expected='one@@@two@@@three@@@four@@@/@@@+@@@*@@@-
akk@@@2@@@3@@@4@@@0.166667@@@9@@@24@@@-9
blah@@@3@@@2@@@1@@@1.5@@@6@@@6@@@-6
yuge@@@2@@@4@@@3@@@0.166667@@@9@@@24@@@-9
goal@@@2@@@4@@@1@@@0.5@@@7@@@8@@@-7
-@@@-9@@@-13@@@-9@@@-2.33334@@@-31@@@-62@@@31
/@@@0.166667@@@0.09375@@@1.33333@@@1.33333@@@0.0238096@@@0.0208334@@@0.0238096
*@@@24@@@96@@@12@@@0.0208334@@@3402@@@27648@@@3402
+@@@9@@@13@@@9@@@2.33334@@@31@@@62@@@-31'
[ "$(ds:agg $tmp '/,+,*,-' '\-,/,*,+')" = "$agg_expected" ] || ds:fail 'agg failed all shortforms case'
agg_expected='one@@@two@@@three@@@four@@@three+two@@@-
akk@@@2@@@3@@@4@@@5@@@-9
blah@@@3@@@2@@@1@@@5@@@-6
yuge@@@2@@@4@@@3@@@6@@@-9
goal@@@2@@@4@@@1@@@6@@@-7
akk-goal@@@0@@@-1@@@3@@@-1@@@-2
blah/yuge@@@1.5@@@0.5@@@0.333333@@@0.833333@@@0.666667'
[ "$(ds:agg $tmp 'three+two,-' 'akk-goal,blah/yuge')" ] || ds:fail 'agg failed keysearch cases'

# ASSORTED COMMANDS TESTS

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

idx_actual="$(echo -e "5\n2\n4\n3\n1" | ds:idx)"
idx_expected='1 5
2 2
3 4
4 3
5 1'
[ "$idx_actual" = "$idx_expected" ] || ds:fail 'idx failed'

[ "$(ds:filename_str $jnf1 '-1')" = 'tests/data/infer_join_fields_test1-1.csv' ] \
  || ds:fail 'filename_str command failed'

[ "$(ds:iter "a" 3)" = 'a a a' ] || ds:fail 'iter failed'

echo $(ds:root) 1> $q || ds:fail 'root command failed'

[ "$(printf "%s\n" a b c d | ds:rev | tr -d '\n')" = "dcba" ] || ds:fail 'rev failed'

echo > $tmp; for i in $(seq 1 10); do echo test$i >> $tmp; done; ds:sedi $tmp 'test'
[[ ! "$(head -n1 $tmp)" =~ "test" ]] || ds:fail 'sedi command failed'

mini_output="1;2;3;4;5;6;7;8;9;10"
[ "$(cat $tmp | ds:mini)" = "$mini_output" ]                             || ds:fail 'mini failed'

[ "$(ds:unicode "cats😼😻")" = '\U63\U61\U74\U73\U1F63C\U1F63B' ]        || ds:fail 'unicode command failed base case'
[ "$(echo "cats😼😻" | ds:unicode)" = '\U63\U61\U74\U73\U1F63C\U1F63B' ] || ds:fail 'unicode command failed pipe case'

todo_expected='tests/commands_tests.sh:# TODO: Negative tests, Git tests'
[ "$(ds:todo tests/commands_tests.sh | head -n1)" = "$todo_expected" ] || ds:fail 'todo command failed'

[ "$(ds:substr "TEST" "T" "ST")" = "E" ]        || ds:fail 'substr failed base case'
[ "$(echo "TEST" | ds:substr "T" "ST")" = "E" ] || ds:fail 'substr failed pipee case'
substr_actual="$(ds:substr "1/2/3/4" "[0-9]+\\/[0-9]+\\/[0-9]+\\/")"
[ "4" = "$substr_actual" ]                      || ds:fail 'substr failed extended regex case'

if [[ $shell =~ 'bash' ]]; then
  fsrc_expected='support/utils.sh'
  [[ "$(ds:fsrc ds:noawkfs | head -n1)" =~ "$fsrc_expected" ]] || ds:fail 'fsrc failed'
fi

help_deps='ds:stag
ds:fail
ds:fit
ds:reo
ds:nset
ds:commands
ds:jn'
[[ "$(ds:deps ds:help)" = "$help_deps" ]]                   || ds:fail 'deps failed'
[ "$(ds:websel https://www.google.com title)" = Google ]    || ds:fail 'websel failed or internet is out'


# INTEGRATION TESTS

expected='@@@PIVOT@@@7@@@21@@@14@@@28@@@+|all@@@
@@@459 PC  BURGLARY RESIDENCE@@@12@@@7@@@10@@@13@@@356@@@
@@@TOWED/STORED VEHICLE@@@9@@@8@@@15@@@9@@@434@@@
@@@459 PC  BURGLARY VEHICLE@@@23@@@22@@@15@@@15@@@462@@@
@@@TOWED/STORED VEH-14602.6@@@11@@@8@@@9@@@11@@@463@@@
@@@10851(A)VC TAKE VEH W/O OWNER@@@21@@@24@@@15@@@23@@@653@@@
+|all@@@@@@249@@@234@@@221@@@279@@@7585@@@'
actual="$(ds:sbsp tests/data/testcrimedata.csv '\/' "" -v apply_to_fields=1 \
  | ds:reo a '2,NF>3' \
  | ds:pvt 6 1 4 c \
  | ds:agg '+|all' '+|all' -v header=1 \
  | ds:sortm NF n \
  | ds:reo '2~PIVOT, >300' '1,2[PIVOT%7,2[PIVOT~all' -v uniq=1 | cat)"
[ "$actual" = "$expected" ] || ds:fail 'integration case 1 failed'

expected='emoji  Generating_code_base10  init_awk_len  len_simple_extract  len_remaining
❎     10062                              3                   1              2
🚧     unknown                            4                   1              3
❓     10067                              3                   1              2
❔     10068                              3                   1              2'
actual="$(cat $emoji | ds:reo '1, NR%2 && NR>80 && NR<90' '[emoji,others' | ds:fit -v color=never)"
[ "$actual" = "$expected" ] || ds:fail 'integration readme emoji case failed'

expected='    one      two     three     four         +         *
 1.0000   2.0000    3.0000   4.0000   10.0000   24.0000
 4.0000   3.0000    2.0000   1.0000   10.0000   24.0000
 1.0000   2.0000    4.0000   3.0000   10.0000   24.0000
 3.0000   2.0000    4.0000   1.0000   10.0000   24.0000
-9.0000  -9.0000  -13.0000  -9.0000  -40.0000  -96.0000
 0.0833   0.1667    0.0938   1.3333    0.0100    0.0017'
actual="$(echo -e "one two three four\n1 2 3 4\n4 3 2 1\n1 2 4 3\n3 2 4 1" | ds:agg '+,*' '\-,/' | ds:fit -v d=4 -v color=never)"
[ "$actual" = "$expected" ] || ds:fail 'integration agg fit negative decimals case failed'

# CLEANUP

rm $tmp
