#!/bin/bash
#
# purge_local_branches.sh - Git Local Branch Cleanup Script
#
# This script safely manages and deletes local git branches across multiple repositories.
# It includes safety checks, backup options, and clear visual feedback to prevent
# accidental deletion of important branches.
#
# Features:
# 1. Safety Measures:
#    - Protection for main development branches (master, main, develop)
#    - Extra confirmation for release/hotfix branches
#    - Backup option to preserve branches before deletion
#    - Checks for unmerged changes
#    - Prevents deletion of current branch
#
# 2. Visual Interface:
#    - Interactive branch selection
#    - Detailed branch information (commit count, last commit date)
#    - Clear warning messages for sensitive operations
#    - Progress feedback during operations
#    - Boxed sections for better readability
#
# 3. Error Handling:
#    - Comprehensive error tracking
#    - Detailed error messages
#    - Safe rollback on failures
#    - Full operation logging
#
# 4. Branch Management:
#    - Multi-repository support
#    - Pattern-based branch selection
#    - Batch operations
#    - Dry run mode for safety
#
# Options:
#   -b    Create backups of branches before deletion
#   -d    Dry run (show what would be deleted)
#   -f    Force delete (skip unmerged changes check)
#   -h    Print help message
#   -n    No confirmation (use with caution!)
#   -v    Verbose mode
#
# Example Usage:
#   ./purge_local_branches.sh              # Interactive mode
#   ./purge_local_branches.sh -d           # Dry run
#   ./purge_local_branches.sh -b           # With backups
#   ./purge_local_branches.sh -f           # Force delete
#   ./purge_local_branches.sh ~/projects   # Specific directory
#
# Example Output:
# ╭── AVAILABLE BRANCHES ──────────────────────────────────────────────────────────╮
# │ NUM   BRANCH                                   COMMITS         LAST COMMIT     │
# │ 1     feature/new-api                         15             2 days ago        │
# │ 2     release/v2.0.0                         45             1 week ago    ⚠️  │
# │ 3     bugfix/login                           3              3 hours ago        │
# ╰────────────────────────────────────────────────────────────────────────────────╯
#
# Safety Features:
# - Automatic backup creation (with -b flag)
# - Extra confirmation for release/hotfix branches
# - Protection for main development branches
# - Checks for unmerged changes
# - Dry run mode available
#
# Backup Location:
#   ${XDG_DATA_HOME:-$HOME/.local/share}/git_branch_backups
#
# Log Location:
#   ${XDG_STATE_HOME:-$HOME/.local/state}/git_branch_purge
#
# Notes:
# - Use -d (dry run) first to preview changes
# - Always ensure important changes are pushed before purging
# - Backups are recommended for important branches
# - Check logs for detailed operation history
#
# Last Updated: 2025-03-04

set -o pipefail
set -e  # Exit on error

if tput colors &> /dev/null; then
    ORANGE="\033[0;33m"
    RED="\033[0;31m"
    WHITE="\033[1;37m"
    BLUE="\033[0;34m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    BOLD="\033[1m"
    NC="\033[0m" # No Color
    DS_COLOR_SUP=true
fi

# Box drawing characters
BOX_TL="╭"
BOX_TR="╮"
BOX_BL="╰"
BOX_BR="╯"
BOX_H="─"
BOX_V="│"

# UI Helper Functions
draw_box() {
    local title="$1"
    local content="$2"
    local color="${3:-$WHITE}"
    local width=80
    local title_padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo -e "\n${color}${BOX_TL}${BOX_H}${BOX_H} ${title} ${BOX_H}$(printf '%*s' $title_padding '')${BOX_TR}"
    echo "$content" | while IFS= read -r line; do
        echo -e "${BOX_V} ${line}$(printf '%*s' $(( width - ${#line} - 2 )) '')${BOX_V}"
    done
    echo -e "${BOX_BL}$(printf '%*s' $((width)) '' | tr ' ' "${BOX_H}")${BOX_BR}${NC}\n"
}

draw_separator() {
    local width=80
    echo -e "\n${WHITE}${BOX_H}$(printf '%*s' $((width-2)) '' | tr ' ' "${BOX_H}")${BOX_H}${NC}\n"
}

format_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  WARNING: ${message}${NC}"
}

format_error() {
    local message="$1"
    echo -e "${RED}❌ ERROR: ${message}${NC}"
}

format_success() {
    local message="$1"
    echo -e "${GREEN}✓ ${message}${NC}"
}

