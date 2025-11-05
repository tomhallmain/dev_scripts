#!/bin/bash
#
## TODO: Git tests

# SETUP

if tput colors &> /dev/null; then
    export NC="\033[0m" # No Color
    export GREEN="\033[0;32m"
fi

export tmp=/tmp/ds_commands_tests
export q=/dev/null
export shell="$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')"

if [[ $shell =~ 'bash' ]]; then
    bsh=0
    MAIN="${BASH_SOURCE%/*}/.."
    cd "$MAIN"
    source commands.sh
    $(ds:fail 'testfail' &> $tmp)
    testfail=$(cat $tmp)
    [[ $testfail =~ '_err_: testfail' ]] || echo 'fail command failed in bash case'
elif [[ $shell =~ 'zsh' ]]; then
    MAIN="$(dirname $0)/.."
    cd "$MAIN"
    source commands.sh
    $(ds:fail 'testfail' &> $tmp)
    testfail=$(cat $tmp)
    [[ $testfail =~ '_err_: Operation intentionally failed' ]] || echo 'fail command failed in zsh case'
else
    echo 'unhandled shell detected - only zsh/bash supported at this time'
    exit 1
fi

if [[ $shell =~ 'bash' ]]; then
    $shell "$DS_SUPPORT/clean.sh" > $q
fi

# TEST RUN

SECONDS=0

## TODO plot tests
## TODO more negative hist tests
## TODO file check tests
## TODO gexec tests

$shell tests/t_basic.sh
$shell tests/t_git.sh
$shell tests/t_case.sh
$shell tests/t_graph.sh
$shell tests/t_shape.sh
$shell tests/t_infer.sh         || ds:fail 'WARNING: infer failed so skipping dependent tests'
$shell tests/t_inferk.sh        || skip_integration=1
$shell tests/t_join.sh          || skip_integration=1
$shell tests/t_sort.sh          || skip_integration=1
$shell tests/t_prefield.sh      || ds:fail 'WARNING: prefield failed so skipping dependent tests'
$shell tests/t_reorder.sh       || skip_integration=1
$shell tests/t_fit.sh           || skip_integration=1
$shell tests/t_newfs.sh         || skip_integration=1
$shell tests/t_fieldcounts.sh   || skip_integration=1 skip_searchx=1
$shell tests/t_subsep.sh        || skip_integration=1
$shell tests/t_power.sh         || skip_integration=1
$shell tests/t_field_replace.sh || skip_integration=1
$shell tests/t_pivot.sh         || skip_integration=1
$shell tests/t_aggregation.sh   || skip_integration=1
$shell tests/t_diff_fields.sh   || skip_integration=1

if [ "$skip_searchx" ]; then
    echo 'WARNING: skipping searchx tests as tests on dependents failed'
else
    $shell tests/t_searchx.sh
fi

if [ "$skip_integration" ]; then
    echo 'WARNING: skipping integration tests as tests on dependents failed'
else
    $shell tests/t_integration.sh
fi

# REPORT

duration=SECONDS
echo "$(($duration / 60))m$(($duration % 60))s elapsed."

# CLEANUP

if [[ $shell =~ 'bash' ]]; then
    $shell "$DS_SUPPORT/clean.sh" > $q
fi

rm $tmp
