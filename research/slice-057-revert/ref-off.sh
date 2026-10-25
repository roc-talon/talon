#!/usr/bin/env bash
# Puts the stubs of slice 057 into the live tree (the state that the code agent gets): the stub modules, Project.roc with the stub scan!, RealFx.roc with the stub exec_in!, and Intent.roc as before slice 057.
set -e
R=$(cd "$(dirname "$0")" && pwd)
T=$(cd "$R/../.." && pwd)
cp "$R"/stubs/cli/lib/*.roc "$T/cli/lib/"
cp "$R/stubs/cli/RealFx.roc" "$T/cli/RealFx.roc"
cp "$R/before/cli/lib/Intent.roc" "$T/cli/lib/Intent.roc"
