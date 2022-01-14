#!/bin/bash
#
# Script to select and check out a branch based on a pattern

ORANGE="\033[0;33m"
WHITE="\033[1;37m"
NC="\033[0m" # No Color
int_re='^[0-9]+$'

testInt() {
    unset confirmed selections_confirmed
    local to_ck="$1" n_matches="$2"
    while [ ! $selections_confirmed ]; do
        while [ -z "$to_ck" ]; do
            echo -e "\n${ORANGE} No value found, please try again or quit by Ctrl+C${NC}\n"
            read -p $'\e[37;1m Enter branch number to check out: \e[0m' to_ck
        done

        if [[ -z "$to_ck" || ! "$to_ck" =~ $int_re || "$to_ck" -lt 1  || $to_ck -gt $n_matches ]]; then
            echo -e "\n${ORANGE} Only input indices of the set provided - to quit enter Ctrl+C${NC}\n"
            break 1
        fi
        selections_confirmed=true
        confirmed=true
    done
}
isInt() {
    local test="$1"
    local n_re="^[0-9]+$"
    [[ "$test" =~ $n_re ]]
}

if [[ ! ( -d .git || $(git rev-parse --is-inside-work-tree 2> /dev/null) ) ]]; then
    echo 'Current location is not a git directory'
    exit 1
fi

if [ $(git status --porcelain | wc -c | xargs) -gt 0 ]; then
    echo -e "${ORANGE}Untracked changes found!${NC}"
    echo
    read -p $'\e[37;1m To stash untracked changes on the current branch, enter "stash": \e[0m' confirm
    if [ "$confirm" = 'stash' ]; then
        git stash
    else
        exit 1
    fi
fi

if [ "$2" ]; then
    git checkout -b "$1"
fi

LOCAL_BRANCHES=($(git for-each-ref --format='%(refname:short)' refs/heads 2> /dev/null | sort))

if [ "$1" ]; then
    MATCH_BRANCHES=($(printf "%s\n" "${LOCAL_BRANCHES[@]}" | awk -v search="$1" '$0 ~ search {print}'))
else
    n_matches="${#LOCAL_BRANCHES[@]}"
    while [ ! $confirmed ]; do
        printf "%s\n" "${LOCAL_BRANCHES[@]}" | awk '{printf "%5s  %s\n", NR, $0}'
        echo
        read -p $'\e[37;1m Enter branch number or pattern to check out: \e[0m' to_ck
        if isInt "$to_ck"; then
            testInt "$to_ck" $n_matches
        else
            branch="$(printf "%s\n" "${LOCAL_BRANCHES[@]}" | awk -v search="$to_ck" '$0~search {print; exit}')"
            [ "$branch" ] && confirmed=0
        fi
    done
    if isInt "$to_ck"; then
        let to_ck--; branch="${LOCAL_BRANCHES[$to_ck]}"
    fi
    git checkout "$branch" && exit
fi

let n_matches=${#MATCH_BRANCHES[@]}

if [[ -z $n_matches || $n_matches -lt 1 ]]; then
    read -p $'\e[37;1m No local branches found for search on current repo. Search remote or checkout new branch (r[emote]/n[ew branch]): \e[0m' choice
    choice="$(echo "${choice}" | tr -d " " | tr "[:upper:]" "[:lower:]")"
    if echo "newbranch" | grep -Eq "^$choice" 2>/dev/null; then
        git checkout -b "$1"
        exit
    elif echo "remote" | grep -Eq "^$choice" 2>/dev/null; then
        git fetch &>/dev/null || exit 1
        REMOTE_BRANCHES=($(git for-each-ref --format="%(refname:short)" refs/remotes 2> /dev/null \
                | sed 's:^origin/::g' | grep -Ev -e HEAD -e "^[0-9]+$"))
        REMOTE_BRANCHES=($(awk 'FNR==NR{_[$0]=1} FNR<NR{if(!($0 in _))print}' \
                <(printf "%s\n" "${LOCAL_BRANCHES[@]}") \
                <(printf "%s\n" "${REMOTE_BRANCHES[@]}") | sort))
        MATCH_BRANCHES=($(printf "%s\n" "${REMOTE_BRANCHES[@]}" | awk -v search="$1" '$0 ~ search {print}'))
    else
        exit 1
    fi
fi

let n_matches=${#MATCH_BRANCHES[@]}

if [[ -z $n_matches || $n_matches -lt 1 ]]; then
    echo -e "${ORANGE} No remote branches found for search pattern on current repo\n" && exit 1
elif [ $n_matches -eq 1 ]; then
    branch="$MATCH_BRANCHES"
    git checkout "$branch" && exit
else
    unset confirmed
    while [ ! $confirmed ]; do
        echo 'Multiple branches found matching search:'
        printf "%s\n" "${MATCH_BRANCHES[@]}" | awk '{printf "%5s  %s\n", NR, $0}'
        echo
        read -p $'\e[37;1m Enter branch number or pattern to check out: \e[0m' to_ck
        if isInt "$to_ck"; then
            testInt "$to_ck" $n_matches
        else
            branch="$(printf "%s\n" "${MATCH_BRANCHES[@]}" | awk -v search="$to_ck" '$0~search {print; exit}')"
            [ "$branch" ] && confirmed=0
        fi
    done
    if isInt "$to_ck"; then
        let to_ck--; branch="${MATCH_BRANCHES[$to_ck]}"
    fi
    git checkout "$branch" && exit
fi

[ $? -gt 0 ] && echo "Possible issue encountered while checking out branch ${branch}" && exit 1
