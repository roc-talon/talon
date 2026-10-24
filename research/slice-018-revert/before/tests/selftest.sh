#!/bin/bash
# Self-test of the two case runners (TESTING.md 8, items 3 and 4): a case that must fail makes the runner
# report a failure. A case that must pass passes. Usage: tests/selftest.sh
# It builds its cases in $TMPDIR/talon-selftest. It does not build tln: a dummy `tln` is on PATH.
set -u
SELF=$(cd "$(dirname "$0")" && pwd)
. "$SELF/../scripts/env.sh"
T=${TMPDIR:-/tmp}/talon-selftest
rm -rf "$T"
mkdir -p "$T/bin"
printf '#!/bin/sh\necho dummy tln\n' > "$T/bin/tln"
chmod +x "$T/bin/tln"
pass=0 fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "SELFTEST FAIL: $*"; }

# mk <root> <area/id> <cmd text>: a new L3 case. Then `put <root> <area/id> <file> <text>` adds a file.
mk() { mkdir -p "$1/$2"; printf '%s\n' "$3" > "$1/$2/cmd"; }
put() { mkdir -p "$(dirname "$1/$2/$3")"; printf '%s' "$4" > "$1/$2/$3"; }

l3() { SCENARIOS=$1 TLN=$T/bin/tln TMPDIR=$T "$SELF/run.sh" "${@:2}" 2>&1; }

