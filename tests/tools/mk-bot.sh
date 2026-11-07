#!/usr/bin/env bash
# Makes the 30 L2 cases of the compat bot (slice 223): tests/commands/cases/bot/b1 to b30 (b28 to b30: slice 229). The expected files are written by hand (no reference code existed): this script is the record of how the cases are made.
# Usage: tests/tools/mk-bot.sh      (run in the root of the repo; it replaces tests/commands/cases/bot/)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/tests/commands/cases/bot
rm -rf "$OUT"
mkdir -p "$OUT"
HA=3JF3sEqM796hk5WFqA6EtmEwJQ9quALszsfJyvXNQKy3
HB=4Ss5JMkXAD9Z7cktFEdrqeMuT6jGMF1pVozTyPHZ6zT4
HC=7tj9biW3KRJ7EEWmVUGigHiouCTXhV2dzcyvwma7Cyu7
HD=29d2S7vB453rNYFdR5Ycwt7y9haRT5fwVwL9zTmBhfV2
T=nightly-2026-10-29-aaaaaaa
N2=nightly-2026-10-20-bbbbbbb
H9=127.0.0.1%3A9
H8=127.0.0.1%3A8
UA="  User-Agent: tln/0.0.1"
RD="  Cache-Control: no-cache"
TOKEN_REQ="http_send GET http://127.0.0.1:8/token?api-version=2.0&audience=http%3A%2F%2F127.0.0.1%3A9 timeout=20
  Authorization: bearer req1"

# w <file> <text>: writes the text and a new line.
w() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

# case <name> <rules text> <entry args...>: the common files of a case: entry, rules, fx/args, fx/env, the token route.
newcase() {
    C=$OUT/$1
    mkdir -p "$C/expect" "$C/fx/http/$H8" "$C/fx/http/$H9/v1"
    w "$C/entry" bot
    w "$C/rules" "$2"
    w "$C/fx/args" "$T"
    printf '%s\n' 'HOME={w}/home' 'RUNNER_TEMP={w}/home/tmp' 'TALON_REGISTRY=http://127.0.0.1:9' 'ACTIONS_ID_TOKEN_REQUEST_URL=http://127.0.0.1:8/token?api-version=2.0' 'ACTIONS_ID_TOKEN_REQUEST_TOKEN=req1' > "$C/fx/env"
    : > "$C/expect/tree.diff"
}
# token <n> <jwt>: the n-th answer of the token route (1 is the route file itself).
token() {
    local f=$C/fx/http/$H8/token
    [ "$1" = 1 ] || f=$f.$1
    w "$f" "{\"count\":1,\"value\":\"$2\"}"
    printf '%s\n' 'status 200' 'header Content-Type: application/json' 'header Cache-Control: no-store' 'require authorization: bearer req1' > "$f.meta"
}
# route <file under v1> <status> <body> [meta lines...]: a registry route. The file is under fx/http/<host>/v1/.
route() {
    local f=$C/fx/http/$H9/v1/$1 status=$2 body=$3
    shift 3
    w "$f" "$body"
    { echo "status $status"; echo 'header Content-Type: application/json'; echo 'header Cache-Control: no-store'; for l in "$@"; do echo "$l"; done; } > "$f.meta"
}
# release_json <hash>: the answer of R-AP2 for one hash.
artifact_json() {
    echo "{\"artifact\":{\"deps\":[],\"exposed\":[\"Json\"],\"hash\":\"$1\",\"kind\":\"package\",\"platform_hash\":null,\"roc_pin\":null,\"size\":222,\"target_names\":[]},\"releases\":[{\"log_index\":3,\"hash\":\"$1\",\"group\":\"github.com/acme/json/releases/download/{v}\",\"series\":\"2\",\"version\":\"2.1.0\",\"url\":\"https://github.com/acme/json/releases/download/2.1.0/$1.tar.zst\",\"tag\":\"2.1.0\",\"roc_version\":null,\"repo\":\"acme/json\",\"published_at\":1792065600000,\"yanked\":false,\"yank_reason\":null,\"withdrawn\":null,\"provenance\":[\"oidc\"]}],\"repos\":[]}"
}
artifact() { route "artifacts/$1" 200 "$(artifact_json "$1")" 'require-none authorization' 'require user-agent: tln/0.0.1'; }
# unit_doc <hash> <compiler> <outcome>: the stdout of `tln probe --json` for a unit check.
unit_doc() { echo "{\"schema\":1,\"command\":\"probe\",\"ok\":true,\"data\":{\"kind\":\"unit\",\"hash\":\"$1\",\"label\":\"acme/json 2.1.0\",\"compiler\":\"$2\",\"outcome\":\"$3\",\"modules\":[],\"probes\":1},\"error\":null}"; }
# jobs <line>...: the lines of fx/jobs. The curl rule is first: the other rules name a hash, and a curl job has the hash too.
TAB=$(printf '\t')
WRITE_REQ=('require user-agent: tln/0.0.1' 'require content-type: application/json' 'require-none talon-contributor')
sweep_body() { echo "{\"log_size\":8,\"members\":3,\"missing\":[$1],\"sweep\":null}"; }
put_route() { route "toolchains/$T.PUT" "$1" '{"toolchains":[{"tag":"nightly-2026-10-29-aaaaaaa","target":"linux_x86_64","asset_name":"roc_nightly-linux_x86_64-2026-10-29-aaaaaaa.tar.gz","sha256":"0000000000000000000000000000000000000000000000000000000000000000","size":123,"published_at":1792065600000,"log_index":7}]}' "require authorization: Bearer jwt1" 'require user-agent: tln/0.0.1' 'require-none content-type'; }
PUTLINES="http_send PUT http://127.0.0.1:9/v1/toolchains/$T timeout=20
$UA
  Authorization: Bearer jwt1"
audit_route() { route 'compat_hints%3Faudit=200' 200 "$1" 'require user-agent: tln/0.0.1' 'require cache-control: no-cache' 'require-none authorization'; }
sweeps_route() { route "sweeps/$T" 200 "$1" 'require user-agent: tln/0.0.1' 'require cache-control: no-cache' 'require-none authorization'; }
GET_SWEEPS="http_get http://127.0.0.1:9/v1/sweeps/$T
$UA
$RD"
GET_AUDIT="http_get http://127.0.0.1:9/v1/compat_hints?audit=200
$UA
$RD"
get_artifact() { printf '%s\n' "http_get http://127.0.0.1:9/v1/artifacts/$1" "$UA" "$RD"; }
fetch_job() { echo "  job - curl -fsSL --output \$HOME/tmp/$1.tar.zst https://github.com/acme/json/releases/download/2.1.0/$1.tar.zst"; }
probe_job() { echo "  job - env ROC_TOOLCHAIN=$1 tln probe --json --yes \$HOME/tmp/$2.tar.zst"; }
post_lines() { printf '%s\n' "http_send POST http://127.0.0.1:9/v1/compat timeout=20" "$UA" "  Content-Type: application/json" "  Authorization: Bearer $1" "  <body> $2"; }
row() { echo "{\"error_digest\":null,\"hash\":\"$1\",\"nightly\":\"$2\",\"result\":\"$3\",\"target\":\"any\"}"; }

