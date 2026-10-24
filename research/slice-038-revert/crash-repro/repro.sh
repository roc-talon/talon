#!/usr/bin/env bash
# Slice 038: the roc object cache (`objects-v7` in ROC_CACHE_DIR) gives a bad test app when the sources change between 2 builds. Roc nightly-2026-10-14-38a3029.
# Steps: build the L2 app with the reference sources, run it (93 cases pass). Change to the stub sources and build again with the SAME cache: the app crashes
# in 37 old cases ("boxy runtime list comparator ordering layout failed", or a segmentation fault). Remove `objects-v7` and build again: 90 pass, 3 fail (todo).
# The script puts the stub sources in cli/lib at the end (the state of the slice). Usage: research/slice-038-revert/crash-repro/repro.sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
root=$(cd "$here/../.." && pwd)
cd "$root"
roc=$root/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc
cache=$(mktemp -d)
export XDG_CACHE_HOME=$cache ROC_CACHE_DIR=$cache/roc
files="Upgrade Lags Ranges Vars Pick PickFlow InstallFlow ResolveBase PickAsk Run main"
put() { for f in $files; do cp "$here/$1/$f.roc" "cli/lib/$f.roc"; done; }
run() { "$roc" build tests/commands/main.roc --opt=dev --output="$cache/l2" > "$cache/build.log" 2>&1; L2BIN=$cache/l2 tests/commands/run.sh 2>&1 | grep '^commands'; }
echo "(the reference was deleted at the review of slice 038: this step needs it)"
put stubs; echo "stubs, same cache (bad app):"; run
rm -rf "$ROC_CACHE_DIR"/compat-*/objects-v7; echo "stubs, objects-v7 removed:"; run
rm -rf "$cache"
