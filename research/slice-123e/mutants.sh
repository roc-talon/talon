#!/usr/bin/env bash
# Slice 123e: mutants of worker/ code on a build copy (never in worker/). Each mutant must fail at least one W2 case.
#   research/slice-123e/mutants.sh <name> [runner [filter ...]]     build the mutant <name> into $MUT_DIR/<name> and run worker/tests/<runner> (default run.mjs) on it
#   MUT_DIR   where the build copies go (default: $WORK/mutants)         MUT_LIST=1: print the mutants
# The runner is looked up in RUNNER_DIR (default worker/tests): the old runner needs a copy of the old tests dir (research/slice-123e/before/).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$HERE/../..
. "$ROOT/scripts/env.sh"
ROC=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
MUT_DIR=${MUT_DIR:-$WORK/mutants}
# name | file | old text | new text
mutants() { cat <<'M'
m1-send-delay@@WebhookRoutes.roc@@IndexQueue.index.send!(message).map_err@@IndexQueue.index.send_with!(message, { delay_ms: 5000 }).map_err
m2-retry-delay@@lib/Webhook.roc@@0 | 1 => Ok(60_000)@@0 | 1 => Ok(120_000)
m3-d1-count@@ReadRoutes.roc@@results = session.batch!(stmts).map_err(|e| Fault(Str.inspect(e)))?@@_extra = session.batch!(stmts)\n\t\tresults = session.batch!(stmts).map_err(|e| Fault(Str.inspect(e)))?
m4-rate-limit@@HintRoutes.roc@@Err(RateLimited) => return Ok(limited_response())@@Err(RateLimited) => {}
m5-hint-status@@HintRoutes.roc@@Response.from_bytes(Compat.written_status(written), "application/json"@@Response.from_bytes(200, "application/json"
m6-session@@lib/Reads.roc@@Ok(text) => if (text.trim() == "") Any else After(text.trim())@@Ok(text) => if (text.trim() == "") Any else After("zzz")
m7-timing-safe@@WebhookRoutes.roc@@if WebCrypto.timing_safe_equal!(WebCrypto.hmac_sha256(secret, bytes), given) {@@if WebCrypto.hmac_sha256(secret, bytes) == given {
m8-ignore-send-fail@@ReconcileCron.roc@@Err(e) => return Err({ error: "the send of the candidates failed: ${Str.inspect(e)}", reserve: $reserve })@@Err(_) => {}
q1-consumer-delay@@IndexQueue.roc@@Ok(ms) => m.retry_with!({ delay_ms: ms })@@Ok(ms) => m.retry_with!({ delay_ms: ms * 2 })
q2-ack-must-retry@@IndexQueue.roc@@Err(GiveUp) => m.retry!()@@Err(GiveUp) => m.ack!()
q3-retry-whole-batch@@IndexQueue.roc@@} else if queue == Webhook.queue_name {@@} else if queue == Webhook.queue_name {\n\t\t\tbatch.retry_all!()
q4-dlq-unrouted@@IndexQueue.roc@@if queue == Webhook.dlq_name {@@if queue == "no-such-queue" {
q5-success-no-ack@@IndexQueue.roc@@Ok({}) => m.ack!()@@Ok({}) => {}
M
}
[ -n "${MUT_LIST:-}" ] && { mutants | awk -F'@@' '{ print $1, $2 }'; exit 0; }
name=${1:?mutant name}; shift
runner=${1:-run.mjs}; shift || true
line=$(mutants | grep "^$name@@") || { echo "no mutant $name"; exit 2; }
file=$(awk -F'@@' '{ print $2 }' <<< "$line")
B=$MUT_DIR/$name
rm -rf "$B"; mkdir -p "$B/packages"
cp -r "$ROOT/worker" "$B/worker"; cp -r "$ROOT/packages/records" "$B/packages/records"; cp -r "$ROOT/sql" "$B/sql"
rm -rf "$B/worker/tests" "$B/worker/app.wasm" "$B/worker/archive-test.wasm" "$B/worker/.roc-cfw"
python3 - "$B/worker/$file" "$line" <<'PY'
import sys
f, line = sys.argv[1:3]
_, _, old, new = line.split('@@')
new = new.replace('\\n', '\n').replace('\\t', '\t')
s = open(f).read()
assert s.count(old) == 1, ('the old text occurs %d times' % s.count(old), old)
open(f, 'w').write(s.replace(old, new))
PY
[ $? = 0 ] || exit 2
( cd "$B/worker" && "$ROC" build --target=wasm32 --no-cache --opt=speed --output="$B/app.wasm" main.roc > "$B/build.log" 2>&1 ) || grep -q "0 errors and" "$B/build.log" || { tail -20 "$B/build.log"; echo "BUILD FAILED $name"; exit 2; }
hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$ROOT/worker/main.roc" | head -n 1)
cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$B/.roc-cfw"
archive=${W2_ARCHIVE_WASM:-$(ls -t "$WORK"/worker-archive/*/archive-test.wasm | head -n 1)}
W2_DIR=$B W2_ARCHIVE_WASM=$archive node "${RUNNER_DIR:-$ROOT/worker/tests}/$runner" "$@" > "$B/w2.log" 2>&1
echo "$name: exit $? ; $(grep -c '^FAIL' "$B/w2.log") FAIL lines; $(tail -n 1 "$B/w2.log")"
grep '^FAIL' "$B/w2.log" | head -8
