#!/bin/bash
# Self-test of the two case runners (TESTING.md 8, items 3 and 4): a case that must fail makes the runner
# report a failure. A case that must pass passes. Usage: tests/selftest.sh
# It builds its cases in $TMPDIR/talon-selftest. It does not build tln: a dummy `tln` is on PATH.
set -u
SELF=$(cd "$(dirname "$0")" && pwd)
. "$SELF/../scripts/env.sh"
# The flags of the caller must not change the rows: a merge run has OPT=speed and SLOW=1 (slice 018).
# The L2 app of a standalone run is built with the same OPT rule as the runners (default dev, TW25).
SELFTEST_OPT=${OPT:-dev}
unset OPT SLOW NET JOBS VERBOSE TAIL REAL_ROC TLN L2BIN BUILD_THREADS L0_THREADS ${!BUDGET_@}
T=${TMPDIR:-/tmp}/talon-selftest
rm -rf "$T"
mkdir -p "$T/bin"
printf '#!/bin/sh\necho dummy tln\n' > "$T/bin/tln"
chmod +x "$T/bin/tln"
# The rows run in parallel (slice 022b: the step was over its 20 s budget). `sec <name> <function and arguments>` runs a group of rows in a background subshell:
# its text goes to $RES/<name>.out, and each ok or bad adds a line to $RES/<name>.ok or <name>.bad. Each group has its own TMPDIR ($ST), so the case dirs of the runners do not meet.
# The report is at the end: the output of each group, then the count.
RES=$T/res
mkdir -p "$RES"
ST=$T
SEC=main
ok() { echo . >> "$RES/$SEC.ok"; }
bad() { echo . >> "$RES/$SEC.bad"; echo "SELFTEST FAIL: $*"; }
skip() { echo . >> "$RES/$SEC.skip"; echo "SELFTEST SKIP: $*"; }
sec() {
    local name=$1
    shift
    ( SEC=$name; ST=$T/tmp-$name; mkdir -p "$ST"; "$@" ) > "$RES/$name.out" 2>&1 &
}

# mk <root> <area/id> <cmd text>: a new L3 case. Then `put <root> <area/id> <file> <text>` adds a file.
mk() { mkdir -p "$1/$2"; printf '%s\n' "$3" > "$1/$2/cmd"; }
put() { mkdir -p "$(dirname "$1/$2/$3")"; printf '%s' "$4" > "$1/$2/$3"; }

l3() { SCENARIOS=$1 TLN=$T/bin/tln TMPDIR=$ST "$SELF/run.sh" "${@:2}" 2>&1; }

