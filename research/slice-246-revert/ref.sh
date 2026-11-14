#!/usr/bin/env bash
# Private reference of slice 246 (not for the code agent, TW18). Usage: research/slice-246-revert/ref.sh [w0|w2|all] [w2 filter...]
# Copies worker/, packages/records and sql/ to refbuild/, puts reference/ over it (NOREF=1: the stubs), MUTATE=mutations/<m>.py changes the copy,
# runs W0 (YankTest of records and of worker) and/or W2 (yank/ by default). The build is --opt=speed.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/refbuild${MUTATE:+-$(basename "$MUTATE" .py)}
rm -rf "$B"; mkdir -p "$B/packages"
cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm" "$B/worker/tests/unit/w0-246.roc" "$B/packages/records/tests/w0-246.roc"
if [ "${NOREF:-}" != 1 ]; then
  cp -r "$HERE/reference/worker/." "$B/worker/"; cp "$HERE/reference/records/Yank.roc" "$B/packages/records/Yank.roc"
  python3 "$HERE/patch.py" "$B/worker" || exit 1
fi
[ -n "${MUTATE:-}" ] && { python3 "$HERE/$MUTATE" "$B" || exit 1; }
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  { head -n 1 "$B/worker/tests/unit/w0.roc"; printf '\nimport YankTest\n\nmain! = |_args| Ok({})\n'; } > "$B/worker/tests/unit/w0-246.roc"
  ( cd "$B/worker" && set -o pipefail && "$ROC" test tests/unit/w0-246.roc --no-cache 2>&1 | tail -${W0_TAIL:-40} ) || rc=1
  { head -n 1 "$B/packages/records/tests/w0.roc"; printf '\nimport YankTest\n\nmain! = |_args| Ok({})\n'; } > "$B/packages/records/tests/w0-246.roc"
  ( cd "$B/packages/records" && set -o pipefail && "$ROC" test tests/w0-246.roc --no-cache 2>&1 | tail -${W0_TAIL:-40} ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -40 "$B/worker/build.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  rm -rf "$B/worker/.roc-cfw"; cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "${@:-yank/}" || rc=1
fi
exit $rc
