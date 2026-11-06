#!/usr/bin/env bash
# Slice 222 (G-C156 to G-C159): what `roc bump` does. Writes results.txt. Usage: research/roc-bump/run.sh [ROC]
# It builds the fixtures in a temp dir, so nothing is left in the repo but results.txt.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$ROOT/scripts/env.sh"
ROC=${1:-$ROC}
T=$(mktemp -d); cd "$T"
w() { mkdir -p "$1"; printf 'package [Greet] {}\n' > "$1/main.roc"; printf '%s\n' "$2" > "$1/Greet.roc"; }
w v1 'Greet :: [].{
	hello : Str -> Str
	hello = |name| "hello ${name}"
}'
w v2patch 'Greet :: [].{
	hello : Str -> Str
	hello = |name| "hello, ${name}"
}'
w v2minor 'Greet :: [].{
	hello : Str -> Str
	hello = |name| "hello ${name}"

	bye : Str -> Str
	bye = |name| "bye ${name}"
}'
w v2major 'Greet :: [].{
	hello : Str, Str -> Str
	hello = |name, other| "hello ${name} ${other}"
}'
w bad 'Greet :: [].{
	hello : Str -> Str
	hello = |name| nope(name)
}'
mkdir -p site/dl/1.0.0; (cd v1 && "$ROC" bundle main.roc Greet.roc --output-dir ../site/dl/1.0.0 >/dev/null 2>&1)
BUNDLE=$(ls site/dl/1.0.0)
(cd site && exec python3 -m http.server 8765 --bind 127.0.0.1 >/dev/null 2>&1) & SRV=$!
sleep 1
OUT=$HERE/results.txt
{ echo "compiler: $("$ROC" version 2>&1 | head -1)"; echo; } > "$OUT"
run() {
  echo "### roc $*" >> "$OUT"
  s=$(date +%s%N); "$ROC" "$@" >o.txt 2>e.txt; e=$?; ms=$(( ($(date +%s%N) - s) / 1000000 ))
  { echo "exit $e, $ms ms"; echo "--- stdout"; cat o.txt; echo "--- stderr"; cat e.txt; echo; } >> "$OUT"
}
run bump --old v1 --old-version 1.0.0 --expect 1.0.1 v2patch/main.roc
run bump --old v1 --old-version 1.0.0 --expect 1.1.0 v2minor/main.roc
run bump --old v1 --old-version 1.0.0 --expect 1.0.1 v2minor/main.roc
run bump --old v1 --old-version 1.0.0 --expect 1.9.0 v2major/main.roc
run bump --old v1 --old-version 1.0.0 --expect 3.0.0 v2major/main.roc
run bump --old v1 --old-version 1.0.0 --expect 1.0.0 v2patch/main.roc
run bump --old v1 --old-version 1.0.0 --expect 1.0.1 bad/main.roc
run bump --old bad --old-version 1.0.0 --expect 1.0.1 v2patch/main.roc
run bump --old v1 --expect 1.0.1 v2patch/main.roc
run bump --old v1 --old-version 1.0.0-rc.1 --expect 1.0.1 v2patch/main.roc
run bump --old v1 --old-version 1.0.0 --expect 1.0.1-rc.1 v2patch/main.roc
run bump --old v1 --old-version 1.0.0 --expect 1.0.1 nonexist/main.roc
run bump --old "http://127.0.0.1:8765/dl/1.0.0/$BUNDLE" --expect 1.1.0 v2minor/main.roc
run bump --old "http://127.0.0.1:8765/dl/1.0.0/$BUNDLE" --expect 1.0.1 v2minor/main.roc
run bump --old http://127.0.0.1:8765/dl/1.0.0/missing.tar.zst --expect 1.0.1 v2minor/main.roc
run bump --old http://127.0.0.1:9/dl/1.0.0/x.tar.zst --expect 1.0.1 v2minor/main.roc
run bump --expect 1.0.1 v2patch/main.roc
(cd v2minor && run bump --old ../v1 --old-version 1.0.0 --expect 1.0.1)
kill $SRV 2>/dev/null; cd /; rm -rf "$T"
echo "wrote $OUT"
