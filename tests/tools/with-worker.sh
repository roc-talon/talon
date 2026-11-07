#!/bin/sh
# Runs a command with the real registry Worker next to it (slice 224, the contract run). Used by tests/run.sh for a case with the tag `worker`, when L3W_DIR is set (step l3w of scripts/test.sh).
# Usage: with-worker.sh <case work dir> <case dir> <build dir> <node> <command> [args ...]
# The server (worker/tests/serve.mjs) runs in the same process tree, so in the network namespace of the case, as with-http.sh. It listens on 127.0.0.1:$L3W_PORT
# (default 8787): a fixed port, because the registry origin is part of the cache path of tln (R-IX1). The namespace of each case has its own loopback, so cases at the
# same time do not share the port (without bwrap, the step runs one case at a time). The command sees:
#   TALON_REGISTRY   http://127.0.0.1:<port>   (CLI 1, R-RG1, R-RG7 row 1)
#   TALON_WORKER     the same URL, for a cmd line that names the origin (`--registry $TALON_WORKER`)
# After the command: a line in `<work dir>/worker.errs` (a GitHub request of the Worker with no route, a fault of the server) is printed to stderr as `worker: <text>`, and the exit code is 98.
# Else the exit code is the exit code of the command. The server stops at the end, also on a kill (TERM) of this script.
W=$1 CASE=$2 BUILD=$3 NODE=$4
shift 4
HERE=$(cd "$(dirname "$0")" && pwd)
PORT=${L3W_PORT:-8787}
rm -f "$W/worker.url" "$W/worker.log" "$W/worker-github.log" "$W/worker.errs"
mkdir -p "$W/worker-tmp"
TMPDIR=$W/worker-tmp W2_DIR=$BUILD "$NODE" "$HERE/../../worker/tests/serve.mjs" "$CASE/worker" "$W" "$PORT" > "$W/worker.out" 2>&1 &
SRV=$!
trap 'kill $SRV 2> /dev/null; exit 143' TERM INT
n=0
while [ ! -s "$W/worker.url" ]; do
    n=$((n + 1))
    if [ $n -gt 600 ] || ! kill -0 $SRV 2> /dev/null; then
        echo "worker: the server did not start in 30 s:" >&2
        cat "$W/worker.errs" "$W/worker.out" 2> /dev/null | head -n 20 >&2
        kill $SRV 2> /dev/null
        exit 97
    fi
    sleep 0.05
done
TALON_REGISTRY=$(cat "$W/worker.url")
TALON_WORKER=$TALON_REGISTRY
export TALON_REGISTRY TALON_WORKER
"$@"
rc=$?
kill $SRV 2> /dev/null
wait $SRV 2> /dev/null
if [ -s "$W/worker.errs" ]; then
    sed -e 's/^/worker: /' "$W/worker.errs" >&2
    rc=98
fi
exit $rc
