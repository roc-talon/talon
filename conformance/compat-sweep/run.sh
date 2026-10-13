#!/bin/bash
# Q11: check every cached package against each nightly. Isolated caches.
W=$(cd "$(dirname "$0")" && pwd)
export XDG_CACHE_HOME=$W/xdg ROC_CACHE_DIR=$W/xdg/roc
mkdir -p $XDG_CACHE_HOME/roc
[ -d $XDG_CACHE_HOME/roc/packages ] || cp -a ~/.cache/roc/packages $XDG_CACHE_HOME/roc/packages
ls $XDG_CACHE_HOME/roc/packages | grep -v '\.' > $W/hashes.txt   # dirs only (no .deps.json, no .tmp)
for tag in $(cat $W/tags.txt); do
  B=$W/bin/$tag/roc
  if [ ! -x $B ]; then
    d=$W/dl/$tag; mkdir -p $d $W/bin/$tag
    gh release download $tag -R roc-lang/nightlies -p '*linux_x86_64*' -D $d >/dev/null 2>&1 || { echo "$tag DOWNLOAD_FAIL" >> $W/log.txt; continue; }
    tar xzf $d/*.tar.gz -C $d && mv $(find $d -name roc -type f) $B && rm -rf $d
  fi
  cat $W/hashes.txt | xargs -P 12 -I{} bash -c '
    out=$(cd /tmp && timeout 30 '"$B"' check '"$XDG_CACHE_HOME"'/roc/packages/{}/main.roc 2>&1); rc=$?
    n=$(echo "$out" | grep -oE "[0-9]+ errors? and [0-9]+ warnings?" | tail -1 | grep -oE "^[0-9]+")
    if echo "$out" | grep -q "No errors found"; then r=pass; e="";
    elif [ $rc -eq 124 ]; then r=timeout; e="";
    elif [ "$n" = "0" ]; then r=pass; e="warnings only";
    elif [ -n "$n" ]; then r=fail; e="$n: $(echo "$out" | grep -E "^── ✗" | head -1 | sed "s/ ─.*//; s/^── //")";
    else r=other; e=$(echo "$out" | tail -1 | cut -c1-120); fi
    printf "%s\t%s\t%s\t%s\n" '"$tag"' {} "$r" "$e"' >> $W/results.tsv
  echo "$tag done $(date +%T)" >> $W/log.txt
done
echo ALL_DONE >> $W/log.txt
