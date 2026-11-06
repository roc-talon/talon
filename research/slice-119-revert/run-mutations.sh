#!/usr/bin/env bash
# Runs each mutant of mutations/ on a copy of the reference (W0 ReconcileTest and WebhookTest, W2 reconcile/ and webhook/pu17, pu13-index-new). Two at a time. Logs: mut-<m>.log.
cd "$(dirname "$0")"
run() { m=$1; MUTATE=mutations/$m.py ./ref.sh all reconcile/ webhook/pu13-index-new webhook/pu17 > mut-$m.log 2>&1; rm -rf refbuild-$m; echo "$m done"; }
ms=$(ls mutations | grep '^m.*\.py$' | sed 's/\.py$//')
set -- $ms
while [ $# -gt 0 ]; do run $1 & if [ $# -gt 1 ]; then run $2 & fi; wait; shift; shift 2>/dev/null || true; done
