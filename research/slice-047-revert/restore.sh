#!/bin/sh
# Puts the stub state of slice 047 into cli/lib: the 3 new modules as stubs, ToolInstall with the type edits only, ToolFlow as it was in slice 046, main.roc with the 3 new exposes. Run from the repo root.
set -e
for f in research/slice-047-revert/stubs/lib/*.roc; do cp "$f" "cli/lib/$(basename "$f")"; done
echo restored stubs
