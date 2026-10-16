#!/bin/bash
# Use each released generic package by its release URL, from an empty cache:
# roc check and roc test on one small app per package. Usage: run.sh [ROC] [app.roc...]
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROC=${1:-$HERE/../../cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc}
ROC=$(cd "$(dirname "$ROC")" && pwd)/roc
shift || true
APPS=("$@"); [ ${#APPS[@]} -gt 0 ] || APPS=("$HERE"/*.roc)
FAIL=0
for app in "${APPS[@]}"; do
	n=$(basename "$app" .roc); W=$HERE/.work/$n; rm -rf "$W"; mkdir -p "$W"
	export XDG_CACHE_HOME=$W/xdg ROC_CACHE_DIR=$W/xdg/roc
	"$ROC" check "$app" >"$W/check.log" 2>&1; c=$?
	"$ROC" test "$app" >"$W/test.log" 2>&1; t=$?
	echo "$n: check exit $c, test exit $t, $(grep -Eo 'All \([0-9]+\) tests passed|[0-9]+ failed' "$W/test.log" | head -1)"
	[ $c = 0 ] && [ $t = 0 ] || FAIL=1
done
exit $FAIL
