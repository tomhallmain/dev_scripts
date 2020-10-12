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
  fit)    ds:gexec true tests/commands_tests.sh tests "1..27,190..202" ;;
  reo)    ds:gexec true tests/commands_tests.sh tests "1..27,98..188"  ;;
  sort)   ds:gexec true tests/commands_tests.sh tests "1..27,75..96"   ;;
  newfs)  ds:gexec true tests/commands_tests.sh tests "1..27,~nfs"     ;;
  todo)   ds:gexec true tests/commands_tests.sh tests "1..27,~todo"    ;;
  substr) ds:gexec true tests/commands_tests.sh tests "1..27,~substr"  ;;
  pow)    ds:gexec true tests/commands_tests.sh tests "1..27,270..288" ;;
  deps)   ds:gexec true tests/commands_tests.sh tests "1..27,291..297" ;;
esac
