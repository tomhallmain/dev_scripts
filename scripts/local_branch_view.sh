#!/bin/bash
set -o pipefail
cd ~

# Handle option flags and set conditional variables

if (($# == 0)); then
  echo -e "\nNo flags set: Running only for repos with non-master branches in home directory\n"
  echo -e "To run for all repos in home directory, run with opt -a"
  INCLUDE_MASTER_ONLYS=false
  DISPLAY_STATUS=false
fi

while getopts ":as" opt; do
  case $opt in
    a)  echo -e "\nAll option triggered: Running for all git repos in home directory"
        INCLUDE_MASTER_ONLYS=true ;;
    s)  echo -e "\nStatus option triggered: Branches with uncommitted changes will be marked in red"
        DISPLAY_STATUS=true ;;
    \?) echo -e "Invalid option: -$OPTARG \nValid options include -a" >&2
        exit 1 ;;
  esac
done


# Initialize variables

CYAN="\033[0;36m"
ORANGE="\033[0;33m"
RED="\033[0;31m"
GRAY="\033[0:37m"
WHITE="\033[1:35m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

HOME_DIRS=( $(cd ~ ; ls -d */ | sed 's#/##') )
TABLE_DATA="${WHITE}BRANCHES_____________\_____________REPOS${GRAY}"
ALL_REPOS=()
SORTED_REPOS=()
ALL_BRANCHES=()
UNIQ_BRANCHES=()
BRANCH_TRACKINGS=()


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

associateKeyToArray() {
  # Bash 3 doesn't support hashes
  local key="${1}"
  local vals="${@:2}"
  printf -v "${key}" %s " ${vals[@]} "
}

rangeBind() {
  if   (($1 < $3)) ; then echo "$3"
  elif (($1 > $5)) ; then echo "$5"
  else                    echo "$1"
  fi
}

repeatString() {
  local input="$1"
  local count="$2"
  printf -v myString "%${count}s"
  printf '%s\n' "${myString// /$input}"
}

generateSeqArgs() {
  local n_fields="$1"
  for ((i = 1 ; i <= $n_fields ; i++)) ; do
    str="${str}\$${i}"
    if [[ i -ne $n_fields ]]; then str="${str},"; fi
  done
  printf '%s\n' "${str}"
}


# Find repos and unique branches, set up and sort more variables

for dir in ${HOME_DIRS[@]} ; do
  check_dir=$( git -C ${dir} rev-parse 2> /dev/null )
  check_dir=$( echo $? )
  if [ "${check_dir}" = "0" ]; then ALL_REPOS=(" ${ALL_REPOS[@]} " "${dir}"); fi
done

REPOS=( ${ALL_REPOS[@]} )

