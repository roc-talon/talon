#!/bin/bash
# Slice 112a revert check (code agent). Usage: mutate.sh <file> <old> <new> <w0|w2 filter>. Puts the file back after the run.
set -u
cd "$(dirname "$0")/../.."
f=$1; old=$2; new=$3; what=$4
cp "$f" "$f.keep"
python3 -c "import sys;p,o,n=sys.argv[1:4];s=open(p).read();assert s.count(o)==1,o;open(p,'w').write(s.replace(o,n))" "$f" "$old" "$new" || { rm "$f.keep"; exit 2; }
R=$PWD/cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc
if [ "$what" = w0 ]; then
  $R test worker/tests/unit/w0.roc --no-cache 2>&1 | grep -E "fail .*(Ingest|Reads|Route)Test|passed|failed"
else
  scripts/test.sh wbuild > /dev/null 2>&1; d=$(ls -t .work/logs/worker-dir.* | head -1)
  W2_DIR=$(cat "$d") node worker/tests/run.mjs $what 2>&1 | grep -E "^(PASS|FAIL)|w2:"
fi
mv "$f.keep" "$f"
