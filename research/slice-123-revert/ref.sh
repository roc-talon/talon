#!/usr/bin/env bash
# Private reference of slice 123 (TW18: the code agent does not read this). Usage: ref.sh [w0|w2|all] [w2 filter...]
# Copies worker/, packages/records and sql/ to refbuild/, applies reference/patch.py (NOREF=1: no patch), MUTATE=mutations/<m>.py changes the copy after that,
# runs W0 (worker) and/or W2 (the cases of the filter, default: all). The build is --opt=speed. REUSE=1 keeps the copy (only the files that a mutation changes are rebuilt).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/refbuild${MUTATE:+-$(basename "$MUTATE" .py)}
if [ -z "${REUSE:-}" ]; then
  rm -rf "$B"; mkdir -p "$B/packages"
  cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
  rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm"; rm -rf "$B/worker/.roc-cfw"
  [ "${NOREF:-}" = 1 ] || python3 "$HERE/reference/patch.py" "$B" || exit 1
else
  rsync -a "$ROOT/worker/tests/" "$B/worker/tests/"
fi
true
[ -n "${MUTATE:-}" ] && { python3 "$HERE/$MUTATE" "$B" || exit 1; }
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
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "$@" || rc=1
  node "$ROOT/worker/tests/trap-table.mjs" "$B/worker" || rc=1
fi
exit $rc
