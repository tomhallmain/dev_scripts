#!/bin/bash
# This test script should produce no output if test run is successful

cd "${BASH_SOURCE%/*}/.."
source .commands.sh

test_var=1

nameset 'nameset' 1> /dev/null || fail 'nameset command failed'
searchnames 'searchnames' 1> /dev/null || fail 'searchnames failed on func search'
searchnames 'test_var' 1> /dev/null || fail 'searchnames failed on var search'
[ "$(nametype 'nametype')" = 'FUNC' ] || fail 'nametype commmand failed'

[ $(which_sh) = 'bash' ] || fail 'which_sh command failed'


[ $(git_recent_all | awk '{print $3}' | wc -l) -gt 2 ] \
  || echo 'git recent all failed, possibly due to no git dirs in home'


ajoinf1="tests/infer_join_fields_test1.csv"
ajoinf2="tests/infer_join_fields_test2.csv"

[ "$(inferfs $ajoinf1)" = ',' ] || 'inferfs failed extension case'
[ "$(inferfs tests/seps_test.file)" = '&%#' ] || 'inferfs failed custom separator case'

[ $(ajoin -v k=1 -v ind=1 "$ajoinf1" "$ajoinf2" | wc -l) -gt 15 ] \
  || fail 'ajoin failed pipe_check, or pipe_check failed'

[ $(print_comps $ajoinf1{,} | wc -l) -eq 7 ] || 'print_comps failed no complement case'
[ $(print_comps -v k1=2 -v k2=3,4 $ajoinf1 $ajoinf2 | wc -l) -eq 197 ] \
  || 'print_comps failed complments case'

no_matches='
NO MATCHES FOUND'
[ "$(print_matches -v k1=2 -v k2=2 $ajoinf1 $ajoinf2)" = "$no_matches" ] \
  || 'print_matches failed no matches case'
[ $(print_matches -v k=1 $ajoinf1 $ajoinf2 | wc -l) = 171 ] \
  || 'print_matches failed no matches case'

sort_input='d c a b f
f e c b a
f e d c b
e d c b a'
sort_output='d c a b f
f e d c b
f e c b a
e d c b a'
[ "$(echo "$sort_input" | infsortm -v k=5,1 -v order=d)" = "$sort_output" ]

[ "$(echo 1 2 3 | join_by ', ')" = "1, 2, 3" ] || fail 'join_by command failed on pipe case'
[ "$(join_by ', ' 1 2 3)" = "1, 2, 3" ] || fail 'join_by command failed on pipe case'

[ "$(embrace 'test')" = '{test}' ] || fail 'embrace command failed'

path_el_arr=( tests/ infer_join_fields_test1 '.csv' )
let count=0
for el in $(path_elements $ajoinf1); do
  test_el=${path_el_arr[count]}
  [ $el = $test_el ] || fail "path_elements command failed on $test_el"
  let count+=1
done

[ "$(filename_str $ajoinf1 '-1')" = 'tests/infer_join_fields_test1-1.csv' ] \
  || fail 'filename_str command failed'

[ "$(iter_str "a" 3)" = 'a a a' ] || fail 'iter_str command failed'

echo $(root_vol) 1> /dev/null || fail 'root_vol command failed'

[ "$(printf "%s\n" a b c d | reverse | tr -d '\n')" = "dcba" ] || fail 'reverse command failed'


