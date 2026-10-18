#!/usr/bin/env bash
# Q47/Q49 edge run: deploy and delete the test resources. Each name starts with rocplat-test- and gets a row in ledger.md.
#   ./deploy.sh q47 [cron|sub20]  D1 rocplat-test-q47-d1, Worker rocplat-test-q47 (cron: a cron each minute;
#                                 sub20: limits.subrequests = 20)
#   ./deploy.sh q49               D1 rocplat-test-q49-d1, Workers rocplat-test-q49-default, -smart, -hint (placement.region
#                                 aws:eu-central-1), rocplat-test-q49-client
#   ./deploy.sh delete            delete all of them (each delete gets its time in the ledger)
set -euo pipefail
cd "$(dirname "$0")"
H=$PWD; L=$H/ledger.py; S=$H/.deploy
d1id() { wrangler d1 info "$1" --json 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).uuid||"")}catch{console.log("")}})' || true; }
mkd1() { local id; id=$(d1id "$1"); if [ -z "$id" ]; then wrangler d1 create "$1" ${2:+--location "$2"} >/dev/null; id=$(d1id "$1"); $L add D1 "$1" "$id"; fi; echo "$id"; }
dep() { # dep <name> <dir>: deploy, and a ledger row the first time
  local new=0; wrangler deployments list --name "$1" >/dev/null 2>&1 || new=1
  (cd "$2" && wrangler deploy)
  if [ $new = 1 ]; then $L add Worker "$1" "https://$1.bellup.workers.dev"; fi
}
case "${1:-}" in
q47)
  ID=$(mkd1 rocplat-test-q47-d1)
  mkdir -p "$S/q47"; cp q47/worker.js "$S/q47/"
  cat > "$S/q47/wrangler.toml" <<TOML
name = "rocplat-test-q47"
main = "worker.js"
compatibility_date = "2026-10-01"
compatibility_flags = ["global_fetch_strictly_public"]
workers_dev = true
$( [ "${2:-}" = cron ] && echo '[triggers]
crons = ["* * * * *"]' )
$( [ "${2:-}" = sub20 ] && echo '[limits]
subrequests = 20' )
[[d1_databases]]
binding = "DB"
database_name = "rocplat-test-q47-d1"
database_id = "$ID"
TOML
  dep rocplat-test-q47 "$S/q47" ;;
q49)
  ID=$(mkd1 rocplat-test-q49-d1)
  for m in default smart hint; do
    mkdir -p "$S/q49-$m"; cp q49/target.js "$S/q49-$m/worker.js"
    cat > "$S/q49-$m/wrangler.toml" <<TOML
name = "rocplat-test-q49-$m"
main = "worker.js"
compatibility_date = "2026-10-01"
workers_dev = true
$( [ $m = smart ] && echo '[placement]
mode = "smart"' )
$( [ $m = hint ] && echo '[placement]
region = "aws:eu-central-1"' )
[vars]
PLACEMENT = "$m"
[[d1_databases]]
binding = "DB"
database_name = "rocplat-test-q49-d1"
database_id = "$ID"
TOML
    dep rocplat-test-q49-$m "$S/q49-$m"
  done
  mkdir -p "$S/q49-client"; cp q49/client.js "$S/q49-client/worker.js"
  cat > "$S/q49-client/wrangler.toml" <<TOML
name = "rocplat-test-q49-client"
main = "worker.js"
compatibility_date = "2026-10-01"
compatibility_flags = ["global_fetch_strictly_public"]
workers_dev = true
[[durable_objects.bindings]]
name = "CLIENT"
class_name = "Client"
[[migrations]]
tag = "v1"
new_sqlite_classes = ["Client"]
TOML
  dep rocplat-test-q49-client "$S/q49-client" ;;
delete)
  for w in rocplat-test-q47 rocplat-test-q49-default rocplat-test-q49-smart rocplat-test-q49-hint rocplat-test-q49-client; do
    if wrangler deployments list --name $w >/dev/null 2>&1; then wrangler delete --name $w --force && $L del $w; fi
  done
  for d in rocplat-test-q47-d1 rocplat-test-q49-d1; do
    if [ -n "$(d1id $d)" ]; then wrangler d1 delete $d --skip-confirmation && $L del $d; fi
  done ;;
*) sed -n 2,6p "$0"; exit 1 ;;
esac