# Slice 030: a cmd text that makes `talon/compat.db` with 1 fact, 1 pinned row and the format 1 (R-TF1), as the real Fx does, with python3 (the runner dumps it with tests/tools/dumpdb.py).
MKDB='mkdir -p $HOME/.cache/roc/talon
python3 -I -c "import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute(\"CREATE TABLE facts (hash TEXT, nightly TEXT, target TEXT, outcome TEXT, modules TEXT, closure TEXT)\")
c.execute(\"INSERT INTO facts VALUES (\x27h\x27, \x27n\x27, \x27any\x27, \x27fail\x27, \x27B.roc,A.roc\x27, \x27\x27)\")
c.execute(\"CREATE TABLE pinned (tag TEXT, target TEXT, sha256 TEXT, source TEXT)\")
c.execute(\"INSERT INTO pinned VALUES (\x27t\x27, \x27x\x27, \x27s\x27, \x27registry\x27)\")
c.execute(\"PRAGMA user_version = 1\")
c.commit()" $HOME/.cache/roc/talon/compat.db'
FACTS_TSV=$'format\t1\nfact\th\tn\tany\tfail\tB.roc,A.roc\t\npinned\tt\tx\ts\tregistry\n'

s_l3_pass() {
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
mk $P runner/tree $'echo new > new.txt\necho changed > main.roc\nrm ../home/gone.txt\nmkdir -p ../home/talon/tmp\necho x > ../home/talon/tmp/t\necho x > ../home/talon/compat.db\necho x > ../home/talon/compat.db-wal\necho x > ../home/talon/compat.db-shm\necho x > ../home/f.tmp'
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
    want=13
else want=12; fi
# Slice 030: expect/facts.tsv is the dump of compat.db (tests/tools/dumpdb.py). It is compared when the file is there. An empty file means that there is no db.
mk $P runner/facts "$MKDB"
put $P runner/facts expect/facts.tsv "$FACTS_TSV"
mk $P runner/facts-none 'echo no db'
put $P runner/facts-none expect/facts.tsv ''
put $P runner/facts-none expect/stdout $'no db\n'
mk $P runner/facts-skipped "$MKDB"
# The format line is the user_version of the file, not a fixed 1.
mk $P runner/facts-v3 "$MKDB"$'\npython3 -I -c "import sqlite3, sys\nc = sqlite3.connect(sys.argv[1])\nc.execute(\\"PRAGMA user_version = 3\\")\nc.commit()" $HOME/.cache/roc/talon/compat.db'
put $P runner/facts-v3 expect/facts.tsv "${FACTS_TSV/format	1/format	3}"
# tags that the fast set skips
mk $P runner/slow 'exit 5'
put $P runner/slow tags $'slow\n'
out=$(l3 $P)
if echo "$out" | grep -q "scenarios: $want passed, 0 failed, 1 skipped"; then ok; else bad "pass cases"; echo "$out"; fi
}
sec l3_pass s_l3_pass

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
sec fl3-exit-code fl3 exit-code 'exit code differs' 'exit 3' expect/exit $'0\n'
sec fl3-exit-missing fl3 exit-missing 'exit code differs' 'exit 3'
sec fl3-stdout fl3 stdout 'stdout differs' 'echo hi' expect/stdout $'ho\n'
sec fl3-stdout-extra fl3 stdout-extra 'stdout differs' 'echo hi'
sec fl3-stderr fl3 stderr 'stderr differs' 'echo hi >&2' expect/stderr $'ho\n'
sec fl3-tree-extra fl3 tree-extra 'file tree differs' 'echo x > new.txt' expect/tree.diff ''
sec fl3-tree-wrong fl3 tree-wrong 'file tree differs' 'echo x > new.txt' expect/tree.diff $'--- project/new.txt\n+++ project/new.txt\n@@ -0,0 +1 @@\n+y\n'
sec fl3-tree-missing fl3 tree-missing 'file tree differs' 'true' expect/tree.diff $'--- project/new.txt\n+++ project/new.txt\n@@ -0,0 +1 @@\n+x\n'
sec fl3-roc-unexpected fl3 roc-unexpected 'unexpected roc call' 'roc check main.roc' given/roc.tsv $'check *\t0\t-\t-\n'
sec fl3-roc-missing fl3 roc-missing 'roc calls differs' 'true' expect/roc.log $'check main.roc\n'
sec fl3-roc-wrong-args fl3 roc-wrong-args 'roc calls differs' 'roc build a.roc' given/roc.tsv $'*\t0\t-\t-\n' expect/roc.log $'build b.roc\n'
sec fl3-roc-no-answer fl3 roc-no-answer 'exit code differs' 'roc check main.roc' expect/roc.log $'check main.roc\n'
sec fl3-http-log fl3 http-log 'http requests differs' 'curl -s "$TALON_HTTP/x" > /dev/null' given/http/x $'x' expect/http.log $'GET /y 200\n'
sec fl3-facts-differs fl3 facts-differs 'compat.db rows differs' "$MKDB" expect/facts.tsv "${FACTS_TSV/B.roc,A.roc/A.roc,B.roc}"
sec fl3-facts-extra-db fl3 facts-extra-db 'compat.db rows differs' "$MKDB" expect/facts.tsv ''
sec fl3-facts-missing-db fl3 facts-missing-db 'compat.db rows differs' 'true' expect/facts.tsv $'format\t1\n'
sec fl3-facts-format fl3 facts-format 'compat.db rows differs' "$MKDB" expect/facts.tsv "${FACTS_TSV/format	1/format	2}"
sec fl3-tty-no-terminal fl3 tty-no-terminal 'stdout differs' 'test -t 0 || echo no-terminal' tags $'tty\n' expect/stdout $'no-terminal\n'

# --- UPDATE=1 writes the files, and then the case passes ---
s_l3_update() {
U=$T/l3-update
mk $U runner/update $'echo out; echo err >&2; echo n > new.txt; exit 4'
out=$(UPDATE=1 l3 $U)
out=$(l3 $U)
if echo "$out" | grep -q '1 passed, 0 failed' &&
    [ "$(cat $U/runner/update/expect/exit)" = 4 ] && [ "$(cat $U/runner/update/expect/stdout)" = out ] &&
    [ "$(cat $U/runner/update/expect/stderr)" = err ] && grep -q '^+n$' $U/runner/update/expect/tree.diff &&
    [ ! -e $U/runner/update/expect/roc.log ]; then ok; else bad "UPDATE=1"; echo "$out"; fi
}
sec l3_update s_l3_update

# Slice 030: UPDATE=1 writes expect/facts.tsv when there is a db, and writes no file when there is none.
s_l3_update_facts() {
U=$T/l3-update-facts
mk $U runner/with-db "$MKDB"
mk $U runner/no-db 'true'
UPDATE=1 l3 $U > /dev/null
out=$(l3 $U)
if echo "$out" | grep -q '2 passed, 0 failed' && [ "$(cat $U/runner/with-db/expect/facts.tsv)" = "$(printf '%s' "$FACTS_TSV")" ] && [ ! -e $U/runner/no-db/expect/facts.tsv ]; then ok; else bad "UPDATE=1 facts.tsv"; echo "$out"; fi
}
sec l3_update_facts s_l3_update_facts

# --- L2 runner ---
# SELFTEST_L2BIN: an L2 app that scripts/test.sh built already (the same source), so it is built once for the run.
L2APP=${SELFTEST_L2BIN:-$T/bin/l2}
if [ -z "${SELFTEST_L2BIN:-}" ]; then
    "$ROC" build "$SELF/commands/main.roc" --opt="$SELFTEST_OPT" --output="$L2APP" > "$T/build-l2.log" 2>&1 || { echo "build of the L2 app failed"; cat "$T/build-l2.log"; exit 1; }
fi
l2() { CASES=$1 L2BIN=$L2APP TMPDIR=$T "$SELF/commands/run.sh" "${@:2}" 2>&1; }
L2P=$SELF/selftest/commands/pass
s_l2() {
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
}
sec l2 s_l2

# --- Slice 018: build mode, slow tag, parallel L0, step budget (TW20, TW25 to TW27) ---
# A fake roc logs each call. `build` makes a no-op binary, but only under $FAKE_ROC_OUTDIR (the work dir of the row), and fails
# when FAKE_ROC_BUILD=fail. `test` sleeps FAKE_ROC_SLEEP s, writes its start and end time to FAKE_ROC_CONC, and fails for a file
# that matches FAKE_ROC_FAIL. TEST_TIMEOUT rows: `test` hangs (10 s) for a file that matches FAKE_ROC_HANG, a fuzz target hangs when its build call matches FAKE_FUZZ_HANG,
# and FAKE_ROC_APP=cases makes a test app (L2) that passes, or hangs for a case whose dir has `hang` in its name. `fmt` sleeps FAKE_ROC_SLEEP s and passes. Slice 022: `check` is as `test` (the start and end time, a failure for FAKE_ROC_FAIL, `boom in <file>`), and passes with `No errors found`.
FR=$T/fakeroc
cat > "$FR" << 'FAKEROC'
#!/bin/sh
printf '%s\n' "$*" >> "$FAKE_ROC_LOG"
case $1 in
build)
    out=
    for a in "$@"; do case $a in --output=*) out=${a#--output=} ;; esac; done
    [ "${FAKE_ROC_BUILD:-ok}" = fail ] && { echo "fake roc: build refused" >&2; exit 1; }
    case $out in
    "$FAKE_ROC_OUTDIR"/*)
        fuzz=
        for a in "$@"; do [ "$a" = --fuzz ] && fuzz=1; done
        hang=0
        [ -n "${FAKE_FUZZ_HANG:-}" ] && case "$*" in *"$FAKE_FUZZ_HANG"*) hang=1 ;; esac
        if [ -n "$fuzz" ]; then
            # Slice 033: a fake roc-fuzz target. It logs its dir and its arguments, a file that an earlier run left in its dir, and answers like the real one:
            # FAKE_FUZZ_EXIT (default 0) is its exit code. A failing run writes an input file in --artifact-dir and prints libFuzzer noise and one crash line.
            cat > "$out" << FUZZ
#!/bin/sh
echo "RUN \$PWD \$*" >> "$FAKE_ROC_LOG"
[ -e stale ] && echo "STALE \$PWD" >> "$FAKE_ROC_LOG"
echo "INFO: noise"
[ $hang = 1 ] && exec sleep 10
if [ "${FAKE_FUZZ_EXIT:-0}" != 0 ]; then
    d=
    for a in "\$@"; do case \$a in --artifact-dir=*) d=\${a#--artifact-dir=} ;; esac; done
    mkdir -p "\$d"
    echo input > "\$d/crash-abc"
    echo "#9 NEW noise"
    echo "[roc crashed] R-EP6: boom"
    exit ${FAKE_FUZZ_EXIT:-0}
fi
echo "Done 20000 runs in 0 second(s)"
FUZZ
        elif [ "${FAKE_ROC_APP:-}" = cases ]; then
            printf '#!/bin/sh\ncase $1 in *hang*) exec sleep 10 ;; esac\nmkdir -p "$1/out"\necho 0 > "$1/out/exit"\n' > "$out"
        else
            printf '#!/bin/sh\nexit 0\n' > "$out"
        fi
        chmod +x "$out"; exit 0 ;;
    esac
    echo "fake roc: output outside FAKE_ROC_OUTDIR: $out" >&2; exit 1 ;;
test)
    [ -n "${FAKE_ROC_HANG:-}" ] && case "$*" in *"$FAKE_ROC_HANG"*) exec sleep 10 ;; esac
    [ -n "${FAKE_ROC_CONC:-}" ] && echo "$(date +%s%N) s" >> "$FAKE_ROC_CONC"
    sleep "${FAKE_ROC_SLEEP:-0}"
    [ -n "${FAKE_ROC_CONC:-}" ] && echo "$(date +%s%N) e" >> "$FAKE_ROC_CONC"
    if [ -n "${FAKE_ROC_FAIL:-}" ]; then case "$*" in *"$FAKE_ROC_FAIL"*) echo "boom in $2" >&2; exit 1 ;; esac; fi
    echo "0 failed and 1 passed in 1 ms" ;;
check)
    [ -n "${FAKE_ROC_CONC:-}" ] && echo "$(date +%s%N) s" >> "$FAKE_ROC_CONC"
    sleep "${FAKE_ROC_SLEEP:-0}"
    [ -n "${FAKE_ROC_CONC:-}" ] && echo "$(date +%s%N) e" >> "$FAKE_ROC_CONC"
    if [ -n "${FAKE_ROC_FAIL:-}" ]; then case "$*" in *"$FAKE_ROC_FAIL"*) echo "boom in $2" >&2; exit 1 ;; esac; fi
    echo "No errors found" ;;
*) sleep "${FAKE_ROC_SLEEP:-0}"; echo "No errors found" ;;
esac
FAKEROC
chmod +x "$FR"
mk $T/l3-one runner/ok 'true'
# fx <name> <env assignment or command>...: run a harness script from the repo root with the fake roc and its own WORK dir.
# The roc calls are in $T/<name>.log, the output is in $T/<name>.out, the exit code is in $rc.
fx() {
    local n=$1
    shift
    : > "$T/$n.log"
    (cd "$ROOT" && env ROC="$FR" WORK="$T/work-$n" FAKE_ROC_LOG="$T/$n.log" FAKE_ROC_OUTDIR="$T/work-$n" TMPDIR="$ST" "$@") > "$T/$n.out" 2>&1
    rc=$?
}
# builds_have <log> <mode> <min>: at least <min> `roc build` calls, and each has exactly one --opt flag, --opt=<mode>.
builds_have() {
    awk -v want="--opt=$2" -v min="$3" '/^build /{n++; c=0; for(i=1;i<=NF;i++) if($i ~ /^--opt=/){c++; if($i!=want) bad=1} if(c!=1) bad=1}
        END{exit !(n>=min && !bad)}' "$1"
}
# opt_runs <label> <env assignment>...: the 3 scripts that build test binaries. tests/run.sh and tests/commands/run.sh build for real
# (with the fake). test.sh gets builds that fail: only its calls are checked.
opt_runs() {
    local l=$1
    shift
    fx "$l-ts" env FAKE_ROC_BUILD=fail "$@" "$ROOT/scripts/test.sh" check fmt l0 l2 l3
    rc_ts=$rc
    fx "$l-run" env SCENARIOS="$T/l3-one" "$@" "$SELF/run.sh"
    rc_run=$rc
    fx "$l-l2" env CASES="$L2P" "$@" "$SELF/commands/run.sh"
    rc_l2=$rc
}
# TW25: the test binaries are built with --opt=dev. OPT=speed gives the LLVM build. Another value is a usage error (exit 2) before any build.
s_opt_dev() {
opt_runs dev
if builds_have $T/dev-ts.log dev 4 && builds_have $T/dev-run.log dev 3 && builds_have $T/dev-l2.log dev 1 && [ $rc_run = 0 ]; then ok
else bad "OPT unset: each roc build must have --opt=dev (test.sh 4 builds, run.sh 3, commands/run.sh 1)"; cat $T/dev-*.log; fi
# Slice 036b3: with OPT=dev and the step l0 in the run, the builds of test.sh get BUILD_THREADS=1 compile thread (`--jobs=1`): the builds run while l0 runs. A run without l0 (row l1) has no --jobs.
if [ "$(grep -c '^build ' $T/dev-ts.log)" -ge 4 ] && [ "$(grep '^build ' $T/dev-ts.log | grep -vc -e ' --jobs=1 ')" = 0 ]; then ok
else bad "OPT unset, steps with l0: each roc build of test.sh must have --jobs=1 (BUILD_THREADS)"; grep '^build ' $T/dev-ts.log; fi
# TW26: the table of scripts/test.sh has the budget of each step (seconds). The run "dev" above has all steps but selftest.
if grep -Eq '^check +pass +[0-9.]+ +10$' $T/dev-ts.out && grep -Eq '^fmt +pass +[0-9.]+ +5$' $T/dev-ts.out &&
    grep -Eq '^l0 +pass +[0-9.]+ +10$' $T/dev-ts.out && grep -Eq '^l2 +FAIL +[0-9.]+ +30$' $T/dev-ts.out &&
    grep -Eq '^l3 +FAIL +[0-9.]+ +60$' $T/dev-ts.out; then ok
else bad "the table of test.sh needs the budget column: check 10, fmt 5, l0 10, l2 30, l3 60"; cat $T/dev-ts.out; fi
}
sec opt_dev s_opt_dev
s_opt_speed() {
opt_runs speed OPT=speed
if builds_have $T/speed-ts.log speed 4 && builds_have $T/speed-run.log speed 3 && builds_have $T/speed-l2.log speed 1 && [ $rc_run = 0 ]; then ok
else bad "OPT=speed: each roc build must have --opt=speed"; cat $T/speed-*.log; fi
if [ "$(grep -c '^build ' $T/speed-ts.log)" -ge 4 ] && [ "$(grep '^build ' $T/speed-ts.log | grep -c -e '--jobs')" = 0 ]; then ok
else bad "OPT=speed: a roc build of test.sh has no --jobs (the LLVM build keeps all threads)"; grep '^build ' $T/speed-ts.log; fi
}
sec opt_speed s_opt_speed
s_opt_bad() {
opt_runs bad OPT=fast
if [ $rc_ts = 2 ] && [ $rc_run = 2 ] && [ $rc_l2 = 2 ] && ! grep -q '^build ' $T/bad-ts.log $T/bad-run.log $T/bad-l2.log &&
    grep -q 'OPT must be dev or speed' $T/bad-ts.out $T/bad-run.out $T/bad-l2.out; then ok
else bad "OPT=fast: exit 2 with 'OPT must be dev or speed', no build"; cat $T/bad-*.out; fi
}
sec opt_bad s_opt_bad

# TW27: the tag slow. The fast set skips it. SLOW=1 runs it, and a failure shows. Other tags (windows) stay skipped.
s_slow() {
S=$T/l3-slow
mk $S slow/ok 'exit 5'
put $S slow/ok tags $'slow\n'
put $S slow/ok expect/exit $'5\n'
mk $S slow/bad 'exit 3'
put $S slow/bad tags $'slow\n'
mk $S slow/win 'exit 3'
put $S slow/win tags $'windows\n'
out=$(l3 $S)
rc1=$?
out2=$(SLOW=1 l3 $S)
rc2=$?
if [ $rc1 = 0 ] && echo "$out" | grep -q 'scenarios: 0 passed, 0 failed, 3 skipped' &&
    [ $rc2 = 1 ] && echo "$out2" | grep -q 'FAIL slow/bad' && ! echo "$out2" | grep -q 'FAIL slow/ok' &&
    echo "$out2" | grep -q 'scenarios: 1 passed, 1 failed, 1 skipped'; then ok
else bad "slow tag: skipped in the fast set, run with SLOW=1 (slow/bad fails, windows stays skipped)"; echo "$out"; echo "$out2"; fi
}
sec slow s_slow

# TW20: L0 files run in parallel (at most JOBS at one time). A failed file fails the step, and its name and output show.
# The other files still run, and the log has the files in sorted order.
s_l0_par() {
n_unit=$(cd "$ROOT" && ls tests/unit/*.roc packages/*/tests/*.roc 2> /dev/null | sort -u | wc -l)
fx l0-par env JOBS=4 FAKE_ROC_SLEEP=0.2 FAKE_ROC_FAIL=tests/unit/lock.roc FAKE_ROC_CONC="$T/l0-par.conc" TAIL=1000 "$ROOT/scripts/test.sh" l0
maxc=$(sort -k1,1n -k2,2 "$T/l0-par.conc" 2> /dev/null | awk '{c += ($2 == "s") ? 1 : -1; if (c > m) m = c} END {print m + 0}')
files=$(grep -o '^[^ :]*\.roc' "$T/l0-par.out")
if [ $rc != 0 ] && grep -q '^== l0: FAIL' $T/l0-par.out && grep -q '^tests/unit/lock\.roc: FAILED' $T/l0-par.out &&
    grep -q 'boom in tests/unit/lock.roc' $T/l0-par.out &&
    [ "$(grep -c '^[^ ]*[.]roc: 0 failed and 1 passed' $T/l0-par.out)" = $((n_unit - 1)) ] &&
    [ "$files" = "$(echo "$files" | sort)" ] && [ "$maxc" -ge 2 ] && [ "$maxc" -le 4 ]; then ok
else bad "l0 in parallel: exit != 0, 'lock.roc: FAILED' with its output, $((n_unit - 1)) passes, sorted, 2 to 4 at one time (max seen: $maxc)"; head -n 70 $T/l0-par.out; fi
}
sec l0_par s_l0_par

# Slice 036b3 (l0 time): the l0 step starts the files in the order of the last run, the slowest first (`$WORK/l0-times`, lines "<ms> <file>"). A file with no time goes first. The report stays in the order of the files (row l0_par).
# Each `roc test` has L0_THREADS compile threads (`--jobs=1`). The step writes the times of its run. The row seeds a time that grows with the name, so the order of the starts is the reverse of the sorted names, but the file lock.roc has no time: it starts first.
s_l0_order() {
files=$(cd "$ROOT" && ls tests/unit/*.roc packages/*/tests/*.roc 2> /dev/null | sort -u)
n_unit=$(echo "$files" | wc -l | tr -d ' ')
mkdir -p "$T/work-l0-ord"
echo "$files" | grep -v '^tests/unit/lock\.roc$' | awk '{ print NR * 10 " " $0 }' > "$T/work-l0-ord/l0-times"
fx l0-ord env JOBS=1 "$ROOT/scripts/test.sh" l0
started=$(grep '^test ' "$T/l0-ord.log" | awk '{ print $2 }')
want=$({ echo tests/unit/lock.roc; echo "$files" | grep -v '^tests/unit/lock\.roc$' | sort -r; })
if [ $rc = 0 ] && [ "$started" = "$want" ] && [ "$(grep -c -e ' --jobs=1$' "$T/l0-ord.log")" = "$n_unit" ] &&
    [ "$(wc -l < "$T/work-l0-ord/l0-times" | tr -d ' ')" = "$n_unit" ] && [ "$(grep -Ec '^[0-9]+ [^ ]+\.roc$' "$T/work-l0-ord/l0-times")" = "$n_unit" ]; then ok
else bad "l0 order: the files start with the no-time file first, then the longest time first, each roc test has --jobs=1, and the step writes a time for each of the $n_unit files"; echo "$started" | head -n 5; echo "$want" | head -n 5; cat "$T/l0-ord.out"; fi
}
sec l0_order s_l0_order

# Slice 022 (PLAN-P1 row 022, the harness): the `check` step runs its `roc check` calls in parallel, as l0 does (it was at 8.2 s of its 10 s budget). At most JOBS at one time. A file that fails fails the step, the other files
# still run, and each failure shows its output and the line `^^^ roc check <file> (exit <n>)`, in the order of the files (the report is not in the order in which the calls end).
s_chk_par() {
# The unit files are not in `check` (the l0 step compiles them, see s_unit_guard), so the count of calls is the count of apps. cli/f matches cli/flowprobe.roc and cli/fxprobe.roc.
n_apps=$(cd "$ROOT" && { echo cli/main.roc; echo cli/fxprobe.roc; echo cli/flowprobe.roc; echo cli/lib/main.roc; echo tests/commands/main.roc; ls packages/*/main.roc 2> /dev/null; } | sort -u | wc -l)
n_fail=2
fx chk-par env JOBS=4 FAKE_ROC_SLEEP=0.1 FAKE_ROC_FAIL=cli/f FAKE_ROC_CONC="$T/chk-par.conc" TAIL=1000 "$ROOT/scripts/test.sh" check
rc_par=$rc
maxc=$(sort -k1,1n -k2,2 "$T/chk-par.conc" 2> /dev/null | awk '{c += ($2 == "s") ? 1 : -1; if (c > m) m = c} END {print m + 0}')
marks=$(grep -o '^\^\^\^ roc check [^ ]* (exit 1)' $T/chk-par.out)
if [ $rc_par != 0 ] && [ "$(grep -c '^check ' $T/chk-par.log)" = "$n_apps" ] && grep -q '^== check: FAIL' $T/chk-par.out && [ "$(echo "$marks" | grep -c .)" = "$n_fail" ] &&
    [ "$marks" = "$(echo "$marks" | sort)" ] && [ "$(grep -c '^boom in cli/f' $T/chk-par.out)" = "$n_fail" ] && ! grep -q 'tests/unit' $T/chk-par.log && [ "$maxc" -ge 2 ] && [ "$maxc" -le 4 ]; then ok
else bad "check in parallel: $n_apps roc check calls (also after a failure), '== check: FAIL', $n_fail failures with their output and '^^^ roc check <file> (exit 1)' in sorted order, 2 to 4 at one time (max seen: $maxc)"; head -n 60 $T/chk-par.out; fi
}
sec chk_par s_chk_par
# P1 section 5 (check speed): the unit files are only in the l0 step (`roc test`), not in `check`. So `roc test` must fail on what `roc check` reports.
# The real roc runs the real l0 step on a copy of the tree with one unit file: a clean file passes, an unused variable (a warning, roc exit 2) and a type error (roc exit 1) fail the step.
s_unit_guard() {
U=$T/unit-guard
rm -rf "$U"
mkdir -p "$U/tests/unit"
ln -s "$ROOT/scripts" "$U/scripts"
ln -s "$ROOT/cli" "$U/cli"
ln -s "$ROOT/packages" "$U/packages"
ln -s "$ROOT/tests/lib.sh" "$U/tests/lib.sh"
hdr=$'app [main!] { lib: "../../cli/lib/main.roc" }\n\nimport lib.Args\n\nmain! = |_args| Ok({})\n\nexpect 1 == 1\n'
ug() { # ug <name> <extra text>: the l0 step on one unit file
    printf '%s%s' "$hdr" "$2" > "$U/tests/unit/g.roc"
    # The roc package cache (the URL packages, for example roc-semver) is the one of this run: the l0 step filled it, so a warm cache needs no network. A new cache dir would download each package again.
    mkdir -p "$ROC_CACHE_DIR/packages" "$U/work-$1/cache/roc"
    ln -sfn "$ROC_CACHE_DIR/packages" "$U/work-$1/cache/roc/packages"
    (cd "$U" && env WORK="$U/work-$1" VERBOSE=1 TAIL=1000 "$U/scripts/test.sh" l0) > "$T/ug-$1.out" 2>&1
    ug_rc=$?
}
ug clean ''
c_rc=$ug_rc
ug warn $'\nwarn_demo = |x| {\n    unused = 1\n    x\n}\n'
w_rc=$ug_rc
ug type $'\ntype_demo : U64\ntype_demo = "text"\n'
t_rc=$ug_rc
# A cold package cache and no network: roc says `package download failed`. That is not a fault of the guard, so the row is skipped, with the reason.
if grep -q 'package download failed' "$T/ug-clean.out" "$T/ug-warn.out" "$T/ug-type.out"; then
    skip "unit guard: roc could not download a package (cold package cache $ROC_CACHE_DIR/packages and no network): $(grep -h -A3 'Failed to download' "$T/ug-clean.out" | tr -s ' \n' ' ' | cut -c1-160)"
elif [ $c_rc = 0 ] && grep -q "^tests/unit/g.roc: .*passed" "$T/ug-clean.out" &&
    [ $w_rc != 0 ] && grep -q '^== l0: FAIL' "$T/ug-warn.out" && grep -q 'unused variable' "$T/ug-warn.out" &&
    [ $t_rc != 0 ] && grep -q '^== l0: FAIL' "$T/ug-type.out" && grep -q 'type mismatch' "$T/ug-type.out"; then ok
else bad "unit guard: the l0 step passes a clean unit file (exit $c_rc), fails on an unused variable (exit $w_rc) and on a type error (exit $t_rc)"; head -n 30 "$T/ug-clean.out" "$T/ug-warn.out" "$T/ug-type.out"; fi
}
sec unit_guard s_unit_guard
s_chk_ok() {
fx chk-ok env JOBS=4 FAKE_ROC_SLEEP=0.1 "$ROOT/scripts/test.sh" check
if [ $rc = 0 ] && grep -Eq '^check +pass' $T/chk-ok.out; then ok; else bad "check in parallel: all files pass, exit 0"; cat $T/chk-ok.out; fi
}
sec chk_ok s_chk_ok

