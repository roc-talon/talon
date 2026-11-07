#!/usr/bin/env bash
# Usage: hpair.sh DIR TEXT [opt]. As pair.sh, for a headerless DIR/main.roc. `roc build --target=wasm32` gives an
# archive for a headerless app; the script links it with `zig wasm-ld` (ZIG, any zig 0.16) and counts with count.mjs.
set -e
here=$(cd "$(dirname "$0")" && pwd)
ROC=${ROC:-/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc}
ZIG=${ZIG:?set ZIG to a zig 0.16 binary (zig wasm-ld)}
d=$(cd "$1" && pwd); text=$2; opt=${3:-speed}; n=$(basename "$d")
[ -n "$NOGEN" ] || NOBUILD=1 "$here/pair.sh" "$d" "$text"
for f in or arms one; do (
	o=$here/out/$n-$f-$opt; rm -rf "$o.d"; mkdir -p "$o.d"
	(cd "$d/$f" && $ROC build --target=wasm32 --opt=$opt --no-cache --output="$o.a" main.roc > "$o.log" 2>&1) || true
	(cd "$o.d" && ar x "$o.a")
	$ZIG wasm-ld --no-entry --export-dynamic --allow-undefined --gc-sections -o "$o.wasm" "$o.d"/*.o
	echo "$n $f: $(node "$here/count.mjs" "$o.wasm" "$text")" ) & done; wait
