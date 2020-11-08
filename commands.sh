#!/bin/bash

[ ! "$DS_LOC" ] && DS_LOC="$HOME/dev_scripts"
DS_SCRIPT="$DS_LOC/scripts"
DS_SUPPORT="$DS_LOC/support"
source "$DS_SUPPORT/utils.sh"

ds:commands() { # List commands from dev_scripts/commands.sh: ds:commands [bufferchar] [utils]
  [ "$2" ] && local utils="$DS_SUPPORT/utils.sh"
  echo
  grep -h '[[:alnum:]_]*()' "$DS_LOC/commands.sh" "$utils" 2>/dev/null | grep -hv 'grep -h' | sort \
    | awk -F "\\\(\\\) { #" '{printf "%-18s\t%s\n", $1, $2}' \
    | ds:sbsp '\\\*\\\*' "$DS_SEP" -v retain_pattern=1 -v apply_to_fields=2 -v FS="[[:space:]]{2,}" -v OFS="$DS_SEP" \
    | ds:sbsp ":[[:space:]]" "888" -v apply_to_fields=3 -v FS="$DS_SEP" -v OFS="$DS_SEP" \
    | ds:sbsp '\\\(alias ' '$' -v apply_to_fields=3 | sed 's/)@/@/' \
    | awk -v FS="$DS_SEP" 'BEGIN{print "COMMAND" FS FS "DESCRIPTION" FS "ALIAS" FS "USAGE\n"}
      {print} END{print "\nCOMMAND" FS FS "DESCRIPTION" FS "ALIAS" FS "USAGE"}' \
    | ds:reo a 2,1,4,3,5 \
    | ds:ttyf "$DS_SEP" t -v bufferchar="${1:- }"
  echo
  echo "** - function supports receiving piped data"
  echo
}

ds:help() { # Print help for a given command: ds:help ds_command
  (ds:nset "$1" && [[ "$1" =~ "ds:" ]]) || ds:fail 'Command not found - to see all commands, run ds:commands'
  [[ "$1" =~ 'reo' ]] && ds:reo -h && return
  [[ "$1" =~ 'fit' ]] && ds:fit -h && return
  [[ "$1" =~ 'jn' ]] && ds:jn -h && return
  [[ "$1" =~ 'stag' ]] && ds:stag -h && return
  ds:commands "" t | ds:reo "2,~$1" a
}

ds:vi() { # Search for file and open it in vim: ds:vi search [dir]
  [ ! "$1" ] && echo 'Filename search pattern missing!' && ds:help ds:vi && return 1
  local search="${1}" dir="${2:-.}"
  if fd --version &>/dev/null; then
    local fl="$(fd -t f "$search" "$dir" | head -n1)"
  elif fd-find --version &>/dev/null; then
    local fl="$(fd-find -t f "$search" "$dir" | head -n1)"
  else
    local fl="$(find "$dir" -type f -name "*$search*" -maxdepth 10 | head -n1)"; fi
  vi "$fl"
}

ds:gvi() { # Grep and open vim on the first match: ds:gvi search [file|dir]
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
          "$search" ${basedir_f[@]} "$dir" > $tmp; fi
      local file=$(ds:reo $tmp "$filesearch" 1 -F: -v q=1 | head -n1)
      local line=$(ds:reo $tmp "$filesearch" 2 -F: -v q=1 | head -n1)
    else
      local basedir_f=($(find "$dir" -maxdepth 0 -type f | grep -v ":"))
      if ds:nset 'rg'; then
        rg -Hno --no-heading --hidden --color=never -g '!*:*' -g '!.git' \
          "$search" ${basedir_f[@]} "$dir" | head -n1 > $tmp
      else
        grep -HInors --color=never --exclude ':' --excludedir '.git' \
          "$search" ${basedir_f[@]} "$dir" | head -n1 > $tmp; fi
      local file=$(ds:reo $tmp 1 1 -F: -v q=1) line=$(ds:reo $tmp 1 2 -F: -v q=1)
    fi
    rm $tmp
    [ -f "$file" ] || ds:fail 'No match found'; fi
  ds:is_int $line || ds:fail 'No match found'
  vi +$line "$file" || return 1
}

ds:searchn() { # Searches current names for string, returns matches: ds:searchn name
  ds:ndata | awk -v s="$1" '$0~s{print}'
}

ds:nset() { # Test if name (function, alias, variable) is defined: ds:nset name [search_vars=f]
  [ "$2" ] && ds:ntype "$1" &> /dev/null || type "$1" &> /dev/null
}

ds:ntype() { # Get name type - function, alias, variable: ds:ntype name
  awk -v name="$1" -v q=\' '
    BEGIN { e=1; quoted_name = ( q name q ) }
    $2==name || $2==quoted_name { print $1; e=0 }
    END { exit e }
    ' <(ds:ndata) 2> /dev/null
}

ds:new() { # Refresh zsh or bash interactive session: ds:new
  # TODO: Clear persistent envars
  local s = "$(ds:sh)"
  clear
  if [[ "$s" =~ zsh ]]; then
    exec zsh
  elif [[ "$s" =~ bash ]]; then
    exec bash; fi
}

ds:cp() { # ** Copy standard input in UTF-8: data | ds:cp
  # TODO: Other copy utilities to handle case when pbcopy is not installed
  LC_CTYPE=UTF-8 pbcopy
}

ds:tmp() { # Shortcut for quiet mktemp: ds:tmp filename
  mktemp -q "/tmp/${1}.XXXXX"
}

ds:fail() { # Safe failure, kills parent but returns to prompt: ds:fail [error_message]
  bash "$DS_SUPPORT/clean.sh"
  local shell="$(ds:sh)"
  if [[ "$shell" =~ "bash" ]]; then
    : "${_err_?$1}"
  else
    echo -e "\e[31;1m$1"
    : "${_err_?Operation intentionally failed by fail command}"; fi
}

ds:pipe_check() { # ** Detect if pipe has data or over [n_lines]: data | ds:pipe_check [n_lines]
  local chkfile=$(ds:tmp 'ds_pipe_check')
  tee > $chkfile
  if [[ -z "$1" || $(! ds:is_int "$1") ]]; then
    test -s $chkfile
  else
    [ $(cat $chkfile | wc -l) -gt $1 ]; fi
  local has_data=$?; cat $chkfile; rm $chkfile; return $has_data
}

ds:rev() { # ** Reverse lines from standard input: data | ds:rev
  local line
  if IFS= read -r line; then
    ds:rev
    printf '%s\n' "$line"; fi
}

ds:dup_input() { # ** Duplicate standard input in aggregate: data | ds:dup_input
  local file=$(ds:tmp 'ds_dup_input')
  tee $file && cat $file && rm $file
}

ds:join_by() { # ** Join a shell array by given delimiter: ds:join_by delimiter [join_array]
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
    local args=( "$@" ); fi

  echo -n "$first"; printf "%s" "${args[@]/#/$d}"
}

