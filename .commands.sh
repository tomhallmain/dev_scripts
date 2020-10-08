#!/bin/bash

DS_LOC="$HOME/dev_scripts"
DS_SCRIPT="${DS_LOC}/scripts"
DS_SUPPORT="${DS_LOC}/support"
source "${DS_SUPPORT}/utils.sh"

ds:commands() { # List commands in the dev_scripts/.commands.sh file
  # TODO: Split out / map aliases and args
  echo
  echo "** - function supports receiving piped data"
  echo
  grep -h '[[:alnum:]_]*()' "$DS_LOC/.commands.sh" | sed 's/^  function //' \
    | grep -hv grep | sort | awk -F "\\\(\\\) { #" 'BEGIN{printf "%-18s\t%s\n",
       "COMMAND", "DESCRIPTION"}{printf "%-18s\t%s\n", $1, $2}' \
    | ds:sbsp '\\\*\\\*' "$DS_SEP" -v retain_pattern=1 -v apply_to_fields=2 \
    -v FS="[[:space:]]{2,}" -v OFS="$DS_SEP" | ds:reo a 2,1,3 | ds:fit -v FS="$DS_SEP"
  echo
  echo "** - function supports receiving piped data"
  echo
}

ds:help() { # Print help for a given command
  (ds:nset "$1" && [[ "$1" =~ "ds:" ]]) || ds:fail 'Command not found - to see all commands, run ds:commands'
  [[ "$1" =~ 'reo' ]] && ds:reo -h && return
  [[ "$1" =~ 'fit' ]] && ds:fit -h && return
  [[ "$1" =~ 'stag' ]] && ds:stag -h && return
  ds:commands | ds:reo "2~$1" 3 -v FS="[[:space:]]{2,}" | cat
}

ds:gvi() { # Grep for a line in a file/dir and open vim on the first match: ds:gvi search [file|dir]
  local search="$1"
  if [ -f "$2" ]; then local file="$2"
    if ds:nset 'rg'; then
      local line=$(rg --line-number "$search" "$file" | head -n1 | ds:reo 1 1 -v FS=":")
    else
      local line=$(grep --line-number "$search" "$file" | head -n1 | ds:reo 1 1 -v FS=":")
    fi
  else
    local tmp=$(ds:tmp 'ds_gvi')
    [ -d "$2" ] && local dir="$2"
    if [ -z $dir ]; then
      local dir="." basedir_f=($(find . -maxdepth 0 -type f | grep -v ":"))
      [ ! "$2" = "" ] && local filesearch="1~$2" || local filesearch=1
      if ds:nset 'rg'; then
        rg -Hno --no-heading --hidden --color=never -g '!*:*' -g '!.git' \
          "$search" ${basedir_f[@]} "$dir" > $tmp
      else
        grep -HInors --color=never --exclude ':' --excludedir '.git' \
          "$search" ${basedir_f[@]} "$dir" > $tmp
      fi
      local file=$(ds:reo $tmp "$filesearch" 1 -F: -v q=1 | head -n1)
      local line=$(ds:reo $tmp "$filesearch" 2 -F: -v q=1 | head -n1)
    else
      local basedir_f=($(find "$dir" -maxdepth 0 -type f | grep -v ":"))
      if ds:nset 'rg'; then
        rg -Hno --no-heading --hidden --color=never -g '!*:*' -g '!.git' \
          "$search" ${basedir_f[@]} "$dir" | head -n1 > $tmp
      else
        grep -HInors --color=never --exclude ':' --excludedir '.git' \
          "$search" ${basedir_f[@]} "$dir" | head -n1 > $tmp
      fi
      local file=$(ds:reo $tmp 1 1 -F: -v q=1) line=$(ds:reo $tmp 1 2 -F: -v q=1)
    fi
    rm $tmp
    [ -f "$file" ] || ds:fail 'No match found'
  fi
  ds:is_int $line || ds:fail 'No match found'
  vi +$line "$file" || return 1
}

ds:searchn() { # Searches current names for string, returns matches
  ds:ndata | awk -v s="$1" '$0~s{print}'
}

