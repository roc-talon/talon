#!/usr/bin/env bash
# restore.sh reference|stubs|before: put that state of the new and changed code files of slice 050c into the live tree (cli/lib). `before` puts the files that existed before slice 050c back (ToolBuild, ToolManageFlow) and removes nothing else.
# The wiring files (Fx, RealFx, Run, main, fxprobe) and the test files (tests/) are no part of the states: they are the same in the reference and in the stubs. Run from anywhere.
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
D=$ROOT/research/slice-050c-revert
case "${1:-}" in
reference) echo "the reference was deleted at the review" >&2; exit 1 ;;
stubs)
  cp -a "$D/stubs/cli/." "$ROOT/cli/"
  cp "$D/before/cli/lib/ToolBuild.roc" "$D/before/cli/lib/ToolManageFlow.roc" "$ROOT/cli/lib/"
  ;;
before) cp "$D/before/cli/lib/ToolBuild.roc" "$D/before/cli/lib/ToolManageFlow.roc" "$ROOT/cli/lib/" ;;
*) echo "usage: restore.sh reference|stubs|before" >&2; exit 2 ;;
esac
