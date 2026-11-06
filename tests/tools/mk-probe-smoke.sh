#!/usr/bin/env bash
# Makes the given/ and fx/ files of the L2 cases `probe/sm1` to `sm8` (slice 218b: `tln probe --smoke`). The expect/ files are not made here.
# Usage: tests/tools/mk-probe-smoke.sh   (run from anywhere; it rewrites the given/ and fx/ dirs of the 8 cases)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CASES=$ROOT/tests/commands/cases/probe
PFX=9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK
PFZ=CPn9GfheMVLVbuEhuXk81TvvfeswKFFB4cAYUuvg57p2
JSON=4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq
PFX_URL=https://github.com/acme/pfx/releases/download/0.1.1/$PFX.tar.zst
PFZ_URL=https://github.com/acme/pfz/releases/download/0.3.0/$PFZ.tar.zst
JSON_URL=https://github.com/acme/json/releases/download/2.1.0/$JSON.tar.zst

# A platform header with the targets of its arguments, in this order.
platform_header() {
    printf 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n\ttargets: {\n\t\tinputs_dir: "targets/",\n'
    for t in "$@"; do
        case $t in
        wasm32) printf '\t\twasm32: { inputs: ["host.wasm", app] },\n' ;;
        *) printf '\t\t%s: { inputs: ["crt1.o", "libhost.a", "libunwind.a", app, "libc.a"] },\n' "$t" ;;
        esac
    done
    printf '\t}\n'
}

# world <case> <packages: pfx|none>: the project p1 (a platform entry pf and a package entry json), the config, the held roc on PATH.
world() {
    local d=$CASES/$1
    rm -rf "$d/given" "$d/fx"
    mkdir -p "$d/given/home/.config/talon" "$d/given/home/.cache/roc/talon" "$d/given/home/.cache/roc/packages/$PFX" "$d/given/home/.cache/roc/packages/$JSON" "$d/given/project/p1" "$d/fx"
    printf '[probe]\ntimeout = 9\n' > "$d/given/home/.config/talon/config.toml"
    printf 'app [main!] {\n\tpf: platform "%s",\n\tjson: "%s",\n}\n\nmain! = |_args| Ok({})\n' "$PFX_URL" "$JSON_URL" > "$d/given/project/p1/main.roc"
    platform_header x64musl arm64musl x64glibc wasm32 > "$d/given/home/.cache/roc/packages/$PFX/main.roc"
    printf 'package [Lib] {}\n' > "$d/given/home/.cache/roc/packages/$JSON/main.roc"
    printf 'HOME={w}/home\nTALON_NOW=2026-10-20T12:00:00Z\n' > "$d/fx/env"
    printf '# a tln of 5000 bytes and a roc of 1000 bytes (no file is hashed)\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n' > "$d/fx/path-roc"
    printf 'version\t0\tRoc compiler version nightly-2026-10-14-38a3029\t-\t-\n' > "$d/fx/jobs"
    printf 'roc\n' > "$d/fx/programs"
    printf '.\n' > "$d/fx/gitdirs"
    printf 'format\t1\n' > "$d/given/home/.cache/roc/talon/compat.tsv"
}

# toolchain <case> <id>: an installed compiler (a file `roc` and its sidecar).
toolchain() {
    local t=$CASES/$1/given/home/.cache/roc/toolchains/$2
    mkdir -p "$t"
    printf '#!fake\n' > "$t/roc"
    printf '{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":null,"installed_at":"2026-10-12T12:00:00Z","published_at":"2026-10-12T15:00:00Z"}' "$2" "$2" "$2" > "$t/.talon.json"
}

# sm1: the URL of a platform in packages/, no --target: the 4 targets of the header, 4 results, the key of the first one is in the table already.
world sm1-url-targets
echo commands > $CASES/sm1-url-targets/entry
printf 'probe --smoke %s\n' "$PFX_URL" > $CASES/sm1-url-targets/fx/commands
# no project at all (Q591): the project dir is empty and no dir is a git dir
rm -rf $CASES/sm1-url-targets/given/project $CASES/sm1-url-targets/fx/gitdirs
mkdir -p $CASES/sm1-url-targets/given/project
: > $CASES/sm1-url-targets/given/project/.keep
: > $CASES/sm1-url-targets/fx/gitdirs
# the keys of x64musl (the same result as the new build) and of arm64musl (another result: the row stays, Q589)
printf '%s\tnightly-2026-10-14-38a3029\tx64musl\tpass\n%s\tnightly-2026-10-14-38a3029\tarm64musl\tpass\n' "$PFX" "$PFX" > $CASES/sm1-url-targets/given/home/.cache/roc/talon/smoke.tsv
cat > $CASES/sm1-url-targets/fx/probes <<'X'
# the 4 smoke builds of run 1, in the order of the header targets: x64musl pass, arm64musl fail, x64glibc no end in probe.timeout, wasm32 SIGSEGV
0	../fixtures/check/out/build-pass.stdout	../fixtures/check/out/build-pass.stderr
1	-	../fixtures/check/out/build-target.stderr
timeout	-	-
signal:11	-	-
X

