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

#bash tests/commands_tests.sh || echo 'Failed bash run'
zsh tests/commands_tests.sh || echo 'Failed zsh run'
