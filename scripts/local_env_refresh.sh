#!/bin/bash
#
# local_env_refresh.sh - Git Local Environment Refresh Script
# 
# This script provides a robust way to refresh multiple git repositories in a directory.
# It includes comprehensive error handling, clear visual feedback, and detailed logging
# of all operations.
#
# Features:
# 1. Error Handling and Reporting:
#    - Tracks success, failure, and skip status for each repo
#    - Collects detailed error messages
#    - Provides a summary at the end with statistics
#    - Returns non-zero exit code if any repos failed
#
# 2. Visual Feedback:
#    - Color-coded output for different message types
#    - Progress indicators for long operations
#    - Icons for different status types:
#      ✓ Success
#      ✖ Error
#      ⚠ Warning
#      ℹ Info
#
# 3. Functionality:
#    - Option to update all branches or just current branch
#    - Force update option to reset to remote version
#    - Progress display option for real-time feedback
#    - Quiet mode for CI/CD environments
#
# 4. Logging:
#    - Detailed timestamped logs
#    - Separate log file for each run
#    - Organized log directory structure
#    - Both console and file logging
#
# Example Usage:
#   ./local_env_refresh.sh                  # Refresh current directory
#   ./local_env_refresh.sh -ap ~/dev        # Refresh all branches with progress
#   ./local_env_refresh.sh -fq              # Force refresh with minimal output
#   ./local_env_refresh.sh -h               # Show help
#
# Example Output:
#   ℹ Starting refresh in /home/user/dev
#   ✓ Updated project1
#   ⚠ Skipping project2: uncommitted changes
#   ✖ Failed to update project3
#
#   Operation Summary:
#   Results:
#     ✓ Successful: 1
#     ✖ Failed: 1
#     ⚠ Skipped: 1
#     Total: 3
#
#   Details:
#     ✖ project3: Failed to fetch from remote
#     ⚠ project2: Uncommitted changes present
#
# Last Updated: 2025-03-04

set -o pipefail
set -e  # Exit on error

# Color and formatting
if tput colors &> /dev/null; then
    BOLD="\033[1m"
    DIM="\033[2m"
    ITALIC="\033[3m"
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    MAGENTA="\033[0;35m"
    CYAN="\033[0;36m"
    WHITE="\033[1;37m"
    GRAY="\033[0;90m"
    NC="\033[0m"
fi

# Logging setup
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/git_refresh"
LOG_FILE="$LOG_DIR/refresh_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Operation tracking
declare -A REPO_STATUS
declare -A REPO_MESSAGES
TOTAL_REPOS=0
SUCCESSFUL_REPOS=0
FAILED_REPOS=0
SKIPPED_REPOS=0

usage() {
    cat << EOF
${BOLD}Git Local Environment Refresh${NC}

Refreshes all git repositories in the specified directory by:
1. Fetching latest changes
2. Pruning deleted remote branches
3. Updating current branch if clean
4. Reporting status of all operations

${BOLD}Usage:${NC}
  $(basename "$0") [options] [directory]

${BOLD}Options:${NC}
  -a    Attempt to update all branches, not just current
  -f    Force update (reset to remote version)
  -p    Show progress during operations
  -q    Quiet mode (only show errors)
  -h    Show this help message

${BOLD}Examples:${NC}
  $(basename "$0") ~/dev           # Refresh repos in ~/dev
  $(basename "$0") -a .           # Refresh all branches in current directory
  $(basename "$0") -f ~/projects  # Force refresh repos in ~/projects

${ITALIC}${GRAY}Logs are stored in: $LOG_DIR${NC}
EOF
    exit 0
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        ERROR)   [[ ! $QUIET ]] && echo -e "${RED}✖ $message${NC}" ;;
        WARNING) [[ ! $QUIET ]] && echo -e "${YELLOW}⚠ $message${NC}" ;;
        SUCCESS) [[ ! $QUIET ]] && echo -e "${GREEN}✓ $message${NC}" ;;
        INFO)    [[ ! $QUIET ]] && echo -e "${BLUE}ℹ $message${NC}" ;;
        DETAIL)  [[ ! $QUIET ]] && echo -e "${GRAY}  $message${NC}" ;;
    esac
}

show_progress() {
    [[ ! $PROGRESS ]] && return
    local repo="$1"
    local operation="$2"
    local status="$3"
    local color="$BLUE"
    [[ $status == "done" ]] && color="$GREEN"
    [[ $status == "error" ]] && color="$RED"
    echo -e "\r${GRAY}[$repo] ${color}$operation${NC}                    "
}

