#!/bin/bash
# Lists the rule ids of the design (H3, NI5, ...) and how many test files name each one.
# Usage: scripts/rules.sh [GROUP ...]   GROUP: an id prefix, for example H NI C. Default: all groups.
#        MISSING=1 scripts/rules.sh ...  only the ids that no test names (the open scope)
# A test names a rule in a comment (`# H3: ...`) or in its case directory name (`h3-...`).
set -u
cd "$(dirname "$0")/.."
TEST_DIRS=$(ls -d tests packages cli worker 2>/dev/null)
want=${*:-}
printf "id\tfile\tsection\ttests\n"
for f in DESIGN*.md; do
  awk -v f="$f" '/^## /{sec=$2; sub(/\.$/,"",sec)} /^### [0-9]/{sec=$2}
    match($0, /^\| [A-Z]{1,3}[0-9]+ \|/) { id=substr($0, 3, RLENGTH-4); print id "\t" f "\t" sec }' "$f"
done | awk -F'\t' '$1 !~ /^(G|N|Q)[0-9]/ && !($2=="DESIGN.md" && $1 ~ /^P[0-9]/)' | sort -u -k1,1V -k2,2 |
while IFS=$'\t' read -r id file sec; do
  g=${id%%[0-9]*}
  if [ -n "$want" ] && ! printf '%s\n' $want | grep -qx "$g"; then continue; fi
  n=0
  if [ -n "$TEST_DIRS" ]; then
    lid=$(echo "$id" | tr 'A-Z' 'a-z')
    n=$( { grep -rlw -- "$id" $TEST_DIRS 2>/dev/null; find $TEST_DIRS -type d -name "$lid-*" 2>/dev/null; } | sort -u | wc -l)
  fi
  [ "${MISSING:-0}" = 1 ] && [ "$n" -gt 0 ] && continue
  printf "%s\t%s\t%s\t%s\n" "$id" "$file" "$sec" "$n"
done
