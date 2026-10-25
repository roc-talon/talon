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
# Left out: compat.db and its WAL files compat.db-wal and compat.db-shm (slice 030: a process that ends leaves them, the rows are in `expect/facts.tsv`), path-roc.json (slice 022b: it holds the size and the mtime of files of the machine), a dir or file named tmp, and files that end in .tmp (TESTING.md 3.1).
# The paths of the work dir in the file content are `$HOME`, `$PROJECT` and `$WORK` (slice 002: `projects.json` has paths).
tree_diff() {
    (cd "$1" && diff -rNu -x 'compat.db*' -x path-roc.json -x tmp -x '*.tmp' orig/home home
        diff -rNu -x 'compat.db*' -x path-roc.json -x tmp -x '*.tmp' orig/project project) |
        sed -e 's#^\(---\|+++\) orig/#\1 #' -e 's#^\(---\|+++\) \([^	]*\)	.*$#\1 \2#' \
            -e '/^diff -rNu /d' | normalize "$1"
}

# dump_facts <W>: the rows of `home/.cache/roc/talon/compat.db` as text, for `expect/facts.tsv` (slice 030). `tests/tools/dumpdb.py` has the form. No db file: no output.
dump_facts() { python3 -I "$(dirname "${BASH_SOURCE[0]}")/tools/dumpdb.py" "$1/home/.cache/roc/talon/compat.db"; }

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

# --- The l0 files (research/l0-time/RESULTS.md) ---
# Each `roc test` process compiles the modules that it imports again, so one process for each unit file cost 43 s of CPU for 86 files. A unit file in tests/unit is a unit module (`<Name>Test.roc`,
# no header, a type `<Name>Test :: [].{}`), and a few drivers (`tests/unit/l0-<n>.roc`, apps that import the modules) run them: 8 processes, 25 s of CPU.
# unit_is_app <file>: the first line of the file starts with `app `. The loops below use no process for a file (82 files: 1 s with `head` and `grep`, 0.05 s with `read`).
unit_is_app() { local first; IFS= read -r first < "$1" && [[ $first == app\ * ]]; }
# unit_files: the files that the l0 step gives to `roc test`: the apps of tests/unit (the drivers) and the tests of the packages. Run it in the root of the repo.
unit_files() {
    local f
    for f in tests/unit/*.roc; do
        [ -f "$f" ] && unit_is_app "$f" && echo "$f"
    done
    ls packages/*/tests/*.roc 2> /dev/null
    return 0
}
# unit_modules_check <dir>: every unit module of the dir (a file that is not an app) is imported by exactly one app of the dir. A module that no driver imports is never run, and `roc test` says nothing.
# Prints one line for each fault. Exit 1 when there is a fault.
unit_modules_check() {
    local f n c line rc=0 drivers=() mods=()
    local -A seen
    for f in "$1"/*.roc; do
        [ -f "$f" ] || continue
        if unit_is_app "$f"; then drivers+=("$f"); else mods+=("$f"); fi
    done
    if [ ${#drivers[@]} -gt 0 ]; then
        while IFS= read -r line; do seen[$line]=$((${seen[$line]:-0} + 1)); done < <(grep -hx 'import [A-Za-z0-9_]*' "${drivers[@]}")
    fi
    for f in ${mods[@]+"${mods[@]}"}; do
        n=${f##*/}
        n=${n%.roc}
        c=${seen["import $n"]:-0}
        if [ "$c" != 1 ]; then
            echo "l0: $f: $c drivers import $n (it must be 1: add \`import $n\` to the driver with the smallest time in \$WORK/l0-times)"
            rc=1
        fi
    done
    return $rc
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
