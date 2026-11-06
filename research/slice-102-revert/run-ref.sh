#!/usr/bin/env bash
# Runs the W1 cases of sql/tests/ against the private reference schema (reference/0001_init.sql) or another file.
#   research/slice-102-revert/run-ref.sh [sql-file] [filter ...]
# It copies the runner to ws/ (the runner reads the migration from the dir above its own dir), links the cases, and runs it.
# The real sql/0001_init.sql is not touched. ws/ is rebuilt at each run.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
sqlfile="${1:-$here/reference/0001_init.sql}"
shift || true
rm -rf "$here/ws"
mkdir -p "$here/ws/sql/tests"
cp "$root/sql/tests/run.mjs" "$root/sql/tests/split.mjs" "$here/ws/sql/tests/"
ln -s "$root/sql/tests/cases" "$here/ws/sql/tests/cases"
ln -s "$root/sql/tests/selftest" "$here/ws/sql/tests/selftest"
cp "$sqlfile" "$here/ws/sql/0001_init.sql"
cd "$root"
node "$here/ws/sql/tests/run.mjs" "$@"
