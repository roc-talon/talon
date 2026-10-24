#!/usr/bin/env bash
# Roc object cache repro with the L2 test app (research/roc-object-cache/RESULTS.md, case 1).
# State A = copy of cli/ at the red state of slice 038 (tree/). State B = A with one dead function added in cli/lib/Ranges.roc (MUT=dead) or other edits.
# Build A, build B with the SAME fresh cache, run all L2 cases with each app. Then build B with `objects-v7` removed.
# Usage: research/roc-object-cache/repro-l2.sh [mutation]   mutation: dead (default) | body | comment | none
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
. "$root/scripts/env.sh"
OPT=${OPT:-dev}
out=${OUT:-$here/tmp}
mut=${1:-dead}
tree=$out/tree
cache=$out/cache
rm -rf "$out"; mkdir -p "$out"
cp -r "$here/tree" "$tree"
export XDG_CACHE_HOME=$cache ROC_CACHE_DIR=$cache/roc
# The downloaded packages (basic-cli, roc-toml, ...) are copied from the cache of the test scripts, so the repro needs no network. The compile and object caches start empty.
mkdir -p "$ROC_CACHE_DIR"; [ -d "$root/.work/cache/roc/packages" ] && cp -r "$root/.work/cache/roc/packages" "$ROC_CACHE_DIR/packages"
export TMPDIR=$out/cases; mkdir -p "$TMPDIR"
build() { local t0; t0=$(date +%s.%N); "$ROC" build "$tree/tests/commands/main.roc" --opt="$OPT" ${BJOBS:+--jobs=$BJOBS} --output="$out/l2-$1" > "$out/build-$1.log" 2>&1 || { echo "build $1 failed"; tail "$out/build-$1.log"; exit 1; }
    printf 'build %s: %.1f s\n' "$1" "$(awk -v a="$(date +%s.%N)" -v b="$t0" 'BEGIN{print a-b}')"; }
run() { L2BIN=$out/l2-$1 "$root/tests/commands/run.sh" > "$out/run-$1.log" 2>&1 || true
    echo "run $1: $(grep '^commands' "$out/run-$1.log")"
    echo "  crash lines: $(grep -c -e 'boxy runtime' -e 'Segmentation' -e 'segfault' -e 'SIGSEGV' "$out/run-$1.log")"; }
mutate() {
    local f=$tree/cli/lib/Ranges.roc
    case $mut in
    none) return 0 ;;
    dead) printf '\n# dead\nunused_fn : U64 -> U64\nunused_fn = |n| n + 1\n' >> "$f" ;;
    body) sed -i 's/"0.${(v.minor() + 1).to_str()}.0"/"0.${(v.minor() + 2).to_str()}.0"/' "$f" ;;
    comment) sed -i 's|^# The first version of the next series.*|# The first version of the next series: `2.1.0` gives `3.0.0`.\n# A second line of comment.|' "$f" ;;
    esac
    if cmp -s "$f" "$here/tree/cli/lib/Ranges.roc"; then echo "mutation changed nothing"; exit 1; fi
}
build A; run A
mutate
build B; run B
# CLEAR=half: remove every second object file. CLEAR=all (default): remove objects-v7. CLEAR=dev: only the target dirs of the build (x64musl-dev). CLEAR=comptime: only x64musl-comptime. CLEAR=none: keep the cache.
case ${CLEAR:-all} in
all) rm -rf "$ROC_CACHE_DIR"/compat-*/objects-v7 ;;
dev) rm -rf "$ROC_CACHE_DIR"/compat-*/objects-v7/x64musl-dev ;;
comptime) rm -rf "$ROC_CACHE_DIR"/compat-*/objects-v7/x64musl-comptime ;;
half) find "$ROC_CACHE_DIR"/compat-*/objects-v7/x64musl-dev -type f | sort | awk 'NR % 2 == 0' | xargs rm -f ;; # with mutation `none`: a pruned cache of the same sources
esac
build B2; run B2
