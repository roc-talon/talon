#!/bin/bash
# Tests for install.sh and install.ps1 against a fake release on file:// URLs.
# Usage: install/test.sh [sh ...]   shells to run install.sh with (default: dash bash busybox sh)
#        PWSH=<path to pwsh>       also tests install.ps1 (on Linux: Windows target faked)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "ok   $*"; }
bad() { fail=$((fail + 1)); echo "FAIL $*"; }

# Fake release: tln prints a version, and `tln setup` records its arguments.
release() { # release <dir> <version>
    mkdir -p "$1"
    for t in x64musl arm64musl x64mac arm64mac x64win.exe arm64win.exe; do
        printf '#!/bin/sh\n[ "$1" = --version ] && { echo "tln %s"; exit 0; }\necho "$*" > "$(dirname "$0")/setup.log"\n' "$2" > "$1/tln-$t"
    done
    (cd "$1" && sha256sum tln-* > sha256sums.txt)
}
release "$W/rel/latest/download" 0.4.0
release "$W/rel/download/v0.3.1" 0.3.1
BASE="file://$W/rel"

# run <shell> <home> [args...]: non-interactive, no gh, fake HOME
run() {
    local sh=$1 home=$2; shift 2
    mkdir -p "$home"
    env -i PATH="$W/nogh:/usr/bin:/bin" HOME="$home" CI=true TALON_DOWNLOAD_BASE="$BASE" \
        $sh "$HERE/install.sh" "$@" > "$home/out" 2>&1
}
mkdir -p "$W/nogh"