update_repo() {
    local repo="$1"
    local repo_path="$2"
    cd "$repo_path"
    
    # Track repo status
    REPO_STATUS[$repo]="processing"
    REPO_MESSAGES[$repo]=""
    ((TOTAL_REPOS++))
    
    # Check if repo is clean
    if [[ $(git status --porcelain) ]]; then
        log "WARNING" "Skipping $repo: uncommitted changes"
        REPO_STATUS[$repo]="skipped"
        REPO_MESSAGES[$repo]="Uncommitted changes present"
        ((SKIPPED_REPOS++))
        return
    }
    
    # Store current branch
    local current_branch=$(git branch --show-current)
    
    # Fetch and prune
    show_progress "$repo" "Fetching" "running"
    if ! git fetch --prune &>> "$LOG_FILE"; then
        log "ERROR" "Failed to fetch $repo"
        REPO_STATUS[$repo]="failed"
        REPO_MESSAGES[$repo]="Failed to fetch from remote"
        show_progress "$repo" "Fetching" "error"
        ((FAILED_REPOS++))
        return
    fi
    show_progress "$repo" "Fetching" "done"
    
    # Update branches
    if [[ $UPDATE_ALL ]]; then
        show_progress "$repo" "Updating branches" "running"
        local branches=$(git branch --format='%(refname:short)')
        for branch in $branches; do
            git checkout "$branch" &>> "$LOG_FILE"
            if [[ $FORCE ]]; then
                if ! git reset --hard "origin/$branch" &>> "$LOG_FILE"; then
                    REPO_MESSAGES[$repo]+="Failed to reset $branch. "
                fi
            else
                if ! git merge --ff-only "origin/$branch" &>> "$LOG_FILE"; then
                    REPO_MESSAGES[$repo]+="Failed to update $branch. "
                fi
            fi
        done
        git checkout "$current_branch" &>> "$LOG_FILE"
        show_progress "$repo" "Updating branches" "done"
    else
        show_progress "$repo" "Updating current branch" "running"
        if [[ $FORCE ]]; then
            if ! git reset --hard "origin/$current_branch" &>> "$LOG_FILE"; then
                log "ERROR" "Failed to reset $repo"
                REPO_STATUS[$repo]="failed"
                REPO_MESSAGES[$repo]="Failed to reset to remote version"
                show_progress "$repo" "Updating current branch" "error"
                ((FAILED_REPOS++))
                return
            fi
        else
            if ! git merge --ff-only "origin/$current_branch" &>> "$LOG_FILE"; then
                log "ERROR" "Failed to update $repo"
                REPO_STATUS[$repo]="failed"
                REPO_MESSAGES[$repo]="Failed to fast-forward merge"
                show_progress "$repo" "Updating current branch" "error"
                ((FAILED_REPOS++))
                return
            fi
        fi
        show_progress "$repo" "Updating current branch" "done"
    fi
    
    # Success
    REPO_STATUS[$repo]="success"
    ((SUCCESSFUL_REPOS++))
    log "SUCCESS" "Updated $repo"
}

print_summary() {
    echo
    log "INFO" "Operation Summary:"
    echo -e "${BOLD}${WHITE}Results:${NC}"
    echo -e "  ${GREEN}✓ Successful: $SUCCESSFUL_REPOS${NC}"
    echo -e "  ${RED}✖ Failed: $FAILED_REPOS${NC}"
    echo -e "  ${YELLOW}⚠ Skipped: $SKIPPED_REPOS${NC}"
    echo -e "  ${BLUE}Total: $TOTAL_REPOS${NC}"
    
    if [[ $FAILED_REPOS -gt 0 || $SKIPPED_REPOS -gt 0 ]]; then
        echo
        echo -e "${BOLD}${WHITE}Details:${NC}"
        for repo in "${!REPO_STATUS[@]}"; do
            case ${REPO_STATUS[$repo]} in
                failed)
                    echo -e "  ${RED}✖ $repo${NC}: ${REPO_MESSAGES[$repo]}"
                    ;;
                skipped)
                    echo -e "  ${YELLOW}⚠ $repo${NC}: ${REPO_MESSAGES[$repo]}"
                    ;;
            esac
        done
    fi
    
    echo
    log "INFO" "Log file: $LOG_FILE"
}

# Parse options
while getopts ":afpqh" opt; do
    case $opt in
        a) UPDATE_ALL=true ;;
        f) FORCE=true ;;
        p) PROGRESS=true ;;
        q) QUIET=true ;;
        h) usage ;;
        \?) echo -e "\n${RED}Invalid option: -$OPTARG${NC}" >&2; exit 1 ;;
    esac
done
shift $((OPTIND-1))

# Set target directory
TARGET_DIR="${1:-$PWD}"
cd "$TARGET_DIR"

log "INFO" "Starting refresh in $TARGET_DIR"
[[ $UPDATE_ALL ]] && log "INFO" "Updating all branches"
[[ $FORCE ]] && log "WARNING" "Force mode enabled - will reset to remote versions"

# Find and process git repositories
while IFS= read -r -d '' repo_path; do
    repo_name=${repo_path#"$TARGET_DIR/"}
    repo_name=${repo_name%/.git}
    update_repo "$repo_name" "${repo_path%/.git}"
done < <(find "$TARGET_DIR" -name .git -type d -print0)

print_summary

# Exit with error if any repos failed
[[ $FAILED_REPOS -gt 0 ]] && exit 1
exit 0
