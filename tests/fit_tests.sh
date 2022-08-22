#!/bin/bash
# This script can be used to test multibyte character lengths, i.e. emoji

shell="$(ps -ef | awk '$2==pid {print $8}' pid=$$ | awk -F'/' '{ print $NF }')"

if [[ $shell =~ 'bash' ]]; then
    echo 'This script is not working in bash because the print command is not available'
    exit 1
elif [[ $shell =~ 'zsh' ]]; then
    cd "$(dirname $0)/.."
else
    echo 'unhandled shell detected - only zsh/bash supported at this time - exiting test script'
    exit 1
fi

source commands.sh

if [ "$1" ]; then
    MULTIBYTE_CHAR_ASCII_CODE_POINTS=(${@})
else
    MULTIBYTE_CHAR_ASCII_CODE_POINTS=(\
        $(seq 9193 9203) 9748 9749 9875 9889 9917 9918 9924 9925 9928 9939 9940 \
        9961 9962 $(seq 9968 9978) 9981 9994 9995 10024 10060 10062 10067 10068 \
        10069 10134 10135 11088 11093 \
    )
fi

for i in ${MULTIBYTE_CHAR_ASCII_CODE_POINTS[@]}
do
    if ! ds:is_int "$i"; then echo "Invalid ascii code point $i" && continue; fi
    printf -v n "%x" $i
    printf "\U$n\n" | awk -v vi=$i '{
        _str=$0
        l=length(_str)
        gsub(/[ -~ -¬®-˿Ͱ-ͷͺ-Ϳ΄-ΊΌΎ-ΡΣ-҂Ҋ-ԯԱ-Ֆՙ-՟ա-և։֊־׀׃׆א-תװ-״]+/, "", _str)
        print "Generating_code_base10", "emoji", "init_awk_len", "len_simple_extract", "len_remaining"
        print vi, $0, l, length(_str), l-length(_str)}'
done \
    > /tmp/emoji # Switch this to tests/data/emoji if updating emoji file

ds:reo /tmp/emoji '1,!~emoji' | awk -f $DS_SUPPORT/wcwidth.awk \
    -f <(print '{
        wcw=wcscolumns($2)
        v=2-wcw
        if(NR==1)
            print $0, "wcscolumns", "var_from_expected"
        else
            print $0, wcw, v ? v : ""
        }') | ds:fit -v bufferchar="|"


rm /tmp/emoji
