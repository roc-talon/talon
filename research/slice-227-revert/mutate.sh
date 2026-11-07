#!/bin/bash
# Slice 227 mutation check. Each mutant is a copy of worker/ and packages/records with one sed change,
# a private build (same roc command as scripts/test.sh worker_build), then worker/tests/run.mjs on it.
# Usage: research/slice-227-revert/mutate.sh   (builds the 4 mutants at the same time, then runs w2 on each in turn)
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-227-revert
. $ROOT/scripts/env.sh
ROC_WORKER=${ROC_WORKER:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc}
mutant() { # name sed-expr
  local d=$R/m-$1
  rm -rf "$d"; mkdir -p "$d/packages"
  cp -r "$ROOT/worker" "$d/worker" && rm -rf "$d/worker/.roc-cfw" "$d/worker/app.wasm"
  cp -r "$ROOT/packages/records" "$d/packages/records"
  sed -i "$2" "$d/worker/main.roc"
  if cmp -s "$ROOT/worker/main.roc" "$d/worker/main.roc"; then echo "$1: SED DID NOT APPLY"; return 1; fi
  ( cd "$d/worker" && "$ROC_WORKER" build --target=wasm32 --no-cache --opt=speed --output="$d/app.wasm" main.roc ) > "$d/build.log" 2>&1
  [ -f "$d/app.wasm" ] || { echo "$1: BUILD FAILED (see $d/build.log)"; return 1; }
  hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$ROOT/worker/main.roc" | head -n 1)
  cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$d/.roc-cfw"
}
# m1: a failed bot check on PUT toolchain is a fault (500 internal) in place of its own problem
mutant m1 's/Err(problem) => Err(Refuse(problem))/Err(_) => Err(Fault("x"))/' &
# m2: read_answer gives every refusal as the problem Internal
mutant m2 's/Err(Refuse(problem)) => Ok(problem_response(problem))/Err(Refuse(_)) => Ok(problem_response(Problem.new(Internal, "x")))/' &
# m3: the webhook arm runs the handler of another route
mutant m3 's/PostWebhook => WebhookRoutes.post!(req)/PostWebhook => LoginRoutes.get_me!(req)/' &
# m4: the answer to a fault of a handler has another detail text
mutant m4 's/the Worker failed to handle the request/x/' &
wait
for m in m1 m2 m3 m4; do
  d=$R/m-$m
  [ -f "$d/.roc-cfw/index.js" ] || { echo "$m: not built"; continue; }
  echo "== $m"
  ( cd "$ROOT" && W2_DIR=$d node worker/tests/run.mjs 2>&1 | tail -15 )
done
