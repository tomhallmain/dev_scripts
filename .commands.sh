#!/bin/bash

namedata() { # Gathers data about names in current context
  local all_var=$(declare | awk -F"=" '{print $1}' | awk '{print $NF}')
  local all_func=$(declare -f | grep '^[A-Za-z_]*\s()' | cut -f 1 -d ' ' \
    | grep -v '()' | sed 's/^_//')
  local all_alias=$(alias | awk -F"=" '{print $1}')
  local all_bin=$(ls /bin)
  local all_builtin=$(bash -c 'help' | awk '
    NR > 8 { saveline=$0; $1 = substr($0, 2, 35); $2 = substr(saveline, 37, 35);
      print $1; print $2 }' | cut -f 1 -d ' ' | awk -v q=\' '{print q $0 q }')

  awk '{ if (_[FILENAME] == 0) fd++ 
         if (fd == 1)      { print "VAR", $0 } 
         else if (fd == 2) { print "FUNC", $0 } 
         else if (fd == 3) { print "ALIAS", $0 }
         else if (fd == 4) { print "BIN", $0 }
         else if (fd == 5) { print "BUILTIN", $0 }
         _[FILENAME] = 1 }'            \
    <(printf '%s\n' ${all_var})        \
    <(printf '%s\n' ${all_func})       \
    <(printf '%s\n' ${all_alias})      \
    <(printf '%s\n' ${all_bin})        \
    <(printf '%s\n' ${all_builtin}) | sort
}

nameset() { # Test if a name (function, alias, variable) is defined in context
  local name="$1"
  local check_var=$2

  if [ $check_var ]; then
    nametype $name &> /dev/null
  else
    type $name &> /dev/null
  fi
}

nametype() { # Tests name type (function, alias, variable) if defined in context
  local name="$1"
  awk -v name=$name -v q=\' '
    BEGIN { e=1; quoted_name = ( q name q ) }
    $2==name || $2 == quoted_name { print $1; e=0 }
    END { exit e }
    ' <(namedata)
}

which_sh() { # Print the shell being used (works for sh, bash, zsh)
  ps -ef | awk '$2==pid {print $8}' pid=$$
}

refresh_zsh() { # Refresh zsh interactive session
  clear
  exec zsh
}

refresh_bash() { # Refresh bash interactive session
  clear
  exec bash
}

mktmp() { # mktemp -q "/tmp/${filename}"
  local filename=$1
  mktemp -q "/tmp/${filename}.XXXXX"
}

die() { # Complain to STDERR and exit with error
  echo "$*" >&2; kill $$
}

needs_arg() { # Test if argument is missing and handle UX if it's not
  local opt="$1" optarg="$2"
  if [ $opt && -z "$optarg" ]; then
    die "No arg for --$opt option"
  else
    die "Arg missing!"
  fi
}

longopts() { # Support long options: https://stackoverflow.com/a/28466267/519360
  local opt="$1" optarg="$2"
  opt="${optarg%%=*}"       # extract long option name
  optarg="${optarg#$opt}"   # extract long option argument (may be empty)
  optarg="${optarg#=}"      # if long option argument, remove assigning `=`
  local out=( "$opt" "$optarg" )
  printf '%s\t' "${out[@]}"
}

print_matches() { # Print duplicate lines on given field numbers in two files
  local OPTIND o s
  while getopts ":1:2:-:" OPT; do
    if [ "$OPT" == '-' ]; then
      local IFS=$'\t'; read -r OPT OPTARG <<<$(longopts "$OPT" "$OPTARG")
    fi
    case "${OPT}" in
      1 | f1 | file1) needs_arg "$OPT" "$OPTARG"; local file1="$OPTARG" ;;
      2 | f2 | file2) needs_arg "$OPT" "$OPTARG"; local file2="$OPTARG" ;;
      s1 | sep1) local FS1="$OPTARG" ;;
      s2 | sep2) local FS2="$OPTARG" ;;

      *) echo "print_duplicates: [-s <separator>]" 1>&2; return ;;
    esac
  done

  local file=
  shift $((OPTIND-1))
}

