#!/usr/bin/env bash
# Build one variant dir (arg 1) to out/<name>.wasm and print: biggest functions, and the number of copies of the Problem title table in the biggest one.
set -e
here=$(cd "$(dirname "$0")" && pwd)
ROC=${ROC:-/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc}
v=$1; opt=${2:-speed}; name=$(basename "$v")-$opt
if [ -z "$NOBUILD" ]; then (cd "$v" && $ROC build --target=wasm32 --no-cache --opt=$opt --output="$here/out/$name.wasm" main.roc > "$here/out/$name.log" 2>&1) || { tail -30 "$here/out/$name.log"; exit 1; }; fi
node "$here/../deploy-121/startup/funcsizes.mjs" "$here/out/$name.wasm" | head -5
# the title "Unauthenticated" is the address that the problem table uses; find it per build
node "$here/titles.mjs" "$here/out/$name.wasm"
