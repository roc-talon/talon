#!/bin/bash
# R-PU25 / G14: can an installation token of the GitHub App "Talon Indexer" read public
# repositories that are NOT in the installation?
# Usage:
#   check.sh [owner/repo ...]       the real check; writes RESULT.md. Exit 0: all reads pass, 1: a read fails, 2: setup fault.
#   check.sh --selftest             tests the JWT code with a throwaway key (no network, no App).
#   check.sh --try-with-gh-token    dry run of the read code with the token of `gh` (not the App). Prints the table, writes no RESULT.md.
# Needs: bash, curl, openssl, jq. The App keys are in ~/.config/talon-indexer/ (made by create.sh).
# The token is never printed. It is only in a variable and in a mode 600 header file.
set -uo pipefail

CONF=${TALON_INDEXER_DIR:-$HOME/.config/talon-indexer}
HERE=$(cd "$(dirname "$0")" && pwd)
API=https://api.github.com
ORG=roc-talon

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# make_jwt <app id> <pem file>: RS256, iat now-60, exp now+540, iss the app id
make_jwt() {
  local now h p s
  now=$(date +%s)
  h=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
  p=$(printf '{"iat":%d,"exp":%d,"iss":%d}' $((now - 60)) $((now + 540)) "$1" | b64url)
  s=$(printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -sign "$2" -binary | b64url) || return 1
  printf '%s.%s.%s' "$h" "$p" "$s"
}

