#!/bin/sh
# Slice 229 (Design Q606): merge the compat stats of one bot run into stats/compat/ of a checkout of the branch `compat-stats`.
# Usage: scripts/compat-stats-merge.sh <artifact dir> <branch checkout dir>
# The artifact dir has <YYYY-MM>.csv and runs.csv of one run. A row is added once (probe row key: run id, nightly and hash, run row key: run id). A row with an empty run id has no key and is always added.
# Then stats/compat/README.md is written again: a mermaid chart of the last 60 runs.
set -eu

[ $# -eq 2 ] || { echo "usage: $0 <artifact dir> <branch checkout dir>" >&2; exit 2; }
in=$1
out=$2/stats/compat
mkdir -p "$out"

# merge <file> <key columns>: append the new rows of $in/<file> to $out/<file>, the header once.
merge() {
	[ -f "$in/$1" ] || return 0
	[ -f "$out/$1" ] || head -n 1 "$in/$1" > "$out/$1"
	awk -F, -v keys="$2" '
		function key(   n, i, k, cols) {
			n = split(keys, cols, " ")
			for (i = 1; i <= n; i++) k = k (i > 1 ? "," : "") $(cols[i])
			return $(cols[1]) == "" ? "" : k
		}
		FNR == 1 { next }
		NR == FNR { seen[key()] = 1; next }
		{ k = key(); if (k == "" || !(k in seen)) { print; seen[k] = 1 } }
	' "$out/$1" "$in/$1" > "$out/$1.new"
	# the awk output has only the new rows
	cat "$out/$1.new" >> "$out/$1"
	rm "$out/$1.new"
}

for f in "$in"/????-??.csv; do
	[ -f "$f" ] && merge "$(basename "$f")" "1 3 4"
done
merge runs.csv "1"

# The chart: run totals of the last 60 runs, from runs.csv (run,time,tags,probes,no_stats,wall_ms,cpu_ms,rss_kb).
{
	echo "# Compat bot stats"
	echo
	echo "The compat bot keeps the time and the resources of each probe. \`runs.csv\` has one row per run, \`<YYYY-MM>.csv\` has one row per probe (the columns are the first line of each file)."
	echo
	if [ -f "$out/runs.csv" ]; then
		awk -F, '
			NR == 1 { next }
			{ id[++n] = $1; wall[n] = $6; cpu[n] = $7 }
			END {
				from = n > 60 ? n - 60 + 1 : 1
				labels = ""; w = ""; c = ""
				for (i = from; i <= n; i++) {
					sep = i > from ? ", " : ""
					labels = labels sep "\"" id[i] "\""
					w = w sep wall[i]
					c = c sep cpu[i]
				}
				print "Run totals of the last " (n - from + 1) " runs (ms). The first line is wall time and the second line is CPU time (user plus system)."
				print ""
				print "```mermaid"
				print "xychart-beta"
				print "    title \"Compat bot run totals\""
				print "    x-axis \"run id\" [" labels "]"
				print "    y-axis \"ms\""
				print "    line [" w "]"
				print "    line [" c "]"
				print "```"
			}
		' "$out/runs.csv"
	fi
} > "$out/README.md"
