#!/bin/bash
# Makes the fake release server routes of a tool app whose platform is a release URL (slice 047: the evidence of a build has the hash of the platform, so the platform must have one).
# Usage: tests/tools/mk-tool-pf.sh <http dir> <owner/repo> <spec>...   (the same form as tests/tools/mk-tool.sh)
#   <http dir>    the `given/http/` dir of a case. Under it the script writes the release list and the real app bundle of each spec (as mk-tool.sh), and once the platform release
#                 `acme/pf` 1.0.0 (dl/acme/pf/releases/download/1.0.0/<hash>.tar.zst, the hash is in the file <http dir>/pf.hash, which is not a route: the runner copies it with the rest of given/).
#   <spec>        <version>@<published_at>
# The header of the app is `pf: platform "https://github.com/acme/pf/releases/download/1.0.0/<hash>.tar.zst"` and `roc: "nightly-2026-10-11-1a2b3c4"` (a compiler that the case does not install). The comment line
# `# <repo> <version>` makes each release have its own hash. The case has a `curl` in its bin dir that changes the prefix `https://github.com/` to `<fake server>/dl/` (see mk-tool.sh).
set -e
[ $# -ge 3 ] || { echo "usage: mk-tool-pf.sh <http dir> <owner/repo> <spec>..." >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/env.sh"
mkdir -p "$1"
out=$(cd "$1" && pwd)
repo=$2
shift 2
mkdir -p "$out/api/repos/$repo"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if [ ! -f "$out/pf.hash" ]; then
    mkdir -p "$tmp/pf" "$tmp/pfout"
    printf 'platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}\n\texposes []\n\tpackages {}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n\t\tx64musl: { inputs: ["libhost.a", app] },\n\t\tarm64musl: { inputs: ["libhost.a", app] },\n\t}\n\nmain_for_host! = |_args| 0\n' > "$tmp/pf/main.roc"
    pfhash=$(cd "$tmp/pf" && "$ROC" bundle main.roc --output-dir "$tmp/pfout" | sed -n 's/^Created: .*\/\(.*\)\.tar\.zst$/\1/p')
    mkdir -p "$out/dl/acme/pf/releases/download/1.0.0"
    cp "$tmp/pfout/$pfhash.tar.zst" "$out/dl/acme/pf/releases/download/1.0.0/$pfhash.tar.zst"
    printf '%s\n' "$pfhash" > "$out/pf.hash"
fi
pfhash=$(cat "$out/pf.hash")
# `roc bundle` reads the platform of the app header. It finds it in a roc cache that has the platform package under its hash, so it makes no download (the URL is github.com, and the fake server is not there at this time).
xdg=$tmp/xdg
cache=$xdg/roc
mkdir -p "$cache/packages"
(cd "$cache/packages" && "$ROC" unbundle "$out/dl/acme/pf/releases/download/1.0.0/$pfhash.tar.zst" > /dev/null)
list=
for spec in "$@"; do
    version=${spec%%@*}
    published=${spec#*@}
    src=$tmp/$version
    mkdir -p "$src" "$tmp/out"
    {
        printf 'app [main!] {\n\tpf: platform "https://github.com/acme/pf/releases/download/1.0.0/%s.tar.zst",\n\troc: "nightly-2026-10-11-1a2b3c4",\n}\n\n' "$pfhash"
        printf '# %s %s\n' "$repo" "$version"
        printf 'main! = |_args| Ok({})\n'
    } > "$src/main.roc"
    hash=$(cd "$src" && XDG_CACHE_HOME=$xdg ROC_CACHE_DIR=$cache "$ROC" bundle main.roc --output-dir "$tmp/out" | sed -n 's/^Created: .*\/\(.*\)\.tar\.zst$/\1/p')
    mkdir -p "$out/dl/$repo/releases/download/$version"
    cp "$tmp/out/$hash.tar.zst" "$out/dl/$repo/releases/download/$version/$hash.tar.zst"
    item="{\"tag_name\":\"$version\",\"draft\":false,\"prerelease\":false,\"published_at\":\"$published\",\"assets\":[{\"name\":\"$hash.tar.zst\",\"size\":1000,\"browser_download_url\":\"https://github.com/$repo/releases/download/$version/$hash.tar.zst\"}]}"
    if [ -z "$list" ]; then list=$item; else list="$list,$item"; fi
    echo "$repo $version $hash"
done
printf '[%s]\n' "$list" > "$out/api/repos/$repo/releases?per_page=100"
