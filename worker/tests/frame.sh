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
# Slice 118 (R-PU35, R-PU13, R-WH14): the queue. wrangler.toml has the producer binding INDEX for the queue talon-index, a consumer of talon-index with max_retries = 4 (the first delivery and 4 retries: the delays 1, 5, 15 and 60 min)
# and the dead letter queue talon-index-dlq, and a consumer of talon-index-dlq (it writes a log line). The names of the queues are a proposal (docs/slices/118-webhook.md section 5).
queue_block() { awk -v kind="$1" -v key="$2" 'BEGIN{b=0} /^\[\[/{b=($0=="[["kind"]]")} b && $0==key {f=1} END{exit f?0:1}' "$W/wrangler.toml"; }
queue_in() { awk -v kind="$1" -v q="$2" -v key="$3" 'function flush(){ if (inb && hasq && haskey) ok=1; inb=0; hasq=0; haskey=0 } /^\[/{flush(); inb=($0=="[["kind"]]")} inb && $0=="queue = \""q"\""{hasq=1} inb && $0==key{haskey=1} END{flush(); exit ok?0:1}' "$W/wrangler.toml"; }
queue_block queues.producers 'binding = "INDEX"' || bad "wrangler.toml: needs [[queues.producers]] with binding = \"INDEX\" (R-WH14)"
queue_in queues.producers talon-index 'binding = "INDEX"' || bad "wrangler.toml: the producer INDEX needs queue = \"talon-index\" (R-WH14)"
queue_in queues.consumers talon-index 'max_retries = 4' || bad "wrangler.toml: the consumer of talon-index needs max_retries = 4 (R-PU35: the delays 1, 5, 15, 60 min)"
queue_in queues.consumers talon-index 'dead_letter_queue = "talon-index-dlq"' || bad "wrangler.toml: the consumer of talon-index needs dead_letter_queue = \"talon-index-dlq\" (R-PU35)"
queue_in queues.consumers talon-index-dlq 'queue = "talon-index-dlq"' || bad "wrangler.toml: needs a [[queues.consumers]] for talon-index-dlq (R-PU35: its consumer writes a log line)"
T=$HERE/../../scripts/test.sh
grep -Eq '^WORKER_OPT=speed$' "$T" || bad "scripts/test.sh: needs the line WORKER_OPT=speed"
grep -Eq 'ROC_WORKER" build .*--opt="\$WORKER_OPT"' "$T" || bad "scripts/test.sh: the Worker build line needs --opt=\"\$WORKER_OPT\" (not OPT, never dev)"
grep -E 'ROC_WORKER" build ' "$T" | grep -Eq -- '--opt="?\$OPT"?|--opt=dev' && bad "scripts/test.sh: the Worker build line must not follow OPT or use dev"
# Slice 228 (docs/slices/228-own-sort.md, no rule id: a build-size change): the Worker build has no call of the builtin `sort_with`, `sort_by` or `sort`. Each call site makes a full copy of the sort of the compiler (140 to 250 KB of wasm).
# The sort is `Sorted.sort_with` of packages/records. The tests are not in the build. packages/records/Sorted.roc is the one file that may name the builtin (in a comment).
# There are 12 call sites at the start of the slice (3 in packages/records, 9 in worker/): the count of `Sorted.sort_with(` must not go below 12.
S=$ROOT/packages/records
mapfile -t src < <(find "$W" "$S" -name '*.roc' -not -path "$W/.roc-cfw/*" -not -path "$W/tests/*" -not -path "$S/tests/*" -not -path "$S/Sorted.roc" | sort)
while IFS=: read -r f n; do f=${f#"$ROOT"/}; bad "${f/tests\/..\//}:$n: use Sorted.sort_with, not the sort of the compiler (slice 228)"; done < <(awk '{ t = $0; gsub(/Sorted\.sort_with\(/, "", t) } t !~ /^[ \t]*#/ && t ~ /\.sort(_with|_by)?\(|List\.sort/ { print FILENAME ":" FNR }' "${src[@]}")
[ "$(cat "${src[@]}" | grep -o 'Sorted\.sort_with(' | wc -l)" -ge 12 ] || bad "fewer than 12 uses of Sorted.sort_with( in worker/ and packages/records/ (slice 228)"
exit $rc
