#!/usr/bin/env bash
# Small app (3 modules in a package, sort_with on records and tags). 2 builds with one object cache, then a build with objects-v7 removed. It gives NO crash (RESULTS.md, small cases).
set -eu
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../.." && pwd); . "$root/scripts/env.sh"
OPT=${OPT:-dev}; T=$here/tmp/small; rm -rf "$T"; mkdir -p "$T"; cp -r "$here"/small/. "$T"/
export XDG_CACHE_HOME=$T/cache ROC_CACHE_DIR=$T/cache/roc
mkdir -p "$ROC_CACHE_DIR"; [ -d "$root/.work/cache/roc/packages" ] && cp -r "$root/.work/cache/roc/packages" "$ROC_CACHE_DIR/packages"
cd "$T"
echo "build 1"; "$ROC" build main.roc --opt="$OPT" --output="$T/app1" 2>&1 | tail -n 2; "$T/app1"
sed -i 's/^## Leaf module.*/## Leaf module. Edited comment.\n## Second line./' lib/A.roc
echo "build 2, same cache"; "$ROC" build main.roc --opt="$OPT" --output="$T/app2" 2>&1 | tail -n 2; "$T/app2" || echo "exit $?"
rm -rf "$ROC_CACHE_DIR"/compat-*/objects-v7
echo "build 3, objects-v7 removed"; "$ROC" build main.roc --opt="$OPT" --output="$T/app3" 2>&1 | tail -n 2; "$T/app3" || echo "exit $?"
