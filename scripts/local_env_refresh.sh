#!/bin/bash
set -o pipefail
cd ~

CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
RED="\033[0;31m"
BLUE="\033[0;34m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

[ "$1" ] && BASE_DIR="$1" || BASE_DIR="$HOME"
cd "$BASE_DIR"

BASE_DIRS=($(ls -d */ | sed 's#/##'))
REPOS=()

arrayContains() {
  local pattern="$1"
  shift
  local idx=$(printf "%s\n" "$@" | awk "/$pattern/{print NR-1; exit}")
  [ "$idx" = "" ] && return 1
}

refreshBranch() {
  local repo="$1" branch ="$2"
  git checkout "$branch"
  git pull
  wait
  echo -e "${CYAN} Git pull done for $branch on $repo ${NC}"
  if [ -f 'Gemfile' ]; then
    echo -e "${BLUE} Running bundle install for $branch on $repo ${NC}"
    bundle install &> /dev/null || continue
    if [ -d 'db/migrate' ]; then
      echo -e "${BLUE} Running db migration for $branch on $repo ${NC}"
      rake db:migrate RAILS_ENV=development &> /dev/null
      rake db:migrate RAILS_ENV=test &> /dev/null
    fi
  fi
  if [ -f 'yarn.lock' ]; then
    echo -e "${MAGENTA} Running yarn for ${repo} ${NC}"
    yarn &> /dev/null || continue
  fi
}

for dir in ${BASE_DIRS[@]} ; do
  git -C "$dir" rev-parse &> /dev/null && REPOS=(" ${REPOS[@]} " "$dir")
done

for repo in ${REPOS[@]}; do
  cd "$BASE_DIR"
  cd "$repo"
  if [ $(git status --porcelain | wc -c) -gt 0 ]; then
    echo -e "${RED} No pull for ${repo} as it contains untracked changes! ${NC}"
    continue
  fi
  echo -e "${MAGENTA} Pulling latest for ${repo} ${NC}\n"
  BRANCHES=($(git for-each-ref --format='%(refname:short)' refs/heads))
  arrayContains "master" ${BRANCHES[@]} && refreshBranch "$repo" "master"
  arrayContains "main" ${BRANCHES[@]} && refreshBranch "$repo" "main"
  arrayContains "develop" ${BRANCHES[@]} && refreshBranch "$repo" "develop"
  arrayContains "integration" ${BRANCHES[@]} && refreshBranch "$repo" "integration"
  echo -e "${GREEN} Done with ${repo}! ${NC}"
done
echo -e "\n\n${CYAN}--------------------------------------${NC}\n\n"
