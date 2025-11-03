#!/usr/bin/awk
#
# SYNOPSIS
#      ds:case [string|file] [tocase=proper] [filter]
#
# DESCRIPTION
#      Recase text data with advanced case transformation options.
#
#      Send data to ds:case via pipe, in a text file or a string.
#
#      For the purposes of camel, snake, and variable case, each line
#      is treated as a single joined output.
#
#      If set, [filter] is regex used to only case rows that match.
#
# CASE OUTPUT OPTIONS
#      lowercase      l[ower][case] || lc || d[own][case]
#                    example: "hello world"
#
#      UPPERCASE      u[pper][case] || uc
#                    example: "HELLO WORLD"
#
#      Proper Case    p[roper][case] || pc
#                    example: "Hello World"
#
#      camelCase      c[amel][case] || cc
#                    example: "helloWorld"
#
#      UpperCamelCase uppercamel || ucc
#                    example: "HelloWorld"
#
#      snake_case     s[nake][case] || sc
#                    example: "hello_world"
#
#      VARIABLE_CASE  v[ar][ariable][case] || vc
#                    example: "HELLO_WORLD"
#
#      Object.Case    o[bject][case] || oc
#                    example: "Hello.World"
#
#      kebab-case     k[ebab][case] || kc
#                    example: "hello-world"
#
#      path/case      p[ath][case] || pathc
#                    example: "hello/world/file"
#
#      dot.case       d[ot][case] || dc
#                    example: "hello.world.file"
#
#      Title Case     t[itle][case] || tc
#                    example: "The Quick Brown Fox"
#
#      sentence case  s[entence][case] || senc
#                    example: "The quick brown fox"
#
#      alternating    a[lt][ernating][case] || ac
#                    example: "hElLo WoRlD"
#
# OPTIONS
#      smart=1       Enable smart casing (preserve acronyms, units)
#      preserve=STR  Characters to preserve case for (e.g., "pH SQL")
#      strict=1      Strict title case following Chicago Manual
#      boundary=1    Enable smart word boundary detection
#

BEGIN {
    tocase = tolower(tocase)
    
    if (!tocase)
        pass = 1
    else if ("lowercase" ~ "^"tocase || "downcase" ~ "^"tocase || tocase ~ "^lc(ase)?$")
        lc = 1
    else if ("uppercase" ~ "^"tocase || tocase ~ "^uc(ase)?$")
        uc = 1
    else if ("propercase" ~ "^"tocase || tocase ~ "^pc(ase)?$")
        pc = 1
    else if ("camelcase" ~ "^"tocase || tocase ~ "^cc(ase)?$")
        cc = 1
    else if ("uppercamelcase" ~ "^"tocase || tocase == "ucc")
        ucc = 1
    else if ("snakecase" ~ "^"tocase || tocase ~ "^sc(ase)?$")
        sc = 1
    else if ("varcase" ~ "^"tocase || "variablecase" ~ "^"tocase || tocase ~ "^vc(ase)?$")
        vc = 1
    else if ("objectcase" ~ "^"tocase || tocase ~ "^oc(ase)?$")
        oc = 1
    else if ("kebabcase" ~ "^"tocase || tocase ~ "^kc(ase)?$")
        kc = 1
    else if ("pathcase" ~ "^"tocase || tocase ~ "^pathc(ase)?$")
        pathc = 1
    else if ("dotcase" ~ "^"tocase || tocase ~ "^dc(ase)?$")
        dc = 1
    else if ("titlecase" ~ "^"tocase || tocase ~ "^tc(ase)?$")
        tc = 1
    else if ("sentencecase" ~ "^"tocase || tocase ~ "^senc(ase)?$")
        senc = 1
    else if ("alternatingcase" ~ "^"tocase || "altcase" ~ "^"tocase || tocase ~ "^ac(ase)?$")
        ac = 1
    
    # Initialize preserved terms
    if (preserve) {
        split(preserve, PreservedTerms, " ")
        for (term in PreservedTerms)
            Preserved[PreservedTerms[term]] = 1
    }
    
    # Common acronyms and units for smart casing
    if (smart) {
        # Technical acronyms
        split("SQL HTTP XML JSON API REST URL URI ID HTML CSS PHP AWS DNS TCP IP FTP SSH SSL TLS GPU CPU RAM ROM I/O UTF UTF-8 ASCII ANSI ISO", TechAcronyms)
        for (i in TechAcronyms)
            Preserved[TechAcronyms[i]] = 1
            
        # Common units and scientific notation
        split("pH kB MB GB TB PB mA kW MW GW Hz kHz MHz GHz °C °F K m² m³ cm² cm³ km² km³", Units)
        for (i in Units)
            Preserved[Units[i]] = 1
            
        # Common product/brand names
        split("iPhone iPad macOS iOS Android PostgreSQL MySQL MariaDB MongoDB Redis npm Node.js Vue.js React.js", Products)
        for (i in Products)
            Preserved[Products[i]] = 1
            
        # Common abbreviations
        split("Mr Mrs Ms Dr Jr Sr Prof Inc Ltd Co Corp etc i.e e.g vs viz", Abbrev)
        for (i in Abbrev)
            Preserved[Abbrev[i]] = 1
    }
}

filter && !($0 ~ filter) { next }

lc { print L($0); next }

uc { print U($0); next }

pass { print; next }

{
    line = $0
    line = PrepareLine(line)
    n_wds = split(line, Words, " ")
}

pc {
    for (i = 1; i < n_wds; i++)
        printf "%s", GenPC(Words[i], i) " "
    print GenPC(Words[n_wds]); next
}

