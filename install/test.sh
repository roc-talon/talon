#!/usr/bin/env bash
# Tests for install.sh and install.ps1 against a fake release on file:// URLs. No test uses the network (a fake curl answers for the URLs of the default release page).
# Rules: R-S1 R-S4 R-IS1 to R-IS8 R-HF10 R-NI15 R-EV10 (DESIGN-CLI.md 6.5), slice 052 (docs/slices/052-release-install.md).
# Usage: install/test.sh [sh ...]   shells to run install.sh with (default: dash bash busybox sh)
#        PWSH=<path to pwsh>       also tests install.ps1 (on Linux: Windows target faked)
# scripts/test.sh runs this file in its self-test (row install), with the shells of the machine and pwsh when there is one.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
pass=0 fail=0
ok() { pass=$((pass + 1)); echo "ok   $*"; }
bad() { fail=$((fail + 1)); echo "FAIL $*"; }

# Fake release: tln prints a version (and records the file it ran on, R-IS5), and `tln setup` records its arguments, its asset (the target in the file name) and whether stdin is a terminal (R-IS6).
release() { # release <dir> <version>
    mkdir -p "$1"
    for t in x64musl arm64musl x64mac arm64mac x64win.exe arm64win.exe; do
        printf '#!/bin/sh\n[ "$1" = --version ] && { echo "$0" >> "$(dirname "$0")/version.log"; echo "tln %s"; exit 0; }\necho "$*" > "$(dirname "$0")/setup.log"\necho %s > "$(dirname "$0")/asset.log"\nif [ -t 0 ]; then echo tty; else echo no-tty; fi > "$(dirname "$0")/stdin.log"\n' "$2" "$t" > "$1/tln-$t"
    done
    (cd "$1" && sha256sum tln-* > sha256sums.txt)
}
release "$W/rel/latest/download" 0.4.0
release "$W/rel/download/v0.3.1" 0.3.1
BASE="file://$W/rel"

# run <shell> <home> [args...]: non-interactive, no gh, fake HOME. XPATH is put before PATH, XENV is a list of NAME=value for the script.
XPATH="" XENV=()
mkdir -p "$W/nogh" "$W/uname-linux"
# The default machine of the tests is Linux x86_64 (target x64musl), so the tests give the same result on macOS. busybox sh runs its own uname applet: on Linux x86_64 it gives the same.
printf '#!/bin/sh\ncase "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) echo Linux ;; esac\n' > "$W/uname-linux/uname"; chmod +x "$W/uname-linux/uname"
run() {
    local sh=$1 home=$2; shift 2
    mkdir -p "$home"
    env -i PATH="${XPATH:+$XPATH:}$W/uname-linux:$W/nogh:/usr/bin:/bin" HOME="$home" CI=true TALON_DOWNLOAD_BASE="$BASE" ${XENV[@]+"${XENV[@]}"} \
        $sh "$HERE/install.sh" "$@" > "$home/out" 2>&1
}
# trun <shell> <home> <answers> [args...]: the script under a pseudo terminal (tests/tools/ptyrun.py) that types the answers. TENV is the list of NAME=value (default: TALON_INTERACTIVE=1).
# PIPE=1 is `curl | sh`: the script is the stdin of the shell, so the answer must come from /dev/tty (R-IS4).
PTY="$HERE/../tests/tools/ptyrun.py"
TENV=(TALON_INTERACTIVE=1) PIPE=""
trun() {
    local sh=$1 home=$2 answers=$3; shift 3
    mkdir -p "$home"
    if [ -n "$PIPE" ]; then
        env -i PATH="${XPATH:+$XPATH:}$W/uname-linux:$W/nogh:/usr/bin:/bin" HOME="$home" TALON_DOWNLOAD_BASE="$BASE" ${TENV[@]+"${TENV[@]}"} \
            python3 -I "$PTY" "$answers" /bin/sh -c "cat '$HERE/install.sh' | $sh -s -- $*" > "$home/out" 2>&1
    else
        env -i PATH="${XPATH:+$XPATH:}$W/uname-linux:$W/nogh:/usr/bin:/bin" HOME="$home" TALON_DOWNLOAD_BASE="$BASE" ${TENV[@]+"${TENV[@]}"} \
            python3 -I "$PTY" "$answers" $sh "$HERE/install.sh" "$@" > "$home/out" 2>&1
    fi
}
# A fake gh (R-S1, R-IS3): `gh auth status` and `gh attestation verify` answer as asked, and each call is logged.
mkgh() { # mkgh <dir> <auth ok|no> <verify ok|fail>
    mkdir -p "$1"
    printf '#!/bin/sh\necho "$*" >> "%s/gh.log"\ncase "$1 $2" in\n"auth status") [ %s = ok ] ;;\n"attestation verify") [ %s = ok ] ;;\nesac\n' "$1" "$2" "$3" > "$1/gh"
    chmod +x "$1/gh"
}
BINSUB=.local/share/talon/bin
# A home with an installed tln (content: $2).
oldhome() { mkdir -p "$1/$BINSUB"; printf '%s' "$2" > "$1/$BINSUB/tln"; }
# The files in a bin dir other than tln and the logs of the fake tln: a temp file that was left would show here.
extras() { ls -A "$1/$BINSUB" | grep -v -e '^tln$' -e '[.]log$' | tr '\n' ' '; }

