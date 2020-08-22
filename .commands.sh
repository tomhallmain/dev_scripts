#!/bin/bash

DS_LOC=~/dev_scripts
DS_SCRIPT=$DS_LOC/scripts/

ds:ndata() { # Gathers data about names in current context
  local _var=$(declare | awk -F"=" '{print $1}' | awk '{print $NF}')
  local _func=$(declare -f | grep '^[A-Za-z_:]*\s()' | cut -f 1 -d ' ' \
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

ds:searchn() { # Searches current names for string, returns matches
  local searchval="$1"
  ds:ndata | awk -v sv=$searchval '$0 ~ sv { print }'
}

ds:nset() { # Test if name (function, alias, variable) is defined in context
  local name="$1"
  local check_var=$2

  if [ $check_var ]; then
    ds:ntype $name &> /dev/null
  else
    type $name &> /dev/null
  fi
}

ds:ntype() { # Test name type (function, alias, variable) if defined in context
  local name="$1"
  awk -v name=$name -v q=\' '
    BEGIN { e=1; quoted_name = ( q name q ) }
    $2==name || $2==quoted_name { print $1; e=0 }
    END { exit e }
    ' <(ds:ndata) 2> /dev/null
}

ds:sh() { # Print the shell being used (works for sh, bash, zsh)
  ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{print $NF}'
}

ds:os() { # Return computer operating system if supported
  :
  # TODO
}

ds:subsh() { # Detect if in a subshell 
  [[ $BASH_SUBSHELL -gt 0 || $ZSH_SUBSHELL -gt 0 || "$(exec sh -c 'echo "$PPID"')" != "$$" || "$(exec ksh -c 'echo "$PPID"')" != "$$" ]]
}

ds:nested() { # Detect if shell is nested for control handling
  [ $SHLVL -gt 1 ]
}

ds:is_cli() { # Detect if shell is interactive
  [ -z "$PS1" ]
}

ds:refresh_zsh() { # Refresh zsh interactive session
  clear
  exec zsh
}

ds:refresh_bash() { # Refresh bash interactive session
  clear
  exec bash
}

ds:mktmp() { # mktemp -q "/tmp/${filename}"
  local filename="$1"
  mktemp -q "/tmp/${filename}.XXXXX"
}

ds:die() { # Output to STDERR and exit with error
  echo "$*" >&2
  if ds:sub_sh || ds:nested; then kill $$; fi
}

ds:fail() { # Safe failure, kills parent but returns to prompt (no custom message on zsh)
  local shell="$(ds:sh)"
  if [ "$shell" = "bash" ]; then
    : "${_err_?$1}"
  else
    echo "$1"
    : "${_err_?Operation intentionally failed by fail command}"
  fi
}

ds:needs_arg() { # Test if argument is missing and handle UX if it's not
  local opt="$1" optarg="$2"; echo $optarg
  [ -z "$optarg" ] && echo "No arg for --$opt option" && ds:fail
}

ds:longopts() { # Support long options: https://stackoverflow.com/a/28466267/519360
  local opt="$1" optarg="$2"
  opt="${optarg%%=*}"       # extract long option name
  optarg="${optarg#$opt}"   # extract long option argument (may be empty)
  optarg="${optarg#=}"      # if long option argument, remove assigning `=`
  local out=( "$opt" "$optarg" )
  printf '%s\t' "${out[@]}"
}

ds:opts() { # General flag opts handling
  local OPTIND o s
  while getopts ":1:2:-:" OPT; do
    if [ "$OPT" = '-' ]; then
      local IFS=$'\t'; read -r OPT OPTARG <<<$(ds:longopts "$OPT" "$OPTARG")
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

ds:dup_input() { # ** Duplicate input sent to STDIN in aggregate
  tee /tmp/showlater && cat /tmp/showlater && rm /tmp/showlater
}

ds:pipe_open() { # ** Detect if pipe is open
  [ -p /dev/stdin ]
}

ds:pipe_check() { # ** Detect if pipe has any data, or over a certain number of lines
  tee > /tmp/stdin
  if [ -z $1 ]; then
    test -s /tmp/stdin
  else
    [ $(cat /tmp/stdin | wc -l) -gt $1 ]
  fi
  local has_data=$?
  cat /tmp/stdin; rm /tmp/stdin
  return $has_data
}

ds:pipe_clean() { # Remove a temp file created via stdin if piping has been detected
  if [ $piped ]; then rm "$1" &> /dev/null; fi
}

ds:file_check() { # Test for file validity and fail if invalid
  local testfile="$1"
  [ ! -f "$testfile" ] && ds:fail 'File not provided or invalid!'
}

ds:noawkfs() { # Test whether awk arg for setting field separator is present
  [[ ! "${args[@]}" =~ " -F" && ! "${args[@]}" =~ "-v FS" && ! "${args[@]}" =~ "-v fs" ]]
}

ds:join_by() { # ** Join a shell array by a text argument provided
  local d=$1; shift

  if ds:pipe_open; then
    local pipeargs=($(cat /dev/stdin))
    [ -z ${pipeargs[2]} ] && echo Not enough args to join! && return 1
    local first="${pipeargs[0]}"
    local args=( ${pipeargs[@]:1} "$@" )
    set -- "${args[@]}"
  else
    [ -z $2 ] && echo Not enough args to join! && return 1
    local first="$1"; shift
    local args=( "$@" )
  fi

  echo -n "$first"; printf "%s" "${args[@]/#/$d}"
}

ds:iter_str() { # Repeat a string some number of times: rpt_str str [n=1] [fs]
  local str="$1" fs="${3:- }" liststr="$1"
  let n_repeats=${2:-1}-1
  for ((i=1;i<=$n_repeats;i++)); do liststr="${liststr}${fs}${str}"; done
  echo "$liststr"
}

ds:embrace() { # Enclose a string in braces: embrace string [openbrace="{"] [closebrace="}"]
  local value="$1" 
  [ "$2" = "" ] && local openbrace="{" || local openbrace="$2"
  [ "$3" = "" ] && local closebrace="}" || local closebrace="$3"
  echo "${openbrace}${value}${closebrace}"
}

ds:filename_str() { # Adds a string to the beginning or end of a filename
  read -r dirpath filename extension <<<$(ds:path_elements "$1")
  [ ! -d $dirpath ] && echo 'Filepath given is invalid' && return 1
  local str_to_add="$2" position=${3:-append}
  case $position in
    append)  filename="${filename}${str_to_add}${extension}" ;;
    prepend) filename="${str_to_add}${filename}${extension}" ;;
    *)       echo 'Invalid position provided'; return 1      ;;
  esac
  printf "${dirpath}${filename}"
}