if [ $# -gt 0 ]; then SHELLS=("$@"); else SHELLS=(dash bash "busybox sh"); fi
for sh in "${SHELLS[@]}"; do
    n=$(echo "$sh" | tr ' ' _)
    h="$W/h-$n-latest"
    if run "$sh" "$h" --no-modify-path && [ -x "$h/.local/share/talon/bin/tln" ] &&
        grep -q '^setup --no-modify-path$' "$h/.local/share/talon/bin/setup.log" && grep -q 'tln 0.4.0' "$h/out"; then
        ok "$sh: latest release, setup gets the flags"
    else bad "$sh: latest release"; cat "$h/out"; fi

    h="$W/h-$n-ver"
    if run "$sh" "$h" --version v0.3.1 --yes && grep -q 'installed tln 0.3.1' "$h/out" &&
        grep -q '^setup --yes$' "$h/.local/share/talon/bin/setup.log"; then
        ok "$sh: --version v0.3.1 --yes"
    else bad "$sh: --version"; cat "$h/out"; fi

    # A bad checksum stops with exit 16 and keeps the old binary (R-S3)
    h="$W/h-$n-sum"; mkdir -p "$h/.local/share/talon/bin"; echo old > "$h/.local/share/talon/bin/tln"
    cp -r "$W/rel" "$W/rel-bad-$n"; echo tampered >> "$W/rel-bad-$n/latest/download/tln-x64musl"
    BASE="file://$W/rel-bad-$n" run "$sh" "$h"; rc=$?
    if [ $rc = 16 ] && grep -q 'sha256 mismatch' "$h/out" && [ "$(cat "$h/.local/share/talon/bin/tln")" = old ] &&
        [ -z "$(ls -A "$h/.local/share/talon/bin" | grep -v '^tln$')" ]; then
        ok "$sh: sha256 mismatch, exit 16, old tln kept, no temp files"
    else bad "$sh: sha256 mismatch (rc $rc)"; cat "$h/out"; fi

    h="$W/h-$n-404"
    run "$sh" "$h" --version 9.9.9; rc=$?
    if [ $rc = 15 ] && grep -q 'download failed' "$h/out"; then ok "$sh: missing release, exit 15"
    else bad "$sh: missing release (rc $rc)"; cat "$h/out"; fi

    h="$W/h-$n-arg"
    run "$sh" "$h" --bogus; rc=$?
    if [ $rc = 2 ]; then ok "$sh: unknown argument, exit 2"; else bad "$sh: unknown argument (rc $rc)"; fi

    # Unsupported platform: fake uname. busybox sh runs its own uname applet, so it skips this case.
    [ "$sh" = "busybox sh" ] && continue
    mkdir -p "$W/uname-$n"; printf '#!/bin/sh\n[ "$1" = -s ] && echo FreeBSD || echo x86_64\n' > "$W/uname-$n/uname"; chmod +x "$W/uname-$n/uname"
    h="$W/h-$n-os"; mkdir -p "$h"
    env -i PATH="$W/uname-$n:/usr/bin:/bin" HOME="$h" CI=true TALON_DOWNLOAD_BASE="$BASE" $sh "$HERE/install.sh" > "$h/out" 2>&1; rc=$?
    if [ $rc = 1 ] && grep -q 'no prebuilt tln for FreeBSD/x86_64' "$h/out"; then ok "$sh: unsupported platform"
    else bad "$sh: unsupported platform (rc $rc)"; cat "$h/out"; fi
done

if [ -n "${PWSH:-}" ]; then
    # On Linux, files that pwsh downloads are not executable. Make each fake tln.exe executable as it appears.
    prun() { # prun <home> [args...]
        local home=$1; shift
        mkdir -p "$home/local"
        ( for _ in $(seq 1 1500); do chmod +x "$home"/local/talon/bin/.tln.*.exe 2>/dev/null; sleep 0.01; done ) &
        local poll=$!
        env -i PATH="/usr/bin:/bin" HOME="$home" CI=true LOCALAPPDATA="$home/local" PROCESSOR_ARCHITECTURE="${PROC_ARCH:-AMD64}" \
            TALON_DOWNLOAD_BASE="$PBASE" "$PWSH" -NoProfile -File "$HERE/install.ps1" "$@" > "$home/out" 2>&1
        local rc=$?
        kill $poll 2>/dev/null; wait $poll 2>/dev/null
        return $rc
    }
    # pwsh 7 does not read file:// URLs, so serve the fake releases over http on localhost
    port=$(python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
    python3 -I -m http.server "$port" --bind 127.0.0.1 --directory "$W" > /dev/null 2>&1 &
    srv=$!
    trap 'kill $srv 2>/dev/null; rm -rf "$W"' EXIT
    for _ in $(seq 50); do curl -fs "http://127.0.0.1:$port/" > /dev/null && break; sleep 0.1; done
    PBASE="http://127.0.0.1:$port/rel"
    h="$W/p-latest"
    if prun "$h" -NoModifyPath && grep -q 'installed tln 0.4.0' "$h/out" &&
        grep -q '^setup --no-modify-path$' "$h/local/talon/bin/setup.log"; then
        ok "pwsh: latest release, setup gets the flags"
    else bad "pwsh: latest release"; cat "$h/out"; fi

    h="$W/p-ver"
    if prun "$h" -Version v0.3.1 -Yes && grep -q 'installed tln 0.3.1' "$h/out" &&
        grep -q '^setup --yes$' "$h/local/talon/bin/setup.log"; then
        ok "pwsh: -Version v0.3.1 -Yes, replaces an existing tln.exe"
    else bad "pwsh: -Version"; cat "$h/out"; fi

    h="$W/p-sum"; mkdir -p "$h/local/talon/bin"; echo old > "$h/local/talon/bin/tln.exe"
    cp -r "$W/rel" "$W/rel-bad-p"; echo tampered >> "$W/rel-bad-p/latest/download/tln-x64win.exe"
    PBASE="http://127.0.0.1:$port/rel-bad-p" prun "$h"; rc=$?
    if [ $rc = 16 ] && grep -q 'sha256 mismatch' "$h/out" && [ "$(cat "$h/local/talon/bin/tln.exe")" = old ] &&
        [ -z "$(ls -A "$h/local/talon/bin" | grep -v '^tln.exe$')" ]; then
        ok "pwsh: sha256 mismatch, exit 16, old tln.exe kept, no temp files"
    else bad "pwsh: sha256 mismatch (rc $rc)"; cat "$h/out"; fi

    h="$W/p-404"
    prun "$h" -Version 9.9.9; rc=$?
    if [ $rc = 15 ]; then ok "pwsh: missing release, exit 15"; else bad "pwsh: missing release (rc $rc)"; cat "$h/out"; fi

    # R-IS2: Windows on ARM64 gets the x64 build
    h="$W/p-arm64"
    if PROC_ARCH=ARM64 prun "$h" && grep -q 'installs the newest Talon release (tln-x64win.exe)' "$h/out" &&
        grep -q 'runs by emulation' "$h/out" && grep -q 'installed tln 0.4.0' "$h/out"; then
        ok "pwsh: ARM64 installs the x64 build"
    else bad "pwsh: ARM64 fallback"; cat "$h/out"; fi

    h="$W/p-arch"; mkdir -p "$h"
    env -i PATH="/usr/bin:/bin" HOME="$h" CI=true LOCALAPPDATA="$h" PROCESSOR_ARCHITECTURE=x86 \
        TALON_DOWNLOAD_BASE="$PBASE" "$PWSH" -NoProfile -File "$HERE/install.ps1" > "$h/out" 2>&1; rc=$?
    if [ $rc = 1 ] && grep -q 'no prebuilt tln for Windows on x86' "$h/out"; then ok "pwsh: unsupported arch"
    else bad "pwsh: unsupported arch (rc $rc)"; cat "$h/out"; fi
fi

echo "$pass passed, $fail failed"
[ $fail = 0 ]
