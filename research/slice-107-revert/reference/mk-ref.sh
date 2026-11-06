#!/usr/bin/env bash
# Builds the private reference tree research/slice-107-revert/reference/worker/ : a copy of worker/ with the overlay files on top.
# W0:  $ROCW test research/slice-107-revert/reference/worker/tests/unit/w0.roc
# W2:  see run-ref.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
rm -rf "$here/worker"
mkdir -p "$here/worker"
( cd "$root/worker" && tar cf - --exclude=app.wasm --exclude=.roc-cfw --exclude=.wrangler . ) | ( cd "$here/worker" && tar xf - )
cp -r "$here/overlay/." "$here/worker/"
# the relative path of records: the tree is 3 dirs deeper
sed -i 's#"\.\./\.\./packages/records/main.roc"#"../../../../../packages/records/main.roc"#; s#"\.\./packages/records/main.roc"#"../../../../packages/records/main.roc"#; s#"\.\./\.\./\.\./packages/records/main.roc"#"../../../../../../packages/records/main.roc"#' "$here/worker/lib/main.roc" "$here/worker/main.roc" "$here/worker/tests/unit/w0.roc"
if [ "${DEBUG:-0}" = 1 ]; then
  sed -i 's#Err(Fault(text)) => Err(Fault(text))#Err(Fault(text)) => Ok(problem_response(Problem.new(Internal, text)))#' "$here/worker/main.roc"
fi
# Other slices that are in progress can break the copy: the reference tests only this slice.
sed -i '/^import [A-Za-z]*Test/{/ShortsTest/!d}' "$here/worker/tests/unit/w0.roc"
