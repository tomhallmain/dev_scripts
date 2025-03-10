#!/bin/bash

source commands.sh
tmp=/tmp/ds_commands_tests
q=/dev/null

# BASICS TESTS

echo -n "Running basic commands tests..."


[[ $(ds:sh | grep -c "") = 1 && $(ds:sh) =~ sh ]]    || ds:fail 'sh command failed'


ch='@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE'
ds:commands "" "" 0 > $q
cmp --silent support/commands tests/data/commands && grep -q "$ch" 'support/commands' || ds:fail 'commands listing failed'


ds:file_check 'assets/gcv_ex.png' f t &> $q        || ds:fail 'file check disallowed binary files in allowed case'


expected='COMMAND@@@DESCRIPTION@@@USAGE@@@
ds:help@@@Print help for a given command@@@ds:help ds_command@@@'
[ "$(ds:help 'ds:help')" = "$expected" ]           || ds:fail 'help command failed'
ds:nset 'ds:nset' 1> $q                            || ds:fail 'nset command failed'
ds:searchn 'ds:searchn' 1> $q                      || ds:fail 'searchn failed on func search'
ds:searchn 'test_var' 1> $q                        || ds:fail 'searchn failed on var search'
[ "$(ds:ntype 'ds:ntype')" = 'FUNC' ]              || ds:fail 'ntype command failed'


# zsh trace output in subshell lists a file descriptor
if [[ $shell =~ 'zsh' ]]; then
    ds:trace 'echo test' &>$tmp
    grep -e "+ds:trace:8> eval 'echo test'" -e "+(eval):1> echo test" $tmp &>$q || ds:fail 'trace command failed'
elif [[ $shell =~ 'bash' ]]; then
    expected="++++ echo test\ntest"
    [ "$(ds:trace 'echo test' 2>$q)" = "$(echo -e "$expected")" ] || ds:fail 'trace command failed'
fi


[ "$(echo 1 2 3 | ds:join_by ', ')" = "1, 2, 3" ] || ds:fail 'join_by failed on pipe case'
[ "$(ds:join_by ', ' 1 2 3)" = "1, 2, 3" ]        || ds:fail 'join_by failed on pipe case'


[ "$(ds:embrace 'test')" = '{test}' ]             || ds:fail 'embrace failed'
[ "$(echo 'test' | ds:embrace)" = '{test}' ]      || ds:fail 'embrace failed pipe case'


path_el_arr=( tests/data/ infer_join_fields_test1 '.csv' )
[[ $shell =~ 'zsh' ]] && let count=1 || let count=0
for el in $(IFS=$'\t' ds:path_elements tests/data/infer_join_fields_test1.csv); do
    test_el=${path_el_arr[count]}
    [ $el = $test_el ] || ds:fail "path_elements failed on $el <> $test_el"
    let count+=1
done


actual="$(echo -e "5\n2\n4\n3\n1" | ds:index)"
expected='1 5
2 2
3 4
4 3
5 1'
[ "$actual" = "$expected" ] || ds:fail 'idx failed'


[ "$(ds:filename_str tests/data/infer_join_fields_test1.csv '-1' "" t)" = 'tests/data/infer_join_fields_test1-1.csv' ] \
  || ds:fail 'filename_str command failed'


[ "$(ds:iter "a" 3)" = 'aaa' ] || ds:fail 'iter failed'


[ "$(printf "%s\n" a b c d | ds:rev | tr -d '\n')" = "dcba" ] || ds:fail 'rev failed'


echo > $tmp; for i in $(seq 1 10); do echo test$i >> $tmp; done; ds:sedi $tmp 'test'
[[ ! "$(head -n1 $tmp)" =~ "test" ]] || ds:fail 'sedi command failed'


expected='1;2;3;4;5;6;7;8;9;10'
[ "$(cat $tmp | ds:mini)" = "$expected" ]                               || ds:fail 'mini failed'


