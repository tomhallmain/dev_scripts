#!/usr/bin/awk
#
# Script to return a population of top-level entities within curly braces in 
# a language wwhere comments are marked by pound sign
#
# > awk -f top_curly.awk file

BEGIN {
    curly = 1
    innerBrace = 1
    entityCounter = 1
}

NR > 1 {
    Entities[entityCounter,curly] = Entities[entityCounter, curly] "\n"
}

{
    comment = 0
    escaped = 0
    prevChar = ""
    split($0, Chars, "")
  
    for (i = 1; i <= length(Chars); i++) {
        char = Chars[i]
        if (comment) continue

        if (OpenCurly(char)) {
            if (curly == 2) innerCurly++; else curly++
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
        else if (innerBrace == 1 && !innerCurly && !quote && char == "#") {
            comment = 1
        }

        if (!comment) {
            Entities[entityCounter, curly] = Entities[entityCounter, curly] char
            if (curly == 2 && CloseCurly(char) && BraceMatch(char, activeBrace)) {
                if (innerCurly) {
                    innerCurly--
                }
                else {
                    curly--
                    activeBrace = ""
                    entityCounter++
                }
            }
        }

        if (debug && char != " ") DebugPrint(1)
        prevChar = char
        escaped = (char == "\\")
        quote = (squote || dquote ? 1 : 0)
    }
}

END {
    if (search) {
        for (i = 1; i <= entityCounter; i++)
            if (Entities[i, 1] ~ search) {
                split(Entities[i, 1], SelectedEntity, "\n")
                print SelectedEntity[length(SelectedEntity)]
                print Entities[i, 2]
        }
    }
    else {
        for (i = 1; i <= entityCounter; i++)
            for (j = 1; j <= 2; j++)
                if (Entities[i, j])
                    print Entities[i, j]
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
    }
    else
        return 0
}
function CloseCurly(char) {
    if (!quote && !escaped && char == "}") {
        if (debug) print "close curly"
        return 1
    }
    else
        return 0
}
function InnerOpenBrace(char) {
    if ((char == "[" || char == "(") && !quote) {
        if (debug) print "open brace " char
        return 1
    }
    else if (!escaped && char == "\"" && !squote) {
        dquote = 1
        return 1
    }
    else if (!escaped && char == "\'" && !dquote) {
        squote = 1
        return 1
    }
    else
        return 0
}
function InnerCloseBrace(char) {
    if ((char == "]" || char == ")") && !quote) {
        if (debug) print "close brace " char
        return 1
    }
    else if (!escaped && dquote && char == "\"" && !squote) {
        dquote = 0
        return 1
    }
    else if (!escaped && squote && char == "\'" && !dquote) {
        squote = 0
        return 1
    }
    else
        return 0
}
function DebugPrint(case) {
    if (case == 1) {
        print NR, i, char, curly, entityCounter, activeBrace, BraceMatch(activeBrace)#, Entities[entityCounter, curly]
        print innerCurly, innerBrace, activeInnerBrace[innerBrace], comment
    }
}

