#!/usr/bin/env bash
# Q49: traffic for Smart Placement. Every 30 s, for ITER times: /chain3 of the smart Worker, N times (default 3) from each region.
cd "$(dirname "$0")/.."
for i in $(seq 1 "${ITER:-50}"); do
  PHASE=warm WORKERS=smart ROUTES=chain3 N=${N:-3} node q49/run.mjs >> results/q49-warm.jsonl 2>>results/q49-warm.err
  echo "$(date -u +%T) iter $i placement: $(tail -12 results/q49-warm.jsonl | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log([...new Set(s.trim().split("\n").map(l=>{const j=JSON.parse(l);return j.region+":"+j.placement}))].join(" ")))')"
  sleep 30
done
