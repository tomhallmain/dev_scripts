#!/bin/bash

DS_SEP=$'@@@'

if tput colors &> /dev/null
then
    DS_COLOR_SUP=1
fi

if [ "$TERM" = dumb ]
then
    DS_DUMB_TERM=1
fi

ds:file_check() { # Test for file validity and fail if invalid: ds:file_check testfile [check_writable=f] [allow_binary=f] [enable_search]
    [ -z "$1" ] && ds:fail 'File not provided!'
    local tf="$1" enable_search="$4"
    [[ -e "$tf" && ! -d "$tf" ]] && local filelike=0
    [ "$3" ] && ds:test 't(rue)?' "$3" && local allow_binary=0
    
    if [ "$2" ] && ds:test 't(rue)?' "$2"; then
        [[ -w "$tf" && -f "$tf" ]] || ds:fail "File \"$tf\" is not writable"
    elif [ "$enable_search" ]; then
        if [ "$filelike" ]; then
            if [[ ! "$allow_binary" && ! "$tf" =~ '/dev/fd/' && -s "$tf" ]] && ! grep -Iq "" "$tf"; then
                ds:fail "Found file \"$tf\" Binary files have been disallowed for this command"
            fi
            echo -n "$tf"
        else
            if [ "$allow_binary" ]; then
                local f=$(ds:nset 'fd' && fd -t f "$tf" | head -n1 \
                    || find . -type f -name "*$tf*" -not -path '*/\.*' | head -n1)
            else
                local f=$(ds:nset 'fd' && fd -t f -x grep -Il '.' {} \; "$tf" | head -n1 \
                    || find . -type f -name "*$tf*" -not -path '*/\.*' -exec grep -Il '.' {} \; | head -n1)
            fi
            [[ -z "$f" || ! -f "$f" ]] && ds:fail "File \"$tf\" not provided or invalid"
            local conf=$(ds:readp "Arg is not a file - run on closest match ${f}? (y/n)")
            [ "$conf" = "y" ] && echo -n "$f" || ds:fail "File \"$f\" not provided or invalid"
        fi
        return
    fi
    
    if [ ! "$filelike" ]; then # TODO: Bash -e test fails on fds
        ds:fail "File \"$tf\" not provided or invalid"; fi
    if [[ ! "$allow_binary" && ! "$tf" =~ '/dev/fd/' && -s "$tf" ]] && ! grep -Iq "" "$tf"; then
        ds:fail "Found file \"$tf\" - Binary files have been disallowed for this command!"; fi
}

ds:fd_check() { # Convert fds into files: ds:fd_check testfile
    if [[ "$1" =~ '/dev/fd/' ]]; then
        local ds_fd="$(ds:tmp 'ds_fd')"
        cat "$1" > "$ds_fd"
        echo -n "$ds_fd"
    else echo -n "$1"; fi
}

ds:awk() { # Run an awk script with utils: ds:awk [script] [files...] varargs...
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_awk') piped=0
        cat /dev/stdin > $_file
    fi
    local _SCRIPT_="$(ds:fd_check "$1")"
    local _FILES_=( ) _counter_=0
    while [[ "$2" && $_counter_ -lt 20 ]] && [[ "$2" =~ '/dev/fd/' || -f "$2" ]]; do
        local _FILES_=( "${_FILES_[@]}" "$(ds:fd_check "$2")" )
        let local _counter_+=1
        shift
    done
    local _VARARGS_=( ) _counter_=0
    while [[ "$2" && $_counter_ -lt 50 ]]; do
        local _VARARGS_=( "${_VARARGS_[@]}" -v "$2" )
        let local _counter_+=1
        shift
    done

    if [ "$_SCRIPT_" ]; then
        awk -f "$DS_SUPPORT/utils.awk" -f "$_SCRIPT_" $_VARARGS_ $_FILES_
    else
        awk -f "$DS_SUPPORT/utils.awk" $_VARARGS_ $_FILES_
    fi
}

