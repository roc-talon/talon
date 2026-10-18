#!/usr/bin/env bash
# Remote D1 run: make and delete the test database. The name starts with rocplat-test- and gets a row in ledger.md.
#   ./run.sh create   D1 rocplat-test-d1-remote, and .state/wrangler.toml with remote = true
#   ./run.sh delete   delete it (the delete gets its time in the ledger)
# Then: node ../d1-sweep/test.mjs remote (and ../bot-set, ../d1-contrib).
set -euo pipefail
cd "$(dirname "$0")"
L=$PWD/ledger.py; N=rocplat-test-d1-remote
d1id() { wrangler d1 info "$1" --json 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).uuid||"")}catch{console.log("")}})' || true; }
case "${1:-}" in
create)
  ID=$(d1id $N)
  if [ -z "$ID" ]; then wrangler d1 create $N >/dev/null; ID=$(d1id $N); $L add D1 $N "$ID"; fi
  mkdir -p .state
  cat > .state/wrangler.toml <<TOML
name = "rocplat-test-d1-remote"
compatibility_date = "2026-10-01"
[[d1_databases]]
binding = "DB"
database_name = "$N"
database_id = "$ID"
remote = true
TOML
  echo "$ID" ;;
delete)
  if [ -n "$(d1id $N)" ]; then wrangler d1 delete $N --skip-confirmation && $L del $N; fi
  rm -rf .state .wrangler ;;
*) sed -n 2,5p "$0"; exit 1 ;;
esac
