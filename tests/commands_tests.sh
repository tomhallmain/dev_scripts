#!/bin/bash
# This test script should produce no output if test run is successful
# TODO: Negative tests

test_var=1
tmp=/tmp/commands_tests
q=/dev/null
shell=$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')

if [[ $shell =~ 'bash' ]]; then
  bsh=0
  cd "${BASH_SOURCE%/*}/.."
  source .commands.sh
  $(ds:fail 'testfail' &> $tmp)
  testfail=$(cat $tmp)
  [[ $testfail =~ '_err_: testfail' ]] || echo 'fail command failed in bash case'
elif [[ $shell =~ 'zsh' ]]; then
  cd "$(dirname $0)/.."
  source .commands.sh
  $(ds:fail 'testfail' &> $tmp)
  testfail=$(cat $tmp)
  [[ $testfail =~ '_err_: Operation intentionally failed' ]] || echo 'fail command failed in zsh case'
elif [[ $shell =~ 'ksh' ]]; then
  echo lets see what happens here..
else
  echo 'unhandled shell detected - only zsh/bash supported at this time - exiting test script'
  exit 1
fi

[ $(ds:sh | wc -l) = 1 ] || ds:fail 'sh command failed'


ds:nset 'ds:nset' 1> $q || ds:fail 'nset command failed'
ds:searchn 'ds:searchn' 1> $q || ds:fail 'searchn failed on func search'
ds:searchn 'test_var' 1> $q || ds:fail 'searchn failed on var search'
[ "$(ds:ntype 'ds:ntype')" = 'FUNC' ] || ds:fail 'ntype commmand failed'


[ $(ds:git_recent_all | awk '{print $3}' | wc -l) -gt 2 ] \
  || echo 'git recent all failed, possibly due to no git dirs in home'


jnf1="tests/infer_join_fields_test1.csv"
jnf2="tests/infer_join_fields_test2.csv"

[ "$(ds:inferfs $jnf1)" = ',' ] || ds:fail 'inferfs failed extension case'
[ "$(ds:inferfs tests/seps_test.file)" = '\&\%\#' ] || ds:fail 'inferfs failed custom separator case'

[ $(ds:jn "$jnf1" "$jnf2" 1 | wc -l) -gt 15 ] || ds:fail 'ds:jn failed one-arg shell case'
[ $(ds:jn "$jnf1" "$jnf2" -v ind=1 | wc -l) -gt 15 ] || ds:fail 'ds:jn failed awkarg nonkey case'
[ $(ds:jn "$jnf1" "$jnf2" -v k=1 | wc -l) -gt 15 ] || ds:fail 'ds:jn failed awkarg key case'

[ $(ds:print_comps $jnf1{,} | wc -l) -eq 7 ] || 'print_comps failed no complement case'
[ $(ds:print_comps -v k1=2 -v k2=3,4 $jnf1 $jnf2 | wc -l) -eq 197 ] \
  || 'print_comps failed complments case'

no_matches='
NO MATCHES FOUND'
[ "$(ds:print_matches -v k1=2 -v k2=2 $jnf1 $jnf2)" = "$no_matches" ] \
  || 'print_matches failed no matches case'
[ $(ds:print_matches -v k=1 $jnf1 $jnf2 | wc -l) = 171 ] \
  || 'print_matches failed no matches case'

sort_input='d c a b f
f e c b a
f e d c b
e d c b a'
sort_output='d c a b f
f e d c b
f e c b a
e d c b a'
[ "$(echo "$sort_input" | ds:infsortm -v k=5,1 -v order=d)" = "$sort_output" ] || ds:fail 'infsortm command failed'

reo_input='d c a b f
f e c b a
f e d c b
e d c b a'
reo_output='a c d e b
f a c d b'
[ "$(echo "$reo_input" | ds:reo 4,1 5,3..1,4)" = "$reo_output" ] || ds:fail 'reo command failed'

reo_input=$(for i in $(seq -16 16); do
    printf "%s " $i; printf "%s " $(echo "-1*$i" | bc)
    if [ $(echo "$i%5" | bc) -eq 0 ]; then echo test; else echo nah; fi
  done)
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
[ "$(echo "$reo_input" | ds:reo "2<0,3~test" "31!=14")" = "$reo_output" ] || ds:fail 'reo command failed extended cases'

[ "$(echo 1 2 3 | ds:join_by ', ')" = "1, 2, 3" ] || ds:fail 'join_by command failed on pipe case'
[ "$(ds:join_by ', ' 1 2 3)" = "1, 2, 3" ] || ds:fail 'join_by command failed on pipe case'

[ "$(ds:embrace 'test')" = '{test}' ] || ds:fail 'embrace command failed'

path_el_arr=( tests/ infer_join_fields_test1 '.csv' )
[ -z $bsh ] && let count=1 || let count=0
for el in $(IFS='\t' ds:path_elements $jnf1); do
  test_el=${path_el_arr[count]}
  [ $el = $test_el ] || ds:fail "path_elements command failed on $test_el"
  let count+=1
done

[ "$(ds:filename_str $jnf1 '-1')" = 'tests/infer_join_fields_test1-1.csv' ] \
  || ds:fail 'filename_str command failed'

[ "$(ds:iter_str "a" 3)" = 'a a a' ] || ds:fail 'iter_str command failed'

echo $(ds:root) 1> $q || ds:fail 'root_vol command failed'

[ "$(printf "%s\n" a b c d | ds:rev | tr -d '\n')" = "dcba" ] || ds:fail 'rev command failed'

[ $bsh ] && cmds="tests/commands_output_bash" || cmds="tests/commands_output_zsh"
ds:commands > $tmp
cmp --silent $cmds $tmp || ds:fail 'commands listing failed'

rm $tmp

