#!/bin/bash
# Does roc-fuzz 0.4.3 build and find a planted bug on the pinned nightly?
# Usage: run.sh [ROC]
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROC=${1:-$HERE/../../cloudflare-workers/.cache/nightlies/nightly-2026-10-09-258ab27/roc}
W=$HERE/.work; mkdir -p "$W"; export XDG_CACHE_HOME=$W/xdg ROC_CACHE_DIR=$W/xdg/roc
run() { # run <label>: build, then fuzz 200,000 inputs
  rm -rf "$W/$1"; mkdir -p "$W/$1"; cp "$HERE/main.roc" "$W/$1/main.roc"; cp "$W/Semver.roc" "$W/$1/Semver.roc"
  ( cd "$W/$1" && "$ROC" build --fuzz main.roc >build.log 2>&1 ) || { echo "$1: build failed"; tail -20 "$W/$1/build.log"; return; }
  local s=$(date +%s%N)
  ( cd "$W/$1" && ./main run --runs=200000 --seed=1 --artifact-dir=art >run.log 2>&1 ); local rc=$?
  echo "$1: exit $rc, $(( ($(date +%s%N) - s) / 1000000 )) ms, saved failures: $(ls "$W/$1/art" 2>/dev/null | wc -l)"
  grep -m1 -o 'round trip failed for [0-9.]*' "$W/$1/run.log"
}
cp "$HERE/Semver.roc" "$W/Semver.roc"; run correct
sed 's|# if patch|if patch|' "$HERE/Semver.roc" > "$W/Semver.roc"; run planted
