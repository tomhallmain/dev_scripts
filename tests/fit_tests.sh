#!/bin/bash
if [[ $shell =~ 'bash' ]]; then
    bsh=0
    cd "${BASH_SOURCE%/*}/.."
elif [[ $shell =~ 'zsh' ]]; then
    cd "$(dirname $0)/.."
else
    echo 'unhandled shell detected - only zsh/bash supported at this time - exiting test script'
    exit 1
fi
source commands.sh

for i in $(seq 9193 9203) 9748 9749 9875 9889 9917 9918 9924 9925 9928 9939 9940 9961 9962 $(seq 9968 9978) 9981 9994 9995 10024 10060 10062 10067 10068 10069 10134 10135 11088 11093
do
    printf -v n "%x" $i
    printf "\U$n\n" | awk -v vi=$i '{
        _str=$0
        l=length(_str)
        gsub(/[ -~ -¬®-˿Ͱ-ͷͺ-Ϳ΄-ΊΌΎ-ΡΣ-҂Ҋ-ԯԱ-Ֆՙ-՟ա-և։֊־׀׃׆א-תװ-״]+/, "", _str)
        print "Generating_code_base10", "emoji", "init_awk_len", "len_simple_extract", "len_remaining"
        print vi, $0, l, length(_str), l-length(_str)}'
done > tests/data/emoji
ds:reo tests/data/emoji '1,!~emoji' | awk -f $DS_SUPPORT/wcwidth.awk \
    -f <(print '{
        wcw=wcscolumns($2)
        v=2-wcw
        if(NR==1)
            print $0, "wcscolumns", "var_from_expected"
        else
            print $0, wcw, v ? v : ""
        }') | ds:fit -v bufferchar="|"