ds:path_elements() { # Returns dirname, filename, and extension from a filepath
  ds:file_check "$1"
  local filepath="$1"
  local dirpath=$(dirname "$filepath")
  local filename=$(basename "$filepath")
  local extension=$([[ "$filename" = *.* ]] && echo ".${filename##*.}" || echo '')
  filename="${filename%.*}"
  local out=( "$dirpath/" "$filename" "$extension" )
  printf '%s\n' "${out[@]}"
}

ds:root() { # Returns the root volume / of the system
  for vol in /Volumes/*; do
    if [ "$(readlink "$vol")" = / ]; then
      local root=$vol
      printf $root
    fi
  done
}

ds:rev() { # ** Bash-only solution to reverse lines for processing
  local line
  if IFS= read -r line; then
    ds:rev
    printf '%s\n' "$line"
  fi
}

ds:not_git() { # Check if directory is not part of a git repo
  [ -z $1 ] || cd "$1"
  [[ ! ( -d .git || $(git rev-parse --is-inside-work-tree 2> /dev/null) ) ]]
}

ds:lbv() { # Generate a cross table of git repos vs branches
  if [ -z $1 ]; then
    bash $DS_SCRIPT/local_branch_view.sh
  else
    local flags="${@}"
    bash $DS_SCRIPT/local_branch_view.sh "${flags}"
  fi
}

ds:plb() { # Purge branch name(s) from all local git repos associated
  bash $DS_SCRIPT/purge_local_branches.sh
}

ds:env_refresh() { # Pull latest master branch for all git repos, run installs
  bash $DS_SCRIPT/local_env_refresh.sh
}

ds:git_status() { # Run git status for all repos
  bash $DS_SCRIPT/all_repo_git_status.sh
}

ds:git_branch() { # Run git branch for all repos
  bash $DS_SCRIPT/all_repo_git_branch.sh
}

ds:gadd() { # Add all untracked git files
  ds:not_git && return 1
  local all_untracked=( $(git ls-files -o --exclude-standard) )
  if [ -z "$all_untracked" ]; then
    echo 'No untracked files found to add'
  else
    startdir="$PWD"
    rootdir="$(git rev-parse --show-toplevel)"
    cd "$rootdir"
    git add .
    cd "$startdir"
  fi
}

ds:gpcurr() { # git push origin for current branch
  ds:not_git && return 1
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$current_branch"
};

ds:gacmp() { # Add all untracked files, commit with message, push current branch
  ds:not_git && return 1
  local commit_msg="$1"
  ds:gadd; gcam "$commit_msg"; ds:gpcurr
}

ds:git_recent() { # Display table of commits sorted by recency descending
  ds:not_git && return 1
  local run_context=${1:-display}
  if [ $run_context = display ]; then
    local format='%(HEAD) %(color:yellow)%(refname:short)||%(color:bold green)%(committerdate:relative)||%(color:blue)%(subject)||%(color:magenta)%(authorname)%(color:reset)'
    git for-each-ref --sort=-committerdate refs/heads \
      --format="$format" --color=always | ds:fit -F'\\\|\\\|'
  else
    # If not for immediate display, return extra field for further parsing
    local format='%(HEAD) %(color:yellow)%(refname:short)||%(committerdate:short)||%(color:bold green)%(committerdate:relative)||%(color:blue)%(subject)||%(color:magenta)%(authorname)%(color:reset)'
    git for-each-ref refs/heads --format="$format" --color=always
  fi
}
alias grec="ds:git_recent"

ds:git_recent_all() { # Display table of recent commits for all home dir branches
  local start_dir="$PWD"
  local all_recent=/tmp/git_recent_all_showlater
  echo "repo||branch||sortfield||commit time||commit message||author" > $all_recent
  cd ~
  while IFS=$'\n' read -r dir; do
    [ -d "${dir}/.git" ] && (cd "$dir" && \
      (ds:git_recent parse | awk -v repo="$dir" -F'\\\|\\\|' '
        {print "\033[34m" repo "\033[0m||", $0}') >> $all_recent )
  done < <(find * -maxdepth 0 -type d)
  echo
  ds:infsortm -v order=d -F'\\\|\\\|' -v k=3 $all_recent \
    | awk -F'\\\|\\\|' 'BEGIN {OFS="||"} {print $1, $2, $4, $5, $6}' | \
      (ds:nset 'ds:fit' && ds:fit -F'\\\|\\\|' -v color=never || cat)
  local stts=$?
  echo
  rm $all_recent
  cd "$start_dir"
  return $stts
}
alias gral="ds:git_recent_all"

ds:git_graph() { # Print colorful git history graph
  ds:not_git && return 1
  git log --all --decorate --oneline --graph # git log a dog.
}

ds:todo() { # List todo items found in current directory
  ds:nset 'rg' && local RG=true
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

ds:jn() { # ** Similar to the join Unix command but with different features
  local args=( "$@" )
  let last_arg=${#args[@]}-1
  if ds:pipe_open; then
    local file2=/tmp/ajoin_showlater piped=0
    cat /dev/stdin > $file2
  else
    local file2="${args[@]:$last_arg:1}"
    ds:file_check "$file2"
    let last_arg-=1
    local args=( ${args[@]/"$file2"} )
  fi
  
  local file1="${args[@]:$last_arg:1}"
  if [ ! -f "$file1" ]; then
    echo File not provided or invalid!
    [ $piped ] && rm $file2 &> /dev/null
    return 1
  fi
  local args=( ${args[@]/"$file1"} )
  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$file1")" fs2="$(ds:inferfs "$file2")"

    awk -v fs1="$fs1" -v fs2="$fs2" -f $DS_SCRIPT/join.awk \
      "${args[@]}" "$file1" "$file2" 2> /dev/null
  else
    awk -f $DS_SCRIPT/join.awk "${args[@]}" "$file1" "$file2" 2> /dev/mull
  fi

  ds:pipe_clean $file2
  # TODO: Add opts, infer keys, sort, statistics
  # TODO: Twofile handler function to abstract test logic of two file positional
  # last args
}

ds:mtch() { # ** Print duplicate lines on given field numbers in two files
  local args=( "$@" )
  let last_arg=${#args[@]}-1
  if ds:pipe_open; then
    local file2=/tmp/matches_showlater piped=0
    cat /dev/stdin > $file2
  else
    local file2="${args[@]:$last_arg:1}"
    ds:file_check "$file2"
    let last_arg-=1
    [ "${args[@]:$last_arg:1}" = "$file2" ] && local file1="$file2"
    local args=( ${args[@]/"$file2"} )
  fi
  
  [ -z "$file1" ] && local file1="${args[@]:$last_arg:1}"
  if [ ! -f "$file1" ]; then
    echo File not provided or invalid!
    ds:pipe_clean $file2
    return 1
  fi
  local args=( ${args[@]/"$file1"} )
  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$file1")" fs2="$(ds:inferfs "$file2")"

    awk -v fs1="$fs1" -v fs2="$fs2" -f $DS_SCRIPT/matches.awk \
      "${args[@]}" "$file1" "$file2" 2> /dev/null
  else
    awk -f $DS_SCRIPT/matches.awk "${args[@]}" "$file1" "$file2" 2> /dev/null
  fi
  
  ds:pipe_clean $file2
}

ds:comp() { # ** Print non-matching lines on given field numbers in two files
  local args=( "$@" )
  let last_arg=${#args[@]}-1
  if ds:pipe_open; then
    local file2=/tmp/complements_showlater piped=0
    cat /dev/stdin > $file2
  else
    local file2="${args[@]:$last_arg:1}"
    ds:file_check "$file2"
    let last_arg-=1
    [ "${args[@]:$last_arg:1}" = "$file2" ] && local file1="$file2"
    local args=( ${args[@]/"$file2"} )
  fi

  [ -z "$file1" ] && local file1="${args[@]:$last_arg:1}"
  if [ ! -f "$file1" ]; then
    echo File missing or invalid!
    ds:pipe_clean $file2
    return 1
  fi
  local args=( ${args[@]/"$file1"} )
  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$file1")" fs2="$(ds:inferfs "$file2")"

    awk -v fs1="$fs1" -v fs2="$fs2" -f $DS_SCRIPT/complements.awk \
      "${args[@]}" "$file1" "$file2" 2> /dev/null
  else
    awk -f $DS_SCRIPT/complements.awk "${args[@]}" "$file1" "$file2" 2> /dev/null
  fi
  
  ds:pipe_clean $file2
}

ds:inferh() { # Infer if headers are present in a file: ds:inferh [awkargs] file
  local args=( "$@" )
  awk -f infer_headers.awk "${args[@]}" 2> /dev/null
}

ds:inferk() { # ** Infer join fields in two text data files: ds:inferk file [file (can be piped)]
  local args=( "$@" )
  let last_arg=${#args[@]}-1
  if ds:pipe_open; then
    local file2=/tmp/inferk_showlater piped=0
    cat /dev/stdin > $file2
  else
    local file2="${args[@]:$last_arg:1}"
    ds:file_check "$file2"
    let last_arg-=-1
    local args=( ${args[@]/"$file2"} )
  fi
  
  local file1="${args[@]:$last_arg:1}"
  if [ ! -f "$file1" ]; then
    echo File not provided or invalid!
    ds:pipe_clean $file2
    return 1
  fi
  local args=( ${args[@]/"$file1"} )
  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$file1")" fs2="$(ds:inferfs "$file2")"

    awk -v fs1="$fs1" -v fs2="$fs2" -f $DS_SCRIPT/infer_join_fields.awk \
      "${args[@]}" "$file1" "$file2" 2> /dev/null
  else
    awk -f $DS_SCRIPT/infer_join_fields.awk "${args[@]}" "$file1" "$file2" 2> /dev/null
  fi

  ds:pipe_clean $file2
}

ds:inferfs() { # Infer field separator from text data file: inferfs file [try_custom=true] [use_file_ext=true]
  ds:file_check "$1"
  local file="$1" infer_custom=${2:-true} use_file_ext=${3:-true}

  if [ $use_file_ext = true ]; then
    read -r dirpath filename extension <<<$(ds:path_elements "$file")
    if [ $extension ]; then
      [ ".tsv" = "$extension" ] && echo "\t" && return
      [ ".csv" = "$extension" ] && echo ',' && return
    fi
  fi

  if [ $infer_custom = true ]; then
    awk -f $DS_SCRIPT/infer_field_separator.awk -v high_certainty=1 \
      -v custom=true "$file" 2> /dev/null
  else
    awk -f $DS_SCRIPT/infer_field_separator.awk -v high_certainty=1 "$file" 2> /dev/null
  fi
}

ds:fit() { # ** Print field-separated data in columns with dynamic width: ds:fit [awkargs] file
  local args=( "$@" ) col_buffer=${col_buffer:-3} tty_size=$(tput cols)
  if ds:pipe_open; then
    local file=/tmp/fit_showlater piped=0
    cat /dev/stdin > $file
  else
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    args=( ${args[@]/"$file"} )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file")"
    awk -v FS="$fs" -f $DS_SCRIPT/fit_columns.awk -v tty_size=$tty_size\
      -v buffer=$col_buffer ${args[@]} "$file"{,} 2> /dev/null
  else
    awk -f $DS_SCRIPT/fit_columns.awk -v tty_size=$tty_size\
      -v buffer=$col_buffer ${args[@]} "$file"{,} 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:stag() { # ** Print field-separated data in staggered rows: ds:stag [awkargs] file
  local args=( "$@" ) tty_size=$(tput cols)
  if ds:pipe_open; then
    local file=/tmp/stagger_showlater piped=0
    cat /dev/stdin > $file
  else
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    args=( ${args[@]/"$file"} )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file")"
    awk -v FS="$fs" -f $DS_SCRIPT/stagger.awk -v tty_size=$tty_size \
      ${args[@]} "$file" 2> /dev/null
  else
    awk -f $DS_SCRIPT/stagger.awk ${args[@]} -v tty_size=$tty_size "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:index() { # ** Prints an index attached to data lines from a file or stdin
  if ds:pipe_open; then
    local header=$1 args=( "${@:2}" ) file=/tmp/index_showlater piped=0
    cat /dev/stdin > $file
  else
    local file="$1" header=$2 args=( "${@:3}" )
  fi
  local program="$([ $header ] && echo '{ print NR-1, $0 }' || echo '{ print NR, $0 }')"
  if ds:noawkfs; then
    local fs="$(inferfs "$file")"
    awk -v FS="$fs" ${args[@]} "$program" "$file" 2> /dev/null
  else
    awk ${args[@]} "$program" "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:reo() { # ** Reorder/repeat/slice rows/cols: ds:reo file [rows] [cols] [awkargs] || cmd | ds:reo [rows] [cols] [awkargs]
  if ds:pipe_open; then
    local rows="$1" cols="$2" args=( "${@:3}" ) file=/tmp/reo_showlater piped=0
    cat /dev/stdin > $file
  else
    local file="$1" rows="$2" cols="$3" args=( "${@:4}" )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file")"
    awk -F$fs ${args[@]} -v r=$rows -v c=$cols -f $DS_SCRIPT/reorder.awk \
      "$file" 2> /dev/null
  else
    awk ${args[@]} -v r=$rows -v c=$cols -f $DS_SCRIPT/reorder.awk "$file" 2> /dev/null
  fi
}

ds:dcap() { # ** Remove up to a certain number of lines from the start of a file, default is 1
  let n_lines=1+${1:-1}
  if ds:pipe_open; then
    local file=/tmp/cutheader piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$2"
    local file="$2"
  fi
  tail -n +$n_lines "$file"
  ds:pipe_clean $file
}

ds:transpose() { # ** Transpose field values of a text-based field-separated file
  local args=( "$@" )
  if ds:pipe_open; then
    local file=/tmp/transpose piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    [ ! -f "$file" ] && echo File was not provided or is invalid! && return 1
    local args=( ${args[@]/"$file"} )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file")"
    awk -v FS="$fs" -f $DS_SCRIPT/transpose.awk \
      ${args[@]} "$file" 2> /dev/null
  else
    awk -f $DS_SCRIPT/transpose.awk ${args[@]} \
      "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:ds() { # Generate statistics about data in a Unix text file
  ds:file_check "$1"
  local fs="$(ds:inferfs "$file")"
  
  # TODO
}

ds:fieldcounts() { # Print value counts for a given field: ds:fieldcounts file [field=1] [min=1] [order=a]
  ds:file_check "$1"
  local file="$1" field="${2:-1}" min="$3"
  local fs="$(ds:inferfs "$file")"
  [ $3 ] && ([ $3 = d ] || [ $3 = desc ]) && local order="r"
  ([ $min ] && test $min -gt 0 2> /dev/null) || local min=1
  let min=$min-1
  local program="{ _[\$${field}]++ }
    END { for (i in _) if (_[i] > ${min}) print _[i], i }"
  awk -F"$fs" "$program" "$file" 2> /dev/null | sort -n$order
}

ds:newfs() { # Outputs a file with an updated field separator: newfs file [fs= ]
  ds:file_check "$1"
  local file="$1" field="${2:-1}" min="$3"
  local fs="$(ds:inferfs "$file")"

  # TODO
}

ds:asgn() { # Grabbing lines matching standard assignment pattern from a file
  ds:file_check "$1"
  if ds:nset 'rg'; then
    rg "[[:alnum:]_]+ *=[^=<>]" $1 
  else
    egrep -n --color=always -e "[[:alnum:]_]+ *=[^=<>]" $1
  fi
  if [ ! $? ]; then echo 'No assignments found in file!'; fi
}

ds:enti() { # Print text entities from a file separated by a common pattern
  ds:file_check "$1"
  local file="$1" sep="$2" min="$3"
  [ $sep ] || local sep=" "
  ([ $3 = d ] || [ $3 = desc ]) && local order="r"
  ([ $min ] && test $min -gt 0 2> /dev/null) || min=1
  let min=$min-1
  local program=$DS_SCRIPT/separated_entities.awk
  awk -v sep="$sep" -v min=$min -f $program "$file" 2> /dev/null | sort -n$order
}

ds:sbsp() { # Extend fields to include a common subseparator: ds:sbsp file subsep_pattern [nomatch_handler=space]
  ds:file_check "$1"
  local file="$1" fs="$(ds:inferfs "$file")"
  [ $2 ] && local ssp="-v subsep_pattern=$2"
  [ $3 ] && local nmh="-v nomatch_handler=$3"
  awk -v FS=$fs $ssp $nmh -f $DS_SCRIPT/subseparator.awk \
    "$file" 2> /dev/null
}

ds:mactounix() { # Converts ^M return characters into simple carriage returns in place
  ds:file_check "$1"
  local inputfile="$1" tmpfile=/tmp/mactounix
  cat "$inputfile" > $tmpfile
  tr "\015" "\n" < $tmpfile > "$inputfile"
  rm $tmpfile
}

ds:unixtodos() { # Removes \r characters in place
  # TODO: Name may need to be updated, put this and above in different file
  ds:file_check "$1"
  local inputfile="$1" tmpfile=/tmp/unixtodos
  cat "$inputfile" > $tmpfile
  sed -e 's/\r//g' $tmpfile > "$inputfile"
  rm $tmpfile
}

ds:mini() { # Crude minify, remove whitespace including newlines except space
  if ds:pipe_open; then
    cat /dev/stdin > /tmp/mini_showlater;
    local file=/tmp/mini_showlater piped=0
  else
    ds:file_check "$1"
    local file="$1"
  fi
  awk -v RS="\0" '{ gsub("(\n|\t)" ,""); print }' "$file" 2> /dev/null
  ds:pipe_clean $file
}

ds:infsort() { # Sort with an inferred field separator of exactly 1 char
  local args=( "$@" )
  if ds:pipe_open; then
    local file=/tmp/infsort_showlater piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    args=( ${args[@]/"$file"} )
  fi
  local fs="$(ds:inferfs $file)"
  sort ${args[@]} -t"$fs" "$file"
  ds:pipe_clean $file
}

ds:infsortm() { # Sort with an inferred field separator of 1 or more character
  # TODO: Default to infer header
  local args=( "$@" )
  if ds:pipe_open; then
    local file=/tmp/infsortm_showlater piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    args=( ${args[@]/"$file"} )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file")"
    awk -v FS="$fs" -f $DS_SCRIPT/fields_qsort.awk ${args[@]} "$file" 2> /dev/null
  else
    awk -f $DS_SCRIPT/fields_qsort.awk ${args[@]} "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:srg() { # Scope rg/grep to a set of files that contain a match: ds:srg scope_pattern search_pattern [dir] [invert=]
  ([ $1 ] && [ $2 ]) || ds:fail 'Missing scope and/or search pattern args'
  local scope="$1" search="$2"
  [ -d "$3" ] && local basedir="$3" || local basedir="$PWD"
  [ $4 ] && [ $4 != 'f' ] && [ $4 != 'false' ] && local invert="--files-without-match"
  if ds:nset 'rg'; then
    echo -e "\nrg ${invert} ${search} scoped to files matching ${scope} in ${basedir}\n"
    rg -u -u -0 --files-with-matches -e "$scope" "$basedir" 2> /dev/null \
      | xargs -0 -I % rg -H $invert "$search" "%" 2> /dev/null
  else
    $invert && local invert="${invert}es"
    echo -e "\ngrep ${invert} ${search} scoped to files matching ${scope} in ${basedir}\n"
    grep -r --null --files-with-matches -e "$scope" "$basedir" 2> /dev/null \
      | xargs -0 -I % grep -H --color $invert "$search" "%" 2> /dev/null
  fi
  : # Clear noisy xargs exit status
}

ds:recent() { # ls files modified last 7 days: ds:recent [custom_dir] [recurse=r] [hidden=h]
  if [ $1 ]; then
    local dirname="$(readlink -e "$1")"
    [ ! -d "$dirname" ] && echo Unable to verify directory provided! && return 1
  fi
  
  local dirname="${dirname:-$PWD}" recurse="$2" hidden="$3" datefilter
  ds:nset 'fd' && local FD=1
  [ $recurse ] && ([ $recurse = 'r' ] || [ $recurse = 'true' ]) || unset recurse
  # TODO: Rework this obscene logic with opts flags

  if [ $hidden ]; then
    [ $FD ] && [ $recurse ] && local hidden=-HI #fd hides by default
    [ ! $recurse ] && hidden='A'
    local notfound="No files found modified in the last 7 days!"
  else
    [ ! $FD ] && [ $recurse ] && local hidden="-not -path '*/\.*'" # find includes all by default
    local notfound="No non-hidden files found modified in the last 7 days!"
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
      | (ds:nset 'ds:fit' && ds:fit -F";;" -v buffer=2 || awk -F";;") \
      | ds:pipe_check
  else
    for i in {0..6}; do 
      local datefilter=( "${datefilter[@]}" "-e $(date -d "-$i days" +%D)" )
    done

    ls -ghtG$hidden --time-style=+%D "$dirname" | grep -v '^d' | grep ${datefilter[@]}
  fi
  [ $? = 0 ] || (echo $notfound && return 1)
}

