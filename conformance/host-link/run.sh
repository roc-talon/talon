#!/bin/bash
# Q16: build one app per platform for each target the platform ships, then list run-time imports.
# Each row of PLATFORMS: app file, nightly tag, platform hash. bin/<tag>/roc must exist.
W=$(cd "$(dirname "$0")" && pwd)
export XDG_CACHE_HOME=$W/xdg ROC_CACHE_DIR=$W/xdg/roc   # own cache, packages copied from ~/.cache/roc
mkdir -p $W/xdg/roc $W/out
[ -d $W/xdg/roc/packages ] || cp -a ~/.cache/roc/packages $W/xdg/roc/packages
PLATFORMS="
basic-cli-0.29.0 nightly-2026-10-12-2664a27 GrSTLEKd6yw8orQ5ByQQVY3Htg59vZYaoHBvQELueiMB
basic-cli-0.25.0 nightly-2026-10-12-2664a27 CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA
template-zig-1.0.0 nightly-2026-10-12-2664a27 AnZoxzoGPtSGQ15EQh6pBeeaHJ7aizP9MQhK81dES3Uq
template-ABFg nightly-2026-10-12-2664a27 ABFgWwu8SwPJfp7tzxDoTL41b1jFeHEac3RxUFSt1WWp
basic-webserver-0.17.0 nightly-2026-10-06-c34079d AC9goxhsjJJdrQtnc2ga3eTiESyh6ZLraZJsCVdEfeZT
roc-ray-0.10.0 nightly-2026-10-06-c34079d 5xecDmRJroKT9fnSiYsGdCKEzNWLnRKGtHJ5CxuCnpb9
"
cd $W/apps
printf "platform\ttarget\tbuild\tformat\tinterpreter\timports\n"
echo "$PLATFORMS" | while read app tag hash; do
  [ -z "$app" ] && continue
  for t in $(ls $W/xdg/roc/packages/$hash/targets | grep -v sysroot); do
    o=$W/out/$app-$t
    rm -f $o $o.exe $o.wasm   # roc exits non-zero on warnings, so the output file decides
    timeout 300 $W/bin/$tag/roc build --target=$t --output=$o $app.roc > $o.log 2>&1
    if [ -f $o -o -f $o.exe -o -f $o.wasm ]; then
      f=$(ls $o $o.exe $o.wasm 2>/dev/null | head -1)
      printf "%s\t%s\tok\t%s\n" $app $t "$(python3 -I $W/inspect.py $f)"
    else
      printf "%s\t%s\tfail\t-\t-\t%s\n" $app $t "$(grep -m1 -E '^Error:|error:' $o.log | cut -c1-100)"
    fi
  done
done
