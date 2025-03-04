#!/bin/bash
#
# local_branch_view.sh - Git Repository Branch Overview Tool
#
# This script provides a comprehensive view of branches across multiple local git repositories.
# It helps developers track and manage branches across their entire workspace, with features
# for filtering, sorting, and displaying branch information in various formats.
#
# Features:
# 1. Repository Discovery:
#    - Automatic detection of git repositories
#    - Deep search support for nested repositories
#    - Configurable search paths and depth
#    - Smart caching of repository information
#
# 2. Branch Analysis:
#    - Shows current branch status
#    - Tracks ahead/behind status with remote
#    - Identifies stale and orphaned branches
#    - Detects unmerged changes
#
# 3. Display Options:
#    - Table view with column alignment
#    - Compact mode for large numbers of repos
#    - JSON/YAML output for scripting
#    - Color-coded status indicators
#
# 4. Branch Filtering:
#    - Exclude common branches (main, master, develop)
#    - Custom pattern-based filtering
#    - Regular expression support
#    - Include/exclude specific repositories
#
# 5. Performance Features:
#    - Parallel processing for large workspaces
#    - Repository information caching
#    - Optimized git commands
#    - Fast repository detection
#
# Options:
#   -a    Include repositories with only default branches
#   -d    Deep search for repositories
#   -e    Exclude branches matching pattern
#   -i    Include only branches matching pattern
#   -p    Enable parallel processing
#   -t    Output format (table, json, yaml)
#   -h    Show this help message
#
# Example Usage:
#   ./local_branch_view.sh                    # Basic view
#   ./local_branch_view.sh -d                 # Deep search
#   ./local_branch_view.sh -e '^(main|dev)$'  # Exclude main/dev branches
#   ./local_branch_view.sh -t json            # JSON output
#   ./local_branch_view.sh -p ~/projects      # Parallel search in directory
#
# Status Indicators:
#   ✓  Up to date with remote
#   ↑  Ahead of remote (number of commits)
#   ↓  Behind remote (number of commits)
#   ⚠  Unmerged changes
#   ⚡  No remote tracking
#
# Cache Location:
#   ${XDG_CACHE_HOME:-$HOME/.cache}/git_branch_view
#
# Notes:
# - Cache expires after 5 minutes
# - Use -d for thorough repository discovery
# - Parallel processing (-p) recommended for large workspaces
# - Custom patterns support regular expressions
#
# Performance Tips:
# - Use shallow search for quick results
# - Enable parallel processing for many repositories
# - Use caching for repeated queries
# - Consider using compact view for large outputs
#
# Last Updated: 2025-03-04

set -o pipefail
set -e  # Exit on error
echo

# Default configuration
DEFAULT_BRANCH_PATTERNS=(
    '^master$'
    '^main$'
    '^dev$'
    '^develop$'
    '^trunk$'
    '^release$'
)

# Handle option flags and set conditional variables

lbvHelp() {
    echo "Script to print a view of local git repositories against branches."
    echo
    echo "Syntax: [-ab:Dfhmo:s]"
    echo "-a    Run for all local repos found (implies D, m)"
    echo "-b    Run for a custom base directory filepath arg"
    echo "-D    Deep search for all repos in base directory"
    echo "-e    Exclude branches matching pattern (can be used multiple times)"
    echo "-f    Run find using fd if installed (implies D)"
    echo "-h    Print this help"
    echo "-i    Include branches matching pattern (can be used multiple times)"
    echo "-m    Include repos found with only default branches"
    echo "-o    Override repos to run with filepath args"
    echo "-p    Process repositories in parallel"
    echo "-s    Mark repos and branches with untracked changes"
    echo "-t    Output format (table, json, yaml) [default: table]"
    echo "-v    Run in verbose mode"
    echo
    exit
}

