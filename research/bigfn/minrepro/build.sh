#!/usr/bin/env bash
# Usage: build.sh FILE.roc TEXT [opt]. Builds FILE.roc for wasm32 to out/FILE-opt.wasm and prints the largest function and the copies of TEXT in it.
set -e
here=$(cd "$(dirname "$0")" && pwd)
ROC=${ROC:-/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc}
f=$1; text=$2; opt=${3:-speed}; name=${NAME:-$(basename "$f" .roc)}-$opt
mkdir -p "$here/out"
rm -f "$here/out/$name.wasm"
# roc exits with a non-zero code also for a warning: check the output file
(cd "$(dirname "$f")" && $ROC build --target=wasm32 --no-cache --opt=$opt --output="$here/out/$name.wasm" "$(basename "$f")" > "$here/out/$name.log" 2>&1) || true
[ -f "$here/out/$name.wasm" ] || { tail -30 "$here/out/$name.log"; exit 1; }
node "$here/count.mjs" "$here/out/$name.wasm" "$text"
