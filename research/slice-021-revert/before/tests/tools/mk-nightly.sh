#!/bin/sh
# Makes the fake release list of roc-lang/nightlies and the fake compiler archives for the fake HTTP server (PLAN-P1 3.2, slices 020 and 021).
# Usage: tests/tools/mk-nightly.sh <http dir> <spec>...
#   <http dir>  the `given/http/` dir of a case. The script writes under it:
#                 api/repos/roc-lang/nightlies/releases?per_page=100   the list, one release for each spec, in the order of the specs
#                 dl/<tag>/roc_nightly-<target>-<date>-<sha>.tar.gz    one fake archive for each target of $TARGETS
#   <spec>      <tag>[@<published_at>][+baddigest|+nodigest]
#                 <tag>           a nightly tag in one of the two forms (nightly-2026-10-14-38a3029, nightly-2026-July-31-123c5d7)
#                 @<published_at> RFC 3339 UTC time (default: the tag date at 15:00:00Z)
#                 +baddigest      the digest is the sha256 of other bytes (a download fails the check, R-CV4)
#                 +nodigest       the digest field is null (an asset with no sha256, R-CV4)
#   TARGETS     the targets that get an archive, default `linux_x86_64`. Only `.tar.gz` targets (linux_*, macos_*): a `.zip` needs a tool that is not on each system.
# The archive holds one file, `roc`: a shell script with fixed bytes that prints `Roc compiler version <tag>`. The bytes depend on the tag only. The tar and the gzip
# headers are fixed (`--sort=name --mtime=@0 --owner=0 --group=0`, `gzip -n`), so a second run writes the same files. The asset names have the date and the sha of the tag,
# as roc names them. `$PORT` in the URLs is replaced by the fake HTTP server. It needs GNU tar. It is run by hand, and the output is kept in the cases.
set -e
[ $# -ge 2 ] || { echo "usage: mk-nightly.sh <http dir> <spec>..." >&2; exit 2; }
out=$1
shift
targets=${TARGETS:-linux_x86_64}
list=$out/api/repos/roc-lang/nightlies
mkdir -p "$list"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# `2026-July-31` gives `2026-07-31`
numeric_date() {
    year=$1 month=$2 day=$3
    case $month in
    January) month=01 ;; February) month=02 ;; March) month=03 ;; April) month=04 ;; May) month=05 ;; June) month=06 ;;
    July) month=07 ;; August) month=08 ;; September) month=09 ;; October) month=10 ;; November) month=11 ;; December) month=12 ;;
    esac
    echo "$year-$month-$day"
}

body=
for spec in "$@"; do
    mode=ok
    case $spec in *+baddigest) mode=bad spec=${spec%+baddigest} ;; *+nodigest) mode=none spec=${spec%+nodigest} ;; esac
    tag=${spec%%@*}
    published=
    case $spec in *@*) published=${spec#*@} ;; esac
    rest=${tag#nightly-}
    year=${rest%%-*}
    rest=${rest#*-}
    month=${rest%%-*}
    rest=${rest#*-}
    day=${rest%%-*}
    sha=${rest#*-}
    date=$(numeric_date "$year" "$month" "$day")
    [ -n "$published" ] || published=${date}T15:00:00Z
    assets=
    for target in $targets; do
        name=roc_nightly-$target-$date-$sha.tar.gz
        mkdir -p "$tmp/stage" "$out/dl/$tag"
        printf '#!/bin/sh\necho "Roc compiler version %s"\n' "$tag" > "$tmp/stage/roc"
        chmod 755 "$tmp/stage/roc"
        tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - -C "$tmp/stage" roc | gzip -n > "$out/dl/$tag/$name"
        rm -rf "$tmp/stage"
        size=$(wc -c < "$out/dl/$tag/$name" | tr -d ' ')
        case $mode in
        ok) digest="\"sha256:$(sha256sum "$out/dl/$tag/$name" | cut -d' ' -f1)\"" ;;
        bad) digest="\"sha256:$(printf 'other bytes' | sha256sum | cut -d' ' -f1)\"" ;;
        none) digest=null ;;
        esac
        asset="{\"name\":\"$name\",\"size\":$size,\"digest\":$digest,\"content_type\":\"application/gzip\",\"browser_download_url\":\"http://127.0.0.1:\$PORT/dl/$tag/$name\"}"
        assets=${assets:+$assets,}$asset
    done
    release="{\"tag_name\":\"$tag\",\"draft\":false,\"prerelease\":false,\"published_at\":\"$published\",\"assets\":[$assets]}"
    body=${body:+$body,
}$release
done
printf '[\n%s\n]\n' "$body" > "$list/releases?per_page=100"
