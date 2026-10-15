#!/usr/bin/env bash
# TQ4: does roc fetch a package from an http:// URL?
# Bundles a small package, serves it on 127.0.0.1, and runs `roc check` on a
# package that depends on it through 5 URL forms. Own cache per case.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROC=${1:-$HERE/../../cloudflare-workers/.cache/nightlies/nightly-2026-10-09-258ab27/roc}
W=$HERE/.work
rm -rf "$W" && mkdir -p "$W/dep" "$W/srv/1.0.0" "$W/srv/greet-1.0.0"

cat > "$W/dep/main.roc" <<'R'
package [Greet] {}
R
cat > "$W/dep/Greet.roc" <<'R'
module [hello]

hello : Str
hello = "hi"
R
(cd "$W/dep" && "$ROC" bundle main.roc Greet.roc --output-dir "$W/srv/1.0.0" >/dev/null) || { echo "bundle failed"; exit 1; }
F=$(ls "$W/srv/1.0.0")
cp "$W/srv/1.0.0/$F" "$W/srv/greet-1.0.0/"
echo "bundle: $F"

PORT=${PORT:-18765}
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$W/srv" >"$W/server.log" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT
for _ in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null && break; sleep 0.1; done

run_case() { # name url
  local d=$W/case-$1
  mkdir -p "$d"
  cat > "$d/main.roc" <<R
package [Use] { dep: "$2" }
R
  cat > "$d/Use.roc" <<'R'
module [msg]

import dep.Greet

msg : Str
msg = Greet.hello
R
  local out
  out=$(cd "$d" && XDG_CACHE_HOME=$d/cache ROC_CACHE_DIR=$d/cache/roc timeout 60 "$ROC" check main.roc 2>&1)
  local code=$?
  local fetched=no
  [ -d "$d/cache/roc/packages/${F%.tar.zst}" ] && fetched=yes
  printf '%-10s exit=%-3s fetched=%-3s %s\n' "$1" "$code" "$fetched" "$2"
  echo "$out" | grep -E "error|warning|insecure|No errors" | grep -v "^──.*deprecated" | head -3 | sed 's/^/    /'
}

run_case loopback  "http://127.0.0.1:$PORT/1.0.0/$F"
run_case localhost "http://localhost:$PORT/1.0.0/$F"
# Not loopback: 10.255.255.1 is never routed here; a rejection must come before any connect.
run_case lan       "http://10.255.255.1:$PORT/1.0.0/$F"
# A tag prefix: the version is a run inside the segment (CLI 7.3, DI5).
run_case prefixed "http://127.0.0.1:$PORT/greet-1.0.0/$F"
run_case name      "http://github.com/x/y/releases/download/1.0.0/$F"
echo "server requests:"; grep -c 'GET' "$W/server.log"
