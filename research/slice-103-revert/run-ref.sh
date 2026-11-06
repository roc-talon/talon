#!/usr/bin/env bash
# Runs the W1 cases of sql/tests/ (the real runner) against a migration file.
#   research/slice-103-revert/run-ref.sh [0002-file] [filter ...]      default file: reference/0002_triggers.sql
#   CASES=<dir> ...  use another cases dir (mutate.sh uses it for a mutated case)
# It copies the runner and the real sql/0001_init.sql to ws/, links the cases, and runs it. ws/ is rebuilt at each run.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
f="${1:-$here/reference/0002_triggers.sql}"
shift || true
rm -rf "$here/ws"
mkdir -p "$here/ws/sql/tests"
cp "$root/sql/tests/run.mjs" "$here/ws/sql/tests/run.mjs"
cp "$root/sql/tests/split.mjs" "$here/ws/sql/tests/"
ln -s "${CASES:-$root/sql/tests/cases}" "$here/ws/sql/tests/cases"
ln -s "$root/sql/tests/selftest" "$here/ws/sql/tests/selftest"
cp "$root/sql/0001_init.sql" "$here/ws/sql/0001_init.sql"
cp "$f" "$here/ws/sql/0002_triggers.sql"
cd "$root"
node "$here/ws/sql/tests/run.mjs" "$@"