b64url_decode() { local s=$1; while [ $((${#s} % 4)) -ne 0 ]; do s="$s="; done; printf '%s' "$s" | tr '_-' '/+' | openssl base64 -d -A; }

selftest() {
  local d fail=0 jwt h p
  d=$(mktemp -d); trap 'rm -rf "$d"' RETURN
  openssl genrsa -out "$d/k.pem" 2048 2>/dev/null
  openssl rsa -in "$d/k.pem" -pubout -out "$d/k.pub" 2>/dev/null
  jwt=$(make_jwt 123456 "$d/k.pem") || { echo "FAIL: make_jwt"; return 1; }
  [ "$(printf '%s' "$jwt" | tr -cd . | wc -c)" -eq 2 ] || { echo "FAIL: not 3 parts"; fail=1; }
  case $jwt in *[+/=]*) echo "FAIL: not base64url"; fail=1;; esac
  h=$(b64url_decode "$(cut -d. -f1 <<<"$jwt")"); p=$(b64url_decode "$(cut -d. -f2 <<<"$jwt")")
  echo "header:  $h"; echo "payload: $p"
  [ "$(jq -c . <<<"$h")" = '{"alg":"RS256","typ":"JWT"}' ] || { echo "FAIL: header"; fail=1; }
  now=$(date +%s)
  jq -e --argjson n "$now" '.iss == 123456 and (.iat >= $n-62 and .iat <= $n-58) and (.exp - .iat) == 600 and (keys == ["exp","iat","iss"])' <<<"$p" >/dev/null || { echo "FAIL: payload"; fail=1; }
  cut -d. -f3 <<<"$jwt" | tr '_-' '/+' | { s=$(cat); while [ $((${#s} % 4)) -ne 0 ]; do s="$s="; done; printf '%s' "$s" | openssl base64 -d -A > "$d/sig"; }
  printf '%s' "$(cut -d. -f1,2 <<<"$jwt")" | openssl dgst -sha256 -verify "$d/k.pub" -signature "$d/sig" >/dev/null || { echo "FAIL: signature"; fail=1; }
  [ $fail -eq 0 ] && echo "selftest: OK (3 parts, base64url, header, payload, signature)"
  return $fail
}

MODE=real
case ${1:-} in
  --selftest) selftest; exit $? ;;
  --try-with-gh-token) MODE=dry; shift ;;
esac
REPOS=("$@"); [ ${#REPOS[@]} -gt 0 ] || REPOS=(roc-lang/basic-cli Karakatiza666/roc-semver)

for t in curl openssl jq; do command -v $t >/dev/null || { echo "missing tool: $t" >&2; exit 2; }; done
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; chmod 700 "$W"

# ---- request helpers. A header file keeps the token out of the process list. ----
AUTHF=$W/auth; : > "$AUTHF"; chmod 600 "$AUTHF"
setauth() { printf 'Authorization: Bearer %s\n' "$1" > "$AUTHF"; }

# req <auth: tok|jwt|none> <curl args...> <url>; sets S (status), LIM, REM, ETAG, LOC; the body is in $W/body
req() {
  local mode=$1; shift
  local acc=${ACCEPT:-application/vnd.github+json}
  local a=(); [ "$mode" = none ] || a=(-H "@$AUTHF")
  rm -f "$W/hdr" "$W/body"
  S=$(curl -sS -o "$W/body" -D "$W/hdr" -w '%{http_code}' -H "Accept: $acc" -H 'X-GitHub-Api-Version: 2022-11-28' "${a[@]}" "$@") || S=000
  LIM=$(tr -d '\r' < "$W/hdr" 2>/dev/null | grep -i '^x-ratelimit-limit:' | tail -1 | awk '{print $2}')
  REM=$(tr -d '\r' < "$W/hdr" 2>/dev/null | grep -i '^x-ratelimit-remaining:' | tail -1 | awk '{print $2}')
  ETAG=$(tr -d '\r' < "$W/hdr" 2>/dev/null | grep -i '^etag:' | tail -1 | sed 's/^[^:]*: *//')
  LOC=$(tr -d '\r' < "$W/hdr" 2>/dev/null | grep -i '^location:' | tail -1 | sed 's/^[^:]*: *//')
  : "${LIM:=-}" "${REM:=-}"
}

ROWS=$W/rows; : > "$ROWS"; FAILS=0; LAST_REM=-
# row <check> <repo> <expected status regex> <note>   (uses S LIM REM). before = LAST_REM.
row() {
  local v=PASS
  [[ $S =~ ^($3)$ ]] || { v=FAIL; FAILS=$((FAILS + 1)); }
  printf '| %s | %s | %s | %s | %s | %s | %s | %s |\n' "$1" "$2" "$S" "$LIM" "$LAST_REM" "$REM" "$v" "$4" >> "$ROWS"
  [ "$REM" = "-" ] || LAST_REM=$REM
}
# info row: no verdict that counts
inforow() { printf '| %s | %s | %s | %s | %s | %s | INFO | %s |\n' "$1" "$2" "$S" "$LIM" "$LAST_REM" "$REM" "$3" >> "$ROWS"; [ "$REM" = "-" ] || LAST_REM=$REM; }
free304() { # <check> <repo> ; compares REM with LAST_REM
  local v=FREE; [ "$S" = 304 ] || v="NOT-304"; [ "$REM" = "$LAST_REM" ] || v="COUNTS"
  printf '| %s | %s | %s | %s | %s | %s | %s | 304 is free when before = after |\n' "$1" "$2" "$S" "$LIM" "$LAST_REM" "$REM" "$v" >> "$ROWS"
  [ "$REM" = "-" ] || LAST_REM=$REM
}

NOTES=()
INSTALL_JSON=; TOKEN_JSON=
if [ $MODE = real ]; then
  [ -r "$CONF/id" ] && [ -r "$CONF/private-key.pem" ] || { echo "No App keys in $CONF. Run create.sh first." >&2; exit 2; }
  APPID=$(tr -d '\n' < "$CONF/id")
  setauth "$(make_jwt "$APPID" "$CONF/private-key.pem")" || exit 2
  req jwt "$API/app/installations?per_page=100"
  [ "$S" = 200 ] || { echo "GET /app/installations: status $S ($(jq -r .message "$W/body" 2>/dev/null))" >&2; exit 2; }
  INSTALL_JSON=$(jq -c --arg o "$ORG" '[.[] | select(.account.login == $o)][0] // empty' "$W/body")
  [ -n "$INSTALL_JSON" ] || { echo "The App is not installed on $ORG. Do step 2 (install)." >&2; exit 2; }
  IID=$(jq -r .id <<<"$INSTALL_JSON")
  req jwt -X POST "$API/app/installations/$IID/access_tokens"
  [ "$S" = 201 ] || { echo "POST access_tokens: status $S ($(jq -r .message "$W/body" 2>/dev/null))" >&2; exit 2; }
  TOKEN=$(jq -r .token "$W/body")
  TOKEN_JSON=$(jq -c 'del(.token)' "$W/body")
  setauth "$TOKEN"; unset TOKEN
  req tok "$API/installation/repositories?per_page=100"
  [ "$S" = 200 ] || { echo "GET /installation/repositories: status $S" >&2; exit 2; }
  IN_INST=$(jq -r '.repositories[].full_name' "$W/body")
else
  command -v gh >/dev/null || { echo "missing tool: gh" >&2; exit 2; }
  setauth "$(gh auth token)"; IN_INST=
fi

# ---- baseline without a token ----
req none "$API/rate_limit"; ANON_LIM=$(jq -r .resources.core.limit "$W/body" 2>/dev/null)
# ---- limit with the token (GET /rate_limit does not count) ----
req tok "$API/rate_limit"; TOK_LIM=$(jq -r .resources.core.limit "$W/body" 2>/dev/null); LAST_REM=$(jq -r .resources.core.remaining "$W/body")

for repo in "${REPOS[@]}"; do
  if grep -qixF "$repo" <<<"$IN_INST"; then
    echo "The probe repo $repo is in the installation. The check needs a repo outside it." >&2
    printf '| setup | %s | - | - | - | - | FAIL | in the installation, not a valid probe |\n' "$repo" >> "$ROWS"; FAILS=$((FAILS + 1)); continue
  fi
  # 1. the repository
  req tok "$API/repos/$repo"
  row "GET /repos/{o}/{r}" "$repo" 200 "visibility $(jq -r .visibility "$W/body" 2>/dev/null)"
  ID=$(jq -r .id "$W/body" 2>/dev/null); FULL=$(jq -r .full_name "$W/body" 2>/dev/null)
  E=$ETAG
  req tok -H "If-None-Match: $E" "$API/repos/$repo"; free304 "GET /repos/{o}/{r} + If-None-Match" "$repo"
  # 2. the release list
  req tok "$API/repos/$repo/releases?per_page=30"
  DRAFTS=$(jq '[.[] | select(.draft)] | length' "$W/body" 2>/dev/null)
  row "GET /repos/{o}/{r}/releases" "$repo" 200 "$(jq length "$W/body" 2>/dev/null) releases, drafts listed: $DRAFTS"
  [ "${DRAFTS:-0}" = 0 ] || { FAILS=$((FAILS + 1)); }
  E=$ETAG
  TAG=$(jq -r '[.[] | select(.draft|not) | select(.assets|length > 0)][0].tag_name // empty' "$W/body" 2>/dev/null)
  ASSET_ID=$(jq -r '[.[] | select(.draft|not) | select(.assets|length > 0)][0].assets | sort_by(.size)[0].id // empty' "$W/body" 2>/dev/null)
  ASSET_URL=$(jq -r '[.[] | select(.draft|not) | select(.assets|length > 0)][0].assets | sort_by(.size)[0].browser_download_url // empty' "$W/body" 2>/dev/null)
  req tok -H "If-None-Match: $E" "$API/repos/$repo/releases?per_page=30"
  free304 "GET releases + If-None-Match" "$repo"
  # 3. release by tag
  if [ -n "$TAG" ]; then
    req tok "$API/repos/$repo/releases/tags/$TAG"
    row "GET /repos/{o}/{r}/releases/tags/{tag}" "$repo" 200 "tag $TAG"
  else
    S=-; LIM=-; REM=-; row "GET releases/tags/{tag}" "$repo" 200 "no release with an asset"
  fi
  # 4. asset: browser_download_url (no token; github.com, not the API). A range keeps it small.
  if [ -n "$ASSET_URL" ]; then
    S=$(curl -sSL -r 0-99 -o /dev/null -w '%{http_code}' "$ASSET_URL") || S=000; LIM=-; REM=-
    row "asset: browser_download_url" "$repo" '200|206' "no API call"
    # 5. asset: API URL with octet-stream. Expect 302 to a signed URL; the signed URL gets no token.
    SAVE_REM=$LAST_REM
    ACCEPT=application/octet-stream req tok "$API/repos/$repo/releases/assets/$ASSET_ID"
    row "asset: API url, Accept octet-stream" "$repo" '302' "redirect to a signed URL; the remaining count of this answer can come from another counter, so it is not used"
    LAST_REM=$SAVE_REM
    if [ -n "$LOC" ]; then
      S=$(curl -sS -r 0-99 -o /dev/null -w '%{http_code}' "$LOC") || S=000; LIM=-; REM=-
      row "asset: signed URL (no token)" "$repo" '200|206' "no API call"
    fi
  else
    S=-; LIM=-; REM=-; row "asset downloads" "$repo" 200 "no release asset in the first 30 releases"
  fi
  # 6. read by id (R-PU22, R-TP9, R-PU31)
  req tok "$API/repositories/$ID"
  row "GET /repositories/{id}" "$repo" 200 "full_name $(jq -r .full_name "$W/body" 2>/dev/null), visibility $(jq -r .visibility "$W/body" 2>/dev/null)"
  [ "$(jq -r .full_name "$W/body" 2>/dev/null)" = "$FULL" ] || FAILS=$((FAILS + 1))
  E=$ETAG
  req tok -H "If-None-Match: $E" "$API/repositories/$ID"
  free304 "GET /repositories/{id} + If-None-Match" "$repo"
  # 7. file contents
  req tok "$API/repos/$repo/contents/"
  F=$(jq -r '[.[] | select(.type=="file")][0].path // empty' "$W/body" 2>/dev/null)
  row "GET /repos/{o}/{r}/contents/ (root)" "$repo" 200 "$(jq length "$W/body" 2>/dev/null) entries"
  if [ -n "$F" ]; then
    req tok "$API/repos/$repo/contents/$F"
    row "GET /repos/{o}/{r}/contents/{path}" "$repo" 200 "$F"
    ACCEPT=application/vnd.github.raw+json req tok "$API/repos/$repo/contents/$F"
    row "same, Accept raw" "$repo" 200 "$(wc -c < "$W/body") bytes"
  fi
done

# ---- write the result ----
{
  echo "# R-PU25 check: the installation token reads public repositories outside the installation"
  echo
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)  "
  echo "Mode: $([ $MODE = real ] && echo "real (installation token of the App)" || echo "DRY RUN with the token of gh, NOT the App: not evidence for R-PU25")  "
  echo "Probe repositories (not in the installation): ${REPOS[*]}  "
  if [ $MODE = real ]; then
    echo "Installation id: $(jq -r .id <<<"$INSTALL_JSON"), account $ORG, repository_selection $(jq -r .repository_selection <<<"$TOKEN_JSON")  "
    echo "Repositories in the installation: $(echo $IN_INST)  "
    echo "Permissions of the token: $(jq -c .permissions <<<"$TOKEN_JSON")  "
    echo "Events of the App: $(jq -c .events <<<"$INSTALL_JSON")  "
  fi
  echo
  echo "x-ratelimit-limit with no token: ${ANON_LIM:--} (expect 60). With the token: ${TOK_LIM:--} (expect 5000 or more)."
  echo
  echo "| Read | Repository | Status | x-ratelimit-limit | Remaining before | Remaining after | Verdict | Note |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
  cat "$ROWS"
  echo
  echo "Verdicts: PASS and FAIL are for the status. FREE: a 304 left the remaining count the same. COUNTS: a 304 used one request. INFO: not a pass or fail."
  echo
  echo "Drafts (R-PU23): the release lists above show no draft. This is trivially true for repositories where the App has no write access: GitHub shows drafts only to a reader with push access, so this check cannot test the R-PU23 claim for the installed repository roc-talon/talon. A test needs a draft release in roc-talon/talon."
  echo
  if [ $FAILS -eq 0 ]; then echo "Result: PASS. The installation token reads public repositories outside the installation. R-PU25 stands."
  else echo "Result: FAIL ($FAILS). A read failed. R-PU25 falls back to the fine-grained token of a bot account (GITHUB_READ_TOKEN)."; fi
} > "$W/result.md"

if [ $MODE = real ]; then cp "$W/result.md" "$HERE/RESULT.md"; echo "Written: $HERE/RESULT.md"; else cat "$W/result.md"; fi
[ $FAILS -eq 0 ] && { echo "PASS"; exit 0; } || { echo "FAIL: $FAILS"; exit 1; }
