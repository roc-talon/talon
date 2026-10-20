#!/bin/sh
# Runs a command with the fake HTTP server (tests/tools/fakehttp.py) next to it. Used by tests/run.sh for a case that has `given/http/`.
# Usage: with-http.sh <case work dir> <fixtures dir> <command> [args ...]
# The server runs in the same process tree (and so in the same network namespace) as the command, because the case has no network
# except the loopback of its own namespace. The routes are `<work dir>/http`. The server writes `http.port`, `http.log` and
# `http.maxconn` in the work dir. The command sees:
#   TALON_HTTP         http://127.0.0.1:<port>
#   TALON_GITHUB_API   $TALON_HTTP/api   (CLI 1, R-EV14, R-EV19)
#   TALON_GITHUB_RAW   $TALON_HTTP/raw   (CLI 1, R-EV15, R-EV20)
#   TALON_TEST_FIXTURES  the fixtures dir (tests/fixtures)
# The exit code is the exit code of the command. The server stops at the end, also on a kill (TERM) of this script.
W=$1 FIX=$2
shift 2
HERE=$(cd "$(dirname "$0")" && pwd)
rm -f "$W/http.port" "$W/http.log" "$W/http.maxconn"
python3 -I "$HERE/fakehttp.py" "$W/http" "$FIX" "$W" &
SRV=$!
trap 'kill $SRV 2> /dev/null; exit 143' TERM INT
n=0
while [ ! -s "$W/http.port" ]; do
    n=$((n + 1))
    if [ $n -gt 200 ]; then echo "fake http server: no port after 10 s" >&2; kill $SRV 2> /dev/null; exit 97; fi
    sleep 0.05
done
PORT=$(cat "$W/http.port")
TALON_HTTP=http://127.0.0.1:$PORT
TALON_GITHUB_API=$TALON_HTTP/api
TALON_GITHUB_RAW=$TALON_HTTP/raw
TALON_TEST_FIXTURES=$FIX
export TALON_HTTP TALON_GITHUB_API TALON_GITHUB_RAW TALON_TEST_FIXTURES
"$@"
rc=$?
kill $SRV 2> /dev/null
wait $SRV 2> /dev/null
exit $rc
