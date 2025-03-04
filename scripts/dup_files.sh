#!/bin/bash
#
# dup_files.sh - Duplicate File Detection and Management Tool
#
# This script identifies and manages duplicate files in a directory structure using
# MD5 checksums for reliable duplicate detection. It can operate on specific file
# types or all files, with options for visualization and duplicate removal.
#
# Features:
# - MD5 checksum-based duplicate detection
# - Optional filename-based duplicate checking
# - Support for both 'find' and 'fd' (faster alternative)
# - Progress visualization with 'pv' (if installed)
# - Selective duplicate removal
# - File extension filtering
# - Support for specific file comparison
#
# Usage: ./dup_files.sh [-adcpuf:s:] [directory]
# Options:
#   -a    Search all files (ignore extension filtering)
#   -c    Check for duplicate filenames
#   -d    Enable duplicate deletion (interactive)
#   -p    Show progress bar (requires pv)
#   -u    Use fd-find for faster file search
#   -f    Compare against specific file
#   -s    Specify source folder
#   -h    Show help
#   -H    Hash algorithm (md5, sha1, sha256, sha512) [default: md5]
#
# Examples:
#   ./dup_files.sh ~/Documents              # Check duplicates in Documents
#   ./dup_files.sh -a -d ~/Pictures         # Find and delete duplicates
#   ./dup_files.sh -f file.txt ~/Downloads  # Find duplicates of file.txt
#   ./dup_files.sh -up ~/Videos            # Fast search with progress bar
#   ./dup_files.sh -H sha256 ~/Documents   # Use SHA256 for comparison
#
# Notes:
# - Default behavior filters by extension unless -a is used
# - Deletion is interactive and requires confirmation
# - Using fd (-u) significantly improves performance
# - Progress bar (-p) requires pv package
#
# Safety:
# - Creates temporary files in /tmp
# - Validates source directory existence
# - Confirms before deletion
# - Handles spaces in filenames
#
# Last Updated: 2025-03-04

set -e  # Exit on error
set -u  # Exit on undefined variable

# Default configuration
TEMP_DIR="${TMPDIR:-/tmp}"
MIN_FILE_SIZE=1  # Skip empty files
SCRIPT_NAME=$(basename "$0")
HASH_METHOD="md5"  # Default hash method

# Function to show usage
show_help() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^#//'
    exit 1
}

# Function to check available hash commands
get_hash_command() {
    local hash_method="$1"
    case "$hash_method" in
        md5)    echo "md5sum" ;;
        sha1)   echo "sha1sum" ;;
        sha256) echo "sha256sum" ;;
        sha512) echo "sha512sum" ;;
        *)      echo "md5sum" ;;  # Default to md5sum
    esac
}

# Function to validate hash method
validate_hash_method() {
    local hash_method="$1"
    local hash_cmd=$(get_hash_command "$hash_method")
    
    if ! command -v "$hash_cmd" >/dev/null 2>&1; then
        echo "Error: Hash command '$hash_cmd' not found"
        echo "Available hash methods:"
        for method in md5 sha1 sha256 sha512; do
            if command -v "$(get_hash_command $method)" >/dev/null 2>&1; then
                echo "  - $method"
            fi
        done
        exit 1
    fi
}

# Function to check dependencies
check_dependencies() {
    local missing=()
    local hash_cmd=$(get_hash_command "$HASH_METHOD")
    [ ! -x "$(command -v $hash_cmd)" ] && missing+=("$hash_cmd")
    [ "$PV" = true ] && [ ! -x "$(command -v pv)" ] && missing+=("pv")
    [ "$FD" = true ] && [ ! -x "$(command -v fd)" ] && missing+=("fd")
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing[*]}"
        exit 1
    fi
}

# Function to validate directory
validate_directory() {
    if [ ! -d "$1" ]; then
        echo "Error: Directory '$1' does not exist"
        exit 1
    fi
}

# Function to cleanup temporary files
cleanup() {
    local exit_code=$?
    [ -f "$tempdata" ] && rm -f "$tempdata"
    # Restore cursor and clear line if interrupted
    [ $exit_code -ne 0 ] && echo -en "\033[?25h\033[K"
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Initialize variables
all_files=false
check_filenames=false
delete=false
PV=false
FD=false
of_file=""
source_folder=""

while getopts ":adcpuf:s:H:h" opt; do
    case $opt in
        a)  all_files=true ;;
        c)  check_filenames=true ;;
        d)  delete=true ;;
        p)  PV=true ;;
        u)  FD=true ;;
        f)  of_file="$OPTARG" ;;
        s)  source_folder="$OPTARG" ;;
        H)  HASH_METHOD="$OPTARG" ;;
        h)  show_help ;;
        \?) echo "Error: Invalid option -$OPTARG" >&2; show_help ;;
        :)  echo "Error: Option -$OPTARG requires an argument" >&2; show_help ;;
    esac
