#!/bin/bash
set -o pipefail

# Generates a static report of selector elements from a Rails-based QA 
# repo in comparison to other Rails-based view repos - need to add repos
# involved to the VIEW_REPOS array defined below for this to work, and map them
# to the PAGES_DIR variable lower in the script. Besides the aforementioned
# this script makes several assumptions about the way in which page objects are 
# structured and probably needs to be updated to be made useful in contexts of 
# different environments.

# TODO: Update run opts
# TODO: Search for selector usage in unit tests and pages methods
# TODO: Join by selector + attr

# Handle option flags and set conditional variables

DATA_TEST_ONLY='true'
COMPARE_VIEW_REPOS='false'
DISPLAY_DUPLICATES='false'

if (($# == 0)); then
    echo -e "\nNo flags set: Running only for selector definitions in qa_integration_testing pages\n"
    # echo -e "-a  Run for all selectors"
    echo -e "-d  Display duplicate selectors in QA repo in the console: Add arg 0 for QA repo only and 1 for all repos"
    echo -e "-q  Display a table of selectors from the QA repo in the console"
    echo -e "-v  Run a comparison on view repo selector usage"
fi

while getopts ":ad:qs:v" opt; do
    case "$opt" in
        a)  # TODO: Finish this option logic
                DATA_TEST_ONLY='false'
                echo -e "\nAll selectors flag: Running for all selector types\n" ;;
        d)  DISPLAY_DUPLICATES='true'
                case "$OPTARG" in
                    1) echo -e "\nAll repo duplicate selectors console display flag set: To run for QA repo only run with arg 0\n"
             QA_DUPLICATES_ONLY='false'
             RUN_VIEW_REPOS_FOR_DUPLICATES='true';;
                    0) echo -e "\nQA duplicate selectors console display flag set: To run for all repos run with arg 1\n"
             QA_DUPLICATES_ONLY='true' ;;
                    *) echo -e "\nInvalid optional argument for duplicates option: Add arg 0 for QA repo only and 1 for all repos\n"
             exit 1 ;;
                esac
                sleep 2 ;;
        q)  QA_SELECTORS_CONSOLE_DISPLAY='true'
                echo -e "\nQA repo selectors console display flag set\n"
                sleep 1 ;;
        s)  # TODO: Finish this option logic
                SEARCH=$OPTARG
                echo -e "\nSearch flag set: Limiting results to selectors matching pattern\n" ;;
        v)  COMPARE_VIEW_REPOS='true'
                echo -e "\nViews flag set: Running comparison for view repo selector usage\n" ;;
        \?) echo -e "\nInvalid option: -$OPTARG \nValid options include -dqv" >&2 # Update once done
                exit 1;;
    esac
done


# Initialize variables

CYAN="\033[0;36m"
ORANGE="\033[0;33m"
RED="\033[0;31m"
WHITE="\033[1:35m"
NC="\033[0m" # No Color
# Can include false repos here to handle external page objects selectors
VIEW_REPOS=(externalpages)


# Begin script

cd ~/qa_integration_testing

comment_line_re='^[[:blank:]]*#'
end_comment_re='^[[:blank:]]*[^[:space:]#]+.*#'

# For right now filtering on the objects comment. This may result in some
# missing selectors if Object marker comment is missing on valid page objects. 
QA_REPO_SELECTOR_FILES=$(grep -rl '# Objects' pages)
QA_REPO_SELECTOR_DATA=$( \
    printf '%s\n' "${QA_REPO_SELECTOR_FILES[@]}" \
    | xargs awk -v comment_line_re=$comment_line_re -v end_comment_re=$end_comment_re '
        /# Objects/,/# Methods/ { 
            DT_SELECTOR_FOUND=match($0, /data_test_[_[:alnum:]]*/)
            DT_SELECTOR=substr($0, RSTART, RLENGTH)
            gsub(/_/, "-", DT_SELECTOR)
      
            VARNAME_MATCH=match($0, /[A-Z_]{2,}/)
            VARNAME=substr($0, RSTART, RLENGTH)
      
            if($0 ~ comment_line_re) {
                STATUS="COMMENTED"
            } else {
                STATUS="ACTIVE"
            }

            if($0 ~ end_comment_re) {
                match($0, /#[[:space:]]*[[:alnum:]\/]+$/)
                ELEMENT=substr($0, RSTART+1, RLENGTH)
                gsub(/ /, "", ELEMENT)
                if (ELEMENT == "") { ELEMENT="UNPARSEABLEELEMENT" }
            } else {
                ELEMENT="NOELEMENTCOMMENT"
            }

            if( DT_SELECTOR_FOUND ) {
                ATTR_MATCH=match($0, /:.+\}/)
                ATTR=substr($0, RSTART+1, RLENGTH-1)
                gsub(/ /, "", ATTR)
                print FILENAME, VARNAME, DT_SELECTOR, ATTR, ELEMENT, "DATATEST", STATUS
            } else {
                BLOCK_FOUND=match($0, /\{.+\}/)
                SELECTOR=substr($0, RSTART+1, RLENGTH-2)
                gsub(/ /, "", SELECTOR)
                if( BLOCK_FOUND )
                    { print FILENAME, VARNAME, SELECTOR, "NA", ELEMENT, "NONDATATEST", STATUS }
            }
        }                                                                               '
)

