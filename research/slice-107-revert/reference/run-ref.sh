#!/usr/bin/env bash
# Runs the slice 107 W2 cases against the private reference, with the runner changes RR1 and RR2 (research/slice-107-revert/runner/).
#   research/slice-107-revert/reference/run-ref.sh [filter ...]      BUILD=0 skips the build of app.wasm
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
. "$root/scripts/env.sh"
ROCW=$root/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
"$here/mk-ref.sh"
if [ "${BUILD:-1}" = 1 ]; then
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$here/worker/main.roc" | head -n 1)
  ( cd "$here/worker" && "$ROCW" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc || test -s app.wasm )
  rm -rf "$here/worker/.roc-cfw"; cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$here/worker/.roc-cfw"
fi
stage=$here/stage
rm -rf "$stage"; mkdir -p "$stage/worker"
ln -s "$root/sql" "$stage/sql"
cp -r "$root/worker/tests" "$stage/worker/tests"
# the runner is in worker/tests now (RR1 to RR3 applied)
W2_DIR=$here/worker node "$stage/worker/tests/run.mjs" "$@"
