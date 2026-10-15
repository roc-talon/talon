#!/bin/sh
# Talon installer for Linux and macOS. Rules: DESIGN-CLI.md 6.5 (R-S1, R-IS1 to R-IS8).
#
#   curl -fsSL https://github.com/Karakatiza666/talon/releases/latest/download/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --version 0.3.1      (repair, R-S4)
#
# Downloads the prebuilt tln for this machine, checks its sha256 (and the attestation when
# `gh` is available), puts it in the tool bin dir, then runs `tln setup`.
# The structure follows the rocup installer (github.com/imclerran/rocup).

set -eu

REPO="${TALON_REPO:-Karakatiza666/talon}"
# Base URL of the release assets. Tests and mirrors set TALON_DOWNLOAD_BASE.
BASE="${TALON_DOWNLOAD_BASE:-https://github.com/$REPO/releases}"
VERSION=""
YES=""
SETUP_ARGS=""

say() { printf '%s\n' "$*" >&2; }
die() { printf 'install.sh: error: %s\n' "$*" >&2; exit "${2:-1}"; }

usage() {
    cat >&2 <<EOF
Install Talon (tln) from the GitHub Releases of $REPO.

Usage: install.sh [--version <v>] [--yes] [--no-modify-path]

  --version <v>       Install release v (default: the newest release)
  --yes               Do not ask for confirmation
  --no-modify-path    Do not add the bin dir to PATH (passed to tln setup)

Environment: TALON_REPO, TALON_DOWNLOAD_BASE, and the non-interactive
variables of tln (CI, DEBIAN_FRONTEND, NONINTERACTIVE, TALON_INTERACTIVE).
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --version) [ $# -ge 2 ] || die "--version needs a value" 2; VERSION="${2#v}"; shift 2 ;;
        --version=*) VERSION="${1#--version=}"; VERSION="${VERSION#v}"; shift ;;
        -y|--yes) YES=1; SETUP_ARGS="$SETUP_ARGS --yes"; shift ;;
        --no-modify-path) SETUP_ARGS="$SETUP_ARGS --no-modify-path"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage; die "unknown argument: $1" 2 ;;
    esac
done

# Roc target name of this machine (R-IS2). Linux binaries are static musl, so they run on any distro.
detect_target() {
    os=$(uname -s)
    arch=$(uname -m)
    if [ "$os" = Darwin ] && [ "$arch" = x86_64 ] &&
        [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
        arch=arm64 # x86_64 shell under Rosetta on Apple silicon: use the native binary
    fi
    case "$os/$arch" in
        Linux/x86_64|Linux/amd64) echo x64musl ;;
        Linux/aarch64|Linux/arm64) echo arm64musl ;;
        Darwin/x86_64) echo x64mac ;;
        Darwin/arm64|Darwin/aarch64) echo arm64mac ;;
        *) die "no prebuilt tln for $os/$arch. Prebuilt targets: x64musl, arm64musl, x64mac, arm64mac. On Windows, use install.ps1." ;;
    esac
}

# Same rules as tln (DESIGN-CLI.md 4), except the terminal test: with `curl | sh`, stdin is
# the script, so the installer reads the answer from /dev/tty (R-IS4).
interactive() {
    case "${TALON_INTERACTIVE:-}" in
        0) return 1 ;;
        1) ;;
        *)
            case "$(printf '%s' "${CI:-}" | tr '[:upper:]' '[:lower:]')" in true|1) return 1 ;; esac
            [ "${DEBIAN_FRONTEND:-}" = noninteractive ] && return 1
            case "${NONINTERACTIVE:-}" in 1|true) return 1 ;; esac
            ;;
    esac
    [ -t 2 ] && (: </dev/tty) 2>/dev/null
}

fetch() { # fetch <url> <file>
    if command -v curl >/dev/null 2>&1; then
        curl --proto '=https,file' --tlsv1.2 -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        die "curl or wget is required"
    fi
}

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d ' ' -f 1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d ' ' -f 1
    else
        die "sha256sum or shasum is required to check the download"
    fi
}

TARGET=$(detect_target)
ASSET="tln-$TARGET"
if [ -n "$VERSION" ]; then
    URL="$BASE/download/v$VERSION"
    LABEL="Talon $VERSION"
else
    URL="$BASE/latest/download"
    LABEL="the newest Talon release"
fi
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/talon"
BIN="$DATA/bin"

say "This installs $LABEL ($ASSET) from $REPO:"
say "  - tln goes in $BIN"
say "  - tln setup then adds tln, the roc launcher and completions to ~/.local/bin,"
say "    and the PATH line to your shell profile (DESIGN-CLI.md 6.7)"
if [ -z "$YES" ]; then
    if interactive; then
        printf 'Proceed? [Y/n] ' >&2
        reply=""
        read -r reply </dev/tty || reply=""
        case "$reply" in n|N|no|NO|No) die "cancelled" ;; esac
    else
        say "Non-interactive mode: no prompt (the command names the install)."
    fi
fi

mkdir -p "$BIN"
# Download next to the final path, so the last step is a rename on one filesystem (R-IS5).
TMP=$(mktemp "$BIN/.tln.XXXXXX")
SUMS=$(mktemp "$BIN/.sums.XXXXXX")
trap 'rm -f "$TMP" "$SUMS"' EXIT INT TERM

say "downloading $URL/$ASSET"
fetch "$URL/$ASSET" "$TMP" || die "download failed: $URL/$ASSET" 15
fetch "$URL/sha256sums.txt" "$SUMS" || die "download failed: $URL/sha256sums.txt" 15

want=$(awk -v f="$ASSET" '$2 == f || $2 == "*" f { print $1 }' "$SUMS")
[ -n "$want" ] || die "sha256sums.txt has no line for $ASSET" 16
got=$(sha256_of "$TMP")
[ "$got" = "$want" ] || die "sha256 mismatch for $ASSET: expected $want, got $got" 16
say "sha256 ok ($got)"

# Attestation (R-S1): only when gh is installed and logged in. A failed check stops the install.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh attestation verify "$TMP" --repo "$REPO" >/dev/null || die "attestation check failed for $ASSET" 16
    say "attestation ok"
else
    say "note: attestation not checked (needs gh, logged in)"
fi

chmod +x "$TMP"
# A binary that does not start never replaces a working one (R-S3).
ver=$("$TMP" --version 2>/dev/null) || die "the downloaded tln does not start on this machine"
mv -f "$TMP" "$BIN/tln"
trap 'rm -f "$SUMS"' EXIT INT TERM
say "installed $ver at $BIN/tln"

# tln setup writes the talon entry of tools.json and connects the shell (R-IS6).
# With a terminal, its prompts (R-NI13, R-NI14) read from /dev/tty, as the prompt above.
# shellcheck disable=SC2086 # SETUP_ARGS is a list of flags
if interactive; then
    "$BIN/tln" setup $SETUP_ARGS </dev/tty
else
    "$BIN/tln" setup $SETUP_ARGS
fi
