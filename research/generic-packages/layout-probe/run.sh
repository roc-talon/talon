#!/bin/bash
# Proves the generic-package layout on the pinned nightly (see ../LAYOUT.md).
# Usage: run.sh [ROC]. Needs the network once (roc-parser, roc-fuzz).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROC=${1:-$HERE/../../../cloudflare-workers/.cache/nightlies/nightly-2026-10-09-258ab27/roc}
ROC=$(cd "$(dirname "$ROC")" && pwd)/$(basename "$ROC")
W=$HERE/.work; rm -rf "$W"; mkdir -p "$W"
# No `..` in these paths: roc stops with PathOutsideWorkspace.
export XDG_CACHE_HOME=$W/xdg ROC_CACHE_DIR=$W/xdg/roc
RUNS=100000
step() { echo; echo "== $*"; }
rc() { echo "exit $1 (expected $2)"; [ "$1" = "$2" ] || FAIL=1; }
FAIL=0
cd "$HERE"
"$ROC" version

step "1. check the package (downloads roc-parser by release URL)"
"$ROC" check package/main.roc; rc $? 0
"$ROC" fmt --check package tests fuzz tools; rc $? 0
"$ROC" deps package/main.roc

step "2. L0 tests: test apps in tests/, the package in package/"
for f in tests/*.roc; do "$ROC" test "$f" --no-cache; rc $? 0; done

step "2. red: copy with Hex.decode = crash \"todo\", tests compile and fail"
mkdir -p "$W/stub"; cp -r package tests fuzz "$W/stub/"
sed -i 's/decode = |text| decode_impl(text) # BODY/decode = |_text| crash "todo"/' "$W/stub/package/Hex.roc"
"$ROC" check "$W/stub/package/main.roc"; rc $? 0
"$ROC" test "$W/stub/tests/hex.roc" --no-cache 2>&1 | tail -5; rc "${PIPESTATUS[0]}" 1

step "2. alternative: headerless test in package/tests/ with --main (reaches a hidden module)"
mkdir -p "$W/alt"; cp -r package "$W/alt/"; mkdir -p "$W/alt/package/tests" "$W/alt/dist"
printf 'import /Hex\nimport /Pair\nimport /Internal/Nibble as Nibble\n\nexpect Hex.encode([1]) == "01"\nexpect Nibble.to_ascii(10) == %s\nexpect Pair.parse("a=1").is_ok()\n' "'a'" >"$W/alt/package/tests/all.roc"
"$ROC" test "$W/alt/package/tests/all.roc" --main="$W/alt/package/main.roc" --no-cache; rc $? 0
"$ROC" test "$W/alt/package/tests/all.roc" --no-cache 2>&1 | tail -2; rc "${PIPESTATUS[0]}" 1
"$ROC" bundle "$W/alt/package/main.roc" --output-dir "$W/alt/dist" | grep Created

step "3. L1 fuzz: build and run each target, $RUNS inputs, seed 1"
mkdir -p "$W/fuzz"
for f in fuzz/*.roc; do
	n=$(basename "$f" .roc)
	"$ROC" build --fuzz "$f" --output="$W/fuzz/$n" >"$W/fuzz/$n.build.log" 2>&1; rc $? 0
	"$W/fuzz/$n" run --runs=$RUNS --seed=1 --time=0 --artifact-dir="$W/fuzz/art-$n" >"$W/fuzz/$n.log" 2>&1; rc $? 0
	grep -m1 '^Done' "$W/fuzz/$n.log"
done

step "3. red: the stub fails the fuzz target"
"$ROC" build --fuzz "$W/stub/fuzz/hex-roundtrip.roc" --output="$W/stub/hex" >/dev/null 2>&1; rc $? 0
"$W/stub/hex" run --runs=$RUNS --seed=1 --time=0 --artifact-dir="$W/stub/art" >"$W/stub/fuzz.log" 2>&1; rc $? 77
grep -m1 'roc crashed' "$W/stub/fuzz.log"

step "3. red: a planted bug ('e' decodes as 0) fails, replay fails again"
mkdir -p "$W/planted"; cp -r package fuzz "$W/planted/"
sed -i "s/Ok(c - 'a' + 10)/if c == 'e' Ok(0) else Ok(c - 'a' + 10)/" "$W/planted/package/Internal/Nibble.roc"
"$ROC" build --fuzz "$W/planted/fuzz/hex-roundtrip.roc" --output="$W/planted/hex" >/dev/null 2>&1; rc $? 0
"$W/planted/hex" run --runs=$RUNS --seed=1 --time=0 --artifact-dir="$W/planted/art" >"$W/planted/fuzz.log" 2>&1; rc $? 77
a=$(ls "$W"/planted/art/* | head -1); echo "saved input: $("$W/planted/hex" show "$a")"
"$W/planted/hex" replay "$a" >/dev/null 2>&1; rc $? 77

step "5. bundle: dist/<hash>.tar.zst, files, hash = base58(BLAKE3(file))"
mkdir -p "$W/dist"; "$ROC" bundle package/main.roc --output-dir "$W/dist"; rc $? 0
b=$(ls "$W"/dist/*.tar.zst); zstd -dc "$b" | tar -t
mkdir -p "$W/hash"; cp tools/bundle_hash.roc "$W/hash/"; cp "$b" "$W/hash/bundle.tar.zst"
h=$("$ROC" "$W/hash/bundle_hash.roc"); echo "file name: $(basename "$b" .tar.zst)"; echo "computed:  $h"
[ "$h" = "$(basename "$b" .tar.zst)" ] || { echo "hash differs"; FAIL=1; }

step "5. a path dependency is refused by roc bundle"
mkdir -p "$W/pd/rp" "$W/pd/dist"; cp -r package "$W/pd/"; cp "$W"/xdg/roc/packages/7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW/*.roc "$W/pd/rp/"
sed -i 's|parser: "https[^"]*"|parser: "../rp/main.roc"|' "$W/pd/package/main.roc"
"$ROC" bundle "$W/pd/package/main.roc" --output-dir "$W/pd/dist" 2>&1 | grep -o 'outside the entry point directory'

step "6. docs"
"$ROC" docs package/main.roc --output="$W/docs" >/dev/null; rc $? 0
(cd "$W/docs" && find . -name index.html | sort)

echo; [ $FAIL = 0 ] && echo "ALL AS EXPECTED" || { echo "SOME STEP DIFFERS"; exit 1; }
