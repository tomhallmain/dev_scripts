#!/bin/bash

source commands.sh

# AGG TESTS

echo -n "Running aggregation tests..."

# Create test data files
echo -e "one two three four\n1 2 3 4\n4 3 2 1\n1 2 4 3\n3 2 4 1" > $tmp

# Create statistical test data
echo -e "metric value1 value2 value3\n1 2 2 3\n2 2 3 3\n3 3 3 4\n4 4 4 4\n5 5 5 5" > ${tmp}_stats

# Test existing functionality
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
[ "$(ds:agg tests/data/number_comma_format '+' '$1+$2+$3+$4+$5+$6+$7+$10-$11-$12-$13')" = "$expected" ] || ds:fail 'agg failed number comma format case'

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

# New Statistical Function Tests

# Median Tests
expected='metric value1 value2 value3 med|all
1 2 2 3 2
2 2 3 3 3
3 3 3 4 3
4 4 4 4 4
5 5 5 5 5'
[ "$(ds:agg ${tmp}_stats 'med|all')" = "$expected" ] || ds:fail 'agg failed R median all case'

expected='metric value1 value2 value3
1 2 2 3
2 2 3 3
3 3 3 4
4 4 4 4
5 5 5 5
3 3 3 4'
[ "$(ds:agg ${tmp}_stats 0 'med|all')" = "$expected" ] || ds:fail 'agg failed C median all case'

# Mode Tests
echo -e "category value1 value2 value3\nA 1 1 2\nB 1 1 1\nC 2 2 1\nD 3 2 2" > ${tmp}_mode
expected='category value1 value2 value3 mode|all
A 1 1 2 1
B 1 1 1 1
C 2 2 1 2
D 3 2 2 2'
[ "$(ds:agg ${tmp}_mode 'mode|all')" = "$expected" ] || ds:fail 'agg failed R mode all case'

# Quartile Tests
expected='metric value1 value2 value3 q1|all q2|all q3|all
1 2 2 3 2 2 3
2 2 3 3 2 3 3
3 3 3 4 3 3 4
4 4 4 4 4 4 4
5 5 5 5 5 5 5'
[ "$(ds:agg ${tmp}_stats 'q1|all,q2|all,q3|all')" = "$expected" ] || ds:fail 'agg failed R quartiles case'

# Standard Deviation Tests
echo -e "group val1 val2 val3\nA 10 10 10\nB 10 20 30\nC 0 50 100" > ${tmp}_stddev
expected='group val1 val2 val3 sd|all
A 10 10 10 0
B 10 20 30 10
C 0 50 100 50'
[ "$(ds:agg ${tmp}_stddev 'sd|all')" = "$expected" ] || ds:fail 'agg failed R standard deviation case'

# Combined Statistical Operations
expected='group val1 val2 val3 med|all sd|all mean|all
A 10 10 10 10 0 10
B 10 20 30 20 10 20
C 0 50 100 50 50 50'
[ "$(ds:agg ${tmp}_stddev 'med|all,sd|all,mean|all')" = "$expected" ] || ds:fail 'agg failed R combined stats case'

# Edge Cases
echo -e "type value\nA 1\nA 1\nA 1\nB \nB 2\nB 2" > ${tmp}_edge
expected='type value mode|all med|all sd|all
A 1 1 1 0
B 2 2 2 0'
[ "$(ds:agg ${tmp}_edge 'mode|all,med|all,sd|all')" = "$expected" ] || ds:fail 'agg failed edge case handling'

# Search with Statistical Operations
expected='type value med|~A sd|~B
A 1 1 0
A 1 1 0
A 1 1 0
B  0 0
B 2 0 0
B 2 0 0'
[ "$(ds:agg ${tmp}_edge 'med|~A,sd|~B')" = "$expected" ] || ds:fail 'agg failed search with stats case'

# Cross Aggregation with Statistics
echo -e "region product sales\nNA Widget 100\nNA Gadget 200\nEU Widget 150\nEU Gadget 250\nASIA Widget 120\nASIA Gadget 220" > ${tmp}_cross
expected='Cross Aggregation: med|3 grouped by field 1
NA 150
EU 200
ASIA 170'
[ "$(ds:agg ${tmp}_cross 'med|$3|$1')" = "$expected" ] || ds:fail 'agg failed cross aggregation with median'

# Conditional Aggregation with Statistics
echo -e "dept salary bonus\nIT 1000 100\nIT 2000 200\nHR 1500 150\nHR 2500 250" > ${tmp}_cond
expected='dept salary bonus med|$2>1500
IT 1000 100 2000
IT 2000 200 2000
HR 1500 150 2500
HR 2500 250 2500'
[ "$(ds:agg ${tmp}_cond 'med|$2>1500')" = "$expected" ] || ds:fail 'agg failed conditional aggregation with median'

echo -e "${GREEN}PASS${NC}"
