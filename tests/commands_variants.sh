#!/bin/bash
#
# Generates and runs a test file for a single set of tests

tmp=/tmp/commands_tests
q=/dev/null
shell=$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')

if [[ $shell =~ 'bash' ]]; then
  bsh=0
  cd "${BASH_SOURCE%/*}/.."; source .commands.sh
  $(ds:fail 'testfail' &> $tmp); testfail=$(cat $tmp)
  [[ $testfail =~ '_err_: testfail' ]] || echo 'fail command failed in bash case'
elif [[ $shell =~ 'zsh' ]]; then
  cd "$(dirname $0)/.."; source .commands.sh
  $(ds:fail 'testfail' &> $tmp); testfail=$(cat $tmp)
  [[ $testfail =~ '_err_: Operation intentionally failed' ]] || echo 'fail command failed in zsh case'
else
  echo 'unhandled shell detected - only zsh/bash supported at this time'
  exit 1
fi

tests="$1"

case "$tests" in
  fit) ds:gexec true tests/commands_tests.sh tests "1..27,~fit" ;;
  reo) ds:gexec true tests/commands_tests.sh tests "1..27,97..174" ;;
  sort) ds:gexec true tests/commands_tests.sh tests "1..27,73..94" ;;
esac
