#!/usr/bin/env bash
# Usage: research/slice-040-revert/mode.sh ref|stub
# ref: the private reference in cli/lib (Outdated.roc, Pick.roc). stub: the public stub and the Pick.roc of the slice start.
set -e
cd "$(dirname "$0")/../.."
R=research/slice-040-revert
case "$1" in
ref) echo "the private reference of slice 040 was deleted at the review (2026-10-24); reference.sha256 has its hashes"; exit 1 ;;
stub) cp $R/stubs/Outdated.roc cli/lib/Outdated.roc; cp $R/stubs/OutdatedFlow.roc cli/lib/OutdatedFlow.roc; cp $R/before/cli/lib/Pick.roc cli/lib/Pick.roc ;;
*) echo "ref or stub"; exit 2 ;;
esac
