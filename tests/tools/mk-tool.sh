#!/usr/bin/env bash
# Makes the fake release server routes of a tool app for the L3 runner (slice 046, `tln tool install`).
# Usage: tests/tools/mk-tool.sh <http dir> <owner/repo> <spec>...
#   <http dir>    the `given/http/` dir of a case. The script writes under it (the API base of the fake server is `<http>/api`, R-EV19):
#                   api/repos/<owner>/<repo>/releases%3Fper_page=100    the release list (one release for each spec, newest first as given)
#                   dl/<owner>/<repo>/releases/download/<version>/<hash>.tar.zst   the real app bundle of the release (made by the pinned `roc bundle`)
#   <spec>        <version>@<published_at>   for example `1.1.0@2026-09-01T12:00:00Z`
# The bundle has one file, `main.roc`: an app header with the platform `pf/main.roc` (a path entry: the platform is in the bundle) and the pin `roc: "nightly-2026-10-14-38a3029"`, and a comment line with the repo and the version, so each release has its own hash. `roc bundle`
# gives the bytes a mtime of 0 and an owner of 0, so a second run writes the same files (research/generic-packages/LAYOUT.md 5). Talon builds the URL of a bundle itself, `https://github.com/<owner>/<repo>/releases/download/<version>/<hash>.tar.zst` (Index.candidates), so the case has a
# `curl` in its bin dir that changes the prefix `https://github.com/` to `<fake server>/dl/` (given/bin/curl of tests/scenarios/tools/ti1-tool-install). Real `roc unbundle` checks the hash of the bundle.
# It is run by hand, and the output is kept in the cases.
set -e
[ $# -ge 3 ] || { echo "usage: mk-tool.sh <http dir> <owner/repo> <spec>..." >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/env.sh"
out=$1
repo=$2
shift 2
mkdir -p "$out/api/repos/$repo"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# The platform of an app is a file of the bundle (`pf/main.roc`, a path entry): `roc bundle` needs no request, and the flow has no platform to fetch (R-T2: a path entry is admitted, the check of the `targets` is in the L2 cases).
list=
for spec in "$@"; do
    version=${spec%%@*}
    published=${spec#*@}
    src=$tmp/$version
    mkdir -p "$src" "$tmp/out"
    mkdir -p "$src/pf"
    printf 'platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}\n\texposes []\n\tpackages {}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n\t\tx64musl: { inputs: ["libhost.a", app] },\n\t\tarm64musl: { inputs: ["libhost.a", app] },\n\t}\n\nmain_for_host! = |_args| 0\n' > "$src/pf/main.roc"
    {
        printf 'app [main!] {\n\tpf: platform "pf/main.roc",\n\troc: "nightly-2026-10-14-38a3029",\n}\n\n'
        printf '# %s %s\n' "$repo" "$version"
        printf 'main! = |_args| Ok({})\n'
    } > "$src/main.roc"
    hash=$(cd "$src" && "$ROC" bundle main.roc pf/main.roc --output-dir "$tmp/out" | sed -n 's/^Created: .*\/\(.*\)\.tar\.zst$/\1/p')
    mkdir -p "$out/dl/$repo/releases/download/$version"
    cp "$tmp/out/$hash.tar.zst" "$out/dl/$repo/releases/download/$version/$hash.tar.zst"
    item="{\"tag_name\":\"$version\",\"draft\":false,\"prerelease\":false,\"published_at\":\"$published\",\"assets\":[{\"name\":\"$hash.tar.zst\",\"size\":1000,\"browser_download_url\":\"https://github.com/$repo/releases/download/$version/$hash.tar.zst\"}]}"
    if [ -z "$list" ]; then list=$item; else list="$list,$item"; fi
    echo "$repo $version $hash"
done
printf '[%s]\n' "$list" > "$out/api/repos/$repo/releases%3Fper_page=100"
