#!/bin/bash
# Probe: run the W2 runner alone on the newest wbuild stamp with a given JOBS. Usage: run-w2.sh <JOBS> <label>
# Heavy job: call it through flock + systemd-run (see RESULT.md).
cd /home/george/dev/Karakatiza666/talon || exit 1
export TMPDIR=$PWD/.tmp/tmp
S=$(ls -t .work/worker | head -1)
export W2_DIR=$PWD/.work/worker/$S W2_ARCHIVE_WASM=$PWD/.work/worker-archive/$S/archive-test.wasm JOBS=$1
s=$(date +%s.%N)
timeout 300 node $NODEFLAGS worker/tests/run.mjs > research/slice-256-w2-speed/out-$2.log 2>&1
e=$(date +%s.%N)
echo "$2 JOBS=$1 wall=$(awk -v a=$e -v b=$s 'BEGIN{printf "%.1f",a-b}') load=$(cut -d' ' -f1 /proc/loadavg) $(grep 'w2 pool' research/slice-256-w2-speed/out-$2.log | cut -c1-200) $(tail -1 research/slice-256-w2-speed/out-$2.log)"
