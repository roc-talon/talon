#!/usr/bin/env bash
# Build each repro and print the text size (x86-64 Linux).
# Usage: ROC=<path to roc> OPT=speed ./measure.sh
set -e
ROC=${ROC:-/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc}
OPT=${OPT:-speed}
cd "$(dirname "$0")"; mkdir -p .work/src; cd .work/src
printf 'kind\tN\ttext\tfuncs\n'
for kind in ${KINDS:-named inline distinct samesize types}; do
  for n in ${NS:-0 1 2 4 8}; do
    f=$kind-$n; ../../gen.sh "$kind" "$n" > $f.roc
    $ROC build --opt=$OPT --output=$f.bin $f.roc >/dev/null 2>&1 || { echo "$f build failed"; continue; }
    ./$f.bin 3 1 22 >/dev/null
    printf '%s\t%s\t%s\t%s\n' "$kind" "$n" "$(size $f.bin | tail -1 | awk '{print $1}')" "$(nm $f.bin | grep -c ' [tT] ')"
  done
done
