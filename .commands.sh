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

git_status() { # Runs git status for all repos
  bash ~/dev_scripts/scripts/all_repo_git_status.sh
}

git_branch() { # Runs git branch for all repos
  bash ~/dev_scripts/scripts/all_repo_git_branch.sh
}

gc() { # git commit
  if not_git; then return; fi
  local args=$@
  git commit "$args"
}

gcam() { # git commit -am 'commit message'
  if not_git; then return; fi
  local COMMIT_MESSAGE="$1"
  git commit -am "$COMMIT_MESSAGE"
}

gadd() { # Adds all untracked git files
  if not_git; then return; fi
  ALL_FILES=$(git ls-files -o --exclude-standard)
  if [ -z $ALL_FILES ]; then
    echo 'No untracked files found to add'
  else
    git add "${ALL_FILES}"
  fi
}

gpcurr() { # git push origin for current branch
  if not_git; then return; fi
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$CURRENT_BRANCH"
};

gacmp() { # Adds all untracked files, commits with messsage arg, pushes current branch
  if not_git; then return; fi
  gadd
  local COMMIT_MESSAGE="$1"
  gcam "$COMMIT_MESSAGE"
  gpcurr
}

git_recent() { # Display a table of commits sorted by most recent descending
  if not_git; then return; fi
  git for-each-ref --sort=-committerdate refs/heads \
    --format='%(HEAD)%(color:yellow)%(refname:short)|%(color:bold green)%(committerdate:relative)|%(color:blue)%(subject)|%(color:magenta)%(authorname)%(color:reset)' \
    --color=always | column -ts '|'
}

git_graph() { # Prints colorful git history graph
  if not_git; then return; fi
  git log --all --decorate --oneline --graph
}

not_git() { # Checks if the current directory is not part of a git repo
  if [[ ! ( -d .git || $(git rev-parse --is-inside-work-tree 2> /dev/null) ) ]]; then
    echo 'Not a git repo'
    return 0
  else
    return 1
  fi
}

join_by() { # Joins a shell array by a text argument provided
  local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}";
}

dup_in_dir() { # Reports duplicate files and gives option for deletion
  bash ~/dev_scripts/scripts/compare_files_in_dir.sh $1
}

ls_commands() { # Lists commands in the dev_scripts/.commands.sh file
  echo
  grep '[[:alnum:]_]*()' ~/dev_scripts/.commands.sh | grep -v grep \
    | awk -F "{ #" '{printf "%20s%s\n", $1, $2}'
  echo
}

