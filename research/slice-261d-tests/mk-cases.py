#!/usr/bin/env python3
# Slice 261d (test agent): makes the inputs of the L2 cases tests/commands/cases/logproof/lp16* (tools) and lp17* (compilers) from 3 old cases
# (registry/sc3-tool-install, registry/sc4-x-registry, registry/cv1-roc-default) and the fake logs with tests/tools/mk-log.mjs (test seeds only).
# It writes no expected file: mk-expect.py writes them by hand rules (docs/slices/261-log-inclusion-proofs.md section 16).
# Usage (repo root): python3 research/slice-261d-tests/mk-cases.py
import json, os, shutil, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tests/commands/cases")
OUT = os.path.join(CASES, "logproof")
TOOL_BASE = os.path.join(CASES, "registry/sc3-tool-install")
X_BASE = os.path.join(CASES, "registry/sc4-x-registry")
ROC_BASE = os.path.join(CASES, "registry/cv1-roc-default")

FOO = "github.com/acme/foo/releases/download/{v}/"
# registry/sc3-tool-install: the R-AP1 rows of acme/foo (log index: version, hash).
FOO_ROWS = {"1": ("1.3.0", "GBpEiN5EZocwzciidF98rcP3ADa2Auqako4sfwRm6R7R"), "2": ("1.2.0", "AuoSBcU9ixCmSt4rKTZpZ4eVbXY1E4Qqh4Kpw2odg7Gc"),
            "3": ("1.1.0", "AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY"), "4": ("1.0.0", "GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW")}
TOOL_LEAVES = {i: f"{FOO} {v} {h} 1788264000000" for i, (v, h) in FOO_ROWS.items()}
# registry/sc4-x-registry: 1.1.0 is log index 1, 1.0.0 is log index 2.
X_LEAVES = {"1": f"{FOO} 1.1.0 AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY 1788264000000", "2": f"{FOO} 1.0.0 GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW 1785585600000"}
OTHER = "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK"
# registry/cv1-roc-default: the 3 toolchain rows (log index 10, 20, 30), one sha256.
SHA = "b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78"
SHA_OTHER = "0000000000000000000000000000000000000000000000000000000000000000"
NIGHTLY = "roc-lang/nightlies:linux_x86_64"
ROC_LEAVES = {"10": f"{NIGHTLY} nightly-2026-10-12-2664a27 sha256:{SHA} 1791817200000", "20": f"{NIGHTLY} nightly-2026-10-13-91fa0c2 sha256:{SHA} 1791903600000",
              "30": f"{NIGHTLY} nightly-2026-10-17-601b54c sha256:{SHA} 1792249200000"}


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def case(name, base, commands, rules, spec):
    d = os.path.join(OUT, name)
    keep = os.path.join(OUT, f".{name}.expect")
    if os.path.isdir(os.path.join(d, "expect")):
        shutil.move(os.path.join(d, "expect"), keep)  # the expected files stay (mk-expect.py writes them)
    if os.path.isdir(d):
        shutil.rmtree(d)
    shutil.copytree(base, d, ignore=shutil.ignore_patterns("expect", "rules"))
    if os.path.isdir(keep):
        shutil.move(keep, os.path.join(d, "expect"))
    put(os.path.join(d, "fx/commands"), "".join(c + "\n" for c in commands))
    put(os.path.join(d, "rules"), rules + "\n")
    put(os.path.join(d, "mk-log.json"), json.dumps(spec, indent=1) + "\n")
    line = subprocess.run(["node", os.path.join(ROOT, "tests/tools/mk-log.mjs"), d], check=True, capture_output=True, text=True).stdout.strip()
    put(os.path.join(d, "fx/env"), open(os.path.join(d, "fx/env")).read() + line + "\n")


def log(leaves, size, **extra):
    return {"host": "127.0.0.1:9", "leaves": leaves, "serve": [{"file": "checkpoint", "size": size}], **extra}