if [ $# -gt 0 ]; then SHELLS=("$@"); else SHELLS=(dash bash "busybox sh"); fi
for sh in "${SHELLS[@]}"; do
    n=$(echo "$sh" | tr ' ' _)
    # R-IS1 R-IS2 R-IS6 R-IS4 R-NI15: the newest release (latest/download), setup gets the flags. No terminal: the script says that it asks nothing and goes on (the command names the install).
    h="$W/h-$n-latest"
    if run "$sh" "$h" --no-modify-path && [ -x "$h/.local/share/talon/bin/tln" ] &&
        grep -q '^setup --no-modify-path$' "$h/.local/share/talon/bin/setup.log" && grep -q 'tln 0.4.0' "$h/out" &&
        grep -q 'Non-interactive mode: no prompt' "$h/out" && ! grep -q 'Proceed?' "$h/out"; then
        ok "$sh: latest release, setup gets the flags"
    else bad "$sh: latest release"; cat "$h/out"; fi

    # R-S4 R-IS6 R-NI15: an exact version. --yes is passed to setup.
    h="$W/h-$n-ver"
    if run "$sh" "$h" --version v0.3.1 --yes && grep -q 'installed tln 0.3.1' "$h/out" &&
        grep -q '^setup --yes$' "$h/.local/share/talon/bin/setup.log"; then
        ok "$sh: --version v0.3.1 --yes"
    else bad "$sh: --version"; cat "$h/out"; fi

    # R-IS3 R-IS5 R-IS7 R-S3: a bad checksum stops with exit 16 and keeps the old binary
    h="$W/h-$n-sum"; mkdir -p "$h/.local/share/talon/bin"; echo old > "$h/.local/share/talon/bin/tln"
    cp -r "$W/rel" "$W/rel-bad-$n"; echo tampered >> "$W/rel-bad-$n/latest/download/tln-x64musl"
    BASE="file://$W/rel-bad-$n" run "$sh" "$h"; rc=$?
    if [ $rc = 16 ] && grep -q 'sha256 mismatch' "$h/out" && [ "$(cat "$h/.local/share/talon/bin/tln")" = old ] &&
        [ -z "$(ls -A "$h/.local/share/talon/bin" | grep -v '^tln$')" ]; then
        ok "$sh: sha256 mismatch, exit 16, old tln kept, no temp files"
    else bad "$sh: sha256 mismatch (rc $rc)"; cat "$h/out"; fi

    # R-IS7: a download error is exit 15
    h="$W/h-$n-404"
    run "$sh" "$h" --version 9.9.9; rc=$?
    if [ $rc = 15 ] && grep -q 'download failed' "$h/out"; then ok "$sh: missing release, exit 15"
    else bad "$sh: missing release (rc $rc)"; cat "$h/out"; fi

    # R-IS7: a bad argument is exit 2 (also a missing value). R-IS8: there is no uninstall script and no --uninstall.
    h="$W/h-$n-arg"
    run "$sh" "$h" --bogus; rc=$?
    run "$sh" "$h-b" --version; rc2=$?
    run "$sh" "$h-c" --uninstall; rc3=$?
    run "$sh" "$h-d" --help
    if [ $rc = 2 ] && [ $rc2 = 2 ] && [ $rc3 = 2 ] && ! ls "$HERE" | grep -qi uninstall && ! grep -qi uninstall "$h-d/out"; then
        ok "$sh: unknown argument, missing value and --uninstall, exit 2"
    else bad "$sh: unknown argument (rc $rc $rc2 $rc3)"; fi

    # R-IS3 R-S1: the attestation, only when gh is installed and logged in. A good one: `attestation ok`, gh is asked for the repository of Talon and for the temp file in the bin dir. A bad one: exit 16, the old tln stays, no temp file, setup is not run.
    # gh that is not logged in: the note, no attestation call.
    mkgh "$W/gh-$n-ok" ok ok; mkgh "$W/gh-$n-bad" ok fail; mkgh "$W/gh-$n-out" no ok
    h="$W/h-$n-att-ok"; XPATH="$W/gh-$n-ok" run "$sh" "$h" --yes; rc=$?
    h2="$W/h-$n-att-bad"; oldhome "$h2" old; XPATH="$W/gh-$n-bad" run "$sh" "$h2" --yes; rc2=$?
    h3="$W/h-$n-att-out"; XPATH="$W/gh-$n-out" run "$sh" "$h3" --yes; rc3=$?
    if [ $rc = 0 ] && grep -q 'attestation ok' "$h/out" && grep -q '^auth status$' "$W/gh-$n-ok/gh.log" &&
        grep -q "^attestation verify .*/talon/bin/\\.tln\\..* --repo roc-talon/talon\$" "$W/gh-$n-ok/gh.log" &&
        [ $rc2 = 16 ] && grep -q 'attestation check failed' "$h2/out" && [ "$(cat "$h2/$BINSUB/tln")" = old ] && [ -z "$(extras "$h2")" ] && [ ! -e "$h2/$BINSUB/setup.log" ] &&
        [ $rc3 = 0 ] && grep -q 'attestation not checked' "$h3/out" && ! grep -q 'attestation verify' "$W/gh-$n-out/gh.log"; then
        ok "$sh: attestation checked with gh, a failed check is exit 16 and keeps the old tln, gh not logged in is a note"
    else bad "$sh: attestation (rc $rc $rc2 $rc3)"; cat "$h/out" "$h2/out" "$h3/out"; cat "$W/gh-$n-ok/gh.log"; fi

    # R-IS3: a sha256sums.txt with no line for the asset is exit 16
    cp -r "$W/rel" "$W/rel-noline-$n"; grep -v ' tln-x64musl$' "$W/rel/latest/download/sha256sums.txt" > "$W/rel-noline-$n/latest/download/sha256sums.txt"
    h="$W/h-$n-noline"; BASE="file://$W/rel-noline-$n" run "$sh" "$h"; rc=$?
    if [ $rc = 16 ] && grep -q 'sha256sums.txt has no line for tln-x64musl' "$h/out" && [ -z "$(extras "$h")" ]; then ok "$sh: no sha256 line for the asset, exit 16"
    else bad "$sh: no sha256 line (rc $rc)"; cat "$h/out"; fi

    # R-IS5 R-S3: the file is a temp file in the bin dir (the same file system: the last step is a rename). --version runs on it before the rename. A binary that does not start never replaces the old one and leaves no temp file.
    h="$W/h-$n-temp"; run "$sh" "$h" --yes; rc=$?
    cp -r "$W/rel" "$W/rel-broken-$n"; printf '#!/bin/sh\nexit 1\n' > "$W/rel-broken-$n/latest/download/tln-x64musl"; (cd "$W/rel-broken-$n/latest/download" && sha256sum tln-* > sha256sums.txt)
    h2="$W/h-$n-broken"; oldhome "$h2" old; BASE="file://$W/rel-broken-$n" run "$sh" "$h2"; rc2=$?
    if [ $rc = 0 ] && grep -q "^$h/$BINSUB/[.]tln[.][A-Za-z0-9]*\$" "$h/$BINSUB/version.log" && [ -z "$(extras "$h")" ] &&
        [ $rc2 = 1 ] && grep -q 'does not start' "$h2/out" && [ "$(cat "$h2/$BINSUB/tln")" = old ] && [ -z "$(extras "$h2")" ]; then
        ok "$sh: --version runs on the temp file in the bin dir, a binary that does not start keeps the old tln"
    else bad "$sh: temp file and --version (rc $rc $rc2)"; cat "$h/$BINSUB/version.log" "$h2/out"; fi

    # R-S4: the repair path. install.sh needs no working tln: with an old tln that does not start, --version 0.3.1 installs. It also goes back from a newer release (no rollback command, no copy of the old file).
    h="$W/h-$n-repair"; oldhome "$h" '#!/bin/sh
exit 127
'
    run "$sh" "$h" --version 0.3.1 --yes; rc=$?
    h2="$W/h-$n-back"; run "$sh" "$h2" --yes; run "$sh" "$h2" --version 0.3.1 --yes; rc2=$?
    if [ $rc = 0 ] && [ "$("$h/$BINSUB/tln" --version)" = "tln 0.3.1" ] && [ -z "$(extras "$h")" ] &&
        [ $rc2 = 0 ] && [ "$("$h2/$BINSUB/tln" --version)" = "tln 0.3.1" ] && [ -z "$(extras "$h2")" ]; then
        ok "$sh: --version repairs a tln that does not start and goes back from a newer release, no copy of the old file"
    else bad "$sh: repair (rc $rc $rc2)"; cat "$h/out" "$h2/out"; fi

    # R-IS3: the script uses the URLs of the release page and nothing else: no API call, no token. A fake curl logs its arguments and fails (exit 22, so the script ends with exit 15). The first URL is the asset.
    mkdir -p "$W/fakecurl-$n"; printf '#!/bin/sh\necho "$*" >> "%s"\nexit 22\n' "$W/curl-$n.log" > "$W/fakecurl-$n/curl"; chmod +x "$W/fakecurl-$n/curl"
    : > "$W/curl-$n.log"
    XPATH="$W/fakecurl-$n"; XENV=(GITHUB_TOKEN=tok123 GH_TOKEN=tok123)
    BASE="" run "$sh" "$W/h-$n-u1" --yes; rc=$?
    XENV=()
    BASE="" run "$sh" "$W/h-$n-u2" --yes --version v0.3.1
    XENV=(TALON_REPO=foo/bar)
    BASE="" run "$sh" "$W/h-$n-u3" --yes
    if [ $rc = 15 ] && [ "$(wc -l < "$W/curl-$n.log" | tr -d ' ')" = 3 ] &&
        sed -n 1p "$W/curl-$n.log" | grep -q ' https://github.com/roc-talon/talon/releases/latest/download/tln-x64musl ' &&
        sed -n 2p "$W/curl-$n.log" | grep -q ' https://github.com/roc-talon/talon/releases/download/v0.3.1/tln-x64musl ' &&
        sed -n 3p "$W/curl-$n.log" | grep -q ' https://github.com/foo/bar/releases/latest/download/tln-x64musl ' &&
        ! grep -q -e 'api[.]github' -e 'tok123' -e 'Authorization' -e ' -H' "$W/curl-$n.log"; then
        ok "$sh: release page URLs only (latest/download, download/v<version>, TALON_REPO), no API call, no token"
    else bad "$sh: URLs (rc $rc)"; cat "$W/curl-$n.log"; fi
    XPATH="" XENV=()

    # R-IS4 R-NI15 R-IS6 R-EV10: the question under a terminal, `curl | sh` (the script is stdin, the answer comes from /dev/tty). n: exit 1 `cancelled`, nothing is made.
    # Enter: the default Yes installs, and tln setup gets /dev/tty as stdin (R-IS6). --yes and TALON_YES=1 ask nothing and pass --yes to setup.
    printf 'n\n' > "$W/ans-n"; printf '\n' > "$W/ans-enter"; : > "$W/ans-none"
    PIPE=1
    h="$W/h-$n-ask-n"; trun "$sh" "$h" "$W/ans-n" --no-modify-path; rc=$?
    h2="$W/h-$n-ask-y"; trun "$sh" "$h2" "$W/ans-enter" --no-modify-path; rc2=$?
    h3="$W/h-$n-ask-yes"; trun "$sh" "$h3" "$W/ans-none" --yes; rc3=$?
    if [ $rc = 1 ] && grep -q 'Proceed? \[Y/n\]' "$h/out" && grep -q 'cancelled' "$h/out" && [ ! -e "$h/$BINSUB" ] &&
        [ $rc2 = 0 ] && grep -q 'Proceed? \[Y/n\]' "$h2/out" && grep -q 'installed tln 0.4.0' "$h2/out" && [ "$(cat "$h2/$BINSUB/stdin.log")" = tty ] && grep -q '^setup --no-modify-path$' "$h2/$BINSUB/setup.log" &&
        [ $rc3 = 0 ] && ! grep -q 'Proceed?' "$h3/out" && [ "$(cat "$h3/$BINSUB/stdin.log")" = tty ] && grep -q '^setup --yes$' "$h3/$BINSUB/setup.log"; then
        ok "$sh: curl | sh: n cancels, Enter installs, setup reads /dev/tty, --yes asks nothing"
    else bad "$sh: the question (rc $rc $rc2 $rc3)"; cat "$h/out" "$h2/out" "$h3/out"; fi
    TENV=(TALON_INTERACTIVE=1 TALON_YES=1)
    h="$W/h-$n-ask-env"; trun "$sh" "$h" "$W/ans-enter"; rc=$?
    if [ $rc = 0 ] && ! grep -q 'Proceed?' "$h/out" && grep -q '^setup --yes$' "$h/$BINSUB/setup.log"; then ok "$sh: TALON_YES=1 asks nothing and passes --yes to setup (R-EV10)"
    else bad "$sh: TALON_YES=1 (rc $rc)"; cat "$h/out"; fi
    # The non-interactive rules of section 4 (R-EV8): each of these turns the question off, also under a terminal. The script goes on and says so.
    for e in TALON_INTERACTIVE=0 CI=true CI=1 DEBIAN_FRONTEND=noninteractive NONINTERACTIVE=1; do
        TENV=("$e"); h="$W/h-$n-ni-$e"; trun "$sh" "$h" "$W/ans-none" --no-modify-path; rc=$?
        if [ $rc = 0 ] && ! grep -q 'Proceed?' "$h/out" && grep -q 'Non-interactive mode: no prompt' "$h/out" && grep -q 'installed tln 0.4.0' "$h/out"; then ok "$sh: $e is non-interactive, no question"
        else bad "$sh: $e (rc $rc)"; cat "$h/out"; fi
    done
    TENV=(TALON_INTERACTIVE=1) PIPE=""

    # Unsupported platform: fake uname. busybox sh runs its own uname applet, so it skips this case.
    [ "$sh" = "busybox sh" ] && continue
    mkdir -p "$W/uname-$n"; printf '#!/bin/sh\n[ "$1" = -s ] && echo FreeBSD || echo x86_64\n' > "$W/uname-$n/uname"; chmod +x "$W/uname-$n/uname"
    h="$W/h-$n-os"; mkdir -p "$h"
    env -i PATH="$W/uname-$n:/usr/bin:/bin" HOME="$h" CI=true TALON_DOWNLOAD_BASE="$BASE" $sh "$HERE/install.sh" > "$h/out" 2>&1; rc=$?
    if [ $rc = 1 ] && grep -q 'no prebuilt tln for FreeBSD/x86_64' "$h/out" && grep -q 'x64musl, arm64musl, x64mac, arm64mac' "$h/out"; then ok "$sh: unsupported platform, the error lists the targets"
    else bad "$sh: unsupported platform (rc $rc)"; cat "$h/out"; fi

    # R-IS2 R-HF10: the target of each machine. Linux gets the musl build (any distribution), macOS the native one, and a shell under Rosetta on Apple silicon (x86_64 with sysctl.proc_translated 1) gets arm64. 5 targets, no arm64win (install.ps1 has the same rule).
    mkdir -p "$W/ut-$n"
    printf '#!/bin/sh\ncase "$1" in -s) echo "$FAKE_OS" ;; -m) echo "$FAKE_ARCH" ;; esac\n' > "$W/ut-$n/uname"
    printf '#!/bin/sh\necho "${FAKE_TRANS:-0}"\n' > "$W/ut-$n/sysctl"
    chmod +x "$W/ut-$n/uname" "$W/ut-$n/sysctl"
    bad_rows=""
    for row in "Linux x86_64 0 x64musl" "Linux amd64 0 x64musl" "Linux aarch64 0 arm64musl" "Linux arm64 0 arm64musl" "Darwin x86_64 0 x64mac" "Darwin x86_64 1 arm64mac" "Darwin arm64 0 arm64mac"; do
        set -- $row
        h="$W/h-$n-t-$1-$2-$3"
        XPATH="$W/ut-$n"; XENV=(FAKE_OS="$1" FAKE_ARCH="$2" FAKE_TRANS="$3")
        run "$sh" "$h" --yes --no-modify-path
        [ "$(cat "$h/$BINSUB/asset.log" 2>/dev/null)" = "$4" ] || bad_rows="$bad_rows [$row got $(cat "$h/$BINSUB/asset.log" 2>/dev/null)]"
    done
    XPATH="" XENV=()
    if [ -z "$bad_rows" ]; then ok "$sh: target of Linux x86_64 and arm64, macOS x86_64 and arm64, Rosetta"
    else bad "$sh: targets$bad_rows"; fi
done

if [ -n "${PWSH:-}" ]; then
    # On Linux, files that pwsh downloads are not executable. Make each fake tln.exe executable as it appears.
    prun() { # prun <home> [args...]
        local home=$1; shift
        mkdir -p "$home/local"
        ( for _ in $(seq 1 1500); do chmod +x "$home"/local/talon/bin/.tln.*.exe 2>/dev/null; sleep 0.01; done ) &
        local poll=$!
        env -i PATH="${XPATH:+$XPATH:}/usr/bin:/bin" HOME="$home" CI=true LOCALAPPDATA="$home/local" PROCESSOR_ARCHITECTURE="${PROC_ARCH:-AMD64}" \
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

    # R-IS3 R-S1 R-IS7 (slice 052, not run on a machine with no pwsh): the attestation as in install.sh. A good one: `attestation ok`. A bad one: exit 16, the old tln.exe stays, no temp file.
    # A sha256sums.txt with no line for the asset: exit 16.
    mkgh "$W/pgh-ok" ok ok; mkgh "$W/pgh-bad" ok fail
    h="$W/p-att-ok"; XPATH="$W/pgh-ok" prun "$h" -Yes; rc=$?
    h2="$W/p-att-bad"; mkdir -p "$h2/local/talon/bin"; echo old > "$h2/local/talon/bin/tln.exe"; XPATH="$W/pgh-bad" prun "$h2" -Yes; rc2=$?
    if [ $rc = 0 ] && grep -q 'attestation ok' "$h/out" && grep -q '^attestation verify .* --repo roc-talon/talon$' "$W/pgh-ok/gh.log" &&
        [ $rc2 = 16 ] && grep -q 'attestation check failed' "$h2/out" && [ "$(cat "$h2/local/talon/bin/tln.exe")" = old ] &&
        [ -z "$(ls -A "$h2/local/talon/bin" | grep -v -e '^tln.exe$' -e '[.]log$')" ]; then
        ok "pwsh: attestation checked with gh, a failed check is exit 16 and keeps the old tln.exe"
    else bad "pwsh: attestation (rc $rc $rc2)"; cat "$h/out" "$h2/out"; fi
    XPATH=""
    cp -r "$W/rel" "$W/rel-noline-p"; grep -v ' tln-x64win.exe$' "$W/rel/latest/download/sha256sums.txt" > "$W/rel-noline-p/latest/download/sha256sums.txt"
    h="$W/p-noline"; PBASE="http://127.0.0.1:$port/rel-noline-p" prun "$h"; rc=$?
    if [ $rc = 16 ] && grep -q 'sha256sums.txt has no line for tln-x64win.exe' "$h/out"; then ok "pwsh: no sha256 line for the asset, exit 16"
    else bad "pwsh: no sha256 line (rc $rc)"; cat "$h/out"; fi

    h="$W/p-arch"; mkdir -p "$h"
    env -i PATH="/usr/bin:/bin" HOME="$h" CI=true LOCALAPPDATA="$h" PROCESSOR_ARCHITECTURE=x86 \
        TALON_DOWNLOAD_BASE="$PBASE" "$PWSH" -NoProfile -File "$HERE/install.ps1" > "$h/out" 2>&1; rc=$?
    if [ $rc = 1 ] && grep -q 'no prebuilt tln for Windows on x86' "$h/out"; then ok "pwsh: unsupported arch"
    else bad "pwsh: unsupported arch (rc $rc)"; cat "$h/out"; fi
fi

echo "$pass passed, $fail failed"
[ $fail = 0 ]
