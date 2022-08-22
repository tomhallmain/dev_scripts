#!/bin/bash

source commands.sh

# REORDER TESTS

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
expected='**@@@ds:diff_fields@@@ds:df@@@Get elementwise diff of two datasets@@@ds:df file [file*] [op=-] [exc_fields=0] [prefield=f] [awkargs]
@@@ds:path_elements@@@@@@Return dirname/filename/extension from filepath@@@read -r dirpath filename extension <<< "$(ds:path_elements file)"'
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

actual="$(ds:reo tests/data/seps_test_base ">100&&%7" "%7")"
expected='7&%#2
420&%#1'
[ "$actual" = "$expected" ] || ds:fail 'reo failed extended logic cases'

actual="$(ds:reo tests/data/seps_test_base '5[2!~2' | grep -h "^1")"
[ "$(ds:reo tests/data/seps_test_base '5[2!=2 && 5[2!=23' | grep -h "^1")" = "$actual" ] || ds:fail 'reo failed comparison case'

head -n5 tests/data/company_funding_data.csv > $tmp

expected='company,category,city,raisedAmt,raisedCurrency,round
Facebook,web,Palo Alto,300000000,USD,c
ZeniMax,web,Rockville,300000000,USD,a'
actual="$(ds:reo tests/data/company_funding_data.csv '1, >200000000' '[^c, [^r')"
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