# sm2: --target in the order of the line, --json, ROC_TOOLCHAIN (the compiler of the bot), then one target.
world sm2-json-order
echo commands > $CASES/sm2-json-order/entry
toolchain sm2-json-order nightly-2026-10-12-2664a27
printf 'probe --smoke %s --target arm64musl --target x64musl --json env:ROC_TOOLCHAIN=nightly-2026-10-12-2664a27\nprobe --smoke %s --target wasm32 env:ROC_TOOLCHAIN=nightly-2026-10-12-2664a27\n' "$PFX_URL" "$PFX_URL" > $CASES/sm2-json-order/fx/commands
cat > $CASES/sm2-json-order/fx/probes <<'X'
# run 1: arm64musl (the first --target) hang, x64musl pass. Run 2: wasm32 pass
timeout	-	-
0	../fixtures/check/out/build-pass.stdout	../fixtures/check/out/build-pass.stderr
0	../fixtures/check/out/build-pass.stdout	../fixtures/check/out/build-pass.stderr
X

# sm3: a URL that is not in packages/: the download and the unbundle, then the build; run 2 has a hash mismatch (exit 16).
world sm3-fetch
echo commands > $CASES/sm3-fetch/entry
mkdir -p $CASES/sm3-fetch/fx/pkgs
platform_header x64musl arm64musl > $CASES/sm3-fetch/fx/pkgs/pfz.hdr
BAD=2B3sC6U2dWkVUK2VY2gJS5Wej9YCDo3ZYq2e7tMWUCNp
BAD_URL=https://github.com/acme/pfw/releases/download/0.4.0/$BAD.tar.zst
printf 'probe --smoke %s\nprobe --smoke %s\n' "$PFZ_URL" "$BAD_URL" > $CASES/sm3-fetch/fx/commands
printf 'roc\ncurl\n' > $CASES/sm3-fetch/fx/programs
cat >> $CASES/sm3-fetch/fx/jobs <<X
# the unbundle of run 1 gives a platform header; the unbundle of run 2 says that the hash is wrong (R-FE2)
unbundle $PFZ.tar.zst	0	-	-	dir:{cwd}/$PFZ;copy:{cwd}/$PFZ/main.roc={w}/fx/pkgs/pfz.hdr
unbundle $BAD.tar.zst	1	-	Error: Hash mismatch	-
$PFZ.tar.zst	0	-	-	file:{w}/home/.cache/roc/packages/$PFZ.0123456789abcdef.tmp/$PFZ.tar.zst
$BAD.tar.zst	0	-	-	file:{w}/home/.cache/roc/packages/$BAD.0123456789abcdef.tmp/$BAD.tar.zst
X

# sm4: a header alias: the platform entry pf (the smoke app has its URL), then a package, a name that is not in the project.
world sm4-alias
echo commands > $CASES/sm4-alias/entry
printf 'probe --smoke pf --target x64musl --file p1/main.roc\nprobe --smoke json --file p1/main.roc\nprobe --smoke nope --file p1/main.roc\n' > $CASES/sm4-alias/fx/commands
printf '# run 1: x64musl pass\n0\t../fixtures/check/out/build-pass.stdout\t../fixtures/check/out/build-pass.stderr\n' > $CASES/sm4-alias/fx/probes

# sm5: the usage stops (exit 2), one fault in each run: no operand, --range, --share, a bundle file, 2 operands, --target with no --smoke, a target that the platform has not, the URL of a package, a URL with no version, a URL with --file, a platform with no target.
world sm5-usage
NOT=8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f
NOT_URL=https://github.com/acme/pfn/releases/download/0.5.0/$NOT.tar.zst
mkdir -p $CASES/sm5-usage/given/home/.cache/roc/packages/$NOT
printf 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n' > $CASES/sm5-usage/given/home/.cache/roc/packages/$NOT/main.roc
echo commands > $CASES/sm5-usage/entry
cat > $CASES/sm5-usage/fx/commands <<X
probe --smoke --file p1/main.roc
probe --smoke $PFX_URL --range
probe --smoke $PFX_URL --share
probe --smoke out/$PFX.tar.zst --file p1/main.roc
probe --smoke $PFX_URL pf
probe json --target x64musl --file p1/main.roc
probe --smoke $PFX_URL --target x64musl --target riscv
probe --smoke $JSON_URL
probe --smoke https://github.com/acme/pfx/releases/download/latest/$PFX.tar.zst
probe --smoke $PFX_URL --file p1/main.roc
probe --smoke $NOT_URL
X

