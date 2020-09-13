#!/bin/bash
#
# Script to select and check out a branch based on a pattern

ORANGE="\033[0;33m"
WHITE="\033[1;37m"
NC="\033[0m" # No Color
int_re='^[0-9]+$'

if [[ ! ( -d .git || $(git rev-parse --is-inside-work-tree 2> /dev/null) ) ]]; then
  echo 'Current location is not a git directory'
  exit 1
fi

branches=($(git for-each-ref --format='%(refname:short)' refs/heads 2> /dev/null))

if [ $1 ]; then
  branches=($(printf "%s\n" "${branches[@]}" | awk -v search="$1" '$0 ~ search {print}'))
fi

let n_matches=${#branches[@]}

if [[ -z $n_matches || $n_matches -lt 1 ]]; then
  echo -e "${ORANGE} No branches found for search pattern on current repo\n" && exit 1
elif [ $n_matches -eq 1 ]; then
  branch="$branches"
  git checkout "$branch" && exit
else
  while [ ! $confirmed ]; do
    unset selections_confirmed
    echo 'Multiple branches found matching search:'
    printf "%s\n" "${branches[@]}" | awk '{print NR, $0}'
    echo
    read -p $'\e[37;1m Enter branch number to check out: \e[0m' to_ck

    while [ ! $selections_confirmed ]; do
      while [[ -z "$to_ck" ]]; do
        echo -e "\n${ORANGE} No value found, please try again or quit by Ctrl+C${NC}\n"
        read -p $'\e[37;1m Enter branch number to check out: \e[0m' to_ck
      done

      if [[ -z $to_ck || $to_ck -lt 1 || ! $to_ck =~ $int_re || $to_ck -gt $n_matches ]]; then
        echo -e "\n${ORANGE} Only input indices of the set provided - to quit enter Ctrl+C${NC}\n"
        break 1
      fi
      selections_confirmed=true
      confirmed=true
    done
  done
  let to_ck--; branch="${branches[$to_ck]}"
  git checkout "$branch" && exit
fi

[ $? -gt 0 ] && echo "Unable to check out branch ${branch}" && exit 1