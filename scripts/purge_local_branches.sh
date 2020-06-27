#!/bin/bash
set -o pipefail
cd ~


# Initialize variables

ORANGE="\033[0;33m"
RED="\033[0;31m"
WHITE="\033[1:35m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

HOME_DIRS=( $(cd ~ ; ls -d */ | sed 's#/##') )
ALL_REPOS=()
ALL_BRANCHES=()
UNIQ_BRANCHES=()


# Define methods

extendAssociativeArray() {
  local key="${1}"
  local addvals="${@:2}"
  printf -v "${key}" %s " ${!key} ${addvals[@]} "
}

generateFilterString() {
  local matches=(" ${@} ")
  let length=${#matches[@]}
  last_match=${matches[length-1]}
  for match in ${matches[@]} ; do
    str="${str}(NR==${match})"
    if [ ! $match -eq $last_match ]; then
      str="${str} || "
    fi
  done
  printf '%s\n' "${str}"
}


# Find repos and unique branches, set up and sort more variables

for dir in ${HOME_DIRS[@]} ; do
  check_dir=$( git -C ${dir} rev-parse 2> /dev/null )
  check_dir=$( echo $? )
  if [ "${check_dir}" = "0" ] ; then ALL_REPOS=( " ${ALL_REPOS[@]} " "${dir}" ) ; fi
done

REPOS=( ${ALL_REPOS[@]} )

for repo in ${ALL_REPOS[@]} ; do
  cd ~
  cd "${repo}"
  BRANCHES=()

  eval "$(git for-each-ref --shell --format='BRANCHES+=(%(refname:lstrip=2))' refs/heads/)"

  # Remove master branches to disallow their deletion
  BRANCHES=( ${BRANCHES[@]//"master"} )
  ALL_BRANCHES=( " ${ALL_BRANCHES[@]} " " ${BRANCHES[@]} ")

  for branch in "${BRANCHES[@]}" ; do
    # shell doesn't allow hyphens in variable names, and Bash 3 doesn't support associative arrays
    branch_cleaned="${branch//\//_FSLASH_}"
    branch_cleaned="${branch_cleaned//\./_DOT_}"
    branch_key="${branch_cleaned//-/_HYPHEN_}_key"

    extendAssociativeArray $branch_key $repo
  done
done

UNIQ_BRANCHES=( $(printf '%s\n' "${ALL_BRANCHES[@]}" | sort | uniq ) )
let BRANCH_COUNT=${#UNIQ_BRANCHES[@]}


# Initiate user interfacing

echo -e "\n To quit this script, press Ctrl+C"

while [ ! "${confirmation}" = 'confirm' ]; do
  set_confirmed='false'
  to_purge=()
  echo ''
  echo -e "${BLUE} Available-to-purge branches are listed below.${NC}"
  echo ''
  printf '%s\n' "${UNIQ_BRANCHES[@]}" | awk '{print " " int((NR)) " " $1}'
  echo ''
  read -p $'\e[37m Enter branch numbers to purge separated by spaces: \e[0m' to_purge

  to_purge=( $(printf '%s\n' "${to_purge[@]}") )

  while [ ! "$set_confirmed" = 'true' ]; do
    while [[ -z "${to_purge[@]// }" ]]; do
      echo ''
      echo -e "${ORANGE} No value found, please try again. To quit the script, press Ctrl+C${NC}"
      echo ''
      read -p $'\e[37m Enter branch numbers to purge separated by spaces: \e[0m' to_purge
    done

    for i in ${to_purge[@]}; do
      re='^[0-9]+$'
      while [[ -z $i || ! $i =~ $re || $i -gt $BRANCH_COUNT ]]; do
        to_purge=()
        echo ''
        echo -e "${ORANGE} Only input indices of the set provided. To quit the script, press Ctrl+C${NC}"
        echo ''
        read -p $'\e[37m Enter branch numbers to purge separated by spaces: \e[0m' to_purge
        to_purge=( $(printf '%s\n' "${to_purge[@]}") )
        break 2
      done
      set_confirmed='true'
    done
  done

  conditional=$(generateFilterString ${to_purge[@]})
  filter="{ if(${conditional}) { print } }"
  PURGE_BRANCHES=($(printf '%s\n' "${UNIQ_BRANCHES[@]}" | awk "$filter"))

  echo ''
  echo -e "${ORANGE} Confirm branch purge selection below - BE CAREFUL, confirmation will attempt local deletion in all repos!${NC}"
  echo ''
  printf '\e[31m%s\n\e[m' "${PURGE_BRANCHES[@]}" | awk '{print " " $1}'
  read -p $'\e[37m Enter "confirm" to delete branches: \e[0m' confirmation

  if [[ $(echo "${confirmation}" | tr "[:upper:]" "[:lower:]") = 'confirm' ]]; then continue; fi

  echo ''
  echo "${ORANGE} Selection not confirmed. Would you like to modify your selection?${NC}"
  echo ''
  read -p $'\e[37m Enter "y" to modify selection or "continue" to proceed with current purge selection: \e[0m' modify

  modify=$(echo "${modify}" | tr "[:upper:]" "[:lower:]")

  if [ "${modify}" = 'y' ]; then
    confirmation=''
  elif [ "${modify}" = 'continue' ]; then
    confirmation='confirm'
  else
    echo ''
    echo -e "${RED} Input not understood and selection unconfirmed. Exiting script.${NC}"
    exit 1
  fi
done


# Delete the branches

for branch in ${PURGE_BRANCHES[@]}; do
  branch_cleaned="${branch//\//_FSLASH_}"
  branch_cleaned="${branch_cleaned//\./_DOT_}"
  branch_key="${branch_cleaned//-/_HYPHEN_}_key"
  for repo in ${!branch_key}; do
    cd ~
    cd $repo
    git checkout master
    git branch -D $branch
  done
done


# Report success

echo ''
echo -e "${BLUE} Successfully deleted selected local branches.${NC}"
echo ''

