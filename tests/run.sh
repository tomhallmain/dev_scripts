#!/bin/bash

shell=$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')

if [[ $shell =~ 'bash' ]]; then
    bsh=0
    cd "${BASH_SOURCE%/*}/.."
elif [[ $shell =~ 'zsh' ]]; then
    cd "$(dirname $0)/.."
else
    echo 'unhandled shell detected - only zsh/bash supported at this time - exiting test script'
    exit 1
fi

echo -e "\n---- Running bash commands tests ----\n"
if ! bash tests/commands_tests.sh; then
    echo 'Failed bash run'
    err=1
fi
echo -e "\n---- Running zsh commands tests ----\n"
if ! zsh tests/commands_tests.sh; then
    echo 'Failed zsh run'
    err=1
fi
if [ "$err" ]; then
    echo -e "\nOne or more test failures observed."
else
    echo -e "\nTests completed with no failures."
fi
