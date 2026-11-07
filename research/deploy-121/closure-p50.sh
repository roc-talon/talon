#!/usr/bin/env bash
# Slice 121 (Design 7 P2 exit): time N closure queries on the edge and print p50, p90, max (curl time_total, seconds), and the server-side time is not split out.
# ./closure-p50.sh <base url> <n>
B=${1:-https://registry.roc-talon.org}; N=${2:-40}
body='{"groups":[{"group":"github.com/Karakatiza666/roc-semver/releases/download/{v}/"}],"hashes":[]}'
curl -s -o /dev/null -X POST -H 'content-type: application/json' -H 'user-agent: tln/0.0.0' -d "$body" "$B/v1/closure"
for i in $(seq "$N"); do curl -s -o /dev/null -w '%{http_code} %{time_starttransfer} %{time_connect}\n' -X POST -H 'content-type: application/json' -H 'user-agent: tln/0.0.0' -d "$body" "$B/v1/closure"; done |
  awk '{print $1, ($2 - $3) * 1000}' | sort -k2,2n | awk '{c[$1]++; t[NR]=$2} END {printf "n %d  ttfb minus connect: p50 %.0f ms  p90 %.0f ms  max %.0f ms\n", NR, t[int(NR*0.5)], t[int(NR*0.9)], t[NR]; for (k in c) print "  status " k ": " c[k]}'
