#!/usr/bin/env bash
# Private reference of slice 247 (test agent, not for the code agent, TW18). Usage: research/slice-247-revert/ref.sh [w0|w2|rec|all] [w2 filter...]
# Copies worker/, packages/records and sql/ to refbuild/, puts reference/ over it (NOREF=1: the stubs), MUTATE=mutations/<m>.py changes the copy (the mutation gets the copy root),
# runs W0 (MoveTest, RouteTest, ClientTest), the records W0 and/or W2 (move/ by default). The build is --opt=speed. Memory: run it under systemd-run (CLAUDE.md).
set -u -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/refbuild${MUTATE:+-$(basename "$MUTATE" .py)}
rm -rf "$B"; mkdir -p "$B/packages"
cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm"
if [ "${NOREF:-}" != 1 ]; then cp -r "$HERE/reference/worker/." "$B/worker/"; cp -r "$HERE/reference/packages/records/." "$B/packages/records/"; python3 "$HERE/patch.py" "$B/worker" || exit 1; fi
[ -n "${MUTATE:-}" ] && python3 "$HERE/$MUTATE" "$B"
what=${1:-all}; shift || true
rc=0
if [ "$what" = rec ] || [ "$what" = all ]; then
  ( cd "$B/packages/records/tests" && printf '%s\n' "$(head -n 1 w0.roc)" '' 'import MoveTest' 'import OwnerChangedTest' 'import WireTest' 'import AnswerTest' '' 'main! = |_args| Ok({})' > w0-247.roc && "$ROC" test w0-247.roc --no-cache 2>&1 | tail -${W0_TAIL:-40} ) || rc=1
fi
if [ "$what" = w0 ] || [ "$what" = all ]; then
  { head -n 1 "$B/worker/tests/unit/w0.roc"; printf '\nimport MoveTest\nimport RouteTest\nimport ClientTest\nimport ReadsTest\nimport ClosureQueryTest\n\nmain! = |_args| Ok({})\n'; } > "$B/worker/tests/unit/w0-247.roc"
  ( cd "$B/worker" && "$ROC" test tests/unit/w0-247.roc --no-cache 2>&1 | tail -${W0_TAIL:-60} ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -40 "$B/worker/build.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  rm -rf "$B/worker/.roc-cfw"; cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  W2_DIR=$B/worker W2_TMP=${TMPDIR:-} node "$B/worker/tests/run.mjs" "${@:-move/}" || rc=1
fi
exit $rc