# --- b1: a nightly with 2 missing hashes: the whole run. The tag is registered (201), the work list, one fetch and one probe for each hash, a new token, the rows and the sweep (201), the audit (empty).
newcase b1-sweep 'R-MX1 R-MX4 R-MX15 R-MX17 R-AP6 R-AP10 R-AP39 R-AP40 R-AP2 R-TP2 R-TP17 R-PB7 R-OUT2 (slice 223): the bot for the nightly nightly-2026-10-29-aaaaaaa. PUT of the tag (201), the work list (2 missing of 3 members, log size 8), the archives and the probes of the 2 hashes in the order of the list (pass, fail), then a new token, POST /v1/compat with 2 rows and the sweep up to 8 (201), the audit read (no pair). Reading: the token is fetched before each write (Q6).'
token 1 jwt1; token 2 jwt2
put_route 201
sweeps_route "$(sweep_body "\"$HA\",\"$HB\"")"
artifact $HA; artifact $HB
audit_route '{"pairs":[]}'
route compat.POST 201 '{"written":2}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
printf '%s\n' "# the download, then one rule for each hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\t-\n%s\t0\t%s\t-\t-\n' "$HA.tar.zst" "$(unit_doc $HA $T pass)" "$HB.tar.zst" "$(unit_doc $HB $T fail)" >> "$C/fx/jobs"
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    get_artifact $HA; get_artifact $HB
    echo "spawn_all limit=4"; fetch_job $HA; fetch_job $HB
    echo "spawn_all limit=4"; probe_job $T $HA; probe_job $T $HB
    printf '%s\n' "$TOKEN_REQ"
} > "$C/expect/calls.log"
post_lines jwt2 "{\"rows\":[$(row $HA $T pass),$(row $HB $T fail)],\"sweep\":{\"nightly\":\"$T\",\"target\":\"any\",\"upto_log_index\":8}}" >> "$C/expect/calls.log"
printf '%s\n' "$GET_AUDIT" >> "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: new" "sweep $T: 2 of 3 members to probe" "probe $HA on $T: pass" "probe $HB on $T: fail" "posted $T: 2 rows, sweep up to 8" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b2: nothing is missing and there is no sweep row yet: no probe, a sweep with no rows (R-MX4: an empty set is complete). The tag is known (200), the post answers 200 (written 0).
newcase b2-sweep-only 'R-MX4 R-MX1 R-AP10 R-AP39 R-AP6 R-OUT2 (slice 223): PUT of the tag answers 200 (known). The work list has no missing hash and no sweep row: no archive, no probe. POST /v1/compat has no row and the sweep up to the log size 8 (answer 200, written 0). The audit has no pair.'
token 1 jwt1; token 2 jwt2
put_route 200
sweeps_route "$(sweep_body "")"
audit_route '{"pairs":[]}'
route compat.POST 200 '{"written":0}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS" "$TOKEN_REQ"
    post_lines jwt2 "{\"rows\":[],\"sweep\":{\"nightly\":\"$T\",\"target\":\"any\",\"upto_log_index\":8}}"
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: known" "sweep $T: 0 of 3 members to probe" "posted $T: 0 rows, sweep up to 8" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b3: the hint audit: 2 unit pairs of an older nightly, probed on that nightly (ROC_TOOLCHAIN is the older tag), posted as rows with no sweep.
newcase b3-audit 'R-MX13 R-MX10 R-MX1 R-AP40 R-AP10 R-MX17 (slice 223): the sweep part is as b2. The audit read has 2 unit pairs of the nightly nightly-2026-10-20-bbbbbbb (one probe each on that compiler: pass, crash). Then a new token and POST /v1/compat with the 2 rows and no sweep (201). The pairs are grouped by nightly.'
token 1 jwt1; token 2 jwt2; token 3 jwt3
put_route 200
sweeps_route "$(sweep_body "")"
artifact $HC; artifact $HD
audit_route "{\"pairs\":[{\"crash_count\":0,\"fail_count\":1,\"hash\":\"$HC\",\"nightly\":\"$N2\",\"pass_count\":5,\"target\":\"any\"},{\"crash_count\":1,\"fail_count\":2,\"hash\":\"$HD\",\"nightly\":\"$N2\",\"pass_count\":0,\"target\":\"any\"}]}"
route compat.POST 200 '{"written":0}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
route compat.POST.2 201 '{"written":2}' 'require authorization: Bearer jwt3' "${WRITE_REQ[@]}"
printf '%s\n' "# the download, then one rule for each hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\t-\n%s\t0\t%s\t-\t-\n' "$HC.tar.zst" "$(unit_doc $HC $N2 pass)" "$HD.tar.zst" "$(unit_doc $HD $N2 crash)" >> "$C/fx/jobs"
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS" "$TOKEN_REQ"
    post_lines jwt2 "{\"rows\":[],\"sweep\":{\"nightly\":\"$T\",\"target\":\"any\",\"upto_log_index\":8}}"
    printf '%s\n' "$GET_AUDIT"
    get_artifact $HC; get_artifact $HD
    echo "spawn_all limit=4"; fetch_job $HC; fetch_job $HD
    echo "spawn_all limit=4"; probe_job $N2 $HC; probe_job $N2 $HD
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt3 "{\"rows\":[$(row $HC $N2 pass),$(row $HD $N2 crash)]}"
} > "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: known" "sweep $T: 0 of 3 members to probe" "posted $T: 0 rows, sweep up to 8" "audit: 2 pairs" "probe $HC on $N2: pass" "probe $HD on $N2: crash" "posted audit $N2: 2 rows" > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b4: no OIDC variable: exit 2 (usage), no request (R-AP27 for the bot, R-TP2).
newcase b4-no-oidc 'R-TP2 R-AP27 R-MX15 R-EC2 R-OUT2 (slice 223): the variable ACTIONS_ID_TOKEN_REQUEST_URL is not set: exit 2 and no request (the text names the permission). Reading: the same rule as tln publish (Q8).'
printf '%s\n' 'HOME={w}/home' 'RUNNER_TEMP={w}/home/tmp' 'TALON_REGISTRY=http://127.0.0.1:9' 'ACTIONS_ID_TOKEN_REQUEST_TOKEN=req1' > "$C/fx/env"
printf '%s\n' args env_all > "$C/expect/calls.log"
w "$C/expect/exit" 2
: > "$C/expect/stdout"
w "$C/expect/stderr" 'tln: error[usage]: the compat bot needs an OIDC token, and ACTIONS_ID_TOKEN_REQUEST_URL is not set. In a GitHub Actions job, set permissions: id-token: write.'

# --- b5: a probe gives no fact (tln probe exits 1): no row for that hash, so no sweep (R-MX4: the Worker would answer 422). The other row goes. Exit 1.
newcase b5-no-fact 'R-MX4 R-MX17 R-MX1 R-AP10 R-P3 (slice 223): 2 missing hashes. The probe of the first passes. The probe of the second exits 1 with a JSON error (no fact). The post has the 1 row and NO sweep (a member has no bot row). The run goes on to the audit. Exit 1 (Q8).'
token 1 jwt1; token 2 jwt2
put_route 201
sweeps_route "$(sweep_body "\"$HA\",\"$HB\"")"
artifact $HA; artifact $HB
audit_route '{"pairs":[]}'
route compat.POST 201 '{"written":1}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
printf '%s\n' "# the download, then one rule for each hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\t-\n%s\t1\t%s\t-\t-\n' "$HA.tar.zst" "$(unit_doc $HA $T pass)" "$HB.tar.zst" '{"schema":1,"command":"probe","ok":false,"data":null,"error":{"kind":"internal","code":1,"message":"no fact","details":null}}' >> "$C/fx/jobs"
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    get_artifact $HA; get_artifact $HB
    echo "spawn_all limit=4"; fetch_job $HA; fetch_job $HB
    echo "spawn_all limit=4"; probe_job $T $HA; probe_job $T $HB
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt2 "{\"rows\":[$(row $HA $T pass)]}"
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 1
printf '%s\n' "put $T: new" "sweep $T: 2 of 3 members to probe" "probe $HA on $T: pass" "posted $T: 1 row, no sweep" "audit: 0 pairs" > "$C/expect/stdout"
printf '%s\n' "warning: no fact for $HB on $T: tln probe exited with 1" "tln: error[internal]: 1 probe gave no fact, so there is no sweep for $T" > "$C/expect/stderr"

