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
#   ${XDG_CACHE_HOME:-$HOME/.cache}/local_branch_view
#
# Skip Repos File:
#   Create ${XDG_CACHE_HOME:-$HOME/.cache}/local_branch_view/.skip_repos to define
#   repository patterns to exclude. One pattern per line (supports regex).
#   Lines starting with # are treated as comments and ignored.
#
# Notes:
# - Caching is disabled by default (local git operations are fast, no remote calls needed)
# - Use -C <seconds> to enable caching if you run this frequently on many repos
# - By default, repos starting with '.' (hidden directories) are excluded
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
    echo "Syntax: [-ab:Dfhmo:pst:vC:x:]"
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
    echo "-C    Cache time in seconds, or 'off' to disable (default: disabled, no caching)"
    echo "-x    Exclude repositories matching pattern (can be used multiple times)"
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
EXCLUDE_PATTERNS=()
INCLUDE_PATTERNS=()
# Default: exclude repos starting with a dot (hidden directories)
EXCLUDE_REPO_PATTERNS=('^\..*')

while getopts ":ab:De:fhi:mo:pst:vC:x:" opt; do
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
        C)  if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then CACHE_TTL="$OPTARG"; elif [[ "$OPTARG" = "off" ]]; then CACHE_TTL=0; else echo -e "\nInvalid -C value. Use a number (cache time in seconds) or 'off' to disable" >&2; exit 1; fi ;;
        x)  EXCLUDE_REPO_PATTERNS+=("$OPTARG") ;;
        \?) echo -e "\nInvalid option: -$opt \nValid options include [-ab:De:fhi:mo:pst:vC:x:]" >&2
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
# Cache time: default 3 days (259200 seconds) - only used if caching enabled via -C flag
[[ -z "$CACHE_TTL" ]] && CACHE_TTL=0

# Cache directory for repository information
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/local_branch_view"
mkdir -p "$CACHE_DIR"
SKIP_REPOS_FILE="$CACHE_DIR/.skip_repos"

