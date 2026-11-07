#!/usr/bin/env bash
# Usage: natpair.sh DIR TEXT [opt]. As pair.sh, but a native build of a headerless DIR/main.roc; counts with countnat.py.
set -e
here=$(cd "$(dirname "$0")" && pwd)
ROC=${ROC:-/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc}
d=$(cd "$1" && pwd); text=$2; opt=${3:-speed}; n=$(basename "$d")
[ -n "$NOGEN" ] || NOBUILD=1 "$here/pair.sh" "$d" "$text"
for f in or arms one; do ( cd "$d/$f" && $ROC build --opt=$opt --no-cache --output="$here/out/$n-$f-$opt.bin" main.roc > "$here/out/$n-$f-$opt.nlog" 2>&1 || true; echo "$n $f: $("$here/countnat.py" "$here/out/$n-$f-$opt.bin" "$text")" ) & done; wait
