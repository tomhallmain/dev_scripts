#!/usr/bin/awk
#
# DS:RANDOM - Advanced text randomization and generation utility
#
# NAME
#     ds:random, randomize.awk - Text randomization and generation utility
#
# SYNOPSIS
#     ds:random [file] [-v mode=MODE] [-v options=OPTIONS]
#
# DESCRIPTION
#     Advanced text randomization utility that supports multiple modes:
#     - Text anonymization with pattern preservation
#     - Password generation
#     - Random number generation
#     - UUID generation
#     - Random string generation with custom patterns
#
# MODES
#     text       - Randomize text while preserving patterns
#     number     - Generate random numbers
#     password   - Generate secure passwords
#     uuid       - Generate UUIDs
#     pattern    - Generate strings matching a pattern
#
# OPTIONS
#     length=N           - Length for generated strings/passwords
#     charset=STRING     - Custom character set for generation
#     preserve=STRING    - Characters to preserve in text mode
#     strength=N        - Password strength (1-4, default 3)
#     case=STRING       - Case mode: upper, lower, mixed (default)
#     format=STRING     - Output format for numbers
#     range=STRING      - Number range (min,max)
#
# EXAMPLES
#     # Generate a random password
#     $ echo | awk -f randomize.awk -v mode=password -v length=16
#
#     # Anonymize text preserving patterns
#     $ echo "John Doe (ID: 123-45-6789)" | awk -f randomize.awk -v mode=text
#
#     # Generate a UUID
#     $ echo | awk -f randomize.awk -v mode=uuid
#
#     # Generate random string matching pattern
#     $ echo | awk -f randomize.awk -v mode=pattern -v pattern="LL-DD-LL"

BEGIN {
    # Initialize configuration
    if (!mode || mode == "") mode = "number"
    if (!length) length = 12
    if (!strength) strength = 3
    if (!case) case = "mixed"
    if (!format) format = "%.6f"
    
    # Character sets
    CHARS_LOWER = "abcdefghijklmnopqrstuvwxyz"
    CHARS_UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    CHARS_DIGITS = "0123456789"
    CHARS_SPECIAL = "!@#$%^&*()_+-=[]{}|;:,.<>?"
    CHARS_HEX = "0123456789abcdef"
    
    # Initialize random seed
    SeedRandom()
    
    # Set up character sets based on options
    setup_charsets()
}

# Random number generation mode
mode == "number" {
    if (range) {
        split(range, r, ",")
        min = r[1] + 0
        max = r[2] + 0
        print(min + rand() * (max - min))
    } else {
        printf(format "\n", rand())
    }
    exit(0)
}

# Password generation mode
mode == "password" {
    print(generate_password())
    exit(0)
}

# UUID generation mode
mode == "uuid" {
    print(generate_uuid())
    exit(0)
}

# Pattern-based generation mode
mode == "pattern" {
    print(generate_pattern())
    exit(0)
}

# Text randomization mode
mode == "text" {
    for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (c ~ /[0-9]/) {
            printf("%c", random_digit())
        }
        else if (c ~ /[A-Z]/) {
            printf("%c", random_upper())
        }
        else if (c ~ /[a-z]/) {
            printf("%c", random_lower())
        }
        else if (preserve && index(preserve, c)) {
            printf("%c", c)
        }
        else {
            printf("%c", c)
        }
    }
    print ""
}

# Helper Functions

# Generate a secure password based on strength level
function generate_password(    result, i, types) {
    types = strength >= 2 ? 3 : 2
    types = strength >= 3 ? 4 : types
    
    result = ""
    for (i = 1; i <= length; i++) {
        if (i % types == 0) result = result random_special()
        else if (i % types == 1) result = result random_upper()
        else if (i % types == 2) result = result random_lower()
        else result = result random_digit()
    }
    
    # Shuffle the result
    return shuffle_string(result)
}

# Generate a UUID v4
function generate_uuid(    result, i) {
    result = ""
    for (i = 1; i <= 32; i++) {
        if (i == 13) result = result "4"  # Version 4
        else if (i == 17) result = result substr("89ab", 1 + int(rand() * 4), 1)
        else result = result substr(CHARS_HEX, 1 + int(rand() * 16), 1)
        if (i == 8 || i == 12 || i == 16 || i == 20) result = result "-"
    }
    return result
}

# Generate string matching pattern (L=letter, D=digit, S=special)
function generate_pattern(    result, i, c) {
    if (!pattern) pattern = "LLDDSS"
    result = ""
    for (i = 1; i <= length(pattern); i++) {
        c = substr(pattern, i, 1)
        if (c == "L") result = result random_letter()
        else if (c == "D") result = result random_digit()
        else if (c == "S") result = result random_special()
        else result = result c
    }
    return result
}

# Random character generators
function random_lower() { return substr(CHARS_LOWER, 1 + int(rand() * 26), 1) }
function random_upper() { return substr(CHARS_UPPER, 1 + int(rand() * 26), 1) }
function random_digit() { return substr(CHARS_DIGITS, 1 + int(rand() * 10), 1) }
function random_special() { return substr(CHARS_SPECIAL, 1 + int(rand() * length(CHARS_SPECIAL)), 1) }
function random_letter() { return case == "upper" ? random_upper() : case == "lower" ? random_lower() : (rand() > 0.5 ? random_upper() : random_lower()) }

# Setup character sets based on options
function setup_charsets() {
    if (charset) {
        CHARS_LOWER = charset
        CHARS_UPPER = charset
        CHARS_SPECIAL = charset
    }
}

# Shuffle a string
function shuffle_string(str,    n, i, j, temp, arr) {
    n = length(str)
    for (i = 1; i <= n; i++) arr[i] = substr(str, i, 1)
    for (i = n; i > 1; i--) {
        j = 1 + int(rand() * i)
        temp = arr[i]
        arr[i] = arr[j]
        arr[j] = temp
    }
    str = ""
    for (i = 1; i <= n; i++) str = str arr[i]
    return str
}

# Reseed random number generator periodically
function maybe_reseed(    now) {
    if (++seed_count % 100 == 0) SeedRandom()
}

function SeedRandom() {
    "date +%s%3N" | getline date; srand(date)
}


