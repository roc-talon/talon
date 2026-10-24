#!/usr/bin/env bash
# Install the pinned roc compiler (ROC_TAG of scripts/env.sh, TW28) and print its path.
# Usage: scripts/get-roc.sh      Needs gh and GH_TOKEN. Messages go to stderr, the path of roc to stdout.
# It downloads the asset of the release ROC_TAG in roc-lang/nightlies, checks the sha256 against the digest of the
# release API (R-CV3), and installs to $WORK/nightlies/$ROC_TAG. A found file is not downloaded again.
# Exit 1: unknown system, no asset, no digest, a sha256 mismatch, or no roc in the archive.
set -eu -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
REPO=roc-lang/nightlies

fail() { echo "get-roc: $*" >&2; exit 1; }

case "$(uname -s)-$(uname -m)" in
Linux-x86_64) target=linux_x86_64 ext=.tar.gz exe=roc ;;
Darwin-arm64) target=macos_apple_silicon ext=.tar.gz exe=roc ;;
MINGW*-x86_64 | MSYS*-x86_64 | CYGWIN*-x86_64) target=windows_x86_64 ext=.zip exe=roc.exe ;;
*) fail "no nightly asset for $(uname -s) $(uname -m)" ;;
esac

dest=$WORK/nightlies/$ROC_TAG
if [ -f "$dest/$exe" ]; then
    echo "get-roc: found $dest/$exe" >&2
    echo "$dest/$exe"
    exit 0
fi

row=$(gh api "repos/$REPO/releases/tags/$ROC_TAG" --jq \
    ".assets[] | select((.name | startswith(\"roc_nightly-$target-\")) and (.name | endswith(\"$ext\"))) | [.name, .digest] | @tsv" |
    head -n 1) || fail "no release $ROC_TAG in $REPO"
name=${row%%$'\t'*}
want=${row#*$'\t'}
want=${want#sha256:}
[ -n "$name" ] || fail "release $ROC_TAG has no asset roc_nightly-$target-*$ext"
case $want in
*[!0-9a-f]* | "") fail "asset $name has no sha256 digest" ;;
esac
[ ${#want} -eq 64 ] || fail "asset $name has no sha256 digest"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "get-roc: download $name" >&2
gh release download "$ROC_TAG" -R "$REPO" -p "$name" -D "$tmp" >&2 || fail "download of $name failed"
if command -v sha256sum > /dev/null 2>&1; then
    got=$(sha256sum "$tmp/$name" | cut -d' ' -f1)
else
    got=$(shasum -a 256 "$tmp/$name" | cut -d' ' -f1)
fi
[ "$got" = "$want" ] || fail "sha256 mismatch for $name: got $got, want $want"

mkdir "$tmp/x"
case $ext in
.tar.gz) tar -xzf "$tmp/$name" -C "$tmp/x" ;;
.zip) if command -v 7z > /dev/null 2>&1; then 7z x -y "-o$tmp/x" "$tmp/$name" > /dev/null; else unzip -q "$tmp/$name" -d "$tmp/x"; fi ;;
esac
bin=$(find "$tmp/x" -type f -name "$exe" | head -n 1)
[ -n "$bin" ] || fail "no $exe in $name"
mkdir -p "$dest"
# The archive can have more files than roc (for example a platform dir): keep them next to roc.
cp -R "$(dirname "$bin")/." "$dest/"
chmod +x "$dest/$exe"
echo "get-roc: installed $dest/$exe" >&2
echo "$dest/$exe"
