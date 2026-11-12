#!/usr/bin/env bash
# norm.sh <calls.log>...: turn a log baked under .tmp/tmp/talon-l2 into the /tmp/talon-l2 form of the committed logs
ROOT=/home/george/dev/Karakatiza666/talon
. $ROOT/tests/lib.sh
for f in "$@"; do
  awk '/^read_files / && / \/talon\.toml( |$)/ {print $0 " @A"; next} {print}' "$f" > "$f.n1"
  anc_filter "$ROOT/.tmp/tmp/talon-l2/x" < "$f.n1" | sed -e '\#^list_dirs /$#d' > "$f.n2"
  sed -E -e '/ @A$/{s#^read_files #read_files /talon.toml #; s# \$WORK/talon\.toml( |$)# $WORK/talon.toml /tmp/talon-l2/talon.toml /tmp/talon.toml\1#; s# @A$##}' "$f.n2" > "$f"
  rm -f "$f.n1" "$f.n2"
done
