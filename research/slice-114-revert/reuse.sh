#!/usr/bin/env bash
# Private (TW18): runs W2 on a copy of refbuild/ (the last good reference build) with one mutation. Use when the live IngestRoutes.roc and Auth.roc already hold the code agent's work and patch.py no longer applies.
# Usage: reuse.sh mutations/<m>.py [w2 filter...]
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
M=$1; shift
B=$HERE/refbuild-$(basename "$M" .py)
rm -rf "$B"; cp -r "$HERE/refbuild" "$B"; rm -f "$B/worker/app.wasm"
python3 "$HERE/$M" "$B/worker" || exit 1
( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -30 "$B/worker/build.log"; exit 1; }
W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "${@:-publish/}"
