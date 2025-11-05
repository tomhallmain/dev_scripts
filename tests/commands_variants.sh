#!/bin/bash

# Run a single test file

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

show_options() {
    echo -e "Available test options:"
    ds:reo "$0" '^case##^esac' off \
        | grep -Eo '^    [a-z_|*]+' \
        | sed 's# *##g' \
        | grep -Ev '^\*$'
}

# RUN


if [ ! "$1" ]
then
    show_options
    exit 1
fi

tests="$1"
debug="$2"

case "$tests" in
    agg*)       _test="aggregation"  ;;
    basic*)     _test="basic"   ;;
    case)       _test="case"         ;;
    diff_f*)    _test="diff_fields"  ;;
    fc|fieldcounts|uniq)     _test="fieldcounts"     ;;
    fieldrep*|field_replace) _test="field_replace"  ;;
    fit)        _test="fit"       ;;
    graph)      _test="graph"  ;;
    infer|inf)  _test="infer"     ;;
    inferk)     _test="inferk"    ;;
    join|jn)    _test="join"    ;;
    newfs)      _test="newfs" ;;
    pivot)      _test="pivot"    ;;
    pow*)       _test="power" ;;
    prefield)   _test="prefield" ;;
    reo*)       _test="reorder"      ;;
    search*|dep*)  _test="searchx"        ;;
    shape|hist) _test="shape"     ;;
    sort*)      _test="sort" ;;
    int*) _test="integration" ;;
    *) ds:fail "Invalid option: $tests"
        show_options
        exit 1
        ;;
esac

if [ "$debug" ]; then
    $shell -x ./tests/t_${_test}.sh
else
    $shell ./tests/t_${_test}.sh
fi

#rm $tmp
