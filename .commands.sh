#!/bin/bash

namedata() { # Gathers data about names in current context
  local _var=$(declare | awk -F"=" '{print $1}' | awk '{print $NF}')
  local _func=$(declare -f | grep '^[A-Za-z_]*\s()' | cut -f 1 -d ' ' \
    | grep -v '()' | sed 's/^_//')
  local _alias=$(alias | awk -F"=" '{print $1}')
  local _bin=$(ls /bin)
  local _usrbin=$(ls /usr/bin | grep -v "\.")
  local _usrlocalbin=$(ls /usr/local/bin | grep -v "\.")
  local _builtin=$(bash -c 'help' | awk 'NR > 8 { line=$0
    $1 = substr($0, 2, 35); $2 = substr(line, 37, 35);
    print $1; print $2 }' | cut -f 1 -d ' ' | awk -v q=\' '{print q $0 q}')

  awk '{ if (_[FILENAME] == 0) f++ 
         if (f == 1) { print "VAR", $0 } 
    else if (f == 2) { print "FUNC", $0 } 
    else if (f == 3) { print "ALIAS", $0 }
    else if (f == 4) { print "BIN", $0 }
    else if (f == 5) { print "BUILTIN", $0 }
    else if (f == 6) { print "USRBIN", $0 }
    else if (f == 7) { print "USRLOCALBIN", $0 }
     _[FILENAME] = 1 }'               \
    <(printf '%s\n' ${_var})          \
    <(printf '%s\n' ${_func})         \
    <(printf '%s\n' ${_alias})        \
    <(printf '%s\n' ${_bin})          \
    <(printf '%s\n' ${_builtin})      \
    <(printf '%s\n' ${_usrbin})       \
    <(printf '%s\n' ${_usrlocalbin})  | sort
}

searchnames() { # Searches current names for string, returns matches
  local searchval="$1"
  namedata | awk -v sv=$searchval '$0 ~ sv { print }'
}

nameset() { # Test if name (function, alias, variable) is defined in context
  local name="$1"
  local check_var=$2

  if [ $check_var ]; then
    nametype $name &> /dev/null
  else
    type $name &> /dev/null
  fi
}

nametype() { # Test name type (function, alias, variable) if defined in context
  local name="$1"
  awk -v name=$name -v q=\' '
    BEGIN { e=1; quoted_name = ( q name q ) }
    $2==name || $2==quoted_name { print $1; e=0 }
    END { exit e }
    ' <(namedata)
}

which_sh() { # Print the shell being used (works for sh, bash, zsh)
  ps -ef | awk '$2==pid {print $8}' pid=$$
  # There is also envvar SHELL, might be more portable
}

sub_sh() { # Detect if in a subshell TODO - update to replace unreliable SUBSHELL vars
  [[ $BASH_SUBSHELL -gt 0 || $ZSH_SUBSHELL -gt 0  \
     || "$(exec sh -c 'echo "$PPID"')" != "$$"    \
     || "$(exec ksh -c 'echo "$PPID"')" != "$$"   ]]
}

nested() { # Detect if shell is nested for control handling
  [ $SHLVL -gt 1 ]
}

is_cli() { # Detect if shell is interactive
  [ -z "$PS1" ]
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
  local filename="$1"
  mktemp -q "/tmp/${filename}.XXXXX"
}

die() { # Output to STDERR and exit with error
  echo "$*" >&2
  if sub_sh || nested; then kill $$; else fi
}

fail() { # Safe failure, kills parent but returns to prompt (no custom message on zsh)
  local shell="$(which_sh)"
  if [ "$shell" = "bash" ]; then
    : "${_err_?$1}"
  else
    : "${_err_?'Operation intentionally failed by fail command'}"
  fi
}

needs_arg() { # Test if argument is missing and handle UX if it's not
  local opt="$1" optarg="$2"
  echo $optarg
  [ -z "$optarg" ] && echo "No arg for --$opt option" && fail
  echo reached end
}

longopts() { # Support long options: https://stackoverflow.com/a/28466267/519360
  local opt="$1" optarg="$2"
  opt="${optarg%%=*}"       # extract long option name
  optarg="${optarg#$opt}"   # extract long option argument (may be empty)
  optarg="${optarg#=}"      # if long option argument, remove assigning `=`
  local out=( "$opt" "$optarg" )
  printf '%s\t' "${out[@]}"
}

