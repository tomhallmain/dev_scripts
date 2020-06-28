#!/bin/bash

lbv() { # Generates a cross table of git repos vs branches
  if [ -z $1 ] ; then
    bash ~/dev_scripts/scripts/local_branch_view.sh
  else
    local flags=$1
    bash ~/dev_scripts/scripts/local_branch_view.sh "$flags"
  fi
}

plb() { # Purges a branch name from all git repos associated
  bash ~/dev_scripts/scripts/purge_local_branches.sh
}

env_refresh() { # Pulls latest master branch for all git repos
  bash ~/dev_scripts/scripts/local_env_refresh.sh
}

all_status() {
  bash ~/dev_scripts/scripts/all_repo_git_status.sh
}

all_branch() {
  bash ~/dev_scripts/scripts/all_repo_git_branch.sh
}

join_by() { # Joins a shell array by a text argument provided
  local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}";
}

dup_in_dir() { # Reports duplicate files and gives option for deletion
  bash ~/dev_scripts/scripts/compare_files_in_dir.sh $1
}

gc() {
  local args=$@
  git commit "$args"
}

gcam() {
  local message="$1"
  git commit -am "$message"
}

gadd_all() {
  ALL_FILES=$(git ls-files -o --exclude-standard)
  git add "${ALL_FILES}"
}

gpcurr() {
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$CURRENT_BRANCH"
};

gacmp() { # Adds all untracked files, commits with messsage arg, pushes current branch
  gadd_all
  local message="$1"
  gcam "$message"
  gpcurr
}


