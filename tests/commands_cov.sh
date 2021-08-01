#!/bin/bash
#
# Stats about test coverage for dev_scripts repo

shell=$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')
if [[ $shell =~ 'bash' ]]; then cd "${BASH_SOURCE%/*}/.."
elif [[ $shell =~ 'zsh' ]]; then cd "$(dirname $0)/.."
else
    echo 'unhandled shell detected - only zsh/bash supported at this time'
    exit 1
fi
source commands.sh
tmp=$(ds:tmp 'ds_commands_cov')
tmp1=$(ds:tmp 'ds_commands_cov1')
tmpndata=$(ds:tmp 'ds_ndata')
deps=$(ds:tmp 'ds_commands_cov_deps')
command_funcs=$(grep -ho '[[:alnum:]_:]*()' "$DS_LOC/commands.sh" \
    | sed 's/^  function //' | sed 's/()//' | sort)
util_funcs=$(grep -ho '[[:alnum:]_:]*()' "$DS_SUPPORT/utils.sh" \
    | sed 's/^  function //' | sed 's/()//' | sort)
test_funcs=$(grep -Eho 'ds:[a-z_]+' tests/commands_tests.sh | sort)
test_funcs="$test_funcs\n$(grep -Eho 'ds:[a-z_]+' tests/commands_cov.sh | sort)"
test_funcs="$test_funcs\n$(grep -Eho 'ds:[a-z_]+' tests/commands_variants.sh | sort)"

awk 'FNR == 1 {f++}
      f == 1 { Funcs[$0]++ }
      f == 2 { Funcs[$0]++ }
      f == 3 { TestFuncs[$0]++ }
    END {
        len_funcs=length(Funcs)
        len_covered_funcs=length(TestFuncs)
        for (fnc in Funcs) {
            if (fnc in TestFuncs)
                print fnc, "Y", TestFuncs[fnc]
            else
                print fnc, "N", 0
        }
    }' \
    <(printf "%s\n" $command_funcs) \
    <(printf "%s\n" $util_funcs) \
    <(printf "%s\n" $test_funcs) \
    > $tmp

ds:ndata | awk '$1~"(FUNC|ALIAS)"{print $2}' | sort > $tmpndata

for fnc in $(ds:reo $tmp '3>0' 1); do
    ds:deps "$fnc" "ds:" "" 0 $tmpndata >> $deps; done

awk 'BEGIN { print "Command", "Covered", "UsageCount" }
    FNR == 1 {f++}
    f == 1 { DepFuncs[$2] = DepFuncs[$2] $1"," }
    f == 2 { Funcs[$1] = 1
              Covered[$1] = $2
              Usage[$1] = $3 }
    END {
        for (fnc in DepFuncs) {
            Covered[fnc] = "Y"
            split(DepFuncs[fnc], CallingFuncs, ",")
            for (f = 1; f < length(CallingFuncs); f++) {
                calling_fnc = CallingFuncs[f]
                Usage[fnc] += Usage[calling_fnc] }}
        for (fnc in Funcs) {
            if (Covered[fnc] == "Y") coverage++
            print fnc, Covered[fnc], Usage[fnc] }
        print "\nTotals:"
        print "Total Commands: " length(Funcs)
        print "Total Covered Commands: " coverage
        print "Simple Coverage Ratio: " coverage / length(Funcs) }
    ' $deps $tmp > $tmp1

ds:reo $tmp1 "1,1~^ds:" a | sort -nk3 | ds:fit
tail $tmp1 -n5

rm $tmp $tmp1 $tmpndata $deps
