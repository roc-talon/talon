#!/usr/bin/env bash
# Runs the mutations of this dir one after the other (one heavy job at a time, CLAUDE.md), each filtered to the cases it affects. Usage: run-mutations.sh m1 m2 ...
# Each line of the table says: the mutation, the stage (w0 or w2), the filter. A mutation passes the revert check when the stage FAILS.
HERE=$(cd "$(dirname "$0")" && pwd)
declare -A STAGE=([m1]=w0 [m2]=w2 [m3]=w2 [m4]=w2 [m5]=w2 [m6]=w2 [m7]=w2 [m8]=w2 [m9]=w2 [m10]=w2 [m11]=w2)
declare -A FILTER=([m1]="" [m2]="move/ap31-checks" [m3]="move/ap31-checks" [m4]="move/tp15-refusals move/tp15-offer" [m5]="move/tp15-offer" [m6]="move/ap31-put-delete" [m7]="move/ap31-put-delete" [m8]="move/ap31-put-delete move/tp15-offer" [m9]="move/tp15-operator" [m10]="move/tp15-refusals" [m11]="move/ap31-put-delete")
for m in "$@"; do
  echo "== $m (${STAGE[$m]}) ${FILTER[$m]}"
  MUTATE=mutations/$m.py timeout 900 "$HERE/ref.sh" "${STAGE[$m]}" ${FILTER[$m]} > "$HERE/mut-$m.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then echo "$m: CAUGHT (exit $rc)"; else echo "$m: SURVIVED"; fi
  grep -E "^(FAIL|w2:|All|[0-9]+ (passed|failed))|failed" "$HERE/mut-$m.log" | head -6
done
