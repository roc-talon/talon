#!/bin/sh
# Puts the stub state of slice 048 into cli/lib: the 6 new modules as stubs, ToolsJson of before the slice with the stubs of `Tool`, `manifest`, `put` and `drop`, ToolBuild and ToolFlow as they were before (the code agent changes them),
# Run.roc with the dispatches of `tool list`, `remove`, `update` and `rebuild` (`tool install` stays `ToolFlow.run!`), main.roc with the 6 new exposes. Run from the repo root.
set -e
for f in research/slice-048-revert/stubs/lib/*.roc; do cp "$f" "cli/lib/$(basename "$f")"; done
echo restored stubs
