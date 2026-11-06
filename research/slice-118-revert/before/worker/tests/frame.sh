#!/usr/bin/env bash
# The frame checks of the Worker project (W0 step, no build needed). Usage: worker/tests/frame.sh      Env: ROC_TAG_WORKER (scripts/env.sh).
# R-WH12: the header names the platform by its release URL, never by a path to the submodule cloudflare-workers/. talon.toml pins roc-cfw (a ref and a locked url)
#         and its build script runs `roc build`, then `roc-cfw sync`. No npm package in worker/. The shim copy, the wasm and the Wrangler state are not tracked.
# R-PL2:  the platform is a Roc platform release (a .tar.zst of Karakatiza666/roc-cloudflare-workers), the generic Worker platform.
# R-WH13: the `roc:` pin of the header is ROC_TAG_WORKER.
# R-SG6:  wrangler.toml has no kv_namespaces entry (the log is a D1 table, KV is not used).
# One line for each fault, exit 1 when there is a fault.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
W=$HERE/..
. "$HERE/../../scripts/env.sh"
rc=0
bad() { echo "frame: $*"; rc=1; }
has() { grep -Eq -- "$2" "$W/$1" || bad "$1: $3"; }
has main.roc '^\s*pf: platform "https://github\.com/Karakatiza666/roc-cloudflare-workers/releases/download/[0-9]+\.[0-9]+\.[0-9]+/[A-Za-z0-9]+\.tar\.zst",?$' 'the header needs the platform by its release URL (R-WH12, R-PL2)'
grep -Eq 'cloudflare-workers/(platform|js|main\.roc)|"\.\./cloudflare-workers' "$W/main.roc" && bad "main.roc: the header must not name a path in the submodule cloudflare-workers/ (R-WH12)"
has main.roc "^\s*roc: \"$ROC_TAG_WORKER\",?$" "the header needs the pin roc: \"$ROC_TAG_WORKER\" (R-WH13)"
has talon.toml '^\[tools\]' 'needs a [tools] table (R-WH12)'
has talon.toml '^roc-cfw = \{ ref = "[^"]+", url = "https://[^"]+\.tar\.zst" \}' 'needs [tools] roc-cfw with a ref and a locked url (R-WH12)'
has talon.toml '^build = \[.*roc build --target=wasm32 --no-cache --opt=speed --output=app\.wasm main\.roc.*, "roc-cfw sync"\]' 'the script build needs roc build, then roc-cfw sync (R-WH12)'
has talon.toml '^check = \[.*"roc-cfw sync --check"\]' 'the script check needs roc-cfw sync --check (R-WH12)'
[ -e "$W/package.json" ] && bad "package.json: a Worker project has no npm package (R-WH12)"
grep -Eq '^\s*(\[\[?kv_namespaces\]?\]|kv_namespaces\s*=)' "$W/wrangler.toml" && bad "wrangler.toml: no kv_namespaces entry, KV is not used (R-SG6)"
for f in app.wasm .roc-cfw/ .wrangler/; do has .gitignore "^$f\$" ".gitignore needs $f"; done
# The Worker is built with --opt=speed, never dev: on nightly 2026-10-31 the wasm32 dev backend gives wrong code for I128 to_u8_try, to_u16_try, to_i8_try and to_i16_try
# (research/roc-dev-wasm32-narrow/README.md). Three places: the scripts of talon.toml, the build of scripts/test.sh (its own mode WORKER_OPT, not OPT).
grep -Eq 'roc build .*--opt=dev' "$W/talon.toml" && bad "talon.toml: a roc build line has --opt=dev: a Worker is built with --opt=speed"
[ "$(grep -c -- '--opt=speed' "$W/talon.toml")" -ge 2 ] || bad "talon.toml: the scripts build and check need --opt=speed"
T=$HERE/../../scripts/test.sh
grep -Eq '^WORKER_OPT=speed$' "$T" || bad "scripts/test.sh: needs the line WORKER_OPT=speed"
grep -Eq 'ROC_WORKER" build .*--opt="\$WORKER_OPT"' "$T" || bad "scripts/test.sh: the Worker build line needs --opt=\"\$WORKER_OPT\" (not OPT, never dev)"
grep -E 'ROC_WORKER" build ' "$T" | grep -Eq -- '--opt="?\$OPT"?|--opt=dev' && bad "scripts/test.sh: the Worker build line must not follow OPT or use dev"
exit $rc