print_complements() { # Print non-matching lines on given field numbers in two files

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

add_str_to_filename() { # Adds a string to the beginning or end of a filename
  local IFS=$'\t'; read -r dirpath filename extension <<<$(deconstruct_filepath "$1")
  [ ! -d $dirpath ] && echo 'Filepath given is invalid' && return 1
  local str_to_add="$2" position=$3
  position=${position:-append}
  case $position in
    append)  filename="${filename}${str_to_add}${extension}";;
    prepend) filename="${filename}${str_to_add}${extension}";;
    *)       echo 'Invalid position provided'; return 1     ;;
  esac
  printf "${dirpath}${filename}"
}

deconstruct_filepath() { # Returns dirname, filename, and extension from a filepath
  [ ! -f $1 ] && echo 'Filepath given is invalid' && return 1
  local filepath="$1"
  local dirpath=$(dirname "$filepath")
  local filename=$(basename "$filepath")
  local extension=$([[ "$filename" = *.* ]] && echo ".${filename##*.}" || echo '')
  filename="${filename%.*}"
  local out=( "$dirpath/" "$filename" "$extension" )
  printf '%s\t' "${out[@]}"
}

root_volume() { # Returns the root volume / of the system
  for vol in /Volumes/*; do
    [ "$(readlink "$vol")" = / ] && root_vol=$vol
    return $root_vol
  done
}

reverse() { # Bash-only solution to reverse lines for processing
  local line
  if IFS= read -r line; then
    reverse
    printf '%s\n' "$line"
  fi
}

not_git() { # Check if directory is not part of a git repo
  [ -z $1 ] || cd "$1"
  [[ ! ( -d .git || $(git rev-parse --is-inside-work-tree 2> /dev/null) ) ]]
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

nameset gc || \
  function gc() { # git commit, defined if alias gc not set
    not_git && return 1
    local args=$@
    git commit "$args"
  }

nameset gcam || \
  function gcam() { # git commit -am 'commit message', defined if alias gcam not set
    not_git && return 1
    local COMMIT_MESSAGE="$1"
    git commit -am "$COMMIT_MESSAGE"
  }

gadd() { # Add all untracked git files
  not_git && return 1
  local ALL_FILES=$(git ls-files -o --exclude-standard)
  if [ -z $ALL_FILES ]; then
    echo 'No untracked files found to add'
  else
    git add "${ALL_FILES}"
  fi
}

gpcurr() { # git push origin for current branch
  not_git && return 1
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$CURRENT_BRANCH"
};

gacmp() { # Add all untracked files, commit with message, push current branch
  not_git && return 1
  local message="$1"
  gadd; gcam "$message"; gpcurr
}

git_recent() { # Display table of commits sorted by recency descending
  not_git && return 1
  local run_context=${1:-display}
  if [ $run_context = display ]; then
    format=$(echo '%(HEAD) %(color:yellow)%(refname:short)|
      %(color:bold green)%(committerdate:relative)|
      %(color:blue)%(subject)|
      %(color:magenta)%(authorname)%(color:reset)' \
      | tr -d '[\n\t]')
    git for-each-ref --sort=-committerdate refs/heads \
      --format=$format --color=always | fitcol -F'|'
  else
    # If not for immediate display, return extra field for further parsing
    format=$(echo '
      %(HEAD) %(color:yellow)%(refname:short)|
      %(committerdate:short)|%(color:bold green)%(committerdate:relative)|
      %(color:blue)%(subject)|
      %(color:magenta)%(authorname)%(color:reset)' \
      | tr -d '[\n\t]')
    git for-each-ref refs/heads --format=$format --color=always
  fi
}

git_recent_all() { # Display table of commits for all home dir branches
  local start_dir="$PWD"
  local all_recent=/tmp/git_recent_all_showlater
  while IFS=$'\n' read -r dir; do
    [ -d "${dir}/.git" ] && (cd "$dir" && \
      (git_recent parse | awk -v repo="$dir" -F'|' '
        {print "\033[34m" repo "\033[0m|", $0}') >> $all_recent )
  done < <(cd ~; find * -maxdepth 0 -type d)
  echo
  cat $all_recent | sort -r -t '|' -k3 | awk -F'|' '
    BEGIN {OFS=FS} {print $1, $2, $4, $5, $6}' | fitcol -F"|"
  echo
  rm $all_recent
  cd "$start_dir"
}

git_graph() { # Print colorful git history graph
  not_git && return 1
  git log --all --decorate --oneline --graph
}

todo() { # List todo items found in current directory
  if [ -z $1 ]; then
    grep -rs 'TODO:' --color=always .
    echo
  else 
    local search_paths=( "${@}" )
    for search_path in ${search_paths[@]} ; do
      if [ ! -d "$search_path" ]; then
        echo "${search_path} is not a directory or is not found"
        local bad_dir=0
        continue
      fi
      grep -rs 'TODO:' --color=always "$search_path"
      echo
    done
  fi
  [ -z $bad_dir ] || (echo 'Some paths provided could not be searched' && return 1)
}

rgtodo() { # List all todo items found in current dir using ripgrep if installed
  nameset rg || (echo 'ripgrep not found - use `todo` command' && return 1)
  if [ -z $1 ]; then
    rg 'TODO:'
    echo
  else 
    local search_paths=( "${@}" )
    for search_path in ${search_paths[@]} ; do
      if [ ! -d "$search_path" ]; then
        echo "${search_path} is not a directory or is not found"
        local bad_dir=0
        continue
      fi
      rg 'TODO:' "$search_path"
      echo
    done
  fi
  [ -z $bad_dir ] || (echo 'Some paths provided could not be searched' && return 1)
}

inferfs() { # Infer a field separator from a given text data file
  local file="$1"
  local use_file_ext=${2:-true}
  
  if [ $use_file_ext = true ]; then
    local IFS=$'\t'; read -r dirpath filename extension <<<$(deconstruct_filepath "$file")
    if [ $extension ]; then
      [ ".tsv" = "$extension" ] && echo "\t" && return
      [ ".csv" = "$extension" ] && echo ',' && return
    fi
  fi

  local fst=$(awk -f ~/dev_scripts/scripts/infer_field_separator.awk "$file")

  case $fst in
    s) echo "\s" && return ;;
    t) echo "\t" && return ;;
    p) echo "|"  && return ;;
    m) echo ';'  && return ;;
    c) echo ','  && return ;;
    *) echo 'Script encountered an error' && return 1
  esac
}

fitcol() { # Print field-separated data in columns with dynamic width
  local args=( "$@" )
  COL_MARGIN=${COL_MARGIN:-1} # Set an envvar for margin between cols, default is 1 char 
  if data_in; then
    local file=/tmp/fitcol_showlater piped=0
    cat /dev/stdin > $file
  else
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    args=( ${args[@]/"$file"} )
  fi
  awk -f ~/dev_scripts/scripts/max_field_lengths.awk \
    -v buffer=$COL_MARGIN ${args[@]} "$file"{,} # List file twice for duplicate reading
  if [ $piped ]; then rm $file &> /dev/null; fi
}

stagger() { # Print field-separated data in staggered rows
  local args=( "$@" )
  TTY_WIDTH=$( tput cols )
  if data_in; then
    local file=/tmp/stagger_showlater piped=0
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

google() { # Executes Google search with args provided
  local search_args="$@"
  if [ -z $search_args ]; then
    echo 'Arg required for search'
    return 1
  else
    local base_url="https://www.google.com/search?query="
    local search_query=$(echo $search_args | sed -e "s/ /+/g")
    open "${base_url}${search_query}"
  fi
}

so_search() { # Executes Stack Overflow search with args provided
  local search_args="$@"
  if [ -z $search_args ]; then
    echo 'Arg required for search'
    return 1
  else
    local base_url="https://www.stackoverflow.com/search?q="
    local search_query=$(echo $search_args | sed -e "s/ /+/g")
    open "${base_url}${search_query}"
  fi
}

dup_in_dir() { # Report duplicate files with option for deletion
  bash ~/dev_scripts/scripts/compare_files_in_dir.sh $1
}

ls_commands() { # List commands in the dev_scripts/.commands.sh file
  echo
  grep '[[:alnum:]_]*()' ~/dev_scripts/.commands.sh | grep -v grep \
    | sort | awk -F "{ #" '{printf "%30s%s\n", $1, $2}'
  echo
}

