#!/usr/bin/env bash
# Peak RSS and time of each roc call of scripts/test.sh, one call at a time (/usr/bin/time -v).
# Usage: research/test-memory/measure.sh        (uses the roc cache of scripts/env.sh; set WORK for another one)
set -u
. "$(dirname "$0")/../../scripts/env.sh"
cd "$ROOT" || exit 1
OUT=$WORK/exp-bin
mkdir -p "$OUT"
T=$(mktemp)
m() { # m <label> <cmd...>
    local label=$1
    shift
    /usr/bin/time -v -o "$T" "$@" > /dev/null 2>&1
    printf '%-34s rc=%s  %6.1f s  %7.0f MB\n' "$label" "$?" \
        "$(grep Elapsed "$T" | awk '{n=split($NF,a,":"); s=0; for(i=1;i<=n;i++) s=s*60+a[i]; print s}')" \
        "$(grep 'Maximum resident' "$T" | awk '{print $NF/1024}')"
}
for f in cli/main.roc cli/fxprobe.roc cli/flowprobe.roc cli/lib/main.roc tests/commands/main.roc; do m "check $f" "$ROC" check "$f"; done
m "build l2 (tests/commands)" "$ROC" build tests/commands/main.roc --opt=dev --output="$OUT/l2"
m "build tln (cli/main.roc)" "$ROC" build cli/main.roc --opt=dev --output="$OUT/tln"
m "build fxprobe" "$ROC" build cli/fxprobe.roc --opt=dev --output="$OUT/fxprobe"
m "build flowprobe" "$ROC" build cli/flowprobe.roc --opt=dev --output="$OUT/flowprobe"
m "test tests/unit/why.roc --no-cache" "$ROC" test tests/unit/why.roc --no-cache
m "test tests/unit/why.roc (cache)" "$ROC" test tests/unit/why.roc
OBJ=$(echo "$ROC_CACHE_DIR"/compat-*/objects-v7)
echo "objects-v7: $(du -sm "$OBJ" 2> /dev/null | cut -f1) MB, $(find "$OBJ" -type f 2> /dev/null | wc -l) files"
rm -f "$T"