ds:sedi() { # Linux-portable sed in place substitution: ds:sedi file search_pattern [replacement]
  [ $1 ] && [ $2 ] || ds:fail 'Missing required args: ds:sedi file search [replace]'
  [ ! -f "$1" ] && echo File was not provided or is invalid! && return 1
  local file="$1" search="$2" replace="$3"
  perl -pi -e "s/${search}/${replace}/g" "$file"
}

ds:dff() { # Diff shortcut for more relevant changes: ds:dff file1 file2 [suppress_common]
  local tty_size=$(tput cols)
  let local tty_half=$tty_size/2
  [ $3 ] && local sup=--suppress-common-lines && set -- "${@:1:2}"
  diff -b -y -W $tty_size $sup ${@} | expand | awk -v tty_half=$tty_half \
    -f $DS_SCRIPT/diff_color.awk | less
}

ds:gwdf() { # Git word diff shortcut
  local args=( "$@" )
  git diff --word-diff-regex="[A-Za-z0-9. ]|[^[:space:]]" --word-diff=color ${args[@]}
}

ds:goog() { # Executes Google search with args provided
  local search_args="$@"
  [ -z $search_args ] && ds:fail 'Arg required for search'
  local base_url="https://www.google.com/search?query="
  local search_query=$(echo $search_args | sed -e "s/ /+/g")
  open "${base_url}${search_query}"
}