# Memory rule (research/test-memory/RESULTS.md): jobs_for = min(cores, (budget - reserve) / per job), at least 1. TEST_MEM_GB sets the budget.
# prune_roc_objects keeps the 3 newest files of a dir of the object cache, and every file under 10 minutes old (a large cache made `roc check` use 14 GB).
s_mem() {
got=$(. "$SELF/lib.sh"; echo "$(jobs_for 24 25600 8000 1000) $(jobs_for 24 4096 4000 1000) $(jobs_for 4 100000 0 2000) $(jobs_for 24 100000 0 2000) $(TEST_MEM_GB=8 mem_budget_mb)")
want="17 1 4 24 8192"
PO=$T/prune/compat-x/objects-v7/x64musl-dev/pkg/h1
mkdir -p $PO $T/prune/compat-x/objects-v7/x64musl-dev/pkg/h2
for i in 1 2 3 4 5 6; do echo x > $PO/old$i; touch -d "$((70 - i)) minutes ago" $PO/old$i; done
echo x > $PO/young1
echo x > $T/prune/compat-x/objects-v7/x64musl-dev/pkg/h2/only
touch -d "2 days ago" $T/prune/compat-x/objects-v7/x64musl-dev/pkg/h2/only
left=$(. "$SELF/lib.sh"; ROC_CACHE_DIR=$T/prune prune_roc_objects; cd $T/prune/compat-x/objects-v7/x64musl-dev/pkg && ls h1 h2 | tr '\n' ' ')
# The l0 step takes its job count from TEST_MEM_GB: 1 GB gives 1 job, 3 GB gives 3 (1 GB for each roc call), also when JOBS is larger.
fx mem1 env TEST_MEM_GB=1 JOBS=8 FAKE_ROC_SLEEP=0.05 FAKE_ROC_CONC="$T/mem1.conc" "$ROOT/scripts/test.sh" l0
fx mem3 env TEST_MEM_GB=3 JOBS=8 FAKE_ROC_SLEEP=0.1 FAKE_ROC_CONC="$T/mem3.conc" "$ROOT/scripts/test.sh" l0
max1=$(sort -k1,1n -k2,2 "$T/mem1.conc" 2> /dev/null | awk '{c += ($2 == "s") ? 1 : -1; if (c > m) m = c} END {print m + 0}')
max3=$(sort -k1,1n -k2,2 "$T/mem3.conc" 2> /dev/null | awk '{c += ($2 == "s") ? 1 : -1; if (c > m) m = c} END {print m + 0}')
if [ "$got" = "$want" ] && [ "$left" = "h1: old4 old5 old6 young1  h2: only " ] && [ "$max1" = 1 ] && [ "$max3" -ge 2 ] && [ "$max3" -le 3 ]; then ok
else bad "memory rule: jobs_for/mem_budget_mb gave '$got' (want '$want'). prune keeps old4 old5 old6 (the 3 newest old files) and the young one, and the only file of a dir: '$left'. l0 at one time with TEST_MEM_GB=1: $max1 (want 1), with 3: $max3 (want 2 or 3)"; fi
}
sec mem s_mem