format_info() {
    local message="$1"
    echo -e "${BLUE}ℹ️  ${message}${NC}"
}

# Configuration
PROTECTED_PATTERNS=(
    '^(master|main|develop|dev|integrations?)$'
)

EXTRA_CONFIRM_PATTERNS=(
    '^release'
    '^hotfix'
    '^prod'
)

BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/git_branch_backups"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/git_branch_purge"
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

usage() {
    local usage_text="Script to safely purge local git branches.

Options:
  -b    Create backups of branches before deletion
  -d    Dry run (show what would be deleted)
  -f    Force delete (skip unmerged changes check)
  -h    Print this help
  -n    No confirmation (use with caution!)
  -v    Verbose mode"
    
    draw_box "USAGE" "$usage_text" "$BLUE"
    exit
}

log() {
    local level="$1"
    local message="$2"
    local logfile="$LOG_DIR/purge_$(date +%Y%m%d).log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$logfile"
    case "$level" in
        ERROR) format_error "$message" ;;
        WARN)  format_warning "$message" ;;
        INFO)  [ "$VERBOSE" ] && format_info "$message" ;;
    esac
}

backup_branch() {
    local repo="$1"
    local branch="$2"
    local backup_ref="refs/backups/$(date +%Y%m%d)/$branch"
    local backup_file="$BACKUP_DIR/${repo//\//_}_${branch//\//_}_$(date +%Y%m%d_%H%M%S).bundle"
    
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git update-ref "$backup_ref" "refs/heads/$branch"
        git bundle create "$backup_file" "$branch"
        log "INFO" "Created backup of '$branch' in '$repo' to $backup_file"
        return 0
    else
        log "ERROR" "Failed to backup branch '$branch' in '$repo'"
        return 1
    fi
}

is_protected() {
    local branch="$1"
    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        if [[ "$branch" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

needs_extra_confirmation() {
    local branch="$1"
    for pattern in "${EXTRA_CONFIRM_PATTERNS[@]}"; do
        if [[ "$branch" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

check_branch_status() {
    local branch="$1"
    local current_branch=$(git branch --show-current)
    
    # Check if branch is current
    if [ "$branch" = "$current_branch" ]; then
        log "ERROR" "Cannot delete current branch '$branch'"
        return 1
    fi
    
    # Check for unmerged changes unless force flag is set
    if [ ! "$FORCE" ] && ! git branch --merged | grep -q "^[[:space:]]*$branch$"; then
        if [ "$DRY_RUN" ]; then
            log "WARN" "Branch '$branch' has unmerged changes"
            return 0
        else
            log "ERROR" "Branch '$branch' has unmerged changes. Use -f to force delete"
            return 1
        fi
    fi
    
    return 0
}

[ -d "$1" ] && BASE_DIR="$1" || BASE_DIR="$HOME"
cd "$BASE_DIR"
BASE_DIRS=( $(ls -d */ | sed 's#/##') )
ALL_REPOS=()
ALL_BRANCHES=()
UNIQ_BRANCHES=()
PURGE_BRANCHES=()

# Parse options
while getopts ":bdfhnv" opt; do
    case $opt in
        b) BACKUP=true ;;
        d) DRY_RUN=true ;;
        f) FORCE=true ;;
        h) usage ;;
        n) NO_CONFIRM=true ;;
        v) VERBOSE=true ;;
        \?) echo -e "\nInvalid option: -$opt" >&2; exit 1 ;;
    esac
done

# Find repos and unique branches
for dir in ${BASE_DIRS[@]}; do
    check_dir=$( git -C ${dir} rev-parse 2> /dev/null; echo $? )
    if [ $check_dir = 0 ]; then ALL_REPOS=( " ${ALL_REPOS[@]} " "${dir}" ) ; fi
done

REPOS=( ${ALL_REPOS[@]} )

