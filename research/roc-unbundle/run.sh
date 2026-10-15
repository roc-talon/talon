#!/bin/sh
# Can Talon extract packages with `roc unbundle` (no zstd tool, no hosted fn)?
# Usage: run.sh <roc binary> <hash>    The hash must be in ~/.cache/roc/packages/.
set -u
ROC=$1 H=$2
A=$HOME/.cache/roc/packages/$H/$H.tar.zst
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
"$ROC" version | head -1
echo "archive: $(wc -c < "$A") bytes"

mkdir "$W/ok" && cp "$A" "$W/ok/"
t0=$(date +%s%N); (cd "$W/ok" && "$ROC" unbundle "$H.tar.zst"); rc=$?; t1=$(date +%s%N)
echo "good archive: exit $rc, $(( (t1 - t0) / 1000000 )) ms"
diff -r -x '*.tar.zst' "$W/ok/$H" "$HOME/.cache/roc/packages/$H" > /dev/null && echo "  same files as the roc cache"

mkdir "$W/bad" && cp "$A" "$W/bad/" && printf x >> "$W/bad/$H.tar.zst"
(cd "$W/bad" && "$ROC" unbundle "$H.tar.zst"); echo "  corrupted archive: exit $?, dir left: $(ls "$W/bad" | grep -vc tar.zst)"

mkdir "$W/name" && cp "$A" "$W/name/2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp.tar.zst"
(cd "$W/name" && "$ROC" unbundle 2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp.tar.zst); echo "  wrong file name (other hash): exit $?"

(cd "$W/ok" && "$ROC" unbundle "$H.tar.zst"); echo "  target dir exists: exit $?"