TOOL_W = "the world of registry/sc3-tool-install: `tln tool install acme/foo` with the registry http://127.0.0.1:9 of config.toml; R-AP1 gives 1.3.0 (log index 1), 1.2.0 (2), 1.1.0 (3), 1.0.0 (4); 1.2.0 is not an app (R-T10), so the release that tools.json gets is 1.1.0, log index 3"
ROC_W = "the world of registry/cv1-roc-default: the compiler list is GET /v1/toolchains?after=0 of the registry http://127.0.0.1:9 of config.toml (rows nightly-2026-10-12-2664a27, log index 10; nightly-2026-10-13-91fa0c2, 20; nightly-2026-10-17-601b54c, 30); no compiler is installed"
KEY = "TALON_LOG_KEY is the test key with the name 127.0.0.1:9/log (tests/tools/mk-log.mjs, mk-log.json)"
WHERE_TOOL = "The check (calls of section 14.3) runs after the bundle of the first app is read (`first_app!`, the end of the pick of R-T10) and before the platform fetch, the build and any write of tools.json (R-LV8, Q261d-1)"
WHERE_ROC = "The check (calls of section 14.3) runs after the list and the digest check of `RocInstall.offer_noted!` (step 6) and before the download prompt, the lock and the download (R-LV1: before the download; R-LV8: before the prompts)"

case("lp16-tool", TOOL_BASE, ["tool install acme/foo", "tool install acme/foo"],
     f"R-LV1 R-LV2 R-LV3 R-LV6 R-LV7 R-LV8 R-LV12 R-IX8 (slice 261d, entry `commands`; {TOOL_W}). {KEY}. The log has size 4. {WHERE_TOOL}. "
     "Run 1: one checkpoint read, the entry bundle and the level 0 tile with http_get_bytes, one write of the copies and the checkpoint; the output of registry/sc3-tool-install (R-LV12: no new line). "
     "Run 2: foo 1.1.0 is installed (`ToolInstall.reuse` gives Keep): no log call (R-LV1: only a release that the command writes).",
     log(TOOL_LEAVES, 4))
case("lp16b-tool-entry-differs", TOOL_BASE, ["tool install acme/foo"],
     f"R-LV2 R-LV11 R-LV12 (slice 261d, entry `commands`; {TOOL_W}). {KEY}. The leaf at log index 3 has another hash. {WHERE_TOOL}. Exit 16, T1 with `<release>` = `tool acme/foo 1.1.0`; no build, tools.json and the bin dir are not written, no log copy.",
     log({**TOOL_LEAVES, "3": f"{FOO} 1.1.0 {OTHER} 1788264000000"}, 4))
case("lp16c-tool-not-included", TOOL_BASE, ["tool install acme/foo --json"],
     f"R-LV3 R-LV11 R-LV12 (slice 261d, entry `commands`; {TOOL_W}). {KEY}. Byte 64 of the served level 0 tile (the hash of tlog index 2) is changed. {WHERE_TOOL}. Exit 16, T2; --json: `error.details` with `release` the release URL (CLI 3 catalog); no build, no write.",
     log(TOOL_LEAVES, 4, tamper=[{"path": "tile/0/000.p/4", "byte": 64}]))
case("lp16d-x", X_BASE, ["x acme/foo -- a b"],
     "R-LV1 R-LV2 R-LV3 R-LV7 R-LV8 R-LV12 (slice 261d, entry `commands`; the world of registry/sc4-x-registry: `tln x acme/foo -- a b` with the registry http://127.0.0.1:9, R-AP1 gives 1.1.0 (log index 1) and 1.0.0 (2), no x entry matches, so 1.1.0 is built). "
     f"{KEY}. The log has size 2. The check runs after the bundle of the app is read and before the platform fetch and the build (R-LV1 names `x`; Q261d-1). The output of registry/sc4-x-registry (R-LV12).",
     log(X_LEAVES, 2))
case("lp17-compiler", ROC_BASE, ["roc install nightly-2026-10-13-91fa0c2", "roc install nightly-2026-10-13-91fa0c2"],
     f"R-LV1 R-LV2 R-LV3 R-LV7 R-LV8 R-LV12 R-SE11 (slice 261d, Design Q640 (3), entry `commands`; {ROC_W}). {KEY}. The log has size 30; the leaves are R-SG3 compiler leaves. {WHERE_ROC}. "
     "Run 1: the leaf at log index 20 (`roc-lang/nightlies:linux_x86_64 nightly-2026-10-13-91fa0c2 sha256:<hex>`) is proved, the copies and the checkpoint are written, then the prompt and the install as in registry/cv1-roc-default (R-LV12: no new line). "
     "Run 2: the compiler is installed (`Present`): no log call (R-LV1: a compiler that Talon installs).",
     log(ROC_LEAVES, 30))