optshandling() { # General flag opts handling
  local OPTIND o s
  while getopts ":1:2:-:" OPT; do
    if [ "$OPT" = '-' ]; then
      local IFS=$'\t'; read -r OPT OPTARG <<<$(longopts "$OPT" "$OPTARG")
    fi
    case "${OPT}" in
      1|f1|file1) needs_arg "$OPT" "$OPTARG"; local file1="$OPTARG" ;;
      2|f2|file2) needs_arg "$OPT" "$OPTARG"; local file2="$OPTARG" ;;
      s1|sep1) local FS1="$OPTARG" ;;
      s2|sep2) local FS2="$OPTARG" ;;

      *) echo "Option not supported" 1>&2; return ;;
    esac
  done
  shift $((OPTIND-1))
  echo reached end
}

dup_input() { # Duplicate input sent to STDIN in aggregate
  tee /tmp/showlater && cat /tmp/showlater && rm /tmp/showlater
}

pipe_open() { # Detect if STDIN pipe is open
  [ -p /dev/stdin ]
}

pipe_check() { # Detect if pipe has any data
  tee > /tmp/stdin
  test -s /tmp/stdin
  local has_data=$?
  cat /tmp/stdin; rm /tmp/stdin
  return $has_data
}

join_by() { # Join a shell array by a text argument provided
  local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}";
}

iter_str() { # Repeat a string some number of times: rpt_str str [n=1] [fs]
  local str="$1" fs="${3:- }" liststr="$1"
  let n_repeats=${2:-1}-2
  for i in {0..$n_repeats}; do liststr="${liststr}${fs}${str}"; done
  echo "$liststr"
}

embrace() { # Enclose a string in braces: embrace string [openbrace="{"] [closebrace="}"]
  local value="$1" closebrace="${3:-\}}"
  [ "$2" = "" ] && local openbrace="{" || local openbrace="$2"
  echo "${openbrace}${value}${closebrace}"
}