for repo in ${ALL_REPOS[@]} ; do
  cd ~
  cd "${repo}"
  BRANCHES=()

  eval "$(git for-each-ref --shell \
    --format='BRANCHES+=(%(refname:lstrip=2))' refs/heads/)"
  if [ "$DISPLAY_STATUS" = true ]; then
    if [ $(git status --porcelain | wc -c) -gt 0 ]; then
      untracked=1
    fi
  fi

  # Exclude repos that are only master with no untracked changes
  if [[ "${BRANCHES[1]}" = '' \
        && "${BRANCHES[@]}" =~ 'master' \
        && ! "$INCLUDE_MASTER_ONLYS" = true \
        && ! "$untracked" ]]
  then
    REPOS=( ${REPOS[@]//"${repo}"} )
  else
    repo_key_base=$(generateAllowedVarName "$repo")
    repo_key="${repo_key_base}_key"
    associateKeyToArray $repo_key ${BRANCHES[@]}

    repo_branch_count_key="${repo_key_base}_branch_count"
    let branch_count=${#BRANCHES[@]}
    associateKeyToArray $repo_branch_count_key $branch_count
    
    ALL_BRANCHES=( "${ALL_BRANCHES[@]}" "${BRANCHES[@]}" )

    if [ "$DISPLAY_STATUS" = true ] ; then
      # Assumes untracked files only exist on the current branch for now
      if [ $untracked ]; then
        active_branch=$(git branch --show-current)
        branch_key_base=$(generateAllowedVarName "$active_branch")
        branch_untracked_key="${branch_key_base}_untracked_key"
        repo_untracked_key="${repo_key_base}_untracked_key"
        repo_branch_untracked_key="${branch_key_base}_${repo_untracked_key}"
        associateKeyToArray $branch_untracked_key $untracked
        associateKeyToArray $repo_untracked_key $untracked
        associateKeyToArray $repo_branch_untracked_key $untracked
      fi
    fi
  fi

  unset untracked
done

# Sort the repos and branches by most combinations found
UNIQ_BRANCHES=( $(printf '%s\n' "${ALL_BRANCHES[@]}" \
                  | sort -r | uniq -c | sort -nr | awk '{print $2}') )
REPOS=( $(printf '%s\n' "${REPOS[@]}") )

for repo in ${REPOS[@]} ; do
  repo_key_base=$(generateAllowedVarName "$repo")
  repo_branch_count_key="${repo_key_base}_branch_count"

  branch_count=$( echo ${!repo_branch_count_key} | tr -d '[:space:]' )

  REPOS=( ${REPOS[@]/"${repo}"/"${branch_count}@@${repo}"} )
done

REPOS=( $(printf '%s\n' "${REPOS[@]}" | sort -nr | awk -F "@@" '{print $2}') )

let N_ROWS=1+${#UNIQ_BRANCHES[@]}
let N_REPOS=${#REPOS[@]}
let N_ALL_COLS=1+$N_REPOS

TERMINAL_WIDTH=$( stty size | awk '{print $2}' )
let REPO_SPACE=$( rangeBind $TERMINAL_WIDTH between 120 and 170 )
let REPO_STR_LEN=$REPO_SPACE/$N_REPOS*3/7
let STR_MAX=$( if (($N_REPOS < 10)) ; then echo '9'; else echo '7'; fi )
REPO_STR_LEN=$( rangeBind $REPO_STR_LEN between 3 and $STR_MAX )

let COL_WID=7/4*$REPO_SPACE/$N_REPOS
let COL_MAX=$( if (($N_REPOS < 10)) ; then echo '30'; else echo '24'; fi )
let COL_MIN=$( if (($N_REPOS < 10)) ; then echo '22'; else echo '20'; fi )
COL_WID=$( rangeBind $COL_WID between $COL_MIN and $COL_MAX )

echo -e "\nRepos included: ${REPOS[@]}\n"


# Build data into ordered table string

for repo in ${REPOS[@]} ; do
  short_repo=${repo:0:$REPO_STR_LEN}
  
  if [ "$DISPLAY_STATUS" = true ]; then
    repo_key_base=$(generateAllowedVarName "$repo")
    repo_untracked_key="${repo_key_base}_untracked_key"
    untracked="${!repo_untracked_key}"
    if [ $untracked ]; then REPO_COLOR="$RED"
    else REPO_COLOR="$WHITE"; fi
  else REPO_COLOR="$WHITE"; fi

  TABLE_DATA="${TABLE_DATA} ${REPO_COLOR}${short_repo}${GRAY}"
done

for branch in ${UNIQ_BRANCHES[@]} ; do
  short_branch=${branch:0:45}

  if [ "$DISPLAY_STATUS" = true ]; then
    branch_key_base=$(generateAllowedVarName "$branch")
    branch_untracked_key="${branch_key_base}_untracked_key"
    untracked="${!branch_untracked_key}"
    if [ $untracked ]; then
      BRANCH_COLOR="$RED"
    else
      if [[ " ${branch} " =~ " master " ]]
      then BRANCH_COLOR="$BLUE"
      else BRANCH_COLOR="$ORANGE"; fi
    fi
  else
    if [[ " ${branch} " =~ " master " ]]
    then BRANCH_COLOR="$BLUE"
    else BRANCH_COLOR="$ORANGE"; fi
  fi

  TABLE_DATA="${TABLE_DATA}\n${BRANCH_COLOR}${short_branch}${GRAY}"
  
  for repo in ${REPOS[@]} ; do
    repo_key_base=$(generateAllowedVarName "$repo")
    
    if [ "$DISPLAY_STATUS" = true ]; then
      repo_untracked_key="${repo_key_base}_untracked_key"
      repo_branch_untracked_key="${branch_key_base}_${repo_untracked_key}"
      untracked="${!repo_branch_untracked_key}"
      if [ $untracked ]; then INTERSECT_COLOR="$RED"
      else INTERSECT_COLOR="$CYAN"; fi
    else INTERSECT_COLOR="$CYAN"; fi

    repo_key="${repo_key_base}_key"
    repo_branches="${!repo_key}"
    
    if [[ " ${repo_branches} " =~ " ${branch} " ]] ; then
      TABLE_DATA="${TABLE_DATA} ${INTERSECT_COLOR}X${GRAY}"
    else
      TABLE_DATA="${TABLE_DATA} ${GRAY}.${GRAY}"
    fi
  done
done


# Build Awk format string and call it to display table in console

COL_FORMAT=$(repeatString "%-${COL_WID}s" $N_REPOS)
COL_FIELDS_ARGS=$(generateSeqArgs $N_ALL_COLS)
COL_FORMAT_STRING="{printf(\"%-60s${COL_FORMAT}\n\",${COL_FIELDS_ARGS})}"

echo -e $TABLE_DATA | awk "${COL_FORMAT_STRING}"
echo -e "\n"

unset TABLE_DATA REPOS UNIQ_BRANCHES COL_FORMAT_BASE COL_FIELDS_BASE COL_FORMAT_STRING
