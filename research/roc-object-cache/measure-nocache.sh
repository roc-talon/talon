#!/usr/bin/env bash
# Build times of the apps of test.sh with and without --no-cache, and with 4 builds at the same time (as test.sh does). Usage: measure-nocache.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../.." && pwd); . "$root/scripts/env.sh"
out=$here/tmp-opt; rm -rf "$out"; mkdir -p "$out"; cp -r "$here/tree" "$out/tree"
export XDG_CACHE_HOME=$out/cache ROC_CACHE_DIR=$out/cache/roc; mkdir -p "$ROC_CACHE_DIR"
cp -r "$root/.work/cache/roc/packages" "$ROC_CACHE_DIR/packages"
apps="tests/commands/main.roc cli/main.roc cli/fxprobe.roc cli/flowprobe.roc"
now() { date +%s.%N; }
par() { # par <label> <flags>: the 4 apps at the same time, wall time
    local s a n=0; s=$(now)
    for a in $apps; do "$ROC" build "$out/tree/$a" --opt=dev ${2:-} ${JOBS1:+--jobs=1} --output="$out/par-$n" > "$out/par-$n.log" 2>&1 & n=$((n+1)); done; wait
    printf '%-34s %.1f s\n' "$1" "$(awk -v a="$(now)" -v b="$s" 'BEGIN{print a-b}')"
}
echo "default threads"
par "cache, cold"; par "cache, warm (objects reused)"
rm -rf "$ROC_CACHE_DIR"/compat-*/objects-v7; par "cache, objects-v7 removed" ; par "--no-cache" "--no-cache"; par "--no-cache again" "--no-cache"
echo "--jobs=1 for each build (as test.sh with the l0 step)"
export JOBS1=1
rm -rf "$out/cache"; mkdir -p "$ROC_CACHE_DIR"; cp -r "$root/.work/cache/roc/packages" "$ROC_CACHE_DIR/packages"
par "cache, cold"; par "cache, warm (objects reused)"; rm -rf "$ROC_CACHE_DIR"/compat-*/objects-v7; par "cache, objects-v7 removed"; par "--no-cache" "--no-cache"
