#!/bin/bash

[ ! "$DS_LOC" ] && DS_LOC="$HOME/dev_scripts"
DS_SCRIPT="$DS_LOC/scripts"
DS_SUPPORT="$DS_LOC/support"
source "$DS_SUPPORT/utils.sh"

ds:commands() { # List dev_scripts commands: ds:commands [bufferchar] [utils] [re_source]
    [ "$2" ] && local utils="$DS_SUPPORT/utils.sh"
    [ "$3" ] && local re_source=0
    [ "$utils" ] && local DS_COMMANDS="$DS_SUPPORT/commands_utils" || local DS_COMMANDS="$DS_SUPPORT/commands"

    if [ "$re_source" ] || ! ds:test "@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE" "$DS_COMMANDS" t; then
        grep -Eh 'ds:[[:alnum:]_]+\(\)' "$DS_LOC/commands.sh" "$utils" 2>/dev/null | sort \
            | awk -F "\\\(\\\) { #" '{printf "%-18s\t%s\n", $1, $2}' \
            | ds:subsep '**' "$DS_SEP" -v retain_pattern=1 -v apply_to_fields=2 -v FS="[[:space:]]{2,}" -v OFS="$DS_SEP" \
            | ds:subsep ":[[:space:]]" "888" -v apply_to_fields=3 -v FS="$DS_SEP" -v OFS="$DS_SEP" \
            | ds:subsep '\\\(alias ' '$' -v apply_to_fields=3 | sed 's/)@/@/' \
            | awk -v FS="$DS_SEP" '
                BEGIN { print "COMMAND" FS FS "DESCRIPTION" FS "ALIAS" FS "USAGE\n" }
                      { print }
                END   { print "\nCOMMAND" FS FS "DESCRIPTION" FS "ALIAS" FS "USAGE\n" }' \
            | ds:reo a 2,1,4,3,5 > "$DS_COMMANDS"
    fi

    echo
    cat "$DS_COMMANDS" | ds:ttyf "$DS_SEP" t -v bufferchar="${1:- }"
    echo "** - function supports receiving piped data"
    echo
}

ds:help() { # Print help for a given command: ds:help ds_command
    (ds:nset "$1" && [[ "$1" =~ "ds:" ]]) || ds:fail 'Command not found - to see all commands, run ds:commands'
    [[ "$1" =~ ':reo' ]] && ds:reo -h && return
    [[ "$1" =~ ':fit' ]] && ds:fit -h && return
    [[ "$1" =~ ':join' ]] && ds:join -h && return
    [[ "$1" =~ ':agg' ]] && ds:agg -h && return
    [[ "$1" =~ ':stag' ]] && ds:stagger -h && return
    [[ "$1" =~ ':pow' ]] && ds:pow -h && return
    [[ "$1" =~ ':shape' ]] && ds:shape -h && return
    [[ "$1" =~ ':subsep' ]] && ds:subsep -h && return
    [[ "$1" =~ ':pivot' ]] && ds:pivot -h && return
    [[ "$1" =~ ':diff_fields' ]] && ds:diff_fields -h && return
    ds:commands "" t | ds:reo "2, 2~$1 || 3~$1" "2[$1~. || 3[$1~."
}

ds:vi() { # Search for files and open in vim: ds:vi search [dir] [edit_all_match=f]
    [ ! "$1" ] && echo 'Filename search pattern missing!' && ds:help ds:vi && return 1
    local search="${1}" dir="${2:-.}" all="${3:-f}"
    ds:test 't(rue)?' "$all" || local singlefile=0
    if fd --version &>/dev/null; then
        local fileset="$(fd -t f "$search" "$dir" 2>/dev/null | head -n100 | sed -E 's#^\./##g')"
    elif fd-find --version &>/dev/null; then
        local fileset="$(fd-find -t f "$search" "$dir" 2>/dev/null | head -n100 | sed -E 's#^\./##g')"
    else
        local fileset="$(find "$dir" -type f -name "*$search*" -maxdepth 10 2>/dev/null | head -n100 | sed -E 's#^\./##g')"
    fi
    local matchcount="$(echo -e "$fileset" | wc -l | xargs)"
    ! ds:is_int "$matchcount" && ds:fail 'Unable to find a match with current args'

    if [ "$matchcount" -gt 1 ]; then
        if [ "$singlefile" ]; then
            echo 'Multiple matches found - select a file:'
            while [ ! $confirmed ]; do
                echo -e "$fileset" | ds:index 1 -v FS=$DS_SEP | ds:fit -v FS=$DS_SEP
                while [ ! "$_matched_" ]; do
                    local choice="$(ds:readp 'Enter a number from the set of files or a pattern:' f)"
                    if ds:is_int "$choice" && [[ $choice -gt 0 && $choice -le $matchcount ]]; then
                        local _matched_=0 _patt_=""
                    elif ! ds:test '^ *$' "$choice" && echo -e "$fileset" | grep -q "$choice"; then
                        local _matched_=0 _patt_='~'
                    else
                        echo "Unable to read selection, try again."
                        continue
                    fi
                done
                local fileset="$(echo -e "$fileset" | ds:reo "${_patt_}${choice}" off)"
                local matchcount="$(echo -e "$fileset" | wc -l | xargs)"
                ! ds:is_int "$matchcount" && ds:fail 'Unable to find a match with current args'
                [ "$matchcount" -gt 1 ] && unset _matched_ && continue
                local confirmed=0
            done
        fi
    fi

    if [ "$singlefile" ]; then
        if [ -f "$fileset" ]; then
            [ -f ".$fileset.swp" ] && ds:fail "File $fileset already open"
            vi "$fileset"
        elif [[ -f "$search" || -d "$search" ]]; then
            vi "$search"
        else
            if [ ! "$try_vi" ]; then
                local try_gvi="$(ds:readp 'No match found - Did you mean to search with ds:grepvi? (y/n)')"
            fi
            if [ "$try_gvi" = y ]; then
                ds:grepvi $@
                return $?
            else
                return 1
            fi
        fi
    else
        echo 'Editing files:'; echo -e "$fileset"
        vi $(echo -e "$fileset")
    fi
}

