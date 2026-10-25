#!/bin/sh
# Makes the fake GitHub routes and the fake source archives of a tool app for the L3 runner (slice 048, `tln tool install --git`, `update`, `rebuild`).
# Usage: tests/tools/mk-tool-git.sh <http dir> <owner/repo> <spec>...
#   <http dir>    the `given/http/` dir of a case. The script writes under it (the API base of the fake server is `<http>/api`, R-EV19):
#                   api/repos/<owner>/<repo>/commits/<ref>       the sha as text (the answer of the media type `application/vnd.github.sha`)
#                   api/repos/<owner>/<repo>/tarball/<sha>       one real `.tar.gz` for each spec (the route that R-R3 names, with no redirect)
#   <spec>        <ref>=<sha>   a branch, a tag or a short sha, and the 40 hex digits of the commit
# The archive is what GitHub makes for `tarball/<sha>`: one top dir `<owner>-<repo>-<sha7>/` with the files of the commit. Here the files are `main.roc` (an app with the platform `pf/main.roc`, a path entry, and the pin `roc: "nightly-2026-10-14-38a3029"`; a comment line
# `# <repo> <sha7>` gives each commit its own bytes, and the fake compiler of the case prints it), `pf/main.roc` (a platform with native targets) and `apps/cli/main.roc` (the same app: the target of `--path apps/cli`, with the comment `# <repo> <sha7> cli`). The tar and gzip settings
# are fixed (`--sort=name --mtime=@0 --owner=0 --group=0`, `gzip -n`), so a second run writes the same files. It needs GNU tar. It is run by hand, and the output is kept in the cases.
set -e
[ $# -ge 3 ] || { echo "usage: mk-tool-git.sh <http dir> <owner/repo> <spec>..." >&2; exit 2; }
out=$1
repo=$2
shift 2
api=$out/api/repos/$repo
mkdir -p "$api/commits" "$api/tarball"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for spec in "$@"; do
    ref=${spec%%=*}
    sha=${spec#*=}
    sha7=$(echo "$sha" | cut -c1-7)
    printf '%s' "$sha" > "$api/commits/$ref"
    top=$(echo "$repo" | tr / -)-$sha7
    mkdir -p "$tmp/stage/$top/pf" "$tmp/stage/$top/apps/cli"
    printf 'platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}\n\texposes []\n\tpackages {}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n\t\tx64musl: { inputs: ["libhost.a", app] },\n\t\tarm64musl: { inputs: ["libhost.a", app] },\n\t}\n\nmain_for_host! = |_args| 0\n' > "$tmp/stage/$top/pf/main.roc"
    printf 'app [main!] {\n\tpf: platform "pf/main.roc",\n\troc: "nightly-2026-10-14-38a3029",\n}\n\n# %s %s\nmain! = |_args| Ok({})\n' "$repo" "$sha7" > "$tmp/stage/$top/main.roc"
    printf 'app [main!] {\n\tpf: platform "../../pf/main.roc",\n\troc: "nightly-2026-10-14-38a3029",\n}\n\n# %s %s cli\nmain! = |_args| Ok({})\n' "$repo" "$sha7" > "$tmp/stage/$top/apps/cli/main.roc"
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - -C "$tmp/stage" "$top" | gzip -n > "$api/tarball/$sha"
    rm -rf "$tmp/stage"
    echo "$repo $ref $sha"
done