ds:readlink() { # Portable readlink: ds:readlink [file|dir]
    local OLD_PWD="$(pwd)"
    cd "$(dirname "$1")" &>/dev/null 3>/dev/null 4>/dev/null 5>/dev/null 6>/dev/null
    local target="$(basename "$1")"
    while [ -L "$target" ]; do
        local target="$(readlink "$target")"
        cd "$(dirname "$target")" &>/dev/null 3>/dev/null 4>/dev/null 5>/dev/null 6>/dev/null
        local target="$(basename "$target")"
    done
    echo "$(pwd -P)/$target"
    cd "$OLD_PWD" &>/dev/null 3>/dev/null 4>/dev/null 5>/dev/null 6>/dev/null
}

ds:extractfs() { # Infer or extract single awk FS from args: ds:extractfs
    if ds:noawkfs; then
        local fs="$(ds:inferfs "$_file" true)"
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
    echo -n "$fs"
}

ds:noawkfs() { # Test whether AWK arg for setting field separator is present: ds:noawkfs
    [[ ! "${args[@]}" =~ "-F" && ! "${args[@]}" =~ "-v FS" && ! "${args[@]}" =~ "-v fs" ]]
}

ds:awksafe() { # Test whether AWK is configured for multibyte regex: ds:awksafe
    echo test | awk -f "$DS_SUPPORT/wcwidth.awk" -f "$DS_SUPPORT/awktest.awk" &> /dev/null
}

ds:prefield() { # Infer and transform FS for complex field patterns: ds:prefield file fs [dequote] [awkOFSargs]
    ds:file_check "$1"
    local _file="$1" fs="$2" dequote=${3:-0}
    [[ "$_file" =~ "^/tmp" ]] && ds:dostounix "$_file"
    if [[ ! "${@:4}" =~ "-v OFS" && ! "${@:4}" =~ "-v ofs" ]]; then
        LC_ALL='C' awk -v OFS="$DS_SEP" -v FS="$fs" -v retain_outer_quotes="$dequote" ${@:4} \
            -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/quoted_fields.awk" "$_file" 2>/dev/null
    else
        LC_ALL='C' awk -v FS="$fs" -v retain_outer_quotes="$dequote" ${@:4} -f "$DS_SUPPORT/utils.awk" \
            -f "$DS_SCRIPT/quoted_fields.awk" "$_file" 2>/dev/null; fi
}

ds:arr_idx() { # Extract first shell array element position matching pattern: ds:arr_idx pattern ${arr[@]}
    local pattern="$1"; shift
    local idx=$(printf "%s\n" "$@" | awk "/$pattern/{print NR-1; exit}")
    [ "$idx" = "" ] && return 1
    let local idx=$idx+$(ds:arr_base)
    echo -n $idx
}

ds:die() { # Output to STDERR and exit with error: ds:die
    echo "$*" >&2
    if ds:sub_sh || ds:nested; then kill $$; fi
}

ds:pipe_open() { # ** Detect if pipe is open: if ds:pipe_open [possible_file_arg]; then [...]
    [ $DS_DUMB_TERM ] && [[ "$1" && ! -f "$1" || ! -t 0 ]] || [ ! -t 0 ]
}

ds:ttyf() { # ** Run ds:fit on output only if to a terminal: data | ds:ttyf [FS] [run_fit=t] [fit_awkargs]
    local fit="${2:-t}"
    if [[ "$fit" = "t" && -t 1 ]]; then
        ds:arr_idx 'debug' "${args[@]}" && cat && return
        [ "$1" ] && ds:fit -v FS="$1" ${@:3} && return
        ds:fit ${@:3}
    else cat; fi
}

ds:pipe_clean() { # Remove tmpfile created via STDIN if piping detected: piped=0; tmp=$(mktemp tmp); ds:pipe_clean $tmp
    if [ $piped ]; then rm "$1" &> /dev/null; fi
}

ds:sh() { # Print the shell being used - works for sh, bash, zsh: ds:sh
    ps -ef | awk 'NR==1 {for (f=4;f<=NF;f++) {if ($f=="CMD") pf=f}} $2==pid {print $pf}' pid=$$
}

ds:subsh() { # Detect if in a subshell: ds:subsh
    [[ $BASH_SUBSHELL -gt 0 || $ZSH_SUBSHELL -gt 0 || "$(exec sh -c 'echo "$PPID"')" != "$$" || "$(exec ksh -c 'echo "$PPID"')" != "$$" ]]
}

ds:nested() { # Detect if shell is nested for control handling: ds:nested
    [ $SHLVL -gt 1 ]
}