# --- L3 cases that must pass ---
P=$T/l3-pass
mk $P runner/exit-code 'exit 7'
put $P runner/exit-code expect/exit $'7\n'
mk $P runner/stdout-stderr $'echo out line\necho err line >&2'
put $P runner/stdout-stderr expect/stdout $'out line\n'
put $P runner/stdout-stderr expect/stderr $'err line\n'
# The environment is fixed: env -i, the dirs of the case, the fixed variables, and given/env.
mk $P runner/environment $'echo "$HOME $PWD"\necho "leak=${TALON_SELFTEST_LEAK:-none} CI=$CI TZ=$TZ LANG=$LANG REG=$TALON_REGISTRY EXTRA=$EXTRA"\ncase $PATH in */fakes/roc*) ;; esac\ncommand -v roc | sed -e "s#$TALON_TEST_DIR#\\$WORK#"'
put $P runner/environment given/env $'EXTRA=from-given-env\n'
put $P runner/environment expect/stdout $'$HOME $PROJECT\nleak=none CI=true TZ=UTC LANG=C.UTF-8 REG=direct EXTRA=from-given-env\n$WORK/bin/roc\n'
# The file tree: a new file, a changed file, a removed file. compat.db and tmp are left out.
mk $P runner/tree $'echo new > new.txt\necho changed > main.roc\nrm ../home/gone.txt\nmkdir -p ../home/talon/tmp\necho x > ../home/talon/tmp/t\necho x > ../home/talon/compat.db\necho x > ../home/f.tmp'
put $P runner/tree given/project/main.roc $'old\n'
put $P runner/tree given/home/gone.txt $'bye\n'
put $P runner/tree expect/tree.diff $'--- home/gone.txt\n+++ home/gone.txt\n@@ -1 +0,0 @@\n-bye\n--- project/main.roc\n+++ project/main.roc\n@@ -1 +1 @@\n-old\n+changed\n--- project/new.txt\n+++ project/new.txt\n@@ -0,0 +1 @@\n+new\n'
# The fake roc: it logs each call, answers from given/roc.tsv, and exits 99 for a call with no rule.
mk $P runner/fake-roc $'roc check main.roc\nroc build --release app.roc || echo "build exit=$?"\nroc test x.roc || echo "unknown exit=$?"'
put $P runner/fake-roc given/roc.tsv "$(printf '# pattern, exit, stdout file, stderr file\ncheck *\t0\tcheck.out\t-\nbuild *\t3\t-\tbuild.err\n')"$'\n'
put $P runner/fake-roc given/check.out $'No errors found\n'
put $P runner/fake-roc given/build.err $'build failed\n'
put $P runner/fake-roc expect/stdout $'No errors found\nbuild exit=3\nunknown exit=99\n'
put $P runner/fake-roc expect/stderr $'build failed\nfake roc: no answer for: test x.roc\n'
put $P runner/fake-roc expect/roc.log $'check main.roc\nbuild --release app.roc\ntest x.roc\n'
# tag tty: one stream, the typed text is the answers file
mk $P runner/tty $'test -t 0 && test -t 2 && echo tty\nread line\necho "got $line"'
put $P runner/tty tags $'tty\n'
put $P runner/tty given/answers $'yes\n'
put $P runner/tty expect/stdout $'tty\ngot yes\n'
# The fake HTTP server (slice 003): a route file with $PORT, a route with a query, no route (404), a status and a header from
# .meta, ETag and If-None-Match (304), a body from the fixtures, the requests in http.log, the most requests at one time.
H=given/http
mk $P runner/http $'curl -s "$TALON_HTTP/hello"; echo\ncurl -s "$TALON_HTTP/q?page=2"; echo\ncurl -s "$TALON_HTTP/q?page=3"; echo\ncurl -s -o /dev/null -w \'%{http_code}\\n\' "$TALON_HTTP/missing"\ncurl -s -i "$TALON_HTTP/teapot" | sed -n -e 1p -e \'/^X-Test/p\' | tr -d \'\\r\'\ncurl -s -o /dev/null -w \'%{http_code}\\n\' -H \'If-None-Match: "v1"\' "$TALON_HTTP/tagged"\ncurl -s -o /dev/null -w \'%{http_code}\\n\' -H \'Authorization: Bearer x\' "$TALON_HTTP/tagged"\ncurl -s "$TALON_HTTP/fixture" | cmp - "$TALON_TEST_FIXTURES/pkgs/9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17.tar.zst" && echo same\necho "$TALON_GITHUB_API $TALON_GITHUB_RAW"\ncurl -s "$TALON_HTTP/slow" > /dev/null &\ncurl -s "$TALON_HTTP/slow" > /dev/null &\nwait\ncat "$TALON_TEST_DIR/http.maxconn"'
put $P runner/http $H/hello $'say http://127.0.0.1:$PORT/x'
put $P runner/http "$H/q?page=2" $'page two'
put $P runner/http $H/q $'page any'
put $P runner/http $H/teapot.meta $'status 418\nheader X-Test: http://127.0.0.1:$PORT/n\n'
put $P runner/http $H/tagged.meta $'header ETag: "v1"\n'
put $P runner/http $H/tagged $'body'
put $P runner/http $H/fixture.meta $'body @pkgs/9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17.tar.zst\n'
put $P runner/http $H/slow.meta $'slow 400\n'
put $P runner/http $H/slow $'0123456789abcdef'
put $P runner/http expect/stdout $'say http://127.0.0.1:$PORT/x\npage two\npage any\n404\nHTTP/1.1 418 I\'m a Teapot\nX-Test: http://127.0.0.1:$PORT/n\n304\n200\nsame\nhttp://127.0.0.1:$PORT/api http://127.0.0.1:$PORT/raw\n2\n'
put $P runner/http expect/http.log $'GET /hello 200\nGET /q?page=2 200\nGET /q?page=3 200\nGET /missing 404\nGET /teapot 418\nGET /tagged 304 if-none-match="v1"\nGET /tagged 200 authorization\nGET /fixture 200\nGET /slow 200\nGET /slow 200\n'
# The fake roc with the rule `real` (slice 003): `roc unbundle` runs the pinned roc. Other calls stay fake.
G=9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17
mk $P runner/roc-real "cp $SELF/fixtures/pkgs/$G.tar.zst .
roc unbundle $G.tar.zst
ls $G | tr '\n' ' '; echo
roc build x.roc || echo \"build exit=\$?\""
put $P runner/roc-real given/roc.tsv "$(printf 'unbundle *\treal\t-\t-\n*\t0\t-\t-\n')"$'\n'
put $P runner/roc-real expect/stdout "Extracted: $G"$'\nGreet.roc main.roc \n'
put $P runner/roc-real expect/roc.log "unbundle $G.tar.zst"$'\nbuild x.roc\n'
put $P runner/roc-real expect/tree.diff "$(printf -- '--- project/%s/Greet.roc\n+++ project/%s/Greet.roc\n@@ -0,0 +1,5 @@\n+## A fixture package of the Talon tests (slice 003).\n+Greet := [].{\n+\thello : Str -> Str\n+\thello = |name| "Hello, ${name}!"\n+}\n--- project/%s/main.roc\n+++ project/%s/main.roc\n@@ -0,0 +1 @@\n+package [Greet] {}\nBinary files orig/project/%s.tar.zst and project/%s.tar.zst differ' $G $G $G $G $G $G)"$'\n'
# The network is off (bwrap --unshare-net). Only when bwrap works on this machine.
if bwrap --dev-bind / / --unshare-net true > /dev/null 2>&1; then
    mk $P runner/no-network $'python3 -I -c "import socket\ntry:\n socket.create_connection((\'1.1.1.1\', 80), timeout=2); print(\'reachable\')\nexcept OSError: print(\'no network\')"'
    put $P runner/no-network expect/stdout $'no network\n'
    want=9