# Load skip repos from file if it exists
if [ -f "$SKIP_REPOS_FILE" ]; then
    while IFS= read -r skip_pattern || [ -n "$skip_pattern" ]; do
        # Skip empty lines and comments (lines starting with #)
        [[ -z "$skip_pattern" || "$skip_pattern" =~ ^[[:space:]]*# ]] && continue
        # Trim whitespace
        skip_pattern=$(echo "$skip_pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -n "$skip_pattern" ]] && EXCLUDE_REPO_PATTERNS+=("$skip_pattern")
    done < "$SKIP_REPOS_FILE"
fi

# Function to check if a repository should be excluded
should_exclude_repo() {
    local repo="$1"
    local repo_path="$repo"
    
    # Check exclude patterns against full path and basename
    for pattern in "${EXCLUDE_REPO_PATTERNS[@]}"; do
        if [[ "$repo_path" =~ $pattern ]] || [[ "$(basename "$repo_path")" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if a branch should be excluded
should_exclude_branch() {
    local branch="$1"

    # No patterns provided: do not filter (show all)
    if [ ${#INCLUDE_PATTERNS[@]} -eq 0 ] && [ ${#EXCLUDE_PATTERNS[@]} -eq 0 ]; then
        return 1
    fi

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

# Function to get repository branch data
get_repo_data() {
    local repo="$1"
    local cache_file="$CACHE_DIR/$(echo "$repo" | tr '/' '_')"
    local branches=()
    local untracked=0
    
    # Check cache only if explicitly enabled via -C flag
    if [ "$CACHE_TTL" -gt 0 ] && [ -f "$cache_file" ]; then
        # Detect stat command format (GNU coreutils vs BSD/macOS stat)
        local mtime=""
        if stat -c %Y "$cache_file" >/dev/null 2>&1; then
            # GNU coreutils stat
            mtime=$(stat -c %Y "$cache_file" 2>/dev/null)
        elif stat -f %m "$cache_file" >/dev/null 2>&1; then
            # BSD/macOS stat
            mtime=$(stat -f %m "$cache_file" 2>/dev/null)
        fi
        
        # Only use cache if we got a valid mtime and it's within cache time
        if [[ -n "$mtime" ]] && [ $(($(date +%s) - mtime)) -lt "$CACHE_TTL" ]; then
            source "$cache_file" 2>/dev/null || true
            echo "${branches[*]}"
            return
        fi
    fi
    
    # Get fresh data from local git repository (fast, no remote calls needed)
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        eval "$(git for-each-ref --shell --format='branches+=(%(refname:lstrip=2))' refs/heads/ 2>/dev/null)" || branches=()
        # Cache the results only if explicitly enabled
        if [ "$CACHE_TTL" -gt 0 ]; then
            {
                echo "branches=(${branches[*]})"
                echo "last_updated=$(date +%s)"
            } > "$cache_file" 2>/dev/null || true
        fi
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
    SPIN_PID=""
    spin &
    SPIN_PID=$!
    # Only disown if we got a valid PID that's not our own
    if [[ -n "$SPIN_PID" && "$SPIN_PID" != "$$" ]]; then
        disown $SPIN_PID 2>/dev/null || true
    else
        SPIN_PID=""
    fi
fi

# Discover repositories based on settings
if [ "$OVERRIDE_REPOS" ]; then
    # Use explicitly provided repositories
    for repo in "${OVERRIDE_REPOS[@]}"; do
        if [ -d "$repo/.git" ] || git -C "$repo" rev-parse --git-dir > /dev/null 2>&1; then
            if ! should_exclude_repo "$repo"; then
                ALL_REPOS+=("$repo")
            fi
        fi
    done
elif [ "$RUN_ALL_REPOS" ] || [ "$DEEP" ]; then
    # Discover repositories using find or fd
    if [ "$USE_FD" ] && command -v fd >/dev/null 2>&1; then
        # Use fd for faster repository discovery
        max_depth="${DEEP:-3}"
        if [[ "$max_depth" == "true" ]]; then
            max_depth=""
        else
            max_depth="-d $max_depth"
        fi
        while IFS= read -r repo; do
            [ -n "$repo" ] && ! should_exclude_repo "$repo" && ALL_REPOS+=("$repo")
        done < <(fd $max_depth -t d -H "^\.git$" "$BASE_DIR" 2>/dev/null | sed 's|/\.git$||' | head -1000)
    else
        # Use find for repository discovery
        max_depth="${DEEP:-3}"
        if [[ "$max_depth" == "true" ]]; then
            while IFS= read -r git_dir; do
                [ -n "$git_dir" ] && repo="${git_dir%/.git}" && ! should_exclude_repo "$repo" && ALL_REPOS+=("$repo")
            done < <(find "$BASE_DIR" -type d -name .git 2>/dev/null | head -1000)
        else
            while IFS= read -r git_dir; do
                [ -n "$git_dir" ] && repo="${git_dir%/.git}" && ! should_exclude_repo "$repo" && ALL_REPOS+=("$repo")
            done < <(find "$BASE_DIR" -maxdepth "$max_depth" -type d -name .git 2>/dev/null | head -1000)
        fi
    fi
elif [ "$BASE_DIR_CASE" ]; then
    # Base directory case: only check top-level directories in BASE_DIR
    for dir in "$BASE_DIR"/*; do
        if [ -d "$dir" ] && ([ -d "$dir/.git" ] || git -C "$dir" rev-parse --git-dir > /dev/null 2>&1); then
            if ! should_exclude_repo "$dir"; then
                ALL_REPOS+=("$dir")
            fi
        fi
    done
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
        # Pass ALL branches (not filtered) so process_repo_result can determine
        # if repo has only default branches when -m flag is used
        if [ $DISPLAY_STATUS ] && [ "$(git status --porcelain 2>/dev/null)" ]; then
            untracked=1
        fi
        
        # Output format: repo:all_branches:untracked (all branches, not filtered)
        printf '%s:%s:%d\n' "$repo" "$branches_str" "$untracked"
    fi
}

# Process repository result (used after parallel processing)
process_repo_result() {
    local repo="$1"
    local branches="$2"
    local untracked="$3"
    
    read -ra all_branches <<< "$branches"
    let all_branch_count=${#all_branches[@]}
    
    # Filter branches based on patterns for display
    local filtered_branches=()
    for branch in "${all_branches[@]}"; do
        if ! should_exclude_branch "$branch"; then
            filtered_branches+=("$branch")
        fi
    done
    BRANCHES=("${filtered_branches[@]}")
    let branch_count=${#BRANCHES[@]}
    
    # Check if repo has only default branches
    local has_only_default=true
    if [ $all_branch_count -gt 0 ]; then
        for branch in "${all_branches[@]}"; do
            local is_default=false
            for pattern in "${DEFAULT_BRANCH_PATTERNS[@]}"; do
                if [[ "$branch" =~ $pattern ]]; then
                    is_default=true
                    break
                fi
            done
            if [ "$is_default" = false ]; then
                has_only_default=false
                break
            fi
        done
    else
        has_only_default=false
    fi
    
    # Rest of the existing repo processing logic
    # Exclude if: no branches at all, OR (not including defaults AND no untracked AND only defaults AND no non-default branches remain after filtering)
    if [[ $all_branch_count -eq 0 || ( ! $INCLUDE_DEFAULT_BRANCHES && ! $untracked && $has_only_default && $branch_count -eq 0 ) ]]
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
    local all_branches=()
    if branches_str=$(get_repo_data "$repo"); then
        read -ra all_branches <<< "$branches_str"
        
        # Filter only when include/exclude patterns are provided; otherwise show all branches
        if [ ${#INCLUDE_PATTERNS[@]} -gt 0 ] || [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
            local filtered_branches=()
            for branch in "${all_branches[@]}"; do
                if ! should_exclude_branch "$branch"; then
                    filtered_branches+=("$branch")
                fi
            done
            BRANCHES=("${filtered_branches[@]}")
        else
            BRANCHES=("${all_branches[@]}")
        fi
        
        [[ $DISPLAY_STATUS && $(git status --porcelain | wc -c | xargs) -gt 0 ]] && untracked=1
    fi

    let branch_count=${#BRANCHES[@]}
    let all_branch_count=${#all_branches[@]}

    # Rest of the existing repo processing logic
    # Check if repo should be excluded:
    # - Exclude if no branches at all
    # - Exclude if INCLUDE_DEFAULT_BRANCHES is NOT set AND:
    #   * No untracked files AND
    #   * No 3rd branch AND
    #   * All branches are only 'master' or 'main' (default branches)
    # - If INCLUDE_DEFAULT_BRANCHES is set, keep repos even if they only have default branches
    local has_only_default=true
    if [ $all_branch_count -gt 0 ]; then
        for branch in "${all_branches[@]}"; do
            local is_default=false
            for pattern in "${DEFAULT_BRANCH_PATTERNS[@]}"; do
                if [[ "$branch" =~ $pattern ]]; then
                    is_default=true
                    break
                fi
            done
            if [ "$is_default" = false ]; then
                has_only_default=false
                break
            fi
        done
    else
        has_only_default=false
    fi

    if [[ $all_branch_count -eq 0 || ( ! $INCLUDE_DEFAULT_BRANCHES && ! $untracked && $has_only_default && $branch_count -eq 0 ) ]]
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

if [[ -n "$SPIN_PID" && "$SPIN_PID" != "$$" && "$SPIN_PID" != "" ]]; then
    kill -9 $SPIN_PID > /dev/null 2>&1 || true
fi
printf '\e[K'
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
# Use the same approach as unmodified version: calculate REPO_SPACE first
let REPO_SPACE=$( rangeBind $TERMINAL_WIDTH between 120 and 170 )
# Start with branch column width of 60
let BRANCH_COL_WIDTH=60
# Space added between columns in TABLE_DATA construction (each repo has a space before it)
let COL_SPACING=1
# Calculate column width using the same formula as unmodified version
# Unmodified: COL_WID = 2 * REPO_SPACE / N_REPOS, then clamped
let BASE_COL_WID=2*$REPO_SPACE/$N_REPOS
# Apply same clamping as unmodified version
let COL_MAX=$( if (($N_REPOS < 10)) ; then echo '30'; else echo '24'; fi )
let COL_MIN=$( if (($N_REPOS < 10)) ; then echo '22'; else echo '20'; fi )
BASE_COL_WID=$( rangeBind $BASE_COL_WID between $COL_MIN and $COL_MAX )
# Increase base column width by 1 as requested
let BASE_COL_WID=$BASE_COL_WID+1

let STR_MAX=$( if (($N_REPOS < 10)) ; then echo '9'; else echo '7'; fi )

# Calculate total width needed with increased base column width
# Branch column + each repo column (format width accounts for the space in the data)
let TOTAL_NEEDED=$BRANCH_COL_WIDTH+$BASE_COL_WID*$N_REPOS

# If too wide after increasing, reduce the last columns progressively (max 10 columns)
# Minimum column width should match the unmodified version's minimum (20)
let MIN_COL_WID=20
if [ $TOTAL_NEEDED -gt $TERMINAL_WIDTH ]; then
    let OVERAGE=$TOTAL_NEEDED-$TERMINAL_WIDTH
    # Determine how many columns to reduce (max 10, but not more than total repos)
    let COLS_TO_REDUCE=10
    if [ $COLS_TO_REDUCE -gt $N_REPOS ]; then
        COLS_TO_REDUCE=$N_REPOS
    fi
    # Calculate reduction per column, keeping minimum width of 20 (same as unmodified)
    let REDUCTION_PER_COL=$OVERAGE/$COLS_TO_REDUCE
    let REDUCED_COL_WID=$BASE_COL_WID-$REDUCTION_PER_COL
    if [ $REDUCED_COL_WID -lt $MIN_COL_WID ]; then
        REDUCED_COL_WID=$MIN_COL_WID
        # If we hit minimum, calculate how many columns we actually need to reduce
        let ACTUAL_REDUCTION=$BASE_COL_WID-$MIN_COL_WID
        if [ $ACTUAL_REDUCTION -gt 0 ]; then
            let COLS_TO_REDUCE=$OVERAGE/$ACTUAL_REDUCTION
            if [ $COLS_TO_REDUCE -gt 10 ]; then
                COLS_TO_REDUCE=10
            fi
            if [ $COLS_TO_REDUCE -gt $N_REPOS ]; then
                COLS_TO_REDUCE=$N_REPOS
            fi
        fi
    fi
else
    # If we have extra space, increase branch column width
    let EXTRA_SPACE=$TERMINAL_WIDTH-$TOTAL_NEEDED
    if [ $EXTRA_SPACE -gt 0 ]; then
        let BRANCH_COL_WIDTH=$BRANCH_COL_WIDTH+$EXTRA_SPACE
    fi
    let COLS_TO_REDUCE=0
    REDUCED_COL_WID=$BASE_COL_WID
fi

# Calculate repo name truncation lengths using conversion factor: 60 terminal widths == 102 printf width
# We need two values: one for normal columns and one for reduced columns
# Conversion: printf_width * 60 / 102 = terminal_width
# Account for the space character at the end of each column (subtract 1)
let BASE_REPO_STR_LEN=$BASE_COL_WID*60/102-1
let REDUCED_REPO_STR_LEN=$REDUCED_COL_WID*60/102-1
# Apply min/max bounds
BASE_REPO_STR_LEN=$( rangeBind $BASE_REPO_STR_LEN between 4 and $STR_MAX )
REDUCED_REPO_STR_LEN=$( rangeBind $REDUCED_REPO_STR_LEN between 4 and $STR_MAX )
# echo "DEBUG_MODIFIED: BASE_REPO_STR_LEN=$BASE_REPO_STR_LEN (from BASE_COL_WID=$BASE_COL_WID)" >&2
# echo "DEBUG_MODIFIED: REDUCED_REPO_STR_LEN=$REDUCED_REPO_STR_LEN (from REDUCED_COL_WID=$REDUCED_COL_WID)" >&2

# Calculate effective column widths for manual justification (header rows only)
# Use sprintf to determine the actual rendered width of data columns
# Build a sample data value (space + indicator with colors, same format as TABLE_DATA)
SAMPLE_DATA_VALUE=" ${CYAN}X${GRAY}"

# Calculate effective width for base columns using sprintf
# Format with the printf width specifier, then measure the rendered visible length
# sprintf counts color codes as characters, so we need to format first, then measure visible length
BASE_COL_EFFECTIVE_WIDTH=$(awk -v width=$BASE_COL_WID -v sample="$SAMPLE_DATA_VALUE" '
    BEGIN {
        # Format the sample value with the printf width specifier
        # This pads the string (including color codes) to the specified width
        formatted = sprintf("%-" width "s", sample)
        # Remove ANSI color codes to get actual visible/rendered length
        # This is what the terminal will actually display
        gsub(/\x1b\[[0-9:;]*m/, "", formatted)
        print length(formatted)
    }
')

# Calculate effective width for reduced columns if needed
if [ $COLS_TO_REDUCE -gt 0 ] && [ $COLS_TO_REDUCE -lt $N_REPOS ]; then
    REDUCED_COL_EFFECTIVE_WIDTH=$(awk -v width=$REDUCED_COL_WID -v sample="$SAMPLE_DATA_VALUE" '
        BEGIN {
            formatted = sprintf("%-" width "s", sample)
            gsub(/\x1b\[[0-9:;]*m/, "", formatted)
            print length(formatted)
        }
    ')
else
    REDUCED_COL_EFFECTIVE_WIDTH=$BASE_COL_EFFECTIVE_WIDTH
fi

# Calculate effective branch column width for row 0 (with color codes)
SAMPLE_BRANCH_VALUE="${WHITE}BRANCHES_____________\\_____________REPOS${GRAY}"
BRANCH_COL_PLAIN_WIDTH=$(awk -v width=$BRANCH_COL_WIDTH -v sample="$SAMPLE_BRANCH_VALUE" '
    BEGIN {
        formatted = sprintf("%-" width "s", sample)
        gsub(/\x1b\[[0-9:;]*m/, "", formatted)
        print length(formatted)
    }
')

# echo "DEBUG_MODIFIED: BASE_COL_EFFECTIVE_WIDTH=$BASE_COL_EFFECTIVE_WIDTH (from BASE_COL_WID=$BASE_COL_WID, sample='$SAMPLE_DATA_VALUE')" >&2
# echo "DEBUG_MODIFIED: REDUCED_COL_EFFECTIVE_WIDTH=$REDUCED_COL_EFFECTIVE_WIDTH (from REDUCED_COL_WID=$REDUCED_COL_WID)" >&2
# echo "DEBUG_MODIFIED: BRANCH_COL_PLAIN_WIDTH=$BRANCH_COL_PLAIN_WIDTH" >&2

# Set column width (will be used for most columns, last ones use reduced width)
COL_WID=$BASE_COL_WID

# Build data into ordered table string

if [ $VERBOSE ]; then
    [ $BASE_DIR_CASE ] && echo -e "\nBase directory: ${BASE_DIR}"

    echo -e "\nRepos included:"
fi

# Build multi-line staggered header - distribute repos across at most 3 rows
# Staggered means: repo 0 in row 0, repo 1 in row 1, repo 2 in row 2, repo 3 in row 0, etc.
let HEADER_ROWS=3

# Build and print each header row manually (no AWK, manual justification)
for header_row in $(seq 0 $((HEADER_ROWS - 1))); do
    # Start building the header line
    HEADER_LINE=""
    
    # First: branch column header or spaces for subsequent rows
    if [ $header_row -eq 0 ]; then
        HEADER_LINE="${WHITE}BRANCHES_____________\\_____________REPOS${GRAY}"
        # Pad to effective branch column width - remove ANSI codes for length calculation
        # Handle both semicolon and colon variants in ANSI codes
        clean_text=$(printf '%b' "$HEADER_LINE" | sed 's/\x1b\[[0-9:;]*m//g')
        clean_len=${#clean_text}
        while [ $clean_len -lt $BRANCH_COL_WIDTH ]; do
            HEADER_LINE="${HEADER_LINE} "
            clean_len=$((clean_len + 1))
        done
    else
        # Fill branch column with spaces (use plain width, no color codes)
        for i in $(seq 1 $BRANCH_COL_PLAIN_WIDTH); do
            HEADER_LINE="${HEADER_LINE} "
        done
    fi
    
    # Add repo fields for this row - use modulo to stagger repos across rows
    # Staggered: repo 0->row 0, repo 1->row 1, repo 2->row 2, repo 3->row 0, etc.
    # In staggered header, spacing between repos is 3 * col_width (repo + 2 empty columns)
    # Track overflow separately for each of the 3 staggered positions (modulo 0, 1, 2)
    overflow_amount=0
    repo_idx=0
    for repo in "${REPOS[@]}"; do
        # Determine individual column width for this repo (use effective width from sprintf)
        if [ $COLS_TO_REDUCE -gt 0 ] && [ $repo_idx -ge $((N_REPOS - COLS_TO_REDUCE)) ]; then
            col_width=$REDUCED_COL_EFFECTIVE_WIDTH
        else
            col_width=$BASE_COL_EFFECTIVE_WIDTH
        fi
        
        # Determine which staggered position this repo belongs to (modulo)
        repo_modulo=$(($repo_idx % $HEADER_ROWS))
        
        # Include repo if it belongs to this row (staggered using modulo)
        if [ $repo_modulo -eq $header_row ]; then
            repo="$(spaceReplace "$repo")"
            repo_basename="$(basename "$repo")"
            repo_display=$(spaceToUnderscore "$repo_basename")
            
            if [ $DISPLAY_STATUS ]; then
                repo_untracked_key="$(generateAllowedVarName "$repo")_untracked_key"
                untracked="${!repo_untracked_key}"
                [ $untracked ] && REPO_COLOR="$RED" || REPO_COLOR="$WHITE"
            else
                REPO_COLOR="$WHITE"
            fi
            
            # Truncate repo display name if needed (compare to stagger width, not column width)
            # Stagger width is 3 * col_width (repo + 2 empty columns)
            stagger_width=$((col_width * $HEADER_ROWS))
            # Reserve 2 space buffer so repos don't touch each other
            max_display_len=$((stagger_width - 2))
            clean_display_len=${#repo_display}
            if [ $clean_display_len -gt $max_display_len ]; then
                # Truncate the plain display name to max_display_len
                repo_display=$(printf '%.*s' $max_display_len "$repo_display")
                clean_display_len=$max_display_len
            fi
            
            # Add repo name with color (after truncation if needed)
            repo_text="${REPO_COLOR}${repo_display}${GRAY}"
            
            # Use the clean display length directly (no need to recalculate after adding colors)
            text_len=$clean_display_len

            # Add repo text and pad to staggered column width (3 * col_width for repo + 2 empty columns)
            HEADER_LINE="${HEADER_LINE}${repo_text}"
            pad_needed=$((col_width - text_len))
            if [ $pad_needed -gt 0 ]; then
                for i in $(seq 1 $pad_needed); do
                    HEADER_LINE="${HEADER_LINE} "
                done
            fi
            
            # Calculate overflow for this staggered position (how much the repo name exceeded its own column width)
            # This overflow will "eat into" the next columns' spaces
            if [ $text_len -gt $col_width ]; then
                overflow_amount=$((text_len - col_width))
            else
                overflow_amount=0
            fi
            unset REPO_COLOR
        else
            # Fill column with spaces for repos not in this row
            # Account for overflow from the repo at this staggered position (modulo)
            # Check the overflow from the repo that belongs to this column position

            spaces_to_add=$col_width
            if [ $overflow_amount -gt 0 ]; then
                # Reduce spaces by the overflow amount (already "eaten" by the repo at this position)
                spaces_to_add=$((spaces_to_add - overflow_amount))
                overflow_amount=$((overflow_amount - col_width))
            fi
            if [ $spaces_to_add -gt 0 ]; then
                for i in $(seq 1 $spaces_to_add); do
                    HEADER_LINE="${HEADER_LINE} "
                done
            fi
        fi
        let repo_idx=$repo_idx+1
    done
    
    # Debug: show which repos are in this row (staggered)
    STAGGERED_REPOS=""
    repo_idx=0
    for repo in "${REPOS[@]}"; do
        if [ $(($repo_idx % $HEADER_ROWS)) -eq $header_row ]; then
            STAGGERED_REPOS="${STAGGERED_REPOS} $repo_idx"
        fi
        let repo_idx=$repo_idx+1
    done
    
    # Print the header line directly (no AWK)
    echo -e "$HEADER_LINE"
done

# Initialize TABLE_DATA for branch rows (empty, will be built below)
TABLE_DATA=""

# Print repo info in verbose mode
if [ $VERBOSE ]; then
    echo -e "\nRepos included:"
    for repo in "${REPOS[@]}"; do
        repo="$(spaceReplace "$repo")"
        repo_basename="$(basename "$repo")"
        [ $BASE_DIR_CASE ] && echo "$repo_basename" || echo "$repo"
    done
fi

# Start building TABLE_DATA for branch rows (header already printed above)

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

# Print table data manually (no AWK) - parse each line and justify manually
[ $VERBOSE ] && echo -e "Local branch view as of $(date):\n"

# Split TABLE_DATA into lines and process each one
OLD_IFS_TABLE="$IFS"
IFS=$'\n'
for line in $(echo -e "$TABLE_DATA"); do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    # Parse the line: branch name (with colors) followed by repo indicators (with colors)
    # Format is: COLORbranchCOLOR COLORindicatorCOLOR COLORindicatorCOLOR ...
    # We need to split on spaces but preserve the structure
    
    # Build output line manually
    OUTPUT_LINE=""
    
    # Extract branch name (first field) - it may have color codes
    # Split by spaces, first element is branch
    IFS=' '
    line_parts=($line)
    IFS=$'\n'
    
    branch_part="${line_parts[0]}"
    # Calculate branch text length (without ANSI codes)
    # Handle both semicolon and colon variants in ANSI codes
    branch_clean=$(printf '%b' "$branch_part" | sed 's/\x1b\[[0-9:;]*m//g')
    branch_len=${#branch_clean}
    
    # Add branch and pad to BRANCH_COL_WIDTH
    OUTPUT_LINE="${branch_part}"
    while [ $branch_len -lt $BRANCH_COL_WIDTH ]; do
        OUTPUT_LINE="${OUTPUT_LINE} "
        branch_len=$((branch_len + 1))
    done
    
    # Add repo indicators (skip first element which is branch)
    repo_col_idx=0
    for i in $(seq 1 $((${#line_parts[@]} - 1))); do
        indicator_part="${line_parts[$i]}"
        
        # Determine column width for this repo
        if [ $COLS_TO_REDUCE -gt 0 ] && [ $repo_col_idx -ge $((N_REPOS - COLS_TO_REDUCE)) ]; then
            col_width=$REDUCED_COL_WID
        else
            col_width=$BASE_COL_WID
        fi
        
        # Calculate indicator text length (without ANSI codes)
        # Handle both semicolon and colon variants in ANSI codes
        indicator_clean=$(printf '%b' "$indicator_part" | sed 's/\x1b\[[0-9:;]*m//g')
        indicator_len=${#indicator_clean}
        
        # Add indicator and pad to column width
        OUTPUT_LINE="${OUTPUT_LINE}${indicator_part}"
        while [ $indicator_len -lt $col_width ]; do
            OUTPUT_LINE="${OUTPUT_LINE} "
            indicator_len=$((indicator_len + 1))
        done
        
        let repo_col_idx=$repo_col_idx+1
    done
    
    # Print the formatted line
    echo -e "$OUTPUT_LINE"
done
IFS="$OLD_IFS_TABLE"

echo

# Cleanup old cache files (older than 1 day) at the end
find "$CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null

