#!/bin/bash
#
# Script by Tom Hall (github.com/tomhallmain)
#
# To report a bug please send a message to: tomhall.main@gmail.com
#

set -o pipefail
echo

# Handle option flags and set conditional variables

lbvHelp() {
  echo "Script to print a view of local git branches."
  echo
  echo "Syntax: [-adhmos]"
  echo "a    Run for all local repos found, implies opt m"
  echo "d    Run this script on a custom base directory filepath arg"
  echo "h    Print this help"
  echo "m    Include repos found with only master branch"
  echo "o    Override repos to run with file pathargs"
  echo "s    Mark repos and branches with untracked changes"
  echo
}

if (($# == 0)); then
  echo -e "No flags set: Running only for repos with non-master branches in home directory"
  echo "Add opt -h to print help"
fi

while getopts ":ad:hmo:s" opt; do
  case $opt in
    a)  echo "All opt set: Running for all git repos found"
        RUN_ALL_REPOS=true ; INCLUDE_MASTER_ONLYS=true ;;
    d)  echo "Base dir opt set: Running with a base dir of ${OPTARG}"
        if [ -z $BASE_DIR ]; then BASE_DIR=$(echo "$OPTARG" | sed 's/^ //g')
        else echo -e "\nOpts -d and -o cannot be used together - exiting"; fi
        if [ "${BASE_DIR:0:1}" = '~' ]; then BASE_DIR="${HOME}${BASE_DIR:1}"; fi ;;
    h)  lbvHelp; exit ;;
    m)  echo "Master opt set: Running for all repos with only master branch"
        INCLUDE_MASTER_ONLYS=true ;;
    o)  echo "Override repos opt set: All filepaths provided must be valid repos"
        if [ -z $BASE_DIR ]; then BASE_DIR=$(echo "$OPTARG" | sed 's/^ //g')
        else echo -e "\nOpts -d and -o cannot be used together - exiting"; fi
        OVERRIDE_REPOS=true ;;
    s)  echo "Status opt set: Branches with untracked changes will be marked in red"
        DISPLAY_STATUS=true ;;
    \?) echo -e "\nInvalid option: -$opt \nValid options include [-a|d|h|m|o|s]" >&2
        exit 1 ;;
  esac
done

[ -z "$BASE_DIR" ] && BASE_DIR=$HOME

# Initialize variables

CYAN="\033[0;36m"
ORANGE="\033[0;33m"
RED="\033[0;31m"
GRAY="\033[0:37m"
WHITE="\033[1:35m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

TABLE_DATA="${WHITE}BRANCHES_____________\_____________REPOS${GRAY}"
BASE_DIRS=()
ALL_REPOS=()
SORTED_REPOS=()
ALL_BRANCHES=()
UNIQ_BRANCHES=()
BRANCH_TRACKINGS=()

OLD_IFS=$IFS

# Define methods

