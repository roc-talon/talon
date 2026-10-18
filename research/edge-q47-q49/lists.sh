#!/usr/bin/env bash
# Q47/Q49 edge run: the lists of the account (start and end state of ledger.md).
#   ./lists.sh > results/start-lists.txt
set -uo pipefail
cd "$(dirname "$0")"
date -u +%FT%TZ
echo "## Workers"; ./cfapi.sh GET /workers/scripts | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);console.log(j.success?j.result.map(w=>`${w.id} (modified ${w.modified_on}, placement ${JSON.stringify(w.placement_mode??w.placement??null)})`).join("\n")||"(none)":JSON.stringify(j.errors))})'
echo "## D1"; wrangler d1 list --json 2>&1
echo "## R2"; wrangler r2 bucket list 2>&1 | grep -E "^name:" || true
echo "## KV"; wrangler kv namespace list 2>&1 | grep -E '"title"' || echo "(none)"
echo "## Queues"; wrangler queues list 2>&1 | grep -E "│" || echo "(none)"
echo "## Durable Object namespaces"; ./cfapi.sh GET /workers/durable_objects/namespaces | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);console.log(j.success?j.result.map(n=>`${n.name} (${n.script}/${n.class})`).join("\n")||"(none)":JSON.stringify(j.errors))})'
