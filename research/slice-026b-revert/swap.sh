#!/bin/sh
# Switches the code files of `cli/` between the stub tree and the private reference of slice 026b.
# Usage: research/slice-026b-revert/swap.sh stubs | reference | save-reference | save-stubs
#   stubs            copy stubs/ over cli/ (the state that the test agent hands over)
#   reference        copy reference/ over cli/ (the private reference: the code that makes all tests green)
#   save-reference   copy the changed files of cli/ to reference/ (list: FILES)
#   save-stubs       copy the changed files of cli/ to stubs/
cd "$(dirname "$0")/../.." || exit 1
R=research/slice-026b-revert
FILES=$(cat "$R/FILES")
case $1 in
stubs) for f in $FILES; do mkdir -p "$(dirname "$f")"; if [ -e "$R/stubs/$f" ]; then cp "$R/stubs/$f" "$f"; else rm -f "$f"; fi; done ;;
reference) for f in $FILES; do mkdir -p "$(dirname "$f")"; if [ -e "$R/reference/$f" ]; then cp "$R/reference/$f" "$f"; else rm -f "$f"; fi; done ;;
save-reference) for f in $FILES; do mkdir -p "$R/reference/$(dirname "$f")"; if [ -e "$f" ]; then cp "$f" "$R/reference/$f"; else rm -f "$R/reference/$f"; fi; done ;;
save-stubs) for f in $FILES; do mkdir -p "$R/stubs/$(dirname "$f")"; if [ -e "$f" ]; then cp "$f" "$R/stubs/$f"; else rm -f "$R/stubs/$f"; fi; done ;;
*) echo "usage: swap.sh stubs|reference|save-reference|save-stubs"; exit 2 ;;
esac
