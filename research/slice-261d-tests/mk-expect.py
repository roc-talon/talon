#!/usr/bin/env python3
# Slice 261d (test agent): writes the expected files of tests/commands/cases/logproof/lp16* and lp17* by hand rules, from the output of the code BEFORE 261d
# (the work dirs of a run of tests/commands/run.sh on these cases, which fails) and the proposal of the check calls (docs/slices/261-log-inclusion-proofs.md
# sections 14.3 and 16). Each inserted Fx call, text and file is written below. No output of new code is used.
# Usage (repo root, after a run of the cases with the code before 261d): [ONLY="logproof/<case> ..."] python3 research/slice-261d-tests/mk-expect.py <work root, e.g. .tmp/tmp/talon-l2>
import json, os, subprocess, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "slice-261c-tests"))
from mkexpectlib import Log, copies_of, put, read, runs_of  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tests/commands/cases")
WROOT = os.path.abspath(sys.argv[1])
LOG = Log("http://127.0.0.1:9", "http_127.0.0.1_9")

FOO_APP = "$HOME/.cache/roc/packages/AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY/main.roc"
FOO_URL = "https://github.com/acme/foo/releases/download/1.1.0/AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY.tar.zst"
TAG = "nightly-2026-10-13-91fa0c2"


def tool_cut(run):
    """Q261d-1: the check point of a tool: just after the read of main.roc of the first app (the end of `first_app!`), before the platform fetch."""
    return run.index(f"read_files {FOO_APP}") + 1


def roc_cut(run):
    """The check point of a compiler: the end of step 6 of `RocInstall.offer_noted!` (after the list and its compat.db calls), before the prompt and the lock."""
    return max(i for i, l in enumerate(run) if l.startswith("db_write ")) + 1


def fresh(tiles):
    """No kept checkpoint, no copy: read the kept file, read the checkpoint, read the copies, fetch the tiles, write (R-LV6, R-LV7, R-IX8)."""
    return LOG.read_kept() + LOG.get_checkpoint() + LOG.read_copies(tiles) + LOG.fetch(tiles) + LOG.write(tiles)


def failed(tiles):
    """The same reads, no write (R-LV7: the copies only after the proof passes)."""
    return LOG.read_kept() + LOG.get_checkpoint() + LOG.read_copies(tiles) + LOG.fetch(tiles)


def tree(w, add=None, drop=()):
    """tree_diff (tests/lib.sh) of the work dir after the change: `add` {path in home: text}, `drop` paths in home (files or dirs): the file of the given home comes back, else it goes."""
    for rel in drop:
        subprocess.run(["rm", "-rf", os.path.join(w, "home", rel)], check=True)
        if os.path.exists(os.path.join(w, "orig/home", rel)):
            subprocess.run(["cp", "-a", os.path.join(w, "orig/home", rel), os.path.join(w, "home", rel)], check=True)
    for rel, text in (add or {}).items():
        put(os.path.join(w, "home", rel), text)
    return subprocess.run(["bash", "-c", f'. "{ROOT}/tests/lib.sh"; tree_diff "$1"', "_", w], check=True, capture_output=True, text=True).stdout


def json_error(command, message, details):
    return json.dumps({"schema": 1, "command": command, "ok": False, "data": None,
                       "error": {"kind": "integrity", "code": 16, "message": message, "details": details}}, separators=(",", ":"), ensure_ascii=False)


def details(reason, size, index, release):
    return {"log": f"{LOG.base}/log", "reason": reason, "size": size, "index": index, "release": release}


