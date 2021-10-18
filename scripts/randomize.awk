#!/usr/bin/awk
#
# Simple text randomization that preserves casing and other features of the text

BEGIN {
    chars_seen = 0
    
    if (!mode || mode == "" || "number" ~ "^"mode) {
        mode = 0 # Gen random number
    }
    else if ("text" ~ "^"mode) {
        mode = 1
    }
    else {
        print("[mode] not understood - available options: [number|text]")
        exit(1)
    }

    SeedRandom()
}

mode == 0 {
    print(rand())
    exit(0)
}

mode {
    for (f = 1; f <= NF; f++) { 
        chars_seen++

        # Soft randomization, only randomize these character classes
        if ($f ~ /[A-z0-9]/) { 
            if(chars_seen % 150 == 0) {
                SeedRandom()
            }
            
            if ($f ~ /[0-9]/) {
                printf("%c", int(rand() * (57 - 48)) + 48)
            }
            else if ($f ~ /[A-Z]/) {
                printf("%c", int(rand() * (90 - 65)) + 65)
            }
            else {
                printf("%c", int(rand() * (121 - 97)) + 97)
            }
        }
        else {
            printf("%s", $f)
        }
    }

    print ""
}

function SeedRandom() {
    "date +%s%3N" | getline date; srand(date)
}


