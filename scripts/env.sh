# Shared settings of the test scripts. Source it: `. "$(dirname "$0")/env.sh"` (from scripts/)
# or `. "$ROOT/scripts/env.sh"`. It sets ROOT, ROC, WORK and the roc cache variables.
# The cache paths are absolute with no `..` (TESTING.md 3.2).
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# The pinned compiler (docs/slices/PLAN.md, TW28): ROC_TAG is the one place of the tag. A caller can set ROC_TAG or ROC.
ROC_TAG=${ROC_TAG:-nightly-2026-10-14-38a3029}
ROC=${ROC:-$ROOT/cloudflare-workers/.cache/nightlies/$ROC_TAG/roc}
# A caller can set WORK (the self-test runs the scripts in its own dir).
WORK=${WORK:-$ROOT/.work}
export XDG_CACHE_HOME=$WORK/cache
export ROC_CACHE_DIR=$WORK/cache/roc
mkdir -p "$XDG_CACHE_HOME" "$WORK/bin"
export ROOT ROC ROC_TAG WORK
