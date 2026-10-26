#!/bin/bash
# F1 of slice 053 (replay, not a small Roc file): `tln add --dry-run lukewilliamboswell/roc-parser@2.0.0` on the real GitHub API
# crashes with `[ROC CRASHED] boxy runtime list comparator ordering layout failed` in one dev binary and not in another from the same sources.
# What was measured on 2026-10-25 (compiler nightly-2026-10-14-38a3029):
#   - `--opt=dev` build with the shared roc cache `.work/cache` (a warm cache, 49 GB here): crash.  `--opt=dev --no-cache`: no crash.  `--opt=speed`: no crash.
#   - The bytes of the GitHub answers are not the cause: the real answers of the 3 release lists (roc-parser, basic-cli, nightlies; 2.6 MB) on the fake HTTP of L3 give no crash with the crashing binary.
#     So the crash needs the real client path (real `curl` and headers), and a binary that was built with a warm object cache.
#   - A fresh cache does not give the crash (a build of the L2 app, then tln, then tln again: all good). research/roc-object-cache/RESULTS.md has the rule "a dev build that reads dev objects of
#     an earlier build can be bad". The state that makes it bad here is the warm `.work/cache`.
# Usage: research/slice-053-revert/f1-repro/repro.sh [speed]    needs the network, and `gh auth token` or GITHUB_TOKEN (60 requests an hour with no token). About 20 s (speed: 5 min more).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
. "$ROOT/scripts/env.sh"
W=$HERE/work
rm -rf "${W:?}"
mkdir -p "$W/warm" "$W/nocache" "$W/speed" "$W/home" "$W/p"
cp "$ROOT/tests/scenarios/exit/ex1-parser-basic-cli/given/project/main.roc" "$W/p/main.roc"
printf '[dependencies]\n' > "$W/p/talon.toml"
sed -i 's#, parser: "[^"]*"##' "$W/p/main.roc"   # an app with the platform only: `add` has a package to add
build() { # build <dir> <opt> [roc flags]
    local out=$1 opt=$2
    shift 2
    # the cache of this repo (env.sh: .work/cache): the warm one
    "$ROC" build "$ROOT/cli/main.roc" --opt="$opt" --output="$W/$out/tln" "$@" > "$W/$out.log" 2>&1 || { echo "build $out failed"; tail -3 "$W/$out.log"; exit 1; }
}
try() { # try <dir>: the real network, the pinned roc on PATH, HOME in the work dir
    (cd "$W/p" && env -i HOME="$W/home" PATH="$(dirname "$ROC"):/usr/bin:/bin" XDG_CACHE_HOME="$W/home/.cache" ROC_CACHE_DIR="$W/home/.cache/roc" TALON_REGISTRY=direct CI=true \
        GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token 2> /dev/null)}" "$W/$1/tln" add --dry-run lukewilliamboswell/roc-parser@2.0.0 2>&1 | tail -1)
}
build warm dev
build nocache dev --no-cache
echo "dev, warm cache:    $(try warm)"
echo "dev, --no-cache:    $(try nocache)"
if [ "${1:-}" = speed ]; then build speed speed; echo "speed:              $(try speed)"; fi
rm -rf "${W:?}"
