#!/bin/sh
# Makes the fake Zig index and the fake Zig archives for the fake HTTP server (PLAN-P1 3.2, slice 044).
# Usage: tests/tools/mk-zig.sh <http dir> <spec>...
#   <http dir>  the `given/http/` dir of a case. The script writes under it:
#                 zig/index.json                                       the index, one release for each spec, after a `master` entry
#                 zig/dl/<version>/zig-x86_64-linux-<version>.tar.xz   one real `.tar.xz` for each spec
#   <spec>      <version>[+badsha|+evil|+slow]
#                 <version>   a release `X.Y.Z`
#                 +badsha     the `shasum` of the index is the sha256 of other bytes (a download fails the check, R-D2)
#                 +evil       the archive has one more member, `<top>/../../evil.txt`, and its `shasum` is right: `tar` must refuse it (R-SE9)
#                 +slow       the route has `slow 300`: the body goes out in 4 parts
# The index has the shape of https://ziglang.org/download/index.json for the target `x86_64-linux` only: a `master` entry with a dev `version`, and for each release `date`, `docs`, `src` and the target object
# with `tarball`, `shasum` and `size` (a text of digits). `$PORT` in a URL is replaced by the fake HTTP server (tests/tools/fakehttp.py).
# The archive has one top dir `zig-x86_64-linux-<version>/` (as the real archive has), with `zig` (a shell script that prints the version), `LICENSE`, `lib/std/std.zig` and `doc/langref.html`.
# The tar and the xz settings are fixed (`--sort=name --mtime=@0 --owner=0 --group=0`, `xz -T1`), so a second run with the same tools writes the same files. It needs GNU tar and xz. It is run by hand, and the output is kept in the cases.
set -e
[ $# -ge 2 ] || { echo "usage: mk-zig.sh <http dir> <spec>..." >&2; exit 2; }
out=$1
shift
mkdir -p "$out/zig"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
body='"master": { "version": "0.18.0-dev.5+abcdef", "date": "2026-10-20", "x86_64-linux": { "tarball": "https://ziglang.org/builds/zig-x86_64-linux-0.18.0-dev.5+abcdef.tar.xz", "shasum": "9999999999999999999999999999999999999999999999999999999999999999", "size": "1" } }'
for spec in "$@"; do
    mode=ok
    case $spec in *+badsha) mode=bad spec=${spec%+badsha} ;; *+evil) mode=evil spec=${spec%+evil} ;; *+slow) mode=slow spec=${spec%+slow} ;; esac
    version=$spec
    top=zig-x86_64-linux-$version
    name=$top.tar.xz
    mkdir -p "$tmp/stage/$top/lib/std" "$tmp/stage/$top/doc" "$out/zig/dl/$version"
    printf '#!/bin/sh\necho %s\n' "$version" > "$tmp/stage/$top/zig"
    chmod 755 "$tmp/stage/$top/zig"
    printf 'fake license of zig %s\n' "$version" > "$tmp/stage/$top/LICENSE"
    printf '// fake std %s\n' "$version" > "$tmp/stage/$top/lib/std/std.zig"
    printf '<html>fake langref %s</html>\n' "$version" > "$tmp/stage/$top/doc/langref.html"
    if [ $mode = evil ]; then
        printf 'evil\n' > "$tmp/stage/evil.txt"
        tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cPf - -C "$tmp/stage" --transform="s,^evil.txt\$,$top/../../evil.txt," "$top" evil.txt 2> /dev/null | xz -T1 > "$out/zig/dl/$version/$name"
    else
        tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - -C "$tmp/stage" "$top" | xz -T1 > "$out/zig/dl/$version/$name"
    fi
    rm -rf "$tmp/stage"
    size=$(wc -c < "$out/zig/dl/$version/$name" | tr -d ' ')
    if [ $mode = bad ]; then sha=$(printf 'other bytes' | sha256sum | cut -d' ' -f1); else sha=$(sha256sum "$out/zig/dl/$version/$name" | cut -d' ' -f1); fi
    [ $mode = slow ] && printf 'slow 300\n' > "$out/zig/dl/$version/$name.meta"
    release="\"$version\": { \"date\": \"2026-01-01\", \"docs\": \"https://ziglang.org/documentation/$version/\", \"src\": { \"tarball\": \"http://127.0.0.1:\$PORT/zig/dl/$version/zig-$version.tar.xz\", \"shasum\": \"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\", \"size\": \"17000000\" }, \"x86_64-linux\": { \"tarball\": \"http://127.0.0.1:\$PORT/zig/dl/$version/$name\", \"shasum\": \"$sha\", \"size\": \"$size\" } }"
    body="$body,
$release"
done
printf '{\n%s\n}\n' "$body" > "$out/zig/index.json"
