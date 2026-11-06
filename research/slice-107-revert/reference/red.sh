#!/usr/bin/env bash
# Runs the slice 107 W2 cases against the STUBS (a copy of worker/ with no overlay): the red check.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
. "$root/scripts/env.sh"
ROCW=$root/cloudflare-workers/.cache/nightlies/$ROC_TAG_WORKER/roc
d=$here/../red-tree; rm -rf "$d"; mkdir -p "$d/worker"
( cd "$root/worker" && tar cf - --exclude=app.wasm --exclude=.roc-cfw --exclude=.wrangler . ) | ( cd "$d/worker" && tar xf - )
sed -i 's#"\.\./\.\./\.\./packages/records/main.roc"#"../../../../../../packages/records/main.roc"#; s#"\.\./\.\./packages/records/main.roc"#"../../../../../packages/records/main.roc"#; s#"\.\./packages/records/main.roc"#"../../../../packages/records/main.roc"#' "$d/worker/lib/main.roc" "$d/worker/main.roc" "$d/worker/tests/unit/w0.roc"
hash=$(sed -n 's#.*roc-cloudflare-workers/releases/download/[^/]*/\([A-Za-z0-9]*\)\.tar\.zst.*#\1#p' "$d/worker/main.roc" | head -n 1)
( cd "$d/worker" && "$ROCW" build --target=wasm32 --no-cache --opt=speed --output=app.wasm main.roc || test -s app.wasm )
cp -r "$ROC_CACHE_DIR/packages/$hash/js" "$d/worker/.roc-cfw"
stage=$d/stage; mkdir -p "$stage/worker"; ln -s "$root/sql" "$stage/sql"; cp -r "$root/worker/tests" "$stage/worker/tests"
W2_DIR=$d/worker node "$stage/worker/tests/run.mjs" "$@"
