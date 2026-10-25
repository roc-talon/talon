#!/bin/sh
# Puts the stubs of slice 046 back into cli/lib (copies over; the new modules stay as stubs). Run from the repo root.
set -e
for f in research/slice-046-revert/stubs/lib/*.roc; do cp "$f" "cli/lib/$(basename "$f")"; done
echo restored stubs