done

# Shift past the parsed options
shift $((OPTIND-1))

# Set source folder from positional argument if not set with -s
[ -z "$source_folder" ] && source_folder="${1:-.}"

# Validate inputs
validate_directory "$source_folder"
[ -n "$of_file" ] && [ ! -f "$of_file" ] && echo "Error: File '$of_file' not found" && exit 1

# Check dependencies
check_dependencies

# Validate hash method before proceeding
validate_hash_method "$HASH_METHOD"
HASH_CMD=$(get_hash_command "$HASH_METHOD")

# Create temporary file
tempdata=$(mktemp -q "$TEMP_DIR/filedata.XXXXX") || {
    echo "Error: Failed to create temporary file"
    exit 1
}

# Function to format file size
format_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        printf "%.1fG" $(echo "$size/1073741824" | bc -l)
    elif [ $size -ge 1048576 ]; then
        printf "%.1fM" $(echo "$size/1048576" | bc -l)
    elif [ $size -ge 1024 ]; then
        printf "%.1fK" $(echo "$size/1024" | bc -l)
    else
        echo "${size}B"
    fi
}

# Colors for output
if [ -t 1 ]; then
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    NC="\033[0m"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    NC=""
fi

echo -e "\n${BLUE}Scanning directory: ${NC}$source_folder"
echo -e "${BLUE}Using hash method: ${NC}$HASH_METHOD"

# Process files based on options
if [[ "$of_file" && ! $all_files ]]; then
    of_file_cksum="$($HASH_CMD "$of_file" | awk '{print $1}')"
    of_file_filename=$(basename "$of_file")
    of_file_extension=$([[ "$of_file_filename" = *.* ]] && echo ".${of_file_filename##*.}" || echo '')
    echo -e "${YELLOW}Searching for duplicates of: ${NC}$of_file_filename"
fi

echo -e "\n${BLUE}Gathering checksum data...${NC}"

# Limit search to only files of same extension type by default

if [[ "$of_file" && ! $all_files ]]; then
    # pv provides a way to view the status and probable completion time of a process
    if [ $PV ]; then
        if [ $FD ]; then
            fd . "$source_folder" -H --type f -e "$of_file_extension" --exec $HASH_CMD "{}" \; \
                | pv -l -s $(fd . "$source_folder" -H --type f -e "$of_file_extension" | wc -l) | sort > $tempdata
        else
            find "$source_folder" -type f -name "*$of_file_extension" -exec $HASH_CMD "{}" \; \
                | pv -l -s $(find "$source_folder" -type f -name "*$of_file_extension" | wc -l) | sort > $tempdata
        fi
    else
        if [ $FD ]; then
            fd . "$source_folder" -H --type f -e "$of_file_extension" --exec $HASH_CMD "{}" \; | sort > $tempdata
        else
            find "$source_folder" -type f -name "*$of_file_extension" -exec $HASH_CMD "{}" \; | sort > $tempdata
        fi
    fi
else
    if [ $PV ]; then
        if [ $FD ]; then
            fd . "$source_folder" -H --type f --exec $HASH_CMD "{}" \; \
                | pv -l -s $(fd . "$source_folder" -H --type f | wc -l) | sort >$tempdata
        else
            find "$source_folder" -type f -exec $HASH_CMD "{}" \; \
                | pv -l -s $(find "$source_folder" -type f | wc -l) | sort >$tempdata
        fi
    else
        if [ $FD ]; then
            fd . "$source_folder" -H --type f --exec $HASH_CMD "{}" \; | sort > $tempdata
        else
            find "$source_folder" -type f -exec $HASH_CMD "{}" \; | sort > $tempdata
        fi
    fi
fi

