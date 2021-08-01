#!/bin/bash
set -o pipefail

CYAN="\033[0;36m"
ORANGE="\033[0;33m"
RED="\033[0;31m"
GRAY="\033[0:37m"
WHITE="\033[1:35m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

# shellcheck disable=SC1009

echo -e "\n"

cd ~

REPOS=()
HOME_DIRS=( $(cd ~ ; ls -d */ | sed 's#/##') )

for dir in ${HOME_DIRS[@]} ; do
    check_dir=$( git -C ${dir} rev-parse 2> /dev/null )
    check_dir=$( echo $? )
    if [ "${check_dir}" = "0" ] ; then REPOS=( " ${REPOS[@]} " "${dir}" ) ; fi
done

for repo in ${REPOS[@]} ; do
    cd ~
    cd "${repo}"

    echo -e "${WHITE} ${repo}${NC}"

    git -c color.ui=always branch | grep '' || echo -e "${ORANGE} No non-master branches found. ${NC}"
    wait

    echo -e "\n"
done

echo -e "\n"