# --- b6: the post is retried (R-AP34, as tln publish): 503 busy, 2 s wait, 200. The same token. Nothing else.
newcase b6-retry 'R-AP34 R-AP10 R-MX4 R-TP2 (slice 223): as b2, the first POST answers 503 /errors/busy: sleep 2000 and the same request with the same token, then 200. The reads and the PUT are not retried here.'
token 1 jwt1; token 2 jwt2
put_route 200
sweeps_route "$(sweep_body "")"
audit_route '{"pairs":[]}'
route compat.POST 503 '{"type":"/errors/busy","title":"T","status":503,"detail":"D"}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
route compat.POST.2 200 '{"written":0}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
B='{"rows":[],"sweep":{"nightly":"'$T'","target":"any","upto_log_index":8}}'
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS" "$TOKEN_REQ"
    post_lines jwt2 "$B"
    echo "sleep 2000"
    post_lines jwt2 "$B"
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: known" "sweep $T: 0 of 3 members to probe" "posted $T: 0 rows, sweep up to 8" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"

# ---------------------------------------------------------------- round 2 (Design Q566 to Q578, Registry R-MX18)
# Helpers with the tag and the token as arguments.
put_route_t() { route "toolchains/$1.PUT" "$2" "{\"toolchains\":[{\"tag\":\"$1\",\"target\":\"linux_x86_64\",\"asset_name\":\"roc_nightly-linux_x86_64-x.tar.gz\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000000\",\"size\":123,\"published_at\":1792065600000,\"log_index\":7}]}" "require authorization: Bearer $3" 'require user-agent: tln/0.0.1' 'require-none content-type'; }
putlines_t() { printf '%s\n' "http_send PUT http://127.0.0.1:9/v1/toolchains/$1 timeout=20" "$UA" "  Authorization: Bearer $2"; }
sweeps_route_t() { route "sweeps/$1" 200 "$2" 'require user-agent: tln/0.0.1' 'require cache-control: no-cache' 'require-none authorization'; }
get_sweeps_t() { printf '%s\n' "http_get http://127.0.0.1:9/v1/sweeps/$1" "$UA" "$RD"; }
work_body() { echo "{\"log_size\":$1,\"members\":$2,\"missing\":[$3],\"sweep\":$4}"; }
sweep_row() { echo "{\"nightly\":\"$1\",\"target\":\"any\",\"time\":1767225609000,\"upto_log_index\":$2}"; }
problem() { echo "{\"type\":\"/errors/$1\",\"title\":\"T\",\"status\":$2,\"detail\":\"D\"}"; }
SWEEPT() { echo "{\"nightly\":\"$T\",\"target\":\"any\",\"upto_log_index\":$1}"; }
GH="api.github.com/repos/roc-lang/nightlies"
T1=nightly-2026-10-27-ccccccc; T2=nightly-2026-10-28-bbbbbbb
GH_LINES="http_get https://api.github.com/repos/roc-lang/nightlies/releases?per_page=7
$UA"
gh_item() { echo "{\"tag_name\":\"$1\",\"draft\":false,\"prerelease\":false}"; }

# --- b7: the first release of the artifact is withdrawn and it is the only one: no archive, no job, a warning, no row, so no sweep, no post. Exit 1.
newcase b7-no-release 'R-MX18 R-MX4 R-AP2 R-MX17 R-MX1 (slice 223, Q566): 1 missing hash. GET /v1/artifacts/<hash> has one release and it is withdrawn: no curl job, no probe job (no spawn_all call), a warning, no row. With no row and no sweep there is no post and no token. The audit read follows. Exit 1.'
token 1 jwt1
put_route 201
sweeps_route "$(sweep_body "\"$HA\"")"
route "artifacts/$HA" 200 "$(artifact_json $HA | sed 's/"withdrawn":null/"withdrawn":1792065700000/')" 'require user-agent: tln/0.0.1'
audit_route '{"pairs":[]}'
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    get_artifact $HA
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 1
printf '%s\n' "put $T: new" "sweep $T: 1 of 3 members to probe" "audit: 0 pairs" > "$C/expect/stdout"
printf '%s\n' "warning: no fact for $HA on $T: the artifact has no release that is not withdrawn" "tln: error[internal]: 1 probe gave no fact, so there is no sweep for $T" > "$C/expect/stderr"

