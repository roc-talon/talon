#!/bin/sh
# Switches the code files of `cli/` between the stub tree and the private reference of slice 025.
# Usage: research/slice-025-revert/swap.sh stubs | reference | save-reference | save-stubs
#   stubs            copy stubs/ over cli/ (the state that the test agent hands over)
#   reference        copy reference/ over cli/ (the private reference: the code that makes all tests green)
#   save-reference   copy the changed files of cli/ to reference/ (list: FILES)
#   save-stubs       copy the changed files of cli/ to stubs/
cd "$(dirname "$0")/../.." || exit 1
R=research/slice-025-revert
FILES=$(cat "$R/FILES")
case $1 in
stubs) for f in $FILES; do mkdir -p "$(dirname "$f")"; if [ -e "$R/stubs/$f" ]; then cp "$R/stubs/$f" "$f"; else rm -f "$f"; fi; done ;;
reference) echo "the private reference was deleted"; exit 2 ;;
save-reference) echo "the private reference was deleted"; exit 2 ;;
save-stubs) for f in $FILES; do mkdir -p "$R/stubs/$(dirname "$f")"; if [ -e "$f" ]; then cp "$f" "$R/stubs/$f"; else rm -f "$R/stubs/$f"; fi; done ;;
*) echo "usage: swap.sh stubs|reference|save-reference|save-stubs"; exit 2 ;;
esac
