#!/usr/bin/env bash
# restore.sh reference|stubs|before: put that state of the changed and new code files of slice 051 into the live tree (cli/lib and cli/RealFx.roc). `before` puts the files that existed before slice 051 back (the new modules stay: they are no part of the old state).
# The new test and fake files (tests/, cli/fxprobe.roc) are no part of the states. Run from anywhere.
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
D=$ROOT/research/slice-051-revert
case "${1:-}" in
reference | stubs) cp -a "$D/$1/cli/." "$ROOT/cli/" ;;
before)
  cp "$D"/before/cli/lib/*.roc "$ROOT/cli/lib/"
  cp "$D"/before/cli/RealFx.roc "$ROOT/cli/RealFx.roc"
  ;;
*) echo "usage: restore.sh reference|stubs|before" >&2; exit 2 ;;
esac
