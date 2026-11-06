#!/usr/bin/env bash
# Private reference of slice 111 (not for the code agent, TW18). Usage: research/slice-111-revert/ref.sh [w0|w2|all] [w2 filter...]
# Copies worker/ and packages/records to refbuild/, puts reference/ over it (NOREF=1: the stubs), MUTATE=mutations/<m>.py changes the copy, runs W0 and/or W2.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/refbuild${MUTATE:+-$(basename "$MUTATE" .py)}
rm -rf "$B"; mkdir -p "$B/packages"
cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm"
[ "${NOREF:-}" = 1 ] || cp -r "$HERE/reference/worker/." "$B/worker/"
[ -n "${MUTATE:-}" ] && python3 "$HERE/$MUTATE" "$B/worker"
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  # A driver with ArchiveReadTest only: the other unit modules belong to other slices.
  { head -n 1 "$B/worker/tests/unit/w0.roc"; printf '\nimport ArchiveReadTest\n\nmain! = |_args| Ok({})\n'; } > "$B/worker/tests/unit/w0-111.roc"
  ( cd "$B/worker" && "$ROC" test tests/unit/w0-111.roc --no-cache 2>&1 | tail -${W0_TAIL:-60} ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=archive-test.wasm archive-test.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -30 "$B/worker/build.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  cp "$B/worker/archive-test.wasm" "$B/worker/app.wasm"   # run.mjs needs app.wasm to start; the archive cases use archive-test.wasm
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "${@:-archive/}" || rc=1
fi
exit $rc