ds:test() { # ** Test input quietly with extended regex: ds:test regex [str|file] [test_file=f]
  ds:pipe_open && grep -Eq "$1" && return $?
  [[ "$3" =~ t ]] && [ -f "$2" ] && grep -Eq "$1" "$2" && return $?
  echo "$2" | grep -Eq "$1"
}

ds:substr() { # ** Extract a substring from a string with regex: ds:substr str [leftanc] [rightanc]
  if ds:pipe_open; then
    local str="$(cat /dev/stdin)"
  else
    local str="$1"; shift; fi
  [ -z "$str" ] && ds:fail 'Empty string detected - a string required for substring extraction'
  local leftanc="$1" rightanc="$2"
  if [ "$rightanc" ]; then
    [ -z "$leftanc" ] && local sedstr="s/$rightanc//" || local sedstr="s/$leftanc//;s/$rightanc//"
    local out="$(grep -Eho "$leftanc.*?[^\\]$rightanc" <<< "$str" | sed -E $sedstr)"
  elif [ "$leftanc" ]; then
    local sedstr="s/$leftanc//"
    local out="$(grep -Eho "$leftanc.*?[^\\]" <<< "$str" | sed -E $sedstr)"
  else
    out="$str"; fi
  [ "$out" ] && printf "$out" || echo 'No string match to extract'
}

ds:iter() { # Repeat a string some number of times: ds:iter str [n=1] [fs]
  local str="$1" fs="${3:- }" out="$1"
  let n_repeats=${2:-1}-1
  for ((i=1;i<=$n_repeats;i++)); do local out="${out}${fs}${str}"; done
  echo -n "$out"
}

ds:embrace() { # Enclose a string on each side by args: embrace str [left={] [right=}]
  local val="$1"
  [ -z "$2" ] && local l="{" || local l="$2"
  [ -z "$3" ] && local r="}" || local r="$3"
  echo -n "${l}${val}${r}"
}

ds:filename_str() { # Add string to beginning or end of a filename: ds:filename_str file str [prepend|append]
  read -r dirpath filename extension <<<$(ds:path_elements "$1")
  [ ! -d "$dirpath" ] && echo 'Filepath given is invalid' && return 1
  local add="$2" position=${3:-append}
  case $position in
    append)  filename="${filename}${add}${extension}" ;;
    prepend) filename="${add}${filename}${extension}" ;;
    *)       ds:help 'ds:filename_str'; return 1      ;; esac
  printf "${dirpath}${filename}"
}

ds:path_elements() { # Returns dirname, filename, extension from a filepath: ds:path_elements file
  ds:file_check "$1"
  local filepath="$1" dirpath=$(dirname "$1") filename=$(basename "$1")
  local extension=$([[ "$filename" = *.* ]] && echo ".${filename##*.}" || echo '')
  local filename="${filename%.*}"
  local out=( "$dirpath/" "$filename" "$extension" )
  printf '%s\t' "${out[@]}"
}

ds:src() { # Source a piece of file: ds:src file ["searchx" pattern] || [line endline] || [pattern linesafter]
  local tmp=$(ds:tmp 'ds_src')
  ds:file_check "$1"; local file="$1"
  if [ "$2" = "searchx" ]; then
    [ "$3" ] && ds:searchx "$file" "$3" > $tmp
    if ds:is_cli; then
      cat $tmp
      echo
      confirm="$(ds:readp 'Confirm source action: (y/n)')"
      [ "$confirm" != "y" ] && rm $tmp && echo 'External code not sourced' && return
    fi
    source $tmp; rm $tmp
    [ "$confirm" ] && echo -e "Selection confirmed - new code sourced"
    return; fi
  if ds:is_int "$2"; then
    local line=$2 
    if ds:is_int "$3"; then
      local endline=$3
      ds:reo "$file" "$line..$endline" > $tmp
    else
      ds:reo "$file" "$line" > $tmp; fi
    source $tmp; rm $tmp
  elif [ "$2" ]; then
    ds:is_int "$3" && local linesafter=(-A $3)
    source <(cat "$file" | grep "$pattern" ${linesafter[@]})
  else
    source "$file"; fi
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
      which "$1"; rm $tmp; return $?; fi
    local file=$(awk '{for(i=1;i<=NF;i++)if(i>2)printf "%s",$i}' $tmp \
      2> /dev/null | head -n1)
    awk -v f="$file" '{ print f ":" $2 }' $tmp
  elif [[ $shell =~ zsh ]]; then
    grep '> source' <(zsh -xc "declare -F $1" 2>&1) \
      | awk '{ print substr($0, index($0, "> source ")+9) }' > $tmp
    local file="$(grep --files-with-match -En "$1 ?\(.*?\)" \
      $(cat $tmp) 2> /dev/null | head -n1)"
    if [ -z $file ]; then
      which "$1"; rm $tmp; return $?; fi
    echo "$file"; fi
  ds:searchx "$file" "$1" q
  rm $tmp
}

ds:trace() { # Search shell trace for a pattern: ds:trace [command] [search]
  if [ -z "$1" ]; then
    cmd="$(fc -ln -1)"
    [[ "\"$cmd\"" =~ 'ds:trace' ]] && return 1
    ds:readp 'Press enter to trace last command'
  else
    cmd="$1"; fi
  grep --color=always "$2" <(set -x &> /dev/null; eval "$cmd" 2>&1)
}

ds:git_cross_view() { # Display table of git repos vs branches (alias ds:gcv): ds:gcv [:ab:Dfhmo:sv]
  # TODO: Add man page -- set config in scripts/support/lbv.conf
  ds:nset 'fd' && local use_fd="-f"
  source "${DS_SUPPORT}/lbv.conf"
  [ "$LBV_DEPTH" ] && local maxdepth=(-D $LBV_DEPTH)
  [ "$LBV_SHOWSTATUS" ] && local showstatus=-s
  bash "$DS_SCRIPT/local_branch_view.sh" ${@} $use_fd $showstatus ${maxdepth[@]}
}
alias ds:gcv="ds:git_cross_view"

ds:git_purge_local() { # Purge branches from local git repos (alias ds:gpl): ds:gpl [repos_dir=~]
  bash "$DS_SCRIPT/purge_local_branches.sh" ${@}
}
alias ds:gpl="ds:git_purge_local"

ds:git_refresh() { # Pull latest for all repos, run installs (alias ds:grr): ds:gr [repos_dir=~]
  bash "$DS_SCRIPT/local_env_refresh.sh" ${@}
}
alias ds:grf="ds:git_refresh"

ds:git_checkout() { # Checkout branch matching pattern (alias ds:gco): ds:gco [pattern]
  bash "$DS_SCRIPT/git_checkout.sh" ${@}
}
alias ds:gco="ds:git_checkout"

