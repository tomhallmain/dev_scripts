#!/bin/bash
#
# Kill the process listening on a port, or matching a search pattern.
# Walks up to a wrapper parent (npm/yarn/sh/etc.) when it's the sole reason
# that parent exists, so the wrapper isn't left running/erroring behind it.
# Invoked as: kill_port.sh <port|pattern>

target="$1"
self_pid=$$
shell_pid=$PPID
wait_ticks=20    # 20 * 0.1s = 2s grace period before escalating to SIGKILL

if [ -z "$target" ]; then
    echo "Usage: ds:kill_port port|pattern"
    exit 1
fi

# Normalized PID\tPPID\tUSER\tCMD rows for every process, via a column set
# that GNU ps, BSD/macOS ps, and BusyBox ps all accept (header label may
# read COMMAND, ARGS, or CMD depending on the ps implementation).
ps_rows() {
    ps -eo pid,ppid,user,args 2>/dev/null | awk '
        NR==1 {
            for (f=1; f<=NF; f++) {
                if ($f=="PID") pidf=f
                else if ($f=="PPID") ppidf=f
                else if ($f=="USER") userf=f
                else if ($f=="COMMAND" || $f=="ARGS" || $f=="CMD") cmdf=f
            }
            next
        }
        {
            cmd=$cmdf
            for (i=cmdf+1; i<=NF; i++) cmd=cmd" "$i
            print $pidf "\t" $ppidf "\t" $userf "\t" cmd
        }'
}

proc_row()  { ps_rows | awk -F'\t' -v p="$1" '$1==p {print; exit}'; }
proc_ppid() { proc_row "$1" | awk -F'\t' '{print $2}'; }
proc_user() { proc_row "$1" | awk -F'\t' '{print $3}'; }
proc_cmd()  { proc_row "$1" | awk -F'\t' '{print $4}'; }
children_count() { ps_rows | awk -F'\t' -v pp="$1" '$2==pp' | wc -l | tr -d ' '; }

print_details() {
    local pid="$1" row
    row="$(proc_row "$pid")"
    if [ -z "$row" ]; then
        echo "  PID $pid (process details unavailable -- already exited?)"
        return
    fi
    awk -F'\t' '{printf "  PID %s   PPID %s   USER %s   CMD %s\n", $1, $2, $3, $4}' <<< "$row"
}

is_wrapper_comm() {
    case "$1" in
        npm|yarn|pnpm|npx|make|sh|bash|nodemon|ts-node-dev|concurrently) return 0 ;;
        *) return 1 ;;
    esac
}

# Walks up from $1 while each successive parent is a thin wrapper (matches
# is_wrapper_comm) whose only live child is the process below it in the
# chain. Stops at the first parent that doesn't qualify, or after 10 hops.
resolve_kill_target() {
    local pid="$1" hops=0 ppid parent_cmd parent_comm
    while [ "$hops" -lt 10 ]; do
        ppid="$(proc_ppid "$pid")"
        [ -z "$ppid" ] && break
        [ "$ppid" = 1 ] && break
        parent_cmd="$(proc_cmd "$ppid")"
        parent_comm="$(basename "${parent_cmd%% *}")"
        is_wrapper_comm "$parent_comm" || break
        [ "$(children_count "$ppid")" = 1 ] || break
        pid="$ppid"
        hops=$((hops + 1))
    done
    echo "$pid"
}

declare -a candidates=()

if [[ "$target" =~ ^[0-9]+$ ]]; then
    mode=port
    if command -v lsof &>/dev/null; then
        while IFS= read -r p; do
            [ -n "$p" ] && candidates+=("$p")
        done < <(lsof -nP -iTCP:"$target" -sTCP:LISTEN -t 2>/dev/null)
    else
        echo "lsof is required to look up a process by port and was not found."
        exit 1
    fi
else
    mode=pattern
    while IFS= read -r p; do
        [ -n "$p" ] && candidates+=("$p")
    done < <(ps_rows | awk -F'\t' -v pat="$target" '$4 ~ pat {print $1}')
fi

# Never offer to touch this script's own process or the shell that invoked it.
declare -a filtered=()
for p in "${candidates[@]}"; do
    [ "$p" = "$self_pid" ] && continue
    [ "$p" = "$shell_pid" ] && continue
    [ "$p" = 1 ] && continue
    filtered+=("$p")
done
candidates=("${filtered[@]}")

if [ "${#candidates[@]}" = 0 ]; then
    if [ "$mode" = port ]; then
        echo "No process found listening on port $target."
    else
        echo "No process found matching pattern: $target"
    fi
    exit 1
fi

int_re='^[0-9]+$'
found_pid=""

if [ "${#candidates[@]}" = 1 ]; then
    found_pid="${candidates[0]}"
else
    echo "Multiple matching processes found:"
    for i in "${!candidates[@]}"; do
        printf '%5s  ' "$((i + 1))"
        print_details "${candidates[$i]}"
    done
    echo
    while [ -z "$found_pid" ]; do
        if ! read -p "Enter the number of the process to kill: " choice; then
            echo "No input received. No change made."
            exit 1
        fi
        if [[ "$choice" =~ $int_re ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#candidates[@]}" ]; then
            found_pid="${candidates[$((choice - 1))]}"
        else
            echo "Enter a number between 1 and ${#candidates[@]}."
        fi
    done
fi

kill_pid="$(resolve_kill_target "$found_pid")"

echo "Found process:"
print_details "$found_pid"

if [ "$kill_pid" != "$found_pid" ]; then
    echo
    echo "Its parent is a thin wrapper with no other children, so the wrapper will be killed instead:"
    print_details "$kill_pid"
fi

echo
read -p "Kill PID $kill_pid? (y/n) " confirm
if [ "$confirm" != y ]; then
    echo "No change made."
    exit 1
fi

kill -TERM "$kill_pid" 2>/dev/null

ticks=0
while kill -0 "$kill_pid" 2>/dev/null && [ "$ticks" -lt "$wait_ticks" ]; do
    sleep 0.1
    ticks=$((ticks + 1))
done

if kill -0 "$kill_pid" 2>/dev/null; then
    echo "PID $kill_pid did not exit after SIGTERM -- sending SIGKILL."
    kill -KILL "$kill_pid" 2>/dev/null
    ticks=0
    while kill -0 "$kill_pid" 2>/dev/null && [ "$ticks" -lt "$wait_ticks" ]; do
        sleep 0.1
        ticks=$((ticks + 1))
    done
fi

if kill -0 "$kill_pid" 2>/dev/null; then
    echo "Failed to kill PID $kill_pid."
    exit 1
fi

echo "PID $kill_pid terminated."
