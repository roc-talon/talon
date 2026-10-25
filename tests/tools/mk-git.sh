#!/bin/sh
# Makes the fake GitHub routes of a source build and the fake source archives for the fake HTTP server (PLAN-P1 3.2, slice 045).
# Usage: tests/tools/mk-git.sh <http dir> <owner/repo> <spec>...
#   <http dir>    the `given/http/` dir of a case. The script writes under it (the API base of the fake server is `<http>/api`, R-EV19):
#                   api/repos/<owner>/<repo>/commits/<ref>       the sha as text (the answer of the media type `application/vnd.github.sha`)
#                   api/repos/<owner>/<repo>/tarball/<sha>       one real `.tar.gz` for each spec (the route that R-R3 names, with no redirect)
#   <spec>        <ref>=<sha>[+evil|+redirect|+unknown]
#                   <ref>       a branch, a tag or a short sha, as the user types it after `@`
#                   <sha>       the 40 hex digits of the commit
#                   +evil       the archive has one more member, `<top>/../../evil.txt`: `tar` must refuse it (R-SE9, R-SE12: GitHub gives no hash, so `tar` is the guard)
#                   +redirect   the tarball route answers 302 to `http://127.0.0.1:$PORT/api/loot/<sha>.tar.gz`, a route that has the real archive: curl must refuse a redirect to http (R-DA3, R-SE12)
#                   +unknown    no archive. The commit route answers 422 with the JSON text of the real API for a ref that does not exist (R-R3)
# The archive is what GitHub makes for `tarball/<sha>` (checked on roc-lang/roc, 2026-10-25): one top dir `<owner>-<repo>-<sha7>/` with the files of the commit. Here the files are `build.zig`, `build.zig.zon` (the real
# key `.minimum_zig_version = "0.17.0"`), `src/main.zig` and `commit.txt` (the sha, so each commit has its own bytes). The tar and gzip settings are fixed (`--sort=name --mtime=@0 --owner=0 --group=0`, `gzip -n`), so a second run
# writes the same files. `$PORT` in a route is replaced by the fake HTTP server (tests/tools/fakehttp.py). It needs GNU tar. It is run by hand, and the output is kept in the cases.
set -e
[ $# -ge 3 ] || { echo "usage: mk-git.sh <http dir> <owner/repo> <spec>..." >&2; exit 2; }
out=$1
repo=$2
shift 2
api=$out/api/repos/$repo
mkdir -p "$api/commits" "$api/tarball"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for spec in "$@"; do
    mode=ok
    case $spec in *+evil) mode=evil spec=${spec%+evil} ;; *+redirect) mode=redirect spec=${spec%+redirect} ;; *+unknown) mode=unknown spec=${spec%+unknown} ;; esac
    ref=${spec%%=*}
    sha=${spec#*=}
    mkdir -p "$(dirname "$api/commits/$ref")"
    if [ $mode = unknown ]; then
        printf '{"message":"Not Found","documentation_url":"https://docs.github.com/rest/commits/commits#get-a-commit","status":"404"}' > "$api/commits/$ref"
        printf 'status 422\n' > "$api/commits/$ref.meta"
        continue
    fi
    printf '%s' "$sha" > "$api/commits/$ref"
    top=$(echo "$repo" | tr / -)-$(echo "$sha" | cut -c1-7)
    mkdir -p "$tmp/stage/$top/src"
    printf '// fake build.zig of %s\n' "$sha" > "$tmp/stage/$top/build.zig"
    printf '.{\n    .name = .roc,\n    .version = "0.0.0",\n    .minimum_zig_version = "0.17.0",\n    .dependencies = .{},\n}\n' > "$tmp/stage/$top/build.zig.zon"
    printf '// fake main.zig of %s\n' "$sha" > "$tmp/stage/$top/src/main.zig"
    printf '%s\n' "$sha" > "$tmp/stage/$top/commit.txt"
    archive=$tmp/archive.tar.gz
    if [ $mode = evil ]; then
        printf 'evil\n' > "$tmp/stage/evil.txt"
        tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cPf - -C "$tmp/stage" --transform="s,^evil.txt\$,$top/../../evil.txt," "$top" evil.txt 2> /dev/null | gzip -n > "$archive"
    else
        tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - -C "$tmp/stage" "$top" | gzip -n > "$archive"
    fi
    rm -rf "$tmp/stage"
    if [ $mode = redirect ]; then
        mkdir -p "$out/api/loot"
        cp "$archive" "$out/api/loot/$sha.tar.gz"
        printf 'redirect' > "$api/tarball/$sha"
        printf 'status 302\nheader Location: http://127.0.0.1:$PORT/api/loot/%s.tar.gz\n' "$sha" > "$api/tarball/$sha.meta"
    else
        cp "$archive" "$api/tarball/$sha"
    fi
done
