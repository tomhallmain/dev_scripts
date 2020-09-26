#!/bin/bash
#
# Stats about test coverage for dev_scripts repo

shell=$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')

if [[ $shell =~ 'bash' ]]; then
  bsh=0
  cd "${BASH_SOURCE%/*}/.."
elif [[ $shell =~ 'zsh' ]]; then
  cd "$(dirname $0)/.."
else
  echo 'unhandled shell detected - only zsh/bash supported at this time'
  exit 1
fi

source .commands.sh

tmp=$(ds:tmp 'ds_commands_cov')
command_funcs=$(grep -ho '[[:alnum:]_:]*()' "$DS_LOC/.commands.sh" \
  | sed 's/^  function //' | sed 's/()//' | sort)
util_funcs=$(grep -ho '[[:alnum:]_:]*()' "$DS_SUPPORT/utils.sh" \
  | sed 's/^  function //' | sed 's/()//' | sort)
test_funcs=$(grep -Eho 'ds:[a-z_]+' tests/commands_tests.sh | sort)

awk 'FNR == 1 {f++}
  f == 1 { Funcs[$0]++ }
  f == 2 { Funcs[$0]++ }
  f == 3 { TestFuncs[$0]++ }
  END {
    len_funcs=length(Funcs)
    len_covered_funcs=length(TestFuncs)
    print "Command", "Covered", "Variants"
    for (fnc in Funcs) {
      if (fnc in TestFuncs)
        print fnc, "Y", TestFuncs[fnc]
      else
        print fnc, "N", 0
    }
    print "\nTotals:"
    print "Total Commands: " len_funcs
    print "Total Covered Commands: " len_covered_funcs
    print "Simple Coverage Ratio: " len_covered_funcs / len_funcs
  }' \
  <(printf "%s\n" $command_funcs) \
  <(printf "%s\n" $util_funcs) \
  <(printf "%s\n" $test_funcs) \
  > $tmp

ds:reo $tmp "1~^Command,1~^ds:" a | sort -nk3 | ds:fit
tail $tmp -n4
rm $tmp
