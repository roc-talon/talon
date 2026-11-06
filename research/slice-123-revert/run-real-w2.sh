#!/usr/bin/env bash
# W2 and wtrap on the real code with one mutation each (3 at the same time). Logs: real-<m>.w2.log
cd "$(dirname "$0")"
run() { NOREF=1 MUTATE=mutations/real/$1.py ./ref.sh w2 "${@:2}" > real-$1.w2.log 2>&1; echo done >> real-$1.w2.log; }
run r5-feed-no-loop archive/pu38-zero archive/pu38-hash &
run r6-jwks-memo-1h oidc/tp3 &
run r7-retry-after-cpu shorts/ap7 &
wait
run r8-decoded-not-kept archive/pu38-zero &
run r9-ff-kept-raw shorts/ap7 &
run r10-wrong-title shorts/ap7 &
wait
echo all-done > real-w2.done