case("lp17b-compiler-entry-differs", ROC_BASE, ["roc install nightly-2026-10-13-91fa0c2"],
     f"R-LV2 R-LV11 R-LV12 R-SE11 (slice 261d, entry `commands`; {ROC_W}). {KEY}. The leaf at log index 20 has another sha256. {WHERE_ROC}. Exit 16, T1 with `<release>` = `nightly-2026-10-13-91fa0c2 (linux_x86_64)`; no prompt, no download, no log copy.",
     log({**ROC_LEAVES, "20": f"{NIGHTLY} nightly-2026-10-13-91fa0c2 sha256:{SHA_OTHER} 1791903600000"}, 30))
case("lp17c-compiler-not-included", ROC_BASE, ["roc install nightly-2026-10-13-91fa0c2 --json"],
     f"R-LV3 R-LV11 R-LV12 R-SE11 (slice 261d, entry `commands`; {ROC_W}). {KEY}. Byte 608 of the served level 0 tile (the hash of tlog index 19) is changed. {WHERE_ROC}. Exit 16, T2; --json: `error.details` with `release` the compiler tag (CLI 3 catalog); no prompt, no download, no write.",
     log(ROC_LEAVES, 30, tamper=[{"path": "tile/0/000.p/30", "byte": 608}]))
case("lp17d-roc-update", ROC_BASE, ["roc update"],
     f"R-LV1 R-LV2 R-LV3 R-LV7 R-LV8 R-LV12 R-SE11 (slice 261d, entry `commands`; {ROC_W}). {KEY}. `tln roc update` picks the newest allowed compiler nightly-2026-10-17-601b54c (log index 30), a call site of `RocInstall.offer_noted!` other than `roc install`. {WHERE_ROC}. Exit 0, the output of the update (R-LV12).",
     log(ROC_LEAVES, 30))

# Q261d-2 (a), the user 2026-11-24: a take-over of an x entry by `tool install` (XTake.online!) checks the R-AP1 row of the URL that tools.json gets.
XHIT = ".cache/roc/talon/x/12a9a07e3bfad229b786f055419c9cd6824c28c2835865525c4c3d2b5cdfa2c7"
XMAN = ('{"format":1,"name":"acme/foo","source":{"kind":"release","version":"1.1.0","url":"https://github.com/acme/foo/releases/download/1.1.0/AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY.tar.zst"},'
        '"build":{"hashes":["CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA","3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"],"nightly":"nightly-2026-10-14-38a3029","target":"x64musl"},'
        '"sha256":"b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78","libs":[],"bundle":"AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY","last_run":"2026-10-15T12:00:00Z"}')
TAKE_W = ("the world of registry/sc4-x-registry with the x entry of acme/foo 1.1.0 that logproof/lp16d-x builds (manifest and binary in given/home): `tln tool install acme/foo` with the registry "
          "http://127.0.0.1:9; R-AP1 gives 1.1.0 (log index 1) and 1.0.0 (2); the x entry matches the newest release, so the tool is taken over (XTake.online!, R-B3, R-B4), with no download")
WHERE_TAKE = "The check (calls of section 14.3) runs after the x entry is chosen and before `take!` (the bin dir check, the lock of tools.json, the move and the write) (Q261d-2 (a))"
for name, leaves, cmds, text in [
    ("lp16e-takeover", X_LEAVES, ["tool install acme/foo"], "Exit 0: the copies and the checkpoint are written, then the take-over as before (R-LV12: no new line)."),
    ("lp16f-takeover-entry-differs", {**X_LEAVES, "1": f"{FOO} 1.1.0 {OTHER} 1788264000000"}, ["tool install acme/foo"],
     "The leaf at log index 1 has another hash: exit 16, T1 with `tool acme/foo 1.1.0`; the x entry is not moved, tools.json and the bin dir are not written, no log copy."),
]:
    case(name, X_BASE, cmds, f"R-LV1 R-LV2 R-LV3 R-LV7 R-LV8 R-LV11 R-LV12 (slice 261d, Q261d-2 (a), entry `commands`; {TAKE_W}). {KEY}. The log has size 2. {WHERE_TAKE}. {text}", log(leaves, 2))
    d = os.path.join(OUT, name, "given/home", XHIT)
    put(os.path.join(d, "manifest.json"), XMAN)
    put(os.path.join(d, "foo"), "fake")

# Gap test of the mutation check (section 16.10): a row of the same tag for another target, with a smaller log index and a valid leaf. The check must take the row of the host target.
MAC_ROW = ('{"tag":"nightly-2026-10-13-91fa0c2","target":"macos_apple_silicon","asset_name":"roc_nightly-macos_apple_silicon-2026-10-13-91fa0c2.tar.gz",'
           '"sha256":"c5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78","size":70000000,"published_at":1791903000000,"log_index":15},')
