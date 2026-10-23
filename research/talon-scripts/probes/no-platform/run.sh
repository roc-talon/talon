#!/usr/bin/env bash
# What can an app with no platform (`app [main!] {}`) do? Expected on nightly-2026-10-21-5349569:
#   main.roc: runs, exit 0. echo.roc: error "Stdout.line! does not exist" (no I/O), dbg prints the args, then a
#   runtime error at that line, exit 1. bad.roc: Err(Exit(3)) gives exit 3.
# Usage: ROC=<roc> research/talon-scripts/probes/no-platform/run.sh
set -uo pipefail
cd "$(dirname "$0")"
: "${ROC:?set ROC}"
for f in main echo bad; do
  echo "== $f.roc"; "$ROC" "$f.roc" -- a b 2>&1 | tail -4; echo "exit ${PIPESTATUS[0]}"
done
