#!/bin/bash
#
# TODO use this script instead of awktest.awk
#
# awk_feature_test.sh - AWK Feature and Capability Detection Script
#
# This script tests various AWK features and capabilities and outputs results
# in JSON format for programmatic use. Tests include:
# - Version and implementation details
# - Unicode/multibyte handling
# - Extended regular expressions
# - Built-in functions and variables
# - GNU AWK specific features
#
# Usage: ./awk_feature_test.sh [-v] [-a awk_path]
# Options:
#   -v    Verbose output (shows test details in comments)
#   -a    Specify AWK interpreter path
#
# Output: JSON object containing test results
#
# Example output:
# {
#   "version": "GNU Awk 5.0.1",
#   "path": "/usr/bin/awk",
#   "features": {
#     "posix_compliant": true,
#     "extended_regex": true,
#     "multibyte_gsub": true,
#     "time_functions": true,
#     "bitwise_ops": true,
#     "advanced_arrays": true
#   }
# }

set -e

# Default settings
VERBOSE=false
AWK_CMD="awk"
TEMP_DIR="${TMPDIR:-/tmp}"
TEST_FILE=$(mktemp "$TEMP_DIR/awktest.XXXXXX")

# Cleanup function
cleanup() {
    [ -f "$TEST_FILE" ] && rm -f "$TEST_FILE"
}
trap cleanup EXIT

# Parse arguments
while getopts "va:" opt; do
    case $opt in
        v) VERBOSE=true ;;
        a) AWK_CMD="$OPTARG" ;;
        *) echo "Usage: $0 [-v] [-a awk_path]" >&2; exit 1 ;;
    esac
done

[ "$VERBOSE" = true ] && echo "# Testing AWK implementation..."

# Get version info
version=$($AWK_CMD --version 2>&1 || $AWK_CMD -V 2>&1 || echo "unknown")
version=$(echo "$version" | head -n1 | sed 's/[^a-zA-Z0-9. ()-]//g')

# Get AWK path
awk_path=$(command -v "$AWK_CMD" || echo "not found")

# Test POSIX features
[ "$VERBOSE" = true ] && echo "# Testing POSIX compliance..."
cat > "$TEST_FILE" << 'EOF'
BEGIN {
    print 1 + 1
    print length("test")
    arr[1] = "test"
    print arr[1]
    print NR
}
EOF
posix_test=$($AWK_CMD -f "$TEST_FILE" 2>/dev/null && echo "true" || echo "false")

# Test extended regex
[ "$VERBOSE" = true ] && echo "# Testing extended regex support..."
regex_test=$($AWK_CMD 'BEGIN { if ("test" ~ /^[[:alpha:]]+$/) print "true" }' 2>/dev/null || echo "false")

# Test multibyte gsub handling
[ "$VERBOSE" = true ] && echo "# Testing multibyte gsub handling..."
mb_test=$($AWK_CMD '
{
    test = "cats😼😻"
    gsub(/[ -~]+/, "", test)
    if (length(test) > 0) print "true"
}' 2>/dev/null <<< "test" || echo "false")

# Test GNU AWK features
[ "$VERBOSE" = true ] && echo "# Testing GNU AWK features..."
time_test=$($AWK_CMD 'BEGIN { print strftime("%Y") }' 2>/dev/null && echo "true" || echo "false")
bitwise_test=$($AWK_CMD 'BEGIN { print and(1, 1) }' 2>/dev/null && echo "true" || echo "false")
array_test=$($AWK_CMD 'BEGIN { PROCINFO["sorted_in"] = "@ind_num_asc"; print "true" }' 2>/dev/null || echo "false")

# Output JSON result
cat << EOF
{
  "version": "$(echo "$version" | sed 's/"/\\"/g')",
  "path": "$(echo "$awk_path" | sed 's/"/\\"/g')",
  "features": {
    "posix_compliant": $posix_test,
    "extended_regex": $regex_test,
    "multibyte_gsub": $mb_test,
    "time_functions": $time_test,
    "bitwise_ops": $bitwise_test,
    "advanced_arrays": $array_test
  }
}
EOF 