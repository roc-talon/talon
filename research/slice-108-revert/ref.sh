#!/usr/bin/env bash
# Runs the slice 108 tests against the private reference (reference/ over a copy of worker/). Usage: ref.sh [w0|w2|all] [w2 filter...]
# MUTATE=<file> applies a python mutation script (it edits files of the copy) before the run.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$ROOT/scripts/env.sh"
ROC=$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
B=$HERE/refbuild
rm -rf "$B"; mkdir -p "$B"
rsync -a --exclude app.wasm --exclude .roc-cfw --exclude .wrangler "$ROOT/worker/" "$B/worker/"
cp -r "$HERE/reference/worker/." "$B/worker/"
[ -n "${MUTATE:-}" ] && python3 -I "$MUTATE" "$B/worker"
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  ( cd "$B/worker/tests/unit" && "$ROC" test w0.roc --no-cache 2>&1 | tail -n 40 ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > "$B/build.log" 2>&1 ) || { cat "$B/build.log" | tail -40; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  W2_DIR=$B/worker node "$ROOT/worker/tests/run.mjs" "${@:-oidc}" || rc=1
fi
exit $rc