ds:arr_base() { # Return first array index for shell: ds:arr_base
    local shell="$(ds:sh)"
    if [[ $shell =~ bash ]]; then
        printf 0
    elif [[ $shell =~ zsh ]]; then
        printf 1
    else
        ds:fail 'This shell unsupported at this time'; fi
}

ds:needs_arg() { # Test if argument is missing from opt and handle UX: ds:needs_arg opt [optarg]
    local opt="$1" optarg="$2"; #echo $optarg
    [ -z "$optarg" ] && echo "No arg for --$opt option" && ds:fail
}

ds:longopts() { # Extract long opts - https://stackoverflow.com/a/28466267/519360: ds:longopts opt [optarg]
    local opt="$1" optarg="$2"
    opt="${optarg%%=*}"       # extract long option name
    optarg="${optarg#$opt}"   # extract long option argument (may be empty)
    optarg="${optarg#=}"      # if long option argument, remove assigning `=`
    local out=( "$opt" "$optarg" )
    printf '%s\t' "${out[@]}"
}

ds:opts() { # General flag opts handling: ds:opts $@
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

ds:os() { # Return computer operating system if supported: ds:os
    local mstest=/proc/version
    [ -f $mstest ] && grep -q Microsoft $mstest && echo "MS Windows" && return

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "MacOSX"
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        echo "MSWindows"
    elif [[ "$OSTYPE" == "msys" ]]; then
        echo "MSWindows"
    elif [[ "$OSTYPE" == "win32" ]]; then
        echo "MSWindows"
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        echo "FreeBSD"
    else
        echo "Failed to detect OS" && return 1; fi
}

ds:not_git() { # Check if directory is not part of a git repo: ds:not_git
    [ -z $1 ] || cd "$1"
    [[ ! ( -d .git || $(git rev-parse --is-inside-work-tree 2> /dev/null) ) ]]
}

ds:is_cli() { # Detect if shell is interactive: ds:is_cli
    local shell="$(ds:sh)"
    if [[ $shell =~ bash ]]; then
        [ "$PS1" ]
    elif [[ $shell =~ zsh ]]; then
        [[ $PS1 =~ "(base)" ]]
        [ $? = 1 ]
    else
        ds:fail 'This shell unsupported at this time'
    fi
}

ds:term_width() { # Get a terminal width that doesn't fail if TERM isn't set: ds:term_width
    if ! tput cols
    then
        echo 100
    fi
}

ds:readp() { # Portable read prompt: ds:readp [message] [downcase=t]
    local s="$(ds:sh)" downcase="${2:-t}"
    if [[ "$s" =~ bash ]]; then
        read -p $'[37m'"$1 "'[0m' readvar
    elif [[ $s =~ zsh ]]; then
        read "readvar?$1 "
    else
        ds:fail 'This shell unsupported at this time'
    fi
    if [[ "$downcase" = t || "$downcase" = T ]]; then
        ds:case $readvar down
    else
        echo -n "$readvar"
    fi
    unset readvar
}

ds:is_int() { # Tests if arg is an integer: ds:is_int arg
    local int_re="^-?[0-9]+$"
    [[ $1 =~ $int_re ]]
}

ds:genvar() { # Gen varname, shell disallows certain chars in var names: ds:genvar name
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

ds:ndata() { # Gathers data about names in current context: ds:ndata
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
       _[FILENAME] = 1 }'                 \
        <(printf '%s\n' ${_var})          \
        <(printf '%s\n' ${_func})         \
        <(printf '%s\n' ${_alias})        \
        <(printf '%s\n' ${_bin})          \
        <(printf '%s\n' ${_builtin})      \
        <(printf '%s\n' ${_usrbin})       \
        <(printf '%s\n' ${_usrlocalbin})  | sort
}

ds:termcolors() { # Check terminal colors: ds:termcolors
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

ds:ascii() { # List characters in ASCII code point range: ds:ascii start_index end_index
    if [[ "$(ds:sh)" =~ zsh ]]; then
        ds:is_int "$1" && ds:is_int "$2" || ds:fail 'Code point endpoint args must be integers'
        for i in $(seq $1 $2); do printf "%s " $i; printf -v n "%x" $i; echo -e "\U$n"; done
    else
        echo "Your shell does not currently support this function"
    fi
}
