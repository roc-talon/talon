#!/bin/bash
# Builds fuzz/t.roc of each variant two times from a fresh compile cache, and
# replays the empty input on each binary. Facts on nightly-2026-10-14-38a3029:
#   leak-lazy-cycle     two top-level parsers that refer to each other through
#                       `Parser.lazy` and a lambda: build1 clean, build2 (from
#                       the cache) "[roc-fuzz leak] 9 allocation(s) ... never freed"
#   leak-step-function  the same recursion through a named top-level step
#                       function, no `Parser.lazy`: build1 and build2 clean
# A `--no-cache` build of the leaking form is clean, and its binary differs
# from the cached build. Copies the package cache of roc-toml (SRC) so that
# nothing downloads.
# Usage: SRC=<roc-toml>/.work/xdg/roc/packages twice.sh ROC VARIANT...
ROC=$1; shift
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to the roc package cache of roc-toml}
for v in "$@"; do
	(
		C=$HERE/.work/cache-$v
		rm -rf "$C"; mkdir -p "$C/roc"; cp -r "$SRC" "$C/roc/"
		export XDG_CACHE_HOME=$C ROC_CACHE_DIR=$C/roc
		printf '' > "$HERE/.work/empty-$v"
		out=""
		for i in 1 2; do
			cd "$HERE/$v" && "$ROC" build --fuzz fuzz/t.roc --output="$HERE/.work/$v-$i" > "$HERE/.work/$v-$i.log" 2>&1
			r=$("$HERE/.work/$v-$i" replay "$HERE/.work/empty-$v" 2>&1 | grep -oE 'leak\] [0-9]+|Executed' | head -1)
			out="$out build$i=${r:-FAIL}"
		done
		echo "$v:$out"
	) &
done
wait
