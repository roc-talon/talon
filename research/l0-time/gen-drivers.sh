#!/usr/bin/env bash
# Write the drivers tests/unit/l0-<g>.roc: each unit module tests/unit/<X>Test.roc goes to the driver with the smallest sum of weights so far (the heaviest first).
# Weight: the time of the file alone before the change (research/l0-time/per-file-j1.txt). Usage: gen-drivers.sh [N] (default 8)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/../.."
N=${1:-8}
awk '{ f=$4; sub(".*/","",f); sub("\\.roc$","",f); print $1, toupper(substr(f,1,1)) substr(f,2) "Test" }' "$HERE/per-file-j1.txt" | grep -v ' \(Conflicts\|Domain\|Moves\|Solver\)Test$' | sort -rn |
    awk -v N="$N" '{ best=1; for (g=2; g<=N; g++) if (load[g] < load[best]) best=g; load[best]+=$1; print best, $2 }' > "$HERE/assign.txt"
for g in $(seq 1 "$N"); do
    {
        echo 'app [main!] { lib: "../../cli/lib/main.roc" }'
        echo
        echo "# l0 driver $g of $N: \`roc test\` runs the \`expect\`s of the unit modules that it imports. Each unit module of this dir is imported by exactly one driver (\`scripts/test.sh\` checks it)."
        echo
        awk -v g="$g" '$1 == g { print "import " $2 }' "$HERE/assign.txt" | LC_ALL=C sort
        echo
        echo 'main! = |_args| Ok({})'
    } > "tests/unit/l0-$g.roc"
done
