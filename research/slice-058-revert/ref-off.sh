#!/usr/bin/env bash
# Puts the stubs of slice 058 into the live tree (the state that the code agent gets): the stub modules and the changed wiring files. RunSteps.roc is a reference file only: it is removed.
set -e
R=$(cd "$(dirname "$0")" && pwd)
T=$(cd "$R/../.." && pwd)
cp "$R"/stubs/cli/lib/*.roc "$T/cli/lib/"
cp "$R/before/cli/lib/Intent.roc" "$T/cli/lib/Intent.roc"
rm -f "$T/cli/lib/RunSteps.roc"
