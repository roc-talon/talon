#!/usr/bin/env bash
# Does an app built after ANOTHER app (same cache, same sources) give a good L2 app? Usage: cross.sh "<first app main.roc> ..." (paths relative to tree/)
set -eu
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../.." && pwd); . "$root/scripts/env.sh"
out=${OUT:-$here/tmp-cross}; rm -rf "$out"; mkdir -p "$out"; cp -r "$here/tree" "$out/tree"
export XDG_CACHE_HOME=$out/cache ROC_CACHE_DIR=$out/cache/roc TMPDIR=$out/cases; mkdir -p "$ROC_CACHE_DIR" "$TMPDIR"
[ -d "$root/.work/cache/roc/packages" ] && cp -r "$root/.work/cache/roc/packages" "$ROC_CACHE_DIR/packages"
for a in $1; do "$ROC" build "$out/tree/$a" --opt=dev --output="$out/first-$(basename "$(dirname "$a")")-$(basename "$a" .roc)" > "$out/first.log" 2>&1 && echo "first: $a built" || { echo "first: $a failed"; tail -3 "$out/first.log"; }; done
"$ROC" build "$out/tree/tests/commands/main.roc" --opt=dev --output="$out/l2" > "$out/build.log" 2>&1
L2BIN=$out/l2 "$root/tests/commands/run.sh" > "$out/run.log" 2>&1 || true
grep '^commands' "$out/run.log"
