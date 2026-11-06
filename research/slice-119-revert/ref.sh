#!/usr/bin/env bash
# Private reference of slice 119b (the reconcile; not for the code agent, TW18). Usage: research/slice-119-revert/ref.sh [w0|w2|all] [w2 filter...]
# Copies worker/, packages/records and sql/ to refbuild[-<mutation>]/, puts reference/ over it (NOREF=1: the stubs), MUTATE=mutations/<m>.py changes the copy,
# REFDIR=reference-119c uses the reference of 119c.
# runs W0 (ReconcileTest) and/or W2 (reconcile/ by default). The build is --opt=speed, never dev. KEEP=1 reuses the last build of the same dir.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/refbuild${REFDIR:+-$REFDIR}${MUTATE:+-$(basename "$MUTATE" .py)}
if [ "${KEEP:-}" != 1 ]; then
  rm -rf "$B"; mkdir -p "$B/packages"
  cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
  rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm"
  if [ "${NOREF:-}" != 1 ]; then cp -r "$HERE/${REFDIR:-reference}/worker/." "$B/worker/"; fi
  [ -n "${MUTATE:-}" ] && python3 "$HERE/$MUTATE" "$B/worker"
fi
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  { head -n 1 "$B/worker/tests/unit/w0.roc"; printf '\nimport ReconcileTest\nimport WebhookTest\n\nmain! = |_args| Ok({})\n'; } > "$B/worker/tests/unit/w0-119.roc"
  ( cd "$B/worker" && set -o pipefail && "$ROC" test tests/unit/w0-119.roc --no-cache 2>&1 | tail -${W0_TAIL:-40} ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  if [ "${KEEP:-}" != 1 ] || [ ! -f "$B/worker/app.wasm" ]; then
    ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -30 "$B/worker/build.log"; exit 1; }
  fi
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  rm -rf "$B/worker/.roc-cfw"; cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  if [ "$#" -eq 0 ]; then set -- reconcile/; fi
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "$@" || rc=1
fi
exit $rc
