#!/usr/bin/awk
{
    line = $0
    save_line = line
    gsub(/[ -~ -¬®-˿Ͱ-ͷͺ-Ϳ΄-ΊΌΎ-ΡΣ-҂Ҋ-ԯԱ-Ֆՙ-՟ա-և։֊־׀׃׆א-תװ-״]+/, "", line)
    exit (length(line) == length(save_line))
}