files=$(cat "$tempdata" | awk '{print substr($0,length($1)+3)}')
count_files=$(cat "$tempdata" | wc -l | xargs)
assured=$(cat "$tempdata" | awk -v of_file_cksum="$of_file_cksum" '
    of_file_cksum {
        if ($1 == of_file_cksum) print $2; next
    }
    {
        md5 = $1
        filename = substr($0,length(md5)+3)
        md5s[md5]++
        filenames[filename] = md5
        if (md5s[md5] == 1) {base_filename[md5] = filename}
        else if (length(filename) < length(base_filename[md5])) {
            base_filename[md5] = filename
        }
    }
    END {
        for (filename in filenames) {
            md5 = filenames[filename]
 
            if (md5s[md5] > 1 && base_filename[md5] != filename) {
                printf "%-100s|||%-100s\n", base_filename[md5], filename
            }
        }
    }
')
let md5dup_count=$(echo "$assured" | wc -l | xargs)
[ -z "$of_file" ] && let md5dup_count-=1

# Improve duplicate display format
if [ $md5dup_count -gt 1 ]; then
    echo -e "\n${GREEN}Found $md5dup_count duplicate files:${NC}\n"
    if [ "$of_file" ]; then
        echo "$assured" | while IFS= read -r line; do
            orig=$(echo "$line" | cut -d'|' -f1 | xargs)
            dup=$(echo "$line" | cut -d'|' -f2 | xargs)
            orig_size=$(stat -f %z "$orig")
            echo -e "${YELLOW}Original: ${NC}$orig ${BLUE}($(format_size $orig_size))${NC}"
            echo -e "${RED}Duplicate: ${NC}$dup"
            echo
        done
    else
        echo "$assured" | while IFS= read -r line; do
            if [ "$line" = "DUPLICATE|||COMPDUPLICATE" ]; then
                echo -e "${YELLOW}Original File${NC}${BLUE} (Size)${NC} | ${RED}Duplicate File${NC}"
                echo "----------------------------------------+----------------------------------------"
            else
                orig=$(echo "$line" | cut -d'|' -f1 | xargs)
                dup=$(echo "$line" | cut -d'|' -f2 | xargs)
                orig_size=$(stat -f %z "$orig")
                echo -e "${YELLOW}$orig ${BLUE}($(format_size $orig_size))${NC} | ${RED}$dup${NC}"
            fi
        done

        if [ $delete ]; then
            echo
            echo -e "${YELLOW}Delete duplicates?${NC}"
            echo "  l) Remove files in left column"
            echo "  r) Remove files in right column"
            echo "  n) Keep all files"
            read -p "Choice [l/r/n]: " choice

            case $choice in
                l|L) 
                    echo -e "\n${RED}Removing original files...${NC}"
                    echo "$assured" | awk -F"\\\|\\\|\\\|" '{if (NR==1) {next};
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}' | 
                        sed -e "s/'/\\\\'/g" | xargs -I % rm -v "%"
                    ;;
                r|R)
                    echo -e "\n${RED}Removing duplicate files...${NC}"
                    echo "$assured" | awk -F"\\\|\\\|\\\|" '{if (NR==1) {next};
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}' |
                        sed -e "s/'/\\\\'/g" | xargs -I % rm -v "%"
                    ;;
                *)
                    echo -e "\n${GREEN}No files removed.${NC}"
                    ;;
            esac
        fi
    fi
else
    echo -e "\n${GREEN}No duplicates found.${NC}"
fi

if [ "$check_filenames" ]; then
    echo -e "\n${BLUE}Checking for duplicate filenames...${NC}"

    # If no other directory levels exist past the source, all files can be assumed
    # to have unique names, so looking for possible duplicates using name is a waste.
    dir_count=$(find "$source_folder" -maxdepth 1 -type d | wc -l | xargs)

    if [ $dir_count -gt 1 ]; then 
        if [ "$of_file" ]; then
            of_file_basename="$(basename -a "$of_file")"
            if [ "$FD" ]; then
                dup_filenames=$(fd --type f "^$of_file_filename(\.|$)" "$source_folder")
            else
                dup_filenames=$(find "$source_folder" -type f -name "$of_file_filename\\.*")
            fi
        else
            echo -e "${BLUE}Analyzing filenames...${NC}"
            filenames=$(printf "%s\n" "${files[@]}" | sed -e "s/'/\\\\'/g" | xargs -I % basename -a "%" )
            filedata=$(paste <(echo "${filenames[@]}") <(echo "${files[@]}"))
            dup_filenames=$(echo "${filedata[@]}" | awk -F"\t" '
                {
                    file=$1
                    path=$2
                    count[file]++
                    if (count[file] == 1) {
                        first[file]=path
                    } else if (count[file] == 2) {
                        print "\n" file ":"
                        print "  " first[file]
                        print "  " path
                    } else {
                        print "  " path
                    }
                }
            ')
        fi
    
        dup_name_count=$(echo "$dup_filenames" | grep -c ":" || true)
    
        if [ $dup_name_count -gt 0 ]; then
            echo -e "\n${YELLOW}Found files with identical names in different locations:${NC}"
            echo "$dup_filenames"
            if [ "$of_file" ]; then
                echo -e "\n${BLUE}Note:${NC} Target file \"$of_file\" may be included in this list."
            fi
        else
            echo -e "${GREEN}No duplicate filenames found.${NC}"
        fi
    else
        echo -e "${GREEN}No subdirectories found - skipping filename check.${NC}"
    fi
fi

# Cleanup temporary files
[ -f "$tempdata" ] && rm -f "$tempdata"

# Print summary
echo -e "\n${BLUE}Summary:${NC}"
echo -e "  Scanned files: ${GREEN}$count_files${NC}"
echo -e "  Found duplicates: ${YELLOW}$md5dup_count${NC}"
if [ "$check_filenames" ] && [ $dir_count -gt 1 ]; then
    echo -e "  Files with duplicate names: ${YELLOW}$dup_name_count${NC}"
fi
echo


