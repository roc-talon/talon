#!/bin/bash
# Q15: does `roc check` on an app check only the package modules it imports?
# pkg/ has Good (valid) and Bad (type error). Per nightly, with a basic-cli that passes there:
#   app imports Good -> expect pass;  app imports Bad -> expect fail;  pkg/main.roc -> expect fail.
# Usage: run.sh [BIN_DIR]   (BIN_DIR/<tag>/roc, default ../compat-sweep/bin)
W=$(cd "$(dirname "$0")" && pwd); S=$W/../compat-sweep
BIN=${1:-$S/bin}
export XDG_CACHE_HOME=$W/xdg ROC_CACHE_DIR=$W/xdg/roc   # own cache, packages seeded from the sweep
rm -rf $W/xdg; mkdir -p $W/xdg/roc; cp -a $S/xdg/roc/packages $W/xdg/roc/
cd $W
chk() { out=$(timeout 30 $B check $1 2>&1); rc=$?
  if echo "$out" | grep -q "No errors found"; then echo pass
  elif [ $rc -eq 124 ]; then echo timeout
  elif [ "$(echo "$out" | grep -oE "[0-9]+ errors? and" | tail -1 | grep -oE "^[0-9]+")" = 0 ]; then echo pass
  else echo fail; fi; }
printf "nightly\tplatform\tapp_good\tapp_bad\tpkg\tverdict\n"
for tag in $(cat $S/tags.txt); do
  B=$BIN/$tag/roc
  h=$(awk -v t=$tag '$1==t && $3=="pass"{print $2}' $S/results.tsv | grep -xFf <(grep basic-cli $S/labels.tsv | cut -f1) | head -1)
  [ -z "$h" ] && { printf "%s\t-\t-\t-\t-\tno platform\n" $tag; continue; }
  v=$(awk -v h=$h '$1==h{print $2}' $S/labels.tsv)
  for m in Good Bad; do sed "s|PF|https://github.com/roc-lang/basic-cli/releases/download/${v#basic-cli@}/$h.tar.zst|" app_$m.roc > .t_$m.roc; done
  g=$(chk .t_Good.roc); b=$(chk .t_Bad.roc); p=$(chk pkg/main.roc)
  [ $g = pass ] && [ $b = fail ] && [ $p = fail ] && r=yes || r=NO
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" $tag $v $g $b $p $r
done
rm -f .t_*.roc
