#!/usr/bin/env bash
# Private reference of slice 122 (TW18: the code agent does not read this). Usage: ref.sh [w0|w1|w2|all] [w2 filter...]
# Copies worker/, packages/records and sql/ to refbuild/, applies reference/patch.py (NOREF=1: the stubs), MUTATE=mutations/<m>.py changes the copy after that,
# runs W0 (records and worker), W1 (closure) and/or W2 (the cases of slice 122 by default). The build is --opt=speed.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/refbuild${MUTATE:+-$(basename "$MUTATE" .py)}
if [ -z "${REUSE:-}" ]; then
  rm -rf "$B"; mkdir -p "$B/packages"
  cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
  rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm"
  [ "${NOREF:-}" = 1 ] || python3 "$HERE/reference/patch.py" "$B" || exit 1
else
  rm -f "$B/worker/app.wasm"
fi
[ -n "${MUTATE:-}" ] && { python3 "$HERE/$MUTATE" "$B" || exit 1; }
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  ( cd "$B" && "$ROC" test worker/tests/unit/w0.roc --no-cache 2>&1 | grep -E "fail ───|passed|failed|errors" | grep -v "Login\|Toolchains\|Webhook" | sed 's/──*/-/g' ) || rc=1
  ( cd "$B" && "$ROC" test packages/records/tests/w0.roc --no-cache 2>&1 | grep -E "fail ───|passed|failed|errors" | sed 's/──*/-/g' ) || rc=1
fi
if [ "$what" = w1 ] || [ "$what" = all ]; then
  CLOSURE_SQL_DIR=$B/worker/sql/closure node "$ROOT/sql/tests/run.mjs" closure 2>&1 | tail -${W1_TAIL:-15} || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -30 "$B/worker/build.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  rm -rf "$B/worker/.roc-cfw"; cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  if [ $# -eq 0 ]; then set -- reads/ closure/ ingest/ ingest-limits/ publish/; fi
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "$@" || rc=1
fi
exit $rc