tc {
    for (i = 1; i < n_wds; i++)
        printf "%s", GenTC(Words[i], i) " "
    print GenTC(Words[n_wds]); next
}

senc {
    printf "%s", GenTC(Words[1], 1) " "
    for (i = 2; i < n_wds; i++)
        printf "%s", L(Words[i]) " "
    print L(Words[n_wds]); next
}

cc || ucc {
    for (i = 1; i < n_wds; i++) {
        if (ucc) {
            printf "%s", GenCC(Words[i], 2)
        }
        else {
            printf "%s", GenCC(Words[i], i)
        }
    }
    print GenCC(Words[n_wds], n_wds); next
}

sc {
    for (i = 1; i < n_wds; i++)
        printf "%s", L(Words[i]) "_"
    print L(Words[n_wds]); next
}

kc {
    for (i = 1; i < n_wds; i++)
        printf "%s", L(Words[i]) "-"
    print L(Words[n_wds]); next
}

vc {
    for (i = 1; i < n_wds; i++)
        printf "%s", U(Words[i]) "_"
    print U(Words[n_wds]); next
}

oc {
    for (i = 1; i < n_wds; i++)
        printf "%s", GenPC(Words[i]) "."
    print GenPC(Words[n_wds])
}

ac {
    result = ""
    str = $0
    for (i = 1; i <= length(str); i++) {
        c = substr(str, i, 1)
        if (c ~ /[[:space:]]/)
            result = result c
        else
            result = result (i % 2 ? L(c) : U(c))
    }
    print result; next
}

pathc {
    for (i = 1; i < n_wds; i++)
        printf "%s", L(Words[i]) "/"
    print L(Words[n_wds]); next
}

dc {
    for (i = 1; i < n_wds; i++)
        printf "%s", L(Words[i]) "."
    print L(Words[n_wds]); next
}

function U(s) {
    return IsPreserved(s) ? s : toupper(s)
}

function L(s) {
    return IsPreserved(s) ? s : tolower(s)
}

function SS(str, start, end) {
    return substr(str, start, end)
}

function PrepareLine(line) {
    if (boundary) {
        # Smart word boundary detection
        # Handle CamelCase
        gsub(/([a-z])([A-Z])/, "\\1 \\2", line)
        # Handle numbers in words
        gsub(/([a-zA-Z])([0-9])/, "\\1 \\2", line)
        gsub(/([0-9])([a-zA-Z])/, "\\1 \\2", line)
        # Handle multiple consecutive uppercase letters followed by lowercase
        gsub(/([A-Z]+)([A-Z][a-z])/, "\\1 \\2", line)
        # Handle special characters
        gsub(/[-_\.\/]/, " ", line)
        # Handle parentheses and brackets
        gsub(/[\(\)\[\]\{\}]/, " & ", line)
    } else {
        gsub(/[_\.\/-]/, " ", line)
    }
    gsub(/ +/, " ", line)
    return boundary ? line : SpaceCasevars(line)
}

function SpaceCasevars(s) {
    if (boundary) return s
    while (match(s, /[a-z][A-Z]/)) {
        s = SS(s, 1, RSTART) " " SS(s, RSTART + 1, length(s) - RSTART)
    }
    return s
}

function IsPreserved(word) {
    if (smart && (word in Preserved)) return 1
    if (smart && word ~ /^[A-Z]{2,}[a-z]*$/) return 1  # Likely an acronym
    if (smart && word ~ /^[A-Z][a-z]+[A-Z]/) return 1  # Likely a product name
    if (smart && word ~ /^(v|V)[0-9]+(\.[0-9]+)*$/) return 1  # Version numbers
    if (smart && word ~ /^[0-9]+[A-Za-z]+$/) return 1  # Units with numbers
    return 0
}

function GenPC(word, idx) {
    if (IsPreserved(word)) return word
    if (IsCompoundWord(word)) {
        # Handle compound words specially
        gsub(/-/, " ", word)
        n = split(word, parts, " ")
        result = ""
        for (i = 1; i <= n; i++) {
            if (i > 1) result = result "-"
            result = result GenPC(parts[i], idx)
        }
        return result
    }
    if (idx < 2)
        return U(SS(word, 1, 1)) L(SS(word, 2, length(word)))
    else if (word ~ /^(and|as|but|for|if|nor|or|so|yet|a|an|the|upon|from|as|at|by|for|in|of|off|on|per|to|up|via)$/)
        return word
    else
        return U(SS(word, 1, 1)) L(SS(word, 2, length(word)))
}

function GenTC(word, idx) {
    if (IsPreserved(word)) return word
    if (!strict) return GenPC(word, idx)
    
    # Chicago Manual of Style rules
    if (idx == 1 || idx == n_wds) return GenPC(word, 1)
    if (length(word) >= 4) return GenPC(word, 1)
    if (word ~ /^(and|as|but|for|if|nor|or|so|yet|a|an|the|upon|from|as|at|by|for|in|of|off|on|per|to|up|via)$/)
        return L(word)
    return GenPC(word, 1)
}

function GenCC(word, idx) {
    if (IsPreserved(word)) return word
    if (idx == 1)
        start_char = L(SS(word, 1, 1))
    else
        start_char = U(SS(word, 1, 1))
    
    return start_char L(SS(word, 2, length(word)))
}

# Enhanced word boundary detection for compound words
function IsCompoundWord(word) {
    return word ~ /^(e-mail|co-op|pre-|post-|non-|self-|cross-|multi-|inter-|intra-|ultra-)/
}

