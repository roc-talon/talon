#!/usr/bin/env bash
# Evidence for slice 052: can one Linux machine build tln for the 5 release targets (R-IS2, R-HF10)?
# Usage: research/release-targets/build-all.sh <out dir> [opt]   Prints one line for each target: exit code, seconds, file type.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/scripts/env.sh"
out=${1:?out dir}; opt=${2:-speed}
mkdir -p "$out"
for t in x64musl arm64musl x64mac arm64mac x64win; do
    ext=""; [ "$t" = x64win ] && ext=".exe"
    (
        s=$(date +%s)
        "$ROC" build "$ROOT/cli/main.roc" --no-cache --opt="$opt" --target="$t" --output="$out/tln-$t$ext" > "$out/build-$t.log" 2>&1
        rc=$?
        echo "$t rc=$rc $(( $(date +%s) - s )) s $(file -b "$out/tln-$t$ext" 2>/dev/null | cut -c1-90)"
    ) &
done
wait