ds:git_squash() { # Squash last n commits (alias ds:gsq): ds:gsq [n_commits=1]
  local extent="${1:-1}"
  ! ds:is_int "$extent" && echo 'Squash commits to arg must be an integer' && ds:help ds:git_squash && return 1
  local conf="$(ds:readp "Are you sure you want to squash the last $extent commits on current branch?

    The new commit messages will be:
      $(git log --format=%B --reverse HEAD..HEAD@{1})

    Please confirm (y/n) " | ds:downcase)"
  [ ! "$conf" = y ] && echo 'No change made' && return 1
  let local extent=$extent+1
  git reset --soft HEAD~$extent
  git commit --edit -m"$(git log --format=%B --reverse HEAD..HEAD@{1})"
}

ds:git_time_stat() { # Last local pull+change+commit times (alias ds:gts): cd repo; ds:gts
  ds:not_git && return 1
  local last_pull="$(stat -c %y "$(git rev-parse --show-toplevel)/.git/FETCH_HEAD" 2>/dev/null)"
  local last_change="$(stat -c %y "$(git rev-parse --show-toplevel)/.git/HEAD" 2>/dev/null)"
  local last_commit="$(git log -1 --format=%cd)"
  if [ "$last_pull" ]; then
    local last_pull="$(date --date="$last_pull" "+%a %b %d %T %Y %z")"
    printf "%-40s%-30s\n" "Time of last pull:" "${last_pull}"
  else
    echo "No pulls found"; fi
  if [ "$last_change" ]; then
    local last_change="$(date --date="$last_change" "+%a %b %d %T %Y %z")"
    printf "%-40s%-30s\n" "Time of last local change:" "${last_change}"
  else
    echo "No local changes found"; fi
  [ "$last_commit" ] && printf "%-40s%-30s\n" "Time of last commit found locally:" "${last_commit}" || echo "No local commit found"
}
alias ds:gts="ds:git_time_stat"

ds:git_status() { # Run git status for all repos (alias ds:gs): ds:gs
  bash "$DS_SCRIPT/all_repo_git_status.sh" ${@}
}
alias ds:gs="ds:git_status"

ds:git_branch() { # Run git branch for all repos (alias ds:gb): ds:gb
  bash "$DS_SCRIPT/all_repo_git_branch.sh" ${@}
}
alias ds:gb="ds:git_branch"

ds:git_add_com_push() { # Add, commit with message, push (alias ds:gacmp): ds:gacmp commit_message
  ds:not_git && return 1
  local commit_msg="$1"
  ds:git_add_all; ds:gcam "$commit_msg"; ds:git_push_cur
}
alias ds:gacmp="ds:git_add_com_push"

ds:git_recent() { # Display commits sorted by recency (alias ds:gr): ds:gr [refs=heads] [run_context=display]
  ds:not_git && return 1
  local refs="${1:-heads}" run_context="${2:-display}"
  if [ "$run_context" = display ]; then
    local format='%(color:white)%(HEAD) %(color:bold yellow)%(refname:short)@@@%(color:bold green)%(committerdate:relative)@@@%(color:blue)%(subject)@@@%(color:magenta)%(authorname)%(color:reset)'
    git for-each-ref --sort=-committerdate refs/"$refs" \
      --format="$format" --color=always | ds:fit -F"$DS_SEP"
  else
    # If not for immediate display, return extra field for further parsing
    local format='%(color:white)%(HEAD) %(color:bold yellow)%(refname:short)@@@%(committerdate:short)@@@%(color:bold green)%(committerdate:relative)@@@%(color:blue)%(subject)@@@%(color:magenta)%(authorname)%(color:reset)'
    git for-each-ref refs/$refs --format="$format" --color=always; fi
}
alias ds:gr="ds:git_recent"

