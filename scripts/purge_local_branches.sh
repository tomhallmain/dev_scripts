#!/bin/bash
set -o pipefail

if tput colors &> /dev/null; then
    ORANGE="\033[0;33m"
    RED="\033[0;31m"
    WHITE="\033[1;37m"
    BLUE="\033[0;34m"
    GREEN="\033[0;32m"
    NC="\033[0m" # No Color
    DS_COLOR_SUP=true
fi

[ -d "$1" ] && BASE_DIR="$1" || BASE_DIR="$HOME"
cd "$BASE_DIR"
BASE_DIRS=( $(ls -d */ | sed 's#/##') )
ALL_REPOS=()
ALL_BRANCHES=()
UNIQ_BRANCHES=()
PURGE_BRANCHES=()
master='^(master|main|develop|dev|integrations?)$'

# Methods

genAllowedVarName() {
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
isInt() {
    local test="$1"
    local n_re="^[0-9]+$"
    [[ "$test" =~ $n_re ]]
}
assoc() {
    # Bash 3 doesn't support hashes
    local key="${1}"
    local addvals="${@:2}"
    printf -v "${key}" %s " ${!key} ${addvals[@]} "
}
genFilterString() {
    local matches=(" ${@} ")
    let local length=${#matches[@]}
    let local last_match=length-1
    for ((i=0; i<$length; i++)) ; do
        local match="$(echo "${matches[$i]}" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print}')"
        if isInt "$match"; then
            str="${str}(NR==${match})"
        else
            str="${str}(\$0~/${match}/)"
        fi
        if [ $i -lt $last_match ]; then str="${str} || "; fi
    done
    printf '%s\n' "${str}"
}


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
        echo -e "${ORANGE} Excluding repo with untracked changes: $repo ${NC}"
        ALL_REPOS=( ${ALL_REPOS[@]/%"${repo}"/} )
        REPOS=( ${REPOS[@]/%"${repo}"/} )
        continue
    fi

    # Note common master branches removed to disallow their deletion
    BRANCHES=($(git for-each-ref --format='%(refname:lstrip=2)' refs/heads/ | grep -Ev "$master"))

    repo_key=$(genAllowedVarName "$repo")
    assoc "$repo_key" "${BRANCHES[@]}"
    ALL_BRANCHES=( ${ALL_BRANCHES[@]} ${BRANCHES[@]} )

    for branch in "${BRANCHES[@]}" ; do
        # shell doesn't allow hyphens in variable names, and Bash 3 doesn't support associative arrays
        branch_key_base=$(genAllowedVarName "$branch")
        branch_key="${branch_key_base}_key"

        assoc "$branch_key" "$repo"
    done
done

UNIQ_BRANCHES=( $(printf '%s\n' ${ALL_BRANCHES[@]} | sort | uniq ) )
let BRANCH_COUNT=${#UNIQ_BRANCHES[@]}


# Initiate user interfacing

if [ $BRANCH_COUNT = 0 ]; then
    echo -e "\n${ORANGE} No purgeable branches found.${NC}\n"
    exit 1
fi

echo -e "\n To quit, press Ctrl+C"

while [ ! $confirmed ]; do
    unset selections_confirmed
    to_purge=()
    echo -e "\n${WHITE} Purgeable branches are listed below - you will be asked to confirm selection${NC}\n"
    printf '%s\n' "${UNIQ_BRANCHES[@]}" | awk '{printf "%5s  %s\n", NR, $0}'
    echo
    if [ $DS_COLOR_SUP ] ; then
        read -p $'\e[37m Enter branch numbers or search patterns to purge separated by spaces: \e[0m' to_purge
    else
        read -p $' Enter branch numbers or search patterns to purge separated by spaces: ' to_purge
    fi

    to_purge=( $(printf '%s\n' "${to_purge[@]}") )

    while [ ! $selections_confirmed ]; do
        while [[ -z "${to_purge[@]// }" ]]; do
            echo -e "\n${ORANGE} No value found, please try again. To quit the script, press Ctrl+C${NC}\n"
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
                    echo -e "\n${ORANGE} Only input indices of the set provided. To quit the script, press Ctrl+C${NC}\n"
                    
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

    echo -e "\n${ORANGE} Confirm branch purge selection below - BE CAREFUL, confirmation will attempt local deletion in all repos!${NC}\n"
    
    if [ $DS_COLOR_SUP ]; then
        printf '\e[31m%s\n\e[0m' "${PURGE_BRANCHES[@]}" | awk '{print " " $1}'
        read -p $'\e[37m Enter "confirm" to delete branches: \e[0m' confirm_input
    else
        printf '%s\n' "${PURGE_BRANCHES[@]}" | awk '{print " " $1}'
        read -p $' Enter "confirm" to delete branches: ' confirm_input
    fi

    confirm_input=$(echo "${confirm_input}" | tr "[:upper:]" "[:lower:]")
    if [[ "$confirm_input" = 'confirm' ]]; then confirmed=true; continue; fi

    echo -e "\n${ORANGE} Selection not confirmed. Would you like to modify your selection?${NC}\n"
    
    if [ $DS_COLOR_SUP ]; then
        read -p $'\e[37m Enter "y" to modify selection or "continue" to proceed with current purge selection: \e[0m' modify
    else
        read -p $' Enter "y" to modify selection or "continue" to proceed with current purge selection: ' modify
    fi

    modify=$(echo "${modify}" | tr "[:upper:]" "[:lower:]")

    if [ "${modify}" = 'y' ]; then continue
    elif [ "${modify}" = 'continue' ]; then confirmed=true
    else
        echo -e "\n${RED} Input not understood and selection unconfirmed - exiting${NC}"
        exit 1
    fi
done

echo

# Delete the branches

for branch in ${PURGE_BRANCHES[@]}; do
    branch_key_base=$(genAllowedVarName "$branch")
    branch_key="${branch_key_base}_key"
    for repo in ${!branch_key}; do
        echo -e "${WHITE}Deleting ${branch} from ${repo}${NC}"
        cd "$BASE_DIR"
        cd "$repo"
        repo_key="$(genAllowedVarName "$repo")"
        REPO_BRANCHES="${!repo_key}"
        if echo "$REPO_BRANCHES" | grep -q master; then
            git checkout master
        elif echo "$REPO_BRANCHES" | grep -q main; then
            git checkout main
        elif echo "$REPO_BRANCHES" | grep -q develop; then
            git checkout develop
        elif echo "$REPO_BRANCHES" | grep -q integration; then
            git checkout integration
        else
            git checkout master
        fi
        unset delete_issue
        git branch -D "$branch" || delete_issue=0
        [ "$delete_issue" ] && _delete_issue=0
        [ "$delete_issue" ] && git show-ref "refs/heads/$branch" 2>/dev/null | grep -q "$branch" || unset delete_issue
        [ "$delete_issue" ] && echo "${RED} Encountered an issue deleting branch $branch in repo $repo ${NC}"
    done
done


# Report success

[ "$_delete_issue" ] || echo -e "\n${GREEN} Successfully deleted selected local branches.${NC}\n"

