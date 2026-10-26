#!/usr/bin/env bash
# L3 runner: `tln` end to end with the real Fx, fake roc, a new dir on tmpfs and a fixed environment
# (TESTING.md 3). Usage: tests/run.sh [filter ...]
#   filter    a case path, or a part of it (`json/`, `unknown`). No filter: the fast set.
#   UPDATE=1  write the actual output to expect/ (TW21: only for outputs that the slice changes)
#   SLOW=1      also run the cases with the tag slow (TW27)
#   OPT=dev|speed    build mode of tln, fxprobe and flowprobe (default dev, TW25). Another value: exit 2
#   NET=1       also run the cases with the tag net (real network; the nightly run only, TW28). A net case has no network cut, and gets GITHUB_TOKEN and GH_TOKEN (slice 053)
#   REAL_CACHE=<dir>  the real roc cache that a case with the tag net or real-roc may copy (default ~/.cache/roc). The cases only copy it (slice 053).
#                     A case with the file `needs-real-cache` is skipped, with a SKIP line, when that dir does not exist.
#   REAL_ROC=1  also run the cases with the tag real-roc, with the pinned roc in place of the fake (L4)
#   SCENARIOS=<dir>  another case tree (the self-test of the runner uses it)
#   TLN=<file>       use this binary, do not build one
#   JOBS=<n>         cases at the same time (default: the CPU count)
#   BWRAP=0          do not cut the network with bwrap
#   CASE_TIMEOUT=<s> a case that runs longer fails (default 120)
# Case layout and rules: TESTING.md 3.1, 3.2. Expected files that are missing are empty (exit: 0).
# Extra to TESTING.md 3.2 (proposals of slice 001):
#   - given/roc.tsv: tab-separated rules, see tests/fakes/roc.
#   - stdout and stderr: `$HOME`, `$PROJECT` and `$WORK` stand for the dirs of the case.
#   - tag tty: the cmd runs under a pseudo terminal (tests/tools/ptyrun.py; with given/http/ it runs with the fake HTTP server, slice 025). stdout and stderr are one
#     stream, so expect/stdout has all the output and expect/stderr must be empty.
#     given/answers is the text that is typed in.
#   - the tags windows, exdev, slow (without SLOW=1), net (without NET=1) and real-roc (without REAL_ROC=1) are not in the fast set.
#   - expect/facts.tsv (slice 030): the rows of `home/.cache/roc/talon/compat.db` after the cmd (the dump of tests/tools/dumpdb.py, the line form of `Db.file_text`).
#     When the file is missing, the db is not compared. An empty file means that there is no db file. UPDATE=1 writes it, and removes it when the db is missing.
#   - expect/roc.log: when it is missing, the case expects no roc call.
#   - given/http/ (slice 003): routes for the fake HTTP server (tests/tools/fakehttp.py, the format is in its doc comment). The runner
#     starts one server for the case (tests/tools/with-http.sh), in the namespace of the case (the network is off, but the loopback
#     works in it). The cmd sees TALON_GITHUB_API, TALON_GITHUB_RAW and TALON_HTTP. `$PORT` stands for the port in all output and in
#     the tree diff. expect/http.log (optional) is the log of the requests: one line for each, in the order of arrival.
#   - the fake roc can run the pinned roc for a rule (the exit field `real`, tests/fakes/roc): `roc unbundle` has no fake.
set -u
SELF=$(cd "$(dirname "$0")" && pwd)
. "$SELF/../scripts/env.sh"
. "$SELF/lib.sh"
# The GNU timeout by its full path: the case runs under `env -i` with a PATH of its own (macOS: gtimeout, or a timeout in a gnubin dir that is not on that PATH).
for TIMEOUT_CMD in gnutimeout gtimeout timeout; do TIMEOUT_CMD=$(command -v "$TIMEOUT_CMD") && break; done
SCENARIOS=${SCENARIOS:-$SELF/scenarios}
# The real path of TMPDIR: macOS has a trailing slash (`T//`) and the link /var -> /private/var, so the path that a process reports (getcwd) would not be the path that normalize replaces.
CASEROOT=$(cd "${TMPDIR:-/tmp}" && pwd -P)/talon-test

