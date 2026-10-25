#!/bin/bash
# Check cli/lib/main.roc with the pinned nightly.
cd /home/george/dev/Karakatiza666/talon
export ROC=/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc
. scripts/env.sh
$ROC check cli/lib/main.roc 2>&1 | head -${1:-60}
