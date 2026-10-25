#!/usr/bin/env bash
# Puts the private reference (ref) or the stubs (stub) of slice 042 in cli/lib. Usage: research/slice-042-revert/swap.sh ref|stub [name ...]
# The files of the reference are in research/slice-042-revert/reference/cli/lib, the stubs in research/slice-042-revert/stubs/cli/lib.
set -eu
cd "$(dirname "$0")/../.."
mode=$1; shift
case $mode in ref) from=research/slice-042-revert/reference/cli/lib ;; stub) from=research/slice-042-revert/stubs/cli/lib ;; *) echo "usage: $0 ref|stub [name ...]"; exit 2 ;; esac
names=("$@")
[ ${#names[@]} -eq 0 ] && names=(Diff PatchCmd PatchFlow Intent IntentEdit Listing Ls)
for n in "${names[@]}"; do cp "$from/$n.roc" "cli/lib/$n.roc"; done
