#!/usr/bin/env bash
# Run a command and sample the memory every 0.2 s. Prints the peak of the command tree (sum of RSS of the command and all its
# children) and the peak fall of MemAvailable. A guard kills the tree when MemAvailable is under GUARD_GB (default 20).
# Usage: research/test-memory/sample.sh <log.csv> <command...>
set -u
LOG=$1
shift
GUARD_KB=$(( ${GUARD_GB:-20} * 1024 * 1024 ))
avail() { awk '/MemAvailable/ {print $2}' /proc/meminfo; }
tree_kb() { ps -eo pid=,ppid=,rss= | awk -v root="$1" '{ppid[$1]=$2; rss[$1]=$3} END {for (p in rss) {q=p; while (q != "" && q != 0) {if (q == root) {s+=rss[p]; break}; q=ppid[q]}} print s+0}'; }
START=$(avail)
setsid "$@" &
PID=$!
echo "t,tree_kb,avail_kb" > "$LOG"
T0=$(date +%s.%N)
peak_tree=0
min_avail=$START
killed=no
while kill -0 "$PID" 2> /dev/null; do
    t=$(tree_kb "$PID")
    a=$(avail)
    echo "$(awk -v a="$(date +%s.%N)" -v b="$T0" 'BEGIN {printf "%.1f", a-b}'),$t,$a" >> "$LOG"
    [ "$t" -gt "$peak_tree" ] && peak_tree=$t
    [ "$a" -lt "$min_avail" ] && min_avail=$a
    if [ "$a" -lt "$GUARD_KB" ]; then
        killed=yes
        kill -KILL -- "-$PID" 2> /dev/null
        break
    fi
    sleep 0.2
done
wait "$PID" 2> /dev/null
rc=$?
awk -v t="$peak_tree" -v s="$START" -v m="$min_avail" -v rc=$rc -v k=$killed 'BEGIN {printf "exit=%s guard_killed=%s peak_tree=%.1f GB fall_of_MemAvailable=%.1f GB\n", rc, k, t/1048576, (s-m)/1048576}'
