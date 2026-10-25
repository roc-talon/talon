#!/usr/bin/env bash
# Puts the stubs of slice 059 into the live tree (the state that the code agent gets): the stub XProject, and the files of before slice 059 for XFlow, RunFlow and RunSteps (the code agent wires and moves, slice file section 10).
set -e
R=$(cd "$(dirname "$0")" && pwd)
T=$(cd "$R/../.." && pwd)
cp "$R/stubs/cli/lib/XProject.roc" "$T/cli/lib/XProject.roc"
for f in XFlow RunFlow RunSteps; do cp "$R/before/cli/lib/$f.roc" "$T/cli/lib/$f.roc"; done