else want=8; fi
# tags that the fast set skips
mk $P runner/slow 'exit 5'
put $P runner/slow tags $'slow\n'
out=$(l3 $P)
if echo "$out" | grep -q "scenarios: $want passed, 0 failed, 1 skipped"; then ok; else bad "pass cases"; echo "$out"; fi

# --- L3 cases that must fail: each one has the text that the report must show ---
# fl3 <name> <needle> <cmd> [<file> <text>]...
fl3() {
    local name=$1 needle=$2 cmd=$3 root=$T/l3-fail-$1
    shift 3
    mk "$root" "bad/$name" "$cmd"
    while [ $# -ge 2 ]; do put "$root" "bad/$name" "$1" "$2"; shift 2; done
    out=$(l3 "$root")
    if echo "$out" | grep -q "FAIL bad/$name" && echo "$out" | grep -q "$needle" && echo "$out" | grep -q '1 failed'; then ok
    else bad "l3 $name must fail with '$needle'"; echo "$out"; fi
}
fl3 exit-code 'exit code differs' 'exit 3' expect/exit $'0\n'
fl3 exit-missing 'exit code differs' 'exit 3'
fl3 stdout 'stdout differs' 'echo hi' expect/stdout $'ho\n'
fl3 stdout-extra 'stdout differs' 'echo hi'
fl3 stderr 'stderr differs' 'echo hi >&2' expect/stderr $'ho\n'
fl3 tree-extra 'file tree differs' 'echo x > new.txt' expect/tree.diff ''
fl3 tree-wrong 'file tree differs' 'echo x > new.txt' expect/tree.diff $'--- project/new.txt\n+++ project/new.txt\n@@ -0,0 +1 @@\n+y\n'
fl3 tree-missing 'file tree differs' 'true' expect/tree.diff $'--- project/new.txt\n+++ project/new.txt\n@@ -0,0 +1 @@\n+x\n'
fl3 roc-unexpected 'unexpected roc call' 'roc check main.roc' given/roc.tsv $'check *\t0\t-\t-\n'
fl3 roc-missing 'roc calls differs' 'true' expect/roc.log $'check main.roc\n'
fl3 roc-wrong-args 'roc calls differs' 'roc build a.roc' given/roc.tsv $'*\t0\t-\t-\n' expect/roc.log $'build b.roc\n'
fl3 roc-no-answer 'exit code differs' 'roc check main.roc' expect/roc.log $'check main.roc\n'
fl3 http-log 'http requests differs' 'curl -s "$TALON_HTTP/x" > /dev/null' given/http/x $'x' expect/http.log $'GET /y 200\n'
fl3 tty-no-terminal 'stdout differs' 'test -t 0 || echo no-terminal' tags $'tty\n' expect/stdout $'no-terminal\n'

# --- UPDATE=1 writes the files, and then the case passes ---
U=$T/l3-update
mk $U runner/update $'echo out; echo err >&2; echo n > new.txt; exit 4'
out=$(UPDATE=1 l3 $U)
out=$(l3 $U)
if echo "$out" | grep -q '1 passed, 0 failed' &&
    [ "$(cat $U/runner/update/expect/exit)" = 4 ] && [ "$(cat $U/runner/update/expect/stdout)" = out ] &&
    [ "$(cat $U/runner/update/expect/stderr)" = err ] && grep -q '^+n$' $U/runner/update/expect/tree.diff &&
    [ ! -e $U/runner/update/expect/roc.log ]; then ok; else bad "UPDATE=1"; echo "$out"; fi

# --- L2 runner ---
# SELFTEST_L2BIN: an L2 app that scripts/test.sh built already (the same source), so it is built once for the run.
L2APP=${SELFTEST_L2BIN:-$T/bin/l2}
if [ -z "${SELFTEST_L2BIN:-}" ]; then
    "$ROC" build "$SELF/commands/main.roc" --output="$L2APP" > "$T/build-l2.log" 2>&1 || { echo "build of the L2 app failed"; cat "$T/build-l2.log"; exit 1; }
fi
l2() { CASES=$1 L2BIN=$L2APP TMPDIR=$T "$SELF/commands/run.sh" "${@:2}" 2>&1; }
L2P=$SELF/selftest/commands/pass
out=$(l2 $L2P)
if echo "$out" | grep -q 'commands: 1 passed, 0 failed'; then ok; else bad "l2 pass case"; echo "$out"; fi
# fl2 <name> <needle> <file> <text>: copy the pass case, change one expected file, the runner must fail.
fl2() {
    local name=$1 needle=$2 root=$T/l2-fail-$1
    mkdir -p "$root/harness"
    cp -a "$L2P/harness/fake-fx" "$root/harness/$name"
    if [ "$3" = rm ]; then rm "$root/harness/$name/expect/$4"; else printf '%s' "$4" > "$root/harness/$name/expect/$3"; fi
    out=$(l2 "$root")
    if echo "$out" | grep -q "FAIL harness/$name" && echo "$out" | grep -q "$needle"; then ok
    else bad "l2 $name must fail with '$needle'"; echo "$out"; fi
}
fl2 exit 'exit code differs' exit $'0\n'
fl2 stdout 'stdout differs' stdout $'wrong\n'
fl2 stderr 'stderr differs' stderr $'wrong\n'
fl2 calls-missing 'Fx calls differs' calls.log "$(head -n -1 "$L2P/harness/fake-fx/expect/calls.log")"$'\n'
fl2 calls-order 'Fx calls differs' calls.log "$(sed -e '1{h;d}' -e '2{G}' "$L2P/harness/fake-fx/expect/calls.log")"$'\n'
fl2 tree 'file tree differs' tree.diff ''
# An entry that does not exist is a failure (the app exits 99 and writes its text).
root=$T/l2-entry; mkdir -p "$root/x/entry/fx"; echo nonsense > "$root/x/entry/entry"
out=$(l2 "$root")
if echo "$out" | grep -q 'FAIL x/entry' && echo "$out" | grep -q 'unknown entry nonsense'; then ok; else bad "l2 unknown entry"; echo "$out"; fi

rm -rf "$T"
echo "selftest: $pass passed, $fail failed"
[ $fail -eq 0 ]