# Roc object cache (research/roc-object-cache/RESULTS.md): a build that reads cached objects (objects-v7) gives a bad app, so each `roc build` of test.sh has --no-cache.
# The run has the steps l2 and l3 (4 builds with the fake roc, which refuses to build: its log has the calls).
s_nocache() {
fx nocache env FAKE_ROC_BUILD=fail "$ROOT/scripts/test.sh" l2 l3
nb=$(grep -c '^build ' $T/nocache.log)
nn=$(grep '^build ' $T/nocache.log | grep -c -e ' --no-cache ')
if [ "$nb" -ge 4 ] && [ "$nb" = "$nn" ]; then ok
else bad "test.sh: each roc build must have --no-cache (the object cache gives a bad build): $nn of $nb builds have it"; cat $T/nocache.log; fi
}
sec nocache s_nocache

# TW26: a step over its budget gives a warning line, and the exit code stays 0. BUDGET_<STEP>=<s> sets the budget of a step,
# BUDGET_TOTAL=<s> the budget of the whole run (default 180, TW20).
s_bud() {
fx bud-slow env FAKE_ROC_SLEEP=0.6 BUDGET_FMT=0.3 "$ROOT/scripts/test.sh" fmt
rc1=$rc
fx bud-ok env FAKE_ROC_SLEEP=0.6 BUDGET_FMT=30 BUDGET_TOTAL=30 "$ROOT/scripts/test.sh" fmt
rc2=$rc
fx bud-total env FAKE_ROC_SLEEP=0.6 BUDGET_FMT=30 BUDGET_TOTAL=0.3 "$ROOT/scripts/test.sh" fmt
rc3=$rc
if [ $rc1 = 0 ] && grep -q '^WARN fmt' $T/bud-slow.out && ! grep -q 'WARN total' $T/bud-slow.out &&
    [ $rc2 = 0 ] && ! grep -q WARN $T/bud-ok.out &&
    [ $rc3 = 0 ] && grep -q '^WARN total' $T/bud-total.out && ! grep -q 'WARN fmt' $T/bud-total.out; then ok
else bad "budget: WARN fmt over its share, WARN total over the whole, no WARN under, exit 0 each time"; cat $T/bud-slow.out $T/bud-ok.out $T/bud-total.out; fi
}
sec bud s_bud