# --- b8: no operand: the newest 7 releases of roc-lang/nightlies (GitHub, no token, one request): 3 nightly tags and `latest`. They go oldest first. The first 2 tags are done (bound 8 at least the log size 8, nothing missing): a token, a PUT and a read, no post. The third has nothing missing and no sweep row: the sweep alone.
newcase b8-find-tags 'R-MX18 R-MX1 R-MX4 R-MX15 R-AP39 R-AP6 (slice 223, Q567, Q572): no operand. The GitHub list has latest and 3 nightly tags (newest first). Order of the work: oldest first. Tags 1 and 2 are done: PUT and one read each, line `sweep <tag>: done`. Tag 3: the sweep alone. A token for each write (4).'
: > "$C/fx/args"
token 1 jwt1; token 2 jwt2; token 3 jwt3; token 4 jwt4
mkdir -p "$C/fx/http/$GH"
f=$C/fx/http/$GH/releases%3Fper_page=7
w "$f" "[$(gh_item $T),$(gh_item latest),$(gh_item $T2),$(gh_item $T1)]"
printf '%s\n' 'status 200' 'header Content-Type: application/json' 'require user-agent: tln/0.0.1' 'require-none authorization' > "$f.meta"
put_route_t $T1 200 jwt1; put_route_t $T2 200 jwt2; put_route_t $T 200 jwt3
sweeps_route_t $T1 "$(work_body 8 3 "" "$(sweep_row $T1 8)")"
sweeps_route_t $T2 "$(work_body 8 3 "" "$(sweep_row $T2 8)")"
sweeps_route_t $T "$(sweep_body "")"
audit_route '{"pairs":[]}'
route compat.POST 200 '{"written":0}' 'require authorization: Bearer jwt4' "${WRITE_REQ[@]}"
{
    printf '%s\n' args env_all "$GH_LINES"
    printf '%s\n' "$TOKEN_REQ"; putlines_t $T1 jwt1; get_sweeps_t $T1
    printf '%s\n' "$TOKEN_REQ"; putlines_t $T2 jwt2; get_sweeps_t $T2
    printf '%s\n' "$TOKEN_REQ"; putlines_t $T jwt3; get_sweeps_t $T
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt4 "{\"rows\":[],\"sweep\":$(SWEEPT 8)}"
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T1: known" "sweep $T1: done" "put $T2: known" "sweep $T2: done" "put $T: known" "sweep $T: 0 of 3 members to probe" "posted $T: 0 rows, sweep up to 8" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b9: no operand and GitHub answers 503: exit 15, no other request. One request, no retry (reading, Q14).
newcase b9-list-fails 'R-MX18 R-MX1 (slice 223, Q567, Q573): no operand. The GitHub list answers 503: exit 15, stop at once, no token, no registry request. Reading: the list read is one request (Q567 says one request), with no retry (Q14).'
: > "$C/fx/args"
mkdir -p "$C/fx/http/$GH"
f=$C/fx/http/$GH/releases%3Fper_page=7
w "$f" '{"message":"unavailable"}'
printf '%s\n' 'status 503' 'header Content-Type: application/json' > "$f.meta"
printf '%s\n' args env_all "$GH_LINES" > "$C/expect/calls.log"
w "$C/expect/exit" 15
: > "$C/expect/stdout"
w "$C/expect/stderr" 'tln: error[network]: the list of nightlies at api.github.com did not answer (503). The bot stops, and the next run starts again.'

# --- b10: an operand that is not a nightly tag: exit 2, no request.
newcase b10-bad-tag 'R-MX18 R-EC2 R-IK4 (slice 223, Q567, Q573): the operand latest is not a nightly tag: exit 2 and no request.'
w "$C/fx/args" latest
printf '%s\n' args env_all > "$C/expect/calls.log"
w "$C/expect/exit" 2
: > "$C/expect/stdout"
w "$C/expect/stderr" "tln: error[usage]: 'latest' is not a nightly tag. Use nightly-<date>-<sha>."

# post_base <name> <rules>: the common part of b11, b12, b17: as b2 up to the first post.
sweep_only_head() {
    token 1 jwt1; token 2 jwt2
    put_route 200
    sweeps_route "$(sweep_body "")"
    audit_route '{"pairs":[]}'
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS" "$TOKEN_REQ"
    post_lines jwt2 "$(echo "{\"rows\":[],\"sweep\":$(SWEEPT 8)}")"
}
B2BODY="{\"rows\":[],\"sweep\":{\"nightly\":\"$T\",\"target\":\"any\",\"upto_log_index\":8}}"
HEAD2="put $T: known
sweep $T: 0 of 3 members to probe"

# --- b11: 401 on the post: one new token, the same request, 200 (R-AP34 Renew). No sleep.
newcase b11-renew 'R-AP34 R-TP2 R-AP10 R-MX18 (slice 223, Q571): as b2, the first POST answers 401. A new token (the third request of the token route), the same body, 200. No sleep.'
sweep_only_head > "$C/expect/calls.log"
token 3 jwt3
route compat.POST 401 "$(problem unauthenticated 401)" 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
route compat.POST.2 200 '{"written":0}' 'require authorization: Bearer jwt3' "${WRITE_REQ[@]}"
{ printf '%s\n' "$TOKEN_REQ"; post_lines jwt3 "$B2BODY"; printf '%s\n' "$GET_AUDIT"; } >> "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "$HEAD2" "posted $T: 0 rows, sweep up to 8" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b12: 401, a new token, 401 again: exit 20 (stop at once, no audit read).
newcase b12-renew-twice 'R-AP34 R-TP2 R-E6 R-MX18 (slice 223, Q571, Q573): the post answers 401 with the first token and with the new token: exit 20 with the text of Bot.failure for a 401 (Q585), no third request, no audit read.'
sweep_only_head > "$C/expect/calls.log"
token 3 jwt3
route compat.POST 401 "$(problem unauthenticated 401)" 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
route compat.POST.2 401 "$(problem unauthenticated 401)" 'require authorization: Bearer jwt3' "${WRITE_REQ[@]}"
{ printf '%s\n' "$TOKEN_REQ"; post_lines jwt3 "$B2BODY"; } >> "$C/expect/calls.log"
w "$C/expect/exit" 20
printf '%s\n' "$HEAD2" > "$C/expect/stdout"
w "$C/expect/stderr" 'tln: error[rejected]: the registry http://127.0.0.1:9 refused the OIDC token of this run (/errors/unauthenticated): D. Check that the run is the workflow of BOT_WORKFLOW_REF on the default branch of BOT_REPOSITORY_ID (R-TP7) and that the job has permissions: id-token: write.'

# --- b17: 403 on the post: exit 20, stop at once. The text of Registry.refuse.
newcase b17-refused 'R-E6 R-AP10 R-TP7 R-MX18 (slice 223, Q573): as b2, the post answers 403 forbidden: exit 20, no retry, no audit read. The text is the one of Bot.failure for a 403 (Q585).'
sweep_only_head > "$C/expect/calls.log"
route compat.POST 403 "$(problem forbidden 403)" 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
w "$C/expect/exit" 20
printf '%s\n' "$HEAD2" > "$C/expect/stdout"
w "$C/expect/stderr" 'tln: error[rejected]: the registry http://127.0.0.1:9 refused the OIDC token of this run (/errors/forbidden): D. Check that the run is the workflow of BOT_WORKFLOW_REF on the default branch of BOT_REPOSITORY_ID (R-TP7) and that the job has permissions: id-token: write.'

# --- b18: the PUT gets no answer 4 times: sleeps of 2000, 8000 and 30000 ms, the same token, exit 15.
newcase b18-no-answer 'R-AP34 R-E6 R-AP6 R-MX18 (slice 223, Q573): the PUT of the tag times out 4 times: the sleeps 2000, 8000, 30000 (R-AP34), the same token, then exit 15. No read of the work list.'
token 1 jwt1
for n in "" .2 .3 .4; do
    f=$C/fx/http/$H9/v1/toolchains/$T.PUT$n
    mkdir -p "$(dirname "$f")"; : > "$f"
    printf '%s\n' 'error timeout' 'require authorization: Bearer jwt1' 'require user-agent: tln/0.0.1' 'require-none content-type' > "$f.meta"
done
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "sleep 2000" "$PUTLINES" "sleep 8000" "$PUTLINES" "sleep 30000" "$PUTLINES"
} > "$C/expect/calls.log"
w "$C/expect/exit" 15
: > "$C/expect/stdout"
w "$C/expect/stderr" "tln: error[network]: the registry http://127.0.0.1:9 did not take the put $T after 4 requests (no answer). The bot stops, and the next run starts again."

