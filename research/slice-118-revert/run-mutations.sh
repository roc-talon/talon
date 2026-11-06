#!/usr/bin/env bash
# Runs the mutations of slice 118 one after the other: W0 (WebhookTest) and W2 (webhook/). Logs: mut-<m>.log. Usage: run-mutations.sh m1 m2 ...
cd "$(dirname "$0")"
for m in "$@"; do
  MUTATE=mutations/$m.py ./ref.sh all webhook/ > mut-$m.log 2>&1
  echo "$m exit=$? $(grep -c '^FAIL' mut-$m.log) w2-fail-lines $(grep -E 'passed|failed' mut-$m.log | grep -E 'Ran |tests passed|^w2' | tr '\n' ' ')" >> mut-progress.txt
done