# run_case <case dir>: run one case. Prints nothing on a pass. Prints the reasons on a failure.
# The exit code is 0 (pass), 1 (fail) or 2 (skipped).
run_case() {
    local dir=$1 name tags W
    name=${dir#"$SCENARIOS"/}
    tags=$(cat "$dir/tags" 2> /dev/null || true)
    for t in windows exdev; do
        case " $tags " in *" $t "*) return 2 ;; esac
    done
    case " $tags " in *" slow "*) [ "${SLOW:-0}" = 1 ] || return 2 ;; esac
    case " $tags " in *" real-roc "*) [ "${REAL_ROC:-0}" = 1 ] || return 2 ;; esac
    case " $tags " in *" net "*) [ "${NET:-0}" = 1 ] || return 2 ;; esac
    # Slice 053: a case with the file `needs-real-cache` copies the real roc cache. When that dir does not exist (the runner of the nightly run has none), the case is skipped with a reason.
    if [ -f "$dir/needs-real-cache" ] && [ ! -d "${REAL_CACHE:-$HOME/.cache/roc}" ]; then
        echo "no real roc cache: ${REAL_CACHE:-$HOME/.cache/roc} does not exist (set REAL_CACHE)"
        return 2
    fi

    W=$CASEROOT/$(echo "$name" | tr / _)
    rm -rf "$W"
    mkdir -p "$W/home" "$W/project" "$W/out" "$W/bin"
    [ -d "$dir/given" ] && cp -a "$dir/given/." "$W/"
    decode_names "$W" # %3F, %3A, %5C: the names that Windows refuses (tests/lib.sh)
    mkdir -p "$W/home" "$W/project" "$W/orig"
    cp -a "$W/home" "$W/orig/home"
    cp -a "$W/project" "$W/orig/project"

    # Fake roc first on PATH. With the tag real-roc, the pinned roc.
    if [[ " $tags " == *" real-roc "* ]]; then
        ln -s "$ROC" "$W/bin/roc"
    else
        ln -s "$SELF/fakes/roc" "$W/bin/roc"
    fi
    local envs=(
        "HOME=$W/home" "PATH=$W/bin:$BIN:/usr/bin:/bin"
        "XDG_CACHE_HOME=$W/home/.cache" "XDG_CONFIG_HOME=$W/home/.config" "XDG_DATA_HOME=$W/home/.local/share"
        "ROC_CACHE_DIR=$W/home/.cache/roc" "TALON_TEST_DIR=$W" "TZ=UTC" "LANG=C.UTF-8" "CI=true"
        "TALON_REGISTRY=direct" "TALON_TEST_REAL_ROC=$ROC"
    )
    case " $tags " in *" tty "*) envs+=("TALON_INTERACTIVE=1") ;; esac
    # Slice 053: the tag net is the one tag that needs the real network, so the case is not cut off (netoff), and it gets the token of the caller
    # (R-RG3: 60 requests an hour with no token). A case with the tag net or real-roc can copy a real roc cache (TALON_TEST_REAL_CACHE:
    # REAL_CACHE, else ~/.cache/roc of the caller). The case must only copy it, and work in the copy.
    local cut=netoff v
    case " $tags " in
    *" net "*)
        cut=env
        for v in GITHUB_TOKEN GH_TOKEN; do [ -n "${!v:-}" ] && envs+=("$v=${!v}"); done
        ;;
    esac
    case " $tags " in *" net "* | *" real-roc "*) envs+=("TALON_TEST_REAL_CACHE=${REAL_CACHE:-$HOME/.cache/roc}") ;; esac
    if [ -f "$W/env" ]; then
        while IFS= read -r line; do [ -n "$line" ] && envs+=("$line"); done < "$W/env"
    fi

    local cmdfile=$dir/cmd run
    if [[ " $tags " == *" tty "* ]]; then
        run=(python3 -I "$SELF/tools/ptyrun.py" "$W/answers" sh -e "$cmdfile")
        # Slice 025: a case with the tag tty and routes gets the fake HTTP server too (the pseudo terminal runs the server and the command).
        [ -d "$W/http" ] && run=(python3 -I "$SELF/tools/ptyrun.py" "$W/answers" "$SELF/tools/with-http.sh" "$W" "$SELF/fixtures" sh -e "$cmdfile")
    else
        # A case that hangs (a lock that waits for ever, slice 002) fails after CASE_TIMEOUT s with exit code 124.
        run=("$TIMEOUT_CMD" "${CASE_TIMEOUT:-120}" sh -e "$cmdfile")
        # A case with routes gets the fake HTTP server (slice 003). It runs inside the namespace of the case.
        [ -d "$W/http" ] && run=("$TIMEOUT_CMD" "${CASE_TIMEOUT:-120}" "$SELF/tools/with-http.sh" "$W" "$SELF/fixtures" sh -e "$cmdfile")
    fi
    (cd "$W/project" && $cut env -i "${envs[@]}" "${run[@]}" > "$W/out/stdout.raw" 2> "$W/out/stderr.raw" < /dev/null)
    echo $? > "$W/out/exit"
    normalize "$W" < "$W/out/stdout.raw" | hexnorm > "$W/out/stdout"
    normalize "$W" < "$W/out/stderr.raw" | hexnorm > "$W/out/stderr"
    tree_diff "$W" > "$W/out/tree.diff"
    dump_facts "$W" > "$W/out/facts.tsv"
    if [ -f "$W/roc.log" ]; then normalize "$W" < "$W/roc.log" | hexnorm > "$W/out/roc.log"; else : > "$W/out/roc.log"; fi
    if [ -f "$W/http.log" ]; then normalize "$W" < "$W/http.log" > "$W/out/http.log"; else : > "$W/out/http.log"; fi

    local ex=$dir/expect
    if [ "${UPDATE:-0}" = 1 ]; then
        update_file "$ex/stdout" "$W/out/stdout" optional
        update_file "$ex/stderr" "$W/out/stderr" optional
        update_file "$ex/exit" "$W/out/exit"
        update_file "$ex/tree.diff" "$W/out/tree.diff"
        update_file "$ex/roc.log" "$W/out/roc.log" optional
        update_file "$ex/facts.tsv" "$W/out/facts.tsv" optional
        update_file "$ex/http.log" "$W/out/http.log" optional
        return 0
    fi
    [ -f "$ex/exit" ] || echo 0 > "$W/out/exit.expected"
    [ -f "$ex/exit" ] && cp "$ex/exit" "$W/out/exit.expected"
    local fail=0 report=$W/out/report
    : > "$report"
    compare_file "exit code" "$W/out/exit.expected" "$W/out/exit" >> "$report" || fail=1
    compare_file "stdout" "$ex/stdout" "$W/out/stdout" >> "$report" || fail=1
    compare_file "stderr" "$ex/stderr" "$W/out/stderr" >> "$report" || fail=1
    compare_file "file tree" "$ex/tree.diff" "$W/out/tree.diff" >> "$report" || fail=1
    if [ -f "$ex/roc.log" ]; then
        compare_file "roc calls" "$ex/roc.log" "$W/out/roc.log" >> "$report" || fail=1
    elif [ -s "$W/out/roc.log" ]; then
        { echo "  unexpected roc call (the case has no expect/roc.log):"; sed -e 's/^/    /' "$W/out/roc.log"; } >> "$report"
        fail=1
    fi
    [ -f "$ex/facts.tsv" ] && { compare_file "compat.db rows" "$ex/facts.tsv" "$W/out/facts.tsv" >> "$report" || fail=1; }
    [ -f "$ex/http.log" ] && { compare_file "http requests" "$ex/http.log" "$W/out/http.log" >> "$report" || fail=1; }
    if [ $fail = 1 ]; then cat "$report"; return 1; fi
    return 0
}

