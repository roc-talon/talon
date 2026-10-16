#!/bin/sh
# Checks the GitHub device flow of the OAuth App "Talon" (Registry 6.1, R-CT8).
# Usage: research/oauth-device-flow/check.sh [client_id]
# Prints the user code, waits for a person to approve it at github.com/login/device,
# then reads GET /user with the token. It never prints the token, and it keeps it only in a variable.
set -eu
CLIENT_ID=${1:-Ov23li2sxWgMaAvjaUbQ}
json() { sed -n "s/.*\"$1\": *\"\{0,1\}\([^\",}]*\).*/\1/p"; }

code=$(curl -fsS -X POST https://github.com/login/device/code -H "Accept: application/json" -d "client_id=$CLIENT_ID")
device_code=$(echo "$code" | json device_code)
interval=$(echo "$code" | json interval)
expires=$(echo "$code" | json expires_in)
echo "user_code: $(echo "$code" | json user_code)"
echo "open:      $(echo "$code" | json verification_uri)"
echo "expires in ${expires}s, poll every ${interval}s"

waited=0
while [ "$waited" -lt "$expires" ]; do
  sleep "$interval"; waited=$((waited + interval))
  answer=$(curl -fsS -X POST https://github.com/login/oauth/access_token -H "Accept: application/json" \
    -d "client_id=$CLIENT_ID&device_code=$device_code&grant_type=urn:ietf:params:oauth:grant-type:device_code")
  token=$(echo "$answer" | json access_token)
  if [ -n "$token" ]; then
    echo "token: received (type $(echo "$answer" | json token_type), scope '$(echo "$answer" | json scope)')"
    headers=$(curl -fsS -D - -o /tmp/oauth-user.$$ -H "Authorization: Bearer $token" https://api.github.com/user)
    echo "GET /user: id $(json id < /tmp/oauth-user.$$), login $(json login < /tmp/oauth-user.$$)"
    echo "$headers" | grep -i '^x-oauth-scopes:' || echo "x-oauth-scopes: (no header)"
    rm -f /tmp/oauth-user.$$
    exit 0
  fi
  err=$(echo "$answer" | json error)
  case "$err" in
    authorization_pending) ;;
    slow_down) interval=$((interval + 5)) ;;
    *) echo "error: $err"; exit 1 ;;
  esac
done
echo "error: the code expired"; exit 1
