#!/bin/sh
# Puts the stub state of slice 056 into cli/lib: the 6 new modules as stubs, Intent with the field `tools` (value `[]`), InstallFlow, Resolve, Install, Update, XTake, Gc, CacheGc and XCacheIo as they were before the slice (the code agent changes them),
# Run.roc with the dispatch of `--tool`, main.roc with the 6 new exposes, Args.roc with `--tool`. Run from the repo root.
set -e
for f in research/slice-056-revert/stubs/lib/*.roc; do cp "$f" "cli/lib/$(basename "$f")"; done
echo restored stubs