if [ "${1:-}" = --case ]; then
    BIN=$2
    run_case "$3"
    exit $?
fi

check_opt
# Build `tln`, `fxprobe` and `flowprobe` once for the run.
BIN=$WORK/bin
if [ -z "${TLN:-}" ]; then
    "$ROC" build "$ROOT/cli/main.roc" --no-cache --opt="$OPT" --output="$BIN/tln" > "$WORK/build-tln.log" 2>&1 ||
        { echo "build of tln failed:"; cat "$WORK/build-tln.log"; exit 1; }
    "$ROC" build "$ROOT/cli/fxprobe.roc" --no-cache --opt="$OPT" --output="$BIN/fxprobe" > "$WORK/build-fxprobe.log" 2>&1 ||
        { echo "build of fxprobe failed:"; cat "$WORK/build-fxprobe.log"; exit 1; }
    "$ROC" build "$ROOT/cli/flowprobe.roc" --no-cache --opt="$OPT" --output="$BIN/flowprobe" > "$WORK/build-flowprobe.log" 2>&1 ||
        { echo "build of flowprobe failed:"; cat "$WORK/build-flowprobe.log"; exit 1; }
else
    BIN=$(dirname "$TLN")
fi

# Select the cases: each dir that has a `cmd` file, filtered by the arguments.
mapfile -t ALL < <(find "$SCENARIOS" -name cmd -type f -printf '%h\n' | sort)
CASES=()
for c in "${ALL[@]}"; do
    rel=${c#"$SCENARIOS"/}
    if [ $# -eq 0 ]; then CASES+=("$c"); continue; fi
    for f in "$@"; do
        case $rel in *"$f"*) CASES+=("$c"); break ;; esac
    done
done
if [ ${#CASES[@]} -eq 0 ]; then echo "scenarios: no case matches"; exit 1; fi

mkdir -p "$CASEROOT"
RESULTS=$(mktemp -d)
printf '%s\0' "${CASES[@]}" |
    xargs -0 -P "$(parallel_jobs)" -I{} bash -c '
        out=$("$0" --case "$1" "$2" 2>&1); rc=$?
        n=$(echo "${2#"$3"/}" | tr / _)
        printf "%s\n" "$out" > "$4/$n.out"; echo $rc > "$4/$n.rc"' "$0" "$BIN" {} "$SCENARIOS" "$RESULTS"

pass=0 failed=0 skipped=0
for c in "${CASES[@]}"; do
    rel=${c#"$SCENARIOS"/}
    n=$(echo "$rel" | tr / _)
    rc=$(cat "$RESULTS/$n.rc")
    case $rc in
    0) pass=$((pass + 1)) ;;
    2) skipped=$((skipped + 1)); [ -s "$RESULTS/$n.out" ] && echo "SKIP $rel: $(head -n 1 "$RESULTS/$n.out")" ;;
    *) failed=$((failed + 1)); echo "FAIL $rel"; sed -e 's/^/  /' "$RESULTS/$n.out" ;;
    esac
done
rm -rf "$RESULTS"
echo "scenarios: $pass passed, $failed failed, $skipped skipped"
[ $failed -eq 0 ]
