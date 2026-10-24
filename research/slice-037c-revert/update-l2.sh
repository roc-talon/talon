#!/usr/bin/env bash
# Slice 037c: change the expected files of the old L2 case probe/pc2-range (TW21). Run with the private reference in the tree.
# The change is `UPDATE=1` of this one case, then check-diff.py reads the diff against research/slice-037c-revert/before/.
set -eu
cd "$(dirname "$0")/../.."
UPDATE=1 tests/commands/run.sh probe/pc2-range
python3 -I research/slice-037c-revert/check-diff.py