def copies(case, size, tiles):
    """The files that the check writes: the copies of `tiles` and the kept checkpoint (the served text)."""
    d = os.path.join(CASES, case)
    leaves = json.loads(read(os.path.join(d, "mk-log.json")))["leaves"]
    all_copies = copies_of(d, size, LOG.origin, leaves)
    out = {f".cache/roc/talon/index/registry/{LOG.origin}/log/{t}": all_copies[f".cache/roc/talon/index/registry/{LOG.origin}/log/{t}"] for t in tiles}
    out[f".local/share/talon/log/{LOG.origin}/checkpoint"] = read(os.path.join(d, "fx/http/127.0.0.1%3A9/log/checkpoint"))
    return out


def success(case, cut, tiles, size, work=None):
    """`work`: the case whose run of the code before 261d gives the calls (default: `case` itself)."""
    if os.environ.get("ONLY") and case not in os.environ["ONLY"].split():
        return
    w = os.path.join(WROOT, (work or case).replace("/", "_"))
    runs = runs_of(read(os.path.join(w, "out/calls.log.n")).split("\n")[:-1])
    r1 = runs[0]
    k = cut(r1)
    runs[0] = r1[:k] + fresh(tiles) + r1[k:]
    ex = os.path.join(CASES, case, "expect")
    put(os.path.join(ex, "calls.log"), "".join(l + "\n" for r in runs for l in r))
    # R-LV12: a success adds no line: stdout, stderr and exit are those of the code before 261d.
    for f in ["stdout", "stderr"]:
        text = read(os.path.join(w, f"out/{f}.n"))
        if text:
            put(os.path.join(ex, f), text)
    put(os.path.join(ex, "exit"), read(os.path.join(w, "out/exit")))
    put(os.path.join(ex, "tree.diff"), tree(w, add=copies(case, size, tiles)))


def failure(case, cut, tiles, line, stdout_json, drop, before=""):
    if os.environ.get("ONLY") and case not in os.environ["ONLY"].split():
        return
    w = os.path.join(WROOT, case.replace("/", "_"))
    runs = runs_of(read(os.path.join(w, "out/calls.log.n")).split("\n")[:-1])
    assert len(runs) == 1
    r1 = runs[0]
    calls = r1[:cut(r1)] + failed(tiles)
    ex = os.path.join(CASES, case, "expect")
    put(os.path.join(ex, "calls.log"), "".join(l + "\n" for l in calls))
    command = read(os.path.join(CASES, case, "fx/commands")).strip()
    put(os.path.join(ex, "stdout"), f"== {command}\n" + (stdout_json + "\n" if stdout_json else "") + "exit 16\n")
    put(os.path.join(ex, "stderr"), before + f"tln: error[integrity]: {line}\n")
    put(os.path.join(ex, "exit"), "0\n")
    put(os.path.join(ex, "tree.diff"), tree(w, drop=drop))


TOOL_TILES = ["tile/entries/000.p/4", "tile/0/000.p/4"]
# A failed tool check writes none of the files after the check point: the platform bundle, `.last-use` of the compiler, the binaries, tools.json.
TOOL_DROP = [".cache/roc/packages/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA", ".cache/roc/toolchains/nightly-2026-10-14-38a3029/.last-use",
             ".local/bin/foo", ".local/share/talon/bin/foo", ".local/share/talon/tools.json"]
ROC_TILES = ["tile/entries/000.p/30", "tile/0/000.p/30"]
# A failed compiler check: no download, no install, no default in config.toml.
ROC_DROP = [f".cache/roc/toolchains/{TAG}", ".config/talon/config.toml"]

success("logproof/lp16-tool", tool_cut, TOOL_TILES, 4)
success("logproof/lp16d-x", tool_cut, ["tile/entries/000.p/2", "tile/0/000.p/2"], 2)
success("logproof/lp17-compiler", roc_cut, ROC_TILES, 30)
success("logproof/lp17d-roc-update", roc_cut, ROC_TILES, 30)

# T1, `<release>` of a tool: `tool <name> <version>` (section 7), the full name.
failure("logproof/lp16b-tool-entry-differs", tool_cut, TOOL_TILES,
        "tool acme/foo 1.1.0: the log of http://127.0.0.1:9 has another entry at log index 3: github.com/acme/foo/releases/download/{v}/ 1.1.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK. Talon wrote nothing.",
        None, TOOL_DROP)