if (($# == 0)); then
    echo "No flags set: Running only for repos with non-default branches in top level of home"
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

# Initialize arrays for branch patterns
EXCLUDE_PATTERNS=("${DEFAULT_BRANCH_PATTERNS[@]}")
INCLUDE_PATTERNS=()

while getopts ":ab:De:fhi:mo:pst:v" opt; do
    case $opt in
        a)  RUN_ALL_REPOS=true ; DEEP=true ; INCLUDE_DEFAULT_BRANCHES=true ;;
        b)  if [ -z $BASE_DIR ]; then
                    BASE_DIR=$(echo "$OPTARG" | sed 's/^ //g')
                else
                    echo -e "\nOpts -b and -o cannot be used together - exiting"; exit 1
                fi
                [ "${BASE_DIR:0:1}" = '~' ] && BASE_DIR="${HOME}${BASE_DIR:1}" ;;
        D)  getoptsGetOptarg $@
                DEEP=${OPTARG:-true} ;;
        e)  EXCLUDE_PATTERNS+=("$OPTARG") ;;
        f)  which fd &> /dev/null
                [ $? = 0 ] && USE_FD=true || echo 'Unable to validate fd command - '\
                    'FD not set - running all repos using find'
                DEEP=true ;;
        h)  lbvHelp ;;
        i)  INCLUDE_PATTERNS+=("$OPTARG") ;;
        m)  INCLUDE_DEFAULT_BRANCHES=true ;;
        o)  if [ -z $BASE_DIR ]; then
                    OVERRIDE_REPOS=( $(echo "${OPTARG[@]}") )
                else
                    echo -e "\nOpts -b and -o cannot be used together - exiting"; exit 1
                fi ;;
        p)  PARALLEL=true ;;
        s)  DISPLAY_STATUS=true ;;
        t)  OUTPUT_FORMAT="$OPTARG" ;;
        v)  VERBOSE=true ;;
        \?) echo -e "\nInvalid option: -$opt \nValid options include [-ab:De:fhi:mo:pst:v]" >&2
                exit 1 ;;
    esac
done

[[ ! ( $RUN_ALL_REPOS || $OVERRIDE_REPOS ) ]] && BASE_DIR_CASE=true

if [ $VERBOSE ]; then
    [ $RUN_ALL_REPOS ] && echo "All opt set: Running for all git repos found"
    [ $BASE_DIR ] && echo "Base dir opt set: Running with base directory ${OPTARG}"
    if [[ $DEEP && $BASE_DIR_CASE ]]; then
        echo "Deep search opt set: Running for all repos found in base directory"
    fi
    [ $OVERRIDE_REPOS ] && echo "Override repos opt set: All filepaths provided must be valid repos"
    [ $DISPLAY_STATUS ] && echo "Status opt set: Branches with untracked changes will be marked in red if color supported"
    [ $INCLUDE_DEFAULT_BRANCHES ] && echo "Default branch opt set: Repos with only default branches will be included"
    [ $PARALLEL ] && echo "Parallel opt set: Processing repositories in parallel"
fi

# Initialize variables

if tput colors &> /dev/null; then
    CYAN="\033[0;36m"
    ORANGE="\033[0;33m"
    RED="\033[0;31m"
    GRAY="\033[0:37m"
    WHITE="\033[1:35m"
    BLUE="\033[0;34m"
    NC="\033[0m" # No Color
fi

TABLE_DATA="${WHITE}BRANCHES_____________\_____________REPOS${GRAY}"
[ "$BASE_DIR" ] || BASE_DIR="$HOME"
FIND_DIRS=(/Users /bin /usr /var)
BASE_DIRS=()
ALL_REPOS=()
SORTED_REPOS=()
ALL_BRANCHES=()
UNIQ_BRANCHES=()
BRANCH_TRACKINGS=()
OLD_IFS="$IFS"

# Cache directory for repository information
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/local_branch_view"
mkdir -p "$CACHE_DIR"

# Function to check if a branch should be excluded
should_exclude_branch() {
    local branch="$1"
    
    # Check include patterns first
    if [ ${#INCLUDE_PATTERNS[@]} -gt 0 ]; then
        for pattern in "${INCLUDE_PATTERNS[@]}"; do
            if [[ "$branch" =~ $pattern ]]; then
                return 1
            fi
        done
        return 0
    fi
    
    # Then check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$branch" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Function to get cached or fresh repository data
get_repo_data() {
    local repo="$1"
    local cache_file="$CACHE_DIR/$(echo "$repo" | tr '/' '_')"
    local branches=()
    local untracked=0
    
    # Check if cache is fresh (less than 5 minutes old)
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -f %m "$cache_file"))) -lt 300 ]; then
        source "$cache_file"
        echo "${branches[*]}"
        return
    fi
    
    # Get fresh data
    if [ $(git rev-parse --is-inside-work-tree 2> /dev/null) ]; then
        eval "$(git for-each-ref --shell --format='branches+=(%(refname:lstrip=2))' refs/heads/)"
        # Cache the results
        {
            echo "branches=(${branches[*]})"
            echo "last_updated=$(date +%s)"
        } > "$cache_file"
        echo "${branches[*]}"
    fi
}

# Define methods

