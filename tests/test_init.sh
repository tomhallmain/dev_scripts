#!/bin/bash

if [ -f /bin/bash ]; then
    bash "${BASH_SOURCE}/commands_tests.sh"
fi

if [ -f /bin/zsh ]; then
    dir="$(dirname $0)"
    zsh "$dir/commands_tests.sh"
fi


