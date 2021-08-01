#!/usr/bin/awk
#
# Script to return a population of entities within curly braces in 
# a language wwhere comments are marked by pound sign or two forward slashes
#
# > awk -f curlies.awk file
#
## TODO multiline and language-specific comment handling
## TODO maybe try simple shift of base level from 1 to 2 for java function/class searches
## 1-base index (entityCounter)
## 2-depth index (curly)
## 3-atDepth index

BEGIN {
    curly = 0
    innerBrace = 1
    entityCounter = 0
    OpenEntities[0, 0] = 1
  
    if (search) {
        searching = 1
        searchCase = 1
    }
}

NR > 1 {
    if (inMultilineComment) {
        multilineJavaCommentClose = match($0, /(\*)?\*\//)

        if (multilineJavaCommentClose)
            inMultilineComment = 0

        next
    }
    else {
        multilineJavaComment = match($0, /\/\*\*/)

        if (multilineJavaComment) {
            $0 = substr($0, 1, RSTART)
            inMultilineComment = 1
            if ($0 ~ /^[[:space:]]*$/)
                next
        }
    }

    if (!prevLineBlank) {
        for (ecCurly in OpenEntities) {
            addr = ecCurly SUBSEP CurlyIdx[ecCurly]

            if (Entities[addr] ~ /^[[:space:]]*$/)
                continue

            Entities[addr] = Entities[addr] "\n"
        }
    }

    prevLineBlank = ($0 ~ /^[[:space:]]*$/)
}

{
    comment = 0
    notComment = 1
    potentialComment = 0
    escaped = 0
    prevChar = ""
    split($0, Chars, "")

    if (searching && $0 ~ search) {
        searchMatch = 1
        MatchLine[entityCounter, curly, CurlyIdx[entityCounter, curly]] = $0
        searching = 0
    }

    for (char_i = 1; !comment && char_i <= length(Chars); char_i++) {
        char = Chars[char_i]
        closeCurly = 0

        if (OpenCurly(char)) {
            previousAddr = entityCounter SUBSEP curly SUBSEP CurlyIdx[entityCounter, curly]

            if (curly < 1) {
                entityCounter++
            }

            curly++
            OpenEntities[entityCounter, curly]++
            CurlyIdx[entityCounter, curly]++
            currentAddr = entityCounter SUBSEP curly SUBSEP CurlyIdx[entityCounter, curly]

            if (searchMatch) {
                AddrJoin[currentAddr] = previousAddr
                FoundEntities[currentAddr] = 1
                searchMatch = 0
                resolvingSearch = curly
            }

            for (ecCurly in OpenEntities) {
                split(ecCurly, ECCurly, SUBSEP)
                ec = ECCurly[1]
                c = ECCurly[2]
                Curlies[ec]++
                PositiveCurlies[ec]++
                if (Curlies[ec] > MaxLevel[ec]) MaxLevel[ec]++
            }

            activeBrace = char
        }

        else if (InnerOpenBrace(char) && ! BraceMatch(char, activeInnerBrace[innerBrace])) {
            innerBrace++
            activeInnerBrace[innerBrace] = char
        }

        else if (innerBrace > 1 && InnerCloseBrace(char) && BraceMatch(char, activeInnerBrace[innerBrace])) {
            delete activeInnerBrace[innerBrace]
            innerBrace--
        }

        else if (char == "/" && !(prevChar == "/")) {
            potentialComment = 1
            prevChar = char
            continue
        }

        else if (innerBrace == 1 && !quote && (char == "#" || char == "/")) {
            comment = 1
        }

        if (!comment) {
            if (potentialComment > 1) {
                potentialComment = 0
                notComment = 1
                add = "/" char
            }
            else {
                if (potentialComment) {
                    potentialComment++
                    notComment = 0
                }

                add = char
            }

            closeCurly = CloseCurly(char)

            for (ecCurly in OpenEntities) {
                addr = ecCurly SUBSEP CurlyIdx[ecCurly]
                Entities[addr] = Entities[addr] add
            }

            if (closeCurly) {
                if (resolvingSearch == curly && FoundEntities[currentAddr]) {
                    resolvingSearch = 0
                    exit # TODO: Make full scope search - awk keeps adding false positives on array test above -_-
                    break
                }
                currentAddr = previousAddr
                --curly
                --Curlies[entityCounter]
                activeBrace = ""
                for (ecCurly in OpenEntities) {
                    split(ecCurly, ECCurly, SUBSEP)
                    ec = ECCurly[1]
                    c = ECCurly[2]
                    if (!Curlies[ec]) {
                        delete OpenEntities[ecCurly]
                    }
                }
            }
        }

        if (debug && char != " ") DebugPrint(1)

        escaped = ((char == "\\" && !(prevChar == "\\")) || (char == "$" && !(prevChar == "$")))
        prevChar = char
        quote = (squote || dquote ? 1 : 0)
    }
}

END {
    if (searchCase) {
        for (addr in FoundEntities) {
            print MatchLine[AddrJoin[addr]]
            print Entities[addr]
        }
    }
    else {
        print Entities[ec, c, i]

        for (ec = 1; ec <= entityCounter; ec++) {
            for (c = 1; c <= PositiveCurlies[ec]; c++) {
                for (i = 1; i <= CurlyIdx[ec, c]; i++) {
                    if (length(Entities[ec, c, i])) {
                        print Entities[ec, c, i] 
                    }
                }
            }
        }
    }
}

function BraceMatch(char, brace) {
    if (brace == "{" && char == "}")
        return 1
    else if (brace == "[" && char == "]")
        return 1
    else if (brace == "(" && char == ")")
        return 1
    else if (brace == "\"" && char == "\"")
        return 1
    #else if (brace == "<" && char == ">")
        #return 1
    else if (brace == "\'" && char == "\'")
        return 1
    else
        return 0
}
function OpenCurly(char) {
    if (!quote && !escaped && char == "{") {
        if (debug) print "open curly"
        return 1
    } else
        return 0
}
function CloseCurly(char) {
    if (!quote && !escaped && char == "}") {
        if (debug) print "close curly"
        return 1
    } else
        return 0
}
function InnerOpenBrace(char) {
    if ((char == "[" || char == "(") && !quote) {
        if (debug) print "open brace " char
        return 1
    } else if (!escaped && char == "\"" && !squote) {
        dquote = 1
        return 1
    } else if (!escaped && char == "\'" && !dquote) {
        squote = 1
        return 1
    } else
        return 0
}
function InnerCloseBrace(char) {
    if ((char == "]" || char == ")") && !quote) {
        if (debug) print "close brace " char
        return 1
    } else if (!escaped && dquote && char == "\"" && !squote) {
        dquote = 0
        return 1
    } else if (!escaped && squote && char == "\'" && !dquote) {
        squote = 0
        return 1
    } else
        return 0
}
function DebugPrint(case) {
    if (case == 1) {
        print NR, i, char, curly, entityCounter, activeBrace, BraceMatch(activeBrace)#, Entities[entityCounter, curly]
        print innerCurly, innerBrace, activeInnerBrace[innerBrace], comment
    }
}

