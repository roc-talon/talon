#!/usr/bin/env bash
# Build a real roc cache for the L4 case exit/ex2-gc-real-cache (slice 067, slice 053 Q2) and print its path.
# Usage: scripts/real-cache.sh [ROOT]      Needs gh and GH_TOKEN (as scripts/get-roc.sh). Messages go to stderr, the cache dir to stdout.
#   REAL_CACHE=$(scripts/real-cache.sh) REAL_ROC=1 tests/run.sh exit/ex2
# ROOT is a dir that does not exist or is empty (default $WORK/real-cache). The cache is ROOT/roc. The script runs the compilers with
# XDG_CACHE_HOME=ROOT and ROC_CACHE_DIR=ROOT/roc, so it never writes to ~/.cache/roc. ROOT is an absolute path with no `..`.
# What it builds (what ex2 needs, 4 or more of each kind):
#   legacy dirs  nightly-<tag>   the 4 newest nightlies before 2026-10-05 (they write the legacy dirs, R-LY1), each runs `roc check` of one app
#   compat dirs  compat-<id>     the 4 oldest nightlies from 2026-10-11 on (each one has its own id), the same `roc check`
#   packages     packages/<hash> the platform, roc-parser 2.0.0 and their dependencies (4 or more), from the same app
# The tags come from the release list of roc-lang/nightlies, so no tag is in this file. The compilers are downloaded with scripts/get-roc.sh into
# a temp dir that the script deletes. `roc check` of a new compiler can print errors (the app is for the old basic-cli): the cache is made anyway.
# Exit 1: a bad ROOT, no gh, too few nightlies in the list, a download that fails, or the cache has fewer than 4 dirs of one kind.
set -eu -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
REPO=roc-lang/nightlies
OLD_BEFORE=2026-10-05
NEW_FROM=2026-10-11
NEED=4

fail() { echo "real-cache: $*" >&2; exit 1; }
say() { echo "real-cache: $*" >&2; }

root=${1:-$WORK/real-cache}
case $root in
/*) ;;
*) fail "ROOT must be an absolute path: $root" ;;
esac
case "/$root/" in
*/../* | */./*) fail "ROOT must have no . or .. part: $root" ;;
esac
[ "$root" != "${HOME:-/nonexistent}/.cache" ] && [ "$root" != "${HOME:-/nonexistent}/.cache/roc" ] || fail "ROOT is the real cache of the user: $root"
if [ -e "$root" ]; then
    [ -d "$root" ] || fail "ROOT is not a dir: $root"
    [ -z "$(ls -A "$root")" ] || fail "ROOT is not empty: $root"
fi
command -v gh > /dev/null 2>&1 || fail "gh is not installed"

mkdir -p "$root"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

say "list of the nightlies in $REPO"
gh api --paginate "repos/$REPO/releases?per_page=100" --jq '.[].tag_name' > "$tmp/all.lst" || fail "no release list of $REPO"
# Only the tags nightly-YYYY-MM-DD-<sha> (the list has older tags with a month name). The date of a tag is the 10 characters after `nightly-`.
LC_ALL=C grep -E '^nightly-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9a-f]+$' "$tmp/all.lst" | LC_ALL=C sort -u > "$tmp/tags.lst" || true
: > "$tmp/old.lst"
: > "$tmp/new.lst"
while read -r tag; do
    d=${tag#nightly-}
    d=${d:0:10}
    if [[ $d < $OLD_BEFORE ]]; then
        echo "$tag" >> "$tmp/old.lst"
    elif [[ $d > $NEW_FROM || $d == "$NEW_FROM" ]]; then
        echo "$tag" >> "$tmp/new.lst"
    fi
done < "$tmp/tags.lst"
tail -n $NEED "$tmp/old.lst" > "$tmp/old4.lst"
head -n $NEED "$tmp/new.lst" > "$tmp/new4.lst"
[ "$(wc -l < "$tmp/old4.lst")" -ge $NEED ] || fail "fewer than $NEED nightlies before $OLD_BEFORE in the list"
[ "$(wc -l < "$tmp/new4.lst")" -ge $NEED ] || fail "fewer than $NEED nightlies from $NEW_FROM on in the list"

# The app: basic-cli 0.24.0 and roc-parser 2.0.0 (the same as the case exit/ex1). It downloads the platform, the package and their dependencies.
mkdir -p "$tmp/app"
cat > "$tmp/app/main.roc" << 'EOF'
app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.24.0/AEjfyaMFFbh8FJrkkHJy68riVNPr3Qp6c6PawWQjBwMH.tar.zst", parser: "https://github.com/lukewilliamboswell/roc-parser/releases/download/2.0.0/7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW.tar.zst" }

import pf.Stdout
import parser.Utf8

main! = |args| {
    match Utf8.parse_str(Utf8.digits, args.len().to_str()) {
        Ok(n) => Stdout.line!("digits: ${n.to_str()}")?
        Err(_) => Stdout.line!("no digits")?
    }
    Ok({})
}
EOF

# check_with <tag>: install the compiler of the tag (scripts/get-roc.sh, into the temp dir) and run `roc check` with the cache of ROOT.
check_with() {
    local tag=$1 bin rc=0
    bin=$(WORK=$tmp/w ROC_TAG=$tag "$HERE/get-roc.sh") || fail "no compiler $tag"
    say "roc check with $tag"
    (cd "$tmp/app" && XDG_CACHE_HOME=$root ROC_CACHE_DIR=$root/roc "$bin" check main.roc > "$tmp/check.out" 2>&1) || rc=$?
    say "  exit $rc"
    rm -rf "$tmp/w/nightlies/$tag"
}
while read -r tag; do check_with "$tag"; done < "$tmp/old4.lst"
while read -r tag; do check_with "$tag"; done < "$tmp/new4.lst"

# What ex2 needs: 4 or more legacy dirs, compat dirs and packages.
R=$root/roc
legacy=$(cd "$R" && { ls -d nightly-* debug-* 2> /dev/null || true; } | wc -l | tr -d ' ')
compat=$(cd "$R" && { ls -d compat-* 2> /dev/null || true; } | wc -l | tr -d ' ')
pkgs=0
[ -d "$R/packages" ] && pkgs=$(cd "$R/packages" && { ls -d -- */ 2> /dev/null || true; } | wc -l | tr -d ' ')
say "cache $R: legacy dirs $legacy, compat dirs $compat, packages $pkgs"
[ "$legacy" -ge $NEED ] && [ "$compat" -ge $NEED ] && [ "$pkgs" -ge $NEED ] || fail "the cache has fewer than $NEED dirs of one kind (ex2 would fail)"
echo "$R"
