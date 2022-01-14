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

test_base="##BASICS TESTS , "

case "$tests" in
    inferfs)  test_context="IFS TESTS##JOIN TESTS"     ;;
    join)     test_context="JOIN TESTS##SORT TESTS"    ;;
    sort)     test_context="SORT TESTS##PREFIELD TEST" ;;
    prefield) test_context="PREFIELD TESTS##REO TESTS" ;;
    reo)      test_context="REO TESTS##FIT TESTS"      ;;
    fit)      test_context="FIT TESTS##FC TESTS"       ;;
    fc)       test_context="FC TESTS##NEWFS TESTS"     ;;
    newfs)    test_context="NEWFS TESTS##SUBSEP TESTS" ;;
    todo)     test_context="~todo"                     ;;
    substr)   test_context="~substr"                   ;;
    pow)      test_context="POW TESTS##FIELD_REPLAC"   ;;
    fieldrep) test_context="FIELD_REPLAC##PIVOT TEST"  ;;
    pivot)    test_context="PIVOT TESTS##AGG TESTS"    ;;
    agg)      test_context="AGG TESTS##DIFF_FIELDS"    ;;
    diff_f)   test_context="DIFF_FIELDS T##CASE TEST"  ;;
    case)     test_context="CASE TESTS##GRAPH"         ;;
    graph)    test_context="GRAPH TESTS##SHAPE TESTS"  ;;
    shape)    test_context="SHAPE TESTS##ASSORTED"     ;;
    deps)     test_context="help_deps##ds:deps"        ;;
    int)      test_context="INTEGRATION##"             ;;
esac

if [ "$test_context" ]; then
    ds:gexec true tests/commands_tests.sh tests "${test_base}${test_context}"
fi
