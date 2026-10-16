#!/bin/bash
# Compiled fuzz targets: which Hex call is wrong? Usage: run.sh <nightly-tag>...
HERE=$(cd "$(dirname "$0")" && pwd)
for v in "$@"; do
	ROC=$HERE/../../../cloudflare-workers/.cache/nightlies/$v/roc; ROC=$(cd "$(dirname "$ROC")" && pwd)/roc
	W=$HERE/.work/$v; mkdir -p "$W"; export XDG_CACHE_HOME=$W/xdg ROC_CACHE_DIR=$W/xdg/roc
	for t in ${TARGETS:-selfeq rt}; do
		(cd "$HERE" && timeout 120 "$ROC" build --fuzz $t.roc --output="$W/$t" >"$W/$t.build.log" 2>&1) || { echo "$v $t: build failed"; continue; }
		timeout 30 "$W/$t" run --runs=20000 --seed=1 --time=0 --artifact-dir="$W/art-$t" >"$W/$t.log" 2>&1
		echo "$v $t: exit $?"
	done
done
