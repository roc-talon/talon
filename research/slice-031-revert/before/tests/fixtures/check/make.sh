#!/bin/bash
# Makes the real `roc check` and `roc build` outputs of slice 006 again, with the pinned `roc` (docs/slices/006-probes-ladder.md).
# Usage: tests/fixtures/check/make.sh
# Input:  src/<case>/ (an app and its modules), src/lib-local/ (a path package), src/pkg-*-bad|good/ (the sources of the fake package dirs).
#         The hashes are the ones of the L2 case `ladder/ld-ladder-flow`: HA is acme/parser 1.0.0, HB1 is acme/json 2.0.0 (good), HB2 is acme/json 2.1.0 (bad).
# Output: out/<case>.args (the roc arguments), out/<case>.exit, out/<case>.stdout, out/<case>.stderr for each case.
# The cases run in the fixed dir /tmp/talon-check-fixtures, because roc prints paths that are relative to the working
# directory, and some messages have an absolute path. The layout is the one of an L2 case (`tests/commands/cases/`):
# `home/.cache/roc/packages/` (the packages) and `project/<case>/` (the app). So the relative paths of the outputs are the same
# in an L2 case, and the cases can use these outputs as the answers of the fake `probes!`. A case that is run as the candidate
# of a probe (`copy`) runs in `home/.cache/roc/talon/tmp/<16hex>/`, as Talon runs it (R-CC2, R-LY1). A baseline case (`project`)
# runs in `project/<case>/`.
# A package is a dir `home/.cache/roc/packages/<hash>/` with a fake hash: roc does not check the hash of a dir that is there.
# basic-cli comes from the pinned roc cache (a symbolic link). It is the only thing that this script needs from the network.
# The times of roc (`in 41ms`) change from run to run: the tests never compare them.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../../scripts/env.sh"
FIX=/tmp/talon-check-fixtures
HEX=0123456789abcdef
BASIC=CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA
HA=EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc
HB1=7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21
HB2=4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq

rm -rf "$FIX" "$HERE/out"
mkdir -p "$FIX/home/.cache/roc/packages" "$FIX/home/.cache/roc/talon/tmp/$HEX" "$FIX/project" "$HERE/out"
PKGS=$FIX/home/.cache/roc/packages
ln -s "$ROC_CACHE_DIR/packages/$BASIC" "$PKGS/$BASIC"
cp "$ROC_CACHE_DIR/packages/$BASIC.deps.json" "$PKGS/"
cp -r "$HERE/src/pkg-parser-bad" "$PKGS/$HA"
cp -r "$HERE/src/pkg-json-good" "$PKGS/$HB1"
cp -r "$HERE/src/pkg-json-bad" "$PKGS/$HB2"
cp -r "$HERE/src/lib-local" "$FIX/project/lib-local"

# run <case> <source dir in src/> <project or copy> <roc arguments>...
run() {
    local name=$1 src=$2 where=$3 dir
    shift 3
    if [ "$where" = copy ]; then
        dir=$FIX/home/.cache/roc/talon/tmp/$HEX
        rm -rf "$dir" && mkdir -p "$dir"
    else
        dir=$FIX/project/$name
        mkdir -p "$dir"
    fi
    cp -r "$HERE/src/$src/." "$dir/"
    local rc=0
    (cd "$dir" && env -i HOME=/nonexistent PATH=/usr/bin:/bin XDG_CACHE_HOME="$FIX/home/.cache" ROC_CACHE_DIR="$FIX/home/.cache/roc" \
        "$ROC" "$@" > "$HERE/out/$name.stdout" 2> "$HERE/out/$name.stderr") || rc=$?
    echo "$rc" > "$HERE/out/$name.exit"
    echo "$where $*" > "$HERE/out/$name.args"
}

run pass pass project check main.roc
run warn warn project check main.roc
run syntax syntax project check main.roc
run not-found not-found project check main.roc
run dup dup project check main.roc
run dup-shifted dup-shifted copy check main.roc
run app-errors app-errors project check main.roc
run app-errors-shifted app-errors-shifted copy check main.roc
run pkg-base pkg-base project check main.roc
run pkg-same pkg-same copy check main.roc
run pkg-new pkg-new copy check main.roc
# The builds run in the copy, as Talon runs them (Ladder.plan): a build that works, a target that the platform lacks, a build with type errors.
OUT=$FIX/home/.cache/roc/talon/tmp/$HEX/tln-probe.out
run build-pass pass copy build main.roc --output="$OUT"
run build-target pass copy build main.roc --output="$OUT" --target=x64freebsd
run build-errors app-errors-shifted copy build main.roc --output="$OUT"
for f in "$HERE"/out/*.exit; do printf '%s %s\n' "$(basename "$f" .exit)" "$(cat "$f")"; done
