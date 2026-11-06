#!/usr/bin/env bash
# Runs the slice 109b tests against the private reference (reference/ over a copy of worker/, sql/ and packages/; the schema column is added in the copy only).
# Usage: ref.sh [w0|w2|w1|all] [w2 filter...]. MUTATE=<file> applies a python mutation (it edits files of the copy). NOREF=1: no reference, no schema change (the red state).
# OPT=dev builds with --opt=dev; the default is --opt=speed.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$ROOT/scripts/env.sh"
ROC=$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
B=$HERE/refbuild
rm -rf "$B"; mkdir -p "$B"
rsync -a --exclude app.wasm --exclude .roc-cfw --exclude .wrangler "$ROOT/worker/" "$B/worker/"
rsync -a "$ROOT/packages/" "$B/packages/"
rsync -a "$ROOT/sql/" "$B/sql/"
rm -f "$B"/worker/tests/unit/w0-109*tmp.roc
if [ -z "${NOREF:-}" ]; then
  cp -r "$HERE/reference/worker/." "$B/worker/"
  python3 -I - "$B/sql/0001_init.sql" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "  sha256 TEXT NOT NULL,\n  published_at INTEGER NOT NULL,\n  log_index INTEGER NOT NULL,\n  PRIMARY KEY (nightly, target)"
assert old in s, "toolchains table not found"
open(p, "w").write(s.replace(old, "  sha256 TEXT NOT NULL,\n  size INTEGER NOT NULL CHECK (size > 0),\n  published_at INTEGER NOT NULL,\n  log_index INTEGER NOT NULL,\n  PRIMARY KEY (nightly, target)", 1))
PY
fi
[ -n "${MUTATE:-}" ] && python3 -I "$MUTATE" "$B/worker"
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  printf '%s\n\nimport ToolchainsTest\n\nmain! = |_args| Ok({})\n' "$(head -1 "$B/worker/tests/unit/w0.roc")" > "$B/worker/tests/unit/w0-109b.roc"
  ( cd "$B/worker/tests/unit" && "$ROC" test w0-109b.roc --no-cache 2>&1 | tail -n 12 ) || rc=1
fi
if [ "$what" = w1 ] || [ "$what" = all ]; then
  ( cd "$B" && node sql/tests/run.mjs "${W1FILTER:-}" 2>&1 | tail -n 400 ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt="${OPT:-speed}" --output=app.wasm main.roc > "$B/build.log" 2>&1 ) || { tail -40 "$B/build.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "${@:-toolchains}" || rc=1
fi
exit $rc