filename_str() { # Adds a string to the beginning or end of a filename
  local IFS=$'\t'; read -r dirpath filename extension <<<$(path_elements "$1")
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

path_elements() { # Returns dirname, filename, and extension from a filepath
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
    [ "$(readlink "$vol")" = / ] && local root_vol=$vol
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

plb() { # Purge branch name(s) from all local git repos associated
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
    local commit_msg="$1"
    git commit -am "$commit_msg"
  }

gadd() { # Add all untracked git files
  not_git && return 1
  local all_untracked=( $(git ls-files -o --exclude-standard) )
  if [ -z $all_untracked ]; then
    echo 'No untracked files found to add'
  else
    startdir="$PWD"
    rootdir="$(git rev-parse --show-toplevel)"
    cd "$rootdir"
    git add .
    cd "$startdir"
  fi
}

gpcurr() { # git push origin for current branch
  not_git && return 1
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$current_branch"
};

gacmp() { # Add all untracked files, commit with message, push current branch
  not_git && return 1
  local commit_msg="$1"
  gadd; gcam "$commit_msg"; gpcurr
}

git_recent() { # Display table of commits sorted by recency descending
  not_git && return 1
  local run_context=${1:-display}
  local format=$(echo '%(HEAD) %(color:yellow)%(refname:short)|
      %(color:bold green)%(committerdate:relative)|
      %(color:blue)%(subject)|
      %(color:magenta)%(authorname)%(color:reset)' \
      | tr -d '[\n\t]')
  if [ $run_context = display ]; then
    git for-each-ref --sort=-committerdate refs/heads \
      --format=$format --color=always | fitcol -F'|'
  else
    # If not for immediate display, return extra field for further parsing
    format="${format/short)|/short)|%(committerdate:short)|}"
    git for-each-ref refs/heads --format=$format --color=always
  fi
}

git_recent_all() { # Display table of recent commits for all home dir branches
  local start_dir="$PWD"
  local all_recent=/tmp/git_recent_all_showlater
  cd ~
  while IFS=$'\n' read -r dir; do
    [ -d "${dir}/.git" ] && (cd "$dir" && \
      (git_recent parse | awk -v repo="$dir" -F'|' '
        {print "\033[34m" repo "\033[0m|", $0}') >> $all_recent )
  done < <(find * -maxdepth 0 -type d)
  echo
  cat $all_recent | sort -r -t '|' -k3 | awk -F'|' '
    BEGIN {OFS=FS} {print $1, $2, $4, $5, $6}' | \
      (nameset 'fitcol' && fitcol -F"|" || cat)
  local stts=$?
  echo
  rm $all_recent
  cd "$start_dir"
  return $stts
}

alias grec="git_recent"
alias gral="git_recent_all"

git_graph() { # Print colorful git history graph
  not_git && return 1
  git log --all --decorate --oneline --graph # git log a dog.
}

todo() { # List todo items found in current directory
  nameset 'rg' && local RG=true
  if [ -z $1 ]; then
    [ $RG ] && rg 'TODO:' || grep -rs 'TODO:' --color=always .
    echo
  else 
    local search_paths=( "${@}" )
    for search_path in ${search_paths[@]} ; do
      if [ ! -d "$search_path" ]; then
        echo "${search_path} is not a directory or is not found"
        local bad_dir=0
        continue
      fi
      [ $RG ] && rg 'TODO:' "$search_path" \
        || grep -rs 'TODO:' --color=always "$search_path"
      echo
    done
  fi
  [ -z $bad_dir ] || (echo 'Some paths provided could not be searched' && return 1)
}

ajoin() { # Similar to the join Unix command but with different features
  local args=( "$@" )
  if pipe_open; then
    local file2=/tmp/ajoin_showlater piped=0
    cat /dev/stdin > $file2
  else
    let last_arg=${#args[@]}-1
    local file2="${args[@]:$last_arg:1}"
    [ ! -f "$file2" ] && echo File missing or invalid! && return 1
    args=( ${args[@]/"$file2"} )
  fi
  
  let last_arg=${#args[@]}-1
  local file1="${args[@]:$last_arg:1}"
  if [ ! -f "$file1" ]; then
    echo File missing or invalid!
    [ $piped ] && rm $file2 &> /dev/null
    return 1
  fi
  args=( ${args[@]/"$file1"} )
  if [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v fs" ]]; then
    local fs1="-F$(inferfs "$file1")"
    local fs2="-F$(inferfs "$file2")"
  fi

  awk $fs1 $fs2 -f ~/dev_scripts/scripts/fullouterjoin.awk \
    "${args[@]}" "$file1" "$file2"
  if [ $piped ]; then rm $file2 &> /dev/null; fi
  # TODO: Add opts, infer keys, sort, statistics
}

print_matches() { # Print duplicate lines on given field numbers in two files
  local args=( "$@" )
  if pipe_open; then
    local file=/tmp/matches_showlater piped=0
    cat /dev/stdin > $file
  else
    let last_arg=${#args[@]}-1
    local file2="${args[@]:$last_arg:1}"
    [ ! -f "$file2" ] && echo File was not provided or is invalid! && return 1
    args=( ${args[@]/"$file2"} )
  fi
  
  let last_arg=${#args[@]}-1
  local file1="${args[@]:$last_arg:1}"
  if [ ! -f "$file1" ]; then
    echo File missing or invalid!
    [ $piped ] && rm $file2 &> /dev/null
    return 1
  fi
  args=( ${args[@]/"$file1"} )
  if [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v fs" ]]; then
    local fs1="-F$(inferfs "$file1")"
    local fs2="-F$(inferfs "$file2")"
  fi
  
  awk $fs1 $fs2 -f ~/dev_scripts/scripts/matches.awk "${args[@]}" "$file1" "$file2"
  if [ $piped ]; then rm $file2 &> /dev/null; fi
}

print_comps() { # Print non-matching lines on given field numbers in two files
  local args=( "$@" )
  if pipe_open; then
    local file=/tmp/complements_showlater piped=0
    cat /dev/stdin > $file
  else
    let last_arg=${#args[@]}-1
    local file2="${args[@]:$last_arg:1}"
    [ ! -f "$file2" ] && echo File was not provided or is invalid! && return 1
    args=( ${args[@]/"$file2"} )
  fi
  
  let last_arg=${#args[@]}-1
  local file1="${args[@]:$last_arg:1}"
  if [ ! -f "$file1" ]; then
    echo File missing or invalid!
    [ $piped ] && rm $file2 &> /dev/null
    return 1
  fi
  args=( ${args[@]/"$file1"} )
  if [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v fs" ]]; then
    local fs1="-F$(inferfs "$file1")"
    local fs2="-F$(inferfs "$file2")"
  fi
  awk $fs1 $fs2 -f ~/dev_scripts/scripts/complements.awk "${args[@]}" "$file1" "$file2"
  if [ $piped ]; then rm $file2 &> /dev/null; fi
}

inferk() { # Infer join fields in two text data files: inferk file [file (can be piped)]
  local args=( "$@" )
  if pipe_open; then
    local file2=/tmp/inferk_showlater piped=0
    cat /dev/stdin > $file2
  else
    let last_arg=${#args[@]}-1
    local file2="${args[@]:$last_arg:1}"
    [ ! -f "$file2" ] && echo File missing or invalid! && return 1
    args=( ${args[@]/"$file2"} )
  fi
  
  last_arg=$last_arg-1
  local file1="${args[@]:$last_arg:1}"
  if [ ! -f "$file1" ]; then
    echo File missing or invalid!
    [ $piped ] && rm $file2 &> /dev/null
    return 1
  fi
  args=( ${args[@]/"$file1"} )
  if [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v fs" ]]; then
    local fs1="-F$(inferfs "$file1")"
    local fs2="-F$(inferfs "$file2")"
  fi

  awk $fs1 $fs2 -f ~/dev_scripts/scripts/infer_join_fields.awk \
    "${args[@]}" "$file1" "$file2"
  if [ $piped ]; then rm $file2 &> /dev/null; fi
}

inferfs() { # Infer field separator from text data file: inferfs file [try_custom=true] [use_file_ext=true]
  local file="$1"
  [ ! -f "$file" ] && echo File was not provided or is invalid! && return 1
  local infer_custom=${2:-true} use_file_ext=${3:-true}
  
  if [ $use_file_ext = true ]; then
    local IFS=$'\t'; read -r dirpath filename extension <<<$(path_elements "$file")
    if [ $extension ]; then
      [ ".tsv" = "$extension" ] && echo "\t" && return
      [ ".csv" = "$extension" ] && echo ',' && return
    fi
  fi

  if [ $infer_custom = true ]; then
    awk -f ~/dev_scripts/scripts/infer_field_separator.awk -v custom=true "$file"
  else
    awk -f ~/dev_scripts/scripts/infer_field_separator.awk "$file"
  fi
}

fitcol() { # Print field-separated data in columns with dynamic width: fitcol [awkargs] file
  local args=( "$@" )
  local col_buffer=${col_buffer:-1} # Margin between cols, default is 1 char 
  if pipe_open; then
    local file=/tmp/fitcol_showlater piped=0
    cat /dev/stdin > $file
  else
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    [ ! -f "$file" ] && echo File was not provided or is invalid! && return 1
    args=( ${args[@]/"$file"} )
  fi
  if [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v fs" ]]; then
    local fs="-F$(inferfs "$file")"
  fi

  awk $fs -f ~/dev_scripts/scripts/fit_columns_0_decimal.awk \
    -v buffer=$col_buffer ${args[@]} "$file"{,} # List file twice for duplicate reading
  if [ $piped ]; then rm $file &> /dev/null; fi
}

stagger() { # Print field-separated data in staggered rows: stagger [awkargs] file
  local args=( "$@" )
  if pipe_open; then
    local file=/tmp/stagger_showlater piped=0
    cat /dev/stdin > $file
  else
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    [ ! -f "$file" ] && echo File was not provided or is invalid! && return 1
    args=( ${args[@]/"$file"} )
  fi
  if [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v fs" ]]; then
    local fs="-F$(inferfs "$file")"
  fi
  awk $fs -f ~/dev_scripts/scripts/stagger.awk ${args[@]} "$file"
  if [ $piped ]; then rm $file &> /dev/null; fi
}

index() { # Prints an index attached to data lines from a file or stdin
  local args=( "$@" )
  if pipe_open; then
    local header=$1
    local file=/tmp/index_showlater piped=0
    cat /dev/stdin > $file
  else
    local file="$1" header=$2
  fi
  if [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v FS" ]]; then
    local fs="-F$(inferfs "$file")"
  fi
  if [ $header ]; then
    awk $fs '{ print NR-1, $0 }' "$file"
  else
    awk $fs '{ print NR, $0 }' "$file"
  fi
  if [ $piped ]; then rm $file &> /dev/null; fi
}

cut_header() { # Remove up to a certain number of lines from the start of a file, default is 1
  let n_lines=1+${1:-1}
  if pipe_open; then
    local file=/tmp/cutheader piped=0
    cat /dev/stdin > $file
  else
    [ ! -f "$2" ] && echo File was not provided or is invalid! && return 1
    local file="$2"
  fi
  tail -n +$n_lines "$file"
  if [ $piped ]; then rm $file &> /dev/null; fi
}

transpose() { # Transpose field values of a text-based field-separated file
  local args=( "$@" )
  if pipe_open; then
    local file=/tmp/transpose piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    [ ! -f "$file" ] && echo File was not provided or is invalid! && return 1
    args=( ${args[@]/"$file"} )
  fi
  if [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v FS" ]]; then
    local fs="-F$(inferfs "$file")"
  fi
  local fs=$(inferfs "$file")
  awk $fs -f ~/dev_scripts/scripts/transpose.awk ${args[@]} "$file"
  if [ $piped ]; then rm $file &> /dev/null; fi
}

ds() { # Generate basic statistics about data in a Unix text file
  [ ! -f "$1" ] && echo File was not provided or is invalid! && return 1
  # TODO
}

fieldcounts() { # Print value counts for a given field in a data file: fieldcounts file [field=1] [min=1] [order=a]
  [ ! -f "$1" ] && echo File was not provided or is invalid! && return 1
  local file="$1" field="${2:-1}" min="$3"
  local fs="$(inferfs "$file")"
  ([ $3 = d ] || [ $3 = desc ]) && local order="r"
  ([ $min ] && test $min -gt 0 2> /dev/null) || min=1
  let min=$min-1
  local program="{ _[\$${field}]++ }
    END { for (i in _) if (_[i] > ${min}) print _[i], i }"
  cat "$file" | awk -F"$fs" "$program" | sort -n$order
}

mactounix() { # Converts ^M return characters into simple carriage returns in place
  [ ! -f "$1" ] && echo File was not provided or is invalid! && return 1
  local inputfile="$1"
  local tmpfile=/tmp/mactounix
  cat "$inputfile" > $tmpfile
  tr "\015" "\n" < $tmpfile > "$inputfile"
  rm $tmpfile
}

recent_files() { # ls files modified last 7 days: recent_files [custom_dir] [recurse=r] [hidden=h]
  if [ $1 ]; then
    local dirname="$(readlink -e "$1")"
    [ ! -d "$dirname" ] && echo Unable to verify directory provided! && return 1
  fi
  
  local dirname="${dirname:-$PWD}" recurse="$2" hidden="$3" datefilter
  nameset 'fd' && local FD=1
  [ $recurse ] && ([ $recurse = 'r' ] || [ $recurse = 'true' ]) || unset recurse
  # TODO: Rework this obscene logic with opts flags

  if [ $hidden ]; then
    [ $FD ] && [ $recurse ] && hidden=-HI #fd hides by default
    [ ! $recurse ] && hidden='A'
    notfound="No files found modified in the last 7 days!"
  else
    [ ! $FD ] && [ $recurse ] && hidden="-not -path '*/\.*'" # find includes all by default
    notfound="No non-hidden files found modified in the last 7 days!"
  fi
  
  if [ $recurse ]; then
    local ls_exec=(-exec ls -ghG --time-style=+%D \{\})
    (
      if [ $FD ]; then
        fd -t f --changed-within=1week $hidden -E 'Library/' \
          -${ls_exec[@]} 2> /dev/null \; ".*" "$dirname"
      else
        find "$dirname" -type f -maxdepth 6 $hidden -not -path ~"/Library" \
          -mtime -7d ${ls_exec[@]} 2> /dev/null
      fi
    ) | sed "s:$(printf '%q' $dirname)\/::" | sort -k4 \
      | awk '{ match($0, $4); 
        printf "%s;;%s;;%s;;%s;;%s\n", $1, $2, $3, $4, substr($0, RSTART + RLENGTH) }' \
      | (nameset 'fitcol' && fitcol -F";;" -v buffer=2 || awk -F";;") \
      | pipe_check
  else
    for i in {0..6}; do 
      datefilter=( "${datefilter[@]}" "-e $(date -d "-$i days" +%D)" )
    done

    ls -ghtG$hidden --time-style=+%D "$dirname" | grep -v '^d' | grep ${datefilter[@]}
  fi
  [ $? = 0 ] || (echo $notfound && return 1)
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

webpage_title() { # Downloads html from a webpage and extracts the title text
  local location="$1"
  local unescaped_title="$( wget -qO- "$location" |
      perl -l -0777 -ne 'print $1 if /<title.*?>\s*(.*?)\s*<\/title/si' )"
  if [ -f ~/dev_scripts/scripts/support/named_entities_escaped.sed ]; then
    printf "$unescaped_title" |
      sed -f ~/dev_scripts/scripts/support/named_entities_escaped.sed
  else
    printf "$unescaped_title"
  fi
}

dup_in_dir() { # Report duplicate files with option for deletion
  bash ~/dev_scripts/scripts/compare_files_in_dir.sh $1
}

ls_commands() { # List commands in the dev_scripts/.commands.sh file
  echo
  grep '[[:alnum:]_]*()' ~/dev_scripts/.commands.sh | sed 's/^  function //' \
    | grep -v grep | sort | awk -F "\\\(\\\) { #" '{printf "%-12s\t%s\n", $1, $2}'
  echo
}