[ "$(ds:unicode "cats😼😻")" = '\U63\U61\U74\U73\U1F63C\U1F63B' ]        || ds:fail 'unicode command failed base case'
[ "$(echo "cats😼😻" | ds:unicode)" = '\U63\U61\U74\U73\U1F63C\U1F63B' ] || ds:fail 'unicode command failed pipe case'
[ "$(ds:unicode "cats😼😻" hex)" = '%63%61%74%73%F09F98BC%F09F98BB' ]    || ds:fail 'unicode command failed hex case'


if [[ $shell =~ 'zsh' ]]; then
    expected="33 !;34 \";35 #;36 $;37 %;38 &;39 ';40 (;41 );42 *;43 +;44 ,;45 -;46 .;47 /;48 0;49 1;50 2;51 3;52 4;53 5;54 6;55 7;56 8;57 9;58 :;59 ;;60 <;61 =;62 >;63 ?;64 @;65 A;66 B;67 C;68 D;69 E;70 F;71 G;72 H;73 I;74 J;75 K;76 L;77 M;78 N;79 O;80 P;81 Q;82 R;83 S;84 T;85 U;86 V;87 W;88 X;89 Y;90 Z;91 [;92 \;93 ];94 ^;95 _;96 \`;97 a;98 b;99 c;100 d;101 e;102 f;103 g;104 h;105 i;106 j;107 k;108 l;109 m;110 n;111 o;112 p;113 q;114 r;115 s;116 t;117 u;118 v;119 w;120 x;121 y;122 z;123 {;124 |;125 };126 ~;"
    [ "$(ds:ascii 33 126 | awk '{_=_$0";"}END{print _}')" = "$expected" ]    || ds:fail 'ascii failed base case'
    expected="200 È;201 É;202 Ê;203 Ë;204 Ì;205 Í;206 Î;207 Ï;208 Ð;209 Ñ;210 Ò;211 Ó;212 Ô;213 Õ;214 Ö;215 ×;216 Ø;217 Ù;218 Ú;219 Û;220 Ü;221 Ý;222 Þ;223 ß;224 à;225 á;226 â;227 ã;228 ä;229 å;230 æ;231 ç;232 è;233 é;234 ê;235 ë;236 ì;237 í;238 î;239 ï;240 ð;241 ñ;242 ò;243 ó;244 ô;245 õ;246 ö;247 ÷;248 ø;249 ù;250 ú;"
    [ "$(ds:ascii 200 250 | awk '{_=_$0";"}END{print _}')" = "$expected" ]   || ds:fail 'ascii failed accent case'
fi


expected='rgb(110,76,139)'
actual="$(ds:color '#6E4C8B')"
[ "$actual" = "$expected" ] || ds:fail 'color failed hex to rgb case'
expected='rgb(110,76,139)'
actual="$(echo 6E4C8B | ds:color)"
[ "$actual" = "$expected" ] || ds:fail 'color failed hex to rgb case'
expected='#6E4C8B'
actual="$(ds:color 'rgb(110,76,139)')"
[ "$actual" = "$expected" ] || ds:fail 'color failed rgb to hex case 1'
expected='#6E4C8B'
actual="$(ds:color 110 76 139)"
[ "$actual" = "$expected" ] || ds:fail 'color failed rgb to hex case 2'


expected='tests/commands_tests.sh:## TODO: Git tests'
[ "$(ds:todo tests/commands_tests.sh | head -n1)" = "$expected" ]   || ds:fail 'todo command failed'


[ "$(ds:substr TEST T ST)" = 'E' ]                                  || ds:fail 'substr failed base case'
[ "$(echo TEST | ds:substr T ST)" = 'E' ]                           || ds:fail 'substr failed pipe case'
actual="$(ds:substr '1/2/3/4' "[0-9]+\\/[0-9]+\\/[0-9]+\\/")"
[ "$(ds:substr '1/2/3/4' "[0-9]+\\/[0-9]+\\/[0-9]+\\/")" = 4 ]      || ds:fail 'substr failed extended regex case'


[ "$(ds:websel https://www.google.com title)" = Google ]            || ds:fail 'websel failed or internet is out'


echo -e "${GREEN}PASS${NC}"
