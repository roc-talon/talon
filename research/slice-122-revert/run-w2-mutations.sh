#!/usr/bin/env bash
# Private: the W2 runs of the mutations M3 to M7 (one build each). Output: mut-<name>.log and mut-w2-summary.txt
HERE=$(cd "$(dirname "$0")" && pwd)
: > "$HERE/mut-w2-summary.txt"
run() { n=$1; shift; MUTATE=mutations/$n.py "$HERE/ref.sh" w2 "$@" > "$HERE/mut-$n.log" 2>&1; echo "$n: $(grep -E '^w2:' "$HERE/mut-$n.log" | tail -1) FAILED: $(grep -E '^FAIL' "$HERE/mut-$n.log" | sed 's/ (.*//; s/FAIL //' | tr '\n' ' ')" >> "$HERE/mut-w2-summary.txt"; rm -rf "$HERE/refbuild-$n"; }
run m3-join-duplicates reads/ closure/
run m5-only-strongest reads/ closure/
run m6-ingest-no-member ingest/ ingest-limits/ publish/
run m7-stale-answer ingest/ ingest-limits/ publish/
run m4-closure-no-member closure/
