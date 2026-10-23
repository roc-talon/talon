#!/usr/bin/env bash
# Does `roc bundle` take .js and .mjs files next to main.roc, and does `roc unbundle` give them back?
# Usage: ROC=<roc> research/talon-scripts/probes/bundle-js/run.sh
set -euo pipefail
cd "$(dirname "$0")"
: "${ROC:?set ROC}"
rm -rf .work && mkdir -p .work/stage/js .work/out .work/un
cd .work/stage
cat > main.roc <<'R'
package [Hello] {}
R
printf 'module []\n\nx = 1\n' > Hello.roc
echo "export const a = 1;" > js/index.js
echo "console.log('cli');" > js/cli.mjs
echo '{"name":"x"}' > js/package.json
"$ROC" bundle main.roc js/index.js js/cli.mjs js/package.json --output-dir ../out
cd ../un && f=$(ls ../out/*.tar.zst) && cp "$f" . && "$ROC" unbundle "$(basename "$f")" && find . -type f | sort
