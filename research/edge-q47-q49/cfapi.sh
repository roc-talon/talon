#!/usr/bin/env bash
# Q47/Q49 edge run: one Cloudflare API call with the OAuth token of wrangler (the token is never printed).
#   ./cfapi.sh GET /workers/scripts            (path under /accounts/<account>)
#   ./cfapi.sh PUT /d1/database/<id> '{...}'
set -euo pipefail
ACC=${CLOUDFLARE_ACCOUNT_ID:?set CLOUDFLARE_ACCOUNT_ID to the account id (wrangler whoami)}
wrangler whoami >/dev/null 2>&1   # refreshes the token when it is old
TOK=$(sed -n 's/^oauth_token = "\(.*\)"$/\1/p' ~/.config/.wrangler/config/default.toml)
m=$1 p=$2; shift 2
if [ $# -gt 0 ]; then
  curl -sS -X "$m" -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' --data "$1" "https://api.cloudflare.com/client/v4/accounts/$ACC$p"
else
  curl -sS -X "$m" -H "Authorization: Bearer $TOK" "https://api.cloudflare.com/client/v4/accounts/$ACC$p"
fi
