#!/bin/bash
# Slice 223 mutation check (manager). Each mutation gets its own mirror copy of mut/, a private build, and the named cases.
set -u
ROOT=/home/george/dev/Karakatiza666/talon
R=$ROOT/research/slice-223-revert
. $ROOT/scripts/env.sh
run() { # name file sed-expr cases...
  n=$1; f=$2; e=$3; shift 3
  d=$R/m-$n; rm -rf $d; cp -r $R/mut $d
  sed -i "$e" $d/$f
  if cmp -s $R/mut/$f $d/$f; then echo "$n: SED DID NOT APPLY"; return; fi
  if [ "$1" = l0 ]; then
    out=$("$ROC" test $d/tests/unit/l0-9.roc 2>&1 | tail -3 | tr '\n' ' ')
    echo "$n: l0 -> $out"; return
  fi
  "$ROC" build $d/tests/commands/main.roc --no-cache --output=$d/l2 > $d/build.log 2>&1 || { echo "$n: BUILD FAILED"; return; }
  echo "$n: $(cd $ROOT && L2BIN=$d/l2 tests/commands/run.sh "$@" 2>&1 | grep -E '^(FAIL|commands:)' | tr '\n' ' ')"
}
run m1 bot/lib/Bot.roc 's/chunks_of(500)/chunks_of(501)/' bot/b16-chunks bot/b1-sweep &
run m2 bot/lib/BotFlow.roc '152s/state.n >= 2/state.n >= 3/' bot/b14-sweep-incomplete-twice bot/b13-sweep-incomplete &
wait
run m3 bot/lib/BotFlow.roc '249s/answer.status < 500 and answer.status != 429/answer.status < 600/' bot/b26-artifact-503 bot/b25-artifact-404 &
run m4 bot/lib/BotFlow.roc '283s/retries, renewed/retries: 3, renewed/' bot/b22-read-retry bot/b23-read-no-answer &
wait
run m5 bot/lib/Bot.roc '175s/status == 429 or status >= 500/status >= 500/' l0
