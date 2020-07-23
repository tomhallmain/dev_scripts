#!/bin/bash

name_set() { # Test if a name (function, alias, etc) is defined
  local name="$1"
  which $name &> /dev/null
}

which_sh() { # Print the shell being used
  ps -ef | awk '$2==pid {print $NF}' pid=$$
}

mktmp() { # mktemp -q "/tmp/${filename}"
  local filename=$1
  mktemp -q "/tmp/${filename}.XXXXX"
}

duplicate_input() { # Duplicate input sent to stdin in aggregate
  tee /tmp/showlater && cat /tmp/showlater && rm /tmp/showlater
}

data_in() { # Detect if data is being received from stdin via a pipe
  [ -p /dev/stdin ]
}

join_by() { # Join a shell array by a text argument provided
  local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}";
}

not_git() { # Check if current directory is not part of a git repo
  if [[ ! ( -d .git || $(git rev-parse --is-inside-work-tree 2> /dev/null) ) ]]; then
    echo 'Not a git repo'
    return 0
  else
    return 1
  fi
}

lbv() { # Generate a cross table of git repos vs branches
  if [ -z $1 ]; then
    bash ~/dev_scripts/scripts/local_branch_view.sh
  else
    local flags="${@}"
    bash ~/dev_scripts/scripts/local_branch_view.sh "${flags}"
  fi
}

plb() { # Purge branch name(s) from all git repos associated
  bash ~/dev_scripts/scripts/purge_local_branches.sh
}

env_refresh() { # Pull latest master branch for all git repos, run installs
  bash ~/dev_scripts/scripts/local_env_refresh.sh
}

git_status() { # Run git status for all repos
  bash ~/dev_scripts/scripts/all_repo_git_status.sh
}

git_branch() { # Run git branch for all repos
  bash ~/dev_scripts/scripts/all_repo_git_branch.sh
}

! name_set gc && \
  function gc() { # git commit, defined if alias gc not set
    if not_git; then return 1; fi
    local args=$@
    git commit "$args"
  }

! name_set gcam && \
  function gcam() { # git commit -am 'commit message', defined if alias gcam not set
    if not_git; then return 1; fi
    local COMMIT_MESSAGE="$1"
    git commit -am "$COMMIT_MESSAGE"
  }

gadd() { # Add all untracked git files
  if not_git; then return 1; fi
  local ALL_FILES=$(git ls-files -o --exclude-standard)
  if [ -z $ALL_FILES ]; then
    echo 'No untracked files found to add'
  else
    git add "${ALL_FILES}"
  fi
}

gpcurr() { # git push origin for current branch
  if not_git; then return 1; fi
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$CURRENT_BRANCH"
};

gacmp() { # Add all untracked files, commit with message, push current branch
  if not_git; then return 1; fi
  gadd
  local COMMIT_MESSAGE="$1"
  gcam "$COMMIT_MESSAGE"
  gpcurr
}

git_recent() { # Display table of commits sorted by recency descending
  if not_git; then return 1; fi
  git for-each-ref --sort=-committerdate refs/heads \
    --format='%(HEAD)%(color:yellow)%(refname:short)|%(color:bold green)%(committerdate:relative)|%(color:blue)%(subject)|%(color:magenta)%(authorname)%(color:reset)' \
    --color=always | column -ts '|'
}

git_graph() { # Print colorful git history graph
  if not_git; then return 1; fi
  git log --all --decorate --oneline --graph
}

todo() { # List todo items found in current directory
  # TODO: Add support for multiple dirs
  # local paths=( "${@}" )
  #for path in "${paths[@]}"; do
  #  if [ ! -d path ]; then
  #    echo "${path} is not a directory"
  #    return
  #  fi
  #done
  echo
  grep 'TODO:'
  echo
}

rgtodo() { # List all todo items found in current dir using ripgrep if installed
  echo
  if name_set rg; then
    rg 'TODO:'
  else
    echo 'Ripgrep not found - use todo command'
  fi
}

awk_col() { # Print field-separated data in columns with dynamic width
  local args=( "$@" )
  COL_MARGIN=${COL_MARGIN:-1} # Set an envvar for margin between cols, default is 1 char 
  if data_in; then
    local file=/tmp/awk_showlater piped=0
    cat /dev/stdin > $file
  else
    local args_len=${#args[@]}
    let last_arg=$args_len-1
    local file="${args[@]:$last_arg:1}"
    args=( ${args[@]/"$file"} )
  fi
  awk -f ~/dev_scripts/scripts/max_field_lengths.awk \
    -v buffer=$COL_MARGIN ${args[@]} "$file" "$file"
  if [ $piped ]; then rm $file &> /dev/null; fi
}

stagger() { # Print field-separated data in staggered rows
  local args=( "$@" )
  TTY_WIDTH=$( tput cols )
  if data_in; then
    local file=/tmp/awk_showlater piped=0
    cat /dev/stdin > $file
  else
    local args_len=${#args[@]}
    let last_arg=$args_len-1
    local file="${args[@]:$last_arg:1}"
    args=( ${args[@]/"$file"} )
  fi
  awk -f ~/dev_scripts/scripts/stagger.awk \
    -v TTY_WIDTH=$TTY_WIDTH ${args[@]} "$file"
  if [ $piped ]; then rm $file &> /dev/null; fi
}

dup_in_dir() { # Report duplicate files with option for deletion
  bash ~/dev_scripts/scripts/compare_files_in_dir.sh $1
}

ls_commands() { # List commands in the dev_scripts/.commands.sh file
  echo
  grep '[[:alnum:]_]*()' ~/dev_scripts/.commands.sh | grep -v grep \
    | awk -F "{ #" '{printf "%20s%s\n", $1, $2}'
  echo
}