# sm6: a build with no fact and a machine error (Q590). Run 1: x64musl passes, arm64musl is killed by SIGKILL (no fact): exit 1, --json: data null, error.details.smoke has the whole list, the row of x64musl is written. Run 2: a machine error alone: exit 0.
world sm6-no-fact
echo commands > $CASES/sm6-no-fact/entry
cp "$ROOT/tests/commands/cases/share/sh74-smoke-machine-error/fx/smoke-sdk.stderr" $CASES/sm6-no-fact/fx/
printf 'probe --smoke %s --target x64musl --target arm64musl --json\nprobe --smoke %s --target wasm32\n' "$PFX_URL" "$PFX_URL" > $CASES/sm6-no-fact/fx/commands
cat > $CASES/sm6-no-fact/fx/probes <<'X'
# run 1: x64musl pass, arm64musl SIGKILL. Run 2: wasm32 a machine error on stderr (the build itself passes: the line decides)
0	../fixtures/check/out/build-pass.stdout	../fixtures/check/out/build-pass.stderr
signal:9	-	-
0	../fixtures/check/out/pass.stdout	smoke-sdk.stderr
X

# sm7: a platform whose requires clause gives no smoke app (2 entries, R-SM2): no build, no temp dir, no row; each target is `no-smoke-app`, exit 0 (Q598).
world sm7-no-smoke-app
echo commands > $CASES/sm7-no-smoke-app/entry
PFQ=CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA
PFQ_URL=https://github.com/acme/pfq/releases/download/0.6.0/$PFQ.tar.zst
mkdir -p $CASES/sm7-no-smoke-app/given/home/.cache/roc/packages/$PFQ
platform_header x64musl arm64musl | sed 's/requires {} { main! : () => {} }/requires {} { main! : () => {}, helper! : Str => {} }/' > $CASES/sm7-no-smoke-app/given/home/.cache/roc/packages/$PFQ/main.roc
printf 'probe --smoke %s --json\nprobe --smoke %s --target arm64musl\n' "$PFQ_URL" "$PFQ_URL" > $CASES/sm7-no-smoke-app/fx/commands

# sm8: no compiler is selected (no ROC_TOOLCHAIN, no default-roc, nothing installed, no roc on PATH): R-SO14 (1) with the platform of the URL as the package (Q597). Run 1: no flag and no prompt: exit 13, no download. Run 2: TALON_AUTO_INSTALL=yes: the latest compiler of the channel is downloaded, set as default-roc, and the smoke build runs with it.
world sm8-no-compiler
echo commands > $CASES/sm8-no-compiler/entry
printf '# a tln of 5000 bytes, and no roc on PATH\nexe /fake/bin/tln 5000 1700000000\n' > $CASES/sm8-no-compiler/fx/path-roc
printf 'curl\ntar\n' > $CASES/sm8-no-compiler/fx/programs
printf 'HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n' > $CASES/sm8-no-compiler/fx/env
cat > $CASES/sm8-no-compiler/fx/jobs <<'X'
# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod (as init/it4-nocompiler). The first rule whose needle is in the arguments answers.
curl --fail	0	-	-	file:{out}
tar -xf	0	-	-	file:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details
chmod 0755	0	-	-	-
X
mkdir -p $CASES/sm8-no-compiler/fx/http/api.github.com/repos/roc-lang/nightlies
cp "$ROOT/tests/commands/cases/init/it4-nocompiler/fx/http/api.github.com/repos/roc-lang/nightlies/releases%3Fper_page=100" $CASES/sm8-no-compiler/fx/http/api.github.com/repos/roc-lang/nightlies/
printf 'probe --smoke %s\nprobe --smoke %s env:TALON_AUTO_INSTALL=yes\n' "$PFX_URL" "$PFX_URL" > $CASES/sm8-no-compiler/fx/commands
printf '0\t../fixtures/check/out/build-pass.stdout\t../fixtures/check/out/build-pass.stderr\n' > $CASES/sm8-no-compiler/fx/probes
