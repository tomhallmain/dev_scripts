#!/bin/bash


ds:file_check() { # Test for file validity and fail if invalid
  local testfile="$1"
  [ ! -f "$testfile" ] && ds:fail 'File not provided or invalid!'
}

ds:noawkfs() { # Test whether awk arg for setting field separator is present
  [[ ! "${args[@]}" =~ "^\-F" && ! "${args[@]}" =~ "-v FS" && ! "${args[@]}" =~ "-v fs" ]]
}

ds:dequote() { # Transform FS of a file with quoted fields which contain FS into non-clashing FS
  ds:file_check "$1"
  local file="$1" fs="$2"
  if [[ ! "${args[@]}" =~ "-v OFS" && ! "${args[@]}" =~ "-v ofs" ]]; then
    awk -v OFS="||" -v FS="$fs" ${args[@]} -f $DS_SCRIPT/quoted_fields.awk "$file" 2>/dev/null
  else
    awk -v FS="$fs" ${args[@]} -f $DS_SCRIPT/quoted_fields.awk "$file" 2>/dev/null
  fi
}

ds:arr_idx() { # Extract first shell array element position matchings pattern
  local pattern="$1"; shift
  local idx=$(printf "%s\n" "$@" | awk "/$pattern/{print NR-1; exit}")
  [ "$idx" = "" ] && return 1
  let local idx=$idx+$(ds:arr_base)
  echo -n $idx
}

ds:die() { # Output to STDERR and exit with error
  echo "$*" >&2
  if ds:sub_sh || ds:nested; then kill $$; fi
}

ds:pipe_open() { # ** Detect if pipe is open
  [ -p /dev/stdin ]
}

ds:pipe_clean() { # Remove a temp file created via stdin if piping has been detected
  if [ $piped ]; then rm "$1" &> /dev/null; fi
}

ds:sh() { # Print the shell being used (works for sh, bash, zsh)
  ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{print $NF}'
}

ds:subsh() { # Detect if in a subshell 
  [[ $BASH_SUBSHELL -gt 0 || $ZSH_SUBSHELL -gt 0 || "$(exec sh -c 'echo "$PPID"')" != "$$" || "$(exec ksh -c 'echo "$PPID"')" != "$$" ]]
}

ds:nested() { # Detect if shell is nested for control handling
  [ $SHLVL -gt 1 ]
}