ds:sofs() { # Executes Stack Overflow search with args provided
  local search_args="$@"
  [ -z $search_args ] && ds:fail 'Arg required for search'
  local base_url="https://www.stackoverflow.com/search?q="
  local search_query=$(echo $search_args | sed -e "s/ /+/g")
  open "${base_url}${search_query}"
}

ds:webpage_title() { # Downloads html from a webpage and extracts the title text
  local location="$1"
  local tr_file=$DS_SCRIPT/support/named_entities_escaped.sed
  local unescaped_title="$( wget -qO- "$location" |
    perl -l -0777 -ne 'print $1 if /<title.*?>\s*(.*?)\s*<\/title/si' )"

  if [ -f $tr_file ]; then
    printf "$unescaped_title" | sed -f $tr_file
  else
    printf "$unescaped_title"
  fi
}

ds:dir_dup() { # Report duplicate files with option for deletion
  bash $DS_SCRIPT/compare_files_in_dir.sh $1
}

ds:commands() { # List commands in the dev_scripts/.commands.sh file
  echo
  grep '[[:alnum:]_]*()' $DS_LOC/.commands.sh | sed 's/^  function //' \
    | grep -v grep | sort | awk -F "\\\(\\\) { #" '{printf "%-18s\t%s\n", $1, $2}'
  echo
  echo "** - function supports receiving piped data"
  echo
}

