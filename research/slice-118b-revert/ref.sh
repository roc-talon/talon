#!/usr/bin/env bash
# Private reference of slice 118b (the job Release; not for the code agent, TW18). Usage: research/slice-118b-revert/ref.sh [w0|w2|all] [w2 filter...]
# Copies worker/, packages/records and sql/ to refbuild/, puts reference/ over it (NOREF=1: the stubs), MUTATE=mutations/<m>.py changes the copy,
# runs W0 (WebhookTest) and/or W2 (webhook/ by default). The build is --opt=speed (roc-lang/roc#12782), never dev.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/refbuild${MUTATE:+-$(basename "$MUTATE" .py)}
rm -rf "$B"; mkdir -p "$B/packages"
cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm" "$B/worker/tests/unit/w0-118.roc"
if [ "${NOREF:-}" != 1 ]; then cp -r "$HERE/reference/worker/." "$B/worker/"; fi
[ -n "${MUTATE:-}" ] && python3 "$HERE/$MUTATE" "$B/worker"
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  { head -n 1 "$B/worker/tests/unit/w0.roc"; printf '\nimport WebhookTest\n\nmain! = |_args| Ok({})\n'; } > "$B/worker/tests/unit/w0-118.roc"
  ( cd "$B/worker" && set -o pipefail && "$ROC" test tests/unit/w0-118.roc --no-cache 2>&1 | tail -${W0_TAIL:-60} ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -30 "$B/worker/build.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  rm -rf "$B/worker/.roc-cfw"; cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  if [ "$#" -eq 0 ]; then set -- webhook/; fi
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "$@" || rc=1
fi
exit $rc
