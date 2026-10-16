#!/bin/bash
# Generates the smoke app of each platform of conformance/host-link and builds it for each target that the platform ships.
# Compare with conformance/host-link/results.tsv, which built a real app of each platform.
set -u
W=$(cd "$(dirname "$0")" && pwd)
H=$(cd "$W/../../conformance/host-link" && pwd)   # canonical: roc fails on a cache path with ".." (Design Q15)
export XDG_CACHE_HOME=$H/xdg ROC_CACHE_DIR=$H/xdg/roc
mkdir -p $W/apps $W/out
printf "platform\ttarget\tsmoke\thost-link\n"
grep -v '^\s*$' <<'LIST' | while read app tag hash; do
basic-cli-0.29.0 nightly-2026-10-12-2664a27 GrSTLEKd6yw8orQ5ByQQVY3Htg59vZYaoHBvQELueiMB
basic-cli-0.25.0 nightly-2026-10-12-2664a27 CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA
template-zig-1.0.0 nightly-2026-10-12-2664a27 AnZoxzoGPtSGQ15EQh6pBeeaHJ7aizP9MQhK81dES3Uq
template-ABFg nightly-2026-10-12-2664a27 ABFgWwu8SwPJfp7tzxDoTL41b1jFeHEac3RxUFSt1WWp
basic-webserver-0.17.0 nightly-2026-10-06-c34079d AC9goxhsjJJdrQtnc2ga3eTiESyh6ZLraZJsCVdEfeZT
roc-ray-0.10.0 nightly-2026-10-06-c34079d 5xecDmRJroKT9fnSiYsGdCKEzNWLnRKGtHJ5CxuCnpb9
LIST
  url=$(grep -o 'platform "[^"]*"' $H/apps/$app.roc | cut -d'"' -f2)
  python3 -I $W/gen.py $H/xdg/roc/packages/$hash/main.roc "$url" > $W/apps/$app.roc || { printf "%s\t-\tno app\t-\n" $app; continue; }
  for t in $(ls $H/xdg/roc/packages/$hash/targets | grep -v sysroot); do
    o=$W/out/$app-$t; rm -f $o $o.exe $o.wasm
    (cd $W/apps && timeout 300 $H/bin/$tag/roc build --target=$t --output=$o $app.roc > $o.log 2>&1)
    if [ -f $o -o -f $o.exe -o -f $o.wasm ]; then r=ok; else r="fail: $(grep -m1 -E '^Error:|error:' $o.log | cut -c1-70)"; fi
    hl=$(awk -F'\t' -v a=$app -v t=$t '$1==a && $2==t {print $3}' $H/results.tsv)
    printf "%s\t%s\t%s\t%s\n" $app $t "$r" "${hl:--}"
  done
done