case("lp17e-other-target", ROC_BASE, ["roc install nightly-2026-10-13-91fa0c2"],
     f"R-LV1 R-LV2 R-LV11 R-SE11 (slice 261d, mutation gap test, entry `commands`; {ROC_W}, and one more row: nightly-2026-10-13-91fa0c2 for macos_apple_silicon, log index 15, with a valid leaf). {KEY}. "
     "The leaf at log index 20 (the row of the host target linux_x86_64) has another sha256. The check takes the row of the tag AND the host target, not the first row of the tag: exit 16, T1 at log index 20, as logproof/lp17b.",
     log({**ROC_LEAVES, "15": f"roc-lang/nightlies:macos_apple_silicon nightly-2026-10-13-91fa0c2 sha256:c5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78 1791903000000",
          "20": f"{NIGHTLY} nightly-2026-10-13-91fa0c2 sha256:{SHA_OTHER} 1791903600000"}, 30))
tp = os.path.join(OUT, "lp17e-other-target/fx/http/127.0.0.1%3A9/v1/toolchains%3Fafter=0")
t = open(tp).read()
anchor = '{"tag":"nightly-2026-10-13-91fa0c2","target":"linux_x86_64"'
assert t.count(anchor) == 1
put(tp, t.replace(anchor, MAC_ROW + anchor))

# Gap test 2 of the mutation check (section 16.10): a later duplicate row (same tag, target and sha256, log index 25) whose leaf is another entry. The download uses the
# sha256 of the first row (Nightlies keep_first, R-CV6), so the check proves the leaf of that row (log index 20): exit 0; the later leaf is not read.
DUP_ROW = ('{"tag":"nightly-2026-10-13-91fa0c2","target":"linux_x86_64","asset_name":"roc_nightly-linux_x86_64-2026-10-13-91fa0c2.tar.gz",'
           f'"sha256":"{SHA}","size":73500000,"published_at":1791990000000,"log_index":25}},')
case("lp17f-duplicate-row", ROC_BASE, ["roc install nightly-2026-10-13-91fa0c2"],
     f"R-LV1 R-LV2 R-CV6 R-SE11 (slice 261d, mutation gap test, entry `commands`; {ROC_W}, and a later row of nightly-2026-10-13-91fa0c2 for linux_x86_64 with the same sha256, log index 25, whose leaf has another sha256). {KEY}. "
     "The sha256 of the download is the one of the first row (log index 20, R-CV6), so the check proves log index 20: exit 0, the calls of logproof/lp17 run 1.",
     log({**ROC_LEAVES, "25": f"{NIGHTLY} nightly-2026-10-13-91fa0c2 sha256:{SHA_OTHER} 1791990000000"}, 30))
tp = os.path.join(OUT, "lp17f-duplicate-row/fx/http/127.0.0.1%3A9/v1/toolchains%3Fafter=0")
t = open(tp).read()
anchor = '{"tag":"nightly-2026-10-17-601b54c"'
assert t.count(anchor) == 1
put(tp, t.replace(anchor, DUP_ROW + anchor))

# Q261d-3 (b), the user 2026-11-24: an x entry of the same version (1.1.0) with another URL (another hash): no R-AP1 row has that URL, so there is no take-over;
# `tool install` builds the registry release 1.1.0 and checks it after `first_app!`, as when no x entry matches. The x entry stays as it is.
XMAN_OTHER = XMAN.replace("AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY.tar.zst", f"{OTHER}.tar.zst").replace('"bundle":"AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY"', f'"bundle":"{OTHER}"')
case("lp16g-takeover-other-hash", X_BASE, ["tool install acme/foo"],
     "R-LV1 R-LV2 R-LV3 R-LV7 R-LV8 R-LV12 (slice 261d, Q261d-3 (b), entry `commands`; the world of registry/sc4-x-registry with an x entry of acme/foo 1.1.0 whose URL has another hash "
     f"({OTHER}): no R-AP1 row has that URL). {KEY}. The log has size 2. There is no take-over: `tool install` builds the registry release 1.1.0 (log index 1) as when no x entry matches, "
     "and checks it after `first_app!` and before the platform fetch (Q261d-1). The x entry is not changed. Exit 0, the output of a build (no take-over line).",
     log(X_LEAVES, 2))
put(os.path.join(OUT, "lp16g-takeover-other-hash/given/home", XHIT, "manifest.json"), XMAN_OTHER)
put(os.path.join(OUT, "lp16g-takeover-other-hash/given/home", XHIT, "foo"), "fake")
