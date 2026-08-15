#!/bin/bash
#
# Move or copy files/directories, with optional [tag] or glob filtering.
# Invoked as: move.sh <move|copy> source target [filter]
# Tags: [video] [audio] [image] [document] [text] [bin]

mode="$1" src_arg="$2" tgt_arg="$3" filter="$4"
threshold=20

if [ "$mode" != move ] && [ "$mode" != copy ]; then
    echo "Internal error: move.sh called with unknown mode '$mode'" >&2
    exit 1
fi
if [ -z "$src_arg" ] || [ -z "$tgt_arg" ]; then
    echo "Usage: ds:${mode} source target [filter]"
    exit 1
fi
if [ ! -e "$src_arg" ]; then
    echo "Source path does not exist: $src_arg"
    exit 1
fi

command -v fd &>/dev/null && FD=true

if [ "$mode" = copy ]; then verb=copy verb_cap=Copy verb_past=copied
else verb=move verb_cap=Move verb_past=moved; fi

# Resolve to an absolute path without requiring the path to exist yet
# (realpath here is BusyBox's, which lacks GNU's -m/--canonicalize-missing).
abspath() {
    local p="$1" parent base
    case "$p" in
        /*) : ;;
        *) p="$(pwd)/$p" ;;
    esac
    if [ -e "$p" ]; then
        realpath "$p"
        return
    fi
    parent="$(dirname "$p")"
    base="$(basename "$p")"
    [ "$parent" = "$p" ] && { echo "$p"; return; }
    echo "$(abspath "$parent")/$base"
}

source_path="$(abspath "$src_arg")"
target_path="$(abspath "$tgt_arg")"
[ -d "$source_path" ] && source_is_dir=1 || source_is_dir=0
source_equals_target_dir=0
[ "$source_is_dir" = 1 ] && [ -d "$target_path" ] && [ "$source_path" = "$target_path" ] \
    && source_equals_target_dir=1

tag_extensions() {
    case "$1" in
        '[video]')    echo '.mp4 .avi .mkv .mov .wmv .flv .webm .m4v .mpg .mpeg .3gp .ogv .divx .vob .ts .mts' ;;
        '[audio]')    echo '.mp3 .wav .flac .aac .ogg .wma .m4a .opus .aiff .au .ra .amr .ac3 .dts .mpc .ape' ;;
        '[image]')    echo '.jpg .jpeg .png .gif .bmp .tiff .tif .webp .svg .ico .heic .heif .raw .cr2 .nef .orf .sr2 .psd .ai .eps .dng .xcf .sketch .icns .jp2 .j2k .pcx .tga .exr .hdr' ;;
        '[document]') echo '.pdf .doc .docx .xls .xlsx .ppt .pptx .odt .ods .odp .rtf .txt .csv .tsv .pages .numbers .key .epub .mobi .azw .fb2' ;;
        '[text]')     echo '.txt .md .markdown .rst .log .csv .tsv .json .xml .html .htm .css .js .py .java .cpp .c .h .hpp .sh .bat .ps1 .yaml .yml .ini .cfg .conf .properties .sql .r .m .swift .go .rs .php .rb .pl .lua .scala .kt .dart .ts .jsx .tsx .vue .svelte' ;;
        '[bin]')      echo '.exe .dll .so .dylib .bin .app .deb .rpm .pkg .msi .dmg .iso .img .zip .tar .gz .bz2 .xz .7z .rar .cab .jar .war .ear .class .o .obj .a .lib' ;;
        *) return 1 ;;
    esac
}

# Mirrors Python's os.path.splitext: a leading dot doesn't count as an extension marker.
split_ext() {
    local filename="$1" rest
    case "$filename" in
        .*)
            rest="${filename#.}"
            case "$rest" in
                *.*) echo ".${rest##*.}" ;;
                *) echo "" ;;
            esac
            ;;
        *.*) echo ".${filename##*.}" ;;
        *) echo "" ;;
    esac
}

matches_filter() {
    local filepath="$1" filename ext filter_lc tag_exts
    [ -z "$filter" ] && return 0
    filename="$(basename "$filepath")"
    ext="$(split_ext "$filename")"
    ext="${ext,,}"
    filter_lc="${filter,,}"

    if [[ "$filter" == \[*\] ]]; then
        if tag_exts="$(tag_extensions "$filter_lc")"; then
            [[ " $tag_exts " == *" $ext "* ]]
            return
        fi
        [[ "$filename" == $filter ]]
        return
    fi
    case "$filter" in
        *'*'*|*'?'*) [[ "$filename" == $filter ]] ;;
        .*) [ "$filter_lc" = "$ext" ] ;;
        *) [[ "$filename" == $filter ]] ;;
    esac
}

# Populates the array named by $1 with the sorted, filtered files in scope.
collect_files() {
    local -n out_ref="$1"
    out_ref=()
    local f

    if [ "$source_is_dir" = 0 ]; then
        matches_filter "$source_path" && out_ref=("$source_path")
        return
    fi

    while IFS= read -r -d '' f; do
        # Flatten-in-place: skip files already sitting directly in the source
        # root, since that root is also the target when moving into itself.
        if [ "$source_equals_target_dir" = 1 ] && [ "$(dirname "$f")" = "$source_path" ]; then
            continue
        fi
        matches_filter "$f" && out_ref+=("$f")
    done < <(
        if [ "$FD" = true ]; then
            fd . "$source_path" -H --type f -0
        else
            find "$source_path" -type f -print0
        fi
    )

    if [ "${#out_ref[@]}" -gt 0 ]; then
        local -a sorted
        while IFS= read -r f; do sorted+=("$f"); done < <(printf '%s\n' "${out_ref[@]}" | sort)
        out_ref=("${sorted[@]}")
    fi
}

# Prints the target path for a source file to stdout; on the
# multiple-files-into-one-file-target error, prints nothing and returns 1.
determine_target_path() {
    local source_file="$1" files_count="$2" filename rel

    if [ -d "$target_path" ]; then
        filename="$(basename "$source_file")"
        echo "$target_path/$filename"
        return 0
    fi

    if [ "$source_is_dir" = 0 ]; then
        echo "$target_path"
        return 0
    fi

    if [ ! -e "$target_path" ]; then
        rel="${source_file#"$source_path"/}"
        echo "$target_path/$rel"
        return 0
    fi

    if [ "$files_count" = 1 ]; then
        echo "$target_path"
        return 0
    fi

    echo "Cannot $verb multiple files to a single file target: $target_path" >&2
    return 1
}

# Prints a "  .ext: N" breakdown, sorted by count desc then extension name.
print_summary() {
    local -n files_ref="$1"
    local -A counts
    local f ext
    for f in "${files_ref[@]}"; do
        ext="$(split_ext "$(basename "$f")")"
        [ -z "$ext" ] && ext="(no extension)"
        counts["$ext"]=$(( ${counts["$ext"]:-0} + 1 ))
    done
    for ext in "${!counts[@]}"; do
        printf '%s\t%s\n' "${counts[$ext]}" "$ext"
    done | sort -t $'\t' -k1,1nr -k2,2 | while IFS=$'\t' read -r count ext; do
        printf '  %s: %s\n' "$ext" "$count"
    done
}

confirm() {
    local reply
    read -p "$1 (y/n) " reply
    [ "$reply" = y ]
}

# Copies via a same-directory temp file, verifies with sha256sum, then
# atomically renames it into place -- mirrors atomic_copy/atomic_move from
# the dev_scripts_py SafeFileOps module this was ported from.
safe_copy() {
    local src="$1" dst="$2" dst_dir tmp
    dst_dir="$(dirname "$dst")"
    mkdir -p "$dst_dir" || { echo "Failed to create directory: $dst_dir"; return 1; }
    tmp="$(mktemp "$dst_dir/.ds_move.XXXXXX")" || { echo "Failed to create temp file in $dst_dir"; return 1; }
    if ! cp -p "$src" "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        echo "Copy failed: $src -> $dst"
        return 1
    fi
    if [ "$(sha256sum < "$src")" != "$(sha256sum < "$tmp")" ]; then
        rm -f "$tmp"
        echo "Verification failed: copied file does not match source: $src"
        return 1
    fi
    if ! mv -f "$tmp" "$dst"; then
        rm -f "$tmp"
        echo "Failed to finalize copy to $dst"
        return 1
    fi
    return 0
}

safe_move() {
    local src="$1" dst="$2" err
    err="$(safe_copy "$src" "$dst")"
    if [ $? -ne 0 ]; then
        echo "$err"
        return 1
    fi
    if ! rm -f "$src"; then
        rm -f "$dst"
        echo "Failed to remove source file after copy: $src"
        return 1
    fi
    return 0
}

declare -a all_files
collect_files all_files
file_count="${#all_files[@]}"

if [ "$file_count" = 0 ]; then
    if [ -n "$filter" ]; then
        echo "No files found matching filter: $filter"
    else
        echo "No files found to $verb."
    fi
    echo "${verb_cap} operation cancelled - no files to $verb."
    exit 1
fi

echo "Files to be ${verb_past} (${file_count} total):"
print_summary all_files

confirm "\nConfirm $verb operation?" || { echo "${verb_cap} operation cancelled."; exit 1; }

if [ "$file_count" -ge "$threshold" ]; then
    echo -e "\nWarning: $file_count files to $verb (threshold: $threshold)"
    confirm "Are you sure you want to proceed?" || { echo "${verb_cap} operation cancelled."; exit 1; }
fi

# Re-scan right before executing; if the matched set drifted since the
# preview above, show what changed and require re-confirmation.
baseline=("${all_files[@]}")
while :; do
    declare -a refreshed
    collect_files refreshed
    if [ "$(printf '%s\n' "${refreshed[@]}")" = "$(printf '%s\n' "${baseline[@]}")" ]; then
        all_files=("${refreshed[@]}")
        break
    fi

    refreshed_count="${#refreshed[@]}"
    echo -e "\nFile list changed since preview: ${#baseline[@]} -> ${refreshed_count}. Please re-confirm."

    mapfile -t removed < <(comm -23 <(printf '%s\n' "${baseline[@]}") <(printf '%s\n' "${refreshed[@]}"))
    mapfile -t added < <(comm -13 <(printf '%s\n' "${baseline[@]}") <(printf '%s\n' "${refreshed[@]}"))

    if [ "${#removed[@]}" -gt 0 ]; then
        echo "Removed from operation list:"
        for f in "${removed[@]:0:10}"; do echo "  - $f"; done
        [ "${#removed[@]}" -gt 10 ] && echo "  ... and $(( ${#removed[@]} - 10 )) more"
    fi
    if [ "${#added[@]}" -gt 0 ]; then
        echo "Added to operation list:"
        for f in "${added[@]:0:10}"; do echo "  + $f"; done
        [ "${#added[@]}" -gt 10 ] && echo "  ... and $(( ${#added[@]} - 10 )) more"
    fi

    if [ "$refreshed_count" = 0 ]; then
        echo "${verb_cap} operation cancelled - no files to $verb."
        exit 1
    fi

    baseline=("${refreshed[@]}")
    confirm "Proceed with updated $verb set?" || { echo "${verb_cap} operation cancelled."; exit 1; }

    if [ "$refreshed_count" -ge "$threshold" ]; then
        echo -e "\nWarning: $refreshed_count files to $verb (threshold: $threshold)"
        confirm "Are you sure you want to proceed?" || { echo "${verb_cap} operation cancelled."; exit 1; }
    fi
done

if [ "$source_is_dir" = 1 ] && [ ! -e "$target_path" ]; then
    mkdir -p "$target_path"
    echo "Target directory created: $target_path"
fi

files_count="${#all_files[@]}"
declare -a succeeded=() failed_files=() failed_errors=()
skipped=0

for source_file in "${all_files[@]}"; do
    target_file="$(determine_target_path "$source_file" "$files_count")" || exit 1

    if [ "$source_file" = "$target_file" ]; then
        skipped=$(( skipped + 1 ))
        continue
    fi

    if [ "$mode" = copy ]; then
        err="$(safe_copy "$source_file" "$target_file")"
    else
        err="$(safe_move "$source_file" "$target_file")"
    fi
    if [ $? -eq 0 ]; then
        succeeded+=("$source_file")
    else
        failed_files+=("$source_file")
        failed_errors+=("$err")
    fi
done

echo -e "\n${verb_cap} operation completed (${files_count} total):"
print_summary all_files
[ "$skipped" -gt 0 ] && echo "Skipped $skipped file(s) already at target path."
if [ "${#failed_files[@]}" -gt 0 ]; then
    echo -e "\nFailed ${verb_past} (${#failed_files[@]}):"
    for i in "${!failed_files[@]}"; do
        echo "  ${failed_files[$i]}: ${failed_errors[$i]}"
    done
    exit 1
fi
