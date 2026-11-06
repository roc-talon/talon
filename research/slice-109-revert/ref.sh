#!/usr/bin/env bash
# Runs the slice 109 tests against the private reference (reference/ over a copy of worker/). Usage: ref.sh [w0|w2|all] [w2 filter...]
# MUTATE=<file> applies a python mutation script (it edits files of the copy) before the run.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$ROOT/scripts/env.sh"
ROC=$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
B=$HERE/refbuild
rm -rf "$B"; mkdir -p "$B"
rsync -a --exclude app.wasm --exclude .roc-cfw --exclude .wrangler "$ROOT/worker/" "$B/worker/"
rsync -a "$ROOT/packages/" "$B/packages/"
[ -z "${NOREF:-}" ] && cp -r "$HERE/reference/worker/." "$B/worker/"
rm -f "$B/worker/tests/unit/w0-109tmp.roc"
[ -n "${MUTATE:-}" ] && python3 -I "$MUTATE" "$B/worker"
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  # Only the unit module of this slice: the modules of other slices may be red or not yet compiling.
  printf '%s\n\nimport ToolchainsTest\n\nmain! = |_args| Ok({})\n' "$(head -1 "$B/worker/tests/unit/w0.roc")" > "$B/worker/tests/unit/w0-109.roc"
  ( cd "$B/worker/tests/unit" && "$ROC" test w0-109.roc --no-cache 2>&1 | tail -n 40 ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > "$B/build.log" 2>&1 ) || { tail -40 "$B/build.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  W2_DIR=$B/worker node "$ROOT/worker/tests/run.mjs" "${@:-toolchains}" || rc=1
fi
exit $rc
