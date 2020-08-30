#!/bin/bash
#
# Checks a directory for duplicate files and provides user an option to remove
# duplicates if desired
#
# TODO: Tempfile


while getopts ":fps:" opt; do
  case $opt in
    f)  FD=true ;;
    p)  PV=true ;;
    s)  source_folder="$OPTARG" ;;
    \?) echo -e "\nInvalid option: -$opt \nValid options include [-fp]" >&2
        exit 1 ;;
  esac
done

tempdata=$(mktemp -q /tmp/filedata.XXXXX || echo '/tmp/filedata.XXXXX')
[ -z $source_folder ] && source_folder="$1"

echo -e "\n Gathering checksum data... \n"
if [ $PV ]; then
  if [ $FD ]; then
    fd . "$source_folder" -H --type f --exec md5sum "{}" \; \
      | pv -l -s $(fd . "$source_folder" -H --type f | wc -l)> $tempdata
  else
    find "$source_folder" -type f -exec md5sum "{}" \; \
      | pv -l -s $(find "$source_folder" -type f | wc -l)> $tempdata
  fi
else
  if [ $FD ]; then
    fd . "$source_folder" -H --type f --exec md5sum "{}" \; > $tempdata
  else
    find "$source_folder" -type f -exec md5sum "{}" \; > $tempdata
  fi
fi
# pv provides a way to view the completion status of processes

files=$(cat "$tempdata" | awk '{print substr($0,length($1)+3)}')
count_files=$(cat "$tempdata" | wc -l)
assured=$(cat "$tempdata" | awk '
  {
    if (NR == 1) {printf "%-100s|||%-100s\n", "DUPLICATE", "COMPDUPLICATE"}
    md5s[$1]++
    if (md5s[$1] == 1) {filename[$1] = substr($0,length($1)+3)};
    if (md5s[$1] > 1)  {printf "%-100s|||%-100s\n", substr($0,length($1)+3), filename[$1]}
  }
')
md5dup_count=$(echo "$assured" | wc -l)

if [ $md5dup_count -gt 1 ]; then
  echo -e "\n Assured duplicates in md5 checksums: \n"
  echo "$assured" | awk -F"\\\|\\\|\\\|" '{print}'
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
else
  echo -e "\n No duplicates found in md5 checksums."
fi

echo -e "\n ++++++++++++++++++++++++++++ \n"

# If no other directory levels exist past the source, all files can be assumed
# to have unique names, so looking for possible duplicates using name is a waste.
dir_count=$(find "$source_folder" -maxdepth 1 -type d | wc -l)
if [ $dir_count -gt 1 ]; then 
  echo -e " Gathering filename data... \n"
  filenames=$(printf "%s\n" "${files[@]}" | sed -e "s/'/\\\\'/g" | xargs -I % basename -a "%" )
  filedata=$(paste <(echo "${filenames[@]}") <(echo "${files[@]}"))
  dup_filenames=$(echo "${filedata[@]}" | awk -F"\t" '{_[$1]++; if(_[$1] == 2) {print $1}}') # only returns second duplicate
  dup_name_count=$(echo "$dup_filenames" | wc -l)
  empty=$([[ $dup_name_count == 1 && ($dup_filenames == "\n" || $dup_filenames == '') ]] && echo true ||  echo false)
  if [[ $empty == 'false' && $dup_name_count -gt 0 ]]; then
    echo -e " Duplicate filenames found: \n"
    echo "$dup_filenames"
  else
    echo -e " No duplicate filenames found. \n" 
  fi
else
  echo -e " No duplicate filenames found. \n"
fi

# Remove temporary file
exec 3>"$tempdata"
rm "$tempdata"
echo foo >&3


