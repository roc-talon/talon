#!/usr/bin/env bash
# TW12 on the real code of 119b: each mutant of real/ on a build copy (NOREF=1), W0 and W2 reconcile/ and webhook/pu17. Two at a time. Logs: real-<m>.log.
cd "$(dirname "$0")"
run() { MUTATE=real/$1.py NOREF=1 ./ref.sh all reconcile/ webhook/pu17 webhook/pu13-index-new > real-$1.log 2>&1; rm -rf refbuild-$1; }
set -- $(ls real | grep '^r.*\.py$' | sed 's/\.py$//')
while [ $# -gt 0 ]; do run $1 & if [ $# -gt 1 ]; then run $2 & shift; fi; shift; wait; done