# Slice 021 (review of slice 020, TW26): the budget warnings are for the fast set (OPT=dev) only. A run with OPT=speed (the merge run and the nightly run: LLVM builds, TW25) has no WARN line,
# also when a step and the whole run are over their budget, and its exit code and its table stay as they are. The control: the same run with OPT=dev warns.
s_bud_speed() {
fx bud-speed env OPT=speed FAKE_ROC_SLEEP=0.6 BUDGET_FMT=0.3 BUDGET_TOTAL=0.3 "$ROOT/scripts/test.sh" fmt
rc1=$rc
fx bud-dev env OPT=dev FAKE_ROC_SLEEP=0.6 BUDGET_FMT=0.3 BUDGET_TOTAL=0.3 "$ROOT/scripts/test.sh" fmt
rc2=$rc
if [ $rc1 = 0 ] && ! grep -q 'WARN' $T/bud-speed.out && grep -Eq '^fmt +pass +[0-9.]+' $T/bud-speed.out &&
    [ $rc2 = 0 ] && grep -q '^WARN fmt' $T/bud-dev.out && grep -q '^WARN total' $T/bud-dev.out; then ok
else bad "budget with OPT=speed: no WARN line (fmt and total are over), exit 0, the table of results stays. With OPT=dev: WARN fmt and WARN total."; cat $T/bud-speed.out $T/bud-dev.out; fi
}
sec bud_speed s_bud_speed

