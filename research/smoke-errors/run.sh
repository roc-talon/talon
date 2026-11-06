#!/bin/bash
# G-C178 (Design Q548): where and how does `roc build` print a machine error (Resolution R-SM7)?
# Builds the smoke apps of research/smoke-app for cases that fail, and keeps stdout, stderr and the exit code apart.
# Uses the compilers and the package cache of conformance/host-link (canonical paths, Design Q15).
set -u
W=$(cd "$(dirname "$0")" && pwd)
H=$(cd "$W/../../conformance/host-link" && pwd)
A=$(cd "$W/../smoke-app/apps" && pwd)
export XDG_CACHE_HOME=$H/xdg ROC_CACHE_DIR=$H/xdg/roc
O=$W/out; mkdir -p $O
run() { # name nightly app target
  local n=$1 tag=$2 app=$3 t=$4
  (cd $A && timeout 300 $H/bin/$tag/roc build --target=$t --output=$O/$n.bin $app.roc >$O/$n.stdout 2>$O/$n.stderr); echo $? >$O/$n.exit
  rm -f $O/$n.bin $O/$n.bin.exe
  printf "%s\texit=%s\tstdout_bytes=%s\tstderr_bytes=%s\n" $n "$(cat $O/$n.exit)" "$(wc -c <$O/$n.stdout)" "$(wc -c <$O/$n.stderr)"
}
run winsdk-webserver nightly-2026-10-06-c34079d basic-webserver-0.17.0 x64win
run winsdk-ray nightly-2026-10-06-c34079d roc-ray-0.10.0 x64win
run lsystem-cli nightly-2026-10-12-2664a27 basic-cli-0.29.0 x64mac
run crt-cli-win nightly-2026-10-12-2664a27 basic-cli-0.29.0 x64win
run badtarget-cli nightly-2026-10-12-2664a27 basic-cli-0.29.0 x64nonesuch
run notarget-cli nightly-2026-10-12-2664a27 basic-cli-0.29.0 arm64glibc
