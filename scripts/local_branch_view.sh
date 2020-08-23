#!/bin/bash
#
# Script by Tom Hall (github.com/tomhallmain)
#
# Credit getoptsGetOptarg function:
# https://stackoverflow.com/questions/11517139/optional-option-argument-with-getopts/57295993#57295993
#
# To report a bug please send a message to: tomhall.main@gmail.com
#

set -o pipefail
echo



# Handle option flags and set conditional variables

lbvHelp() {
  echo "Script to print a view of local git repositories against branches."
  echo
  echo "Syntax: [-ab:Dfhmo:s]"
  echo "a    Run for all local repos found (implies d, m)"
  echo "b    Run for a custom base directory filepath arg"
  echo "D    Deep search for all repos in base directory"
  echo "f    Run all find using fd if installed (implies a, d, m)"
  echo "h    Print this help"
  echo "m    Include repos found with only master branch"
  echo "o    Override repos to run with filepath args"
  echo "s    Mark repos and branches with untracked changes"
  echo "v    Run in verbose mode"
  echo
  exit
}

if (($# == 0)); then
  echo "No flags set: Running only for repos with non-master branches in top level of home"
  echo "Add opt -h to print help"
fi

getoptsGetOptarg() {
  eval next_token=\${$OPTIND}
  if [[ -n $next_token && $next_token != -* ]]; then
    OPTIND=$((OPTIND + 1))
    OPTARG=$next_token
  else
    OPTARG=""
  fi
}

while getopts ":ab:Dfhmo:sv" opt; do
  case $opt in
    a)  RUN_ALL_REPOS=true ; DEEP=true ; INCLUDE_MASTER_ONLYS=true ;;
    b)  if [ -z $BASE_DIR ]; then
          BASE_DIR=$(echo "$OPTARG" | sed 's/^ //g')
        else
          echo -e "\nOpts -b and -o cannot be used together - exiting"; exit 1
        fi
        [ "${BASE_DIR:0:1}" = '~' ] && BASE_DIR="${HOME}${BASE_DIR:1}" ;;
    D)  getoptsGetOptarg $@
        DEEP=${OPTARG:-true} ;;
    f)  which fd &> /dev/null
        [ $? ] && USE_FD=true || (echo 'FD not set - running all repos using find') 
        DEEP=true ;;
    h)  lbvHelp ;;
    m)  INCLUDE_MASTER_ONLYS=true ;;
    o)  if [ -z $BASE_DIR ]; then
          OVERRIDE_REPOS=( $(echo "${OPTARG[@]}") )
        else
          echo -e "\nOpts -b and -o cannot be used together - exiting"; exit 1
        fi ;;
    s)  DISPLAY_STATUS=true ;;
    v)  VERBOSE=true ;;
    \?) echo -e "\nInvalid option: -$opt \nValid options include [-ab:Dfhmo:sv]" >&2
        exit 1 ;;
  esac
done

[[ ! ( $RUN_ALL_REPOS || $OVERRIDE_REPOS ) ]] && BASE_DIR_CASE=true

if [ $VERBOSE ]; then
  [ $RUN_ALL_REPOS ] && echo "All opt set: Running for all git repos found"
  [ $BASE_DIR ] && echo "Base dir opt set: Running with a base dir of ${OPTARG}"
  if [[ $DEEP && $BASE_DIR_CASE ]]; then
    echo "Deep search opt set: Running for all repos found in base directory"
  fi
  [ $OVERRIDE_REPOS ] && echo "Override repos opt set: All filepaths provided must be valid repos"
  [ $DISPLAY_STATUS ] && echo "Status opt set: Branches with untracked changes will be marked in red"
  [ $INCLUDE_MASTER_ONLYS ] && echo "Master opt set: Repos with only master branch will be included"
fi

# Initialize variables

CYAN="\033[0;36m"
ORANGE="\033[0;33m"
RED="\033[0;31m"
GRAY="\033[0:37m"
WHITE="\033[1:35m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

TABLE_DATA="${WHITE}BRANCHES_____________\_____________REPOS${GRAY}"
[ $BASE_DIR ] || BASE_DIR=$HOME
FIND_DIRS=(/Users /bin /usr /var)
BASE_DIRS=()
ALL_REPOS=()
SORTED_REPOS=()
ALL_BRANCHES=()
UNIQ_BRANCHES=()
BRANCH_TRACKINGS=()
OLD_IFS=$IFS




# Define methods

isInt() {
  local test="$1"
  local n_re="^[0-9]$"
  [[ $test =~ $n_re ]]
}
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
argIndex() {
  unset str
  local n_fields="$1"
  for i in $(seq 1 $n_fields); do
    [ $i -lt $n_fields ] && str="${str}\$$i," || str="${str}\$$i"
  done
  printf '%s\n' "${str}"
}
spin() {
  spinner='\|/—'
  let count=0
  while [ $count -lt 5000 ]; do
    for i in {0..3}; do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      let count+=1
      sleep 0.5
    done
  done
}




# Find repos if unset and unique branches, sort and set more variables