# --- b13: a 422 sweep-incomplete: the work list again, the new hash is probed, all rows go again with the new bound 9 (2 sweep requests).
newcase b13-sweep-incomplete 'R-MX9 R-MX4 R-MX18 R-RE13 (slice 223, Q572): the first work list has 1 missing hash (log size 8). Probe, post with the sweep up to 8: 422 sweep-incomplete (nothing was written). Read the work list again: missing 2 hashes, log size 9. The hash with a row is not probed again; the new one is. A new token, a second post with both rows and the sweep up to 9: 201. The audit follows.'
token 1 jwt1; token 2 jwt2; token 3 jwt3
put_route 201
sweeps_route "$(work_body 8 3 "\"$HA\"" null)"
f=$C/fx/http/$H9/v1/sweeps/$T.2
w "$f" "$(work_body 9 3 "\"$HA\",\"$HB\"" null)"
printf '%s\n' 'status 200' 'header Content-Type: application/json' 'header Cache-Control: no-store' 'require user-agent: tln/0.0.1' 'require cache-control: no-cache' 'require-none authorization' > "$f.meta"
artifact $HA; artifact $HB
audit_route '{"pairs":[]}'
route compat.POST 422 "$(problem sweep-incomplete 422)" 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
route compat.POST.2 201 '{"written":2}' 'require authorization: Bearer jwt3' "${WRITE_REQ[@]}"
printf '%s\n' "# the download, then one rule for each hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\t-\n%s\t0\t%s\t-\t-\n' "$HA.tar.zst" "$(unit_doc $HA $T pass)" "$HB.tar.zst" "$(unit_doc $HB $T pass)" >> "$C/fx/jobs"
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    get_artifact $HA
    echo "spawn_all limit=4"; fetch_job $HA
    echo "spawn_all limit=4"; probe_job $T $HA
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt2 "{\"rows\":[$(row $HA $T pass)],\"sweep\":$(SWEEPT 8)}"
    printf '%s\n' "$GET_SWEEPS"
    get_artifact $HB
    echo "spawn_all limit=4"; fetch_job $HB
    echo "spawn_all limit=4"; probe_job $T $HB
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt3 "{\"rows\":[$(row $HA $T pass),$(row $HB $T pass)],\"sweep\":$(SWEEPT 9)}"
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: new" "sweep $T: 1 of 3 members to probe" "probe $HA on $T: pass" "sweep $T: not complete (422), reading the work list again" "sweep $T: 1 of 3 members to probe" "probe $HB on $T: pass" "posted $T: 2 rows, sweep up to 9" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b14: the second post is 422 too: no third post. The run goes on with the next operand (a done nightly). Exit 1 at the end.
T3=nightly-2026-10-30-ddddddd
newcase b14-sweep-incomplete-twice 'R-MX9 R-MX4 R-MX18 (slice 223, Q572, Q573): as b13, but the second post is 422 too: at most 2 sweep requests for a tag, no third post, a warning. The run goes on with the second operand (nightly-2026-10-30-ddddddd, done: PUT and one read). The audit follows. Exit 1 at the end.'
printf '%s\n%s\n' "$T" "$T3" > "$C/fx/args"
token 1 jwt1; token 2 jwt2; token 3 jwt3; token 4 jwt4
put_route_t $T 201 jwt1; put_route_t $T3 200 jwt4
sweeps_route_t $T "$(work_body 8 3 "\"$HA\"" null)"
f=$C/fx/http/$H9/v1/sweeps/$T.2
w "$f" "$(work_body 9 3 "\"$HA\",\"$HB\"" null)"
printf '%s\n' 'status 200' 'header Content-Type: application/json' 'header Cache-Control: no-store' 'require user-agent: tln/0.0.1' 'require cache-control: no-cache' 'require-none authorization' > "$f.meta"
sweeps_route_t $T3 "$(work_body 8 3 "" "$(sweep_row $T3 8)")"
artifact $HA; artifact $HB
audit_route '{"pairs":[]}'
route compat.POST 422 "$(problem sweep-incomplete 422)" 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
route compat.POST.2 422 "$(problem sweep-incomplete 422)" 'require authorization: Bearer jwt3' "${WRITE_REQ[@]}"
printf '%s\n' "# the download, then one rule for each hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\t-\n%s\t0\t%s\t-\t-\n' "$HA.tar.zst" "$(unit_doc $HA $T pass)" "$HB.tar.zst" "$(unit_doc $HB $T pass)" >> "$C/fx/jobs"
{
    printf '%s\n' args env_all "$TOKEN_REQ"; putlines_t $T jwt1; get_sweeps_t $T
    get_artifact $HA
    echo "spawn_all limit=4"; fetch_job $HA
    echo "spawn_all limit=4"; probe_job $T $HA
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt2 "{\"rows\":[$(row $HA $T pass)],\"sweep\":$(SWEEPT 8)}"
    get_sweeps_t $T
    get_artifact $HB
    echo "spawn_all limit=4"; fetch_job $HB
    echo "spawn_all limit=4"; probe_job $T $HB
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt3 "{\"rows\":[$(row $HA $T pass),$(row $HB $T pass)],\"sweep\":$(SWEEPT 9)}"
    printf '%s\n' "$TOKEN_REQ"; putlines_t $T3 jwt4; get_sweeps_t $T3
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 1
printf '%s\n' "put $T: new" "sweep $T: 1 of 3 members to probe" "probe $HA on $T: pass" "sweep $T: not complete (422), reading the work list again" "sweep $T: 1 of 3 members to probe" "probe $HB on $T: pass" "put $T3: known" "sweep $T3: done" "audit: 0 pairs" > "$C/expect/stdout"
printf '%s\n' "warning: no sweep for $T: the registry answered 422 sweep-incomplete after 2 sweep requests" "tln: error[internal]: no sweep for $T" > "$C/expect/stderr"

# --- b15: the work list is done (bound 8, log size 8, nothing missing): no post, no second token, `sweep <tag>: done`.
newcase b15-done 'R-MX4 R-MX18 R-AP39 (slice 223, Q572): the sweep row has the bound 8 and the log size is 8, and nothing is missing: the line `sweep <tag>: done`, no token and no post after the read. The audit follows.'
token 1 jwt1
put_route 200
sweeps_route "$(work_body 8 3 "" "$(sweep_row $T 8)")"
audit_route '{"pairs":[]}'
{ printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS" "$GET_AUDIT"; } > "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: known" "sweep $T: done" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b16: 501 missing hashes: 501 rows, 2 posts: the first has 500 rows and no sweep, the second has 1 row and the sweep. A token for each post.
newcase b16-chunks 'R-AP46 R-MX4 R-MX18 R-AP10 (slice 223, Q572): 501 missing hashes (log size 8, members 501), all pass. 2 posts: 500 rows and no sweep, then 1 row and the sweep up to 8 (a new token for each). The hashes are the 41 first characters of a real hash and 3 digits.'
token 1 jwt1; token 2 jwt2; token 3 jwt3
put_route 201
hashes=()
for i in $(seq 0 500); do
    a=$((i / 81 % 9 + 1)); b=$((i / 9 % 9 + 1)); c=$((i % 9 + 1))
    hashes+=("${HA:0:41}$a$b$c")
done
missing=$(printf '"%s",' "${hashes[@]}"); missing=${missing%,}
sweeps_route "$(work_body 8 501 "$missing" null)"
audit_route '{"pairs":[]}'
route compat.POST 201 '{"written":500}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
route compat.POST.2 201 '{"written":1}' 'require authorization: Bearer jwt3' "${WRITE_REQ[@]}"
printf '%s\n' "# the download, then one rule for each hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n' >> "$C/fx/jobs"
for h in "${hashes[@]}"; do
    artifact "$h"
    printf '%s\t0\t%s\t-\t-\n' "$h.tar.zst" "$(unit_doc "$h" $T pass)" >> "$C/fx/jobs"
done
rows=""
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    for h in "${hashes[@]}"; do get_artifact "$h"; done
    echo "spawn_all limit=4"; for h in "${hashes[@]}"; do fetch_job "$h"; done
    echo "spawn_all limit=4"; for h in "${hashes[@]}"; do probe_job $T "$h"; done
    printf '%s\n' "$TOKEN_REQ"
    first=$(for h in "${hashes[@]:0:500}"; do row "$h" $T pass; done | paste -sd, -)
    post_lines jwt2 "{\"rows\":[$first]}"
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt3 "{\"rows\":[$(row "${hashes[500]}" $T pass)],\"sweep\":$(SWEEPT 8)}"
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 0
{
    echo "put $T: new"; echo "sweep $T: 501 of 501 members to probe"
    for h in "${hashes[@]}"; do echo "probe $h on $T: pass"; done
    echo "posted $T: 500 rows, no sweep"; echo "posted $T: 1 row, sweep up to 8"; echo "audit: 0 pairs"
} > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b19, b20: TALON_REGISTRY is `direct` or empty: exit 2, no request.
newcase b19-registry-direct 'R-MX18 R-EC2 R-RG7 (slice 223, Q576): TALON_REGISTRY is direct: exit 2, no request.'
printf '%s\n' 'HOME={w}/home' 'RUNNER_TEMP={w}/home/tmp' 'TALON_REGISTRY=direct' 'ACTIONS_ID_TOKEN_REQUEST_URL=http://127.0.0.1:8/token?api-version=2.0' 'ACTIONS_ID_TOKEN_REQUEST_TOKEN=req1' > "$C/fx/env"
printf '%s\n' args env_all > "$C/expect/calls.log"
w "$C/expect/exit" 2
: > "$C/expect/stdout"
w "$C/expect/stderr" 'tln: error[usage]: the compat bot needs a registry, and TALON_REGISTRY is direct. Set TALON_REGISTRY to the base URL of the registry.'
newcase b20-registry-empty 'R-MX18 R-EC2 R-RG7 (slice 223, Q576): TALON_REGISTRY is empty: exit 2, no request.'
printf '%s\n' 'HOME={w}/home' 'RUNNER_TEMP={w}/home/tmp' 'TALON_REGISTRY=' 'ACTIONS_ID_TOKEN_REQUEST_URL=http://127.0.0.1:8/token?api-version=2.0' 'ACTIONS_ID_TOKEN_REQUEST_TOKEN=req1' > "$C/fx/env"
printf '%s\n' args env_all > "$C/expect/calls.log"
w "$C/expect/exit" 2
: > "$C/expect/stdout"
w "$C/expect/stderr" 'tln: error[usage]: the compat bot needs a registry, and TALON_REGISTRY is not set or is empty. Set TALON_REGISTRY to the base URL of the registry.'

# --- b21: the registry text is not in the base URL form (upper case, the default port, a trailing /): the calls go to the base URL form (R-RG7 row 3), and the audience is that form.
newcase b21-registry-path 'R-MX18 R-TP17 R-RG7 (slice 223, Q576, dispute D1): TALON_REGISTRY=HTTPS://Reg.Example:443/ is read as the base URL form (R-RG7 row 3): the calls go to https://reg.example/v1/..., and the token request has audience=https%3A%2F%2Freg.example. As b2, exit 0. A registry with a path (https://reg.example/api/) is a bad form (R-RG7 rows 2 and 6): exit 2 with no request, as b19 and b20.'
rm -rf "$C/fx/http/$H9"
mkdir -p "$C/fx/http/reg.example"
cp -a "$OUT/b2-sweep-only/fx/http/$H9/v1" "$C/fx/http/reg.example/v1"
printf '%s\n' 'HOME={w}/home' 'RUNNER_TEMP={w}/home/tmp' 'TALON_REGISTRY=HTTPS://Reg.Example:443/' 'ACTIONS_ID_TOKEN_REQUEST_URL=http://127.0.0.1:8/token?api-version=2.0' 'ACTIONS_ID_TOKEN_REQUEST_TOKEN=req1' > "$C/fx/env"
token 1 jwt1; token 2 jwt2
sed -e 's#http://127.0.0.1:9/v1#https://reg.example/v1#g' -e 's#audience=http%3A%2F%2F127.0.0.1%3A9#audience=https%3A%2F%2Freg.example#g' "$OUT/b2-sweep-only/expect/calls.log" > "$C/expect/calls.log"
cp "$OUT/b2-sweep-only/expect/stdout" "$C/expect/stdout"
w "$C/expect/exit" 0
: > "$C/expect/stderr"
# ---------------------------------------------------------------- round 4 (Design Q594 to Q596, Registry R-MX18 item 14)
RETRY_TXT="The bot stops, and the next run starts again."
# fail_route <route under v1> <n> <status or timeout> <type>: the n-th answer of a read: a problem answer, or a timeout.
read_answer() {
    local f=$C/fx/http/$H9/v1/$1; [ "$2" = 1 ] || f=$f.$2
    mkdir -p "$(dirname "$f")"
    if [ "$3" = timeout ]; then : > "$f"; printf '%s\n' 'error timeout' > "$f.meta"
    else problem "$4" "$3" > "$f"; printf '%s\n' "status $3" 'header Content-Type: application/json' 'header Cache-Control: no-store' > "$f.meta"; fi
}

# --- b22: the work list read gets 503 busy, then 200: one sleep of 2000 ms, the run goes on (R-AP34 for a read).
newcase b22-read-retry 'R-AP34 R-AP39 R-MX18 (slice 223, Q594): as b2, but the first GET /v1/sweeps/<tag> answers 503 /errors/busy: sleep 2000 and the same read, then 200 and the run goes on (the sweep alone, as b2).'
token 1 jwt1; token 2 jwt2
put_route 200
read_answer "sweeps/$T" 1 503 busy
route "sweeps/$T.2" 200 "$(sweep_body "")" 'require user-agent: tln/0.0.1' 'require cache-control: no-cache' 'require-none authorization'
audit_route '{"pairs":[]}'
route compat.POST 200 '{"written":0}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS" "sleep 2000" "$GET_SWEEPS" "$TOKEN_REQ"
    post_lines jwt2 "$B2BODY"
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: known" "sweep $T: 0 of 3 members to probe" "posted $T: 0 rows, sweep up to 8" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"

# --- b23: the work list read gets no answer 4 times: the sleeps 2000, 8000, 30000, then exit 15 with the text of Bot.failure for the step `get sweeps <tag>`.
newcase b23-read-no-answer 'R-AP34 R-AP39 R-MX18 R-E6 (slice 223, Q594, Q573): GET /v1/sweeps/<tag> times out 4 times: sleeps 2000, 8000, 30000 and exit 15. No post.'
token 1 jwt1
put_route 201
for n in 1 2 3 4; do read_answer "sweeps/$T" $n timeout; done
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS" "sleep 2000" "$GET_SWEEPS" "sleep 8000" "$GET_SWEEPS" "sleep 30000" "$GET_SWEEPS"
} > "$C/expect/calls.log"
w "$C/expect/exit" 15
w "$C/expect/stdout" "put $T: new"
w "$C/expect/stderr" "tln: error[network]: the registry http://127.0.0.1:9 did not take the get sweeps $T after 4 requests (no answer). $RETRY_TXT"

# --- b24: the work list read answers 404: exit 20 at once (no retry), the rejected text with the step.
newcase b24-read-refused 'R-AP39 R-MX18 R-E6 (slice 223, Q594, Q585): GET /v1/sweeps/<tag> answers 404 not-found: exit 20, no retry, the fault text of Bot.failure for the step `get sweeps <tag>`.'
token 1 jwt1
put_route 201
read_answer "sweeps/$T" 1 404 not-found
{ printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"; } > "$C/expect/calls.log"
w "$C/expect/exit" 20
w "$C/expect/stdout" "put $T: new"
w "$C/expect/stderr" "tln: error[rejected]: the registry http://127.0.0.1:9 refused the get sweeps $T (/errors/not-found): D. The bot stops. This is a fault of the bot or of the registry data, not of the run."

# --- b25: the artifact read of one hash answers 404: a warning for that hash, no row, no sweep. The other hash is probed and rowed. Exit 1 at the end.
newcase b25-artifact-404 'R-AP2 R-MX4 R-MX18 (slice 223, Q595): 2 missing hashes. GET /v1/artifacts/<first> answers 404 (not indexed): a warning, no row. The second is fetched, probed (pass) and posted with no sweep. The audit follows. Exit 1.'
token 1 jwt1; token 2 jwt2
put_route 201
sweeps_route "$(sweep_body "\"$HA\",\"$HB\"")"
read_answer "artifacts/$HA" 1 404 not-found
artifact $HB
audit_route '{"pairs":[]}'
route compat.POST 201 '{"written":1}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
printf '%s\n' "# the download, then one rule for the hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\t-\n' "$HB.tar.zst" "$(unit_doc $HB $T pass)" >> "$C/fx/jobs"
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    get_artifact $HA; get_artifact $HB
    echo "spawn_all limit=4"; fetch_job $HB
    echo "spawn_all limit=4"; probe_job $T $HB
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt2 "{\"rows\":[$(row $HB $T pass)]}"
    printf '%s\n' "$GET_AUDIT"
} > "$C/expect/calls.log"
w "$C/expect/exit" 1
printf '%s\n' "put $T: new" "sweep $T: 2 of 3 members to probe" "probe $HB on $T: pass" "posted $T: 1 row, no sweep" "audit: 0 pairs" > "$C/expect/stdout"
printf '%s\n' "warning: no fact for $HA on $T: the registry did not give the artifact (404)" "tln: error[internal]: 1 probe gave no fact, so there is no sweep for $T" > "$C/expect/stderr"

