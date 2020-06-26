#!/bin/bash

lbv() { # Generates a cross table of git repos vs branches
  flags=$1
  bash ~/dev_scripts/scripts/local_branch_view.sh "$flags"
}

plb() { # Purges a branch name from all git repos associated
  bash ~/dev_scripts/scripts/purge_local_branches.sh
}

join_by() { # Joins a shell array by a text argument provided
  local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}";
}

dup_in_dir() { # Reports duplicate files and gives option for deletion
  bash ~/dev_scripts/scripts/compare_files_in_dir.sh $1
}

