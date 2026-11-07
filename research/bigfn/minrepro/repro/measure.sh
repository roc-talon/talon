#!/usr/bin/env bash
# Usage: measure.sh [M]. For N = 2, 4, 6, 8 and the opt modes dev and speed: build or/ and wild/ (native),
# print the size of the function that has the match (main!) and the copies of the arm body in it.
here=$(cd "$(dirname "$0")" && pwd); top=$(cd "$here/.." && pwd)
ROC=${ROC:-/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-31-f7bef6b/roc}
M=${1:-20}
echo "| N | --opt | or: main! bytes | or: copies | wild: main! bytes | wild: copies |"
echo "| --- | --- | --- | --- | --- | --- |"
for n in 2 4 6 8; do
	python3 "$here/gen.py" $n $M
	for opt in dev speed; do
		row="| $n | $opt"
		for f in or wild; do
			b=$top/out/repro-$f-$n-$opt.bin
			(cd "$here/$f" && $ROC build --opt=$opt --no-cache --output="$b" main.roc > "$b.log" 2>&1)
			r=$("$top/countnat.py" "$b" "line 07" | grep "as immediates" | head -1)
			row="$row | $(echo "$r" | sed -E 's/.* ([0-9]+) bytes: ([0-9]+) copies.*/\1 | \2/')"
		done
		echo "$row |"
	done
done
