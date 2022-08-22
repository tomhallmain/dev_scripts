#!/bin/bash

source commands.sh

jnd1="tests/data/infer_jf_test_joined.csv"
jnd2="tests/data/infer_jf_joined_fit"
jnd3="tests/data/infer_jf_joined_fit_dz"
jnd4="tests/data/infer_jf_joined_fit_sn"
jnd5="tests/data/infer_jf_joined_fit_d2"

# FIT TESTS

echo -n "Running fit tests..."

fit_var_present="$(echo -e "t 1\nte 2\ntes 3\ntest 4" | ds:fit -v color=never | awk '{cl=length($0);if(pl && pl!=cl) {print 1;exit};pl=cl}')"
[ "$fit_var_present" = 1 ]                          && ds:fail 'fit failed pipe case'

expected='Desert City'
actual="$(ds:fit tests/data/addresses.csv | ds:reo 7 4 '-F {2,}')"
[ "$expected" = "$actual" ]                         || ds:fail 'fit failed base case'

expected='Company Name                            Employee Markme       Description
INDIAN HERITAGE ,ART & CULTURE          MADHUKAR              ACCESS PUBLISHING INDIA PVT.LTD
ETHICS, INTEGRITY & APTITUDE ( 3RD/E)   P N ROY ,G SUBBA RAO  ACCESS PUBLISHING INDIA PVT.LTD
PHYSICAL, HUMAN AND ECONOMIC GEOGRAPHY  D R KHULLAR           ACCESS PUBLISHING INDIA PVT.LTD'
actual="$(ds:reo tests/data/Sample100.csv 1,35,37,42 2..4 | ds:fit -F, -v color=never)"
[ "$(echo -e "$expected")" = "$actual" ]            || ds:fail 'fit failed quoted field case'

expected='-rw-r--r--  1  tomhall   4330  Oct  12  11:55  emoji
-rw-r--r--  1  tomhall      0  Oct   3  17:30  file with space, and: commas & colons \ slashes
-rw-r--r--  1  tomhall  12003  Oct   3  17:30  infer_jf_test_joined.csv
-rw-r--r--  1  tomhall   5245  Oct   3  17:30  infer_join_fields_test1.csv
-rw-r--r--  1  tomhall   6043  Oct   3  17:30  infer_join_fields_test2.csv'
[ "$(ds:fit tests/data/ls_sq -v color=never)" = "$expected" ] || ds:fail 'fit failed ls sq case'

ds:fit $jnd1 -v bufferchar="|" -v no_zero_blank=1 > $tmp
cmp --silent $jnd2 $tmp || ds:fail 'fit failed bufferchar/decimal case'
ds:fit $jnd1 -v bufferchar="|" -v d=z -v no_zero_blank=1 > $tmp
cmp --silent $jnd3 $tmp || ds:fail 'fit failed const decimal case'
ds:fit $jnd1 -v bufferchar="|" -v d=-2 -v no_zero_blank=1 > $tmp
cmp --silent $jnd4 $tmp || ds:fail 'fit failed scientific notation / float output case'
ds:fit $jnd1 -v bufferchar="|" -v d=2 -v no_zero_blank=1 > $tmp
cmp --silent $jnd5 $tmp || ds:fail 'fit failed fixed 2-place decimal case'

## TODO add dec_off check

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
[ "$(ds:fit tests/data/taxables.csv -v color=never | head)" = "$expected" ] || ds:fail 'fit failed spaced quoted field case'

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
actual="$(ds:fit tests/data/floats_test -v color=never -v no_zero_blank=1 | sed -E 's/[[:space:]]+$//g')"
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
actual="$(ds:fit tests/data/number_comma_format -v color=never)"
[ "$expected" = "$actual" ] || ds:fail 'fit failed number comma format case'

if ds:awksafe; then
    ds:fit tests/data/emoji > $tmp
    cmp --silent tests/data/emojifit $tmp   || ds:fail 'fit failed emoji case'
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
    actual="$(ds:fit tests/data/jn_repeats_jnd1 -v gridlines=1 -v d=2 -v color=never | sed -E 's/[[:space:]]+$//g')"
    [ "$expected" = "$actual" ] || ds:fail 'fit failed gridlines decimals multibyte chars case'

    ds:fit tests/data/emoji -v gridlines=1 -v color=never > $tmp
    cmp $tmp tests/data/emoji_fit_gridlines || ds:fail 'fit failed gridlines emoji case'
else
    echo "Skipping multibyte chars cases - AWK configuration is not multibyte-character-safe"
fi

ds:fit tests/data/commands -v gridlines=1 -v color=never -v tty_size=120 | sed -E 's/[[:space:]]+$//g' > $tmp
cmp $tmp tests/data/commands_shrink_fit_gridlines || ds:fail 'fit failed gridlines shrink field case'

echo -e "${GREEN}PASS${NC}"
