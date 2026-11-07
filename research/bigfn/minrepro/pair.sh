#!/usr/bin/env bash
# Usage: pair.sh DIR TEXT [opt]. DIR/main.roc has the or-pattern form, with the 2 lines of the event! arms
# marked by "#OR". The script makes DIR/or (as is) DIR/arms (one arm for each alternative, with the same body)
# and DIR/one (the body once, in a `_` arm)
# and builds the 2 forms in parallel. Prints the sizes and the copies of TEXT.
set -e
here=$(cd "$(dirname "$0")" && pwd)
d=$(cd "$1" && pwd); text=$2; opt=${3:-speed}
for f in or arms one; do rm -rf "$d/$f"; mkdir -p "$d/$f"; cp "$d"/*.roc "$d/$f/"; done
python3 - "$d" <<'PY'
import sys, re
d = sys.argv[1]
s = open(d + '/main.roc').read()
m = re.search(r'^(\t*)(.*?) => (.*?) #OR\n', s, re.M)
ind, pat, body = m.group(1), m.group(2), m.group(3)
alts = [a.strip() for a in pat.split('|')]
arms = ''.join(f'{ind}{a} => {body}\n' for a in alts)
open(d + '/arms/main.roc', 'w').write(s.replace(m.group(0), arms))
open(d + '/or/main.roc', 'w').write(s.replace(' #OR', ''))
# one: the body once, as a wildcard arm (the next `_` arm, if any, is removed)
one = re.sub(r'^' + re.escape(m.group(0)) + r'(\t*_ => .*\n)?', f'{ind}_ => {body}\n', s, flags=re.M)
open(d + '/one/main.roc', 'w').write(one)
PY
n=$(basename "$d")
if [ -n "$NOBUILD" ]; then exit 0; fi
for f in or arms one; do ( r=$(NAME=$n-$f "$here/build.sh" "$d/$f/main.roc" "$text" $opt 2>&1); echo "$n $f: $r" ) & done; wait