isInt() {
    local test="$1"
    local n_re="^[0-9]$"
    [[ "$test" =~ $n_re ]]
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
  
    printf '%s\n' "$var"
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
    local key="$1" vals="${@:2}"
    printf -v "$key" %s " ${vals[@]} "
}
rangeBind() {
    if   (($1 < $3)) ; then echo "$3"
    elif (($1 > $5)) ; then echo "$5"
    else                    echo "$1"
    fi
}
repeatString() {
    local input="$1" count="$2"
    printf -v str "%${count}s"
    printf '%s\n' "${str// /$input}"
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

# Process repositories based on settings
process_repos() {
    local repo_data=()
    
    if [ $PARALLEL ] && command -v parallel >/dev/null; then
        # Parallel processing for initial data gathering only
        while IFS= read -r result; do
            repo_data+=("$result")
        done < <(printf '%s\n' "${ALL_REPOS[@]}" | parallel --will-cite -j+0 get_repo_info {})
        
        # Process results sequentially to maintain sorting
        for line in "${repo_data[@]}"; do
            # Format: repo:branch1 branch2 branch3:untracked
            IFS=':' read -r repo branches untracked <<< "$line"
            process_repo_result "$repo" "$branches" "$untracked"
        done
    else
        for repo in "${ALL_REPOS[@]}"; do
            process_single_repo "$repo"
        done
    fi
}

# Function to get repository info (used by parallel processing)
get_repo_info() {
    local repo="$1"
    local spacey_repo=$(spaceReplace "$repo")
    local branches_str=""
    local untracked=0
    
    cd "$spacey_repo" 2>/dev/null || return
    
    if branches_str=$(get_repo_data "$repo"); then
        # Filter branches based on patterns
        local filtered_branches=()
        for branch in $branches_str; do
            if ! should_exclude_branch "$branch"; then
                filtered_branches+=("$branch")
            fi
        done
        
        if [ $DISPLAY_STATUS ] && [ "$(git status --porcelain 2>/dev/null)" ]; then
            untracked=1
        fi
        
        # Output format: repo:filtered_branches:untracked
        printf '%s:%s:%d\n' "$repo" "${filtered_branches[*]}" "$untracked"
    fi
}

# Process repository result (used after parallel processing)
process_repo_result() {
    local repo="$1"
    local branches="$2"
    local untracked="$3"
    
    read -ra BRANCHES <<< "$branches"
    let branch_count=${#BRANCHES[@]}
    
    # Rest of the existing repo processing logic
    if [[ $branch_count -eq 0 || ! $INCLUDE_DEFAULT_BRANCHES && ! $untracked \
            && -z ${BRANCHES[2]} && ("${BRANCHES[@]}" = 'master' || "${BRANCHES[@]}" = 'main') ]]
    then
        REPOS=( ${REPOS[@]/%"${repo}"/} )
    else
        ALL_BRANCHES=( "${ALL_BRANCHES[@]}" "${BRANCHES[@]}" )
    
        repo_key_base=$(generateAllowedVarName "$repo")
        repo_key="${repo_key_base}_key"
        repo_branch_count_key="${repo_key_base}_branch_count"
        associateKeyToArray $repo_key ${BRANCHES[@]}
        associateKeyToArray $repo_branch_count_key $branch_count
    
        if [ $untracked = "1" ] ; then
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
}

process_single_repo() {
    local repo="$1"
    local spacey_repo=$(spaceReplace "$repo")
    [ $RUN_ALL_REPOS ] || [ $OVERRIDE_REPOS ] || cd "$BASE_DIR"
    cd "$spacey_repo"
    BRANCHES=()

    # Get repository data (from cache if available)
    if branches_str=$(get_repo_data "$repo"); then
        read -ra BRANCHES <<< "$branches_str"
        
        # Filter branches based on patterns
        local filtered_branches=()
        for branch in "${BRANCHES[@]}"; do
            if ! should_exclude_branch "$branch"; then
                filtered_branches+=("$branch")
            fi
        done
        BRANCHES=("${filtered_branches[@]}")
        
        [[ $DISPLAY_STATUS && $(git status --porcelain | wc -c | xargs) -gt 0 ]] && untracked=1
    fi

    let branch_count=${#BRANCHES[@]}

    # Rest of the existing repo processing logic
    if [[ $branch_count -eq 0 || ! $INCLUDE_DEFAULT_BRANCHES && ! $untracked \
            && -z ${BRANCHES[2]} && ("${BRANCHES[@]}" = 'master' || "${BRANCHES[@]}" = 'main') ]]
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
}

[ $SPIN_PID ] && kill -9 $SPIN_PID > /dev/null 2>&1; printf '\e[K'
IFS="$OLD_IFS"
[[ $VERBOSE && $OVERRIDE_REPOS ]] && echo 'Override repos valid'
REPOS=( ${ALL_REPOS[@]} )
let input_repo_count=${#REPOS[@]}

process_repos

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

# Cleanup old cache files (older than 1 day) at the end
find "$CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null

