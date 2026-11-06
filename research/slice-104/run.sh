#!/bin/bash
# usage: run.sh <tag-suffix: 14|31>  run the W0 tests of packages/records
cd /home/george/dev/Karakatiza666/talon
case "$1" in 14) T=nightly-2026-10-14-38a3029;; *) T=nightly-2026-10-31-f7bef6b;; esac
cloudflare-workers/.cache/nightlies/$T/roc test packages/records/tests/w0.roc --no-cache 2>&1
