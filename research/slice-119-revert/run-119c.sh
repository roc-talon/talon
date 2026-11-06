#!/usr/bin/env bash
# TW12 on the private reference of 119c: each mutant of m119c/ on a build copy of reference-119c, W0 and W2 reconcile/ and webhook/. Two at a time. Logs: m119c-<m>.log.
cd "$(dirname "$0")"
run() { REFDIR=reference-119c MUTATE=m119c/$1.py ./ref.sh all reconcile/ webhook/ > m119c-$1.log 2>&1; rm -rf refbuild-reference-119c-$1; }
set -- ${@:-$(ls m119c | grep '^c.*\.py$' | sed 's/\.py$//')}
while [ $# -gt 0 ]; do run $1 & if [ $# -gt 1 ]; then run $2 & shift; fi; shift; wait; done
