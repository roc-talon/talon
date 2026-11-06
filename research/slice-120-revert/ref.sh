#!/usr/bin/env bash
# Runs the slice 120 tests against the private reference (reference/overlay/ over a copy of worker/). Usage: ref.sh [w0|w2|all] [w2 filter...]
# MUTATE_PY=<file> and ROC_MUT=<name>: a python script of mutations/ that edits the copy of worker/ (Roc mutations). NOREF=1: the stubs of worker/ with no reference (the red check).
# KEEP=1 keeps the app.wasm of the last run (the build takes about 60 s): only for a change of tests, never for a change of Roc code.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$ROOT/scripts/env.sh"
ROC=$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
B=$HERE/refbuild
[ -n "${KEEP:-}" ] && [ -f "$B/worker/app.wasm" ] && cp "$B/worker/app.wasm" "$HERE/.app.wasm.keep"
rm -rf "$B"; mkdir -p "$B"
rsync -a --exclude app.wasm --exclude .roc-cfw --exclude .wrangler "$ROOT/worker/" "$B/worker/"
rsync -a "$ROOT/packages/" "$B/packages/"
rsync -a "$ROOT/sql/" "$B/sql/"
if [ -z "${NOREF:-}" ]; then
  cp -r "$HERE/reference/overlay/worker/." "$B/worker/"
fi
[ -n "${MUTATE_PY:-}" ] && python3 -I "$MUTATE_PY" "$B/worker"
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  printf '%s\n\nimport DailyTest\n\nmain! = |_args| Ok({})\n' "$(head -1 "$B/worker/tests/unit/w0.roc")" > "$B/worker/tests/unit/w0-120.roc"
  ( cd "$B/worker/tests/unit" && "$ROC" test w0-120.roc --no-cache 2>&1 | tail -n "${W0_TAIL:-60}" ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  if [ -n "${KEEP:-}" ] && [ -f "$HERE/.app.wasm.keep" ]; then mv "$HERE/.app.wasm.keep" "$B/worker/app.wasm"; else
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > "$B/build.log" 2>&1 ) || { grep -q "^0 errors" "$B/build.log" && [ -f "$B/worker/app.wasm" ] || { tail -40 "$B/build.log"; exit 1; }; }
  fi
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "${@:-cron}" || rc=1
fi
exit $rc
