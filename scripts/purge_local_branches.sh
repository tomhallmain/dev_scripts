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

generateAllowedVarName() {
  # shell doesn't allow some chars in var names
  local unparsed="$1"
  var="${unparsed//\./_DOT_}"
  var="${var//-/_HYPHEN_}"
  var="${var//\//_FSLASH_}"
  var="${var//\\/_BSLASH_}"
  var="${var//1/_ONE_}"
  var="${var//2/_TWO_}"
  var="${var//3/_THREE_}"
  var="${var//4/_FOUR_}"
  var="${var//5/_FIVE_}"
  var="${var//6/_SIX_}"
  var="${var//7/_SEVEN_}"
  var="${var//8/_EIGHT_}"
  var="${var//9/_NINE_}"

  printf '%s\n' "${var}"
}

extendAssociativeArray() {
  # Bash 3 doesn't support hashes
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
    if [ ! $match -eq $last_match ]; then str="${str} || "; fi
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

  # Remove master and main branches to disallow their deletion
  BRANCHES=( ${BRANCHES[@]//" master "} )
  BRANCHES==( ${BRANCHES[@]//" main "} )
  ALL_BRANCHES=( " ${ALL_BRANCHES[@]} " " ${BRANCHES[@]} ")

  for branch in "${BRANCHES[@]}" ; do
    # shell doesn't allow hyphens in variable names, and Bash 3 doesn't support associative arrays
    branch_key_base=$(generateAllowedVarName "$branch")
    branch_key="${branch_key_base}_key"

    extendAssociativeArray $branch_key $repo
  done
done

UNIQ_BRANCHES=( $(printf '%s\n' "${ALL_BRANCHES[@]}" | sort | uniq ) )
let BRANCH_COUNT=${#UNIQ_BRANCHES[@]}


# Initiate user interfacing

echo -e "\n To quit this script, press Ctrl+C"

while [ ! $confirmed ]; do
  unset selections_confirmed
  to_purge=()
  echo -e "\n${BLUE} Available-to-purge branches are listed below.${NC}\n"
  printf '%s\n' "${UNIQ_BRANCHES[@]}" | awk '{print " " int((NR)) " " $1}'
  echo ''
  read -p $'\e[37m Enter branch numbers to purge separated by spaces: \e[0m' to_purge

  to_purge=( $(printf '%s\n' "${to_purge[@]}") )

  while [ ! $selections_confirmed ]; do
    while [[ -z "${to_purge[@]// }" ]]; do
      echo -e "\n${ORANGE} No value found, please try again. To quit the script, press Ctrl+C${NC}\n"
      read -p $'\e[37m Enter branch numbers to purge separated by spaces: \e[0m' to_purge
    done

    for i in ${to_purge[@]}; do
      re='^[0-9]+$'
      while [[ -z $i || ! $i =~ $re || $i -gt $BRANCH_COUNT ]]; do
        to_purge=()
        echo -e "\n${ORANGE} Only input indices of the set provided. To quit the script, press Ctrl+C${NC}\n"
        read -p $'\e[37m Enter branch numbers to purge separated by spaces: \e[0m' to_purge
        to_purge=( $(printf '%s\n' "${to_purge[@]}") )
        break 2
      done
      selections_confirmed=true
    done
  done

  conditional=$(generateFilterString ${to_purge[@]})
  filter="{ if(${conditional}) { print } }"
  PURGE_BRANCHES=($(printf '%s\n' "${UNIQ_BRANCHES[@]}" | awk "$filter"))

  echo -e "\n${ORANGE} Confirm branch purge selection below - BE CAREFUL, confirmation will attempt local deletion in all repos!${NC}\n"
  printf '\e[31m%s\n\e[m' "${PURGE_BRANCHES[@]}" | awk '{print " " $1}'
  read -p $'\e[37m Enter "confirm" to delete branches: \e[0m' confirm_input
  confirm_input=$(echo "${confirm_input}" | tr "[:upper:]" "[:lower:]")
  if [[ "$confirm_input" = 'confirm' ]]; then confirmed=true; fi

  echo -e "\n${ORANGE} Selection not confirmed. Would you like to modify your selection?${NC}\n"
  read -p $'\e[37m Enter "y" to modify selection or "continue" to proceed with current purge selection: \e[0m' modify

  modify=$(echo "${modify}" | tr "[:upper:]" "[:lower:]")

  if [ "${modify}" = 'y' ]; then continue
  elif [ "${modify}" = 'continue' ]; then confirmed=true
  else
    echo -e "\n${RED} Input not understood and selection unconfirmed. Exiting script.${NC}"
    exit 1
  fi
done


# Delete the branches

for branch in ${PURGE_BRANCHES[@]}; do
  branch_key_base=$(generateAllowedVarName "$branch")
  branch_key="${branch_key_base}_key"
  for repo in ${!branch_key}; do
    cd ~
    cd $repo
    git checkout master
    git branch -D $branch
  done
done

# TODO: Add check to be sure branch actually deleted

# Report success

echo -e "\n${BLUE} Successfully deleted selected local branches.${NC}\n"