([[ $VERBOSE && $DEEP ]] && echo -e "\nGathering repo data...") || \
([[ $VERBOSE && $OVERRIDE_REPOS ]] && echo -e "\nValidating override repos...") || \
cd "$BASE_DIR"

if [[ $DEEP || $OVERRIDE_REPOS ]]; then
  spin &
  SPIN_PID=$!
  disown $SPIN_PID
fi

while IFS=$'\n' read -r line; do
  ([ $DEEP ] || [ -d "${line}/.git" ]) && ALL_REPOS+=( $(spaceRemove $line ) )
done < <(
  if [ $OVERRIDE_REPOS ]; then
    printf '%s\n' "${OVERRIDE_REPOS[@]}"
  elif [ $DEEP ]; then
    [ -z $RUN_ALL_REPOS ] && FIND_DIRS=( "$BASE_DIR" )
    if [ $USE_FD ]; then
      isInt $DEEP && maxdepth="-d $DEEP"
      fd $maxdepth -c never -Hast d "\.git$" "${FIND_DIRS}" | sed 's/\/\.git$//'
    else
      isInt $DEEP && maxdepth="-maxdepth $DEEP"
      find "${FIND_DIRS[@]}" -name ".git" -prune $maxdepth 2>/dev/null | sed 's/\/\.git$//'
    fi
  else
    cd "$BASE_DIR" ; find * -maxdepth 0 -type d
  fi
)

[ $SPIN_PID ] && kill -9 $SPIN_PID > /dev/null 2>&1; printf '\e[K'
IFS=$OLD_IFS
[[ $VERBOSE && $OVERRIDE_REPOS ]] && echo 'Override repos valid'
REPOS=( ${ALL_REPOS[@]} )
let input_repo_count=${#REPOS[@]}

for repo in ${ALL_REPOS[@]} ; do
  spacey_repo=$(spaceReplace $repo)
  [ $RUN_ALL_REPOS ] || [ $OVERRIDE_REPOS ] || cd "$BASE_DIR"
  cd "$spacey_repo"
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
    REPOS=( ${REPOS[@]/%"${repo}"/} )
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
  if [ $OVERRIDE_REPOS ]; then
    echo -e "\n${ORANGE}Filepaths provided for repo override are not valid repos\n"
  else
    echo -e "\n${ORANGE}No repos found that match current settings - exiting\n"
  fi
  exit
elif [ ${#ALL_BRANCHES[@]} -eq 0 ]; then
  echo -e "\n${ORANGE}No branches found that match current settings - exiting\n"
  exit
else
  let output_repo_count=${#REPOS[@]}
  let repos_filtered_out=($input_repo_count - $output_repo_count)
  if [ $VERBOSE ]; then
    echo -e "${repos_filtered_out} out of ${input_repo_count} repos found do not meet display criteria"
  fi
fi


# Sort the repos and branches by most combinations found

UNIQ_BRANCHES=( $(printf '%s\n' "${ALL_BRANCHES[@]}" \
                  | sort -r | uniq -c | sort -nr | awk '{print $2}') )
REPOS=( $(printf '%s\n' "${REPOS[@]}") )

for repo in ${REPOS[@]} ; do
  repo_branch_count_key="$(generateAllowedVarName "$repo")_branch_count"

  branch_count=$( echo ${!repo_branch_count_key} | tr -d '[:space:]' )

  REPOS=( ${REPOS[@]/%$repo/${branch_count}@@${repo}} )
done

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




# Build data into ordered table string

if [ $VERBOSE ]; then
  [ $BASE_DIR_CASE ] && echo -e "\nBase directory: ${BASE_DIR}"

  echo -e "\nRepos included:"
fi

for repo in ${REPOS[@]} ; do
  repo="$(spaceReplace $repo)"
  repo_basename="$(basename "$repo")"
  short_repo=${repo_basename:0:$REPO_STR_LEN}
  
  if [ $VERBOSE ]; then
    [ $BASE_DIR_CASE ] && echo "$repo_basename" || echo "$repo"
  fi
  
  if [ $DISPLAY_STATUS ]; then
    repo_untracked_key="$(generateAllowedVarName "$repo")_untracked_key"
    untracked="${!repo_untracked_key}"
    [ $untracked ] && REPO_COLOR="$RED"
  fi
  [ $REPO_COLOR ] || REPO_COLOR="$WHITE"

  TABLE_DATA="${TABLE_DATA} ${REPO_COLOR}$(spaceToUnderscore $short_repo)${GRAY}"

  unset REPO_COLOR
done

echo

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
    [ $INTERSECT_COLOR ] || INTERSECT_COLOR="$CYAN"

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



# Build Awk format string and call relevant data to display table in console

COL_FORMAT=$(repeatString "%-${COL_WID}s" $N_REPOS)
COL_FIELDS_ARGS=$(argIndex $N_ALL_COLS)
PRINT_STRING="{printf(\"%-60s${COL_FORMAT}\n\",${COL_FIELDS_ARGS})}"

[ $VERBOSE ] && echo -e "Local branch view as of $(date):\n"
echo -e $TABLE_DATA | awk "$PRINT_STRING"
echo -e "\n"

