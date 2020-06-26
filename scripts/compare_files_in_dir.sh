#!/bin/bash

tempdata=$(mktemp -q /tmp/filedata.XXXXX || echo '/tmp/filedata.XXXXX')
source_folder="$1"

echo -e "\n Gathering data... \n"
find "$source_folder" -type f -exec md5sum "{}" \; | pv -l -s $(find "$source_folder" -type f | wc -l)> $tempdata
# pv provides a way to view the completion status of processes

files=$(cat "$tempdata" | awk '{print substr($0,length($1)+3)}')
count_files=$(cat "$tempdata" | wc -l)
assured=$(cat "$tempdata" | awk '
  {
    if (NR == 1) {print "Duplicates                                                                CompareFile"}
    md5s[$1]++i;
    if (md5s[$1] == 1) {filename[$1] = substr($0,length($1)+1)};
    if (md5s[$1] > 1)  {print substr($0,length($1)+1), filename[$1]}
  }
')
md5dup_count=$(echo "$assured" | wc -l)

if [ $md5dup_count -gt 1 ]; then
  echo -e "\n Assured duplicates in md5 checksums: \n"
  echo "$assured"
  echo ""
  read -p " Would you like to remove the set of files on the left, on the right, or neither? (l/r/n) " choice

  if [ $choice == 'l' ]; then
    echo "$assured" | awk -F"   " '{if (NR==1) {next}; print substr($1,3,length($1))}' | sed -e "s/'/\\\\'/g" | xargs -I % rm "%"
    echo -e "\n Attempted removal of ${md5dup_count} duplicates."
  elif [ $choice == 'r' ]; then
    echo "$assured" | awk -F"   " '{if (NR==1) {next}; print substr($0,length($1)+4,length($0))}' | sed -e "s/'/\\\\'/g" | xargs -I % rm "%"
    echo -e "\n Attempted removal of the files in the right column."
  else
    echo -e "\n No duplicates removed."
  fi
else
  echo -e "\n No duplicates found in md5 checksums."
fi

echo -e "\n ++++++++++++++++++++++++++++ \n"

# If no other directory levels exist past the source, all files can be assumed
# to have unique names, so looking for possible duplicates using name is a waste.
dir_count=$(find "$source_folder" -maxdepth 1 -type d | wc -l)
if [ $dir_count -gt 1 ]; then 
  filenames=$(printf "%s\n" "${files[@]}" | sed -e "s/'/\\\\'/g" | xargs -I % basename -a "%" )
  filedata=$(paste <(echo "${filenames[@]}") <(echo "${files[@]}"))
  dup_filenames=$(echo "${filedata[@]}" | awk -F"\t" '{_[$1]++; if(_[$1] == 2) {print $1}}') # only returns second duplicate
  dup_name_count=$(echo "$dup_filenames" | wc -l)
  empty=$(if [[ $dup_name_count == 1 && ($dup_filenames == "\n" || $dup_filenames == '') ]]; then echo 'true'; else echo 'false'; fi)
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


