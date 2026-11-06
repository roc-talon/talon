#!/usr/bin/env bash
# Slice 123e probe: build copy of worker/ with platform 0.0.4 in the headers of the copy only. Usage: build.sh [w0|w2|all] [w2 filter...]
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/build
NEW=0.0.4/AuZxUqJVSbVSbPX9EUhBGLVqgS3yZUE7ZC5VC2EqSeUk
if [ -z "${REUSE:-}" ]; then
  rm -rf "$B"; mkdir -p "$B/packages"
  cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
  rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm"; rm -rf "$B/worker/.roc-cfw"
  sed -i -E "s#roc-cloudflare-workers/releases/download/0\.0\.3/[A-Za-z0-9]+\.tar\.zst#roc-cloudflare-workers/releases/download/$NEW.tar.zst#" "$B/worker/main.roc" "$B/worker/archive-test.roc"
fi
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  ( cd "$B" && "$ROC" test worker/tests/unit/w0.roc --no-cache 2>&1 | grep -E "fail ───|passed|failed|errors|rror" | sed 's/──*/-/g' ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -30 "$B/worker/build.log"; exit 1; }
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=archive-test.wasm archive-test.roc > build-archive.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build-archive.log" || { tail -30 "$B/worker/build-archive.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  rm -rf "$B/worker/.roc-cfw"; cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  /usr/bin/time -f "W2 wall %e s" env W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "$@" || rc=1
fi
exit $rc