ds:grepvi() { # Grep and open vim on match (alias ds:gvi): ds:gvi search [file|dir] [edit_all_match=f]
    local search="$1" all="${3:-f}"
    if [ -f "$2" ]; then local file="$2"
        if ds:nset 'rg'; then
            local line=$(rg --line-number "$search" "$file" | head -n1 | ds:reo 1 1 -v FS=":")
        else
            local line=$(grep --line-number "$search" "$file" | head -n1 | ds:reo 1 1 -v FS=":")
        fi
    else
        ds:test 't(rue)?' "$all" || local singlefile=0
        local tmp=$(ds:tmp 'ds_gvi')
        [ -d "$2" ] && local dir="$2"
        
        if [ -z $dir ]; then
            local dir="." basedir_f=($(find . -maxdepth 0 -type f | grep -v ":"))
            [ ! "$2" = "" ] && local filesearch="1~$2" || local filesearch=a
        else
            local basedir_f=($(find "$dir" -maxdepth 0 -type f | grep -v ":"))
        fi
        
        if ds:nset 'rg'; then
            rg -Hno --no-heading --hidden --color=never -g '!*:*' -g '!.git' \
                "$search" ${basedir_f[@]} "$dir" | head -n1000 > $tmp
        else
            grep -HInors --color=never --exclude ':' --excludedir '.git' \
                "$search" ${basedir_f[@]} "$dir" | head -n1000 > $tmp
        fi
        
        local fileline="$(ds:reo $tmp "$filesearch" 1,2 -F: -v q=1 | head -n500 | sed -E 's#^\./##g' | sort)"
        local matchcount="$(echo -e "$fileline" | wc -l | xargs)"
        local fileset="$(echo -e "$fileline" | ds:fc 1 1 -v FS=: | ds:reo a 2 -F: | sort)"
        local filematchcount="$(echo -e "$fileset" | wc -l | xargs)"
        ! ds:is_int "$matchcount" && rm $tmp && ds:fail 'gvi encountered an error while processing match data'
        ! ds:is_int "$filematchcount" && rm $tmp && ds:fail 'gvi encountered an error while processing match data'
        
        if [ "$singlefile" ]; then
            if [ "$matchcount" -gt 1 ]; then
                if [ "$filematchcount" -gt 1 ]; then
                    echo 'Multiple matches found - select a file:'
                    
                    while [ ! "$confirmed" ]; do
                        echo -e "$fileset" | ds:index 1 -F: | ds:fit -v FS=: -v color=never
                        
                        while [ ! "$_matched_" ]; do
                            local choice="$(ds:readp 'Enter a number from the set of files or a pattern:' f)"
                            if ds:is_int "$choice" && [[ $choice -gt 0 && $choice -le $matchcount ]]; then
                                local _matched_=0 _patt_=""
                            elif ! ds:test '^ *$' "$choice" && echo -e "$fileset" | grep -q "$choice"; then
                                local _matched_=0 _patt_='~'
                            else
                                echo "Unable to read selection, try again."
                                continue
                            fi
                        done

                        local fileset="$(echo -e "$fileset" | ds:reo "${_patt_}${choice}" off)"
                        local filematchcount="$(echo -e "$fileset" | wc -l | xargs)"
                        [ "$filematchcount" -gt 1 ] && unset _matched_ && continue
                        local confirmed=0
                        local fileline="$(echo -e "$fileline" | ds:reo "1~$fileset" a -F: | head -n1)"
                    done
                else
                    local fileline="$(echo -e "$fileline" | head -n1)"
                fi
            fi
            local file="${fileline%:*}" line=${fileline##*:}
        fi
    
        rm $tmp
    
        if [[ "$singlefile" && ! -f "$file" ]]; then echo "$file"
            if [ -f "$search" ]; then
                vi "$search" && return
            else
                if [ ! "$try_gvi" ]; then
                    local try_vi="$(ds:readp 'No match found - Did you mean to search with ds:vi? (y/n)')"
                fi
                if [ "$try_vi" = y ]; then
                    ds:vi $@
                    return $?
                else
                    return 1
                fi
            fi
        fi
    fi

    if [[ "$singlefile" || "$filematchcount" -lt 2 ]]; then
        if ! ds:is_int "$line"; then
            if [ -f "$search" ]; then
                [ -f ".$file.swp" ] && echo "File $file already open - can't open matchline $line" && return 1
                vi "$search" && return
            else
                local try_vi="$(ds:readp 'No match found - Did you mean to search with ds:vi? (y/n)')"
                if [ "$try_vi" = y ]; then ds:vi $@; return $?
                else return 1
                fi
            fi
        fi

        vi +$line "$file" || return 1
    
    else
        echo 'Running vim on all file matches. To move to the next file quit the current one.'
        echo 'To quit the loop press Ctrl+C after quitting a file.'
        sleep 4
        local OLD_IFS="$IFS"
        IFS=$'\n'
        
        for fl in $(echo -e "$fileline"); do
            local file="${fl%:*}" line="${fl##*:}"
            [ -f "$file" ] && ds:is_int "$line" || continue
            ds:test "${file}${DS_SEP}" "$seenfiles" && continue
            local seenfiles="${seenfiles}${file}${DS_SEP}"
            [ -f ".$file.swp" ] && echo "File $file already open - can't open matchline $line" && continue 
            sleep 1; vi +$line "$file"
        done

        IFS="$OLD_IFS"
    fi
}
alias ds:gvi="ds:grepvi"

ds:cd() { # cd to higher or lower level dirs: ds:cd [search]
    [ ! "$1" ] && cd "$HOME" && return
    local search="$1"
    [ -d "$search" ] && cd "$search" && return
    
    if fd --version &>/dev/null; then
        local _FD=0 dirset="$(fd -t d "$search" 2>/dev/null | head -n100 | sed -E 's#^\./##g')"
    elif fd-find --version &>/dev/null; then
        local _FDF=0 dirset="$(fd-find -t d "$search" 2>/dev/null | head -n100 | sed -E 's#^\./##g')"
    else
        local dirset="$(find "$dir" -type d -name "$search" -maxdepth 10 2>/dev/null | head -n100 | sed -E 's#^\./##g')"
    fi
    
    local matchcount="$(echo -e "$dirset" | wc -l | xargs)"
    
    if [ "$dirset" ] && ds:is_int "$matchcount"; then
        if [ "$matchcount" -gt 1 ]; then
            echo 'Multiple matches found - select a directory:'
            
            while [ ! "$confirmed" ]; do
                echo -e "$dirset" | ds:index 1 -F: | ds:fit -v FS=: -v color=never
                
                while [ ! "$_matched_" ]; do
                    local choice="$(ds:readp 'Enter a number from the set of directories or a pattern:')"
                    if ds:is_int "$choice" && [[ $choice -gt 0 && $choice -le $matchcount ]]; then
                        local _matched_=0 _patt_=""
                    elif echo -e "$dirset" | grep -q "$choice"; then
                        local _matched_=0 _patt_='~'
                    else
                        echo "Unable to read selection, try again."
                        continue
                    fi
                done
                
                local dirset="$(echo -e "$dirset" | ds:reo "${_patt_}${choice}" off)"
                local matchcount="$(echo -e "$dirset" | wc -l | xargs)"
                ! ds:is_int "$matchcount" && ds:fail 'Unable to find a match with current args'
                [ "$matchcount" -gt 1 ] && unset _matched_ && continue
                local confirmed=0
            done
            
            local dirchoice="$dirset"
            [ -d "$dirchoice" ] && cd "$dirchoice" && return
        else
            [ -d "$dirset" ] && cd "$dirset" && return
        fi
    else
        local testdir=".." counter=1
        while [[ $counter -lt 7 && -d "$testdir" ]]; do
            if [ "$_FD" ]; then
                local dirmatch="$(fd --max-depth 1 -t d "$search" "$testdir" | head -n1)"
            elif [ "$_FDF" ]; then
                local dirmatch="$(fd-find --max-depth 1 -t d "$search" "$testdir" | head -n1)"
            else
                local dirmatch="$(find "$testdir" -type d -maxdepth 1 -not -path './.*' -name "*$search*" 2>/dev/null | head -n1)"
            fi

            [[ "$dirmatch" && -d "$dirmatch" ]] && cd "$dirmatch" && return
            local testdir="../$testdir"
            let local counter+=1
        done
        
        ds:fail 'Unable to find a match with current args'
    fi
}

ds:searchn() { # Search shell environment names: ds:searchn name
    ds:ndata | awk -v s="$1" '$2~s{print}'
}

ds:nset() { # Test name (function/alias/variable) is defined: ds:nset name [search_vars=f]
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
    local _sh="$(ds:sh)"
    clear
    if [[ "$_sh" =~ zsh ]]; then
        env -i zsh
    elif [[ "$_sh" =~ bash ]]; then
        env -i bash; fi
}

ds:cp() { # ** Copy standard input in UTF-8: data | ds:cp
    # TODO: Other copy utilities to handle case when pbcopy is not installed
    LC_CTYPE=UTF-8 pbcopy
}

ds:tmp() { # Shortcut for quiet mktemp: ds:tmp filename
    mktemp -q "/tmp/${1}.XXXXX"
}

ds:fail() { # Safe failure that kills parent: ds:fail [error_message]
    bash "$DS_SUPPORT/clean.sh"
    local shell="$(ds:sh)"
    if [[ "$shell" =~ "bash" ]]; then
        : "${_err_?$1}"
    else
        echo -e "\e[31;1m$1"
        : "${_err_?Operation intentionally failed by fail command}"
    fi
}

ds:pipe_check() { # ** Detect if pipe has data or over [n_lines]: data | ds:pipe_check [n_lines]
    local chkfile=$(ds:tmp 'ds_pipe_check')
    tee > $chkfile
    if [[ -z "$1" || $(! ds:is_int "$1") ]]; then
        test -s $chkfile
    else
        [ $(cat $chkfile | wc -l | xargs) -gt $1 ]
    fi
    local has_data=$?; cat $chkfile; rm $chkfile; return $has_data
}

ds:rev() { # ** Reverse lines from standard input: data | ds:rev
    local line
    if IFS= read -r line; then ds:rev; printf '%s\n' "$line"; fi
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

ds:substr() { # ** Extract a substring with regex: ds:substr str [leftanc] [rightanc]
    if ds:pipe_open; then
        local str="$(cat /dev/stdin)"
    else
        local str="$1"; shift
    fi
    [ -z "$str" ] && ds:fail 'Empty string detected - a string required for substring extraction'
    local leftanc="$1" rightanc="$2"

    if [ "$rightanc" ]; then
        [ -z "$leftanc" ] && local sedstr="s/$rightanc//" || local sedstr="s/$leftanc//;s/$rightanc//"
        local out="$(grep -Eho "$leftanc.*?[^\\]$rightanc" <<< "$str" | sed -E $sedstr)"
    elif [ "$leftanc" ]; then
        local sedstr="s/$leftanc//"
        local out="$(grep -Eho "$leftanc.*?[^\\]" <<< "$str" | sed -E $sedstr)"
    else
        out="$str"
     fi

    [ "$out" ] && printf "$out" || echo 'No string match to extract'
}

ds:iter() { # Repeat a string: ds:iter str [n=1] [fs]
    local str="$1" fs="$3" out="$1"
    let local n_repeats=${2:-1}-1 i=1
    for ((i=1;i<=$n_repeats;i++)); do local out="${out}${fs}${str}"; done
    echo -n "$out"
}

ds:embrace() { # Enclose a string on each side by args: embrace str [left={] [right=}]
    local val="$1"
    [ -z "$2" ] && local l="{" || local l="$2"
    [ -z "$3" ] && local r="}" || local r="$3"
    echo -n "${l}${val}${r}"
}

ds:filename_str() { # Add string to filename, preserving path: ds:filename_str file str [prepend|append|replace] [abs_path=t]
    read -r dirpath filename extension <<<$(ds:path_elements "$1")
    [ ! -d "$dirpath" ] && echo 'Filepath given is invalid' && return 1
    if [ "$dirpath" = "./" ]
    then
        dirpath=""
    fi
    local add="$2" position=${3:-append} abs_path="${4:-t}"
    [ "$abs_path" ] && ds:test '^t(rue)?$' "$abs_path" || local abs_path=""

    case "$position" in
        append)  filename="${filename}${add}${extension}" ;;
        prepend) filename="${add}${filename}${extension}" ;;
        replace) filename="${add}${extension}"            ;;
        *)       ds:help 'ds:filename_str'; return 1      ;;
    esac
    
    if [ "$abs_path" ]
    then
        printf "${dirpath}${filename}"
    else
        printf "${filename}"
    fi
}

ds:path_elements() { # Return dirname/filename/extension from filepath: ds:path_elements file
    local filepath="$1" dirpath=$(dirname "$1") filename=$(basename "$1")
    local extension=$([[ "$filename" = *.* ]] && echo ".${filename##*.}" || echo '')
    local filename="${filename%.*}"
    local out=( "$dirpath/" "$filename" "$extension" )
    printf '%s\t' "${out[@]}"
}

ds:src() { # Source a piece of shell code: ds:src file ["searchx" pattern] || [start end] || [search linesafter]
    local tmp=$(ds:tmp 'ds_src')
    ds:file_check "$1"; local file="$(ds:fd_check "$1")"
    
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
        return
    fi
    
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
        ds:is_int "$3" && local linesafter=(-A $3)
        source <(cat "$file" | grep "$pattern" ${linesafter[@]})
    else
        source "$file"
    fi
    :
}

ds:fsrc() { # Show the source of a shell function: ds:fsrc func
    local shell=$(ds:sh) tmp=$(ds:tmp 'ds_fsrc')
    
    if [[ $shell =~ bash ]]; then
        bash --debugger -c 'echo' &> /dev/null
        [ $? -eq 0 ] && \
            bash --debugger -c "source ~/.bashrc; declare -F $1" > $tmp
        if [ ! -s $tmp ]; then
            which "$1"
            rm $tmp
            return $?
        fi
        local sourcefile=$(awk '{for(i=1;i<=NF;i++)if(i>2)printf "%s",$i}' $tmp \
            2>/dev/null | head -n1)
        awk -v f="$sourcefile" '{ print f ":" $2 }' $tmp
    elif [[ $shell =~ zsh ]]; then
        local sourcefile="$(whence -v "$1" | grep -Eo 'from .+' | sed -E 's#^from ##g')"
        if [ ! -f "$sourcefile" ]
        then
            which "$1"
            rm $tmp
            return $?
        fi
        echo "$sourcefile:$(grep -En "$1 ?\(.*?\)" "$sourcefile" | ds:reo 1 1 -v FS=:)"
    fi

    ds:searchx "$sourcefile" "$1" q
    rm $tmp
}

