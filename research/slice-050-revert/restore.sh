#!/usr/bin/env bash
# restore.sh stubs|before: put the stub state, the state before slice 050 (changed files only, the new files stay), into the live tree (the reference was deleted at the review, so mkstubs.py and mut.py no longer run). Run from anywhere.
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
D=$ROOT/research/slice-050-revert
case "${1:-}" in
stubs)
  cp "$D"/before/cli/lib/*.roc "$ROOT/cli/lib/"
  cp "$D"/stubs/cli/lib/*.roc "$ROOT/cli/lib/"
  ;;
before)
  cp "$D"/before/cli/lib/*.roc "$ROOT/cli/lib/"
  ;;
*) echo "usage: restore.sh stubs|before" >&2; exit 2 ;;
esac
