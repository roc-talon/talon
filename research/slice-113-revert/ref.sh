#!/usr/bin/env bash
# Private reference of slice 113 (not for the code agent, TW18). Usage: research/slice-113-revert/ref.sh [w0|w2|all] [w2 filter...]
# Copies worker/, packages/records and sql/ to refbuild/, puts reference/ over it (NOREF=1: the stubs), runs patch.py (the IngestRoutes change), MUTATE=mutations/<m>.py changes the copy,
# runs W0 (IdentityTest) and/or W2 (identity/ by default). The build is --opt=speed (roc-lang/roc#12782).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
B=$HERE/refbuild${MUTATE:+-$(basename "$MUTATE" .py)}
rm -rf "$B"; mkdir -p "$B/packages"
cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
rm -f "$B/worker/app.wasm" "$B/worker/archive-test.wasm" "$B/worker/tests/unit/w0-113.roc"
if [ "${NOREF:-}" != 1 ]; then cp -r "$HERE/reference/worker/." "$B/worker/"; python3 "$HERE/patch.py" "$B/worker" || exit 1; fi
if [ ! -f "$B/worker/LoginRoutes.roc" ] && grep -q "import LoginRoutes" "$B/worker/main.roc"; then
  # slice 117 is in progress and its file may be missing: a stub for the build of this private run
  cat > "$B/worker/LoginRoutes.roc" <<'R'
import pf.Request
import pf.Response
import pf.RateLimit
import lib.Problem

LoginRoutes :: [].{
	limiter = RateLimit.binding("RL_LOGIN")

	post_tokens! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
	post_tokens! = |_req| Err(Fault("stub"))

	delete_tokens! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
	delete_tokens! = |_req| Err(Fault("stub"))

	get_me! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
	get_me! = |_req| Err(Fault("stub"))

	delete_me! : Request => Try(Response, [Refuse(Problem), Fault(Str)])
	delete_me! = |_req| Err(Fault("stub"))
}
R
fi
# the runner may not give RL_LOGIN yet (slice 117 in progress): the private run does not use it
sed -i 's/, LoginRoutes.limiter.declare()//' "$B/worker/main.roc"
[ -n "${MUTATE:-}" ] && python3 "$HERE/$MUTATE" "$B/worker"
what=${1:-all}; shift || true
rc=0
if [ "$what" = w0 ] || [ "$what" = all ]; then
  { head -n 1 "$B/worker/tests/unit/w0.roc"; printf '\nimport IdentityTest\n\nmain! = |_args| Ok({})\n'; } > "$B/worker/tests/unit/w0-113.roc"
  ( cd "$B/worker" && set -o pipefail && "$ROC" test tests/unit/w0-113.roc --no-cache 2>&1 | tail -${W0_TAIL:-60} ) || rc=1
fi
if [ "$what" = w2 ] || [ "$what" = all ]; then
  ( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc > build.log 2>&1 ) || grep -q "0 errors and" "$B/worker/build.log" || { tail -30 "$B/worker/build.log"; exit 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$B/worker/main.roc" | head -n 1)
  rm -rf "$B/worker/.roc-cfw"; cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/worker/.roc-cfw"
  W2_DIR=$B/worker node "$B/worker/tests/run.mjs" "${@:-identity/}" || rc=1
fi
exit $rc
