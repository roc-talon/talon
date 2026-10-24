#!/usr/bin/env bash
# Spike for slice 030: basic-cli Sqlite in WAL with 2 processes (R-CC8).
# Usage: research/compat-db/run.sh   (builds the spike with the pinned roc, then runs the cases)
set -u
. "$(dirname "$0")/../../scripts/env.sh"
OUT=${OUT:-$WORK/compat-db-spike}
export XDG_CACHE_HOME=$OUT/cache ROC_CACHE_DIR=$OUT/cache/roc
mkdir -p "$OUT/cache"
cd "$ROOT/research/compat-db" || exit 1
"$ROC" build --opt=dev spike.roc --output="$OUT/spike" > "$OUT/build.log" 2>&1 || { cat "$OUT/build.log"; exit 1; }
S=$OUT/spike
now() { date +%s.%N; }
fresh() { rm -f "$OUT"/t.db*; }

echo "== 1. single process"
fresh; "$S" single "$OUT/t.db"

echo "== 2. one writer alone: 3000 writes, no gap (speed of one write)"
fresh; s=$(now)
"$S" writer "$OUT/t.db" A 3000 5000 0
echo "elapsed $(echo "$(now) - $s" | bc) s"

echo "== 3. two writers at once on a NEW db (both create it), 300 writes each, gap 5 ms, busy_timeout 5000"
fresh; s=$(now)
"$S" writer "$OUT/t.db" A 300 5000 5 & p1=$!
"$S" writer "$OUT/t.db" B 300 5000 5 & p2=$!
wait $p1; wait $p2
echo "elapsed $(echo "$(now) - $s" | bc) s; $("$S" count "$OUT/t.db") (600 expected)"

echo "== 3b. same, busy_timeout 0 (no wait)"
fresh; s=$(now)
"$S" writer "$OUT/t.db" A 300 0 5 & p1=$!
"$S" writer "$OUT/t.db" B 300 0 5 & p2=$!
wait $p1; wait $p2
echo "elapsed $(echo "$(now) - $s" | bc) s; $("$S" count "$OUT/t.db") (600 expected)"

echo "== 3c. two writers at once, tight loop, 3000 writes each, busy_timeout 5000 (starvation test, not a Talon pattern)"
fresh; "$S" single "$OUT/t.db" > /dev/null; s=$(now)
"$S" writer "$OUT/t.db" A 3000 5000 0 & p1=$!
"$S" writer "$OUT/t.db" B 3000 5000 0 & p2=$!
wait $p1; wait $p2
echo "elapsed $(echo "$(now) - $s" | bc) s; $("$S" count "$OUT/t.db") (6002 expected)"

echo "== 4. holder keeps the write lock 2 s; second writer with busy_timeout 5000"
fresh; "$S" single "$OUT/t.db" > /dev/null
"$S" hold "$OUT/t.db" 2000 5000 & p1=$!
sleep 0.5; s=$(now)
"$S" busy "$OUT/t.db" 5000
echo "second writer waited $(echo "$(now) - $s" | bc) s"
wait $p1

echo "== 5. holder keeps the write lock 2 s; second writer with busy_timeout 500"
fresh; "$S" single "$OUT/t.db" > /dev/null
"$S" hold "$OUT/t.db" 2000 5000 & p1=$!
sleep 0.5; s=$(now)
"$S" busy "$OUT/t.db" 500
echo "second writer waited $(echo "$(now) - $s" | bc) s"
wait $p1

echo "== 6. errors: dir missing, not a database"
"$S" single "$OUT/nodir/t.db"; echo "exit=$?"
echo "this is not a database file at all, just text, padding padding padding padding padding padding padding padding" > "$OUT/bad.db"
"$S" single "$OUT/bad.db"; echo "exit=$?"