# --- b26: the artifact read answers 503 4 times: exit 15 at once, no probe, no post.
newcase b26-artifact-503 'R-AP2 R-AP34 R-MX18 (slice 223, Q594, Q595): the only missing hash: GET /v1/artifacts/<hash> answers 503 busy 4 times (sleeps 2000, 8000, 30000): exit 15 at once, no job, no post, no audit read.'
token 1 jwt1
put_route 201
sweeps_route "$(sweep_body "\"$HA\"")"
for n in 1 2 3 4; do read_answer "artifacts/$HA" $n 503 busy; done
{
    printf '%s\n' args env_all "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    get_artifact $HA; echo "sleep 2000"; get_artifact $HA; echo "sleep 8000"; get_artifact $HA; echo "sleep 30000"; get_artifact $HA
} > "$C/expect/calls.log"
w "$C/expect/exit" 15
printf '%s\n' "put $T: new" "sweep $T: 1 of 3 members to probe" > "$C/expect/stdout"
w "$C/expect/stderr" "tln: error[network]: the registry http://127.0.0.1:9 did not take the get artifact $HA after 4 requests (503). $RETRY_TXT"

# --- b27: no operand and the GitHub list answers 200 with 7 releases, none is a nightly tag: exit 15 with the line of item 14.
newcase b27-list-no-nightly 'R-MX18 R-MX1 (slice 223, Q596): no operand. The GitHub list has 7 releases with the tags v1.0 to v1.6: no nightly tag, so exit 15 with the line `has no nightly tag (7 releases read)`, no other request.'
: > "$C/fx/args"
mkdir -p "$C/fx/http/$GH"
f=$C/fx/http/$GH/releases%3Fper_page=7
w "$f" "[$(for i in 0 1 2 3 4 5 6; do gh_item "v1.$i"; done | paste -sd, -)]"
printf '%s\n' 'status 200' 'header Content-Type: application/json' 'require user-agent: tln/0.0.1' 'require-none authorization' > "$f.meta"
printf '%s\n' args env_all "$GH_LINES" > "$C/expect/calls.log"
w "$C/expect/exit" 15
: > "$C/expect/stdout"
w "$C/expect/stderr" "tln: error[network]: the list of nightlies at api.github.com has no nightly tag (7 releases read). $RETRY_TXT"

