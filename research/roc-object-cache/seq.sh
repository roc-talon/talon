#!/usr/bin/env bash
# Build the L2 app N times with identical sources and one cache; run all cases after each build. Usage: seq.sh [N]
set -eu
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../.." && pwd); . "$root/scripts/env.sh"
out=${OUT:-$here/tmp-seq}; rm -rf "$out"; mkdir -p "$out"; cp -r "$here/tree" "$out/tree"
export XDG_CACHE_HOME=$out/cache ROC_CACHE_DIR=$out/cache/roc TMPDIR=$out/cases; mkdir -p "$ROC_CACHE_DIR" "$TMPDIR"
[ -d "$root/.work/cache/roc/packages" ] && cp -r "$root/.work/cache/roc/packages" "$ROC_CACHE_DIR/packages"
for i in $(seq 1 "${1:-4}"); do
    s=$(date +%s.%N); "$ROC" build "$out/tree/tests/commands/main.roc" --opt=dev ${BFLAGS:-} --output="$out/l2-$i" > "$out/build-$i.log" 2>&1
    printf 'build %s: %.1f s, ' "$i" "$(awk -v a="$(date +%s.%N)" -v b="$s" 'BEGIN{print a-b}')"
    L2BIN=$out/l2-$i "$root/tests/commands/run.sh" > "$out/run-$i.log" 2>&1 || true
    grep '^commands' "$out/run-$i.log"
done
