#!/usr/bin/env bash
# Lists the rule ids of the design (R-H3, R-NI5, ...) and how many test files name each one.
# A rule id is the first cell of a table row (`| R-H3 |`) or the start of a paragraph (`R-SL14: ...`).
# Usage: scripts/rules.sh [GROUP ...]   GROUP: an id prefix, for example R-H R-NI R-C (or H NI C). Default: all groups.
#        MISSING=1 scripts/rules.sh ...  only the ids that no test names (the open scope)
# A test names a rule in a comment (`# R-H3: ...`) or in its case directory name (`r-h3-...`).
set -u
cd "$(dirname "$0")/.."
# `install/test.sh` is a test (slice 052). `cli/` and `worker/` hold code, not tests. A rule id in a code comment is no test (slice 001).
TEST_DIRS=$(ls -d tests packages install 2>/dev/null)
want=${*:-}
printf "id\tfile\tsection\ttests\n"
for f in DESIGN*.md; do
  awk -v f="$f" '/^## /{sec=$2; sub(/\.$/,"",sec)} /^### [0-9]/{sec=$2}
    match($0, /^\| R-[A-Z]{1,3}[0-9]+ \|/) { id=substr($0, 3, RLENGTH-4); print id "\t" f "\t" sec }
    match($0, /^R-[A-Z]{1,3}[0-9]+: /) { id=substr($0, 1, RLENGTH-2); print id "\t" f "\t" sec }' "$f"
done | sort -u -k1,1V -k2,2 |
while IFS=$'\t' read -r id file sec; do
  g=${id%%[0-9]*}
  if [ -n "$want" ] && ! printf '%s\n' $want | sed 's/^R-//; s/^/R-/' | grep -qx "$g"; then continue; fi
  n=0
  if [ -n "$TEST_DIRS" ]; then
    lid=$(echo "$id" | tr 'A-Z' 'a-z')
    n=$( { grep -rlw -- "$id" $TEST_DIRS 2>/dev/null; find $TEST_DIRS -type d -name "$lid-*" 2>/dev/null; } | sort -u | wc -l)
  fi
  [ "${MISSING:-0}" = 1 ] && [ "$n" -gt 0 ] && continue
  printf "%s\t%s\t%s\t%s\n" "$id" "$file" "$sec" "$n"
done