ds:git_recent_all() { # Display recent commits for local repos (alias ds:gra): ds:gra [refs=heads] [repos_dir=~]
  local start_dir="$PWD" all_recent=$(ds:tmp 'ds_git_recent_all')
  local w="\033[37;1m" nc="\033[0m"
  local refs="$1"
  [ -d "$2" ] && cd "$2" || cd ~
  echo -e "${w}repo@@@   ${w}branch@@@sortfield@@@${w}commit time@@@${w}commit message@@@${w}author${nc}" > $all_recent
  while IFS=$'\n' read -r dir; do
    [ -d "${dir}/.git" ] && (cd "$dir" && \
      (ds:git_recent "$refs" parse | awk -v repo="$dir" -F"$DS_SEP" '
        {print "\033[1;31m" repo "@@@", $0}') >> $all_recent )
  done < <(find * -maxdepth 0 -type d)
  echo
  ds:sortm $all_recent -v order=d -F"$DS_SEP" -v k=3 \
    | ds:reo "a" "NF!=3" -F"$DS_SEP" -v OFS="$DS_SEP" | ds:ttyf
  local stts=$?
  echo
  rm $all_recent
  cd "$start_dir"
  return $stts
}
alias ds:gra="ds:git_recent_all"

ds:git_graph() { # Print colorful git history graph (alias ds:gg): ds:gg
  ds:not_git && return 1
  git log --all --decorate --oneline --graph
}
alias ds:gg="ds:git_graph"

ds:todo() { # List todo items found in paths: ds:todo [searchpaths=.]
  ds:nset 'rg' && local RG=true
  if [ -z "$1" ]; then
    [ "$RG" ] && rg -His 'TODO' || grep -irs 'TODO' --color=always .
    echo
  else
    local search_paths=( "${@}" )
    for search_path in ${search_paths[@]} ; do
      if [[ ! -d "$search_path" && ! -f "$search_path" ]]; then
        echo "$search_path is not a file or directory or is not found"
        local bad_dir=0; continue; fi
      [ "$RG" ] && rg -His 'TODO' "$search_path" \
        || grep -irs 'TODO' --color=always "$search_path"
      echo
    done; fi
  [ -z $bad_dir ] || (echo 'Some paths provided could not be searched' && return 1)
}

ds:searchx() { # Search file for C-lang/curly-brace top-level object: ds:searchx file|dir [search] [q]
  if [[ -d "$1" && "$2" ]]; then
    local tmp="$(ds:tmp 'ds_searchx')" w="\033[37;1m" nc="\033[0m"
    if ds:nset 'rg'; then
      rg --files-with-matches "$2" "$1" 2>/dev/null > $tmp
    else
      grep -Er --files-with-matches "$2" "$1" 2>/dev/null > $tmp; fi
    for fl in $(cat $tmp); do
      if [ -f "$fl" ] && grep -q '{' "$fl" 2>/dev/null; then
        echo -e "\n${w}${fl}${nc}"
        ds:searchx "$fl" "$2" "$3"; fi; done
    local stts=$?
    rm $tmp; return $stts
  fi
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
    local file="$1" start="$2" end="$3"; fi
  awk "/$start/,/$end/{print}" "$file"
  ds:pipe_clean $file
}

ds:insert() { # ** Redirect input into a file at lineno or pattern: ds:insert file [lineno|pattern] [srcfile]
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
      local confirm="$(ds:readp "$conftext")"
      [ "$confirm" != "y" ] && rm $source $tmp && echo 'Exit with no insertion' && return 1
    fi
  else
    rm $source $tmp; ds:fail 'Insertion point not provided or invalid'; fi
  if ds:pipe_open; then
    local piped=0; cat /dev/stdin > $source
  else
    if [ -f "$3" ]; then
      cat "$3" > $source
    elif [ "$3" ]; then
      echo "$3" > $source
    else
      rm $source $tmp; ds:fail 'Insertion source not provided'; fi; fi
  awk -v src="$src" -v lineno=$lineno -v pattern="$pattern" \
    -f "$DS_SCRIPT/insert.awk" "$sink" $source > $tmp
  cat $tmp > "$sink"
  rm $source $tmp
}

ds:shape() { # ** Print data shape by length or FS: ds:shape [file] [FS] [chart_size=15ln] [chart_off=f]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_shape') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi

  local lines=$(cat "$file" | wc -l | awk '{print $0+0}')
  [ $lines = 0 ] && return 1
  ds:is_int "$2" && local printlns=$2 || local printlns=15
  let local span=$lines/$printlns
  awk -v FS="${1:- }" -v span=${span:-15} -v tty_size="$(tput cols)" -v lines="$lines" \
    -v simple="${3:-0}" -f "$DS_SCRIPT/shape.awk" "$file" 2>/dev/null

  ds:pipe_clean $file
}

ds:jn() { # ** Join two files, or a file and STDIN, with any keyset: ds:jn file1 [file2] [jointype] [k|merge] [k2] [prefield=t] [awkargs]
  ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/join.awk" \
    | tr -d "#" | less && return
  ds:file_check "$1"
  local f1="$1"; shift
  if ds:pipe_open; then
    local f2=$(ds:tmp 'ds_jn') piped=0
    cat /dev/stdin > $f2
  else
    ds:file_check "$1"
    local f2="$1"; shift; fi

  # TODO: PREFIELD

  if [ "$1" ]; then
    [[ "$1" =~ '^d' ]] && local type='diff'
    [[ "$1" =~ '^i' ]] && local type='inner'
    [[ "$1" =~ '^l' ]] && local type='left'
    [[ "$1" =~ '^r' ]] && local type='right'
    [[ ! "$1" =~ '-' && ! "$1" =~ '^[0-9]+$' ]] && shift; fi

  local merge=$(ds:arr_idx 'm(erge)' ${@})
  local has_keyarg=$(ds:arr_idx 'k[12]?=' ${@})
  if [[ "$merge" = "" && "$has_keyarg" = "" ]]; then
    if ds:is_int "$1"; then
      local k="$1"; shift
      ds:is_int "$1" && local k1="$k" k2="$1" && shift
    elif [[ -z "$1" || "$1" =~ "-" ]]; then
      local k="$(ds:inferk "$f1" "$f2")"
      [[ "$k" =~ " " ]] && local k2="$(ds:substr "$k" " " "")" k1="$(ds:substr "$k" "" " ")"
    elif ds:test '^([0-9]+,)+[0-9]+$' "$1"; then
      local k="$1"; shift
      ds:test '^([0-9]+,)+[0-9]+$' "$1" && local k1="$k" k2="$1" && shift
    fi
    local args=( "$@" )
    [ "$k2" ] && local args=("${args[@]}" -v "k1=$k1" -v "k2=$k2") || local args=("${args[@]}" -v "k=$k")
  else local args=( "$@" ); fi
  [ "$merge" ] && unset "args[$merge]" && local args=("${args[@]}" -v 'merge=1')
  [ "$type" ] && local args=("${args[@]}" -v "join=$type")

  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"
    awk -v fs1="$fs1" -v fs2="$fs2" ${args[@]} -f "$DS_SCRIPT/join.awk" \
      "$f1" "$f2" 2> /dev/null | ds:ttyf "$fs1"
  else
    awk ${args[@]} -f "$DS_SCRIPT/join.awk" "$f1" "$f2" 2> /dev/mull | ds:ttyf
  fi

  ds:pipe_clean $f2
}

ds:print_matches() { # ** Get match lines in two datasets (alias ds:pm): ds:pm file [file] [awkargs]
  ds:file_check "$1"
  local f1="$1"; shift
  if ds:pipe_open; then
    local f2=$(ds:tmp 'ds_matches') piped=1
    cat /dev/stdin > "$f2"
  else
    ds:file_check "$1"
    local f2="$1"; shift; fi
  [ "$f1" = "$f2" ] && echo 'Files are the same!' && return
  local args=( "$@" )
  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"

    awk -v fs1="$fs1" -v fs2="$fs2" -v piped=$piped ${args[@]} \
      -f "$DS_SCRIPT/matches.awk" "$f1" "$f2" 2> /dev/null | ds:ttyf "$fs1"
  else
    awk -v piped=$piped ${args[@]} -f "$DS_SCRIPT/matches.awk" "$f1" "$f2" \
      2> /dev/null | ds:ttyf; fi
  
  ds:pipe_clean $f2
}
alias ds:pm="ds:print_matches"

ds:print_comps() { # ** Print non-matching lines on keys given (alias ds:pc): ds:pc file [file] [awkargs]
  ds:file_check "$1"
  local f1="$1"; shift
  if ds:pipe_open; then
    local f2=$(ds:tmp 'ds_comps') piped=1
    cat /dev/stdin > "$f2"
  else
    ds:file_check "$1"
    local f2="$1"; shift; fi
  [ "$f1" = "$f2" ] && echo 'Files are the same!' && return 1
  local args=( "$@" )
  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"

    awk -v fs1="$fs1" -v fs2="$fs2" -v piped=$piped ${args[@]} \
      -f "$DS_SCRIPT/complements.awk" "$f1" "$f2" 2> /dev/null | ds:ttyf "$fs1"
  else
    awk -v piped=$piped ${args[@]} -f "$DS_SCRIPT/complements.awk" "$f1" "$f2" \
      2> /dev/null | ds:ttyf; fi
  
  ds:pipe_clean $f2
}
alias ds:pc="ds:print_comps"

ds:inferh() { # Infer if headers present in a file: ds:inferh file [awkargs]
  ds:file_check "$1"
  local file="$1"; shift
  local args=( "$@" )
  awk ${args[@]} -f "$DS_SCRIPT/infer_headers.awk" "$file" 2> /dev/null
}

ds:inferk() { # ** Infer join fields in two text data files: ds:inferk file [file] [awkargs]
  ds:file_check "$1"
  local f1="$1"; shift
  if ds:pipe_open; then
    local f2=$(ds:tmp 'ds_inferk') piped=0
    cat /dev/stdin > $file2
  else
    ds:file_check "$1"
    local f2="$1"; shift; fi
  local args=( "$@" )
  if ds:noawkfs; then
    local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"

    awk -v fs1="$fs1" -v fs2="$fs2" ${args[@]} -f "$DS_SCRIPT/infer_join_fields.awk" \
      "$f1" "$f2" 2> /dev/null
  else
    awk ${args[@]} -f "$DS_SCRIPT/infer_join_fields.awk" "$f1" "$f2" 2> /dev/null; fi

  ds:pipe_clean $f2
}

ds:inferfs() { # Infer field separator from data: ds:inferfs file [reparse=f] [custom=t] [file_ext=t] [high_cert=f]
  ds:file_check "$1"
  local file="$1" reparse="${2:-false}" custom="${3:-true}" file_ext="${4:-true}" hc="${5:-false}"

  if [ "$file_ext" = true ]; then
    read -r dirpath filename extension <<<$(ds:path_elements "$file")
    if [ "$extension" ]; then
      [ ".csv" = "$extension" ] && echo ',' && return
      [ ".tsv" = "$extension" ] && echo "\t" && return; fi; fi

  ds:test 't(rue)?' "$custom" || custom=""
  ds:test 't(rue)?' "$hc" || hc=""

  if [ "$reparse" = true ]; then
    awk -f "$DS_SCRIPT/infer_field_separator.awk" -v high_certainty="$hc" \
      -v custom="$custom" "$file" 2> /dev/null | sed 's/\\/\\\\\\/g'
  else
    awk -f "$DS_SCRIPT/infer_field_separator.awk" -v high_certainty="$hc" \
      -v custom="$custom" "$file" 2> /dev/null; fi
}

ds:fit() { # ** Fit fielded data in columns with dynamic width: ds:fit [-h|file*] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_fit') piped=0 hc=f
    cat /dev/stdin > $file
  else
    ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/fit_columns.awk" \
      | tr -d "#" | less && return
    if [[ -f "$2" && -f "$1" ]]; then
      local w="\033[37;1m" nc="\033[0m"
      while [ -f "$1" ]; do
        local fls=("${fls[@]}" "$1"); shift; done
      for fl in ${fls[@]}; do
        echo -e "\n${w}${fl}${nc}"
        [ -f "$fl" ] && ds:fit "$fl" $@; done
      return $?
    else
      ds:file_check "$1"
      local file="$1" hc=true; shift; fi; fi
  local args=( "$@" ) buffer=${DS_FIT_BUFFER:-2} tty_size=$(tput cols)
  local prefield=$(ds:tmp "ds_fit_prefield")
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  ds:prefield "$file" "$fs" 0 > $prefield
  ds:awksafe && local args=( ${args[@]} -v awksafe=1 -f "$DS_SUPPORT/wcwidth.awk" )
  awk -v FS="$DS_SEP" -v OFS="$fs" -v tty_size=$tty_size -v buffer="$buffer" \
    ${args[@]} -f "$DS_SCRIPT/fit_columns.awk" $prefield{,} 2>/dev/null
  ds:pipe_clean $file; rm $prefield
}

ds:stag() { # ** Print field-separated data in staggered rows: ds:stag [file] [stag_size]
  ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/stagger.awk" \
    | tr -d "#" | less && return
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_stagger') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi
  ds:is_int "$1" && local stag_size=$1 && shift
  local args=( "$@" ) tty_size=$(tput cols)
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" ${args[@]} -v tty_size=$tty_size -v stag_size=$stag_size \
      -f "$DS_SCRIPT/stagger.awk" "$file" 2> /dev/null
  else
    awk ${args[@]} -v tty_size=$tty_size -v stag_size=$stag_size \
      -f "$DS_SCRIPT/stagger.awk" "$file" 2> /dev/null; fi
  ds:pipe_clean $file
}

ds:idx() { # ** Attach an index to lines from a file or STDIN: ds:idx [file] [startline=1]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_idx') piped=0
    cat /dev/stdin > $file
  else
    local file="$1"; shift; fi
  local args=( "${@:2}" )
  [ -t 1 ] || local pipe_out=1
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" true)"
    awk -v FS="$fs" ${args[@]} -v header="${1:-1}" -v pipeout="$pipe_out" \
      -f "$DS_SCRIPT/index.awk" "$file" 2> /dev/null
  else # TODO: Replace with consistent fs logic
    awk ${args[@]} -v header="${1:-1}" -v pipeout="$pipe_out" \
      -f "$DS_SCRIPT/index.awk" "$file" 2> /dev/null
  fi
  ds:pipe_clean $file
}

ds:reo() { # ** Reorder/repeat/slice data by rows and cols: ds:reo [-h|file] [rows] [cols] [prefield=t] [awkargs]
  if ds:pipe_open; then
    local rows="${1:-a}" cols="${2:-a}" base=3
    local file=$(ds:tmp "ds_reo") piped=0
    cat /dev/stdin > $file
  else
    ds:test "(^| )(-h|--help)" "$1" && grep -E "^#( |$)" "$DS_SCRIPT/reorder.awk" \
      | tr -d "#" | less && return
    if [[ -f "$2" && -f "$1" ]]; then
      local w="\033[37;1m" nc="\033[0m"
      while [ -f "$1" ]; do
        local fls=("${fls[@]}" "$1"); shift; done
      for fl in ${fls[@]}; do
        echo -e "\n${w}${fl}${nc}"
        [ -f "$fl" ] && ds:reo "$fl" $@; done
      return $?
    else
      local tmp=$(ds:tmp "ds_reo")
      ds:file_check "$1" t > $tmp
      local file="$(cat $tmp; rm $tmp)" rows="${2:-a}" cols="${3:-a}" base=4
    fi
  fi
  local arr_base=$(ds:arr_base)
  local args=( "${@:$base}" )
  if [ "$cols" = 'off' ] || $(ds:test "(f|false)" "${args[$arr_base]}"); then
    local pf_off=0 args=( "${args[@]:1}" )
    [ "$cols" = 'off' ] && run_fit='f'
  else local prefield=$(ds:tmp "ds_reo_prefield"); fi
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  if [ "$pf_off" ]; then
    awk -v FS="$fs" -v OFS="$fs" -v r="$rows" -v c="$cols" ${args[@]} \
      -f "$DS_SCRIPT/reorder.awk" "$file" 2>/dev/null | ds:ttyf "$fs" "$run_fit"
  else
    ds:prefield "$file" "$fs" 1 > $prefield
    awk -v FS="$DS_SEP" -v OFS="$fs" -v r="$rows" -v c="$cols" ${args[@]} \
      -f "$DS_SCRIPT/reorder.awk" $prefield 2>/dev/null | ds:ttyf "$fs" "$run_fit"; fi
  local stts_bash=${PIPESTATUS[0]} # TODO: Zsh pipestatus not working
  ds:pipe_clean $file; [ "$pf_off" ] || rm $prefield
  if [ "$stts_bash" ]; then return $stts_bash; fi
}

ds:pvt() { # ** Pivot data: ds:pv [file] [y_keys] [x_keys] [z_keys] [agg_type] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_pivot') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi

  if ds:is_int "$1" || ds:test '^([0-9]+,)+[0-9]+$' "$1"; then
    local y_keys="$1"; shift; fi
  if ds:is_int "$1" || ds:test '^([0-9]+,)+[0-9]+$' "$1"; then
    local x_keys="$1"; shift; fi
  if ds:is_int "$1" || ds:test '^([0-9]+,)+[0-9]+$' "$1"; then
    local z_keys="$1"; shift; fi

  ds:test '^[A-z]+$' "$1" && local agg_type="$1" && shift

  local args=( "$@" ) prefield=$(ds:tmp "ds_pivot_prefield")
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  ds:prefield "$file" "$fs" 1 > $prefield
  awk -v FS="$DS_SEP" -v OFS="$fs" -v x="${x_keys:-0}" -v y="${y_keys:-0}" \
    -v z="${z_keys:-0}" -v agg="${agg_type:-0}" ${args[@]} \
    -f "$DS_SCRIPT/pivot.awk" "$prefield" \
    | ds:ttyf "$DS_SEP"
  ds:pipe_clean $file; rm $prefield
}

ds:agg() { # ** Aggregate numerical data by index - i.e. '+|3..5': ds:agg [file] [r_aggs] [c_aggs] [x_aggs] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_agg') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi
  
  [ "$1" ] && ! grep -Eq '^-' <(echo "$1") && local r_aggs="$1" && shift
  [ "$1" ] && ! grep -Eq '^-' <(echo "$1") && local c_aggs="$1" && shift
  [ "$1" ] && ! grep -Eq '^-' <(echo "$1") && local x_aggs="$1" && shift

  if [ ! "$r_aggs" ] && [ ! "$x_aggs" ] && [ ! "$x_aggs" ]; then
    local r_aggs='+|all' c_aggs='+|all'; fi

  local args=( "$@" ) prefield=$(ds:tmp "ds_agg_prefield")
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  ds:prefield "$file" "$fs" 1 > $prefield
  awk -v FS="$DS_SEP" -v OFS="$fs" -v r_aggs="$r_aggs" -v c_aggs="$c_aggs" \
    -v x_aggs="$x_aggs" ${args[@]} -f "$DS_SCRIPT/agg.awk" "$prefield" \
    | ds:ttyf "$DS_SEP"
  ds:pipe_clean $file; rm $prefield
}

ds:decap() { # ** Remove up to n_lines from the start of a file: ds:decap [n_lines=1] [file]
  if [ "$1" ]; then
    ds:is_int "$1" && let n_lines=1+${1:-1} || ds:fail 'n_lines must be an integer: ds:decap n_lines [file]'
  fi
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_decap') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$2"
    local file="$2"; fi
  tail -n +${n_lines:-2} "$file"
  ds:pipe_clean $file
}

ds:transpose() { # ** Transpose field values (alias ds:t): ds:transpose [file] [awkargs]
  # TODO: Man page
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_transpose') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi
  local args=( "$@" ) prefield=$(ds:tmp "ds_transpose_prefield")
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  ds:prefield "$file" "$fs" 1 > $prefield
  awk -v FS="$DS_SEP" -v OFS="$fs" -v VAR_OFS=1 ${args[@]} \
    -f "$DS_SCRIPT/transpose.awk" $prefield 2> /dev/null | ds:ttyf "$fs"
  ds:pipe_clean $file; rm $prefield
}
alias ds:t="ds:transpose"

ds:pow() { # ** Print the frequency distribution of fielded data: ds:pow [file] [min] [return_fields=f] [invert=f] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_pow') piped=0
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift; fi
  ds:is_int "$1" && local min=$1 && shift
  ds:test "^(t|true)$" "$1" && local flds=1; [ "$1" ] && shift
  ds:test "^(t|true)$" "$1" && local inv=1; [ "$1" ] && shift
  local args=( "$@" )
  local prefield=$(ds:tmp "ds_pow_prefield") # TODO: Wrap this logic in prefield and return filename
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  ds:prefield "$file" "$fs" 1 > $prefield
  awk -v FS="$DS_SEP" -v OFS="$fs" -v min=${min:-1} -v c_counts=${flds:-0} -v invert=${inv:-0} \
    ${args[@]} -f "$DS_SCRIPT/power.awk" $prefield 2>/dev/null \
    | ds:sortm 1 a n -v FS="$fs" | sed 's///' | ds:ttyf "$fs"
  ds:pipe_clean $file; rm $prefield
}

ds:fieldcounts() { # ** Print value counts (alias ds:fc): ds:fc [file] [fields=1] [min=1] [order=a] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_fieldcounts') piped=0 
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift; fi
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
        unset "args[$fsv_idx]"; fi
      unset "args[$fs_idx]"; fi
    local prefield=$(ds:tmp "ds_fc_prefield")
    ds:prefield "$file" "$fs" > $prefield
    ds:test "\[.+\]" "$fs" && fs=" " 
    awk ${args[@]} -v FS="$DS_SEP" -v OFS="$fs" -v min="$min" -v fields="$fields" \
      -f "$DS_SCRIPT/field_counts.awk" $prefield 2>/dev/null | sort -n$order | ds:ttyf "$fs"
  else
    awk ${args[@]}-v min="$min" -v fields="$fields" \
      -f "$DS_SCRIPT/field_counts.awk" "$file" 2>/dev/null | sort -n$order | ds:ttyf "$fs"
  fi
  ds:pipe_clean $file; [ "$prefield" ] && rm $prefield; :
}
alias ds:fc="ds:fieldcounts"

ds:newfs() { # ** Outputs a file with an updated field separator: ds:newfs [file] [newfs=,] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_newfs') piped=0
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift; fi
  [ "$1" ] && local newfs="$1" && shift
  local args=( "$@" ) newfs="${newfs:-,}" prefield=$(ds:tmp "ds_newfs_prefield")
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  ds:prefield "$file" "$fs" > $prefield
  awk -v FS="$DS_SEP" -v OFS="$newfs" ${args[@]} "$program" $prefield 2> /dev/null
  ds:pipe_clean $file; rm $prefield
}

ds:hist() { # ** Print histograms for all number fields in data: ds:hist [file] [n_bins] [bar_len] [awkargs]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_hist') piped=0
    cat /dev/stdin > $file
  else 
    ds:file_check "$1"
    local file="$1"; shift; fi
  ds:is_int "$1" && local n_bins="$1" && shift
  ds:is_int "$1" && local bar_len="$1" && shift
  local args=( "$@" ) prefield=$(ds:tmp "ds_tmp_prefield")
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  ds:prefield "$file" "$fs" > $prefield
  awk -v FS="$DS_SEP" -v OFS="$fs" -v n_bins=$n_bins -v max_bar_leb=$bar_len \
    ${args[@]} -f "$DS_SCRIPT/hist.awk" $prefield 2> /dev/null
  ds:pipe_clean $file; rm $prefield

}

ds:asgn() { # Print lines from a file matching assignment pattern: ds:asgn file
  ds:file_check "$1"
  if ds:nset 'rg'; then
    rg "[[:alnum:]_]+ *=[^=<>]" $1 
  else
    egrep -n --color=always -e "[[:alnum:]_]+ *=[^=<>]" $1; fi
  if [ ! $? ]; then echo 'No assignments found in file!'; fi
}

ds:enti() { # Print text entities from a file separated by pattern: ds:enti [file] [sep= ] [min=1] [order=a]
  if ds:pipe_open; then
    local file=/tmp/newfs piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi
  local sep="${1:- }" min="${2:-1}"
  ([ "$3" = d ] || [ "$3" = desc ]) && local order="r"
  ([ "$min" ] && test "$min" -gt 0 2> /dev/null) || min=1
  let min=$min-1
  local program="$DS_SCRIPT/separated_entities.awk"
  LC_All='C' awk -v sep="$sep" -v min=$min -f $program "$file" 2> /dev/null | LC_ALL='C' sort -n$order
}

ds:sbsp() { # ** Extend fields by a common subseparator: ds:sbsp [file] subsep_pattern [nomatch_handler= ] [awkargs]
  # TODO: wrap pipe handling in single function (return tmp filename if piped)
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_sbsp') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi
  local ssp=(-v subsep_pattern="${1:- }") nmh=(-v nomatch_handler="${2:- }")
  local args=("${@:3}") prefield=$(ds:tmp "ds_sbsp_prefield")
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
      unset "args[$fsv_idx]"; fi
    unset "args[$fs_idx]"; fi
  ds:prefield "$file" "$fs" > $prefield
  awk -v FS="$DS_SEP" -v OFS="$fs"  ${ssp[@]} ${nmh[@]} ${args[@]} -f "$DS_SCRIPT/subseparator.awk" \
    "$prefield" "$prefield" 2> /dev/null
  ds:pipe_clean $file; rm $prefield
}

ds:dostounix() { # Remove ^M / CR characters in place: ds:dostounix file
  ds:file_check "$1"
  local inputfile="$1" tmpfile=$(ds:tmp 'ds_dostounix')
  cat "$inputfile" > $tmpfile
  tr -d "\015" < $tmpfile > "$inputfile"
  rm $tmpfile
}

ds:mini() { # ** Crude minify, remove whitespace and newlines: ds:mini [file] [newline_sep=;]
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_mini') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi
  local program='{gsub("(\n\r)+" ,"'"${1:-;}"'");gsub("\n+" ,"'"${1:-;}"'")
      gsub("\t+" ,"'"${1:-;}"'");gsub("[[:space:]]{2,}"," ");print}'
  awk -v RS="\0" "$program" "$file" 2> /dev/null | awk -v RS="\0" "$program" 2> /dev/null
  ds:pipe_clean $file
}

ds:sort() { # ** Sort with inferred field sep of exactly 1 char: ds:sort [unix_sort_args] [file]
  local args=( "$@" )
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_sort') piped=0
    cat /dev/stdin > $file
  else 
    let last_arg=${#args[@]}-1
    local file="${args[@]:$last_arg:1}"
    ds:file_check "$file"
    args=( ${args[@]/"$file"} ); fi
  local fs="$(ds:inferfs $file f true f f)"
  sort ${args[@]} --field-separator "$fs" "$file"
  ds:pipe_clean $file
}

ds:sortm() { # ** Sort with inferred field sep of >=1 char (alias ds:s): ds:sortm [file] [keys] [order=a|d] [sort_type] [awkargs]
  # TODO: Default to infer header
  if ds:pipe_open; then
    local file=$(ds:tmp 'ds_sortm') piped=0
    cat /dev/stdin > $file
  else
    ds:file_check "$1"
    local file="$1"; shift; fi
  ! grep -Eq '^-' <(echo "$1") && local keys="$1" && shift
  [ "$keys" ] && grep -Eq '^[A-z]$' <(echo "$1") && local ord="$1" && shift
  [ "$ord" ] && grep -Eq '^[A-z]$' <(echo "$1") && local type="$1" && shift
  local args=( "$@" )
  [ "$keys" ] && local args=("${args[@]}" -v k="$keys")
  [ "$ord" ] && local args=("${args[@]}" -v order="$ord")
  [ "$type" ] && local args=("${args[@]}" -v type="$type")
  if ds:noawkfs; then
    local fs="$(ds:inferfs "$file" f true f f)"
    awk -v FS="$fs" ${args[@]} -f "$DS_SCRIPT/fields_qsort.awk" "$file" 2> /dev/null
  else #TODO: Replace with consistent fs logic
    awk ${args[@]} -f "$DS_SCRIPT/fields_qsort.awk" "$file" 2> /dev/null; fi
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
      | xargs -0 -I % grep -H --color $invert "$search" "%" 2> /dev/null; fi
  :
}

ds:recent() { # List files modified in last 7 days: ds:recent [dir=.] [recurse=r] [hidden=h]
  if [ "$1" ]; then
    local dirname="$(echo "$1")"
    [ ! -d "$dirname" ] && echo Unable to verify directory provided! && return 1; fi

  local dirname="${dirname:-$PWD}" recurse="$2" hidden="$3" datefilter
  ds:nset 'fd' && local FD=1
  [ "$recurse" ] && ([ "$recurse" = 'r' ] || [ "$recurse" = 'true' ]) || unset recurse

  [ "$(ls --time-style=%D 2>/dev/null)" ] || local bsd=1
  local prg='{for(f=1;f<NF;f++){printf "%s ", $f;if($f~"^[0-3][0-9]/[0-3][0-9]/[0-9][0-9]$")printf "\""};print $NF "\""}'
  if [ "$hidden" ]; then
    [ $FD ] && [ "$recurse" ] && local hidden=-HI #fd hides by default
    [ -z "$recurse" ] && local hidden='A'
    local notfound="No files found modified in the last 7 days!"
  else
    [ ! $FD ] && [ "$recurse" ] && local hidden="-not -path '*/\.*'" # find includes all by default
    local notfound="No non-hidden files found modified in the last 7 days!"; fi

  if [ "$recurse" ]; then
    if [ "$bsd" ]; then
      local cmd_exec=(-exec stat -l -t "%D" \{\}) sortf=5
    else
      local cmd_exec=(-exec ls -ghtG --time-style=+%D \{\}) sortf=4; fi
    (
      if [ $FD ]; then
        fd -t f --changed-within=1week $hidden -E 'Library/' \
          -${cmd_exec[@]} 2> /dev/null \; ".*" "$dirname"
      else
        find "$dirname" -type f -maxdepth 6 $hidden -not -path ~"/Library" \
          -mtime -7d ${cmd_exec[@]} 2> /dev/null
      fi
    ) | sed "s:\\$(echo -n "$dirname")\/::" | awk "$prg" | sort -k$sortf \
      | ds:fit -v FS=" " | ds:pipe_check
  else
    if [ "$(date -v -0d 2>/dev/null)" ]; then
      for i in {0..6}; do
        local dates=( "${dates[@]}" "-e $(date -v "-${i}d" "+%D")" ); done
    else
      for i in {0..6}; do
        local dates=( "${dates[@]}" "-e $(date -d "-$i days" +%D)" ); done; fi

    ([ "$bsd" ] && stat -l -t "%D" "$dirname"/* \
      || ls -ghtG$hidden --time-style=+%D "$dirname" \
    ) | grep -v '^d' | grep ${dates[@]} | awk "$prg" | ds:fit -v FS=" " | ds:pipe_check
  fi
  [ $? = 0 ] || (echo "$notfound" && return 1)
}

ds:sedi() { # Linux-portable sed in place substitution: ds:sedi file|dir search [replace]
  [ "$1" ] && [ "$2" ] || ds:fail 'Missing required args: ds:sedi file|dir search [replace]'
  if [ -f "$1" ]; then
    local file="$1"
  else
    [ -d "$1" ] && local dir="$1" || local dir=.
    local conf="$(ds:readp "Confirm replacement of \"$2\" -> \"$3\" on all files in $dir (y/n):" | ds:downcase)"
    [ ! "$conf" = y ] && echo 'No change made!' && return 1; fi

  local search="$(printf "%q" "$2")"
  [ "$3" ] && local replace="$(printf "%q" "$3")"
  if [ "$file" ]; then
    perl -pi -e "s/${search}/${replace}/g" "$file"
  else
    while IFS=$'\n' read -r file; do
      echo "replaced \"$search\" with \"$replace\" in $file"
      perl -pi -e "s/${search}/${replace}/g" "$file"
    done < <(grep -r --files-with-match "$search" "$dir"); fi
  # TODO: Fix for forward slash replacement case and printf %q
}

ds:dff() { # Diff shortcut for more relevant changes: ds:dff file1 file2 [suppress_common]
  local tty_size=$(tput cols)
  let local tty_half=$tty_size/2
  [ "$3" ] && local sup=--suppress-common-lines && set -- "${@:1:2}"
  diff -b -y -W $tty_size $sup ${@} | expand | awk -v tty_half=$tty_half \
    -f "$DS_SCRIPT/diff_color.awk" | less
}

ds:gwdf() { # Git word diff shortcut: ds:gwdf [git_diff_args]
  local args=( "$@" )
  git diff --word-diff-regex="[A-Za-z0-9. ]|[^[:space:]]" --word-diff=color ${args[@]}
}

ds:goog() { # Search Google: ds:goog [search query]
  local search_args="$@"
  [ -z "$search_args" ] && ds:fail 'Arg required for search'
  local base_url="https://www.google.com/search?query="
  local search_query=$(echo $search_args | sed -e "s/ /+/g")
  local OS="$(ds:os)" search_url="${base_url}${search_query}"
  [ "$OS" = "Linux" ] && xdg-open "$search_url" && return
  open "$search_url"
}

ds:so() { # Search Stack Overflow: ds:so [search query]
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

ds:unicode() { # ** Get UTF-8 unicode for a character sequence: ds:unicode [str]
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

ds:websel() { # Download and extract inner html by regex: ds:websel url [tag_re] [attrs_re]
  local location="$1" tr_file="$DS_SUPPORT/named_entities_escaped.sed"
  local tag="${2:-[a-z]+}" attrs="${3:-[^>]*}"
  local unescaped="$( wget -qO- "$location" |
    perl -l -0777 -ne 'printf join("\n",/<'"$tag.*?$attrs"'.*?>\s*(.*?)\s*<\/'"$tag"'/g)' )"

  if [ -f "$tr_file" ]; then
    printf "$unescaped" | sed -f "$tr_file"
  else
    printf "$unescaped"; fi
}

ds:dups() { # Report duplicate files with option for deletion: ds:dups [dir]
  if ! ds:nset 'md5sum'; then
    echo 'md5sum utility not found - please install GNU coreutils to enable this command'
    return 1
  fi
  ds:nset 'pv' && local use_pv="-p"
  ds:nset 'fd' && local use_fd="-f"
  [ -d "$1" ] && local dir="$1" || local dir="$PWD"
  bash "$DS_SCRIPT/dup_files.sh" -s "$dir" $use_fd $use_pv
}

ds:deps() { # Identify the dependencies of a shell function: ds:deps name [filter] [ntype=(FUNC|ALIAS)] [call_func] [data]
  [ "$1" ] || (ds:help ds:deps && return 1)
  local tmp=$(ds:tmp 'ds_deps') srch="$2"
  [ "$3" ] && local scope="$3" || local scope="(FUNC|ALIAS)"
  [ "$4" ] && local cf="$1"
  if [ -f "$5" ]; then local ndt="$5"
  else
    local ndt=$(ds:tmp 'ds_ndata') rm_dt=0
    ds:ndata | awk "\$1~\"$scope\"{print \$2}" | sort > $ndt; fi
  if [ $(which "ds:help" | wc -l) -gt 1  ]; then
    which "$1" | ds:decap > $tmp
  else
    ds:fsrc "$1" | ds:decap 2 > $tmp; fi
  awk -v search="$srch" -v calling_func="$cf" -f "$DS_SCRIPT/shell_deps.awk" $tmp $ndt
  rm $tmp; [ "$rm_dt" ] && rm $ndt
}

ds:gexec() { # Generate a script from pieces of another and run it: ds:gexec run=f srcfile outputdir reo_r_args [clean] [verbose]
  [ "$1" ] && local run="$1" && shift || (ds:help ds:gexec && return 1)
  ds:file_check "$1"
  [ -d "$2" ] || ds:fail 'second arg must be a directory'
  [ "$3" ] || ds:fail 'missing required match patterns'
  local src="$1" scriptdir="$2" r_args="$3" clean="$4"
  [ "$5" ] && local run_verbose=-x
  read -r dirpath filename extension <<<$(ds:path_elements "$src")
  local gscript="$scriptdir/ds_gexec_from_$filename$extension"

  ds:reo $src "$r_args" 'off' false > "$gscript"
  echo -e "\n\033[0;33mNew file: $gscript\033[0m\n"
  chmod 777 "$gscript"; cat "$gscript"

  ds:test "^(t|true)$" "$run" && echo && local conf=$(ds:readp 'Confirm script run (y/n):')
  if [ "$conf" = y ]; then
    echo -e "\n\033[0;33mRunning file $gscript\033[0m\n"
    bash $run_verbose "$gscript"; local stts="$?"
  else
    echo -e "\n\033[0;33mScript not executed!\033[0m"; fi

  [ $clean ] && rm "$gscript" && echo -e "\n\033[0;33mRemoved file $gscript\033[0m"
  if [ "$stts" ]; then return "$stts"; fi
}

