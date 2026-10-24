#!/bin/sh
# Copies a file to research/slice-025b-revert/before/<same path> once, before the test agent changes it (the slice boundary of BRIEF-tests.md).
# Usage: research/slice-025b-revert/bk.sh <path relative to the repo root> ...
cd "$(dirname "$0")/../.." || exit 1
for f in "$@"; do
    if [ -e "research/slice-025b-revert/before/$f" ]; then continue; fi
    mkdir -p "research/slice-025b-revert/before/$(dirname "$f")"
    cp -a "$f" "research/slice-025b-revert/before/$f"
done
