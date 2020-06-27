#!/bin/bash
set -o pipefail
cd ~

CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
RED="\033[0;31m"
BLUE="\033[0;34m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

HOME_DIRS=( $(cd ~ ; ls -d */ | sed 's#/##') )
REPOS=()

for dir in ${HOME_DIRS[@]} ; do
  check_dir=$( git -C ${dir} rev-parse 2> /dev/null )
  check_dir=$( echo $? )
  if [ "${check_dir}" = "0" ]; then REPOS=(" ${REPOS[@]} " "${dir}"); fi
done

for repo in ${REPOS[@]}; do
  cd ~
  cd "${repo}"
  echo -e "${MAGENTA} Pulling latest for ${repo} ${NC}\n"
  git checkout master
  git pull
  wait
  echo -e "${CYAN} Git pull done for ${repo} ${NC}"
  if [ -f 'yarn.lock' ]; then
    echo -e "${MAGENTA} Running yarn for ${repo} ${NC}"
    yarn || continue > /dev/null
  fi
  echo -e "${GREEN} Done with ${repo}! ${NC}"
done
echo -e "\n\n${CYAN}--------------------------------------${NC}\n\n"


