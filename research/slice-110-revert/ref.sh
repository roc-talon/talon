#!/usr/bin/env bash
# Runs the slice 110 tests against the private reference (reference/ over a copy of worker/). Usage: ref.sh [w0|w1|w2|all] [w2 filter...]
# reference/overlay/worker/ goes over the copy; the main.roc edit of the slice file section 3.4 is made with sed; reference/sql/closure/ is the SQL.
# MUTATE=<name> applies a mutation of mutations/sql.py to the SQL (w1, w2), or MUTATE_PY=<file> a python script that edits the copy of worker/.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$ROOT/scripts/env.sh"
ROC=$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
B=$HERE/refbuild
# KEEP=1 keeps the app.wasm of the last run (the build takes about 60 s): only for a change of tests, never for a change of Roc code.
[ -n "${KEEP:-}" ] && [ -f "$B/worker/app.wasm" ] && cp "$B/worker/app.wasm" "$HERE/.app.wasm.keep"
rm -rf "$B"; mkdir -p "$B"
rsync -a --exclude app.wasm --exclude .roc-cfw --exclude .wrangler "$ROOT/worker/" "$B/worker/"
rsync -a "$ROOT/packages/" "$B/packages/"
rsync -a "$ROOT/sql/" "$B/sql/"
python3 -I "$HERE/reference/records_nullable.py" "$B/packages"
[ -n "${FOR101:-}" ] && cp -r "$HERE/for-101/." "$B/worker/tests/cases/"
SQL=$HERE/reference/sql/closure
if [ -n "${MUTATE:-}" ]; then python3 -I "$HERE/mutations/sql.py" "$MUTATE" "$SQL" "$B/sql-mut" || exit 1; SQL=$B/sql-mut; fi
if [ -z "${NOREF:-}" ]; then
  cp -r "$HERE/reference/overlay/worker/." "$B/worker/"
  mkdir -p "$B/worker/sql/closure"; cp "$SQL"/*.sql "$B/worker/sql/closure/"
  sed -i 's/^import ReadRoutes$/import ReadRoutes\nimport ClosureRoute/; s/PostClosure => Err(NotBuilt)/PostClosure => read_answer(ClosureRoute.post!(req))/' "$B/worker/main.roc"
fi
[ -n "${MUTATE_PY:-}" ] && python3 -I "$MUTATE_PY" "$B/worker"
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  printf '%s\n\nimport ClosureQueryTest\nimport ProblemTest\n\nmain! = |_args| Ok({})\n' "$(head -1 "$B/worker/tests/unit/w0.roc")" > "$B/worker/tests/unit/w0-110.roc"
  ( cd "$B/worker/tests/unit" && "$ROC" test w0-110.roc --no-cache 2>&1 | tail -n 30 ) || rc=1
fi
if [ "$what" = w1 ] || [ "$what" = all ]; then
  CLOSURE_SQL_DIR=$SQL node "$ROOT/sql/tests/run.mjs" closure || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  if [ -n "${KEEP:-}" ] && [ -f "$HERE/.app.wasm.keep" ]; then mv "$HERE/.app.wasm.keep" "$B/worker/app.wasm"; else
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > "$B/build.log" 2>&1 ) || { tail -40 "$B/build.log"; exit 1; }
  fi
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "${@:-closure router}" || rc=1
fi
exit $rc
