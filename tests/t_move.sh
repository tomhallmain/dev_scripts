#!/bin/bash

source commands.sh

# Solo runs need the same scratch path commands_tests.sh exports.
[ -n "${q:-}" ] || q=/dev/null

# MOVE/COPY TESTS

echo -n "Running move/copy commands tests..."

odir=$(mktemp -d /tmp/ds_move.XXXXXX) || ds:fail 'move tmp dir failed'

# Tag filter, flattening into an already-existing target dir; copy leaves source intact.
mkdir -p "$odir/copy_src/sub"
echo v1 > "$odir/copy_src/a.mp4"
echo v2 > "$odir/copy_src/sub/b.mp4"
echo t1 > "$odir/copy_src/notes.txt"
mkdir -p "$odir/copy_dst"
printf 'y\n' | ds:copy "$odir/copy_src" "$odir/copy_dst" "[video]" &> $q
[ -f "$odir/copy_dst/a.mp4" ]          || ds:fail 'ds:copy did not copy top-level filtered file'
[ -f "$odir/copy_dst/b.mp4" ]          || ds:fail 'ds:copy did not copy nested filtered file'
[ ! -e "$odir/copy_dst/notes.txt" ]    || ds:fail 'ds:copy copied a file that should have been filtered out'
[ -f "$odir/copy_src/a.mp4" ]          || ds:fail 'ds:copy removed a source file (should only copy)'
[ "$(cat "$odir/copy_dst/a.mp4")" = v1 ] || ds:fail 'ds:copy corrupted file content'

# Glob filter.
mkdir -p "$odir/glob_src"
echo x > "$odir/glob_src/keep.log"
echo y > "$odir/glob_src/skip.csv"
printf 'y\n' | ds:copy "$odir/glob_src" "$odir/glob_dst" "*.log" &> $q
[ -f "$odir/glob_dst/keep.log" ]       || ds:fail 'ds:copy glob filter missed a matching file'
[ ! -e "$odir/glob_dst/skip.csv" ]     || ds:fail 'ds:copy glob filter let through a non-matching file'

# Bare-extension filter.
mkdir -p "$odir/ext_src"
echo x > "$odir/ext_src/keep.csv"
echo y > "$odir/ext_src/skip.tsv"
printf 'y\n' | ds:copy "$odir/ext_src" "$odir/ext_dst" ".csv" &> $q
[ -f "$odir/ext_dst/keep.csv" ]        || ds:fail 'ds:copy extension filter missed a matching file'
[ ! -e "$odir/ext_dst/skip.tsv" ]      || ds:fail 'ds:copy extension filter let through a non-matching file'

# Single file source, moved (renamed) to a new path; source is removed.
echo hello > "$odir/single.txt"
printf 'y\n' | ds:move "$odir/single.txt" "$odir/renamed.txt" &> $q
[ -f "$odir/renamed.txt" ]             || ds:fail 'ds:mv did not create renamed target'
[ ! -e "$odir/single.txt" ]            || ds:fail 'ds:mv left the source file behind'
[ "$(cat "$odir/renamed.txt")" = hello ] || ds:fail 'ds:mv corrupted file content'

# Flatten-in-place: source dir == target dir pulls nested matches to the
# root and leaves files already at the root alone.
mkdir -p "$odir/flat/inner"
echo a > "$odir/flat/root.mp4"
echo b > "$odir/flat/inner/deep.mp4"
printf 'y\n' | ds:move "$odir/flat" "$odir/flat" "[video]" &> $q
[ -f "$odir/flat/deep.mp4" ]           || ds:fail 'ds:mv flatten-in-place did not pull the nested file to the root'
[ -f "$odir/flat/root.mp4" ]           || ds:fail 'ds:mv flatten-in-place unexpectedly moved a root-level file'
[ ! -e "$odir/flat/inner/deep.mp4" ]   || ds:fail 'ds:mv flatten-in-place left a file at its old nested path'

# No filter matches: no target created, source untouched, non-zero exit.
mkdir -p "$odir/none_src"
echo x > "$odir/none_src/f.pdf"
ds:move "$odir/none_src" "$odir/none_dst" "[video]" &> $q
[ $? -ne 0 ]                           || ds:fail 'ds:mv with no filter matches should have failed'
[ ! -e "$odir/none_dst" ]              || ds:fail 'ds:mv created a target dir despite no matching files'
[ -f "$odir/none_src/f.pdf" ]          || ds:fail 'ds:mv touched the source despite no matching files'

# Declining the confirmation prompt makes no changes.
mkdir -p "$odir/decline_src"
echo x > "$odir/decline_src/f.txt"
printf 'n\n' | ds:move "$odir/decline_src" "$odir/decline_dst" &> $q
[ $? -ne 0 ]                           || ds:fail 'ds:mv should have failed when confirmation was declined'
[ ! -e "$odir/decline_dst" ]           || ds:fail 'ds:mv created a target despite declined confirmation'
[ -f "$odir/decline_src/f.txt" ]       || ds:fail 'ds:mv moved the source despite declined confirmation'

# Multiple files into a single existing file target: errors, target untouched.
mkdir -p "$odir/multi_src"
echo x > "$odir/multi_src/one.txt"
echo y > "$odir/multi_src/two.txt"
echo orig > "$odir/single_target"
printf 'y\ny\n' | ds:copy "$odir/multi_src" "$odir/single_target" &> $q
[ $? -ne 0 ]                                    || ds:fail 'ds:copy into a single file target with multiple matches should have failed'
[ "$(cat "$odir/single_target")" = orig ]       || ds:fail 'ds:copy overwrote a single file target on the error path'

# Threshold: 20+ files trigger a second, stricter confirmation.
mkdir -p "$odir/many_src"
for i in $(seq 1 22); do echo "x" > "$odir/many_src/f$i.txt"; done

printf 'y\ny\n' | ds:copy "$odir/many_src" "$odir/many_dst_confirmed" &> $q
[ "$(find "$odir/many_dst_confirmed" -type f | wc -l)" -eq 22 ] || ds:fail 'ds:copy threshold case: expected all 22 files copied after confirming both prompts'

printf 'y\nn\n' | ds:copy "$odir/many_src" "$odir/many_dst_declined" &> $q
[ ! -e "$odir/many_dst_declined" ] || ds:fail 'ds:copy threshold case: declining the second confirmation should have made no changes'

rm -rf "$odir"

echo -e "${GREEN}PASS${NC}"