ds:trace() { # Search shell trace for a pattern: ds:trace [command] [search] [strace] [strace_args]
    if [ -z "$1" ]; then
        local cmd="$(fc -ln -1)"
        [[ "\"$cmd\"" =~ 'ds:trace' ]] && return 1
        ds:readp 'Press enter to trace last command'
    else
        local cmd="$1"
        shift
    fi

    local search="$1" run_strace="$2"
    
    if [ -z "$run_strace" ]; then
        grep --color=always "$1" <(set -x &> /dev/null; eval "$cmd" 2>&1)
    else
        ds:nset 'strace' || ds:fail 'strace command not found! Run ds:trace without strace args.'
        local tmp=$(ds:tmp 'ds_trace') strace_args=("$DS_LOC" ${@:3})
        echo '#!/bin/bash' > $tmp
        echo 'source "$1/commands.sh"' >> $tmp
        echo "$cmd" >> $tmp
        grep --color=always "$search" <(strace -f $strace_args "$tmp")
        rm $tmp
    fi
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

ds:git_refresh() { # Pull latest for all repos, run installs (alias ds:grf): ds:grf [repos_dir=~]
    bash "$DS_SCRIPT/local_env_refresh.sh" ${@}
}
alias ds:grf="ds:git_refresh"

ds:git_checkout() { # Checkout branch matching pattern (alias ds:gco): ds:gco [branch_pattern] [new_branch=f]
    bash "$DS_SCRIPT/git_checkout.sh" ${@}
}
alias ds:gco="ds:git_checkout"

ds:git_squash() { # Squash last n commits (alias ds:gsq): ds:gsq [n_commits=1]
    ds:not_git && return 1
    local extent="${1:-1}"
    ! ds:is_int "$extent" && echo 'Squash commits to arg must be an integer' && ds:help ds:git_squash && return 1
    local conf="$(ds:readp "Are you sure you want to squash the last $extent commit(s) on current branch?

    Please confirm (y/n)")"
    [ ! "$conf" = y ] && echo 'No change made' && return 1
    let local extent=$extent+1
    git reset --soft HEAD~$extent
    git commit --edit -m"$(git log --format=%B --reverse HEAD..HEAD@{1})"
}
alias ds:gsq="ds:git_squash"

ds:git_time_stat() { # Last local pull+change+commit times (alias ds:gts): cd repo; ds:gts
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

ds:git_status() { # Run git status for all repos (alias ds:gs): ds:gs
    bash "$DS_SCRIPT/all_repo_git_status.sh" ${@}
}
alias ds:gs="ds:git_status"

ds:git_branch() { # Run git branch for all repos (alias ds:gb): ds:gb
    bash "$DS_SCRIPT/all_repo_git_branch.sh" ${@}
}
alias ds:gb="ds:git_branch"

ds:git_add_com_push() { # Add, commit with message, push (alias ds:gacp): ds:gacp commit_message [prompt=t]
    ds:not_git && return 1
    local commit_msg="$1" prompt="${2:-t}"
    
    if [ "$(ds:os)" = 'MacOSX' ]; then
        if fd --version &>/dev/null; then
            rm $(fd -t f --hidden '.DS_Store' 2>/dev/null) 2>/dev/null
        elif fd-find --version &>/dev/null; then
            rm $(fd-find -t f --hidden '.DS_Store' 2>/dev/null) 2>/dev/null
        else
            rm $(find . -name "\.DS_Store" -maxdepth 10 2>/dev/null) 2>/dev/null
        fi
    fi

    if ds:test '^t$' "$prompt"; then
        git status; echo
        local confirm="$(ds:readp 'Do you wish to proceed with add+commit+push? (y/n/new_commit_message)' f)"
        if [[ "$confirm" = n || "$confirm" = N ]]; then
            echo 'No add/commit/push made.'
            return
        elif [[ ! "$confirm" = y && ! "$confirm" = Y ]]; then
            local commit_msg="$confirm"
            local change_message_confirm="$(ds:readp "Change message to \"$commit_msg\" ? (y/n)")"
            if [ ! "$change_message_confirm" = y ]; then
                echo 'No add/commit/push made.'
                return
            fi
        fi
    fi
    
    git add "$(git rev-parse --show-toplevel)"
    
    if [ "$commit_msg" ]; then
        git commit -am "$commit_msg"
    else
        git commit
    fi
    
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null; then
        git push --set-upstream origin "$(git rev-parse --abbrev-ref HEAD)"
        echo -e "\nSet a new upstream branch for current branch."
    else
        git push
    fi
}
alias ds:gacp="ds:git_add_com_push"

ds:git_recent() { # Display commits sorted by recency (alias ds:gr): ds:gr [refs=heads] [run_context=display]
    ds:not_git && return 1
    local refs="${1:-heads}" run_context="${2:-display}"
    if [ "$run_context" = display ]; then
        local format='%(color:white)%(HEAD) %(color:bold yellow)%(refname:short)@@@%(color:bold green)%(committerdate:relative)@@@%(color:blue)%(subject)@@@%(color:magenta)%(authorname)%(color:reset)'
        git for-each-ref --sort=-committerdate refs/"$refs" \
              --format="$format" --color=always | ds:fit -F"$DS_SEP" -v color=never
    else
        # If not for immediate display, return extra field for further parsing
        local format='%(color:white)%(HEAD) %(color:bold yellow)%(refname:short)@@@%(committerdate:short)@@@%(color:bold green)%(committerdate:relative)@@@%(color:cyan)%(objectname:short)@@@%(color:blue)%(subject)@@@%(color:magenta)%(authorname)%(color:reset)'
        git for-each-ref refs/$refs --format="$format" --color=always
    fi
}
alias ds:gr="ds:git_recent"

ds:git_recent_all() { # Display recent commits for local repos (alias ds:gra): ds:gra [refs=heads] [repos_dir=~]
    local start_dir="$PWD" all_recent=$(ds:tmp 'ds_git_recent_all')
    local w="\033[37;1m" nc="\033[0m"
    local refs="$1"
    [ -d "$2" ] && cd "$2" || cd ~
    echo -e "${w}repo@@@   ${w}branch@@@sortfield@@@${w}commit time@@@${w}hash@@@${w}commit message@@@${w}author${nc}" > $all_recent
    
    while IFS=$'\n' read -r dir; do
        [ -d "${dir}/.git" ] && \
            (cd "$dir" &>/dev/null 3>/dev/null 4>/dev/null 5>/dev/null 6>/dev/null && \
                (ds:git_recent "$refs" parse | awk -v repo="$dir" -F"$DS_SEP" '
                    {print "\033[1;31m" repo "@@@", $0}') >> $all_recent)
    done < <(find * -maxdepth 0 -type d)
    
    echo
    ds:sortm $all_recent -v order=d -F"$DS_SEP" -v k=3 2>/dev/null \
        | ds:reo "a" "NF!=3" -F"$DS_SEP" -v OFS="$DS_SEP" | ds:ttyf "$DS_SEP" "" -v color=never
    
    local stts=$?
    echo; rm $all_recent; cd "$start_dir"; return $stts
}
alias ds:gra="ds:git_recent_all"

ds:git_graph() { # Print colorful git history graph (alias ds:gg): ds:gg
    ds:not_git && return 1
    git log --all --decorate --oneline --graph
}
alias ds:gg="ds:git_graph"

ds:git_diff() { # Diff shortcut for exclusions: ds:git_diff obj obj exclusions
    if [ -f "$1" ]; then
        git diff $@
    else
        local from_object="$1" to_object="$2" FILE_EXCLUSIONS=()
        if [[ -z "$from_object" || -z "$to_object" ]]; then
            echo "Missing commit or branch objects"
            return 1
        fi
        shift 2
        while [ ! -z "$1" ]; do
            local FILE_EXCLUSIONS=(${FILE_EXCLUSIONS[@]} ":(exclude)$1")
            shift
        done
        echo "git diff \"$from_object\" \"$to_object\" -b $@ -- . ${FILE_EXCLUSIONS[@]}"
        git diff "$from_object" "$to_object" -b $@ -- . ${FILE_EXCLUSIONS[@]}
    fi
}

ds:todo() { # List todo items found in paths: ds:todo [searchpaths=.]
    ds:nset 'rg' && local RG=true
    local re='(TODO|FIXME|(^|[^X])XXX)( |:|\-)'
    if [ -z "$1" ]; then
        [ "$RG" ] && rg -His "$re" || grep -Eirs "$re" --color=always .
        echo
    else
        local search_paths=( "${@}" )
        for search_path in ${search_paths[@]} ; do
            if [[ ! -d "$search_path" && ! -f "$search_path" ]]; then
                echo "$search_path is not a file or directory or is not found"
                local bad_dir=0
                continue
            fi
            [ "$RG" ] && rg -His "$re" "$search_path" \
                || grep -Eirs "$re" --color=always "$search_path"
            echo
        done
    fi
    [ -z $bad_dir ] || (echo 'Some paths provided could not be searched' && return 1)
}

ds:searchx() { # Search for a C-lang/curly-brace object: ds:searchx file|dir [search] [q] [multilevel]
    if [[ -d "$1" && "$2" ]]; then
        local tmp="$(ds:tmp 'ds_searchx')" w="\033[37;1m" nc="\033[0m"
        if ds:nset 'rg'; then
            rg --files-with-matches "$2" "$1" 2>/dev/null > $tmp
        else
            grep -Er --files-with-matches "$2" "$1" 2>/dev/null > $tmp
        fi
        
        for fl in $(cat $tmp); do
            if [ -f "$fl" ] && grep -q '{' "$fl" 2>/dev/null; then
                echo -e "\n${w}${fl}${nc}"
                ds:searchx "$fl" "$2" "$3" "$4"; fi; done
        
        local stts=$?
        rm $tmp
        return $stts
    fi
    
    ds:file_check "$1"
    
    if ds:test '^q$' "$3"; then
        if [ "$2" ]; then
            awk -f "$DS_SCRIPT/top_curly.awk" -v search="$2" "$1" 2>/dev/null && return
        else
            awk -f "$DS_SCRIPT/top_curly.awk" "$1" 2>/dev/null && return
        fi
    else 
        if [ "$2" ]; then
            if [ "$4" ]; then
                awk -f "$DS_SCRIPT/curlies.awk" -v search="$2" "$1" 2>/dev/null | ds:pipe_check
            else
                awk -f "$DS_SCRIPT/top_curly.awk" -v search="$2" "$1" 2>/dev/null | ds:pipe_check; fi
        else
            if [ "$4" ]; then
                awk -f "$DS_SCRIPT/curlies.awk" "$1" 2>/dev/null | ds:pipe_check
            else
                awk -f "$DS_SCRIPT/top_curly.awk" "$1" 2>/dev/null | ds:pipe_check; fi; fi; fi
  
    # TODO: Add variable search
}

ds:select() { # ** Select code by regex anchors: ds:select file [startpattern endpattern]
    if ds:pipe_open; then
        local file=$(ds:tmp 'ds_select') piped=0 start="$2" end="$3"
        cat /dev/stdin > $file
    else
        ds:file_check "$1"
        local file="$1" start="$2" end="$3"
    fi
    awk "/$start/,/$end/{print}" "$file" 2>/dev/null
    ds:pipe_clean $file
}

ds:insert() { # ** Redirect input into a file at lineno or pattern: ds:insert file [lineno|pattern] [srcfile] [inplace=f]
    if ds:pipe_open; then
        local _source=$(ds:tmp 'ds_selectsource') piped=0
        cat /dev/stdin > $_source
    else
        local _source=$(ds:tmp 'ds_selectsource')
        if [ -f "$3" ]; then
            cat "$3" > $_source
        elif [ "$3" ]; then
            echo "$3" > $_source
        else
            rm $_source; ds:fail 'Insertion source not provided'
        fi
    fi

    ds:file_check "$1" t
    local sink="$1" where="$2" _inplace="${4:f}"

    if ds:test '$t(rue)?$' "$inplace"; then
        _tmp=$(ds:tmp 'ds_select')
    else
        unset _inplace
    fi

    local nsinklines=$(cat $sink | grep -c .)
    let local nsinklines+=500

    if ds:is_int "$_where"; then
        [ "$_where" -le "$nsinklines" ] || ds:fail 'Insertion line number must be less than or equal to sink file lines + 500'
        local lineno="$_where"
    elif [ "$_where" ]; then
        local pattern="$_where"
        if [ $(grep -c "$pattern" "$sink") -gt 1 ]; then
            local conftext='File contains multiple instaces of pattern - are you sure you want to proceed? (y|n)'
            local confirm="$(ds:readp "$conftext")"
            [ "$confirm" != "y" ] && rm $_source $_tmp && echo 'Exit with no insertion' && return 1
        fi
    else
        rm $_source $tmp; ds:fail 'Insertion point not provided or invalid'
    fi

    if [ "$_inplace" ]; then
        awk -v lineno=$lineno -v pattern="$pattern" -f "$DS_SCRIPT/insert.awk" \
            "$sink" $_source 2>/dev/null > $_tmp
        cat $_tmp > "$sink"
    else
        awk -v lineno=$lineno -v pattern="$pattern" -f "$DS_SCRIPT/insert.awk" \
            "$sink" $_source 2>/dev/null
    fi
    rm $_source
}

ds:field_replace() { # ** Overwrite field val if matches pattern: ds:field_replace [file] val_replace_func [key=1] [pattern=]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_field_replace') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1" t
        local _file="$1"
        shift
    fi

    local replacement_func="$1" key="${2:-1}" pattern="$3"
    ds:is_int "$key" || ds:fail "Invalid key provided: $key"
    if [[ "$replacement_func" =~ rand ]]; then
        local prg="BEGIN{\"date +%s%3N\" | getline date; srand(date)}{n_rand = rand()}"
    else
        local prg=""
    fi
    local prg="${prg}{if (\$$key ~ \"$pattern\") { val = \$$key; \$$key = $replacement_func }; print}"
    local fs="$(ds:inferfs "$_file" true)"
    awk -v FS="$fs" -v OFS="$fs" "$prg" "$_file" | ds:ttyf "$fs"
    ds:pipe_clean "$_file"
}

ds:space() { # ** Modify file space or tab counts: ds:space [file] from=$'\t' target=4
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_space') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1" t
        local _file="$1"
        shift
    fi
    
    local _from="${1:-2}" _target="${2:-4}"
    [ "$_from" = "$_target" ] && ds:fail "From and target spaces are the same."
    if [ "$_from" = $'\t' ]; then
        local base_space="$_from"
    else
        ds:is_int "$_from" || ds:fail "Non-integer value for from spaces: \"$_from\""
        local base_space="$(ds:iter " " "$_from" "")"
    fi
    if [ "$_target" = $'\t' ]; then
        local target_space="$_target"
    else
        ds:is_int "$_target" || ds:fail "Non-integer value for target spaces: \"$_target\""
        local target_space="$(ds:iter " " "$_target" "")"
    fi
    let local i=0

    if [[ $_from -gt $_target || ($_from = $'\t' && $_target -le 4) || ($_target = $'\t' && $_from -ge 4) ]]; then
        for ((i=0; i<13; i++)); do
            local search="^$(ds:iter "$base_space" $i "")(\\S)"
            local replace="$(ds:iter "$target_space" $i "")\\1"
            ds:sedi "$_file" "$search" "$replace"
        done
    else
        for ((i=12; i>0; i--)); do
            local search="^$(ds:iter "$base_space" $i "")(\\S)"
            local replace="$(ds:iter "$target_space" $i "")\\1"
            ds:sedi "$_file" "$search" "$replace"
        done
    fi

    if [ "$piped" ]; then
        cat "$_file"
    fi
    ds:pipe_clean "$_file"
}

ds:shape() { # ** Print data shape by length or pattern: ds:shape [-h|file*] [patterns] [fields] [chart_size=15ln] [awkargs]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_shape') piped=0
        cat /dev/stdin > $_file
    else
        ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/shape.awk" \
          | tr -d "#" | less && return
        if [[ -f "$2" && -f "$1" ]]; then
            local w="\033[37;1m" nc="\033[0m"
            while [ -f "$1" ]; do
                local fls=("${fls[@]}" "$1")
                shift
            done
            for fl in ${fls[@]}; do
                echo -e "\n${w}${fl}${nc}"
                [ -f "$fl" ] && ds:shape "$fl" $@
            done
            return $?
        else
            local tmp=$(ds:tmp 'ds_shape')
            ds:file_check "$1" f f t > $tmp
            local _file="$(ds:fd_check "$(cat $tmp; rm $tmp)")"
            shift
        fi
    fi

    local _lines=$(cat "$_file" | wc -l | xargs)
    [ $_lines = 0 ] && return 1
    if [ "$1" ]; then local measures="$1"; shift; fi
    if [ "$1" ]; then
        local fields="$1"; shift
        if [ "$fields" != 0 ]; then
            fstmp=$(ds:tmp 'ds_extractfs')
            ds:extractfs > $fstmp
            local fs="$(cat $fstmp; rm $fstmp)"
        fi
    fi
    if [ "$1" ]; then
        if ds:is_int "$1"; then
            [ "$1" = 0 ] && local _simple=1 || local _printlns=$1
        else
            local _simple=1
        fi
        shift
    fi
    local _printlns=${_printlns:-15}
    let local _span=$_lines/$_printlns

    awk -v FS="${fs:- }" -v measures="$measures" -v fields="$fields" -v span=${_span:-15} \
        -v tty_size="$(tput cols)" -v lines="$_lines" -v simple="$_simple" \
        -f "$DS_SUPPORT/utils.awk" $@ -f "$DS_SCRIPT/shape.awk" "$_file" 2>/dev/null

    ds:pipe_clean $_file
}

ds:diff_fields() { # ** Get elementwise diff of two datasets (alias ds:df): ds:df file [file*] [op=-] [exc_fields=0] [prefield=f] [awkargs]
    if ds:pipe_open; then
        local f2=$(ds:tmp 'ds_diff_fields') piped=1
        cat /dev/stdin > $f2
        ds:file_check "$1"
        local f1="$1"
        shift
    else
        ds:test "(^| )(-h|--help)" "$1" && grep -E "^#( |$)" "$DS_SCRIPT/diff_fields.awk" \
            | sed -E 's:^#::g' | less && return
        ds:file_check "$1"
        local f1="$(ds:fd_check "$1")"
        shift
        ds:file_check "$1"
        local f2="$(ds:fd_check "$1")"
        shift
    fi

    local arr_base=$(ds:arr_base)

    if [ -f "$1" ]; then
        local ext_tmp=$(ds:tmp 'ds_diff_fields_ext') ext_jnf=("$f1" "$f2")
        while [ -f "$1" ]; do
            local ext_jnf=(${ext_jnf[@]} "$1")
            shift
        done
        let local ext_f=${#ext_jnf[@]}-1+$arr_base
    fi

    if [ "$1" ]; then
        if [ "$1" = '-' ]; then
            local op="$1" && shift
        else
            ds:test '^[\+\-\%\/\*]$' "$1" && local op="$1" && shift
        fi
    else
        local op="-"
    fi

    if [ "$1" ] && ! ds:test '^-' "$1"; then
        local exclude_fields="${1:-0}" && shift
    else
        local exclude_fields=0
    fi
    
    local args=( "$@" -v "exclude_fields=$exclude_fields" )
    [ "$op" ] && local args=("${args[@]}" -v "op=$op")

    if ds:noawkfs; then
        local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"
    else
        local fs_i="$(ds:arr_idx '^FS=' ${args[@]})"
        if [ "$fs_i" = "" ]; then
            local fs_i="$(ds:arr_idx '^-F' ${args[@]})"
            if [ "$fs_i" ]; then
                local fs1="$(echo "${args[$fs_i]}" | tr -d '\-F')"
            fi
        else
            local fs1="$(echo "${args[$fs_i]}" | tr -d 'FS=')"
            let local fsv_i=$fs_i-1
            unset "args[$fsv_i]"
        fi
        [ "$fs_i" ] && unset "args[$fs_i]"
        if ! ds:noawkfs; then
            local fs1_i="$(ds:arr_idx '^fs1=' ${args[@]})"
            local fs2_i="$(ds:arr_idx '^fs2=' ${args[@]})"
            if [ "$fs1_i" ]; then
                echo $fs1_i ${args[$fs1_i]}
                local fs1="$(echo "${args[$fs1_i]}" | tr -d 'fs1=')"
                unset "args[$fs1_i]"
                let local fs1v_i=$fs1_i-1
                [ "$fs1v_i" ] && unset "args[$fs1v_i]"
            fi
            if [ "$fs2_i" ]; then
                local fs2="$(echo "${args[$fs2_i]}" | tr -d 'fs2=')"
                unset "args[$fs2_i]"
                let local fs2v_i=$fs2_i-1
                [ "$fs2v_i" ] && unset "args[$fs2v_i]"
            fi
        fi
    fi
    [ ! "$fs2" ] && local fs2="$fs1"

    if ds:test 't(rue)?' "$args[$arr_base]"; then
        local pf1=$(ds:tmp "ds_diff_field_prefield1") pf2=$(ds:tmp "ds_diff_field_prefield2")
        ds:prefield "$f1" "$fs1" > $pf1
        ds:prefield "$f2" "$fs2" > $pf2

        if [ "$ext_f" ]; then
            let local file_anc=$arr_base+1
            while [ "$ext_f" -ge "$file_anc" ]
            do
              let local file_anc+=1
              awk -v FS="$DS_SEP" -v OFS="$fs1" ${args[@]} -f "$DS_SUPPORT/utils.awk" \
                  -f "$DS_SCRIPT/diff_fields.awk" $pf1 $pf2 2>/dev/null > $ext_tmp
              ds:prefield "$ext_tmp" "$fs1" > $pf1
              ds:prefield "${ext_jnf[$file_anc]}" "$fs1" > $pf2
            done
            cat $ext_tmp | ds:ttyf "$fs1"; rm $ext_tmp; unset "ext_f"
        else
            awk -v FS="$DS_SEP" -v OFS="$fs1" -v left_label="$f1" -v right_label="$f2" \
                -v piped=$piped ${args[@]} -f "$DS_SUPPORT/utils.awk" \
                -f "$DS_SCRIPT/diff_fields.awk" $pf1 $pf2 2>/dev/null \
                | ds:ttyf "$fs1"
        fi
    else
        ! ds:test '(-|=)' "${args[$arr_base]}" && local args=("${args[@]:1}")
        if [ "$ext_f" ]; then
            let local file_anc=$arr_base+1
            local ext_tmp1=$(ds:tmp 'ds_diff_fields_ext1')
            awk -v fs1="$fs1" -v fs2="$fs2" -v OFS="$fs1" ${args[@]} -f "$DS_SUPPORT/utils.awk" \
                -f "$DS_SCRIPT/diff_fields.awk" "$f1" "$f2" 2>/dev/null > $ext_tmp1
            while [ "$ext_f" -gt "$file_anc" ]
            do
                let local file_anc+=1
                awk -v fs1="$fs1" -v fs2="$fs2" -v OFS="$fs1" ${args[@]} \
                    -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/diff_fields.awk" \
                    $ext_tmp1 "${ext_jnf[$file_anc]}" 2>/dev/null > $ext_tmp
                cat $ext_tmp > $ext_tmp1
            done
            cat $ext_tmp | ds:ttyf "$fs1"; rm $ext_tmp $ext_tmp1; unset "ext_f"
        else
            awk -v fs1="$fs1" -v fs2="$fs2" -v OFS="$fs1" -v piped=$piped ${args[@]} \
                -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/diff_fields.awk" "$f1" "$f2" \
                2>/dev/null | ds:ttyf "$fs1"
        fi
    fi

    ds:pipe_clean $f2
    if [ "$pf1" ]; then rm $pf1 $pf2; fi
}
alias ds:df="ds:diff_fields"

ds:join() { # ** Join two datasets with any keyset (alias ds:jn): ds:join file [file*] [jointype] [k|merge] [k2] [prefield=f] [awkargs]
    if ds:pipe_open; then
        local f2=$(ds:tmp 'ds_jn') piped=1
        cat /dev/stdin > $f2
        ds:file_check "$1"
        local f1="$1"
        shift
    else
        ds:test "(^| )(-h|--help)" "$1" && grep -E "^#( |$)" "$DS_SCRIPT/join.awk" \
            | sed -E 's:^#::g' | less && return
        ds:file_check "$1"
        local f1="$(ds:fd_check "$1")"
        shift
        ds:file_check "$1"
        local f2="$(ds:fd_check "$1")"
        shift
    fi

    local arr_base=$(ds:arr_base)

    if [ -f "$1" ]; then
        local ext_tmp=$(ds:tmp 'ds_jn_ext') ext_jnf=("$f1" "$f2")
        while [ -f "$1" ]; do
            local ext_jnf=(${ext_jnf[@]} "$1")
            shift
        done
        let local ext_f=${#ext_jnf[@]}-1+$arr_base
    fi

    if [ "$1" ]; then
        if ds:test '^d' "$1"; then local type='diff'
        elif ds:test '^i' "$1"; then local type='inner'
        elif ds:test '^l' "$1"; then local type='left'
        elif ds:test '^r' "$1"; then local type='right'
        fi
        [[ ! "$1" =~ '-' ]] && ! ds:is_int "$1" && shift
    fi

    local merge=$(ds:arr_idx 'merge' ${@})
    local has_keyarg=$(ds:arr_idx 'k[12]?=' ${@})

    if [[ "$merge" = "" && "$has_keyarg" = "" ]]; then
        if ds:is_int "$1"; then
            local k="$1"
            shift
            ds:is_int "$1" && local k1="$k" k2="$1" && shift
        elif [ -z "$1" ] || ds:test '^-' "$1"; then
            local k="$(ds:inferk "$f1" "$f2")"
            [[ "$k" =~ " " ]] && local k2="$(ds:substr "$k" " " "")" k1="$(ds:substr "$k" "" " ")"
        else
            local k="$1"
            shift
            if [ "$1" ] && ! ds:test '^-' "$1"; then
                local k1="$k" k2="$1" && shift
            fi
            if [[ $arr_base = 0 && -t 1 && ("$k" =~ " " || "$k2" =~ " ") ]]; then
                echo "WARNING: Bash does not handle args with spaces well. Your implementation may require no spaces in key args to function correctly."
            fi
        fi
        local args=( "$@" )
        [ "$k2" ] && local args=("${args[@]}" -v "k1=$k1" -v "k2=$k2") || local args=("${args[@]}" -v "k=$k")
    else
        local args=( "$@" )
    fi

    [ "$merge" ] && local args=("${args[@]:1}" -v 'merge=1')
    [ "$type" ] && local args=("${args[@]}" -v "join=$type")

    if ds:noawkfs; then
        local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"
    else
        local fs_i="$(ds:arr_idx '^FS=' ${args[@]})"
        if [ "$fs_i" = "" ]; then
            local fs_i="$(ds:arr_idx '^-F' ${args[@]})"
            if [ "$fs_i" ]; then
                local fs1="$(echo "${args[$fs_i]}" | tr -d '\-F')"
            fi
        else
            local fs1="$(echo "${args[$fs_i]}" | tr -d 'FS=')"
            let local fsv_i=$fs_i-1
            unset "args[$fsv_i]"
        fi
        [ "$fs_i" ] && unset "args[$fs_i]"
        if ! ds:noawkfs; then
            local fs1_i="$(ds:arr_idx '^fs1=' ${args[@]})"
            local fs2_i="$(ds:arr_idx '^fs2=' ${args[@]})"
            if [ "$fs1_i" ]; then
                echo $fs1_i ${args[$fs1_i]}
                local fs1="$(echo "${args[$fs1_i]}" | tr -d 'fs1=')"
                unset "args[$fs1_i]"
                let local fs1v_i=$fs1_i-1
                [ "$fs1v_i" ] && unset "args[$fs1v_i]"
            fi
            if [ "$fs2_i" ]; then
                local fs2="$(echo "${args[$fs2_i]}" | tr -d 'fs2=')"
                unset "args[$fs2_i]"
                let local fs2v_i=$fs2_i-1
                [ "$fs2v_i" ] && unset "args[$fs2v_i]"
            fi
        fi
    fi
    [ ! "$fs2" ] && local fs2="$fs1"

    if ds:test 't(rue)?' "$args[$arr_base]"; then
        local pf1=$(ds:tmp "ds_jn_prefield1") pf2=$(ds:tmp "ds_jn_prefield2")
        ds:prefield "$f1" "$fs1" > $pf1
        ds:prefield "$f2" "$fs2" > $pf2

        if [ "$ext_f" ]; then
            let local file_anc=$arr_base+1
            while [ "$ext_f" -ge "$file_anc" ]
            do
              let local file_anc+=1
              awk -v FS="$DS_SEP" -v OFS="$fs1" ${args[@]} -f "$DS_SUPPORT/utils.awk" \
                  -f "$DS_SCRIPT/join.awk" $pf1 $pf2 2>/dev/null > $ext_tmp
              ds:prefield "$ext_tmp" "$fs1" > $pf1
              ds:prefield "${ext_jnf[$file_anc]}" "$fs1" > $pf2
            done
            cat $ext_tmp | ds:ttyf "$fs1"; rm $ext_tmp; unset "ext_f"
        else
            awk -v FS="$DS_SEP" -v OFS="$fs1" -v left_label="$f1" -v right_label="$f2" \
                -v piped=$piped ${args[@]} -f "$DS_SUPPORT/utils.awk" \
                -f "$DS_SCRIPT/join.awk" $pf1 $pf2 2>/dev/null \
                | ds:ttyf "$fs1"
        fi
    else
        ! ds:test '(-|=)' "${args[$arr_base]}" && local args=("${args[@]:1}")
        if [ "$ext_f" ]; then
            let local file_anc=$arr_base+1
            local ext_tmp1=$(ds:tmp 'ds_jn_ext1')
            awk -v fs1="$fs1" -v fs2="$fs2" -v OFS="$fs1" ${args[@]} -f "$DS_SUPPORT/utils.awk" \
                -f "$DS_SCRIPT/join.awk" "$f1" "$f2" 2>/dev/null > $ext_tmp1
            while [ "$ext_f" -gt "$file_anc" ]
            do
                let local file_anc+=1
                awk -v fs1="$fs1" -v fs2="$fs2" -v OFS="$fs1" ${args[@]} -f "$DS_SUPPORT/utils.awk" \
                    -f "$DS_SCRIPT/join.awk" $ext_tmp1 "${ext_jnf[$file_anc]}" 2>/dev/null > $ext_tmp
                cat $ext_tmp > $ext_tmp1
            done
            cat $ext_tmp | ds:ttyf "$fs1"; rm $ext_tmp $ext_tmp1; unset "ext_f"
        else
            awk -v fs1="$fs1" -v fs2="$fs2" -v OFS="$fs1" -v piped=$piped ${args[@]} \
                -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/join.awk" "$f1" "$f2" 2>/dev/null \
                | ds:ttyf "$fs1"
        fi
    fi

    ds:pipe_clean $f2
    if [ "$pf1" ]; then rm $pf1 $pf2; fi
}
alias ds:jn="ds:join"

ds:matches() { # ** Get match lines from two datasets: ds:matches file [file] [awkargs]
    ds:file_check "$1"
    local f1="$(ds:fd_check "$1")"; shift
    if ds:pipe_open; then
        local f2=$(ds:tmp 'ds_matches') piped=1
        cat /dev/stdin > "$f2"
    else
        ds:file_check "$1"
        local f2="$(ds:fd_check "$1")"; shift
    fi
    [ "$f1" = "$f2" ] && echo 'Files are the same!' && return
    local args=( "$@" )
    if ds:noawkfs; then
        local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"
        awk -v fs1="$fs1" -v fs2="$fs2" -v piped=$piped ${args[@]} \
            -f "$DS_SCRIPT/matches.awk" "$f1" "$f2" 2>/dev/null | ds:ttyf "$fs1" -v color=never
    else
        awk -v piped=$piped ${args[@]} -f "$DS_SCRIPT/matches.awk" "$f1" "$f2" \
            2>/dev/null | ds:ttyf
    fi
    ds:pipe_clean $f2
}

ds:comps() { # ** Get non-matching lines from two datasets: ds:comps file [file] [awkargs]
    ds:file_check "$1"
    local f1="$(ds:fd_check "$1")"; shift
    if ds:pipe_open; then
        local f2=$(ds:tmp 'ds_comps') piped=1
        cat /dev/stdin > "$f2"
    else
        ds:file_check "$(ds:fd_check "$1")"
        local f2="$1"; shift
    fi
    [ "$f1" = "$f2" ] && echo 'Files are the same!' && return 1
    local args=( "$@" )
    if ds:noawkfs; then
        local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"
        awk -v fs1="$fs1" -v fs2="$fs2" -v piped=$piped ${args[@]} \
            -f "$DS_SCRIPT/complements.awk" "$f1" "$f2" 2>/dev/null | ds:ttyf "$fs1" -v color=never
    else
        awk -v piped=$piped ${args[@]} -f "$DS_SCRIPT/complements.awk" "$f1" "$f2" \
            2>/dev/null | ds:ttyf
    fi
    ds:pipe_clean $f2
}

ds:inferh() { # Infer if headers present in a file: ds:inferh file [awkargs]
    ds:file_check "$1"
    local file="$(ds:fd_check "$1")"; shift
    local args=( "$@" )
    if ds:noawkfs; then
        local fs="$(ds:inferfs "$file" true)"
        awk ${args[@]} -v FS="$fs" -f "$DS_SCRIPT/infer_headers.awk" "$file" 2>/dev/null
    else
        awk ${args[@]} -f "$DS_SCRIPT/infer_headers.awk" "$file" 2>/dev/null
    fi
}

ds:inferk() { # Infer join fields in two text data files: ds:inferk file1 file2 [awkargs]
    ds:file_check "$1"
    local f1="$(ds:fd_check "$1")"; shift
    ds:file_check "$1"
    local f2="$(ds:fd_check "$1")"; shift
    local args=( "$@" )
    if ds:noawkfs; then
        local fs1="$(ds:inferfs "$f1" true)" fs2="$(ds:inferfs "$f2" true)"
        awk -v fs1="$fs1" -v fs2="$fs2" ${args[@]} -f "$DS_SCRIPT/infer_join_fields.awk" \
            "$f1" "$f2" 2>/dev/null
    else
        awk ${args[@]} -f "$DS_SCRIPT/infer_join_fields.awk" "$f1" "$f2" 2>/dev/null
    fi
}

ds:inferfs() { # Infer field separator from data: ds:inferfs file [reparse=f] [custom=t] [file_ext=t] [high_cert=f]
    ds:file_check "$1"
    local file="$(ds:fd_check "$1")" reparse="${2:-f}" custom="${3:-t}" file_ext="${4:-true}" hc="${5:-f}"

    if [ "$file_ext" = true ]; then
        read -r dirpath filename extension <<<$(ds:path_elements "$file")
        if [ "$extension" ]; then
            [ ".csv" = "$extension" ] && echo ',' && return
            [ ".tsv" = "$extension" ] && echo "\t" && return
            [ ".properties" = "$extension" ] && echo "=" && return
        fi
    fi

    ds:test '^t(rue)?$' "$custom" || custom=""
    ds:test '^t(rue)?$' "$hc" || hc=""

    if [ "$reparse" = true ]; then
        awk -f "$DS_SCRIPT/infer_field_separator.awk" -v high_certainty="$hc" \
            -v custom="$custom" "$file" 2>/dev/null | sed 's/\\/\\\\\\/g'
    else
        awk -f "$DS_SCRIPT/infer_field_separator.awk" -v high_certainty="$hc" \
            -v custom="$custom" "$file" 2>/dev/null; fi
}

ds:fit() { # ** Fit fielded data in columns with dynamic width: ds:fit [-h|file*] [prefield=t] [awkargs]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_fit') piped=0 hc=f
        cat /dev/stdin > $_file
    else
        ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/fit_columns.awk" \
            | tr -d "#" | less && return
        if [[ -f "$2" && -f "$1" ]]; then
            local w="\033[37;1m" nc="\033[0m"
            while [ -f "$1" ]; do
                local fls=("${fls[@]}" "$1")
                shift
            done
            for fl in ${fls[@]}; do
                echo -e "\n${w}${fl}${nc}"
                [ -f "$fl" ] && ds:fit "$fl" $@
            done
            return $?
        else
            ds:file_check "$1"
            local _file="$(ds:fd_check "$1")" hc=true
            shift
        fi
    fi

    if ds:test '(f(alse)?|off)' "$1"; then
        local pf_off=0
        shift
    else
        local prefield=$(ds:tmp "ds_fit_prefield")
    fi
    local args=( "$@" ) buffer=${DS_FIT_BUFFER:-2} tty_size=$(tput cols) fstmp=$(ds:tmp 'ds_extractfs')
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"
    ds:awksafe && local args=( ${args[@]} -v awksafe=1 -f "$DS_SUPPORT/wcwidth.awk" )

    if [ "$pf_off" ]; then
        awk -v FS="$fs" -v OFS="$fs" -v tty_size=$tty_size -v buffer="$buffer" -v file="$_file" \
            ${args[@]} -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/fit_columns.awk" $_file{,} 2>/dev/null
    else
        ds:prefield "$_file" "$fs" 0 > $prefield
        awk -v FS="$DS_SEP" -v OFS="$fs" -v tty_size=$tty_size -v buffer="$buffer" -v file="$_file" \
            ${args[@]} -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/fit_columns.awk" $prefield{,} 2>/dev/null
        rm $prefield
    fi

    ds:pipe_clean $_file
}

ds:stagger() { # ** Print tabular data in staggered rows: ds:stagger [file] [stag_size]
    ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/stagger.awk" \
        | sed -E 's:^#::g' | less && return
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_stagger') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"; shift
    fi
    ds:is_int "$1" && local stag_size=$1 && shift
    local args=( "$@" ) tty_size=$(tput cols)

    if ds:noawkfs; then
        local fs="$(ds:inferfs "$_file" true)"
        awk -v FS="$fs" ${args[@]} -v tty_size=$tty_size -v stag_size=$stag_size \
            -f "$DS_SCRIPT/stagger.awk" "$_file" 2>/dev/null
    else
        awk ${args[@]} -v tty_size=$tty_size -v stag_size=$stag_size \
            -f "$DS_SCRIPT/stagger.awk" "$_file" 2>/dev/null; fi

    ds:pipe_clean $_file
}

ds:index() { # ** Attach an index to lines from a file or STDIN (alias ds:i): ds:i [file] [startline=1]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_idx') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi
    local args=( "${@:2}" )
    [ -t 1 ] || local pipe_out=1
    
    # TODO: Replace with consistent fs logic
    if ds:noawkfs; then
        local fs="$(ds:inferfs "$_file" true)"
        awk -v FS="$fs" ${args[@]} -v header="${1:-1}" -v pipeout="$pipe_out" \
            -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/index.awk" "$_file" 2>/dev/null
    else
        awk ${args[@]} -v header="${1:-1}" -v pipeout="$pipe_out" \
            -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/index.awk" "$_file" 2>/dev/null; fi
    ds:pipe_clean $_file
}
alias ds:i="ds:index"

ds:reo() { # ** Reorder/repeat/slice data by rows and cols: ds:reo [-h|file*] [rows] [cols] [prefield=t] [awkargs]
    if ds:pipe_open; then
        local rows="${1:-a}" cols="${2:-a}" base=3
        local _file=$(ds:tmp "ds_reo") piped=0
        cat /dev/stdin > $_file
    else
        ds:test "(^| )(-h|--help)" "$1" && grep -E "^#( |$)" "$DS_SCRIPT/reorder.awk" \
            | sed -E 's:^#::g' | less && return
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
            ds:file_check "$1" f f t > $tmp
            local _file="$(ds:fd_check "$(cat $tmp; rm $tmp)")" rows="${2:-a}" cols="${3:-a}" base=4
        fi
    fi

    local arr_base=$(ds:arr_base) args=("${@:$base}") fstmp=$(ds:tmp 'ds_extractfs')
    if [ "$cols" = 'off' ] || $(ds:test "f(alse)?" "${args[$arr_base]}"); then
        local pf_off=0 args=( "${args[@]:1}" )
        [ "$cols" = 'off' ] && local run_fit='f'
    else
        local prefield=$(ds:tmp "ds_reo_prefield")
    fi
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"

    if [ "$pf_off" ]; then
        awk -v FS="$fs" -v OFS="$fs" -v r="$rows" -v c="$cols" ${args[@]} -f "$DS_SUPPORT/utils.awk" \
            -f "$DS_SCRIPT/reorder.awk" "$_file" 2>/dev/null | ds:ttyf "$fs" "$run_fit"
    else
        ds:prefield "$_file" "$fs" 1 > $prefield
        awk -v FS="$DS_SEP" -v OFS="$fs" -v r="$rows" -v c="$cols" ${args[@]} -f "$DS_SUPPORT/utils.awk" \
            -f "$DS_SCRIPT/reorder.awk" $prefield 2>/dev/null | ds:ttyf "$fs" "$run_fit"
    fi

    local stts_bash=${PIPESTATUS[0]} # TODO: Zsh pipestatus not working
    ds:pipe_clean $_file; [ "$pf_off" ] || rm $prefield
    if [ "$stts_bash" ]; then return $stts_bash; fi
}

ds:pivot() { # ** Pivot tabular data: ds:pivot [file] [y_keys] [x_keys] [z_keys=count_xy] [agg_type]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_pivot') piped=0
        cat /dev/stdin > $_file
    else
        ds:test "(^| )(-h|--help)" "$1" && grep -E "^#( |$)" "$DS_SCRIPT/pivot.awk" \
            | sed -E 's:^#::g' | less && return
        if [[ -f "$2" && -f "$1" ]]; then
            local w="\033[37;1m" nc="\033[0m"
            while [ -f "$1" ]; do
                local fls=("${fls[@]}" "$1")
                shift
            done
            for fl in ${fls[@]}; do
                echo -e "\n${w}${fl}${nc}"
                [ -f "$fl" ] && ds:pivot "$fl" $@
            done
            return $?
        else
          ds:file_check "$1"
          local _file="$(ds:fd_check "$1")"
          shift
        fi
    fi

    if [ "$1" ] && ! grep -Eq '^-' <(echo "$1"); then
        local y_keys="$1"; shift; fi
    if [ "$1" ] && ! grep -Eq '^-' <(echo "$1"); then
        local x_keys="$1"; shift; fi
    if [ "$1" ] && ! grep -Eq '^-' <(echo "$1"); then
        local z_keys="$1"; shift; fi

    ds:test '^[A-z]+$' "$1" && local agg_type="$1" && shift

    local args=( "$@" ) prefield=$(ds:tmp "ds_pivot_prefield") fstmp=$(ds:tmp 'ds_extractfs')
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"
    ds:prefield "$_file" "$fs" 1 > $prefield

    awk -v FS="$DS_SEP" -v OFS="$fs" -v x="${x_keys:-0}" -v y="${y_keys:-0}" \
        -v z="${z_keys:-_}" -v agg="${agg_type:-0}" ${args[@]} \
        -f "$DS_SCRIPT/pivot.awk" "$prefield" 2>/dev/null \
        | ds:ttyf "$DS_SEP"

    ds:pipe_clean $_file; rm $prefield
}

ds:agg() { # ** Aggregate by index/pattern: ds:agg [-h|file*] [r_aggs=+] [c_aggs=+]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_agg') piped=0
        cat /dev/stdin > $_file
    else
        ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/agg.awk" \
            | sed -E 's:^#::g' | less && return
        
        if [[ -f "$2" && -f "$1" ]]; then
            local w="\033[37;1m" nc="\033[0m"
            while [ -f "$1" ]; do
                local fls=("${fls[@]}" "$1")
                shift
            done
            for fl in ${fls[@]}; do
                echo -e "\n${w}${fl}${nc}"
                [ -f "$fl" ] && ds:agg "$fl" $@
            done
            return $?
        else
            ds:file_check "$1"
            local _file="$(ds:fd_check "$1")"; shift
        fi
    fi

    [ "$1" ] && ! grep -Eq '^-v' <(echo "$1") && local r_aggs="$1" && shift
    [ "$1" ] && ! grep -Eq '^-v' <(echo "$1") && local c_aggs="$1" && shift

    if [ ! "$r_aggs" ] && [ ! "$x_aggs" ]; then
        local r_aggs='+|all' c_aggs='+|all'; fi

    local args=( "$@" ) prefield=$(ds:tmp "ds_agg_prefield") fstmp=$(ds:tmp 'ds_extractfs')
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"
    ds:prefield "$_file" "$fs" > $prefield

    awk -v FS="$DS_SEP" -v OFS="$fs" -v r_aggs="$r_aggs" -v c_aggs="$c_aggs" \
        ${args[@]} -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/agg.awk" "$prefield" 2>/dev/null \
        | ds:ttyf "$fs" "" -v nofit='Cross__FS__Aggregation'

    ds:pipe_clean $_file; rm $prefield
}

ds:decap() { # ** Remove up to n_lines from the start of a file: ds:decap [file] [n_lines=1]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_decap') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi
    if [ "$1" ]; then
        ds:is_int "$1" && let n_lines=1+${1:-1} || ds:fail 'n_lines must be an integer: ds:decap [file] [n_lines=1]'
    fi
    tail -n +${n_lines:-2} "$_file"
    ds:pipe_clean $_file
}

ds:transpose() { # ** Transpose field values (alias ds:t): ds:transpose [file*] [prefield=t] [awkargs]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_transpose') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi

    if [ "$1" ] && ! grep -Eq '^-' <(echo "$1"); then
        local pf="${1:t}"; shift
        ds:test 't(rue)?' "$pf" || local pf=""
    fi

    local args=( "$@" ) fstmp=$(ds:tmp 'ds_extractfs')
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"

    if [ "$pf" ]; then
        local prefield=$(ds:tmp "ds_transpose_prefield")
        ds:prefield "$_file" "$fs" 1 > $prefield
        awk -v FS="$DS_SEP" -v OFS="$fs" -v VAR_OFS=1 ${args[@]} -f "$DS_SUPPORT/utils.awk" \
            -f "$DS_SCRIPT/transpose.awk" $prefield 2>/dev/null | ds:ttyf "$fs"
        rm $prefield
    else
        awk -v FS="$fs" -v OFS="$fs" -v VAR_OFS=1 ${args[@]} -f "$DS_SUPPORT/utils.awk" \
            -f "$DS_SCRIPT/transpose.awk" "$_file" 2>/dev/null | ds:ttyf "$fs"
    fi

    ds:pipe_clean $_file
}
alias ds:t="ds:transpose"

ds:pow() { # ** Combinatorial frequency of data field values: ds:pow [file] [min] [return_fields=f] [invert=f] [awkargs]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_pow') piped=0
        cat /dev/stdin > $_file
    else
        ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/power.awk" \
            | sed -E 's:^#::g' | less && return
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi

    ds:is_int "$1" && local min=$1 && shift
    ds:test "^t(rue)?$" "$1" && local flds=1; [ "$1" ] && shift
    ds:test "^t(rue)?$" "$1" && local inv=1; [ "$1" ] && shift
    local args=( "$@" ) fstmp=$(ds:tmp 'ds_extractfs')
    local prefield=$(ds:tmp "ds_pow_prefield") # TODO: Wrap this logic in prefield and return filename
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"
    ds:prefield "$_file" "$fs" 1 > $prefield

    awk -v FS="$DS_SEP" -v OFS="$fs" -v min=${min:-1} -v c_counts=${flds:-0} -v invert=${inv:-0} \
        ${args[@]} -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/power.awk" $prefield 2>/dev/null \
        | ds:sortm 1 a n -v FS="$fs" | sed 's///' | ds:ttyf "$fs" -v color=never

    ds:pipe_clean $_file; rm $prefield
}

ds:prod() { # ** Return product multiset of filelines: ds:pow file [file*] [awkargs]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_pow') piped=0
        cat /dev/stdin > $file
    else 
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"; shift; fi
    local files=("$_file")
    while [[ -e "$1" && ! -d "$1" ]]; do
        local tf="$1"
        if [[ "$1" =~ '/dev/fd/' ]]; then
            local tf="$(ds:fd_check "$1")"
        else
            local tf="$1"
            ! grep -Iq "" "$tf" && ds:pipe_clean $_file && ds:fail 'Binary files have been disallowed for this command!'
        fi
        local files=(${files[@]} "$tf")
        shift
    done
    awk -f "$DS_SCRIPT/product.awk" $@ ${files[@]} 2>/dev/null
    ds:pipe_clean $_file
}

ds:fieldcounts() { # ** Print value counts (alias ds:fc): ds:fc [file] [fields=1] [min=1] [order=a] [awkargs]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_fieldcounts') piped=0 
        cat /dev/stdin > $_file
    else 
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi
    local fields="${1:-a}" min="$2"; [ "$1" ] && shift; [ "$min" ] && shift
    ([ "$min" ] && test "$min" -gt 0 2> /dev/null) || local min=1
    let min=$min-1
    if [ "$1" ]; then
        ([ "$1" = d ] || [ "$1" = desc ]) && local order="r"
        [[ ! "$1" =~ "-" ]] && shift
    fi
    local args=( "$@" ) fstmp=$(ds:tmp 'ds_extractfs')
    if [ ! "$fields" = "a" ]; then
        ds:extractfs > $fstmp
        local fs="$(cat $fstmp; rm $fstmp)" prefield=$(ds:tmp "ds_fc_prefield")
        ds:prefield "$_file" "$fs" > $prefield
        ds:test "\[.+\]" "$fs" && fs=" " 
        awk ${args[@]} -v FS="$DS_SEP" -v OFS="$fs" -v min="$min" -v fields="$fields" \
            -f "$DS_SCRIPT/field_counts.awk" $prefield 2>/dev/null | sort -n$order | ds:ttyf "$fs" -v color=never
    else
        rm $fstmp
        awk ${args[@]} -v min="$min" -v fields="$fields" -f "$DS_SCRIPT/field_counts.awk" \
            "$_file" 2>/dev/null | sort -n$order | ds:ttyf "$fs" -v color=never
    fi
    ds:pipe_clean $_file; [ "$prefield" ] && rm $prefield; :
}
alias ds:fc="ds:fieldcounts"

ds:newfs() { # ** Convert field separators - i.e. tsv -> csv: ds:newfs [file] [newfs=,] [awkargs]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_newfs') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi

    [ "$1" ] && local newfs="$1" && shift
    local args=( "$@" ) newfs="${newfs:-,}" prefield=$(ds:tmp "ds_newfs_prefield") fstmp=$(ds:tmp 'ds_extractfs')
    local program='BEGIN{is_comma_ofs = OFS == ","}
        {
            for(i=1;i<=NF;i++) {
                if (is_comma_ofs && $i ~ OFS && !($i ~ /^[[:space:]]*"/)) { 
                    gsub("\"", "\"\"", $i)
                    $i = "\"" $i "\""
                }
                printf "%s", $i
                if (i < NF) {
                    printf "%s", OFS
                }
            }
            print ""
        }'
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"
    ds:prefield "$_file" "$fs" > $prefield
    awk -v FS="$DS_SEP" -v OFS="$newfs" ${args[@]} "$program" $prefield 2>/dev/null
    ds:pipe_clean $_file; rm $prefield
}

ds:hist() { # ** Print histograms for all number fields in data: ds:hist [file] [n_bins] [bar_len] [awkargs]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_hist') piped=0
        cat /dev/stdin > $_file
    else
        local tmp=$(ds:tmp 'ds_hist')
        ds:file_check "$1" f f t > $tmp
        local _file="$(ds:fd_check "$(cat $tmp; rm $tmp)")"
        shift
    fi

    ds:is_int "$1" && local n_bins="$1" && shift
    ds:is_int "$1" && local bar_len="$1" && shift
    local args=( "$@" ) prefield=$(ds:tmp "ds_tmp_prefield") fstmp=$(ds:tmp 'ds_extractfs')
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"
    ds:prefield "$_file" "$fs" > $prefield
    awk -v FS="$DS_SEP" -v OFS="$fs" -v n_bins=$n_bins -v max_bar_leb=$bar_len \
        ${args[@]} -f "$DS_SCRIPT/hist.awk" $prefield 2>/dev/null
    ds:pipe_clean $_file; rm $prefield
}

ds:graph() { # ** Extract graph relationships from DAG base data: ds:graph [file]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_graph') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi
    local args=("$@") prefield=$(ds:tmp "ds_graph_prefield") fstmp=$(ds:tmp 'ds_extractfs')
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"
    ds:prefield "$_file" "$fs" > $prefield
    awk -v FS="$DS_SEP" -v OFS="$fs" ${args[@]} -f "$DS_SUPPORT/utils.awk" \
        -f "$DS_SCRIPT/graph.awk" "$prefield" 2>/dev/null | sort
    ds:pipe_clean $_file; rm $prefield
}

ds:asgn() { # Print lines matching assignment pattern: ds:asgn file
    ds:file_check "$1"
    if ds:nset 'rg'; then
        rg "[[:alnum:]_<>\[\]\-]+ *= *(\S)+" $1 
    else
        egrep -n --color=always -e "[[:alnum:]_<>\[\]\-]+ *= *(\S)+" $1
    fi
    if [ ! $? ]; then echo 'No assignments found in file!'; fi
}

ds:enti() { # Print text entities separated by pattern: ds:enti [file] [sep= ] [min=1] [order=a]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_enti') piped=0
        cat /dev/stdin > $_file
    else
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi

    local sep="${1:- }" min="${2:-1}"
    ([ "$3" = d ] || [ "$3" = desc ]) && local order="r"
    ([ "$min" ] && test "$min" -gt 0 2>/dev/null) || min=1
    let min=$min-1
    local program="$DS_SCRIPT/separated_entities.awk"
    LC_All='C' awk -v sep="$sep" -v min=$min -f $program "$_file" 2>/dev/null | LC_ALL='C' sort -n$order
    ds:pipe_clean $_file
}

ds:subsep() { # ** Extend fields by a common subseparator: ds:subsep [-h|file] subsep_pattern [nomatch_handler= ]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_sbsp') piped=0
        cat /dev/stdin > $_file
    else
        ds:test "(^| )(-h|--help)" "$@" && grep -E "^#( |$)" "$DS_SCRIPT/subseparator.awk" \
            | sed -E 's:^#::g' | less && return
        ds:file_check "$1"
        local _file="$(ds:fd_check "$1")"
        shift
    fi

    local ssp=(-v subsep_pattern="${1:- }") nmh=(-v nomatch_handler="${2:- }")
    local args=("${@:3}") prefield=$(ds:tmp "ds_sbsp_prefield") fstmp=$(ds:tmp 'ds_extractfs')
    ds:extractfs > $fstmp
    local fs="$(cat $fstmp; rm $fstmp)"
    ds:prefield "$_file" "$fs" > $prefield

    awk -v FS="$DS_SEP" -v OFS="$fs"  ${ssp[@]} ${nmh[@]} ${args[@]} -f "$DS_SUPPORT/utils.awk" \
        -f "$DS_SCRIPT/subseparator.awk" "$prefield"{,} 2>/dev/null

    ds:pipe_clean $_file; rm $prefield
}

ds:dostounix() { # ** Remove ^M / CR characters in place: ds:dostounix [file*]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_dostounix_piped') piped=0
        cat /dev/stdin > $_file
    else
        if [[ -f "$2" && -f "$1" ]]; then
            local w="\033[37;1m" nc="\033[0m"
            while [ -f "$1" ]; do
                local fls=("${fls[@]}" "$1")
                shift
            done
            for fl in ${fls[@]}; do
                echo -e "Removing CR line endings in ${w}${fl}${nc}"
                [ -f "$fl" ] && ds:dostounix "$fl"
            done
            return $?
        else
            ds:file_check "$1"
            local _file="$(ds:fd_check "$1")"
            shift
        fi
    fi

    local tmpfile=$(ds:tmp 'ds_dostounix')
    cat "$_file" > $tmpfile
    if [ $piped ]; then
        awk '{gsub(/\015$/, "");print}' $tmpfile 2>/dev/null
        rm $_file
    else
        awk '{gsub(/\015$/, "");print}' $tmpfile 2>/dev/null > "$_file"
    fi
    rm $tmpfile
}

ds:mini() { # ** Crude minify, remove whitespace and newlines: ds:mini [file*] [newline_sep=;] [blank_only=f]
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_mini') piped=0
        cat /dev/stdin > $_file
    else
        if [[ -f "$2" && -f "$1" ]]; then
            local w="\033[37;1m" nc="\033[0m"
            while [ -f "$1" ]; do
                local fls=("${fls[@]}" "$1")
                shift
            done
            for fl in ${fls[@]}; do
                echo -e "${w}${fl}${nc}"
                [ -f "$fl" ] && ds:mini "$fl" $@
            done
            return $?
        else
            ds:file_check "$1"
            local _file="$(ds:fd_check "$1")"
            shift
        fi
    fi
    if ds:test '^t(rue)?$' "$2"; then
        perl -pe 'chomp if ($_ =~ /\S/)' "$_file"
    else
        local program='{gsub("(\n\r)+" ,"'"${1:-;}"'");gsub("\n+" ,"'"${1:-;}"'")
                gsub("\t+" ,"'"${1:-;}"'");gsub("[[:space:]]{2,}"," ");print}'
        awk -v RS="\0" "$program" "$_file" 2>/dev/null | awk -v RS="\0" "$program" 2>/dev/null
    fi
    ds:pipe_clean $_file
}

ds:sort() { # ** Sort with inferred field sep of 1 char: ds:sort [unix_sort_args] [file]
    local args=( "$@" )
    if ds:pipe_open; then
        local _file=$(ds:tmp 'ds_sort') piped=0
        cat /dev/stdin > $_file
    else 
        let last_arg=${#args[@]}-1
        local _file="${args[@]:$last_arg:1}"
        ds:file_check "$_file"
        local _file="$(ds:fd_check "$_file")"
        args=( ${args[@]/"$_file"} )
    fi
    if ds:test '^ *$' "${args[@]}"; then
        args=(-V) # Default to Version sort
    fi
    local fs="$(ds:inferfs "$_file" f true f f)"
    sort ${args[@]} --field-separator "$fs" "$_file"
    ds:pipe_clean $_file
}

ds:sortm() { # ** Sort with inferred field sep of >=1 char (alias ds:s): ds:sortm [file] [keys] [order=a|d] [sort_type] [awkargs]
    # TODO: Default to infer header
    if ds:pipe_open; then
        local file=$(ds:tmp 'ds_sortm') piped=0
        cat /dev/stdin > $file
    else
        ds:file_check "$1"
        local file="$(ds:fd_check "$1")"
        shift
    fi
    ! grep -Eq '^-' <(echo "$1") && local keys="$1" && shift
    [ "$keys" ] && grep -Eq '^[A-z]$' <(echo "$1") && local ord="$1" && shift
    [ "$ord" ] && grep -Eq '^[A-z]$' <(echo "$1") && local type="$1" && shift
    local args=( "$@" )
    [ "$keys" ] && local args=("${args[@]}" -v k="$keys")
    [ "$ord" ] && local args=("${args[@]}" -v order="$ord")
    [ "$type" ] && local args=("${args[@]}" -v type="$type")

    #TODO: Replace with consistent fs logic
    if ds:noawkfs; then
        local fs="$(ds:inferfs "$file" f true f f)"
        awk -v FS="$fs" ${args[@]} -f "$DS_SCRIPT/fields_qsort.awk" "$file" 2>/dev/null
    else
        awk ${args[@]} -f "$DS_SCRIPT/fields_qsort.awk" "$file" 2>/dev/null
    fi
    ds:pipe_clean $file
}
alias ds:s="ds:sortm"

ds:srg() { # Scope grep to files that contain a match: ds:srg scope_pattern search_pattern [dir] [invert=]
    ([ "$1" ] && [ "$2" ]) || ds:fail 'Missing scope and/or search pattern args'
    local scope="$1" search="$2"
    [ -d "$3" ] && local basedir="$3" || local basedir="$PWD"
    [ "$4" ] && [ "$4" != 'f' ] && [ "$4" != 'false' ] && local invert="--files-without-match"
    if ds:nset 'rg'; then
        echo -e "\nrg "${invert}" \""${search}"\" scoped to files matching \"${scope}\" in ${basedir}\n"
        rg -u -u -0 --files-with-matches -e "$scope" "$basedir" 2> /dev/null \
            | xargs -0 -I % rg -H $invert "$search" "%" 2> /dev/null
    else
        [ "$invert" ] && local invert="${invert}es"
        echo -e "\ngrep "${invert}" \""${search}"\" scoped to files matching \"${scope}\" in ${basedir}\n"
        grep -r --null --files-with-matches -e "$scope" "$basedir" 2> /dev/null \
            | xargs -0 -I % grep -H --color $invert "$search" "%" 2> /dev/null; fi
    :
}

ds:recent() { # List files modified recently: ds:recent [dir=.] [days=7] [recurse=f] [hidden=f] [only_files=f]
    if [ "$1" ]; then
        local dirname="$(echo "$1")"
        [ ! -d "$dirname" ] && echo Unable to verify directory provided! && return 1
    fi

    local dirname="${dirname:-$PWD}" days="$2" recurse="$3" hidden="$4" only_files="$5" datefilter
    ds:nset 'fd' && local FD=1
    [ "$days" ] && ds:is_int "$days" || let local days=7
    [ "$recurse" ] && ds:test '(r(ecurse)?|t(rue)?)' "$recurse" || unset recurse
    [ "$hidden" ] && ds:test 't(rue)?' "$hidden" || unset hidden
    [ "$only_files" ] && ds:test 't(rue)?' "$only_files" || unset only_files
    [ "$(ls --time-style=%D 2>/dev/null)" ] || local bsd=1
    local prg='{for(f=1;f<NF;f++){printf "%s ", $f;if($f~"^[0-3][0-9]/[0-3][0-9]/[0-9][0-9]$")printf "\""};print $NF "\""}'

    if [ "$hidden" ]; then
        [ $FD ] && [[ "$recurse" || "$only_files" ]] && local hidden=-HI #fd hides by default
        [[ -z "$recurse" && -z "$only_files" ]] && local hidden='A'
        local notfound="No files found modified in the last $days days!"
    else
        [ ! $FD ] && [[ "$recurse" || "$only_files" ]] && local hidden="-not -path '*/\.*'" # find includes all by default
        local notfound="No non-hidden files found modified in the last $days days!"
    fi

    [ "$FD" ] && local fd_hyphen="-" || local fd_hyphen=""

    if [[ "$recurse" || "$only_files" ]]; then
        if [ "$bsd" ]; then
            local sortf=5
            [ ! "$only_files" ] && local cmd_exec=("$fd_hyphen"-exec stat -l -t "%D" \{\})
        else
            local sortf=4
            [ ! "$only_files" ] && local cmd_exec=("$fd_hyphen"-exec ls -ghtG --time-style=+%D \{\})
        fi

        if [[ "$only_files" && ! "$recurse" ]]; then
            local max_depth=("$fd_hyphen"-maxdepth 1) || local max_depth=""
        fi

        (
            if [ $FD ]; then
                if [ "$only_files" ]; then
                    fd -t f --changed-within="${days}days" $hidden -E ~"/Library" \
                        ${max_depth[@]} ".*" "$dirname"
                else
                    fd -t f --changed-within="${days}days" $hidden -E ~"/Library" \
                        ${max_depth[@]} ${cmd_exec[@]} 2> /dev/null \; ".*" "$dirname"
                fi
            else
                if [ "$only_files" ]; then
                    find "$dirname" -type f ${max_depth[@]} $hidden \
                        -not -path ~"/Library" -mtime -${days}d
                else
                    find "$dirname" -type f ${max_depth[@]} $hidden -not -path ~"/Library" \
                        -mtime -${days}d ${cmd_exec[@]} 2> /dev/null
                fi
            fi
        ) | ( [ "$only_files" ] && cat || awk "$prg" ) \
            | sort -V -k$sortf \
            | ( [ "$only_files" ] && cat || ds:fit -v FS=" +" -v color=never ) \
            | ds:pipe_check
    else
        let local days-=1

        if [ "$(date -v -0d 2>/dev/null)" ]; then
            for i in {0..$days}; do
                local dates=( "${dates[@]}" "-e $(date -v "-${i}d" "+%D")" )
            done
        else
            for i in {0..$days}; do
                local dates=( "${dates[@]}" "-e $(date -d "-$i days" +%D)" )
            done
        fi

        ([ "$bsd" ] && stat -l -t "%D" "$dirname"/* \
            || ls -ghtG$hidden --time-style=+%D "$dirname" \
        ) | grep -v '^d' | grep ${dates[@]} | awk "$prg" \
            | ds:fit -v FS=" +" -v color=never | ds:pipe_check
    fi

    [ $? = 0 ] || (echo "$notfound" && return 1)
}

ds:sedi() { # Run global in place substitutions: ds:sedi file|dir search [replace]
    [ "$1" ] && [ "$2" ] || ds:fail 'Missing required args: ds:sedi file|dir search [replace]'
    if [ -f "$1" ]; then
        local file="$1"
    else
        [ -d "$1" ] && local dir="$1" || local dir=.
        local conf="$(ds:readp "Confirm replacement of \"$2\" -> \"$3\" on all files in $dir (y/n):")"
        [ ! "$conf" = y ] && echo 'No change made!' && return 1
    fi

    if [ "$(printf "%q" _ > /dev/null)" ]; then
        local search="$(printf "%q" "$2")"
        [ "$3" ] && local replace="$(printf "%q" "$3")"
    else
        local search="$2"
        [ "$3" ] && local replace="$3"
    fi

    if ds:test '/' "${search}${replace}"; then
        local sepalts=('@' '#' '%' '&' ';' ':' ',' '|')
        local count="$(ds:arr_base)"
        while [ ! "$sep" ]; do
            ds:test "${sepalts[$count]}" "${search}${replace}" && let local count++ && continue
            local sep="${sepalts[$count]}"
            break
        done
        [ ! "$sep" ] && echo 'Failed replacement - please try strings with less token characters.' && return 1
    else
        local sep='/'
    fi

    if [ "$file" ]; then
        perl -pi -e "s${sep}${search}${sep}${replace}${sep}g" "$file"
    else
        while IFS=$'\n' read -r file; do
            perl -pi -e "s${sep}${search}${sep}${replace}${sep}g" "$file"
            echo "replaced \"$search\" with \"$replace\" in $file"
        done < <(grep -r --files-with-match "$search" "$dir")
    fi
}

ds:diff() { # ** Diff shortcut for an easier to read view: ds:diff file1 [file2] [suppress_common] [color=t]
    # TODO: dynamic width if short lines on one or more files
    # TODO: diff >2 files
    if ds:pipe_open; then
        local file1=$(ds:tmp 'ds_dff') piped=0
        cat /dev/stdin > $file1
    else
        ds:file_check "$1"
        local file1="$(ds:fd_check "$1")"
        shift
    fi
    ds:file_check "$1"
    local file2="$(ds:fd_check "$1")"
    [ "$2" ] && local sup=--suppress-common-lines
    local tty_size=$(tput cols) color="${3:-t}"
    let local tty_half=$tty_size/2
    if ds:test 't(rue)?' "$color"; then
        diff -b -y -W $tty_size $sup "$file1" "$file2" | expand | awk -v tty_half=$tty_half \
          -f "$DS_SCRIPT/diff_color.awk" 2>/dev/null | less
    else
        diff -b -y -W $tty_size $sup "$file1" "$file2" | expand | less
    fi
#    ds:pipe_clean $file1
}

ds:git_word_diff() { # Git word diff shortcut (alias ds:gwdf): ds:gwdf [git_diff_args]
    local args=( "$@" )
    git diff --word-diff-regex="[A-Za-z0-9. ]|[^[:space:]]" --word-diff=color ${args[@]}
}
alias ds:gwdf="ds:git_word_diff"

ds:line() { # ** Execute commands on var line: ds:line [seed_cmds] line_cmds [IFS=\n]
    if ds:pipe_open; then
        local _file="$(ds:tmp 'ds_line')" piped=0
        cat /dev/stdin > $_file
    else
        local seed_cmds="$1"
        shift
    fi
    local OLD_IFS="$IFS"
    [ "$2" ] && local sep="$2" || local sep=$'\n'
    while IFS=$sep read -r line; do
        eval "$1"; [ $? -gt 0 ] && local stts=1
    done < <([ "$piped" ] && cat $_file || eval "$seed_cmds")
    ds:pipe_clean $_file
    IFS="$OLD_IFS"
    return $stts
}

ds:goog() { # Search Google: ds:goog [search query]
    local search_args="$@"
    [ -z "$search_args" ] && ds:fail 'Query required for search'
    local base_url="https://www.google.com/search?query="
    local search_query=$(echo $search_args | sed -e "s/ /+/g")
    local OS="$(ds:os)" search_url="${base_url}${search_query}"
    [ "$OS" = "Linux" ] && xdg-open "$search_url" && return
    open "$search_url"
}

ds:so() { # Search Stack Overflow: ds:so [search_query]
    local search_args="$@"
    if [ "$search_args" ]; then
        local base_url="https://www.stackoverflow.com/search?q="
        local search_query=$(echo $search_args | sed -e "s/ /+/g")
    else
        local base_url='https://www.stackoverflow.com'
    fi
    local OS="$(ds:os)" search_url="${base_url}${search_query}"
    [ "$OS" = "Linux" ] && xdg-open "$search_url" && return
    open "$search_url"
}

ds:jira() { # Open Jira at specified workspace issue / search: ds:jira workspace_subdomain [issue|query]
    [ -z "$1" ] && ds:help ds:jira && ds:fail 'Missing workspace subdomain (arg 1)'
    local OS="$(ds:os)" j_url="https://$1.atlassian.net"
    if [ "$2" ]; then
        if ds:test "[A-Z]+-[0-9]+" "$2"; then
            local j_url="$j_url/browse/$2"
        else
            local j_url="$j_url/search/$2"
        fi
    fi
    [ "$OS" = "Linux" ] && xdg-open "$j_url" && return
    open "$j_url"
}

ds:unicode() { # ** Get UTF-8 unicode for a character sequence: ds:unicode [str] [out=codepoint|hex|octet]
    ! ds:nset 'xxd' && ds:fail 'Utility xxd required for this command'
    [ "$2" ] && ds:test '(hex|octet)' "$2" || local codepoint=0
    local sq=($(ds:pipe_open && grep -ho . || echo "$1" | grep -ho .))
    for i in ${sq[@]}; do
        local code="$(printf "$i" | xxd -b \
            | awk -F"[[:space:]]+" -v to="${2:-codepoint}" -f "$DS_SCRIPT/unicode.awk" 2>/dev/null \
            | bc | awk '{_ = _ $0}END{print _}' 2>/dev/null)"
        if [ "$codepoint" ]; then
            printf "\\\U$code"
        else
            printf "%s" "%$code"
        fi
    done
    echo
}

ds:case() { # ** Recase text data globally or in part: ds:case [string] [tocase=proper] [filter]
    local _file=$(ds:tmp 'ds_case') piped=0
    if ds:pipe_open; then
        cat /dev/stdin > $_file
    elif [ "$1" ]; then
        ds:test "^(-h|--help)" "$1" && grep -E "^#( |$)" "$DS_SCRIPT/case.awk" \
            | sed -E 's:^#::g' && ds:pipe_clean $_file && return
        echo "$1" > $_file; shift
    else
        ds:fail 'Input string not found: ** | ds:case [string] [tocase=proper] [filter]'
    fi
    awk -v tocase="${1:-pc}" -f "$DS_SCRIPT/case.awk" $_file
    ds:pipe_clean $_file
}

ds:random() { # ** Generate a random number 0-1 or randomize text: ds:random [number|text]
    if ds:pipe_open; then
        awk -v FS="" -v mode="$1" -f $DS_SCRIPT/randomize.awk
    else
        echo "" | awk -v FS="" -v mode="$1" -f $DS_SCRIPT/randomize.awk
    fi
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

ds:dups() { # Report duplicate files with option for deletion: ds:dups [dir] [confirm=f] [of_file] [try_nonmatch_ext=f]
    if ! ds:nset 'md5sum'; then
        echo 'md5sum utility not found - please install GNU coreutils to enable this command'
        return 1
    fi
    ds:nset 'pv' && local use_pv="-p"
    ds:nset 'fd' && local use_fd="-u"
    [ -d "$1" ] && local dir="$1" || local dir="$PWD"
    ds:test 't(rue)?' "$2" && local delete="-d"
    ds:test 't(rue)?' "$4" && local all_files="-a"
    if [ "$3" ]
    then
        ds:file_check "$3" f t
        local of_file="$3"
        bash "$DS_SCRIPT/dup_files.sh" -s "$dir" -f "$of_file" $delete $use_fd $use_pv $all_files
    else
        bash "$DS_SCRIPT/dup_files.sh" -s "$dir" $delete $use_fd $use_pv 
    fi
}

ds:deps() { # Identify the dependencies of a shell function: ds:deps name [filter] [ntype=(FUNC|ALIAS)] [caller] [ndata]
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
    rm $tmp
    [ "$rm_dt" ] && rm $ndt
}

ds:gexec() { # Generate script from parts of another and run: ds:gexec run=f srcfile outputdir reo_r_args [clean] [verbose]
    [ "$1" ] && local run="$1" && shift || (ds:help ds:gexec && return 1)
    ds:file_check "$1"
    [ -d "$2" ] || ds:fail 'arg 2 must be a directory'
    [ "$3" ] || ds:fail 'arg 2 must be a match pattern set'
    local src="$(ds:fd_check "$1")" scriptdir="$2" r_args="$3" clean="$4"
    [ "$5" ] && local run_verbose=-x
    read -r dirpath filename extension <<<$(ds:path_elements "$src")
    local gscript="$scriptdir/ds_gexec_from_$filename$extension"

    ds:reo "$src" "$r_args" 'off' false > "$gscript"
    echo -e "\n\033[0;33mNew file: $gscript\033[0m\n"
    chmod 777 "$gscript"; cat "$gscript"

    ds:test "^t(rue)?$" "$run" && echo && local conf=$(ds:readp 'Confirm script run (y/n):')
    if [ "$conf" = y ]; then
        echo -e "\n\033[0;33mRunning file $gscript\033[0m\n"
        bash $run_verbose "$gscript"; local stts="$?"
    else
        echo -e "\n\033[0;33mScript not executed!\033[0m"
    fi

    [ $clean ] && rm "$gscript" && echo -e "\n\033[0;33mRemoved file $gscript\033[0m"
    if [ "$stts" ]; then return "$stts"; fi
}

