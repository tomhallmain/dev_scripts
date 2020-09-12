#!/bin/bash

DS_LOC=~/dev_scripts
DS_SCRIPT=$DS_LOC/scripts
DS_SUPPORT="${DS_SCRIPT}/support"
source "${DS_SUPPORT}/utils.sh"




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

ds:zsh() { # Refresh zsh interactive session
  # TODO: Clear persistent envars
  clear
  exec zsh
}

ds:bash() { # Refresh bash interactive session
  clear
  exec bash
}

ds:copy() { # Copy standard input in UTF-8
  LC_CTYPE=UTF-8 pbcopy
}

ds:tmp() { # mktemp -q "/tmp/${filename}"
  local filename="$1"
  local tmp=$(mktemp -q "/tmp/${filename}.XXXXX")
  echo $tmp
}

ds:fail() { # Safe failure, kills parent but returns to prompt
  local shell="$(ds:sh)"
  if [[ "$shell" =~ "bash" ]]; then
    : "${_err_?$1}"
  else
    echo "$1"
    : "${_err_?Operation intentionally failed by fail command}"
  fi
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

ds:rev() { # ** Bash-only solution to reverse lines for processing
  local line
  if IFS= read -r line; then
    ds:rev
    printf '%s\n' "$line"
  fi
}

ds:dup_input() { # ** Duplicate input sent to STDIN in aggregate
  tee /tmp/showlater && cat /tmp/showlater && rm /tmp/showlater
}

ds:join_by() { # ** Join a shell array by a text argument provided
  local d=$1; shift
  local shell="$(ds:sh)"

  if ds:pipe_open; then
    local pipeargs=($(cat /dev/stdin))
    local arr_base=$(ds:arr_base)
    let join_start=$arr_base+1
    [ -z ${pipeargs[$join_start]} ] && echo Not enough args to join! && return 1
    local first="${pipeargs[$arr_base]}"
    local args=( ${pipeargs[@]:1} "$@" )
    set -- "${args[@]}"
  else
    [ -z $2 ] && echo Not enough args to join! && return 1
    local first="$1"; shift
    local args=( "$@" )
  fi

  echo -n "$first"; printf "%s" "${args[@]/#/$d}"
}

ds:re_substr() { # ** Extract a substring from a string with regex anchors
  if ds:pipe_open; then
    local str="$(cat /dev/stdin)"
    local leftanc="$1" rightanc="$2"
  else
    local str="$1" leftanc="$2" rightanc="$3"
    [ -z $str ] && ds:fail 'String required for substring extraction'
  fi
  if [[ $leftanc && $rightanc ]]; then
    local sedstr="s/$leftanc//;s/$rightanc//"
    local out="$(grep -Eo "$leftanc.*?[^\\]$rightanc" <<< "$str" | sed $sedstr)"
  elif [ $leftanc ]; then
    local sedstr="s/$leftanc//"
    local out="$(grep -Eo "$leftanc.*?[^\\]" <<< "$str" | sed $sedstr)"
  elif [ $rightanc ]; then
    local sedstr="s/$rightanc//"
    local out="$(grep -Eo ".*?[^\\]$rightanc" <<< "$str" | sed $sedstr)"
  else
    out="$str"
  fi
  [ $out ] && printf "$out" || echo 'No string match to extract'
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
  local filename="${filename%.*}"
  local out=( "$dirpath/" "$filename" "$extension" )
  printf '%s\t' "${out[@]}"
}

ds:root() { # Returns the root volume / of the system
  for vol in /Volumes/*; do
    if [ "$(readlink "$vol")" = / ]; then
      local root=$vol
      printf $root
    fi
  done
}

ds:src() { # Source a piece of file: ds:src file ["searchx" pattern] || [line endline] || [pattern linesafter]
  local tmp=/tmp/ds:src
  if [ "$2" = searchx ]; then
    [ $3 ] && ds:searchx "$1" "$3" > $tmp
    if ds:is_cli; then
      cat $tmp
      echo
      confirm="$(ds:readp 'Confirm source action: (y/n)' | ds:downcase)"
      [ $confirm != y ] && rm $tmp && echo 'External code not sourced' && return
    fi
    source $tmp; rm $tmp
    [ $confirm ] && echo -e "Selection confirmed - new code sourced"
    return
  fi
  ds:file_check "$1"; local file="$1"
  if ds:is_int "$2"; then
    local line=$2 
    if ds:is_int "$3"; then
      local endline=$3
      ds:reo "$file" "$line-$endline" > $tmp
    else
      ds:reo "$file" "$line" > $tmp
    fi
    source $tmp; rm $tmp
  elif [ $2 ]; then
    ds:is_int $3 && local linesafter=(-A $3)
    source <(cat "$file" | grep "$pattern" ${linesafter[@]})
  else
    source "$file"
  fi
  :
}

ds:fsrc() { # Show the source of a shell function
  local shell=$(ds:sh) tmp=/tmp/fsrc
  if [[ $shell =~ bash ]]; then
    bash --debugger -c "source ~/.bashrc; declare -F $1" > $tmp
    if [ ! -s $tmp ]; then
      which "$1"; return $?
    fi
    local file=$(awk '{for(i=1;i<=NF;i++)if(i>2)printf "%s",$i}' $tmp \
      2> /dev/null | head -n1)
    awk -v f="$file" '{ print f ":" $2 }' $tmp
  elif [[ $shell =~ zsh ]]; then
    grep '> source' <(zsh -xc "declare -F $1" 2>&1) \
      | awk '{ print substr($0, index($0, "> source ")+9) }' > $tmp
    local file="$(grep --files-with-match -En "$1 ?\(.*?\)" \
      $(ds:mini $tmp) 2> /dev/null | head -n1)"
    if [ -z $file ]; then
      which "$1"; return $?
    fi
    echo "$file"
  fi
  ds:searchx "$file" "$1"
  rm $tmp
}

ds:trace() { # Search shell function trace for a pattern: ds:trace "command" [search]
  [ -z $1 ] && ds:fail 'Command required for trace'
  grep --color=always "$2" <(set -x &> /dev/null; eval "$1" 2>&1)
}

ds:lbv() { # Generate a cross table of git repos vs branches - set configuration in scripts/support/lbv.conf
  ds:nset 'fd' && local use_fd="-f"
  ds:src "${DS_SUPPORT}/lbv.conf" 2 3
  [ $LBV_DEPTH ] && local maxdepth=(-D $LBV_DEPTH)
  [ $LBV_SHOWSTATUS ] && local showstatus=-s
  bash $DS_SCRIPT/local_branch_view.sh ${@} $use_fd $showstatus ${maxdepth[@]}
}

ds:plb() { # Purge branch name(s) from all local git repos associated
  bash $DS_SCRIPT/purge_local_branches.sh
}

ds:env_refresh() { # Pull latest master branch for all git repos, run installs
  bash $DS_SCRIPT/local_env_refresh.sh
}

ds:git_checkout() { # Checkout a branch in the current repo matching a given pattern (alias ds:gco)
  bash $DS_SCRIPT/git_checkout.sh ${@}
}
alias ds:gco="ds:git_checkout"

ds:git_time_stat() { # Time of last pull, or last commit if no last pull (alias ds:gl)
  ds:not_git && return 1
  local last_pull="$(stat -c %y "$(git rev-parse --show-toplevel)/.git/FETCH_HEAD" 2>/dev/null)"
  local last_change="$(stat -c %y "$(git rev-parse --show-toplevel)/.git/HEAD" 2>/dev/null)"
  local last_commit="$(git log -1 --format=%cd)"
  if [ $last_pull ]; then
    local last_pull="$(date --date="$last_pull" "+%a %b %d %T %Y %z")"
    printf "%-40s%-30s\n" "Time of last pull:" "${last_pull}"
  else
    echo "No pulls found"
  fi
  if [ $last_change ]; then
    local last_change="$(date --date="$last_change" "+%a %b %d %T %Y %z")"
    printf "%-40s%-30s\n" "Time of last local change:" "${last_change}"
  else
    echo "No local changes found"
  fi
  [ $last_commit ] && printf "%-40s%-30s\n" "Time of last commit found locally:" "${last_commit}" || echo "No local commit found"
}
alias ds:gt="git_time_stat"

ds:git_status() { # Run git status for all repos (alias ds:gs)
  bash $DS_SCRIPT/all_repo_git_status.sh
}
alias ds:gs="ds:git_status"

ds:git_branch() { # Run git branch for all repos (alias ds:gb)
  bash $DS_SCRIPT/all_repo_git_branch.sh
}
alias ds:gb="ds:git_branch"

ds:git_add_all() { # Add all untracked git files (alias ds:ga)
  ds:not_git && return 1
  local all_untracked=( $(git ls-files -o --exclude-standard) )
  if [ -z "${all_untracked[$(ds:arr_base)]}" ]; then
    echo 'No untracked files found to add'
  else
    startdir="$PWD"
    rootdir="$(git rev-parse --show-toplevel)"
    cd "$rootdir"
    git add .
    cd "$startdir"
  fi
}
alias ds:ga="ds:git_add_all"

ds:git_push_cur() { # git push origin for current branch (alias ds:gp)
  ds:not_git && return 1
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  git push origin "$current_branch"
};
alias ds:gp="ds:git_push_cur"

ds:git_add_com_push() { # Add all untracked files, commit with message, push current branch (alias ds:gacmp)
  ds:not_git && return 1
  local commit_msg="$1"
  ds:git_add_all; ds:gcam "$commit_msg"; ds:git_push_cur
}
alias ds:gacmp="ds:git_add_com_push"

ds:git_recent() { # Display table of commits sorted by recency descending (alias ds:gr)
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
alias ds:gr="ds:git_recent"

ds:git_recent_all() { # Display table of recent commits for all home dir branches (alias ds:gra)
  local start_dir="$PWD" all_recent=/tmp/git_recent_all
  local w="\033[37;1m" nc="\033[0m"
  cd ~
  echo "${w}repo${nc}||${w}branch${nc}||sortfield${nc}||${w}commit time${nc}||${w}commit message${nc}||${w}author${nc}" > $all_recent
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
alias ds:gra="ds:git_recent_all"

ds:git_graph() { # Print colorful git history graph (alias ds:gg)
  ds:not_git && return 1
  git log --all --decorate --oneline --graph # git log a dog.
}
alias ds:gg="ds:git_graph"

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

ds:searchx() { # Search a file with top-level curly braces for a name
  ds:file_check "$1"
  if [ $2 ]; then
    awk -f $DS_SCRIPT/top_curly.awk -v search="$2" "$1" | ds:pipe_check
  else
    awk -f $DS_SCRIPT/top_curly.awk "$1" | ds:pipe_check
  fi
  # TODO: Add variable search
}

ds:select() { # ** Select code from a file by regex anchors: ds:select file [startline endline]
  if ds:pipe_open; then
    local file=/tmp/select piped=0 start="$2" end="$3"
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1" start="$2" end="$3"
  fi
  awk "/$start/,/$end/{print}" "$file"
  ds:pipe_clean $file
}

ds:insert() { # ** Redirect input into a file at a specified line number or pattern: ds:insert file [lineno|pattern] [sourcefile]
  ds:file_check "$1"
  local sink="$1" where="$2" source=/tmp/selectsource tmp=/tmp/select
  local nsinklines=$(cat $sink | wc -l)
  if ds:is_int "$where"; then
    [ $where -lt $nsinklines ] || ds:fail 'Insertion point not provided or invalid'
    local lineno=$where
  elif [ ! -z "$where" ]; then
    local pattern="$where"
    if [ $(grep "$pattern" "$sink" | wc -l) -gt 1 ]; then
      local conftext='File contains multiple instaces of pattern - are you sure you want to proceed? (y|n)'
      local confirm="$(ds:readp "$conftext" | ds:downcase)"
      [ $confirm != y ] && echo 'Exit with no insertion' && return 1
    fi
  else
    ds:fail 'Insertion point not provided or invalid'
  fi
  if ds:pipe_open; then
    local piped=0; cat /dev/stdin > $source
  else
    if [ -f "$3" ]; then
      cat "$3" > $source
    elif [ $3 ]; then
      echo "$3" > $source
    else
      ds:fail 'Insertion source not provided'
    fi
  fi
  awk -v src="$src" -v lineno=$lineno -v pattern="$pattern" \
    -f $DS_SCRIPT/insert.awk "$sink" $source > $tmp
  cat $tmp > "$sink"
  ds:pipe_clean $source; ds:pipe_clean $tmp
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
    local fs1="$(ds:inferfs "$file1" true)" fs2="$(ds:inferfs "$file2" true)"

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

ds:print_matches() { # ** Print duplicate lines on given field numbers in two files (alias ds:pm)
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
    local fs1="$(ds:inferfs "$file1" true)" fs2="$(ds:inferfs "$file2" true)"

    awk -v fs1="$fs1" -v fs2="$fs2" -f $DS_SCRIPT/matches.awk \
      "${args[@]}" "$file1" "$file2" 2> /dev/null
  else
    awk -f $DS_SCRIPT/matches.awk "${args[@]}" "$file1" "$file2" 2> /dev/null
  fi
  
  ds:pipe_clean $file2
}
alias ds:pm="ds:print_matches"

ds:print_comps() { # ** Print non-matching lines on given field numbers in two files (alias ds:pc)
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
    local fs1="$(ds:inferfs "$file1" true)" fs2="$(ds:inferfs "$file2" true)"

    awk -v fs1="$fs1" -v fs2="$fs2" -f $DS_SCRIPT/complements.awk \
      "${args[@]}" "$file1" "$file2" 2> /dev/null
  else
    awk -f $DS_SCRIPT/complements.awk "${args[@]}" "$file1" "$file2" 2> /dev/null
  fi
  
  ds:pipe_clean $file2
}
alias ds:pm="ds:print_matches"

ds:inferh() { # Infer if headers are present in a file: ds:inferh [awkargs] file
  local args=( "$@" )
  awk -f $DS_SCRIPT/infer_headers.awk "${args[@]}" 2> /dev/null
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
    local fs1="$(ds:inferfs "$file1" true)" fs2="$(ds:inferfs "$file2" true)"

    awk -v fs1="$fs1" -v fs2="$fs2" -f $DS_SCRIPT/infer_join_fields.awk \
      "${args[@]}" "$file1" "$file2" 2> /dev/null
  else
    awk -f $DS_SCRIPT/infer_join_fields.awk "${args[@]}" "$file1" "$file2" 2> /dev/null
  fi

  ds:pipe_clean $file2
}

ds:inferfs() { # Infer field separator from data: inferfs file [reparse=false] [try_custom=true] [use_file_ext=true]
  ds:file_check "$1"
  local file="$1" reparse=${2:-false} custom=${3:-true} use_file_ext=${4:-true}

  if [ $use_file_ext = true ]; then
    read -r dirpath filename extension <<<$(ds:path_elements "$file")
    if [ $extension ]; then
      [ ".tsv" = "$extension" ] && echo "\t" && return
      [ ".csv" = "$extension" ] && echo ',' && return
    fi
  fi

  [ $custom = true ] || custom=""

  if [ $reparse = true ]; then
    awk -f $DS_SCRIPT/infer_field_separator.awk -v high_certainty=1 \
      -v custom=$custom "$file" 2> /dev/null | sed 's/\\/\\\\\\/g'
  else
    awk -f $DS_SCRIPT/infer_field_separator.awk -v high_certainty=1 \
      -v custom=$custom "$file" 2> /dev/null
  fi
}

ds:fit() { # ** Print field-separated data in columns with dynamic width: ds:fit [awkargs] file
  local args=( "$@" ) col_buffer=${col_buffer:-2} tty_size=$(tput cols)
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
    local fs="$(ds:inferfs "$file" true)"
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
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" -f $DS_SCRIPT/stagger.awk -v tty_size=$tty_size \
      ${args[@]} "$file" 2> /dev/null
  else
    awk -f $DS_SCRIPT/stagger.awk ${args[@]} -v tty_size=$tty_size "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:idx() { # ** Prints an index attached to data lines from a file or stdin
  if ds:pipe_open; then
    local header=$1 args=( "${@:2}" ) file=/tmp/index_showlater piped=0
    cat /dev/stdin > $file
  else
    local file="$1" header=$2 args=( "${@:3}" )
  fi
  local program="$([ $header ] && echo '{ print NR-1, $0 }' || echo '{ print NR, $0 }')"
  if ds:noawkfs; then
    local fs="$(inferfs "$file" true)"
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
    ds:file_check "$1"
    local file="$1" rows="$2" cols="$3" args=( "${@:4}" )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" ${args[@]} -v r=$rows -v c=$cols -f $DS_SCRIPT/reorder.awk \
      "$file" 2> /dev/null
  else
    awk ${args[@]} -v r=$rows -v c=$cols -f $DS_SCRIPT/reorder.awk "$file" 2> /dev/null
  fi
}

ds:decap() { # ** Remove up to a certain number of lines from the start of a file, default is 1
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

ds:transpose() { # ** Transpose field values of a text-based field-separated file (alias ds:t)
  local args=( "$@" )
  if ds:pipe_open; then
    local file=/tmp/transpose piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    local args=( ${args[@]/"$file"} )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" -f $DS_SCRIPT/transpose.awk \
      ${args[@]} "$file" 2> /dev/null
  else
    awk -f $DS_SCRIPT/transpose.awk ${args[@]} \
      "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}
alias ds:t="ds:transpose"

ds:ds() { # Generate statistics about text data: ds:ds file [awkargs]
  ds:file_check "$1"
  local file="$1"; shift
  local args=( "$@" )
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk ${[@]} -v FS="$fs" -f $DS_SCRIPT/power.awk "$file"
  else
    awk ${[@]} -f $DS_SCRIPT/power.awk "$file"
  fi
}

ds:fieldcounts() { # Print value counts: ds:fieldcounts file [fields=1] [min=1] [order=a] [awkargs] (alias ds:fc)
  ds:file_check "$1"
  local file="$1" fields="${2:-1}" min=$3
  [ $4 ] && ([ $4 = d ] || [ $4 = desc ]) && local order="r"
  shift; shift; [ $min ] && shift; [ $order ] && shift; local args=( "$@" )
  ([ $min ] && test $min -gt 0 2> /dev/null) || local min=1
  let min=$min-1
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk ${@} -v min=$min -v fields="$fields" -F"$fs" -v OFS="||" \
      -f $DS_SCRIPT/field_counts.awk "$file" 2> /dev/null | sort -n$order
  else
    awk ${@} -v min=$min -v fields="$fields" -v OFS="||" \
      -f $DS_SCRIPT/field_counts.awk "$file" 2> /dev/null | sort -n$order
  fi
}
alias ds:fc="ds:fieldcounts"

ds:newfs() { # ** Outputs a file with an updated field separator: ds:newfs [] [newfs=,] [file]
  local args=( "$@" )
  let last_arg=${#args[@]}-1
  if ds:pipe_open; then
    local file=/tmp/newfs piped=0
    cat /dev/stdin > $file
  else 
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    let last_arg-=1
    local args=( ${args[@]/"$file"} )
  fi
  [ $last_arg -gt 0 ] && local newfs="${args[@]:$last_arg:1}"
  local newfs="${newfs:-,}"
  local program="BEGIN { OFS=\"${newfs}\" } { for (i = 1; i < NF; i++) {printf \$i OFS} print \$NF }"
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" $program ${args[@]} "$file" 2> /dev/null
  else
    awk ${args[@]} $program "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
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
  local program="$DS_SCRIPT/separated_entities.awk"
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

ds:mini() { # ** Crude minify, remove whitespace including newlines except space
  if ds:pipe_open; then
    cat /dev/stdin > /tmp/mini_showlater;
    local file=/tmp/mini_showlater piped=0
  else
    ds:file_check "$1"
    local file="$1"
  fi
  awk -v RS="\0" '{ gsub("(\n|\t)" ," "); print }' "$file" 2> /dev/null
  ds:pipe_clean $file
}

ds:infsort() { # ** Sort with an inferred field separator of exactly 1 char
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
  local fs="$(ds:inferfs $file true)"
  sort ${args[@]} -v FS="$fs" "$file"
  ds:pipe_clean $file
}

ds:infsortm() { # ** Sort with an inferred field separator of 1 or more character (alias ds:ism)
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
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" -f $DS_SCRIPT/fields_qsort.awk ${args[@]} "$file" 2> /dev/null
  else
    awk -f $DS_SCRIPT/fields_qsort.awk ${args[@]} "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}
alias ds:ism="ds:infsortm"

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
    [ $invert ] && local invert="${invert}es"
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
  local file="$1" search="$(printf -q $2)" replace="$(printf -q $3)"
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

ds:unicode() { # Get the UTF-8 unicode for a given character
  ! ds:nset 'xxd' && ds:fail 'utility xxd required for this command'
  local str="$1"
  local prg='{ if ($3) {
        b[1]=substr($2,5,4);b[2]=substr($3,3,6)
        b[3]=substr($4,3,6);b[4]=substr($5,3,6)
      } else { b[1]=substr($2,2,7) }
      for(i=1;i<=length(b);i++){d=d b[i]}
      print "obase=16; ibase=2; " d}'
  for i in $(echo "$str" | grep -o .); do
    local code="$(printf "$i" | xxd -b | awk -F"[[:space:]]" "$prg" | bc)"
    printf "\\\U$code"
  done
  echo
}

ds:webpage_title() { # Downloads html from a webpage and extracts the title text
  local location="$1"
  local tr_file="$DS_SUPPORT/named_entities_escaped.sed"
  local unescaped_title="$( wget -qO- "$location" |
    perl -l -0777 -ne 'print $1 if /<title.*?>\s*(.*?)\s*<\/title/si' )"

  if [ -f $tr_file ]; then
    printf "$unescaped_title" | sed -f $tr_file
  else
    printf "$unescaped_title"
  fi
}

ds:dups() { # Report duplicate files with option for deletion
  if ! ds:nset 'md5sum'; then
    echo 'md5sum utility not found - please install GNU coreutils to enable this command'
    return 1
  fi
  ds:nset 'pv' && local use_pv="-p"
  ds:nset 'fd' && local use_fd="-f"
  [ -d "$1" ] && local dir="$1" || local dir="$PWD"
  bash $DS_SCRIPT/dup_files.sh -s $dir $use_fd $use_pv
}

ds:commands() { # List functions defined in the dev_scripts/.commands.sh file
  echo
  grep '[[:alnum:]_]*()' $DS_LOC/.commands.sh | sed 's/^  function //' \
    | grep -hv grep | sort | awk -F "\\\(\\\) { #" '{printf "%-18s\t%s\n", $1, $2}'
  echo
  echo "** - function supports receiving piped data"
  echo
}