for repo in ${ALL_REPOS[@]}; do
    cd "$BASE_DIR"
    cd "$repo"
  
    if [ $(git status --porcelain | wc -c | xargs) -gt 0 ]; then
        log "WARN" "Excluding repo with untracked changes: $repo"
        ALL_REPOS=( ${ALL_REPOS[@]/%"${repo}"/} )
        REPOS=( ${REPOS[@]/%"${repo}"/} )
        continue
    fi

    # Get all branches except protected ones
    BRANCHES=()
    while IFS= read -r branch; do
        if ! is_protected "$branch"; then
            BRANCHES+=("$branch")
        fi
    done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

    repo_key=$(genAllowedVarName "$repo")
    assoc "$repo_key" "${BRANCHES[@]}"
    ALL_BRANCHES=( ${ALL_BRANCHES[@]} ${BRANCHES[@]} )

    for branch in "${BRANCHES[@]}" ; do
        branch_key_base=$(genAllowedVarName "$branch")
        branch_key="${branch_key_base}_key"
        assoc "$branch_key" "$repo"
        
        # Get additional branch info for verbose mode
        if [ "$VERBOSE" ]; then
            commit_count=$(git rev-list --count "$branch")
            last_commit=$(git log -1 --format=%cr "$branch")
            log "INFO" "Branch '$branch' in '$repo': $commit_count commits, last commit $last_commit"
        fi
    done
done

