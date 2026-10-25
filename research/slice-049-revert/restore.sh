#!/bin/sh
# Puts the stub state of slice 049 into cli/lib: the 5 new modules (XCache, XCmd, XCacheIo, XTake, XFlow) as stubs, ToolFlow, ToolBuild and CacheGc as they were before the slice (the code agent changes them),
# Run.roc with the dispatch of `x`, main.roc with the 5 new exposes. Run from the repo root.
set -e
for f in research/slice-049-revert/stubs/lib/*.roc; do cp "$f" "cli/lib/$(basename "$f")"; done
echo restored stubs