# --- Slice 229 (Design Q606): the stats of the probes. The stats are on when COMPAT_STATS_DIR is set (a proposal): the cases b1 to b27 do not set it and are not changed. The stats dir is {w}/home/stats (the file tree
# compare leaves out the dir `tmp`, so RUNNER_TEMP could not hold it). The time files are in RUNNER_TEMP: the fake job writes each one with `copy:` from fx/times/<hash> (no rule copy: no time file).
STATS_PROBES='run,time,nightly,hash,repo,target,result,wall_ms,cpu_ms,rss_kb'
STATS_RUNS='run,time,tags,probes,no_stats,wall_ms,cpu_ms,rss_kb'
NOW=2026-10-15T12:00:00Z
statsenv() { printf '%s\n' 'COMPAT_STATS_DIR={w}/home/stats' 'GITHUB_RUN_ID=9001' >> "$C/fx/env"; }
# timefile <hash> <text>: the GNU time file of the fake probe of that hash.
timefile() { mkdir -p "$C/fx/times"; printf '%s' "$2" > "$C/fx/times/$1"; }
# timed_probe_job <tag> <hash>: the log line of a probe job under GNU time.
timed_probe_job() { echo "  job - /usr/bin/time -f %e %U %S %M -o \$HOME/tmp/$2.time env ROC_TOOLCHAIN=$1 tln probe --json --yes \$HOME/tmp/$2.tar.zst"; }
# stats_tree <probe csv text> <run csv text>: the expected `tree.diff` of the 2 new files (diff -rNu, sorted by name).
stats_tree() {
    local f text n
    for f in 2026-10.csv runs.csv; do
        if [ $f = runs.csv ]; then text=$2; else text=$1; fi
        n=$(printf '%s\n' "$text" | wc -l)
        printf '%s\n' "--- home/stats/$f" "+++ home/stats/$f" "@@ -0,0 +1,$n @@"
        printf '%s\n' "$text" | sed 's/^/+/'
    done
}
# stats_calls_tail: the last call of a run with stats.
STATS_WRITE='write_atomic $HOME/stats/2026-10.csv $HOME/stats/runs.csv'

# --- b28: stats on. 2 missing hashes as b1 (pass and fail). The probe jobs run under GNU time (the job text is changed, not the probe), after the probes ONE read of the 2 time files, the rows go to the registry as in b1
# (the stats never change a post), and at the end ONE write of the monthly file and the runs file. `clock` is called once, after `env_all`. The repo is the `repo` of the release of the artifact answer.
newcase b28-stats 'Q606 R-MX18 R-MX15 R-MX1 R-MX17 R-OUT2 (slice 229): as b1 with COMPAT_STATS_DIR and GITHUB_RUN_ID=9001. The probe jobs run under /usr/bin/time (the file is RUNNER_TEMP/<hash>.time), one read_files of the 2 time files after the probe batch, the post is the same as b1, one write_atomic of <stats dir>/2026-10.csv and <stats dir>/runs.csv at the end. The run time is the clock of the start. Exit 0, the same stdout as b1.'
statsenv
token 1 jwt1; token 2 jwt2
put_route 201
sweeps_route "$(sweep_body "\"$HA\",\"$HB\"")"
artifact $HA; artifact $HB
audit_route '{"pairs":[]}'
route compat.POST 201 '{"written":2}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
timefile $HA '12.34 5.67 0.89 123456
'
timefile $HB '3.00 1.00 0.50 2048
'
printf '%s\n' "# the download, then one rule for each hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\tcopy:{w}/home/tmp/%s.time={w}/fx/times/%s\n%s\t0\t%s\t-\tcopy:{w}/home/tmp/%s.time={w}/fx/times/%s\n' "$HA.tar.zst" "$(unit_doc $HA $T pass)" $HA $HA "$HB.tar.zst" "$(unit_doc $HB $T fail)" $HB $HB >> "$C/fx/jobs"
{
    printf '%s\n' args env_all clock "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    get_artifact $HA; get_artifact $HB
    echo "spawn_all limit=4"; fetch_job $HA; fetch_job $HB
    echo "spawn_all limit=4"; timed_probe_job $T $HA; timed_probe_job $T $HB
    echo "read_files \$HOME/tmp/$HA.time \$HOME/tmp/$HB.time"
    printf '%s\n' "$TOKEN_REQ"
} > "$C/expect/calls.log"
post_lines jwt2 "{\"rows\":[$(row $HA $T pass),$(row $HB $T fail)],\"sweep\":{\"nightly\":\"$T\",\"target\":\"any\",\"upto_log_index\":8}}" >> "$C/expect/calls.log"
printf '%s\n' "$GET_AUDIT" "$STATS_WRITE" >> "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: new" "sweep $T: 2 of 3 members to probe" "probe $HA on $T: pass" "probe $HB on $T: fail" "posted $T: 2 rows, sweep up to 8" "audit: 0 pairs" > "$C/expect/stdout"
: > "$C/expect/stderr"
stats_tree "$STATS_PROBES
9001,$NOW,$T,$HA,acme/json,any,pass,12340,6560,123456
9001,$NOW,$T,$HB,acme/json,any,fail,3000,1500,2048" "$STATS_RUNS
9001,$NOW,1,2,0,15340,8060,123456" > "$C/expect/tree.diff"