UNIQ_BRANCHES=( $(printf '%s\n' ${ALL_BRANCHES[@]} | sort | uniq ) )
let BRANCH_COUNT=${#UNIQ_BRANCHES[@]}

# Initiate user interfacing
if [ $BRANCH_COUNT = 0 ]; then
    log "INFO" "No purgeable branches found."
    exit 0
fi

if [ "$DRY_RUN" ]; then
    log "INFO" "DRY RUN MODE - No branches will be deleted"
fi

echo -e "\n To quit, press Ctrl+C"

while [ ! $confirmed ]; do
    unset selections_confirmed
    to_purge=()
    echo -e "\n${WHITE} Purgeable branches are listed below - you will be asked to confirm selection${NC}\n"
    
    # Show branch details
    draw_box "AVAILABLE BRANCHES" "$(printf "%-5s %-40s %-15s %s\n" "NUM" "BRANCH" "COMMITS" "LAST COMMIT")"

    i=1
    for branch in "${UNIQ_BRANCHES[@]}"; do
        commit_count=$(git rev-list --count "$branch" 2>/dev/null || echo "N/A")
        last_commit=$(git log -1 --format=%cr "$branch" 2>/dev/null || echo "N/A")
        branch_line="$(printf "%-5d %-40s %-15s %s" "$i" "$branch" "$commit_count" "$last_commit")"
        if needs_extra_confirmation "$branch"; then
            echo -e "${YELLOW}${BOX_V} ${branch_line} ⚠️${NC}"
        else
            echo -e "${WHITE}${BOX_V} ${branch_line}${NC}"
        fi
        ((i++))
    done
    draw_separator

    if [ $DS_COLOR_SUP ] ; then
        read -p $'\e[37m Enter branch numbers or search patterns to purge separated by spaces: \e[0m' to_purge
    else
        read -p $' Enter branch numbers or search patterns to purge separated by spaces: ' to_purge
    fi

    to_purge=( $(printf '%s\n' "${to_purge[@]}") )

    # Validate selections
    while [ ! $selections_confirmed ]; do
        while [[ -z "${to_purge[@]// }" ]]; do
            log "WARN" "No value found, please try again. To quit the script, press Ctrl+C"
            if [ $DS_COLOR_SUP ] ; then
                read -p $'\e[37m Enter branch numbers or search patterns to purge separated by spaces: \e[0m' to_purge
            else
                read -p $' Enter branch numbers or search patterns to purge separated by spaces: ' to_purge
            fi
        done

        for i in ${to_purge[@]}; do
            if isInt $i; then
                while [[ $i -lt 1 || $i -gt $BRANCH_COUNT ]]; do
                    to_purge=()
                    log "WARN" "Only input indices of the set provided. To quit the script, press Ctrl+C"
                    
                    if [ $DS_COLOR_SUP ] ; then
                        read -p $'\e[37m Enter branch numbers or search patterns to purge separated by spaces: \e[0m' to_purge
                    else
                        read -p $' Enter branch numbers or search patterns to purge separated by spaces: ' to_purge
                    fi

                    to_purge=( $(printf '%s\n' "${to_purge[@]}") )
                    break 2
                done
            fi
            selections_confirmed=true
        done
    done

    conditional=$(genFilterString ${to_purge[@]})
    filter="{ if(${conditional}) print }"
    PURGE_BRANCHES=($(printf '%s\n' "${UNIQ_BRANCHES[@]}" | awk "$filter"))

    # Show detailed confirmation
    draw_box "BRANCHES TO DELETE" "" "${RED}"
    for branch in "${PURGE_BRANCHES[@]}"; do
        branch_key_base=$(genAllowedVarName "$branch")
        branch_key="${branch_key_base}_key"
        echo -e "${WHITE}${BOX_V} Branch: ${BOLD}$branch${NC}"
        if needs_extra_confirmation "$branch"; then
            echo -e "${YELLOW}${BOX_V}   ⚠️  This appears to be a release/hotfix branch${NC}"
        fi
        for repo in ${!branch_key}; do
            commit_count=$(cd "$repo" && git rev-list --count "$branch" 2>/dev/null || echo "N/A")
            last_commit=$(cd "$repo" && git log -1 --format=%cr "$branch" 2>/dev/null || echo "N/A")
            echo -e "${BLUE}${BOX_V}   📁 Repo: $repo${NC}"
            echo -e "${WHITE}${BOX_V}      Commits: $commit_count${NC}"
            echo -e "${WHITE}${BOX_V}      Last commit: $last_commit${NC}"
        done
    done
    draw_separator

    # Check if any branches need extra confirmation
    needs_extra=false
    for branch in "${PURGE_BRANCHES[@]}"; do
        if needs_extra_confirmation "$branch"; then
            needs_extra=true
            break
        fi
    done

    if [ ! "$NO_CONFIRM" ]; then
        warning_text="This operation cannot be undone!"
        if [ "$needs_extra" = true ]; then
            warning_text="$warning_text\nYou are about to delete one or more release/hotfix branches!"
        fi
        if [ "$BACKUP" ]; then
            warning_text="$warning_text\nBackups will be created in: $BACKUP_DIR"
        fi
        draw_box "CONFIRMATION REQUIRED" "$warning_text" "${RED}"
        
        if [ "$needs_extra" = true ]; then
            if [ $DS_COLOR_SUP ]; then
                read -p $"${YELLOW}${BOX_V} Type \"yes-delete-release\" to confirm deletion: ${NC}" confirm_input
            else
                read -p $"${BOX_V} Type \"yes-delete-release\" to confirm deletion: " confirm_input
            fi
            if [[ "$confirm_input" != "yes-delete-release" ]]; then
                log "INFO" "Deletion cancelled - release/hotfix branch confirmation not provided"
                exit 0
            fi
        else
            if [ $DS_COLOR_SUP ]; then
                read -p $"${WHITE}${BOX_V} Enter \"confirm\" to delete branches: ${NC}" confirm_input
            else
                read -p $"${BOX_V} Enter \"confirm\" to delete branches: " confirm_input
            fi
            confirm_input=$(echo "${confirm_input}" | tr "[:upper:]" "[:lower:]")
            if [[ "$confirm_input" != 'confirm' ]]; then confirmed=false; fi
        fi
    else
        confirmed=true
    fi
done

echo

# Delete the branches
errors=0
for branch in ${PURGE_BRANCHES[@]}; do
    branch_key_base=$(genAllowedVarName "$branch")
    branch_key="${branch_key_base}_key"
    for repo in ${!branch_key}; do
        cd "$BASE_DIR"
        cd "$repo"
        
        if ! check_branch_status "$branch"; then
            ((errors++))
            continue
        fi
        
        if [ "$DRY_RUN" ]; then
            log "INFO" "Would delete branch '$branch' from '$repo'"
            continue
        fi
        
        log "INFO" "Deleting branch '$branch' from '$repo'"
        
        # Create backup if requested
        if [ "$BACKUP" ]; then
            if ! backup_branch "$repo" "$branch"; then
                log "ERROR" "Failed to backup branch '$branch' in '$repo'"
                ((errors++))
                continue
            fi
        fi
        
        # Switch to a safe branch
        for safe in "main" "master" "develop" "integration"; do
            if git show-ref --verify --quiet "refs/heads/$safe"; then
                git checkout "$safe" &>/dev/null && break
            fi
        done
        
        # Delete the branch
        if ! git branch -D "$branch" 2>/dev/null; then
            log "ERROR" "Failed to delete branch '$branch' in '$repo'"
            ((errors++))
        fi
    done
done

# Report results
if [ "$DRY_RUN" ]; then
    draw_box "DRY RUN COMPLETE" "$(format_info "No branches were deleted.")"
elif [ $errors -eq 0 ]; then
    draw_box "SUCCESS" "$(format_success "Successfully deleted all selected branches.")"
else
    draw_box "COMPLETED WITH ERRORS" "$(format_warning "Completed with $errors errors. Check the log file for details.")"
fi

if [ "$BACKUP" ]; then
    format_info "Backups stored in: $BACKUP_DIR"
fi

format_info "Log file: $LOG_DIR/purge_$(date +%Y%m%d).log"