generateAllowedVarName() {
  # Shell doesn't allow some chars in var names
  local unparsed="$1"
  var="${unparsed//\./_DOT_}"
  var="${var// /_SPACE_}"
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

spaceRemove() {
  local spaced="$@"
  printf '%s\n' "${spaced// /_SPACE_}"
}

spaceReplace() {
  local unspaced="$1"
  printf '%s\n' "${unspaced//_SPACE_/ }"
}

spaceToUnderscore() {
  local spaced="$@"
  printf '%s\n' "${spaced// /_}"
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


# Find repos if unset and unique branches, sort and set more variables

[ $RUN_ALL_REPOS ] && echo -e "\nGathering repo data..." || cd "$BASE_DIR"

while IFS=$'\n' read -r line; do
  ([ $RUN_ALL_REPOS ] || [ -d "${line}/.git" ]) && ALL_REPOS+=( $(spaceRemove $line ) )
done < <( 
  if [ $RUN_ALL_REPOS ]; then
    find /Users /bin /usr /var -name ".git" -prune 2>/dev/null | sed 's/\/\.git$//'
  else
    cd "$BASE_DIR"; find * -maxdepth 0 -type d
  fi
)

IFS=$OLD_IFS

REPOS=( ${ALL_REPOS[@]} )

echo ${REPOS[@]}

for repo in ${ALL_REPOS[@]} ; do
  spaceyRepo=$(spaceReplace $repo)
  if [ $RUN_ALL_REPOS ]; then
    cd "$spaceyRepo"
  else
    cd "$BASE_DIR"
    cd "$spaceyRepo"
  fi

  BRANCHES=()

  if [ $(git rev-parse --is-inside-work-tree 2> /dev/null) ]; then
    # Despite having a .git folder, a directory may not be a valid git repo
    eval "$(git for-each-ref --shell \
      --format='BRANCHES+=(%(refname:lstrip=2))' refs/heads/)"
    [[ $DISPLAY_STATUS && $(git status --porcelain | wc -c) -gt 0 ]] && untracked=1
  fi

  let branch_count=${#BRANCHES[@]}

  # Exclude repos that are only master with no untracked changes
  if [[ $branch_count -eq 0 || ! $INCLUDE_MASTER_ONLYS && ! $untracked \
        && -z ${BRANCHES[2]} && "${BRANCHES[@]}" = 'master' ]]
  then
    REPOS=( ${REPOS[@]//"${repo}"} )
  else
    ALL_BRANCHES=( "${ALL_BRANCHES[@]}" "${BRANCHES[@]}" )
    
    repo_key_base=$(generateAllowedVarName "$repo")
    repo_key="${repo_key_base}_key"
    repo_branch_count_key="${repo_key_base}_branch_count"
    associateKeyToArray $repo_key ${BRANCHES[@]}
    associateKeyToArray $repo_branch_count_key $branch_count
    
    if [ $untracked ] ; then
      # Assumes untracked files only exist on the current branch for now
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

  unset untracked
done

if [ ${#REPOS[@]} -eq 0 ]; then
  echo -e "\n${ORANGE}No repos found that match current settings - exiting\n"
  exit
elif [ ${#ALL_BRANCHES[@]} -eq 0 ]; then
  echo -e "\n${ORANGE}No branches found that match current settings - exiting\n"
  exit
fi

# Sort the repos and branches by most combinations found
UNIQ_BRANCHES=( $(printf '%s\n' "${ALL_BRANCHES[@]}" \
                  | sort -r | uniq -c | sort -nr | awk '{print $2}') )
REPOS=( $(printf '%s\n' "${REPOS[@]}") )

for repo in ${REPOS[@]} ; do
  repo_branch_count_key="$(generateAllowedVarName "$repo")_branch_count"

  branch_count=$( echo ${!repo_branch_count_key} | tr -d '[:space:]' )
  echo $repo_branch_count_key
  echo $branch_count

  REPOS=( ${REPOS[@]/%$repo/${branch_count}@@${repo}} )
done

echo ${REPOS[@]}
REPOS=( $(printf '%s\n' "${REPOS[@]}" | sort -nr | awk -F "@@" '{print $2}') )

let N_ROWS=1+${#UNIQ_BRANCHES[@]}
let N_REPOS=${#REPOS[@]}
let N_ALL_COLS=1+$N_REPOS

TERMINAL_WIDTH=$( stty size | awk '{print $2}' )
let REPO_SPACE=$( rangeBind $TERMINAL_WIDTH between 120 and 170 )
let REPO_STR_LEN=$REPO_SPACE/$N_REPOS*3/7
let STR_MAX=$( if (($N_REPOS < 10)) ; then echo '9'; else echo '7'; fi )
REPO_STR_LEN=$( rangeBind $REPO_STR_LEN between 4 and $STR_MAX )

let COL_WID=2*$REPO_SPACE/$N_REPOS
let COL_MAX=$( if (($N_REPOS < 10)) ; then echo '30'; else echo '24'; fi )
let COL_MIN=$( if (($N_REPOS < 10)) ; then echo '22'; else echo '20'; fi )
COL_WID=$( rangeBind $COL_WID between $COL_MIN and $COL_MAX )

echo -e "\nRepos included:"


# Build data into ordered table string

for repo in ${REPOS[@]} ; do
  repo="$(spaceReplace $repo)"
  echo "$repo"
  repo="$(basename "$repo")"
  short_repo=${repo:0:$REPO_STR_LEN}
  
  if [ $DISPLAY_STATUS ]; then
    repo_untracked_key="$(generateAllowedVarName "$repo")_untracked_key"
    untracked="${!repo_untracked_key}"
    [ $untracked ] && REPO_COLOR="$RED"
  fi
  [ -z $REPO_COLOR ] && REPO_COLOR="$WHITE"

  TABLE_DATA="${TABLE_DATA} ${REPO_COLOR}$(spaceToUnderscore $short_repo)${GRAY}"

  unset REPO_COLOR
done

for branch in ${UNIQ_BRANCHES[@]} ; do
  short_branch=${branch:0:45}

  if [ $DISPLAY_STATUS ]; then
    branch_key_base=$(generateAllowedVarName "$branch")
    branch_untracked_key="${branch_key_base}_untracked_key"
    untracked="${!branch_untracked_key}"
    [ $untracked ] && BRANCH_COLOR="$RED"
  fi
  
  if [[ ! $BRANCH_COLOR && " ${branch} " =~ " master " ]]; then
    BRANCH_COLOR="$BLUE"
  elif [ ! $BRANCH_COLOR ]; then
    BRANCH_COLOR="$ORANGE"
  fi

  TABLE_DATA="${TABLE_DATA}\n${BRANCH_COLOR}${short_branch}${GRAY}"
  
  for repo in ${REPOS[@]} ; do
    repo_key_base=$(generateAllowedVarName "$repo")
    
    if [ $DISPLAY_STATUS ]; then
      repo_untracked_key="${repo_key_base}_untracked_key"
      repo_branch_untracked_key="${branch_key_base}_${repo_untracked_key}"
      untracked="${!repo_branch_untracked_key}"
      [ $untracked ] && INTERSECT_COLOR="$RED"
    fi
    [ ! $INTERSECT_COLOR ] && INTERSECT_COLOR="$CYAN"

    repo_key="${repo_key_base}_key"
    repo_branches="${!repo_key}"
    
    if [[ " ${repo_branches} " =~ " ${branch} " ]]; then
      TABLE_DATA="${TABLE_DATA} ${INTERSECT_COLOR}X${GRAY}"
    else
      TABLE_DATA="${TABLE_DATA} ${GRAY}.${GRAY}"
    fi

    unset INTERSECT_COLOR
  done
  unset BRANCH_COLOR
done


# Build Awk format string and call it to display table in console

COL_FORMAT=$(repeatString "%-${COL_WID}s" $N_REPOS)
COL_FIELDS_ARGS=$(generateSeqArgs $N_ALL_COLS)
POSITIONING_STRING="{printf(\"%-60s${COL_FORMAT}\n\",${COL_FIELDS_ARGS})}"

echo -e $TABLE_DATA | awk "$POSITIONING_STRING"
echo -e "\n"

