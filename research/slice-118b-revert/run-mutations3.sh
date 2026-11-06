#!/usr/bin/env bash
# Runs the mutations of slice 118b one after the other: W0 (WebhookTest) and W2 (webhook/). Logs: mut-<m>.log. Usage: run-mutations.sh n1 n2 ...
cd "$(dirname "$0")"
for m in "$@"; do
  MUTATE=mutations/$m.py ./ref3.sh all webhook/ > mut3-$m.log 2>&1
  echo "$m exit=$? $(grep -c '^FAIL' mut3-$m.log) w2-fail-lines $(grep -E 'passed|failed' mut3-$m.log | grep -E 'Ran |tests passed|^w2' | tr '\n' ' ')" >> mut-progress3.txt
done
