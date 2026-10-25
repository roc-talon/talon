#!/usr/bin/env bash
# The l0 step alone, with chosen -P and --jobs. Same command as step_l0 of scripts/test.sh. Files in the order of $ORDER (default: the last-run times, slowest first).
# Usage: sweep.sh <P> <threads> [dir-with-unit-files-list]   Prints wall seconds. FILES=<list file> uses another file list (one path per line).
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/env.sh"
cd "$ROOT" || exit 1
P=$1; T=$2
LIST=${FILES:-$HERE/files-before.txt}
ORDER=${ORDER:-$HERE/l0-times-lastrun.txt}
out=$(mktemp -d)
s=$(date +%s.%N)
awk 'FILENAME == ARGV[1] { t[$2] = $1; next } { print (($0 in t) ? t[$0] : 999999999) " " $0 }' "$ORDER" "$LIST" | sort -rn -s -k1,1 | cut -d' ' -f2- | tr '\n' '\0' |
    xargs -0 -P "$P" -I{} bash -c 'n=${1//\//_}; "$ROC" test "$1" --no-cache --jobs="$3" > "$2/$n.log" 2>&1; echo $? > "$2/$n.rc"' _ {} "$out" "$T"
e=$(date +%s.%N)
fail=$(cat "$out"/*.rc | grep -vc '^0$')
printf 'P=%s T=%s files=%s fail=%s wall=%.2f\n' "$P" "$T" "$(wc -l < "$LIST")" "$fail" "$(awk -v a="$e" -v b="$s" 'BEGIN {print a-b}')"
rm -rf "$out"
