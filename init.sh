#!/bin/bash
base="$(dirname $BASH_SOURCE)"; if grep -rq '$' "$base" 2>/dev/null; then for f in $(grep -r --files-with-matches '$' "$base"); do ext=${f##*.}; if [[ "$ext" = sh || "$ext" = awk ]]; then if [ -f "$f" ]; then tmp=/tmp/ds_unixtodos; cat "$f" > $tmp; sed 's/\r//g' $tmp > "$f"; rm $tmp; fi; fi; done; fi; source "$base/commands.sh"
