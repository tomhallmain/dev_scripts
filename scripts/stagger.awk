#!/usr/bin/awk
#
# DS:STAGGER
#
# NAME
#       ds:stagger, stagger.awk
#
# SYNOPSIS
#       ds:stagger [-h|file*] [stag_size=5] [style=simple|box|compact] [wrap=smart|char] [awkargs]
#
# DESCRIPTION
#       Script to print fields in a staggered format with enhanced readability.
#       Useful for viewing files with long column values in a terminal-friendly way.
#
# OPTIONS
#       -v stag_size=N        Size of indentation (default: 5)
#       -v style=TYPE         Output style: simple, box, compact (default: simple)
#       -v wrap=TYPE          Wrapping mode: smart, char (default: smart)
#       -v color=1           Enable color coding for fields
#       -v headers=1         Show column headers/rulers
#       -v align=l|r|c       Field alignment (left, right, center)
#       -v numbers=1         Show line/field numbers
#       -v max_width=N       Maximum width for any field
#       -v ellipsis=1       Show ellipsis for truncated content
#       -v wrap_char=CHAR   Character to indicate wrapped lines (default: ↪)
#
# EXAMPLES
#       Simple staggered view:
#           $ echo "field1,field2,field3" | ds:stagger -F,
#
#       Boxed view with headers:
#           $ ds:stagger -v style=box -v headers=1 data.csv
#
#       Compact view with smart wrapping:
#           $ ds:stagger -v style=compact -v wrap=smart data.tsv

BEGIN {
    # Initialize parameters with defaults
    if (!stag_size) stag_size = 5
    if (!style) style = "simple"
    if (!wrap) wrap = "smart"
    if (!wrap_char) wrap_char = "↪"
    if (!color) color = 0
    if (!headers) headers = 0
    if (!align) align = "l"
    if (!numbers) numbers = 0
    if (!max_width) max_width = 0
    if (!ellipsis) ellipsis = 0

    # Get terminal width
    if (!tty_size) "[ \"$TERM\" ] && tput cols || echo 100" | getline tty_size; tty_size += 0

    # Initialize spacing and styles
    space = "                                                                             "
    stag = sprintf("%.*s", stag_size, space)
    
    # Box drawing characters
    Box["tl"] = "┌"; Box["tr"] = "┐"; Box["bl"] = "└"; Box["br"] = "┘"
    Box["h"] = "─"; Box["v"] = "│"; Box["vr"] = "├"; Box["vl"] = "┤"

    # ANSI colors
    if (color) {
        Colors[1] = "\033[38;5;39m"  # Blue
        Colors[2] = "\033[38;5;40m"  # Green
        Colors[3] = "\033[38;5;208m" # Orange
        Colors[4] = "\033[38;5;169m" # Pink
        Colors[5] = "\033[38;5;220m" # Yellow
        ColorReset = "\033[0m"
    }

    # Track maximum field lengths for headers
    if (headers) max_seen_length = 0
}

# Smart word wrapping function
function smart_wrap(text, width,    words, out, line, i, word) {
    split(text, words, " ")
    line = words[1]
    out[1] = line
    j = 1
    
    for (i = 2; i <= length(words); i++) {
        word = words[i]
        if (length(line) + length(word) + 1 <= width) {
            line = line " " word
            out[j] = line
        } else {
            j++
            line = word
            out[j] = line
        }
    }
    
    return j
}

# Alignment function
function align_text(text, width, alignment) {
    if (alignment == "r")
        return sprintf("%" width "s", text)
    else if (alignment == "c")
        return sprintf("%" int((width-length(text))/2) "s%s%" int((width-length(text)+1)/2) "s", "", text, "")
    return sprintf("%-" width "s", text)
}

{
    # Store field values and calculate maximum lengths
    delete FieldValues
    delete FieldLengths
    max_field_length = 0
    
    for (i = 1; i <= NF; i++) {
        FieldValues[i] = $i
        FieldLengths[i] = length($i)
        if (FieldLengths[i] > max_field_length) max_field_length = FieldLengths[i]
    }
    
    if (headers && max_field_length > max_seen_length) max_seen_length = max_field_length

    # Print line/field numbers if enabled
    if (numbers) printf "%-6d ", NR

    # Handle different styles
    if (style == "box") {
        # Box style output
        if (NR == 1) {
            # Print top border
            printf Box["tl"]
            for (i = 1; i < tty_size - 2; i++) printf Box["h"]
            printf Box["tr"]\n
        }
        
        spacer = 3  # Initial indent in box style
    } else if (style == "compact") {
        spacer = 2  # Minimal indent in compact style
    } else {
        spacer = 0  # Default simple style
    }

    stag_space = sprintf("%*s", spacer, "")

    # Process each field
    for (i = 1; i <= NF; i++) {
        field_text = FieldValues[i]
        available_width = tty_size - spacer

        if (max_width && available_width > max_width) 
            available_width = max_width

        # Apply color if enabled
        if (color) {
            field_text = Colors[(i-1) % 5 + 1] field_text ColorReset
        }

        # Handle wrapping
        if (length(field_text) > available_width) {
            if (wrap == "smart") {
                # Smart word wrapping
                n = smart_wrap(field_text, available_width, wrapped_lines)
                for (j = 1; j <= n; j++) {
                    if (j == 1) {
                        if (style == "box") printf "%s%s ", Box["v"], stag_space
                        else printf "%s", stag_space
                        print wrapped_lines[j]
                    } else {
                        if (style == "box") printf "%s%s%s ", Box["v"], stag_space, wrap_char
                        else printf "%s%s ", stag_space, wrap_char
                        print wrapped_lines[j]
                    }
                }
            } else {
                # Character-based wrapping
                while (length(field_text) > available_width) {
                    if (style == "box") printf "%s%s ", Box["v"], stag_space
                    else printf "%s", stag_space
                    
                    chunk = substr(field_text, 1, available_width)
                    if (ellipsis && length(field_text) > available_width * 2)
                        print chunk "..."
                    else
                        print chunk
                    
                    field_text = substr(field_text, available_width + 1)
                    if (length(field_text) > 0) {
                        if (style == "box") printf "%s%s%s ", Box["v"], stag_space, wrap_char
                        else printf "%s%s ", stag_space, wrap_char
                    }
                }
            }
        }

        # Print the field (or remaining part after wrapping)
        if (length(field_text) > 0) {
            if (style == "box") printf "%s%s ", Box["v"], stag_space
            else printf "%s", stag_space
            print align_text(field_text, available_width, align)
        }

        # Update indentation
        if (style == "compact") {
            spacer += 2
        } else {
            spacer += stag_size
        }
        stag_space = sprintf("%*s", spacer, "")
    }

    # Print box bottom border if needed
    if (style == "box") {
        printf "%s", Box["v"]
        print ""
    } else {
        print ""
    }
}

END {
    # Print final box border if using box style
    if (style == "box") {
        printf Box["bl"]
        for (i = 1; i < tty_size - 2; i++) printf Box["h"]
        printf Box["br"]\n
    }
}
