#!/bin/bash
# Run the l0 driver 8 with the pinned nightly, without the dbg lines.
cd /home/george/dev/Karakatiza666/talon
export ROC=/home/george/dev/Karakatiza666/talon/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc
. scripts/env.sh
cd tests/unit && $ROC test ${1:-l0-8.roc} 2>&1 | grep -v '^\[dbg\]' | head -${2:-150}
