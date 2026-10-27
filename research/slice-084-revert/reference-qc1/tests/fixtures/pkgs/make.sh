#!/bin/bash
# Makes the fixture packages of slice 003 again, with the pinned `roc bundle` (research/generic-packages/LAYOUT.md 5).
# Usage: tests/fixtures/pkgs/make.sh
# Input:  src/<name>/ (a main.roc and the public modules)
# Output: <hash>.tar.zst for each package, and `hashes.txt` with the lines `<name> <hash>`.
# The hash is the base58 of the BLAKE3 of the archive. A bundle has mtime 0 and owner 0, so the same source gives the same
# hash on each run. If a hash changes (a new compiler), run this script and put the new hashes in the cases
# (`grep -rl <old hash> tests/`).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../../scripts/env.sh"
cd "$HERE"
rm -f ./*.tar.zst hashes.txt
for dir in src/*/; do
    name=$(basename "$dir")
    out=$(cd "$dir" && "$ROC" bundle main.roc ./*.roc --output-dir "$HERE" | sed -n 's/^Created: .*\/\(.*\)\.tar\.zst$/\1/p')
    echo "$name $out" >> hashes.txt
done
cat hashes.txt
