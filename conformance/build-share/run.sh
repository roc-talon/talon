#!/bin/bash
# Q18: can 3 `roc build` runs share one compiler cache (compat-<id>/) at the same time?
# Usage: run.sh <roc binary> [iterations]   (default 100)
# Odd iterations start with an empty compiler cache (cold), even ones reuse it (warm).
W=$(cd "$(dirname "$0")" && pwd)
R=$(realpath "$1"); N=${2:-100}
APPS="command-line-args print url"
PF=CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA   # basic-cli 0.25.0
export XDG_CACHE_HOME=$W/xdg ROC_CACHE_DIR=$W/xdg/roc
rm -rf $W/xdg $W/out; mkdir -p $W/xdg/roc/packages $W/out/ref $W/run
cp -a ~/.cache/roc/packages/$PF $W/xdg/roc/packages/
wipe() { find $W/xdg/roc -mindepth 1 -maxdepth 1 ! -name packages -exec rm -rf {} +; }
# Run from a fixed path, so argv[0] in the output is the same for each build.
out() { cp $1 $W/run/$2; (cd /tmp && timeout 5 $W/run/$2 a b 2>&1; echo "rc=$?"); }
cd $W/apps
# References, one build at a time. A warm build gives a different binary than a cold build
# (same output), so each kind has its own reference.
for a in $APPS; do   # cold: each app alone on an empty cache
  wipe; $R build --output=$W/out/ref/cold-$a $a.roc >/dev/null 2>&1
  out $W/out/ref/cold-$a $a > $W/out/ref/$a.txt
done
wipe; for a in $APPS; do $R build --output=$W/out/ref/fill $a.roc >/dev/null 2>&1; done
for a in $APPS; do   # warm: each app alone on a cache that holds all 3 apps
  $R build --output=$W/out/ref/warm-$a $a.roc >/dev/null 2>&1
  out $W/out/ref/warm-$a $a | cmp -s - $W/out/ref/$a.txt || echo "warm reference output differs: $a" >&2
done
printf "iter\tcache\twall_s\tbuilt\tsame_output\tsame_binary\n"
for i in $(seq 1 $N); do
  [ $((i % 2)) -eq 1 ] && { c=cold; wipe; } || c=warm
  d=$W/out/$i; mkdir -p $d; t0=$(date +%s.%N)
  for a in $APPS; do $R build --output=$d/$a $a.roc > $d/$a.log 2>&1 & done; wait
  t=$(echo "$(date +%s.%N) - $t0" | bc)
  b=0; o=0; s=0
  for a in $APPS; do
    [ -f $d/$a ] || continue; b=$((b+1))
    out $d/$a $a | cmp -s - $W/out/ref/$a.txt && o=$((o+1))
    cmp -s $d/$a $W/out/ref/$c-$a && s=$((s+1))
  done
  printf "%s\t%s\t%.2f\t%s\t%s\t%s\n" $i $c $t $b $o $s
  [ $b -eq 3 ] && [ $o -eq 3 ] && [ $s -eq 3 ] && rm -rf $d   # keep only failed iterations
done
