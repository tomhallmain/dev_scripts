#!/bin/bash

source commands.sh

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

if ds:awksafe; then
    expected='emoji  Generating_code_base10  init_awk_len  len_simple_extract  len_remaining
❎     10062                              3                   1              2
🚧     unknown                            4                   1              3
❓     10067                              3                   1              2
❔     10068                              3                   1              2'
    actual="$(cat tests/data/emoji | ds:reo '1, NR%2 && NR>80 && NR<90' '[emoji,others' | ds:fit -v color=never)"
    [ "$actual" = "$expected" ] || ds:fail 'integration readme emoji case failed'
else
    echo "Skipping emoji readme case - AWK configuration is not multibyte-character-safe"
fi


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
