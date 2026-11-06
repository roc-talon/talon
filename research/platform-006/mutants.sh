#!/usr/bin/env bash
# Platform 0.0.6 (TW12): mutants of the delay path of worker/tests/run.mjs (`sentOf`). Each mutant must fail W2 cases that have `queue_sent` delay_s.
# Usage: research/platform-006/mutants.sh   (needs a build: scripts/test.sh wbuild). The mutant is a copy, run-mut.mjs, removed at the end. worker/tests/run.mjs is not changed.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd); cd "$ROOT"
. scripts/env.sh
D=$(ls -dt "$WORK"/worker/*/ | head -1)
export W2_DIR=${D%/}; export W2_ARCHIVE_WASM=$(ls "$W2_DIR"/archive-test.wasm 2> /dev/null || true)
SRC=worker/tests/run.mjs; MUT=worker/tests/run-mut.mjs
trap 'rm -f "$MUT"' EXIT
run() { # name, python replace old, new
  python3 - "$SRC" "$MUT" "$2" "$3" <<'P'
import sys
s=open(sys.argv[1]).read()
assert s.count(sys.argv[3])==1, 'old text not found once'
open(sys.argv[2],'w').write(s.replace(sys.argv[3],sys.argv[4]))
P
  echo "== $1"; node "$MUT" reconcile webhook runner 2>&1 | grep -E "^FAIL|^w2:"
}
run m1-drop-delay "delay_s: it.delaySeconds ?? 0 }" "delay_s: 0 }"
run m2-batch-own-only "b.delaySeconds ?? it.delaySeconds ?? 0" "b.delaySeconds ?? 0"
run m3-batch-option-only "b.delaySeconds ?? it.delaySeconds ?? 0" "it.delaySeconds ?? 0"
run m4-send-plus-one "delay_s: it.delaySeconds ?? 0 }" "delay_s: (it.delaySeconds ?? 0) + 1 }"
