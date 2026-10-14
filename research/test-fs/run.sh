#!/bin/bash
# Does an in-memory filesystem (tmpfs) make Talon tests faster than ext4?
# Usage: run.sh [ROC] [N]   ROC: path to roc (default: the 10-09 nightly of cloudflare-workers), N: runs per case
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROC=${1:-$HERE/../../cloudflare-workers/.cache/nightlies/nightly-2026-10-09-258ab27/roc}
N=${2:-5}
PKG=$(du -s ~/.cache/roc/packages/*/ | sort -n | awk '$1>5000 && $1<20000{print $2; exit}')   # one package of 5 to 20 MB
ms() { local s=$(date +%s%N); "$@" >/dev/null 2>&1; echo $(( ($(date +%s%N) - s) / 1000000 )); }
med() { sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'; }

# Cases. $1 is the work dir on the file system under test.
cold_test() { rm -rf "$1/c"; XDG_CACHE_HOME=$1/c ROC_CACHE_DIR=$1/c/roc "$ROC" test "$1/Semver.roc"; }
warm_test() { XDG_CACHE_HOME=$1/w ROC_CACHE_DIR=$1/w/roc "$ROC" test "$1/Semver.roc"; }
store() { rm -rf "$1/s"; mkdir -p "$1/s"; cp -a "$PKG" "$1/s/p"; tar -C "$1/s" -cf "$1/s/p.tar" p; rm -rf "$1/s/p"; tar -C "$1/s" -xf "$1/s/p.tar"; rm -rf "$1/s"; }
# 200 atomic writes (write, fsync, rename) in one process, as a store write does
fsync200() { rm -rf "$1/f"; mkdir -p "$1/f"; python3 -I -c 'import os,sys
d=sys.argv[1]
for i in range(200):
    t=f"{d}/{i}.tmp"; f=open(t,"wb"); f.write(b"x"*4096); f.flush(); os.fsync(f.fileno()); f.close(); os.rename(t,f"{d}/{i}")' "$1/f"; }
# roc check of an app on basic-cli 0.29.0 (warm build cache, package already in the cache)
# same, cold: the build cache is empty, only the package is there
cold_check() { find "$1/a/roc" -mindepth 1 -maxdepth 1 ! -name packages -exec rm -rf {} +; check_app "$1"; }
check_app() { XDG_CACHE_HOME=$1/a ROC_CACHE_DIR=$1/a/roc "$ROC" check "$1/app.roc"; }

printf "case\text4_ms\ttmpfs_ms\n"
EXT=$HERE/.work; TMP=$(mktemp -d /dev/shm/talon-fs.XXXX); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$EXT"; findmnt -no FSTYPE -T "$EXT" | grep -q ext4 || echo "warning: $EXT is not ext4" >&2
BC=GrSTLEKd6yw8orQ5ByQQVY3Htg59vZYaoHBvQELueiMB   # basic-cli 0.29.0, passes on 10-09 (conformance/compat-sweep)
for d in "$EXT" "$TMP"; do
  cp "$HERE/Semver.roc" "$HERE/app.roc" "$d/"; warm_test "$d" >/dev/null 2>&1
  mkdir -p "$d/a/roc/packages"; [ -d "$d/a/roc/packages/$BC" ] || cp -a ~/.cache/roc/packages/$BC ~/.cache/roc/packages/$BC.deps.json "$d/a/roc/packages/" 2>/dev/null
  check_app "$d" >/dev/null 2>&1
done
check_app "$TMP" 2>&1 | tail -1 >&2
for c in cold_test warm_test cold_check check_app store fsync200; do
  e=$(for i in $(seq $N); do ms $c "$EXT"; done | med)
  t=$(for i in $(seq $N); do ms $c "$TMP"; done | med)
  printf "%s\t%s\t%s\n" $c $e $t
done
echo "package for store: $(du -sh "$PKG" | cut -f1), $(find "$PKG" -type f | wc -l) files" >&2
