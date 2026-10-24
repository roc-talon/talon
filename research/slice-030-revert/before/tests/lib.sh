# Shared functions of the case runners (tests/run.sh for L3, tests/commands/run.sh for L2).
# Source it after scripts/env.sh. A case work dir `$W` holds:
#   home/ project/   the live state (copied from given/)
#   orig/home orig/project   the start state, for the tree diff
#   out/             what the case wrote (stdout, stderr, exit, calls.log, roc.log)

# normalize <W>: read stdin, write stdout. Paths of the work dir become $HOME, $PROJECT and $WORK,
# so expected files do not hold a machine path (TESTING.md 3.1).
# Slice 003: the port of the fake HTTP server (`<W>/http.port`) is `$PORT`, so an expected file has no port.
normalize() {
    local port=0
    [ -s "$1/http.port" ] && port=$(cat "$1/http.port")
    sed -e "s#$1/home#\$HOME#g" -e "s#$1/project#\$PROJECT#g" -e "s#$1#\$WORK#g" -e "s#127\.0\.0\.1:$port#127.0.0.1:\$PORT#g"
}

# hexnorm: read stdin, write stdout. The random name of a probe copy (`talon/tmp/<16hex>`, R-CC2) is `talon/tmp/$HEX`, so an expected file of L3 has no random text (slice 007).
# L2 does not use it: its fake `Fx` makes the same name each time (`fx/random`).
hexnorm() { sed -e 's#/talon/tmp/[0-9a-f]\{16\}#/talon/tmp/$HEX#g'; }

# tree_diff <W>: the change of home/ and project/ against orig/, as a unified diff with no times.
# Left out: compat.db, path-roc.json (slice 022b: it holds the size and the mtime of files of the machine), a dir or file named tmp, and files that end in .tmp (TESTING.md 3.1).
# The paths of the work dir in the file content are `$HOME`, `$PROJECT` and `$WORK` (slice 002: `projects.json` has paths).
tree_diff() {
    (cd "$1" && diff -rNu -x compat.db -x path-roc.json -x tmp -x '*.tmp' orig/home home
        diff -rNu -x compat.db -x path-roc.json -x tmp -x '*.tmp' orig/project project) |
        sed -e 's#^\(---\|+++\) orig/#\1 #' -e 's#^\(---\|+++\) \([^	]*\)	.*$#\1 \2#' \
            -e '/^diff -rNu /d' | normalize "$1"
}

# compare_file <label> <expected file> <actual file>: prints a diff and returns 1 on a difference.
# A missing expected file is an empty file.
compare_file() {
    local label=$1 expected=$2 actual=$3
    [ -f "$expected" ] || expected=/dev/null
    if ! diff -u --label expected --label actual "$expected" "$actual" > "$actual.diff"; then
        echo "  $label differs (- expected, + actual):"
        sed -e 's/^/    /' "$actual.diff"
        return 1
    fi
    return 0
}

# update_file <expected file> <actual file>: UPDATE=1. An empty actual file for an optional file removes it.
update_file() {
    local expected=$1 actual=$2 optional=${3:-}
    if [ -n "$optional" ] && [ ! -s "$actual" ]; then
        rm -f "$expected"
    else
        mkdir -p "$(dirname "$expected")"
        cp "$actual" "$expected"
    fi
}

# netoff <cmd...>: run with no network when bwrap works (BWRAP=0 turns it off). Else run plain.
netoff() {
    if [ "${BWRAP:-1}" != 0 ] && command -v bwrap > /dev/null 2>&1 &&
        bwrap --dev-bind / / --unshare-net true > /dev/null 2>&1; then
        bwrap --dev-bind / / --unshare-net "$@"
    else
        "$@"
    fi
}

# parallel_jobs: how many cases run at the same time.
parallel_jobs() { echo "${JOBS:-$(nproc 2> /dev/null || echo 4)}"; }

# check_opt: the build mode of the test binaries (TW25). OPT is dev (default) or speed. Another value: exit 2, before any build.
check_opt() {
    OPT=${OPT:-dev}
    case $OPT in
    dev | speed) export OPT ;;
    *) echo "OPT must be dev or speed (got: $OPT)" >&2; exit 2 ;;
    esac
}

# --- Memory rule of scripts/test.sh (research/test-memory/RESULTS.md) ---
# jobs_for <cores> <budget_mb> <reserve_mb> <per_job_mb>: how many jobs fit. min(cores, (budget - reserve) / per_job), never under 1. A pure function.
jobs_for() {
    awk -v c="$1" -v b="$2" -v r="$3" -v p="$4" 'BEGIN { n = int((b - r) / p); if (n > c) n = c; if (n < 1) n = 1; print n }'
}
# mem_budget_mb: the memory that one run may use. TEST_MEM_GB, or a third of MemAvailable (Linux), or 8 GB when the machine does not say.
mem_budget_mb() {
    if [ -n "${TEST_MEM_GB:-}" ]; then
        awk -v g="$TEST_MEM_GB" 'BEGIN { printf "%d\n", g * 1024 }'
    else
        awk '/^MemAvailable:/ { printf "%d\n", $2 / 1024 / 3; f = 1 } END { if (!f) print 8192 }' /proc/meminfo 2> /dev/null || echo 8192
    fi
}
# roc_jobs <reserve_mb> <per_job_mb>: jobs for the `roc` calls of a step. JOBS caps it (default: the CPU count).
roc_jobs() { jobs_for "$(parallel_jobs)" "$(mem_budget_mb)" "$1" "$2"; }
# prune_roc_objects: `roc check` and `roc build` read every file of the object cache (objects-v7) into memory, so the cost grows with the cache:
# 11 GB of files gave 14 GB RSS and 3.7 s for `roc check cli/main.roc` (0.3 s and 0.5 GB with none). Each edit of cli/lib adds a 13 MB file.
# Keep the OBJ_KEEP (default 3) newest files of each dir. A file under 10 minutes old stays, so a run at the same time does not lose its file.
prune_roc_objects() {
    local o d f keep=${OBJ_KEEP:-3} old
    for o in "${ROC_CACHE_DIR:-/nonexistent}"/compat-*/objects-v7; do
        [ -d "$o" ] || continue
        while IFS= read -r d; do
            old=()
            while IFS= read -r f; do old+=("$f"); done < <(find "$d" -maxdepth 1 -type f -mmin +10)
            [ ${#old[@]} -gt "$keep" ] || continue
            ls -t -- "${old[@]}" | tail -n +$((keep + 1)) | while IFS= read -r f; do rm -f -- "$f"; done
        done < <(find "$o" -type d)
    done
}
