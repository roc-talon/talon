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
unset OPT SLOW NET JOBS VERBOSE TAIL REAL_ROC TLN L2BIN ${!BUDGET_@}
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
    "$ROC" build "$SELF/commands/main.roc" --opt="$SELFTEST_OPT" --output="$L2APP" > "$T/build-l2.log" 2>&1 || { echo "build of the L2 app failed"; cat "$T/build-l2.log"; exit 1; }
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

# --- Slice 018: build mode, slow tag, parallel L0, step budget (TW20, TW25 to TW27) ---
# A fake roc logs each call. `build` makes a no-op binary, but only under $FAKE_ROC_OUTDIR (the work dir of the row), and fails
# when FAKE_ROC_BUILD=fail. `test` sleeps FAKE_ROC_SLEEP s, writes its start and end time to FAKE_ROC_CONC, and fails for a file
# that matches FAKE_ROC_FAIL. `fmt` sleeps FAKE_ROC_SLEEP s and passes. Slice 022: `check` is as `test` (the start and end time, a failure for FAKE_ROC_FAIL, `boom in <file>`), and passes with `No errors found`.
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
    "$FAKE_ROC_OUTDIR"/*) printf '#!/bin/sh\nexit 0\n' > "$out"; chmod +x "$out"; exit 0 ;;
    esac
    echo "fake roc: output outside FAKE_ROC_OUTDIR: $out" >&2; exit 1 ;;
test)
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
    (cd "$ROOT" && env ROC="$FR" WORK="$T/work-$n" FAKE_ROC_LOG="$T/$n.log" FAKE_ROC_OUTDIR="$T/work-$n" TMPDIR="$T" "$@") > "$T/$n.out" 2>&1
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
opt_runs dev
if builds_have $T/dev-ts.log dev 4 && builds_have $T/dev-run.log dev 3 && builds_have $T/dev-l2.log dev 1 && [ $rc_run = 0 ]; then ok
else bad "OPT unset: each roc build must have --opt=dev (test.sh 4 builds, run.sh 3, commands/run.sh 1)"; cat $T/dev-*.log; fi
opt_runs speed OPT=speed
if builds_have $T/speed-ts.log speed 4 && builds_have $T/speed-run.log speed 3 && builds_have $T/speed-l2.log speed 1 && [ $rc_run = 0 ]; then ok
else bad "OPT=speed: each roc build must have --opt=speed"; cat $T/speed-*.log; fi
opt_runs bad OPT=fast
if [ $rc_ts = 2 ] && [ $rc_run = 2 ] && [ $rc_l2 = 2 ] && ! grep -q '^build ' $T/bad-ts.log $T/bad-run.log $T/bad-l2.log &&
    grep -q 'OPT must be dev or speed' $T/bad-ts.out $T/bad-run.out $T/bad-l2.out; then ok
else bad "OPT=fast: exit 2 with 'OPT must be dev or speed', no build"; cat $T/bad-*.out; fi

# TW26: the table of scripts/test.sh has the budget of each step (seconds). The run "dev" above has all steps but selftest.
if grep -Eq '^check +pass +[0-9.]+ +10$' $T/dev-ts.out && grep -Eq '^fmt +pass +[0-9.]+ +5$' $T/dev-ts.out &&
    grep -Eq '^l0 +pass +[0-9.]+ +10$' $T/dev-ts.out && grep -Eq '^l2 +FAIL +[0-9.]+ +30$' $T/dev-ts.out &&
    grep -Eq '^l3 +FAIL +[0-9.]+ +60$' $T/dev-ts.out; then ok
else bad "the table of test.sh needs the budget column: check 10, fmt 5, l0 10, l2 30, l3 60"; cat $T/dev-ts.out; fi

# TW27: the tag slow. The fast set skips it. SLOW=1 runs it, and a failure shows. Other tags (windows) stay skipped.
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

# TW20: L0 files run in parallel (at most JOBS at one time). A failed file fails the step, and its name and output show.
# The other files still run, and the log has the files in sorted order.
n_unit=$(cd "$ROOT" && ls tests/unit/*.roc packages/*/tests/*.roc 2> /dev/null | sort -u | wc -l)
fx l0-par env JOBS=4 FAKE_ROC_SLEEP=0.2 FAKE_ROC_FAIL=tests/unit/lock.roc FAKE_ROC_CONC="$T/l0-par.conc" TAIL=1000 "$ROOT/scripts/test.sh" l0
maxc=$(sort -k1,1n -k2,2 "$T/l0-par.conc" 2> /dev/null | awk '{c += ($2 == "s") ? 1 : -1; if (c > m) m = c} END {print m + 0}')
files=$(grep -o '^[^ :]*\.roc' "$T/l0-par.out")
if [ $rc != 0 ] && grep -q '^== l0: FAIL' $T/l0-par.out && grep -q '^tests/unit/lock\.roc: FAILED' $T/l0-par.out &&
    grep -q 'boom in tests/unit/lock.roc' $T/l0-par.out &&
    [ "$(grep -c '^tests/unit/.*: 0 failed and 1 passed' $T/l0-par.out)" = $((n_unit - 1)) ] &&
    [ "$files" = "$(echo "$files" | sort)" ] && [ "$maxc" -ge 2 ] && [ "$maxc" -le 4 ]; then ok
else bad "l0 in parallel: exit != 0, 'lock.roc: FAILED' with its output, $((n_unit - 1)) passes, sorted, 2 to 4 at one time (max seen: $maxc)"; head -n 70 $T/l0-par.out; fi

# Slice 022 (PLAN-P1 row 022, the harness): the `check` step runs its `roc check` calls in parallel, as l0 does (it was at 8.2 s of its 10 s budget). At most JOBS at one time. A file that fails fails the step, the other files
# still run, and each failure shows its output and the line `^^^ roc check <file> (exit <n>)`, in the order of the files (the report is not in the order in which the calls end).
n_apps=$(cd "$ROOT" && { echo cli/main.roc; echo cli/fxprobe.roc; echo cli/flowprobe.roc; echo cli/lib/main.roc; echo tests/commands/main.roc; ls packages/*/main.roc packages/*/tests/*.roc 2> /dev/null; ls tests/unit/*.roc; } | sort -u | wc -l)
n_fail=$(cd "$ROOT" && ls tests/unit/l*.roc | wc -l)
fx chk-par env JOBS=4 FAKE_ROC_SLEEP=0.1 FAKE_ROC_FAIL=tests/unit/l FAKE_ROC_CONC="$T/chk-par.conc" TAIL=1000 "$ROOT/scripts/test.sh" check
rc_par=$rc
maxc=$(sort -k1,1n -k2,2 "$T/chk-par.conc" 2> /dev/null | awk '{c += ($2 == "s") ? 1 : -1; if (c > m) m = c} END {print m + 0}')
marks=$(grep -o '^\^\^\^ roc check [^ ]* (exit 1)' $T/chk-par.out)
fx chk-ok env JOBS=4 FAKE_ROC_SLEEP=0.1 "$ROOT/scripts/test.sh" check
if [ $rc = 0 ] && grep -Eq '^check +pass' $T/chk-ok.out; then ok; else bad "check in parallel: all files pass, exit 0"; cat $T/chk-ok.out; fi
if [ $rc_par != 0 ] && [ "$(grep -c '^check ' $T/chk-par.log)" = "$n_apps" ] && grep -q '^== check: FAIL' $T/chk-par.out && [ "$(echo "$marks" | grep -c .)" = "$n_fail" ] &&
    [ "$marks" = "$(echo "$marks" | sort)" ] && [ "$(grep -c '^boom in tests/unit/l' $T/chk-par.out)" = "$n_fail" ] && [ "$maxc" -ge 2 ] && [ "$maxc" -le 4 ]; then ok
else bad "check in parallel: $n_apps roc check calls (also after a failure), '== check: FAIL', $n_fail failures with their output and '^^^ roc check <file> (exit 1)' in sorted order, 2 to 4 at one time (max seen: $maxc)"; head -n 60 $T/chk-par.out; fi

# TW26: a step over its budget gives a warning line, and the exit code stays 0. BUDGET_<STEP>=<s> sets the budget of a step,
# BUDGET_TOTAL=<s> the budget of the whole run (default 180, TW20).
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

# Slice 021 (review of slice 020, TW26): the budget warnings are for the fast set (OPT=dev) only. A run with OPT=speed (the merge run and the nightly run: LLVM builds, TW25) has no WARN line,
# also when a step and the whole run are over their budget, and its exit code and its table stay as they are. The control: the same run with OPT=dev warns.
fx bud-speed env OPT=speed FAKE_ROC_SLEEP=0.6 BUDGET_FMT=0.3 BUDGET_TOTAL=0.3 "$ROOT/scripts/test.sh" fmt
rc1=$rc
fx bud-dev env OPT=dev FAKE_ROC_SLEEP=0.6 BUDGET_FMT=0.3 BUDGET_TOTAL=0.3 "$ROOT/scripts/test.sh" fmt
rc2=$rc
if [ $rc1 = 0 ] && ! grep -q 'WARN' $T/bud-speed.out && grep -Eq '^fmt +pass +[0-9.]+' $T/bud-speed.out &&
    [ $rc2 = 0 ] && grep -q '^WARN fmt' $T/bud-dev.out && grep -q '^WARN total' $T/bud-dev.out; then ok
else bad "budget with OPT=speed: no WARN line (fmt and total are over), exit 0, the table of results stays. With OPT=dev: WARN fmt and WARN total."; cat $T/bud-speed.out $T/bud-dev.out; fi

# --- Slice 018b: CI jobs (TW20, TW25, TW27, TW28). The workflows cannot run here (no remote, no runner), so these rows read the files. ---
# tests/tools/ciscan.py reads the YAML subset of the workflow shape (docs/slices/018b-ci-jobs.md) and prints `FAIL: <reason>` lines.
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

# Slice 019 (G3 of slice 018b): get-roc.sh checks the sha256 of the download against the digest of the release API (R-CV3).
# A fake `gh` (first on PATH) gives the digest in FAKE_DIGEST and an archive that is not a real archive. A wrong digest: exit 1,
# `sha256 mismatch`, nothing installed. The control: the right digest passes the compare (the next step, tar, fails on the fake archive).
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

# TW27, TW28: the tag net (real network, nightly only). The fast set skips it. SLOW=1 and REAL_ROC=1 do not run it. NET=1 runs it.
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

rm -rf "$T"
echo "selftest: $pass passed, $fail failed"
[ $fail -eq 0 ]