T2_TOOL = "tool acme/foo 1.1.0: the inclusion proof of log index 3 does not match the signed checkpoint of http://127.0.0.1:9 (size 4). Talon wrote nothing."
failure("logproof/lp16c-tool-not-included", tool_cut, TOOL_TILES, T2_TOOL,
        json_error("tool install", T2_TOOL, details("not-included", 4, 3, FOO_URL)), TOOL_DROP)
# T1, `<release>` of a compiler: `nightly-<date>-<sha> (<target>)` (section 7).
failure("logproof/lp17b-compiler-entry-differs", roc_cut, ROC_TILES,
        f"{TAG} (linux_x86_64): the log of http://127.0.0.1:9 has another entry at log index 20: roc-lang/nightlies:linux_x86_64 {TAG} sha256:{'0' * 64}. Talon wrote nothing.",
        None, ROC_DROP)
T2_ROC = f"{TAG} (linux_x86_64): the inclusion proof of log index 20 does not match the signed checkpoint of http://127.0.0.1:9 (size 30). Talon wrote nothing."
# `release` of a compiler in `error.details`: the compiler tag (CLI 3 catalog).
failure("logproof/lp17c-compiler-not-included", roc_cut, ROC_TILES, T2_ROC,
        json_error("roc install", T2_ROC, details("not-included", 30, 20, TAG)), ROC_DROP)


def take_cut(run):
    """Q261d-2 (a): the check point of a take-over: after the x entries are read (`XCacheIo.entries!`), before `take!` (its first call is the bin dir check)."""
    return run.index("list_dirs $HOME/.local/bin")


X_TILES = ["tile/entries/000.p/2", "tile/0/000.p/2"]
success("logproof/lp16e-takeover", take_cut, X_TILES, 2)
# A failed check before `take!`: the x entry stays, no binary, tools.json as given. The garbage x dir is deleted by `entries!` before the check (its warning is printed).
failure("logproof/lp16f-takeover-entry-differs", take_cut, X_TILES,
        "tool acme/foo 1.1.0: the log of http://127.0.0.1:9 has another entry at log index 1: github.com/acme/foo/releases/download/{v}/ 1.1.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK. Talon wrote nothing.",
        None, [".local/bin/foo", ".local/share/talon/bin/foo", ".local/share/talon/tools.json", ".cache/roc/talon/x/12a9a07e3bfad229b786f055419c9cd6824c28c2835865525c4c3d2b5cdfa2c7"],
        before="warning: $HOME/.cache/roc/talon/x/garbage/manifest.json: the content does not parse. Talon deletes it and makes it again.\n")

# Gap test of the mutation check (section 16.10): the same T1 as lp17b; the row of another target (log index 15) is not the row that is checked.
failure("logproof/lp17e-other-target", roc_cut, ROC_TILES,
        f"{TAG} (linux_x86_64): the log of http://127.0.0.1:9 has another entry at log index 20: roc-lang/nightlies:linux_x86_64 {TAG} sha256:{'0' * 64}. Talon wrote nothing.",
        None, ROC_DROP)

# Gap test 2 (section 16.10): the check of log index 20 (the first row), as lp17 run 1.
success("logproof/lp17f-duplicate-row", roc_cut, ROC_TILES, 30)

# Q261d-3 (b): no take-over of an x entry whose URL has no R-AP1 row. The code before 261d takes it over, so the calls come from the same world with the version
# 0.9.0 in the manifest (`logproof/lp16g-base` in the mirror of the code before 261d: no match, a build; the calls of `entries!` are the same), with the check of 1.1.0 after `first_app!`.
success("logproof/lp16g-takeover-other-hash", tool_cut, X_TILES, 2, work="logproof/lp16g-base")
