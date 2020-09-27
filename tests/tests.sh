#!/bin/bash
# This test script should produce no output if test run is successful
# TODO: Negative tests

test_var=1
tmp=/tmp/commands_tests
q=/dev/null
shell=$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')

if [[ $shell =~ 'bash' ]]; then
  bsh=0
  cd "${BASH_SOURCE%/*}/.."
  source .commands.sh
  $(ds:fail 'testfail' &> $tmp)
  testfail=$(cat $tmp)
elif [[ $shell =~ 'zsh' ]]; then
  cd "$(dirname $0)/.."
  source .commands.sh
  $(ds:fail 'testfail' &> $tmp)
  testfail=$(cat $tmp)
fi
trace_expected_zsh="+ds:trace:1> [ -z 'echo test' ']'
+ds:trace:6> cmd='echo test' 
+ds:trace:8> set -x
+ds:trace:8> eval 'echo test'
+(eval):1> echo test"
ds:trace 'echo test' &>$tmp
[ "$(head -n5 $tmp)" = "$trace_expected_zsh" ] || ds:fail 'trace command failed'