ds:arr_base() { # Return first array index for shell
  shell="$(ds:sh)"
  if [[ $shell =~ bash ]]; then
    printf 0
  elif [[ $shell =~ zsh ]]; then
    printf 1
  else
    ds:fail 'This shell unsupported at this time'
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

ds:os() { # Return computer operating system if supported
  local mstest=/proc/version
  [ -f $mstest ] && grep -q Microsoft $mstest && echo "MS Windows" && return

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Mac OSX"
  elif [[ "$OSTYPE" == "cygwin" ]]; then
    echo "MS Windows"
  elif [[ "$OSTYPE" == "msys" ]]; then
    echo "MS Windows"
  elif [[ "$OSTYPE" == "win32" ]]; then
    echo "MS Windows"
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
    echo "FreeBSD"
  fi
}

ds:not_git() { # Check if directory is not part of a git repo
  [ -z $1 ] || cd "$1"
  [[ ! ( -d .git || $(git rev-parse --is-inside-work-tree 2> /dev/null) ) ]]
}

ds:unixtodos() { # Removes \r characters in place
  # TODO: Name may need to be updated, put this and above in different file
  # TODO: Add check for WSL
  ds:file_check "$1"
  local inputfile="$1" tmpfile=/tmp/unixtodos
  cat "$inputfile" > $tmpfile
  sed -e 's/\r//g' $tmpfile > "$inputfile"
  rm $tmpfile
}

ds:is_cli() { # Detect if shell is interactive
  shell="$(ds:sh)"
  if [[ $shell =~ bash ]]; then
    [ "$PS1" ]
  elif [[ $shell =~ zsh ]]; then
    [[ $PS1 =~ "(base)" ]]
    [ $? = 1 ]
  else
    ds:fail 'This shell unsupported at this time'
  fi
}

ds:readp() { # Portable read prompt
  shell="$(ds:sh)"
  if [[ $shell =~ bash ]]; then
    read -p $"\e[37m$1\e[0m" myvar
  elif [[ $shell =~ zsh ]]; then
    read "myvar?$1 "
  else
    ds:fail 'This shell unsupported at this time'
  fi
  echo $myvar; unset myvar
}

ds:gcam() { # Git commit add message
  ds:not_git && return 1
  if [ $1 ]; then
    git commit -am "$1"
  else
    git commit
  fi
}

ds:downcase() { # Downcase strings
  if ds:pipe_open; then
    cat /dev/stdin | tr "[:upper:]" "[:lower:]"
  else
    echo "$1" | tr "[:upper:]" "[:lower:]"
  fi
}

ds:is_int() { # Tests if arg is an integer
  local int_re="^[0-9]+$"
  [[ $1 =~ $int_re ]]
}

ds:genvar() { # For meta programming - shell doesn't allow some chars in var names
  local unparsed="$1"

  var="${unparsed//\./_DOT_}"
  var="${var// /_SPACE_}"
  var="${var//-/_HYPHEN_}"
  var="${var//\//_FSLASH_}"
  var="${var//\\/_BSLASH_}"
  var="${var//1/_ONE_}"
  var="${var//2/_TWO_}"
  var="${var//3/_THREE_}"
  var="${var//4/_FOUR_}"
  var="${var//5/_FIVE_}"
  var="${var//6/_SIX_}"
  var="${var//7/_SEVEN_}"
  var="${var//8/_EIGHT_}"
  var="${var//9/_NINE_}"

  printf '%s\n' "${var}"
}

ds:ndata() { # Gathers data about names in current context
  local _var=$(declare | awk -F"=" '{print $1}' | awk '{print $NF}')
  local _func=$(declare -f | grep -h '^[A-Za-z_:]*\s()' | cut -f 1 -d ' ' \
    | grep -hv '()' | sed 's/^_//')
  local _alias=$(alias | awk -F"=" '{print $1}')
  local _bin=$(ls /bin)
  local _usrbin=$(ls /usr/bin | grep -hv "\.")
  local _usrlocalbin=$(ls /usr/local/bin | grep -hv "\.")
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

ds:termcolors() { # Check terminal colors
  echo ANSI ESCAPE FG COLOR CODES
  print "\u001b[30m 30   \u001b[31m 31   \u001b[32m 32   \u001b[33m 33   \u001b[0m"
  print "\u001b[34m 34   \u001b[35m 35   \u001b[36m 36   \u001b[37m 37   \u001b[0m"
  print "\u001b[30;1m 30;1 \u001b[31;1m 31;1 \u001b[32;1m 32;1 \u001b[33;1m 33;1 \u001b[0m"
  print "\u001b[34;1m 34;1 \u001b[35;1m 35;1 \u001b[36;1m 36;1 \u001b[37;1m 37;1 \u001b[0m"
  echo
  echo ANSI ESCAPE BG COLOR CODES
  print "\u001b[40m 40   \u001b[41m 41   \u001b[42m 42   \u001b[43m 43   \u001b[0m"
  print "\u001b[44m 44   \u001b[45m 45   \u001b[46m 46   \u001b[47m 47   \u001b[0m"
  print "\u001b[40;1m 40;1 \u001b[41;1m 41;1 \u001b[42;1m 42;1 \u001b[43;1m 43;1 \u001b[0m"
  print "\u001b[44;1m 44;1 \u001b[45;1m 45;1 \u001b[46;1m 46;1 \u001b[47;1m 47;1 \u001b[0m"
  echo
  echo 256 COLOR TEST
  for ((i=16; i<256; i++)); do
    printf "\e[48;5;${i}m%03d" $i;
    printf '\e[0m';
    [ ! $((($i - 15) % 6)) -eq 0 ] && printf ' ' || printf '\n'
  done
}