if [[ "$COMPARE_VIEW_REPOS" == 'true' || $RUN_VIEW_REPOS_FOR_DUPLICATES == 'true' ]]; then
    VIEW_REPO_DT_SELECTORS=()

    for repo in ${VIEW_REPOS[@]}; do
        cd ~
        if [ -d "${repo}" ] ; then
            cd "${repo}"
            FILES=$(grep -rl 'data-test-' app)
            SELECTORS=($( \
                echo $FILES \
                | xargs awk -v repo="$repo" ' 
                        BEGIN {ORS=" "} {
                            DT_SELECTOR_FOUND=match($0, /data-test-[-[:alnum:]=\"]*/)
                            DT_SELECTOR=substr($0, RSTART, RLENGTH)
                            if(DT_SELECTOR_FOUND)
                                { print repo, FILENAME, DT_SELECTOR }
                            }                                                          ' \
            ))
            VIEW_REPO_DT_SELECTORS=( "${VIEW_REPO_DT_SELECTORS[@]}" "${SELECTORS[@]}" )
        fi
    done
elif [ "$QA_SELECTORS_CONSOLE_DISPLAY" == 'true' ]; then
    echo "${QA_REPO_SELECTOR_DATA[@]}" \
        | awk '{printf "%-60s%-40s%-60s%-25s%-15s\n", $1, $2, $3, $5, $7}'
fi



cd ~

# Join the QA and view repo datasets on selector found using awk. The selector is 
# the third field in both datasets. Requires making two temporary files.
tempqadata=$(mktemp -q /tmp/qaselectordata.txt || echo '/tmp/qaselectordata.txt')
echo "$QA_REPO_SELECTOR_DATA[@]" | sort -k 3 > "$tempqadata"
tempviewdata=$(mktemp -q /tmp/viewselectordata.txt || echo '/tmp/viewselectordata.txt')
printf '%s %s %s\n' "${VIEW_REPO_DT_SELECTORS[@]}" | sort -k 3 > "$tempviewdata"

fmtstr="%s %s %s %s %s %s %s %s %s\n"
nfqa="VDTSNOTFOUNDINQIT"

awk -v tempqadata=$tempqadata -v tempviewdata=$tempviewdata -v nfqa=$nfqa -v fmtstr="$fmtstr" '
    ## Print headers
    NR == 1 {
        printf fmtstr, 
            "VIEWREPO", "VIEWFILE", "PAGESFILE", "VARNAME", "SELECTOR", "ATTRVAL", "ELEMENT", "DATATEST", "STATUS"
    }

    ## Process QA data file the first time. This file has more fields. Join on the third field (selector).
    FILENAME==tempqadata && NR==FNR {
        hash1[ $3 ] = 1
        LR_F1=FNR
        next
    }

    ## Process views data file the first time. Save selector as key for view values.
    FILENAME==tempviewdata && NR-LR_F1==FNR {
        hash2[ $3 ] = $1
        hash3[ $3 ] = $2
        LR_F2=FNR
        next
    }

    ## Process QA data file a second time. Check if selector key is found in the hash.
    FNR == (NR - LR_F1 - LR_F2) { 
        if ( $3 in hash2 ) {
            printf fmtstr, hash2[$3], hash3[$3], $1, $2, $3,  $4, $5, $6, $7
        } else {
            VIEWCHECK=($6 == "DATATEST" ? "NOTFOUNDINVIEW" : "NOTSEARCHEDINVIEW")
            printf fmtstr, VIEWCHECK, VIEWCHECK, $1, $2, $3, $4, $5, $6, $7
        }
    }

    ## Process views data file a second time. Here only need to deal with the unseen case.
    FNR < (NR - LR_F1 - LR_F2) {
        if ( $3 in hash1 ) {
            next
        } else {
            printf fmtstr, $1, $2, nfqa, nfqa, $3, nfqa, nfqa, nfqa, nfqa
        }
    }
' $tempqadata $tempviewdata $tempqadata $tempviewdata \
    | awk 'NR==1; NR > 1 {print $0 | "sort -k 3"}' > selector_data.txt

DUPE_SELECTORS=$(cat selector_data.txt | awk -v qa_only=$QA_DUPLICATES_ONLY -v fmtstr="$fmtstr" '
    {
        if (NR == 1) { print $0 } ## Reprint headers

        if (qa_only == "true" && $3 == "VDTSNOTFOUNDINQIT") { next }

        if (count[$5] > 1)
            { print $0 }
        else if (count[$5] == 1)
            { print save[$5]; print $0 }
        else
            { save[$5] = $0 }
        count[$5]++
    }
')

if [ "$DISPLAY_DUPLICATES" == 'true' ]; then 
    # TODO: Check if any duplicates exist before running awk
    if [ "$QA_DUPLICATES_ONLY" == 'true' ]; then
        awkstr=$(echo '{printf "%-60s%-40s%-65s%-25s%-15s\n", $3, $4, $5, $7, $9}')
    else
        awkstr=$(echo '{printf "%-20s%-75s%-60s%-25s%-25s\n", $1, $2, $3, $4, $5}')
    fi
    echo "${DUPE_SELECTORS[@]}" | awk "$awkstr"
fi

let N_QA_SELECTORS=$(awk '{count++} END{print count}' $tempqadata)
let N_VIEW_SELECTORS=$(awk '{count++} END{print count}' $tempviewdata)
let N_QA_DT_SELECTORS=$(cat selector_data.txt | awk '/[^NON]DATATEST/ {count++} END{print count}')
let N_NOT_FOUND_IN_VIEW=$(grep -c NOTFOUNDINVIEW selector_data.txt)
let N_NOT_FOUND_IN_QA_REPO=$(grep -c VDTSNOTFOUNDINQIT selector_data.txt)
let debug_input_count=$N_QA_SELECTORS+$N_VIEW_SELECTORS-$N_NOT_FOUND_IN_VIEW-$N_NOT_FOUND_IN_QA_REPO

# Remove temporary files
exec 3>"$tempqadata"
exec 4>"$tempviewdata"
rm "$tempqadata"
rm "$tempviewdata"
echo foo >&3
echo bar >&4

# Print statistics
echo -e "${WHITE}Data collection complete. All report data saved to file ~/selector_data.txt${NC}"
echo -e "\n${WHITE}SELECTOR STATISTICS: ${NC}\n"
echo -e "Debug: ${debug_input_count}"
echo -e "${CYAN}${N_QA_SELECTORS}${WHITE} total QA repo selectors found${NC}"
echo -e "${CYAN}${N_QA_DT_SELECTORS}${WHITE} total data-test selectors found in QA repo${NC}"
if [ "$COMPARE_VIEW_REPOS" == 'true' ]; then
    echo -e "${CYAN}${N_VIEW_SELECTORS}${WHITE} total data-test selectors found in view repos${NC}"
    echo -e "${CYAN}${N_NOT_FOUND_IN_VIEW}${WHITE} total QA data-test selectors not found in view repos${NC}"
    echo -e "${CYAN}${N_NOT_FOUND_IN_QA_REPO}${WHITE} total view repo data-test selectors not found in QA repo${NC}"
else
    exit
fi

# Print view comparison report if flag has been set
REPORPTFMT="%s\n"
REPORT_BY_REPO=$(printf "$REPORPTFMT\n" "REPO QIT_DTS_TOTAL VIEW_DTS_TOTAL VIEW_DTS_NOTFOUNDINQIT QIT_DTS_NOTFOUNDINVIEW QIT_NONDTS ALL_QIT_AND_VIEW")

for repo in ${VIEW_REPOS[@]}; do
    cd ~
    case $repo in
        test) PAGESDIR='pages/| pages/| pages/';;
    esac
    if [ $repo == 'externalpages' ]; then
        PAGESDIR='pages/external_pages'
    elif [ ! -d "${repo}" ] ; then
        echo -e "${RED}Repo ${repo} not found. This data may be incomplete.${NC}"
    fi
    let N_QITDTSTOTAL=$(egrep " $PAGESDIR" selector_data.txt | grep -c " DATATEST")
    let N_VIEWDTSTOTAL=$(grep -c "^$repo " selector_data.txt)
    let N_QADTSNOTFOUNDINVIEW=$(egrep " $PAGESDIR" selector_data.txt | grep -c "NOTFOUNDINVIEW")
    let N_QITSNONDT=$(egrep " $PAGESDIR" selector_data.txt | grep -c "NOTSEARCHEDINVIEW")
    let N_VDTSNOTFOUNDQIT=$(grep "^$repo " selector_data.txt | grep -c "$nfqa" || echo 0)
    REPO_DATA=$(printf "$REPORPTFMT" "${repo} \
        ${N_QITDTSTOTAL} \
        ${N_VIEWDTSTOTAL} \
        ${N_VDTSNOTFOUNDQIT} \
        ${N_QADTSNOTFOUNDINVIEW} \
        ${N_QITSNONDT}"
    )
    REPORT_BY_REPO=( "${REPORT_BY_REPO[@]}" "${REPO_DATA}" )
done

let N_QITSNONDT=$(grep -c "NOTSEARCHEDINVIEW" selector_data.txt)
TOTAL_DATA=$(printf "$REPORPTFMT" "TOTALS \
    ${N_QA_DT_SELECTORS} \
    ${N_VIEW_SELECTORS} \
    ${N_NOT_FOUND_IN_QA_REPO} \
    ${N_NOT_FOUND_IN_VIEW} \
    ${N_QITSNONDT}"
)
REPORT_BY_REPO=( "${REPORT_BY_REPO[@]}" "${TOTAL_DATA}" )

echo
printf "$REPORPTFMT" "${REPORT_BY_REPO[@]}" | column -t
echo