# The time limit of one test process (PLAN-P1 5b, TEST_TIMEOUT of scripts/test.sh). A fake process hangs (10 s), the limit is 1 s: the step fails with a line that names the file and says
# `timed out after 1 s`, in far less than 10 s, and the other files or cases of the run pass. One row for each step that starts a test process (one run each: the rows share the CPU with the row `mem`, which sets the time of the step).
s_limit_l0() {
hung=$(cd "$ROOT" && ls tests/unit/*.roc | sed -n 2p)
n_unit=$(cd "$ROOT" && ls tests/unit/*.roc packages/*/tests/*.roc 2> /dev/null | sort -u | wc -l | tr -d ' ')
fx lim-l0 env TAIL=1000 TEST_TIMEOUT=1 FAKE_ROC_HANG="$hung" "$ROOT/scripts/test.sh" l0
if [ $rc = 1 ] && [ -n "$hung" ] && grep -Eq '^l0 +FAIL ' $T/lim-l0.out && grep -qx "l0: $hung: timed out after 1 s" $T/lim-l0.out &&
    [ "$(grep -c 'timed out' $T/lim-l0.out)" = 1 ] && [ "$(grep -c ': 0 failed and 1 passed' $T/lim-l0.out)" = $((n_unit - 1)) ]; then ok
else bad "limit l0: a roc test file that hangs gives 'l0: <file>: timed out after 1 s' (once) and 'l0 FAIL' (exit 1). All other files pass."; cat $T/lim-l0.out; fi
}
sec limit_l0 s_limit_l0
s_limit_l1() {
mkdir -p "$T/fuzz-lim"
printf 'app [target] {}\n' > "$T/fuzz-lim/quick.roc"
printf 'app [target] {}\n' > "$T/fuzz-lim/hangs.roc"
fx lim-l1 env L1_HOST=Linux-x86_64 L1_DIR="$T/fuzz-lim" TEST_TIMEOUT=1 FAKE_FUZZ_HANG=hangs.roc "$ROOT/scripts/test.sh" l1
if [ $rc = 1 ] && grep -Eq '^l1 +FAIL ' $T/lim-l1.out && grep -qx "l1: $T/fuzz-lim/hangs.roc: timed out after 1 s (seed 1, 20000 runs)" $T/lim-l1.out &&
    [ "$(grep -c 'timed out' $T/lim-l1.out)" = 1 ] && grep -q "quick.roc: Done" $T/lim-l1.out; then ok
else bad "limit l1: a fuzz run that hangs gives 'l1: <file>: timed out after 1 s (seed 1, 20000 runs)' (once) and 'l1 FAIL' (exit 1). The other target passes."; cat $T/lim-l1.out; fi
}
sec limit_l1 s_limit_l1
s_limit_l2() {
mkdir -p "$T/l2-lim/a/quick" "$T/l2-lim/a/hang-it"
for c in "$T/l2-lim/a/quick" "$T/l2-lim/a/hang-it"; do echo run > "$c/entry"; done
fx lim-l2 env CASES="$T/l2-lim" FAKE_ROC_APP=cases TEST_TIMEOUT=1 "$ROOT/scripts/test.sh" l2
if [ $rc = 1 ] && grep -Eq '^l2 +FAIL ' $T/lim-l2.out && grep -q '^FAIL a/hang-it$' $T/lim-l2.out && grep -q 'l2: case a_hang-it: timed out after 1 s' $T/lim-l2.out &&
    ! grep -q 'FAIL a/quick' $T/lim-l2.out && grep -q 'commands: 1 passed, 1 failed' $T/lim-l2.out; then ok
else bad "limit l2: an L2 case that hangs fails with 'l2: case <name>: timed out after 1 s' (step exit 1). The other case passes."; cat $T/lim-l2.out; fi
}
sec limit_l2 s_limit_l2
# l3: tests/run.sh has the limit already (CASE_TIMEOUT, exit 124). scripts/test.sh must give it the TEST_TIMEOUT value, so the row has a case that sleeps 10 s and a limit of 1 s.
s_limit_l3() {
mk $T/l3-lim runner/hang 'sleep 10'
mk $T/l3-lim runner/quick 'true'
fx lim-l3 env SCENARIOS="$T/l3-lim" TEST_TIMEOUT=1 "$ROOT/scripts/test.sh" l3
if [ $rc = 1 ] && grep -Eq '^l3 +FAIL ' $T/lim-l3.out && grep -q 'FAIL runner/hang' $T/lim-l3.out && grep -q '^ *+124$' $T/lim-l3.out && ! grep -q 'FAIL runner/quick' $T/lim-l3.out &&
    grep -q 'scenarios: 1 passed, 1 failed' $T/lim-l3.out; then ok
else bad "limit l3: TEST_TIMEOUT=1 kills an L3 case that sleeps 10 s (exit code 124, step exit 1). The quick case passes."; cat $T/lim-l3.out; fi
}
sec limit_l3 s_limit_l3

# --- Slice 033: the l1 step (TESTING.md 4, TW6, TW26). A fake roc makes a fake roc-fuzz target (see the fake roc above). The rows read the calls of the step and its text. ---
# The step: one `roc build --fuzz --opt=speed` for each tests/fuzz/*.roc (LLVM only: it does not follow OPT), one run of each target in $WORK/l1/<name>/ (never in the repo) with a fixed count and seed,
# a new dir for each run, a failure with the replay command, a skip on a system that has no roc-fuzz platform, the budget 60 in the table.
s_l1() {
n_targets=$(ls "$ROOT"/tests/fuzz/*.roc 2> /dev/null | wc -l | tr -d ' ')
W=$T/work-l1-pass
fx l1-pass env L1_HOST=Linux-x86_64 "$ROOT/scripts/test.sh" l1
rc1=$rc
if [ $rc1 = 0 ] && [ "$n_targets" -ge 1 ] && [ "$(grep -c '^build ' $T/l1-pass.log)" = "$n_targets" ] &&
    [ "$(grep -Ec "^build --fuzz --opt=speed tests/fuzz/[a-z0-9_-]+\.roc --output=$W/l1/[a-z0-9_-]+/target$" $T/l1-pass.log)" = "$n_targets" ] &&
    [ "$(grep -Ec "^RUN $W/l1/[a-z0-9_-]+ run --runs=[0-9]+ --seed=1 --artifact-dir=$W/l1/[a-z0-9_-]+/art$" $T/l1-pass.log)" = "$n_targets" ] &&
    ! grep -q -e '--time' $T/l1-pass.log && grep -Eq '^l1 +pass +[0-9.]+ +60$' $T/l1-pass.out; then ok
else bad "l1: one build --fuzz --opt=speed for each target (also with OPT unset, which is dev), one run in \$WORK/l1/<name> with a --runs count, --seed=1 and no --time, table row 'l1 pass .. 60'"; cat $T/l1-pass.log $T/l1-pass.out; fi
# L1_RUNS and L1_SEED change the run. OPT=dev is given on purpose: the fuzz build stays --opt=speed.
fx l1-cfg env OPT=dev L1_HOST=Linux-x86_64 L1_RUNS=7 L1_SEED=3 "$ROOT/scripts/test.sh" l1
if [ $rc = 0 ] && [ "$(grep -c ' run --runs=7 --seed=3 --artifact-dir=' $T/l1-cfg.log)" = "$n_targets" ] && ! grep '^build ' $T/l1-cfg.log | grep -q -e '--opt=dev'; then ok
else bad "l1: L1_RUNS=7 L1_SEED=3 give --runs=7 --seed=3, and OPT=dev does not change the fuzz build"; cat $T/l1-cfg.log; fi
# The count of a target (TESTING.md 1: the long runs are for the nightly run): the line `# l1-runs: <n>` of the target file, else 20000. L1_RUNS is for all targets and wins. L1_DIR is a dir of fake targets.
mkdir -p "$T/fuzz-cnt"
printf '# l1-runs: 123\napp [target] {}\n' > "$T/fuzz-cnt/small.roc"
printf 'app [target] {}\n# l1-runs: 5 is not a header line\n' > "$T/fuzz-cnt/plain.roc"
fx l1-cnt env L1_HOST=Linux-x86_64 L1_DIR="$T/fuzz-cnt" "$ROOT/scripts/test.sh" l1
rc_c=$rc
fx l1-cnt-env env L1_HOST=Linux-x86_64 L1_DIR="$T/fuzz-cnt" L1_RUNS=9 "$ROOT/scripts/test.sh" l1
if [ $rc_c = 0 ] && grep -Eq "^RUN [^ ]+/small run --runs=123 --seed=1 " $T/l1-cnt.log && grep -Eq "^RUN [^ ]+/plain run --runs=20000 --seed=1 " $T/l1-cnt.log &&
    [ $rc = 0 ] && [ "$(grep -Ec '^RUN [^ ]+/(small|plain) run --runs=9 --seed=1 ' $T/l1-cnt-env.log)" = 2 ]; then ok
else bad "l1: a target with the line '# l1-runs: 123' runs 123 inputs, a target with no such line (or the text not at the start of a line) 20000, and L1_RUNS=9 sets 9 for both"; cat $T/l1-cnt.log $T/l1-cnt-env.log; fi
# A failing target: exit 1 for the step, the table says FAIL, the text has the exit code, the seed, the crash line without the libFuzzer noise, and the replay command of the saved input.
W=$T/work-l1-fail
fx l1-fail env L1_HOST=Linux-x86_64 FAKE_FUZZ_EXIT=77 "$ROOT/scripts/test.sh" l1
if [ $rc = 1 ] && grep -Eq '^l1 +FAIL ' $T/l1-fail.out && grep -Eq '^tests/fuzz/[a-z0-9_-]+\.roc: FAILED \(exit 77, seed 1, [0-9]+ runs\)$' $T/l1-fail.out &&
    grep -q '^\[roc crashed\] R-EP6: boom$' $T/l1-fail.out && ! grep -q -e 'INFO: noise' -e '#9 NEW' $T/l1-fail.out &&
    grep -Eq "^replay: $W/l1/[a-z0-9_-]+/target replay $W/l1/[a-z0-9_-]+/art/crash-abc$" $T/l1-fail.out; then ok
else bad "l1: a target that exits 77 fails the step: exit 1, 'l1 FAIL', 'FAILED (exit 77, seed 1, <count> runs)', the crash line, no libFuzzer noise, the replay line"; cat $T/l1-fail.out; fi
# A failing build: exit 1, the build log, no run.
fx l1-build env L1_HOST=Linux-x86_64 FAKE_ROC_BUILD=fail "$ROOT/scripts/test.sh" l1
if [ $rc = 1 ] && grep -Eq '^l1 +FAIL ' $T/l1-build.out && grep -q ': FAILED, the build$' $T/l1-build.out && grep -q 'fake roc: build refused' $T/l1-build.out && ! grep -q '^RUN ' $T/l1-build.log; then ok
else bad "l1: a failing build fails the step (exit 1, 'FAILED, the build', the build log) and runs nothing"; cat $T/l1-build.out $T/l1-build.log; fi
# A system with no roc-fuzz platform: skipped with exit 0 and no build. Darwin-arm64 is supported.
fx l1-win env VERBOSE=1 L1_HOST=MINGW64_NT-10.0-x86_64 "$ROOT/scripts/test.sh" l1
rc_w=$rc
fx l1-arm env VERBOSE=1 L1_HOST=Linux-aarch64 "$ROOT/scripts/test.sh" l1
rc_a=$rc
fx l1-mac L1_HOST=Darwin-arm64 "$ROOT/scripts/test.sh" l1
if [ $rc_w = 0 ] && grep -q '^l1: skipped, roc-fuzz has no platform for MINGW64_NT-10.0-x86_64$' $T/l1-win.out && ! grep -q '^build ' $T/l1-win.log && grep -Eq '^l1 +pass ' $T/l1-win.out &&
    [ $rc_a = 0 ] && grep -q '^l1: skipped, roc-fuzz has no platform for Linux-aarch64$' $T/l1-arm.out && ! grep -q '^build ' $T/l1-arm.log &&
    [ $rc = 0 ] && grep -q '^build --fuzz ' $T/l1-mac.log; then ok
else bad "l1: Windows and Linux-aarch64 are skipped (exit 0, the text 'l1: skipped, roc-fuzz has no platform for <system>', no build), Darwin-arm64 runs"; cat $T/l1-win.out $T/l1-arm.out $T/l1-mac.log; fi
# Each run starts in a new dir: a file that an earlier run left in $WORK/l1/<name>/ is gone, so the corpus of an old run never changes a run (TW6).
mkdir -p "$T/work-l1-stale/l1/epochs"
: > "$T/work-l1-stale/l1/epochs/stale"
fx l1-stale env L1_HOST=Linux-x86_64 "$ROOT/scripts/test.sh" l1
if [ $rc = 0 ] && grep -q '^RUN ' $T/l1-stale.log && ! grep -q '^STALE ' $T/l1-stale.log; then ok
else bad "l1: the dir \$WORK/l1/<name> is new for each run (a stale file must be gone)"; cat $T/l1-stale.log; fi
# The default steps have l1 (the full run needs the real builds, so the row reads the line of the script), as the last step.
if grep -Eq '^\[ \$\{#STEPS\[@\]\} -eq 0 \] && STEPS=\(check fmt l0 l2 l3 selftest l1\)$' "$ROOT/scripts/test.sh"; then ok
else bad "l1: the default steps of scripts/test.sh are 'check fmt l0 l2 l3 selftest l1' (l1 last: the LLVM builds of the targets start at the start and run while the other steps run)"; fi
}
sec l1 s_l1

# --- Slice 018b: CI jobs (TW20, TW25, TW27, TW28). The workflows cannot run here (no remote, no runner), so these rows read the files. ---
# tests/tools/ciscan.py reads the YAML subset of the workflow shape (docs/slices/018b-ci-jobs.md) and prints `FAIL: <reason>` lines.
s_ci() {
ci_row() { # <check> <label>
    local out
    out=$(python3 -I "$SELF/tools/ciscan.py" "$1" "$ROOT" 2>&1) && ok || { bad "$2"; echo "$out"; }
}
# The reader must reject what the shape forbids: a tab, an anchor, a duplicate key, a literal nightly tag in a workflow.
BR=$T/ci-bad
mkdir -p $BR/.github/workflows
printf 'name: x\non: push\njobs:\n\tbad: 1\n' > $BR/.github/workflows/ci.yml
printf 'name: x\non: push\nenv:\n  A: &a 1\n  A: 2\njobs: {}\n' > $BR/.github/workflows/nightly.yml
out=$(python3 -I "$SELF/tools/ciscan.py" yaml $BR 2>&1)
rc=$?
if [ $rc = 1 ] && echo "$out" | grep -q 'ci.yml: line 4: tab in indentation' && echo "$out" | grep -q 'nightly.yml: line 4: anchor'; then ok
else bad "ciscan: a tab and an anchor in a workflow file must fail the yaml check (exit 1)"; echo "$out"; fi
ci_row yaml "ci/yaml: .github/workflows/ci.yml and nightly.yml parse, have name, on, permissions (contents: read), jobs; each job has runs-on, timeout-minutes and steps; each action is pinned"
ci_row fast "ci/fast: ci.yml runs on push and pull_request, a matrix of ubuntu, macos and windows runs scripts/test.sh (windows: check fmt l0), with shell bash, no OPT, SLOW, NET or REAL_ROC; Linux has bubblewrap"
ci_row nightly "ci/nightly: nightly.yml runs on schedule and workflow_dispatch only, on ubuntu, scripts/test.sh with OPT=speed SLOW=1 NET=1 REAL_ROC=1 and GITHUB_TOKEN, no package cache"
ci_row pin "ci/pin: scripts/env.sh has ROC_TAG (the one place of the nightly tag), scripts/get-roc.sh uses it, the workflows run get-roc.sh, cache by runner.os and env.ROC_TAG, have no cloudflare-workers path"
ci_row portable "ci/portable: bash 4 scripts have an env bash shebang, no bc, the macOS job installs bash, coreutils, findutils and diffutils and puts the gnubin dirs on PATH"
}
sec ci s_ci

# Slice 019 (G3 of slice 018b): get-roc.sh checks the sha256 of the download against the digest of the release API (R-CV3).
# A fake `gh` (first on PATH) gives the digest in FAKE_DIGEST and an archive that is not a real archive. A wrong digest: exit 1,
# `sha256 mismatch`, nothing installed. The control: the right digest passes the compare (the next step, tar, fails on the fake archive).
s_get_roc() {
GB=$T/get-roc-bin
mkdir -p $GB
cat > $GB/gh <<'GHEOF'
#!/bin/sh
if [ "$1" = api ]; then printf 'roc_nightly-fake.tar.gz\tsha256:%s\n' "$FAKE_DIGEST"; exit 0; fi
while [ $# -gt 0 ]; do case $1 in -p) name=$2 ;; -D) dir=$2 ;; esac; shift; done
printf payload > "$dir/$name"
GHEOF
chmod +x $GB/gh
if command -v sha256sum > /dev/null 2>&1; then good=$(printf payload | sha256sum | cut -d' ' -f1); else good=$(printf payload | shasum -a 256 | cut -d' ' -f1); fi
bad_digest=$(printf '%064d' 0)
gr() { # <digest> <work dir>
    FAKE_DIGEST=$1 WORK=$2 PATH=$GB:$PATH "$ROOT/scripts/get-roc.sh" 2>&1
}
out=$(gr "$bad_digest" $T/get-roc-w1)
rc=$?
out2=$(gr "$good" $T/get-roc-w2)
rc2=$?
if [ $rc = 1 ] && echo "$out" | grep -q 'get-roc: sha256 mismatch for roc_nightly-fake.tar.gz' && [ ! -e $T/get-roc-w1/nightlies ] &&
    [ $rc2 != 0 ] && ! echo "$out2" | grep -q 'sha256 mismatch' && [ ! -e $T/get-roc-w2/nightlies ]; then ok
else bad "get-roc: a wrong digest gives exit 1, 'sha256 mismatch' and no install dir. The right digest has no mismatch text."; echo "$out"; echo "$out2"; fi
}
sec get_roc s_get_roc

# TW27, TW28: the tag net (real network, nightly only). The fast set skips it. SLOW=1 and REAL_ROC=1 do not run it. NET=1 runs it.
s_net() {
N=$T/l3-net
mk $N net/ok 'exit 5'
put $N net/ok tags $'net\n'
put $N net/ok expect/exit $'5\n'
mk $N net/bad 'exit 3'
put $N net/bad tags $'net\n'
out=$(l3 $N)
rc1=$?
out2=$(SLOW=1 REAL_ROC=1 l3 $N)
rc2=$?
out3=$(NET=1 l3 $N)
rc3=$?
if [ $rc1 = 0 ] && echo "$out" | grep -q 'scenarios: 0 passed, 0 failed, 2 skipped' &&
    [ $rc2 = 0 ] && echo "$out2" | grep -q 'scenarios: 0 passed, 0 failed, 2 skipped' &&
    [ $rc3 = 1 ] && echo "$out3" | grep -q 'FAIL net/bad' && ! echo "$out3" | grep -q 'FAIL net/ok' &&
    echo "$out3" | grep -q 'scenarios: 1 passed, 1 failed, 0 skipped'; then ok
else bad "net tag: skipped in the fast set and with SLOW=1 REAL_ROC=1, run with NET=1 (net/bad fails)"; echo "$out"; echo "$out2"; echo "$out3"; fi
}
sec net s_net

# Slice 034 (R-GP3, R-GP6): a Talon package lives in `packages/` of this repository, and the headers of Talon (`cli/`, `worker/`, `packages/*/`) never name a generic package (`semver`, `base58`, `toml`, `header`) by a path.
# `gen_paths <file>...` prints each header line that gives a generic package a path (a value that starts with `.` or `/`). The row checks the function on 2 fake headers, then the real headers.
gen_paths() { grep -nE '^[[:space:]]*(semver|base58|toml|header)[[:space:]]*:[[:space:]]*"[./]' "$@" 2> /dev/null; }
s_packages() {
G=$T/gp
mkdir -p $G
printf 'package [A]\n\t{\n\t\tsemver: "https://example.com/x.tar.zst",\n\t\tother: "../x/main.roc",\n\t}\n' > $G/ok.roc
printf 'package [A]\n\t{\n\t\tsemver: "../../roc-semver/main.roc",\n\t}\n' > $G/bad.roc
real=$(cd "$ROOT" && gen_paths cli/main.roc cli/lib/main.roc worker/main.roc packages/*/main.roc)
if [ -z "$(gen_paths $G/ok.roc)" ] && [ -n "$(gen_paths $G/bad.roc)" ] && [ -z "$real" ] &&
    [ -f "$ROOT/packages/resolve/main.roc" ] && [ ! -e "$ROOT/packages/resolve/.git" ] && [ ! -e "$ROOT/packages/resolve/LICENSE" ]; then ok
else bad "packages: gen_paths flags a path entry of a generic package and not a URL. The real headers have none ($real). packages/resolve/main.roc exists, with no .git and no LICENSE (R-GP6: not a generic package)"; fi
}
sec packages s_packages

# Slice 036 (R-PH10, 034 section 5): the loop of the commands that resolve takes its step from the oracle (`Oracle.step_probed`, slice 036b, which has the probe rounds), not from `Pick.step`, and the header of `cli/lib` names the Talon package `resolve` by a path (a path to a Talon package is allowed, R-GP3).
# 036b: the L2 case probe/lp1-loop shows the loop of the probe rounds. The row still reads the 2 files, because no case can tell `Oracle` from `Pick` when no probe is wanted.
s_oracle() {
if grep -q 'Oracle\.step_probed(' "$ROOT/cli/lib/PickLoop.roc" && ! grep -q 'Pick\.step(' "$ROOT/cli/lib/PickLoop.roc" &&
    grep -qE '^[[:space:]]*resolve[[:space:]]*:[[:space:]]*"\.\./\.\./packages/resolve/main\.roc"' "$ROOT/cli/lib/main.roc"; then ok
else bad "oracle: cli/lib/PickLoop.roc calls Oracle.step_probed and not Pick.step, and cli/lib/main.roc has the path entry resolve: \"../../packages/resolve/main.roc\""; fi
}
sec oracle s_oracle

wait
pass=$(cat "$RES"/*.ok 2> /dev/null | wc -l | tr -d ' ')
fail=$(cat "$RES"/*.bad 2> /dev/null | wc -l | tr -d ' ')
skipped=$(cat "$RES"/*.skip 2> /dev/null | wc -l | tr -d ' ')
for f in "$RES"/*.out; do [ -s "$f" ] && cat "$f"; done
rm -rf "$T"
echo "selftest: $pass passed, $fail failed$([ "$skipped" != 0 ] && echo ", $skipped skipped")"
[ "$fail" -eq 0 ]