# --- b29: stats on, the time output is bad. The probe of HA left no time file (read_files gives NotFound), the file of HB has text that is not GNU time output. Both rows go to the registry and the sweep is complete (no
# change of exit 0), each stats row has 3 empty numbers, the run row counts 2 probes and 2 no_stats, and each hash gets one warning on stderr. A bad time output never stops the run.
newcase b29-stats-bad-time 'Q606 R-MX18 R-MX4 R-OUT2 (slice 229): as b28, but no time file for the first hash and a text that is not GNU time output for the second. The rows and the sweep are posted as in b28 and the exit is 0. The stats rows have empty wall_ms, cpu_ms and rss_kb. The run row has probes 2 and no_stats 2 and sums 0. One warning for each hash on stderr (proposal text).'
statsenv
token 1 jwt1; token 2 jwt2
put_route 201
sweeps_route "$(sweep_body "\"$HA\",\"$HB\"")"
artifact $HA; artifact $HB
audit_route '{"pairs":[]}'
route compat.POST 201 '{"written":2}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
timefile $HB 'not a time text
'
printf '%s\n' "# the download, then one rule for each hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\t-\n%s\t0\t%s\t-\tcopy:{w}/home/tmp/%s.time={w}/fx/times/%s\n' "$HA.tar.zst" "$(unit_doc $HA $T pass)" "$HB.tar.zst" "$(unit_doc $HB $T fail)" $HB $HB >> "$C/fx/jobs"
{
    printf '%s\n' args env_all clock "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS"
    get_artifact $HA; get_artifact $HB
    echo "spawn_all limit=4"; fetch_job $HA; fetch_job $HB
    echo "spawn_all limit=4"; timed_probe_job $T $HA; timed_probe_job $T $HB
    echo "read_files \$HOME/tmp/$HA.time \$HOME/tmp/$HB.time"
    printf '%s\n' "$TOKEN_REQ"
} > "$C/expect/calls.log"
post_lines jwt2 "{\"rows\":[$(row $HA $T pass),$(row $HB $T fail)],\"sweep\":{\"nightly\":\"$T\",\"target\":\"any\",\"upto_log_index\":8}}" >> "$C/expect/calls.log"
printf '%s\n' "$GET_AUDIT" "$STATS_WRITE" >> "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: new" "sweep $T: 2 of 3 members to probe" "probe $HA on $T: pass" "probe $HB on $T: fail" "posted $T: 2 rows, sweep up to 8" "audit: 0 pairs" > "$C/expect/stdout"
printf '%s\n' "warning: no time stats for $HA on $T" "warning: no time stats for $HB on $T" > "$C/expect/stderr"
stats_tree "$STATS_PROBES
9001,$NOW,$T,$HA,acme/json,any,pass,,,
9001,$NOW,$T,$HB,acme/json,any,fail,,," "$STATS_RUNS
9001,$NOW,1,2,2,0,0,0" > "$C/expect/tree.diff"

# --- b30: stats on, an audit probe. Nothing missing for the tag (as b2) and one unit pair of the older nightly N2 in the audit (as b3, one hash). The audit probe runs under GNU time on ROC_TOOLCHAIN=N2, its stats row has the
# nightly N2 and the run row counts it (tags 1: the audit is not a tag; probes 1). The calls of the audit part have the same order as b3, with the time read after the probe batch.
newcase b30-stats-audit 'Q606 R-MX13 R-MX10 R-MX18 R-OUT2 (slice 229): the tag has nothing missing (post with the sweep only, as b2). The audit has one unit pair of the nightly nightly-2026-10-20-bbbbbbb: the probe under /usr/bin/time, one read_files of its time file, a post with the row and no sweep, then the one write_atomic. The stats row has the nightly of the audit group. The run row: tags 1, probes 1.'
statsenv
token 1 jwt1; token 2 jwt2; token 3 jwt3
put_route 200
sweeps_route "$(sweep_body "")"
artifact $HC
audit_route "{\"pairs\":[{\"crash_count\":0,\"fail_count\":1,\"hash\":\"$HC\",\"nightly\":\"$N2\",\"pass_count\":5,\"target\":\"any\"}]}"
route compat.POST 200 '{"written":0}' 'require authorization: Bearer jwt2' "${WRITE_REQ[@]}"
route compat.POST.2 201 '{"written":1}' 'require authorization: Bearer jwt3' "${WRITE_REQ[@]}"
timefile $HC '1.50 1.00 0.25 4096
'
printf '%s\n' "# the download, then one rule for the hash" > "$C/fx/jobs"
printf 'curl\t0\t-\t-\t-\n%s\t0\t%s\t-\tcopy:{w}/home/tmp/%s.time={w}/fx/times/%s\n' "$HC.tar.zst" "$(unit_doc $HC $N2 pass)" $HC $HC >> "$C/fx/jobs"
{
    printf '%s\n' args env_all clock "$TOKEN_REQ" "$PUTLINES" "$GET_SWEEPS" "$TOKEN_REQ"
    post_lines jwt2 "{\"rows\":[],\"sweep\":{\"nightly\":\"$T\",\"target\":\"any\",\"upto_log_index\":8}}"
    printf '%s\n' "$GET_AUDIT"
    get_artifact $HC
    echo "spawn_all limit=4"; fetch_job $HC
    echo "spawn_all limit=4"; timed_probe_job $N2 $HC
    echo "read_files \$HOME/tmp/$HC.time"
    printf '%s\n' "$TOKEN_REQ"
    post_lines jwt3 "{\"rows\":[$(row $HC $N2 pass)]}"
    printf '%s\n' "$STATS_WRITE"
} > "$C/expect/calls.log"
w "$C/expect/exit" 0
printf '%s\n' "put $T: known" "sweep $T: 0 of 3 members to probe" "posted $T: 0 rows, sweep up to 8" "audit: 1 pair" "probe $HC on $N2: pass" "posted audit $N2: 1 row" > "$C/expect/stdout"
: > "$C/expect/stderr"
stats_tree "$STATS_PROBES
9001,$NOW,$N2,$HC,acme/json,any,pass,1500,1250,4096" "$STATS_RUNS
9001,$NOW,1,1,0,1500,1250,4096" > "$C/expect/tree.diff"

# --- b31 and b32 (slice 229, answers Q-B and Q-C) are not made here: they were made by hand from the committed cases b5-no-fact (b31: COMPAT_STATS_DIR, GITHUB_RUN_ID, time files, the clock, the timed jobs, read_files, write_atomic, the 2 files in tree.diff)
# and b28-stats with the 401 routes of b12-renew-twice (b32: exit 20 after the probes, stats still written). Re-running this script removes them: copy them first.

find "$OUT" -type f | wc -l | sed 's/^/files: /'
echo "made 30 cases in $OUT"
