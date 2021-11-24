#!/bin/bash
#
# Checks a directory for duplicate files and provides user an option to remove
# duplicates if desired

while getopts ":adcpuf:s:" opt; do
    case $opt in
        a)  all_files=true ;;
        c)  check_filenames=true ;;
        d)  delete=true ;;
        p)  PV=true ;;
        u)  FD=true ;;
        f)  of_file="$OPTARG" ;;
        s)  source_folder="$OPTARG" ;;
        ?) echo -e "\nInvalid option: -$opt \nValid options include [-afpsu]" >&2
                exit 1 ;;
    esac
done

tempdata=$(mktemp -q /tmp/filedata.XXXXX || echo '/tmp/filedata.XXXXX')
[ -z "$source_folder" ] && source_folder="$1"

if [ "$of_file" ]; then
    of_file_cksum="$(md5sum "$of_file" | awk '{print $1}')"
    of_file_filename=$(basename "$of_file")
    of_file_extension=$([[ "$of_file_filename" = *.* ]] && echo ".${of_file_filename##*.}" || echo '')
fi

if [ ! "$FD" ]; then
    echo -e "WARNING: Using \"find\" to search for files which may be slow."
    echo -e "Consider installing \"fd\" (fd-find) for improved performance."
fi

echo -e "\n Gathering checksum data... \n"

# Limit search to only files of same extension type by default

if [[ "$of_file" && ! $all_files ]]; then
    # pv provids a way to view the status and probable completion time of a process
    if [ $PV ]; then
        if [ $FD ]; then
            fd . "$source_folder" -H --type f -e "$of_file_extension" --exec md5sum "{}" \; \
                | pv -l -s $(fd . "$source_folder" -H --type f -e "$of_file_extension" | wc -l) | sort > $tempdata
        else
            find "$source_folder" -type f -name "*$of_file_extension" -exec md5sum "{}" \; \
                | pv -l -s $(find "$source_folder" -type f -name "*$of_file_extension" | wc -l) | sort > $tempdata
        fi
    else
        if [ $FD ]; then
            fd . "$source_folder" -H --type f -e "$of_file_extension" --exec md5sum "{}" \; | sort > $tempdata
        else
            find "$source_folder" -type f -name "*$of_file_extension" -exec md5sum "{}" \; | sort > $tempdata
        fi
    fi
else
    if [ $PV ]; then
        if [ $FD ]; then
            fd . "$source_folder" -H --type f --exec md5sum "{}" \; \
                | pv -l -s $(fd . "$source_folder" -H --type f | wc -l) | sort >$tempdata
        else
            find "$source_folder" -type f -exec md5sum "{}" \; \
                | pv -l -s $(find "$source_folder" -type f | wc -l) | sort >$tempdata
        fi
    else
        if [ $FD ]; then
            fd . "$source_folder" -H --type f --exec md5sum "{}" \; | sort > $tempdata
        else
            find "$source_folder" -type f -exec md5sum "{}" \; | sort > $tempdata
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

if [ $md5dup_count -gt 1 ]; then
    echo -e "\n Assured duplicates in md5 checksums: \n"
    if [ "$of_file" ]; then
        echo "$assured" | sort -V
        echo -e "\n Target file \"$of_file\" may be included in this list."
    else
        printf "%-100s|||%-100s\n" "DUPLICATE" "COMPDUPLICATE"
        echo "$assured" | awk -F"\\\|\\\|\\\|" '{print}' | sort -V
        

        if [ $delete ]; then
            echo
            read -p " Would you like to remove the set of files on the left, on the right, or neither? (l/r/n) " choice

            if [ $choice == 'l' ]; then
                echo "$assured" | awk -F"\\\|\\\|\\\|" '{if (NR==1) {next};
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}' | sed -e "s/'/\\\\'/g" | xargs -I % rm "%"
                echo -e "\n Attempted removal of ${md5dup_count} duplicates."
            elif [ $choice == 'r' ]; then
                echo "$assured" | awk -F"\\\|\\\|\\\|" '{if (NR==1) {next};
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}' | sed -e "s/'/\\\\'/g" | xargs -I % rm "%"
                echo -e "\n Attempted removal of the files in the right column."
            else
                echo -e "\n No files removed."
            fi
        fi
    fi
else
    echo -e "\n No duplicates found in md5 checksums."
fi

if [ "$check_filenames" ]; then
    echo -e "\n ++++++++++++++++++++++++++++ \n"

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
            echo -e " Gathering filename data... \n"
            filenames=$(printf "%s\n" "${files[@]}" | sed -e "s/'/\\\\'/g" | xargs -I % basename -a "%" )
            filedata=$(paste <(echo "${filenames[@]}") <(echo "${files[@]}"))
            dup_filenames=$(echo "${filedata[@]}" | awk -F"\t" '{_[$1]++; if(_[$1] == 2) {print $1}}') # only returns second duplicate
        fi
    
        dup_name_count=$(echo "$dup_filenames" | wc -l | xargs)
    
        if [[ $dup_name_count -eq 1 && ($dup_filenames == "\n" || $dup_filenames == '') ]]; then
            has_dups=""
        else
            has_dups=0
        fi
    
        if [[ $has_dups && $dup_name_count -gt 0 ]]; then
            echo -e " Possible duplicate filenames found: \n"
            echo "$dup_filenames"
            if [ "$of_file" ]; then
                echo -e "\n Target file \"$of_file\" may be included in this list."
            fi
        else
            echo -e " No duplicate filenames found. \n" 
        fi
    else
        echo -e " No duplicate filenames found. \n"
    fi
fi

# Remove temporary file
exec 3>"$tempdata"
rm "$tempdata"
echo foo >&3