ds:nset() { # Test if name (function, alias, variable) is defined in context
  [ "$2" ] && ds:ntype "$1" &> /dev/null || type "$1" &> /dev/null
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

ds:cp() { # Copy standard input in UTF-8
  # TODO: Other copy utilities to handle case when pbcopy is not installed
  LC_CTYPE=UTF-8 pbcopy
}

ds:tmp() { # mktemp -q "/tmp/${filename}"
  mktemp -q "/tmp/${1}.XXXXX"
}

ds:fail() { # Safe failure, kills parent but returns to prompt
  bash "$DS_SUPPORT/clean.sh"
  local shell="$(ds:sh)"
  if [[ "$shell" =~ "bash" ]]; then
    : "${_err_?$1}"
  else
    echo -e "\e[31;1m$1"
    : "${_err_?Operation intentionally failed by fail command}"
  fi
}

ds:pipe_check() { # ** Detect if pipe has any data, or over a certain number of lines
  local chkfile=$(ds:tmp 'ds_pipe_check')
  tee > $chkfile
  if [ -z "$1" ]; then
    test -s $chkfile
  else
    [ $(cat $chkfile | wc -l) -gt $1 ]
  fi
  local has_data=$?; cat $chkfile; rm $chkfile; return $has_data
}

ds:rev() { # ** Bash-only solution to reverse lines for processing
  local line
  if IFS= read -r line; then
    ds:rev
    printf '%s\n' "$line"
  fi
}

ds:dup_input() { # ** Duplicate input sent to STDIN in aggregate
  local file=$(ds:tmp 'ds_dup_input')
  tee $file && cat $file && rm $file
}

ds:join_by() { # ** Join a shell array by a text argument provided
  local d=$1; shift

  if ds:pipe_open; then
    local pipeargs=($(cat /dev/stdin))
    local arr_base=$(ds:arr_base)
    let join_start=$arr_base+1
    [ -z ${pipeargs[$join_start]} ] && echo Not enough args to join! && return 1
    local first="${pipeargs[$arr_base]}"
    local args=( ${pipeargs[@]:1} "$@" )
    set -- "${args[@]}"
  else
    [ -z "$2" ] && echo Not enough args to join! && return 1
    local first="$1"; shift
    local args=( "$@" )
  fi

  echo -n "$first"; printf "%s" "${args[@]/#/$d}"
}

ds:test() { # ** Test input quietly using with extended regex: ds:test regex [str|file] [test_file=f]
  ds:pipe_open && grep -Eq "$1" && return $?
  [[ ! "$3" =~ t ]] && echo "$2" | grep -Eq "$1" && return $?
  [ -f "$2" ] && grep -Eq "$1" "$2"
}

ds:substr() { # ** Extract a substring from a string with regex: ds:substr str [leftanc] [rightanc]
  if ds:pipe_open; then
    local str="$(cat /dev/stdin)"
    local leftanc="$1" rightanc="$2"
  else
    local str="$1" leftanc="$2" rightanc="$3"
    [ -z "$str" ] && ds:fail 'String required for substring extraction'
  fi
  if [ "$rightanc" ]; then
    [ -z "$leftanc" ] && local sedstr="s/$rightanc//" || local sedstr="s/$leftanc//;s/$rightanc//"
    local out="$(grep -Eo "$leftanc.*?[^\\]$rightanc" <<< "$str" | sed $sedstr)"
  elif [ "$leftanc" ]; then
    local sedstr="s/$leftanc//"
    local out="$(grep -Eo "$leftanc.*?[^\\]" <<< "$str" | sed $sedstr)"
  else
    out="$str"
  fi
  [ "$out" ] && printf "$out" || echo 'No string match to extract'
}

ds:iter() { # Repeat a string some number of times: ds:iter str [n=1] [fs]
  local str="$1" fs="${3:- }" liststr="$1"
  let n_repeats=${2:-1}-1
  for ((i=1;i<=$n_repeats;i++)); do liststr="${liststr}${fs}${str}"; done
  echo -n "$liststr"
}

ds:embrace() { # Enclose a string in braces: embrace string [openbrace="{"] [closebrace="}"]
  local value="$1" 
  [ -z "$2" ] && local openbrace="{" || local openbrace="$2"
  [ -z "$3" ] && local closebrace="}" || local closebrace="$3"
  echo "${openbrace}${value}${closebrace}"
}

ds:filename_str() { # Adds a string to the beginning or end of a filename
  read -r dirpath filename extension <<<$(ds:path_elements "$1")
  [ ! -d "$dirpath" ] && echo 'Filepath given is invalid' && return 1
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
  local tmp=/tmp/ds_src
  if [ "$2" = searchx ]; then
    [ "$3" ] && ds:searchx "$1" "$3" > $tmp
    if ds:is_cli; then
      cat $tmp
      echo
      confirm="$(ds:readp 'Confirm source action: (y/n)' | ds:downcase)"
      [ "$confirm" != "y" ] && rm $tmp && echo 'External code not sourced' && return
    fi
    source $tmp; rm $tmp
    [ "$confirm" ] && echo -e "Selection confirmed - new code sourced"
    return
  fi
  ds:file_check "$1"; local file="$1"
  if ds:is_int "$2"; then
    local line=$2 
    if ds:is_int "$3"; then
      local endline=$3
      ds:reo "$file" "$line..$endline" > $tmp
    else
      ds:reo "$file" "$line" > $tmp
    fi
    source $tmp; rm $tmp
  elif [ "$2" ]; then
    ds:is_int $3 && local linesafter=(-A $3)
    source <(cat "$file" | grep "$pattern" ${linesafter[@]})
  else
    source "$file"
  fi
  :
}

ds:fsrc() { # Show the source of a shell function: ds:fsrc func
  local shell=$(ds:sh) tmp=$(ds:tmp 'ds_fsrc')
  # TODO: Fix both cases
  if [[ $shell =~ bash ]]; then
    bash --debugger -c 'echo' &> /dev/null
    [ $? -eq 0 ] && \
      bash --debugger -c "source ~/.bashrc; declare -F $1" > $tmp
    if [ ! -s $tmp ]; then
      which "$1"; rm $tmp; return $?
    fi
    local file=$(awk '{for(i=1;i<=NF;i++)if(i>2)printf "%s",$i}' $tmp \
      2> /dev/null | head -n1)
    awk -v f="$file" '{ print f ":" $2 }' $tmp
  elif [[ $shell =~ zsh ]]; then
    grep '> source' <(zsh -xc "declare -F $1" 2>&1) \
      | awk '{ print substr($0, index($0, "> source ")+9) }' > $tmp
    local file="$(grep --files-with-match -En "$1 ?\(.*?\)" \
      $(cat $tmp) 2> /dev/null | head -n1)"
    if [ -z $file ]; then
      which "$1"; rm $tmp; return $?
    fi
    echo "$file"
  fi
  ds:searchx "$file" "$1" q
  rm $tmp
}

ds:trace() { # Search shell trace for a pattern: ds:trace ["command"] [search]
  if [ -z "$1" ]; then
    cmd="$(fc -ln -1)"
    [[ "\"$cmd\"" =~ 'ds:trace' ]] && return 1
    ds:readp 'Press enter to trace last command'
  else
    cmd="$1"
  fi
  grep --color=always "$2" <(set -x &> /dev/null; eval "$cmd" 2>&1)
}

ds:git_cross_view() { # Generate a cross table of git repos vs branches (alias ds:gcv) - set config in scripts/support/lbv.conf
  ds:nset 'fd' && local use_fd="-f"
  source "${DS_SUPPORT}/lbv.conf"
  [ "$LBV_DEPTH" ] && local maxdepth=(-D $LBV_DEPTH)
  [ "$LBV_SHOWSTATUS" ] && local showstatus=-s
  bash "$DS_SCRIPT/local_branch_view.sh" ${@} $use_fd $showstatus ${maxdepth[@]}
}
alias ds:gcv="ds:git_cross_view"

ds:git_purge_local() { # Purge branch name(s) from all local git repos associated (alias ds:gpl)
  bash "$DS_SCRIPT/purge_local_branches.sh" ${@}
}
alias ds:gpl="ds:git_purge_local"

ds:git_repos_refresh() { # Pull latest master branch for all git repos, run installs (alias ds:grr)
  bash "$DS_SCRIPT/local_env_refresh.sh" ${@}
}
alias ds:grr="ds:git_repos_refresh"

ds:git_checkout() { # Checkout a branch in the current repo matching a given pattern (alias ds:gco)
  bash "$DS_SCRIPT/git_checkout.sh" ${@}
}
alias ds:gco="ds:git_checkout"

ds:git_time_stat() { # Time of last pull, or last commit if no last pull (alias ds:gts)
  ds:not_git && return 1
  local last_pull="$(stat -c %y "$(git rev-parse --show-toplevel)/.git/FETCH_HEAD" 2>/dev/null)"
  local last_change="$(stat -c %y "$(git rev-parse --show-toplevel)/.git/HEAD" 2>/dev/null)"
  local last_commit="$(git log -1 --format=%cd)"
  if [ "$last_pull" ]; then
    local last_pull="$(date --date="$last_pull" "+%a %b %d %T %Y %z")"
    printf "%-40s%-30s\n" "Time of last pull:" "${last_pull}"
  else
    echo "No pulls found"
  fi
  if [ "$last_change" ]; then
    local last_change="$(date --date="$last_change" "+%a %b %d %T %Y %z")"
    printf "%-40s%-30s\n" "Time of last local change:" "${last_change}"
  else
    echo "No local changes found"
  fi
  [ "$last_commit" ] && printf "%-40s%-30s\n" "Time of last commit found locally:" "${last_commit}" || echo "No local commit found"
}
alias ds:gts="ds:git_time_stat"

ds:git_status() { # Run git status for all repos (alias ds:gs)
  bash "$DS_SCRIPT/all_repo_git_status.sh" ${@}
}
alias ds:gs="ds:git_status"

ds:git_branch() { # Run git branch for all repos (alias ds:gb)
  bash "$DS_SCRIPT/all_repo_git_branch.sh" ${@}
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
  local run_context="${1:-display}"
  if [ "$run_context" = display ]; then
    local format='%(HEAD) %(color:yellow)%(refname:short)@@@%(color:bold green)%(committerdate:relative)@@@%(color:blue)%(subject)@@@%(color:magenta)%(authorname)%(color:reset)'
    git for-each-ref --sort=-committerdate refs/heads \
      --format="$format" --color=always | ds:fit -F"$DS_SEP"
  else
    # If not for immediate display, return extra field for further parsing
    local format='%(HEAD) %(color:yellow)%(refname:short)@@@%(committerdate:short)@@@%(color:bold green)%(committerdate:relative)@@@%(color:blue)%(subject)@@@%(color:magenta)%(authorname)%(color:reset)'
    git for-each-ref refs/heads --format="$format" --color=always
  fi
}
alias ds:gr="ds:git_recent"

ds:git_recent_all() { # Display table of recent commits for all home dir branches (alias ds:gra)
  local start_dir="$PWD" all_recent=$(ds:tmp 'ds_git_recent_all')
  local w="\033[37;1m" nc="\033[0m"
  [ -d "$1" ] && cd "$1" || cd ~
  echo -e "${w}repo${nc}@@@${w}branch${nc}@@@sortfield${nc}@@@${w}commit time${nc}@@@${w}commit message${nc}@@@${w}author${nc}" > $all_recent
  while IFS=$'\n' read -r dir; do
    [ -d "${dir}/.git" ] && (cd "$dir" && \
      (ds:git_recent parse | awk -v repo="$dir" -F"$DS_SEP" '
        {print "\033[34m" repo "\033[0m@@@", $0}') >> $all_recent )
  done < <(find * -maxdepth 0 -type d)
  echo
  ds:sortm -v order=d -F"$DS_SEP" -v k=3 $all_recent \
    | ds:reo "a" "NF!=3" -F"$DS_SEP" -v OFS="$DS_SEP" | ds:fit
  # TODO: Fix alignment
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

ds:todo() { # List todo items found in paths
  ds:nset 'rg' && local RG=true
  if [ -z $1 ]; then
    [ "$RG" ] && rg -His 'TODO' || grep -irs 'TODO' --color=always .
    echo
  else
    local search_paths=( "${@}" )
    for search_path in ${search_paths[@]} ; do
      if [[ ! -d "$search_path" && ! -f "$search_path" ]]; then
        echo "$search_path is not a file or directory or is not found"
        local bad_dir=0; continue
      fi
      [ "$RG" ] && rg -His 'TODO' "$search_path" \
        || grep -irs 'TODO' --color=always "$search_path"
      echo
    done
  fi
  [ -z $bad_dir ] || (echo 'Some paths provided could not be searched' && return 1)
}

ds:searchx() { # Search a file for a C-lang style (curly-brace) top-level object: ds:searchx file [search] [q]
  ds:file_check "$1"
  if [ "$3" ]; then
    if [ "$2" ]; then
      awk -f "$DS_SCRIPT/top_curly.awk" -v search="$2" "$1" && return
    else
      awk -f "$DS_SCRIPT/top_curly.awk" "$1" && return; fi
  else
    if [ "$2" ]; then
      awk -f "$DS_SCRIPT/top_curly.awk" -v search="$2" "$1" | ds:pipe_check
    else
      awk -f "$DS_SCRIPT/top_curly.awk" "$1" | ds:pipe_check; fi; fi
  # TODO: Add variable search
}

ds:select() { # ** Select code from a file by regex anchors: ds:select file [startpattern endpattern]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_select') piped=0 start="$2" end="$3"
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
  local sink="$1" where="$2" source=$(ds:tmp 'ds_selectsource') tmp=$(ds:tmp 'ds_select')
  local nsinklines=$(cat $sink | wc -l)
  if ds:is_int "$where"; then
    [ "$where" -lt "$nsinklines" ] || ds:fail 'Insertion point not provided or invalid'
    local lineno="$where"
  elif [ "$where" ]; then
    local pattern="$where"
    if [ $(grep "$pattern" "$sink" | wc -l) -gt 1 ]; then
      local conftext='File contains multiple instaces of pattern - are you sure you want to proceed? (y|n)'
      local confirm="$(ds:readp "$conftext" | ds:downcase)"
      [ "$confirm" != y ] && rm $source $tmp && echo 'Exit with no insertion' && return 1
    fi
  else
    rm $source $tmp; ds:fail 'Insertion point not provided or invalid'
  fi
  if ds:pipe_open; then
    local piped=0; cat /dev/stdin > $source
  else
    if [ -f "$3" ]; then
      cat "$3" > $source
    elif [ "$3" ]; then
      echo "$3" > $source
    else
      rm $source $tmp; ds:fail 'Insertion source not provided'
    fi
  fi
  awk -v src="$src" -v lineno=$lineno -v pattern="$pattern" \
    -f "$DS_SCRIPT/insert.awk" "$sink" $source > $tmp
  cat $tmp > "$sink"
  rm $source $tmp
}

ds:shape() { # Print text data shape by length or given field separator: ds:shape [file] [FS] [out]
  ds:file_check "$1"
  local file="$1" lines=$(cat "$1" | wc -l); shift
  ds:is_int "$2" && local printlns=$2 || local printlns=15
  let local span=$lines/$printlns
  awk -v FS="${1:- }" -v span=$span -v tty_size="$(tput cols)" -v lines="$lines" \
    -f "$DS_SCRIPT/shape.awk" "$file" 2>/dev/null
}

ds:jn() { # ** Join two files, or a file and stdin, with any keyset: ds:jn file1 [file2] [jointype] [k] [k2] [awkargs]
  ds:file_check "$1"
  local f1="$1"; shift
  if ds:pipe_open; then
    local f2=$(ds:tmp 'ds_jn') piped=0
    cat /dev/stdin > $f2
  else
    ds:file_check "$1"
    local f2="$1"; shift
  fi

  if [ $1 ]; then
    [[ $1 =~ '^l' ]] && local type='left'
    [[ $1 =~ '^i' ]] && local type='inner'
    [[ $1 =~ '^r' ]] && local type='right'
    [[ ! "$1" =~ '-' && ! "$1" =~ '^[0-9]+$' ]] && shift
  fi

  local has_keyarg=$(ds:arr_idx 'k[12]?=' ${@})
  if [ "$has_keyarg" = "" ]; then
    if ds:is_int "$1"; then
      local k="$1"; shift
      ds:is_int "$1" && local k1="$k" k2="$1" && shift
    elif [[ -z "$1" || "$1" =~ "-" ]]; then
      local k="$(ds:inferk "$f1" "$f2")"
      [[ "$k" =~ " " ]] && local k2=$(ds:re_substr "$k" " " "") k1=$(ds:re_substr "$k" "" " ")
    fi
    local args=( "$@" )
    [ "$k2" ] && local args=("${args[@]}" -v "k1=$k1" -v "k2=$k2") || local args=("${args[@]}" -v "k=$k")
  else local args=( "$@" )
  fi
  [ "$type" ] && local args=("${args[@]}" -v "join=$type")

  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"
    awk -v fs1="$fs1" -v fs2="$fs2" -f "$DS_SCRIPT/join.awk" \
      ${args[@]} "$f1" "$f2" 2> /dev/null | ds:ttyf "%fs1"
  else
    awk -f "$DS_SCRIPT/join.awk" ${args[@]} "$f1" "$f2" 2> /dev/mull | ds:ttyf
  fi

  ds:pipe_clean $f2
}

ds:print_matches() { # ** Print duplicate lines on given field numbers in two files (alias ds:pm)
  local args=( "$@" )
  let last_arg=${#args[@]}-1
  if ds:pipe_open; then
    local file2=$(ds:tmp 'ds_matches') piped=0
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

    awk -v fs1="$fs1" -v fs2="$fs2" -f "$DS_SCRIPT/matches.awk" \
      ${args[@]} "$file1" "$file2" 2> /dev/null | ds:ttyf
  else
    awk -f "$DS_SCRIPT/matches.awk" ${args[@]} "$file1" "$file2" \
      2> /dev/null | ds:ttyf
  fi
  
  ds:pipe_clean $file2
}
alias ds:pm="ds:print_matches"

ds:print_comps() { # ** Print non-matching lines on given field numbers in two files (alias ds:pc)
  local args=( "$@" )
  let last_arg=${#args[@]}-1
  if ds:pipe_open; then
    local file2=$(ds:tmp 'ds_complements') piped=0
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

    awk -v fs1="$fs1" -v fs2="$fs2" -f "$DS_SCRIPT/complements.awk" \
      ${args[@]} "$file1" "$file2" 2> /dev/null | ds:ttyf "$fs1"
  else
    awk -f "$DS_SCRIPT/complements.awk" ${args[@]} "$file1" "$file2" \
      2> /dev/null | ds:ttyf
  fi
  
  ds:pipe_clean $file2
}
alias ds:pc="ds:print_comps"

ds:inferh() { # Infer if headers are present in a file: ds:inferh [awkargs] file
  local args=( "$@" )
  awk -f "$DS_SCRIPT/infer_headers.awk" ${args[@]} 2> /dev/null
}

ds:inferk() { # ** Infer join fields in two text data files: ds:inferk [awkargs] file [file]
  local args=( "$@" )
  let last_arg=${#args[@]}-1
  if ds:pipe_open; then
    local file2=$(ds:tmp 'ds_inferk') piped=0
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
    ds:pipe_clean $file2
    return 1
  fi
  local args=( ${args[@]/"$file1"} )
  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$file1" true)" fs2="$(ds:inferfs "$file2" true)"

    awk -v fs1="$fs1" -v fs2="$fs2" -f "$DS_SCRIPT/infer_join_fields.awk" \
      ${args[@]} "$file1" "$file2" 2> /dev/null
  else
    awk -f "$DS_SCRIPT/infer_join_fields.awk" ${args[@]} "$file1" "$file2" 2> /dev/null
  fi

  ds:pipe_clean $file2
}

ds:inferfs() { # Infer field separator from data: inferfs file [reparse=false] [try_custom=true] [use_file_ext=true] [high_certainty=true]
  ds:file_check "$1"
  local file="$1" reparse="${2:-false}" custom="${3:-true}" use_file_ext="${4:-true}" hc="${5:-true}"

  if [ "$use_file_ext" = true ]; then
    read -r dirpath filename extension <<<$(ds:path_elements "$file")
    if [ "$extension" ]; then
      [ ".csv" = "$extension" ] && echo ',' && return
      [ ".tsv" = "$extension" ] && echo "\t" && return
    fi
  fi

  [ "$custom" = true ] || custom=""
  [ "$hc" = true ] || hc=""

  if [ "$reparse" = true ]; then
    awk -f "$DS_SCRIPT/infer_field_separator.awk" -v high_certainty="$hc" \
      -v custom="$custom" "$file" 2> /dev/null | sed 's/\\/\\\\\\/g'
  else
    awk -f "$DS_SCRIPT/infer_field_separator.awk" -v high_certainty="$hc" \
      -v custom="$custom" "$file" 2> /dev/null
  fi
}

ds:fit() { # ** Print field-separated data in columns with dynamic width: ds:fit file [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_fit') piped=0 hc=f
    cat /dev/stdin > $file
  else
    ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/fit_columns.awk" \
      | tr -d "#" | less && return
    ds:file_check "$1"
    local file="$1" hc=true; shift
  fi
  local args=( "$@" ) col_buffer=${col_buffer:-2} tty_size=$(tput cols)
  local dequote=$(ds:tmp "ds_fit_dequote")
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true true true $hc)"
  else
    local fs_idx="$(ds:arr_idx '^FS=' ${args[@]})"
    if [ "$fs_idx" = "" ]; then
      local fs_idx="$(ds:arr_idx '^\-F' ${args[@]})"
      local fs="$(echo "${args[$fs_idx]}" | tr -d '\-F')"
    else
      local fs="$(echo "${args[$fs_idx]}" | tr -d 'FS=')"
      let local fsv_idx=$fs_idx-1
      unset "args[$fsv_idx]"
    fi
    unset "args[$fs_idx]"
  fi
  ds:prefield "$file" "$fs" 0 > $dequote
  awk -v FS="$DS_SEP" -v OFS="$fs" -f "$DS_SCRIPT/fit_columns.awk" -v tty_size=$tty_size \
    -v buffer="$col_buffer" ${args[@]} $dequote{,} 2>/dev/null
  ds:pipe_clean $file; rm $dequote
}

ds:stag() { # ** Print field-separated data in staggered rows: ds:stag [awkargs] file
  local args=( "$@" ) tty_size=$(tput cols)
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_stagger') piped=0
    cat /dev/stdin > $file
  else
    ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/stagger.awk" \
      | tr -d "#" | less && return
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    args=( ${args[@]/"$file"} )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" ${args[@]} -f "$DS_SCRIPT/stagger.awk" -v tty_size=$tty_size \
      "$file" 2> /dev/null
  else
    awk ${args[@]} -v tty_size=$tty_size -f "$DS_SCRIPT/stagger.awk" "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:idx() { # ** Prints an index attached to data lines from a file or stdin
  if ds:pipe_open; then
    local header=$1 args=( "${@:2}" ) file=$(ds:tmp 'ds_idx') piped=0
    cat /dev/stdin > $file
  else
    local file="$1" header=$2 args=( "${@:3}" )
  fi
  local program="$([ $header ] && echo '{ print NR-1 FS $0 }' || echo '{ print NR FS $0 }')"
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" ${args[@]} "$program" "$file" 2> /dev/null
  else # TODO: Replace with consistent fs logic
    awk ${args[@]} "$program" "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:reo() { # ** Reorder/repeat/slice rows/cols: ds:reo [file] [rows] [cols] [dequote=true] [awkargs] -- or run [-h|--help]
  if ds:pipe_open; then
    local rows="${1:-a}" cols="${2:-a}" base=3
    local file=$(ds:tmp "ds_reo") piped=0
    cat /dev/stdin > $file
  else
    ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/reorder.awk" \
      | tr -d "#" | less && return
    local tmp=$(ds:tmp "ds_reo")
    ds:file_check "$1" t > $tmp
    local file="$(cat $tmp; rm $tmp)" rows="${2:-a}" cols="${3:-a}" base=4
  fi
  local arr_base=$(ds:arr_base)
  local args=( "${@:$base}" )
  if ds:test "(f|false)" "${args[$arr_base]}"; then
    local dq_off="${args[$arr_base]}" args=( "${args[@]:1}" ); fi
  [ ! "$dq_off" ] && local dequote=$(ds:tmp "ds_reo_dequote")
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
  else
    local fs_idx="$(ds:arr_idx '^FS=' ${args[@]})"
    if [ "$fs_idx" = "" ]; then
      local fs_idx="$(ds:arr_idx '^-F' ${args[@]})"
      local fs="$(echo "${args[$fs_idx]}" | tr -d '\-F')"
    else
      local fs="$(echo "${args[$fs_idx]}" | tr -d 'FS=')"
      let local fsv_idx=$fs_idx-1
      unset "args[$fsv_idx]"
    fi
    unset "args[$fs_idx]"
  fi
  if [ ! "$dq_off" ]; then
    ds:prefield "$file" "$fs" 1 > $dequote
    awk -v FS="$DS_SEP" -v OFS="$fs" -v r="$rows" -v c="$cols" ${args[@]} \
      -f "$DS_SCRIPT/reorder.awk" $dequote 2>/dev/null | ds:ttyf "$fs"
  else
    awk -v FS="$fs" -v OFS="$fs" -v r="$rows" -v c="$cols" ${args[@]} \
      -f "$DS_SCRIPT/reorder.awk" "$file" 2>/dev/null | ds:ttyf "$fs"
  fi
  ds:pipe_clean $file; [ ! "$dq_off" ] && rm $dequote; :
}

ds:decap() { # ** Remove up to a certain number of lines from the start of a file, default is 1
  let n_lines=1+${1:-1}
  if ds:pipe_open; then
    local file=/tmp/ds_decap piped=0
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
    local file=$(ds:tmp 'ds_transpose') piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    local args=( ${args[@]/"$file"} )
  fi
  local dequote=$(ds:tmp "ds_transpose_dequote")
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
  else
    local fs_idx="$(ds:arr_idx '^FS=' ${args[@]})"
    if [ "$fs_idx" = "" ]; then
      local fs_idx="$(ds:arr_idx '^-F' ${args[@]})"
      local fs="$(echo "${args[$fs_idx]}" | tr -d '\-F')"
    else
      local fs="$(echo "${args[$fs_idx]}" | tr -d 'FS=')"
      let local fsv_idx=$fs_idx-1
      unset "args[$fsv_idx]"
    fi
    unset "args[$fs_idx]"
  fi
  ds:prefield "$file" "$fs" 1 > $dequote
  awk -v FS="$DS_SEP" -v OFS="$fs" -v VAR_OFS=1 -f "$DS_SCRIPT/transpose.awk" \
    ${args[@]} $dequote 2> /dev/null | ds:ttyf "$fs"
  ds:pipe_clean $file; rm $dequote
}
alias ds:t="ds:transpose"

ds:pow() { # ** Print the power set frequency distribution of fielded text data: ds:pow [file] [min] [return_fields=f] [invert=f]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_pow') piped=0
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift
  fi
  ds:is_int "$1" && local min=$1 && shift
  ds:test "^(t|true)$" "$1" && local flds=1 && shift
  ds:test "^(t|true)$" "$1" && local inv=1 && shift
  local args=( "$@" )
  local dequote=$(ds:tmp "ds_pow_dequote") # TODO: Wrap this logic in prefield and return filename
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
  else
    local fs_idx="$(ds:arr_idx '^FS=' ${args[@]})" # TODO: Wrap this logic in noawkfs and return fs
    if [ "$fs_idx" = "" ]; then
      local fs_idx="$(ds:arr_idx '^-F' ${args[@]})"
      local fs="$(echo "${args[$fs_idx]}" | tr -d '\-F')"
    else
      local fs="$(echo "${args[$fs_idx]}" | tr -d 'FS=')"
      let local fsv_idx=$fs_idx-1
      unset "args[$fsv_idx]"
    fi
    unset "args[$fs_idx]"
  fi
  ds:prefield "$file" "$fs" 1 > $dequote
  awk -v FS="$DS_SEP" -v min=$min -v c_counts=$flds -v invert=$inv ${args[@]} \
    -f "$DS_SCRIPT/power.awk" $dequote 2>/dev/null | sort -n
  ds:pipe_clean $file; rm $dequote
}

ds:fieldcounts() { # ** Print value counts: ds:fieldcounts [file] [fields=1] [min=1] [order=a] [awkargs] (alias ds:fc)
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_fieldcounts') piped=0 
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift
  fi
  local fields="${1:-a}" min="$2"; [ "$1" ] && shift; [ "$min" ] && shift
  ([ "$min" ] && test "$min" -gt 0 2> /dev/null) || local min=1
  let min=$min-1
  if [ "$1" ]; then
    ([ "$1" = d ] || [ "$1" = desc ]) && local order="r"
    [[ ! "$1" =~ "-" ]] && shift; fi
  [ "$order" ] && shift; local args=( "$@" )
  if [ ! "$fields" = "a" ]; then
    if ds:noawkfs; then local fs="$(ds:inferfs "$file" true)"
    else
      local fs_idx="$(ds:arr_idx '^FS=' ${args[@]})"
      if [ "$fs_idx" = "" ]; then
        local fs_idx="$(ds:arr_idx '^\-F' ${args[@]})"
        local fs="$(echo ${args[$fs_idx]} | tr -d '\-F')"
      else
        local fs="$(echo ${args[$fs_idx]} | tr -d 'FS=')"
        let local fsv_idx=$fs_idx-1
        unset "args[$fsv_idx]"
      fi
      unset "args[$fs_idx]"
    fi
    local dequote=$(ds:tmp "ds_fc_dequote")
    ds:prefield "$file" "$fs" > $dequote
    ds:test "\[.+\]" "$fs" && fs=" " 
    awk ${args[@]} -v FS="$DS_SEP" -v OFS="$fs" -v min="$min" -v fields="$fields" \
      -f "$DS_SCRIPT/field_counts.awk" $dequote 2>/dev/null | sort -n$order | ds:ttyf "$fs"
  else
    awk ${args[@]}-v min="$min" -v fields="$fields" \
      -f "$DS_SCRIPT/field_counts.awk" "$file" 2>/dev/null | sort -n$order | ds:ttyf "$fs"
  fi
  ds:pipe_clean $file; [ "$dequote" ] && rm $dequote; :
}
alias ds:fc="ds:fieldcounts"

ds:newfs() { # ** Outputs a file with an updated field separator: ds:newfs [file] [newfs=,] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_newfs') piped=0
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift
  fi
  [ "$1" ] && local newfs="$1" && shift
  local args=( "$@" ) newfs="${newfs:-,}" dequote=$(ds:tmp "ds_newfs_dequote")
  local program='{for(i=1;i<NF;i++){printf "%s", $i OFS} print $NF}'
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
  else
    local fs_idx="$(ds:arr_idx '^FS=' ${args[@]})"
    if [ "$fs_idx" = "" ]; then
      local fs_idx="$(ds:arr_idx '^\-F' ${args[@]})"
      local fs="$(echo ${args[$fs_idx]} | tr -d '\-F')"
    else
      local fs="$(echo ${args[$fs_idx]} | tr -d 'FS=')"
      let local fsv_idx=$fs_idx-1
      unset "args[$fsv_idx]"
    fi
    unset "args[$fs_idx]"
  fi
  ds:prefield "$file" "$fs" > $dequote
  awk -v FS="$DS_SEP" -v OFS="$newfs" ${args[@]} "$program" $dequote 2> /dev/null
  ds:pipe_clean $file; rm $dequote
}

ds:hist() { # ** Print histograms for numerical fields in a data file: ds:hist [file] [n_bins] [bar_len] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_hist') piped=0
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift
  fi
  ds:is_int "$1" && local n_bins="$1" && shift
  ds:is_int "$1" && local bar_len="$1" && shift
  local args=( "$@" ) dequote=$(ds:tmp "ds_tmp_dequote")
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
  else
    local fs_idx="$(ds:arr_idx '^FS=' ${args[@]})"
    if [ "$fs_idx" = "" ]; then
      local fs_idx="$(ds:arr_idx '^\-F' ${args[@]})"
      local fs="$(echo ${args[$fs_idx]} | tr -d '\-F')"
    else
      local fs="$(echo ${args[$fs_idx]} | tr -d 'FS=')"
      let local fsv_idx=$fs_idx-1
      unset "args[$fsv_idx]"
    fi
    unset "args[$fs_idx]"
  fi
  ds:prefield "$file" "$fs" > $dequote
  awk -v FS="$DS_SEP" -v OFS="$fs" -v n_bins=$n_bins -v max_bar_leb=$bar_len \
    ${args[@]} -f "$DS_SCRIPT/hist.awk" $dequote 2> /dev/null
  ds:pipe_clean $file; rm $dequote

}

ds:asgn() { # Get lines matching standard assignment pattern from a file: ds:asgn file
  ds:file_check "$1"
  if ds:nset 'rg'; then
    rg "[[:alnum:]_]+ *=[^=<>]" $1 
  else
    egrep -n --color=always -e "[[:alnum:]_]+ *=[^=<>]" $1
  fi
  if [ ! $? ]; then echo 'No assignments found in file!'; fi
}

ds:enti() { # Print text entities from a file separated by a common pattern: ds:enti [file] [sep= ] [min=1] [order=a]
  if ds:pipe_open; then
    local file=/tmp/newfs piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift
  fi
  local sep="${1:- }" min="${2:-1}"
  ([ "$3" = d ] || [ "$3" = desc ]) && local order="r"
  ([ "$min" ] && test "$min" -gt 0 2> /dev/null) || min=1
  let min=$min-1
  local program="$DS_SCRIPT/separated_entities.awk"
  LC_All='C' awk -v sep="$sep" -v min=$min -f $program "$file" 2> /dev/null | LC_ALL='C' sort -n$order
}

ds:sbsp() { # ** Extend fields to include a common subseparator: ds:sbsp file subsep_pattern [nomatch_handler=space] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_sbsp') piped=0
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift
  fi
  [ $1 ] && local ssp=(-v subsep_pattern="$1")
  [ $2 ] && local nmh=(-v nomatch_handler="$2")
  local args=("${@:3}")
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file")"
    local fsargs=(-v FS="$fs" -v OFS="$fs"); fi
  awk ${fsargs[@]} ${ssp[@]} ${nmh[@]} ${args[@]} -f "$DS_SCRIPT/subseparator.awk" \
    "$file" "$file" 2> /dev/null
  ds:pipe_clean $file
}

ds:mactounix() { # Converts ^M return characters into simple carriage returns in place
  ds:file_check "$1"
  local inputfile="$1" tmpfile=$(ds:tmp 'ds_mactounix')
  cat "$inputfile" > $tmpfile
  tr "\015" "\n" < $tmpfile > "$inputfile"
  rm $tmpfile
}

ds:mini() { # ** Crude minify, remove whitespace including newlines except space: ds:mini [file] [newline_sep=;]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_mini') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift
  fi
  local program='{gsub("(\n\r)+" ,"'"${1:-;}"'");gsub("\n+" ,"'"${1:-;}"'");gsub("\t+" ,"'"${1:-;}"'");gsub("[[:space:]]{2,}"," ");print}'
  awk -v RS="\0" "$program" "$file" 2> /dev/null | awk -v RS="\0" "$program" 2> /dev/null
  ds:pipe_clean $file
}

ds:sort() { # ** Sort with an inferred field separator of exactly 1 char: ds:sort [unixsortargs] [file]
  local args=( "$@" )
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_sort') piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    args=( ${args[@]/"$file"} )
  fi
  local fs="$(ds:inferfs $file f true f f)"
  sort ${args[@]} --field-separator "$fs" "$file"
  ds:pipe_clean $file
}

ds:sortm() { # ** Sort with an inferred field separator of 1 or more character (alias ds:s): ds:sortm [keys] [order=a|d] [awkargs] [file]
  # TODO: Default to infer header
  grep -Eq "^[0-9\\.:;\\!\\?,]+$" <(echo "$1") && local keys="$1" && shift
  [ "$keys" ] && grep -Eq "^[A-z]$" <(echo "$1") && local ord="$1" && shift
  local args=( "$@" )
  [ "$keys" ] && local args=("${args[@]}" -v k="$keys")
  [ "$ord" ] && local args=("${args[@]}" -v order="$ord")
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_sortm') piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    args=( ${args[@]/"$file"} )
  fi
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" f true f f)"
    awk -v FS="$fs" -f "$DS_SCRIPT/fields_qsort.awk" ${args[@]} "$file" 2> /dev/null
  else #TODO: Replace with consistent fs logic
    awk -f "$DS_SCRIPT/fields_qsort.awk" ${args[@]} "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}
alias ds:s="ds:sortm"

ds:srg() { # Scope rg/grep to a set of files that contain a match: ds:srg scope_pattern search_pattern [dir] [invert=]
  ([ "$1" ] && [ "$2" ]) || ds:fail 'Missing scope and/or search pattern args'
  local scope="$1" search="$2"
  [ -d "$3" ] && local basedir="$3" || local basedir="$PWD"
  [ "$4" ] && [ "$4" != 'f' ] && [ "$4" != 'false' ] && local invert="--files-without-match"
  if ds:nset 'rg'; then
    echo -e "\nrg "${invert}" \""${search}"\" scoped to files matching \"${scope}\" in ${basedir}\n"
    rg -u -u -0 --files-with-matches -e "$scope" "$basedir" 2> /dev/null \
      | xargs -0 -I % rg -H $invert "$search" "%" 2> /dev/null
  else
    [ $invert ] && local invert="${invert}es"
    echo -e "\ngrep "${invert}" \""${search}"\" scoped to files matching \"${scope}\" in ${basedir}\n"
    grep -r --null --files-with-matches -e "$scope" "$basedir" 2> /dev/null \
      | xargs -0 -I % grep -H --color $invert "$search" "%" 2> /dev/null
  fi
  :
}

ds:recent() { # ls files modified last 7 days: ds:recent [custom_dir] [recurse=r] [hidden=h]
  if [ "$1" ]; then
    local dirname="$(readlink -e "$1")"
    [ ! -d "$dirname" ] && echo Unable to verify directory provided! && return 1
  fi
  
  local dirname="${dirname:-$PWD}" recurse="$2" hidden="$3" datefilter
  ds:nset 'fd' && local FD=1
  [ "$recurse" ] && ([ "$recurse" = 'r' ] || [ "$recurse" = 'true' ]) || unset recurse
  # TODO: Rework this obscene logic with opts flags

  if [ "$hidden" ]; then
    [ $FD ] && [ "$recurse" ] && local hidden=-HI #fd hides by default
    [ -z "$recurse" ] && local hidden='A'
    local notfound="No files found modified in the last 7 days!"
  else
    [ $FD ] && [ "$recurse" ] && local hidden="-not -path '*/\.*'" # find includes all by default
    local notfound="No non-hidden files found modified in the last 7 days!"
  fi
  
  if [ "$recurse" ]; then
    local ls_exec=(-exec ls -ghG --time-style=+%D \{\})
    (
      if [ $FD ]; then
        fd -t f --changed-within=1week $hidden -E 'Library/' \
          -${ls_exec[@]} 2> /dev/null \; ".*" "$dirname"
      else
        find "$dirname" -type f -maxdepth 6 $hidden -not -path ~"/Library" \
          -mtime -7d ${ls_exec[@]} 2> /dev/null
      fi
    ) | sed "s:$(printf '%q' "$dirname")\/::" | sort -k4 \
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
  [ $? = 0 ] || (echo "$notfound" && return 1)
}

ds:sedi() { # Linux-portable sed in place substitution: ds:sedi file search_pattern [replacement]
  [ "$1" ] && [ "$2" ] || ds:fail 'Missing required args: ds:sedi file search [replace]'
  [ ! -f "$1" ] && echo File was not provided or is invalid! && return 1
  local file="$1" search="$(printf "%q" "$2")"
  [ "$3" ] && local replace="$(printf "%q" "$3")"
  perl -pi -e "s/${search}/${replace}/g" "$file"
  # TODO: Fix for forward slash replacement case
}

ds:dff() { # Diff shortcut for more relevant changes: ds:dff file1 file2 [suppress_common]
  local tty_size=$(tput cols)
  let local tty_half=$tty_size/2
  [ "$3" ] && local sup=--suppress-common-lines && set -- "${@:1:2}"
  diff -b -y -W $tty_size $sup ${@} | expand | awk -v tty_half=$tty_half \
    -f "$DS_SCRIPT/diff_color.awk" | less
}

ds:gwdf() { # Git word diff shortcut
  local args=( "$@" )
  git diff --word-diff-regex="[A-Za-z0-9. ]|[^[:space:]]" --word-diff=color ${args[@]}
}

ds:goog() { # Executes Google search with args provided
  local search_args="$@"
  [ -z "$search_args" ] && ds:fail 'Arg required for search'
  local base_url="https://www.google.com/search?query="
  local search_query=$(echo $search_args | sed -e "s/ /+/g")
  local OS="$(ds:os)" search_url="${base_url}${search_query}"
  [ "$OS" = "Linux" ] && xdg-open "$search_url" && return
  open "$search_url"
}

ds:so() { # Executes Stack Overflow search with args provided
  local search_args="$@"
  [ -z "$search_args" ] && ds:fail 'Arg required for search'
  local base_url="https://www.stackoverflow.com/search?q="
  local search_query=$(echo $search_args | sed -e "s/ /+/g")
  local OS="$(ds:os)" search_url="${base_url}${search_query}"
  [ "$OS" = "Linux" ] && xdg-open "$search_url" && return
  open "$search_url"
}

ds:jira() { # Opens Jira at specified workspace and issue: ds:jira workspace_subdomain [issue]
  [ -z "$1" ] && ds:help ds:jira && ds:fail 'Subdomain arg missing'
  local OS="$(ds:os)" j_url="https://$1.atlassian.net"
  ds:test "[A-Z]+-[0-9]+" "$2" && local j_url="$j_url/browse/$2"
  [ "$OS" = "Linux" ] && xdg-open "$j_url" && return
  open "$j_url"
}

ds:unicode() { # ** Get the UTF-8 unicode for a character sequence: ds:unicode [str]
  ! ds:nset 'xxd' && ds:fail 'utility xxd required for this command'
  local sq=($(ds:pipe_open && grep -ho . || echo "$1" | grep -ho .))
  prg='{ if($3){ b[1]=substr($2,5,4);b[2]=substr($3,3,6)
                 b[3]=substr($4,3,6);b[4]=substr($5,3,6) }
          else { b[1]=substr($2,2,7) }
          for(i=1;i<=length(b);i++){d=d b[i]}
          print "obase=16; ibase=2; " d }'
  for i in ${sq[@]}; do
    local code="$(printf "$i" | xxd -b | awk -F"[[:space:]]" "$prg" | bc)"
    printf "\\\U$code"
  done; echo
}

ds:webpage_title() { # Downloads html from a webpage and extracts the title text
  local location="$1" tr_file="$DS_SUPPORT/named_entities_escaped.sed"
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
  bash "$DS_SCRIPT/dup_files.sh" -s "$dir" $use_fd $use_pv
}

ds:deps() { # Identify the dependencies of a shell function: ds:deps name [filter] [ntype_filter] [calling_func] [data]
  [ "$1" ] || (ds:help ds:deps && return 1)
  local tmp=$(ds:tmp 'ds_deps') srch="$2"
  [ "$3" ] && local scope="$3" || local scope="(FUNC|ALIAS)"
  [ "$4" ] && local cf="$1"
  if [ -f "$5" ]; then local ndt="$5"
  else
    local ndt=$(ds:tmp 'ds_ndata') rm_dt=0
    ds:ndata | awk "\$1~\"$scope\"{print \$2}" | sort > $ndt
  fi
  if [ $(which "ds:help" | wc -l) -gt 1  ]; then
    which "$1" | ds:decap > $tmp
  else
    ds:fsrc "$1" | ds:decap 2 > $tmp
  fi
  awk -v search="$srch" -v calling_func="$cf" -f "$DS_SCRIPT/shell_deps.awk" $tmp $ndt
  rm $tmp; [ "$rm_dt" ] && rm $ndt
}

ds:gexec() { # Generate a script from pieces of another script and run it: ds:gexec run=false srcfile scriptdir reo_match_patterns [clean] [verbose]
  [ "$1" ] && local run="$1" && shift || (ds:help ds:gexec && return 1)
  ds:file_check "$1"
  [ -d "$2" ] || ds:fail 'second arg must be a directory'
  [ "$3" ] || ds:fail 'missing required match patterns'
  local src="$1" scriptdir="$2" r_args="$3" clean="$4"
  [ "$5" ] && local run_verbose=-x
  read -r dirpath filename extension <<<$(ds:path_elements "$src")
  local gscript="$scriptdir/ds_gexec_from_$filename$extension"

  ds:reo $src "$r_args" a false -v FS="$DS_SEP" > "$gscript"
  echo -e "\n\033[0;33mNew file: $gscript\033[0m\n"
  chmod 777 "$gscript"; cat "$gscript"

  [ "$run" = "true" ] && echo && local conf=$(ds:readp 'Confirm script run (y/n):' | ds:downcase)
  if [ "$conf" = y ]; then
    echo -e "\n\033[0;33mRunning file $gscript\033[0m\n"
    bash $run_verbose "$gscript"; local stts="$?"
  else
    echo -e "\n\033[0;33mScript not executed!\033[0m"
  fi

  [ $clean ] && rm "$gscript" && echo -e "\n\033[0;33mRemoved file $gscript\033[0m"
  if [ "$stts" ]; then return "$stts"; fi
}

