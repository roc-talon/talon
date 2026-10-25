#!/usr/bin/env bash
# Prototype: build a tree exp3/<N>/ where each tests/unit/<x>.roc is a type module <X>Test.roc and N driver apps import them (balanced by the one-file times).
# Usage: gen-proto.sh <N>. Then: FILES=<list> sweep.sh P T. Output tree is in research/l0-time/exp3/<N>/unit/
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
N=$1
D=$HERE/exp3/$N/unit
rm -rf "$HERE/exp3/$N"; mkdir -p "$D"
ln -s "$(cd "$HERE/../.." && pwd)/tests/fixtures" "$HERE/exp3/$N/fixtures"
cap() { local s=$1; echo "$(tr a-z A-Z <<< "${s:0:1}")${s:1}"; }
# modules
for f in "$HERE"/../../tests/unit/*.roc; do
    b=$(basename "$f" .roc); M="$(cap "$b")Test"
    { awk -v M="$M" 'NR==1 { next } /^main! = / { next } { print } ' "$f" | awk -v M="$M" 'BEGIN{done=0} { print } /^import / {last=NR} ' > /dev/null
      # imports block first, then the type, then the rest
      grep -E '^import ' "$f"; echo; echo "$M :: [].{"; echo "}"; echo
      grep -vE '^(app |import |main! = )' "$f"
    } > "$D/$M.roc"
done
# groups: greedy balance on time
i=0; : > "$D/.sizes"
awk -v N="$N" '{ f=$4; sub(".*/","",f); sub("\\.roc$","",f); print $1, f }' "$HERE/per-file-j1.txt" | grep -v ' \(conflicts\|domain\|moves\|solver\)$' |
 sort -rn | awk -v N="$N" '{ best=1; for (g=2; g<=N; g++) if (load[g] < load[best]) best=g; if (load[1]=="") {} ; load[best]+=$1; print best, $2 }' > "$D/.assign"
for g in $(seq 1 "$N"); do
    { echo 'app [main!] { lib: "../../../../../cli/lib/main.roc" }'; echo
      awk -v g="$g" '$1==g { print $2 }' "$D/.assign" | while read -r b; do echo "import $(cap "$b")Test"; done | sort
      echo; echo 'main! = |_args| Ok({})'; } > "$D/g$g.roc"
done
ls "$D"/g*.roc > "$HERE/exp3/$N/files.txt"
