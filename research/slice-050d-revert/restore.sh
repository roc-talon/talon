#!/usr/bin/env bash
# restore.sh reference|before: put that state of the 3 code files of slice 050d (XTake, TalonUpdateFlow, TalonRemoveFlow) into the live tree (cli/lib). `before` is the state before slice 050d (there is no stub: the slice adds no signature, the 3 bodies change). The tests are no part of the states. Run from anywhere.
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
D=$ROOT/research/slice-050d-revert
case "${1:-}" in
reference) [ -d "$D/reference/cli/lib" ] || { echo "the reference was deleted" >&2; exit 1; }; cp "$D/reference/cli/lib/XTake.roc" "$D/reference/cli/lib/TalonUpdateFlow.roc" "$D/reference/cli/lib/TalonRemoveFlow.roc" "$ROOT/cli/lib/" ;;
before) cp "$D/before/cli/lib/XTake.roc" "$D/before/cli/lib/TalonUpdateFlow.roc" "$D/before/cli/lib/TalonRemoveFlow.roc" "$ROOT/cli/lib/" ;;
*) echo "usage: restore.sh reference|before" >&2; exit 2 ;;
esac
