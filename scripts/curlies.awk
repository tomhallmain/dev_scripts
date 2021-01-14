#!/usr/bin/awk
#
# Script to return a population of entities within curly braces in 
# a language wwhere comments are marked by pound sign or two forward slashes
#
# > awk -f curlies.awk file
#
## TODO multiline and language-specific comment handling
## TODO maybe try simple shift of base level from 1 to 2 for java function/class searches

BEGIN {
  curly = 1
  innerBrace = 1
  entityCounter = 1
  OpenEntities[1] = 1
}

NR > 1 {
  if (inMultilineComment) {
    multilineJavaCommentClose = match($0, /(\*)?\*\//)
    if (multilineJavaCommentClose)
      inMultilineComment = 0
    next }
  else {
    multilineJavaComment = match($0, /\/\*\*/)
    if (multilineJavaComment) {
      $0 = substr($0, 1, RSTART)
      inMultilineComment = 1
      if ($0 ~ /^[[:space:]]*$/)
        next }}

  for (i = 1; !prevLineBlank && !comment && i <= PositiveCurlies[entityCounter] + 1; i++) {
    for (ec in OpenEntities) {
      #print "building entity " ec " curly " i
      #print Entities[ec, i]

      if (ec == entityCounter && i < PositiveCurlies[entityCounter])
        continue
      else if (Entities[ec, i] ~ /^[[:space:]]*$/)
        continue
 
      if (closeLine && ec < entityCounter)
        Entities[ec, i] = Entities[ec, i] "\n" closeLine

      Entities[ec, i] = Entities[ec, i] "\n" }}

  prevLineBlank = ($0 ~ /^[[:space:]]*$/)
}

{
  comment = 0
  notComment = 1
  potentialComment = 0
  escaped = 0
  prevChar = ""
  closeLine = ""
  split($0, Chars, "")

  for (i = 1; !comment && i <= length(Chars); i++) {
    char = Chars[i]

    if (OpenCurly(char)) {
      curly++
      for (ec in OpenEntities) {
        Curlies[ec]++
        PositiveCurlies[ec]++
        if (Curlies[ec] > MaxLevel[ec]) MaxLevel[ec]++ }
      activeBrace = char }
    else if (InnerOpenBrace(char) && ! BraceMatch(char, activeInnerBrace[innerBrace])) {
      innerBrace++
      activeInnerBrace[innerBrace] = char }
    else if (innerBrace > 1 && InnerCloseBrace(char) && BraceMatch(char, activeInnerBrace[innerBrace])) {
      delete activeInnerBrace[innerBrace]
      innerBrace-- }
    else if (char == "/" && !(prevChar == "/")) {
      potentialComment = 1 }
    else if (innerBrace == 1 && !quote && (char == "#" || char == "/")) {
      comment = 1 }

    if (!comment) {
      if (potentialComment > 1) {
        potentialComment = 0
        notComment = 1
        add = "/" char }
      else {
        if (potentialComment) {
          potentialComment++
          notComment = 0 }

        add = char }

      for (c = 1; notComment && c <= curly; c++) {
        for (ec in OpenEntities) {
      if (ec == entityCounter && c < PositiveCurlies[entityCounter])
        continue
          Entities[ec, c] = Entities[ec, c] add }}

      if (CloseCurly(char)) {
        --curly
        entityCounter++
        OpenEntities[entityCounter] = 1
        closeLine = $0
        activeBrace = ""
        for (ec in OpenEntities) {
          --Curlies[ec]
          if (!Curlies[ec]) {
            delete OpenEntities[ec]
            ClosedEntities[ec] = 1 }}}}

    if (debug && char != " ") DebugPrint(1)
    escaped = (char == "\\" && !(prevChar == "\\"))
    prevChar = char
    quote = (squote || dquote ? 1 : 0) }
}

END {
  if (search) {
    for (i = 1; i <= entityCounter; i++) {
      for (j = 1; j < PositiveCurlies[i]; j++) {
        split(Entities[i, j], SelectedEntity, /\n/)
        checkLine1 = SelectedEntity[1] # TODO make this into a loop over a customizable range
        print i, j
        print checkLine1
        #print Entities[i, j]
        if (checkLine1 ~ search) {
          print checkLine1
          print Entities[i, j+1]
          break }
        checkLine2 = SelectedEntity[2]
        print checkLine2
        if (checkLine2 ~ search) {
          print checkLine2
          print Entities[i, j+1]
          break }
        checkLine3 = SelectedEntity[3]
        if (checkLine3 ~ search) {
          print checkLine3
          print Entities[i, j+1] }}}}
  else {
    for (i = 1; i <= entityCounter; i++) {
      for (j = 1; j <= PositiveCurlies[i]; j++) {
        print "DEBUG: " i, j
        if (Entities[i, j]) {
          print Entities[i, j] }}}}
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
    print innerCurly, innerBrace, activeInnerBrace[innerBrace], comment }
}

