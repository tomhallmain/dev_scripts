#!/bin/bash
#
# Generates and runs a test file for a single set of tests

tmp=/tmp/commands_tests
q=/dev/null
shell=$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')

if [[ $shell =~ 'bash' ]]; then
  bsh=0
  cd "${BASH_SOURCE%/*}/.."; source commands.sh
  $(ds:fail 'testfail' &> $tmp); testfail=$(cat $tmp)
  [[ $testfail =~ '_err_: testfail' ]] || echo 'fail command failed in bash case'
elif [[ $shell =~ 'zsh' ]]; then
  cd "$(dirname $0)/.."; source commands.sh
  $(ds:fail 'testfail' &> $tmp); testfail=$(cat $tmp)
  [[ $testfail =~ '_err_: Operation intentionally failed' ]] || echo 'fail command failed in zsh case'
else
  echo 'unhandled shell detected - only zsh/bash supported at this time'
  exit 1
fi

tests="$1"

case "$tests" in
  inferfs)  ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , ~inferfs"                 ;;
  jn)       ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , ~ds:jn && !~ds:jn$"       ;;
  sort)     ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , SORT TESTS##REO TESTS"    ;;
  reo)      ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , REO TESTS##FIT TESTS"     ;;
  fit)      ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , FIT TESTS##FC TESTS"      ;;
  fc)       ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , FC TESTS##NEWFS TESTS"    ;;
  newfs)    ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , ~nfs"                     ;;
  prefield) ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , PREFIELD TESTS##ASSORTED" ;;
  todo)     ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , ~todo"                    ;;
  substr)   ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , ~substr"                  ;;
  pow)      ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , pow_expected##combin co"  ;;
  deps)     ds:gexec true tests/commands_tests.sh tests "##BASICS TESTS , help_deps##ds:deps" ;;
esac
