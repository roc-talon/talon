#!/usr/bin/env bash
# TW12 on the real code of 119c: each mutant of real119c/ on a build copy (NOREF=1), W0 and W2 reconcile/ and webhook/. Two at a time. Logs: real119c-<m>.log.
cd "$(dirname "$0")"
run() { MUTATE=real119c/$1.py NOREF=1 ./ref.sh all reconcile/ webhook/ > real119c-$1.log 2>&1; rm -rf refbuild-$1; }
set -- ${@:-$(ls real119c | grep '^d.*\.py$' | sed 's/\.py$//')}
while [ $# -gt 0 ]; do run $1 & if [ $# -gt 1 ]; then run $2 & shift; fi; shift; wait; done
