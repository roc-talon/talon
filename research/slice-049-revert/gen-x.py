#!/usr/bin/env python3
"""Slice 049: makes the `given/`, `fx/`, `entry` and `rules` files of the L2 cases x/x1-run, x/x2-offline, tool/tk1-takeover and gc/gc4-x (no `expect/`: UPDATE=1 writes it from the reference, TW21).
Run from the repo root: python3 research/slice-049-revert/gen-x.py. It writes only under tests/commands/cases/x/, tests/commands/cases/tool/tk1-takeover/ and tests/commands/cases/gc/gc4-x/.
It uses the classes of research/slice-048-revert/gen-manage.py (the text before its first case: the file is read, never run as a whole, so the cases of slice 048 are not rewritten). The hashes are the base58 of the sha256 of a label,
so they are valid package hashes and stay the same on each run."""
import hashlib, json, os, shutil

src = open("research/slice-048-revert/gen-manage.py").read().split("# ---------------------------------------------------------------- tm1-manage")[0]
exec(src)

JSON_HASH = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"
HASHES = [PF_HASH, JSON_HASH]   # the hashes of the release URL entries of app(), in header order
TARGET = "x64musl"
NOW = "2026-10-15T12:00:00Z"


def xdigest(name, bundle, hashes=HASHES, nightly=PIN, target=TARGET):
    text = f"{name}\n{bundle}\n{','.join(hashes)}\n{nightly}\n{target}\n"
    return hashlib.sha256(text.encode()).hexdigest()


def xbin(name, version):
    return f"xbin {name} {version}\n"


def manifest(name, version, repo_tag, label, last_run=NOW, sha=None, nightly=PIN, target=TARGET, hashes=HASHES):
    if sha is None:
        sha = hashlib.sha256(xbin(name, version).encode()).hexdigest()
    doc = {"format": 1, "name": name,
           "source": {"kind": "release", "version": version, "url": rel_url(name, repo_tag, label)},
           "build": {"hashes": hashes, "nightly": nightly, "target": target},
           "sha256": sha, "libs": [], "bundle": b58(label), "last_run": last_run}
    return json.dumps(doc, separators=(",", ":")) + "\n"


class XCase(Case):
    def xentry(self, name, version, label=None, last_run="2026-10-01T00:00:00Z", tag=None, target=TARGET, nightly=PIN, text=None, content=None, binary=True):
        """A given `x` cache entry for the release `version` of `name`, as a build of that release makes it (its dir is the digest of the build id)."""
        label = label or f"{name.split('/')[1]}-{version}"
        tag = tag or version
        d = xdigest(name, b58(label), nightly=nightly, target=target)
        base = f"given/home/.cache/roc/talon/x/{d}"
        self.write(f"{base}/manifest.json", text if text is not None else manifest(name, version, tag, label, last_run=last_run, target=target, nightly=nightly))
        if binary:
            self.write(f"{base}/{name.split('/')[1]}", content if content is not None else xbin(name, version))
        return d

    def xraw(self, dirname, text):
        """A given dir of `talon/x/` with a manifest that has this text."""
        self.write(f"given/home/.cache/roc/talon/x/{dirname}/manifest.json", text)


def simple_repo(c, repo, versions):
    """versions: (version, published_at) newest first. Each release is an app."""
    name = repo.split("/")[1]
    c.repo(repo, [(v, f"{name}-{v}", at, app()) for v, at in versions])


# ---------------------------------------------------------------- x/x1-run
ROOT = "tests/commands/cases/x"
RULES = """Slice 049, `tln x` online (entry `commands`). One home with the compiler `nightly-2026-10-14-38a3029` installed (the pin of each app), `TALON_NOW=2026-10-15T12:00:00Z`, no `config.toml` (`min-release-age` is 2 days), no tty. The fake `roc build` writes the output file. The fake `exec!` runs nothing: the rules of `fx/exec` give the exit code of the app.
acme/foo has 2 releases (1.1.0, 1.0.0), acme/bar has 1.1.0 and 1.0.0 (an `x` entry of 1.0.0 is in the cache), acme/baz has 1.0.0 (installed, and an `x` entry of the same version is in the cache), acme/old has 1.0.0 (an `x` entry of 0.9.0 is in the cache), acme/nobin has 1.0.0 (an `x` entry of 1.0.0 is in the cache, with a manifest and no binary).
`talon/x/` also has a dir with a manifest that does not parse (`garbage`) and a dir with a manifest of format 2 (`future`).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `x acme/foo -- a b` | the garbage manifest: a warning and its dir is deleted (the format 2 dir stays). No match: the newest release 1.1.0 is built (the platform line and the build line on stderr, no `--target`), the entry `talon/x/<digest>/` has the binary and the manifest, the temp dir of the build is deleted. No lock, no `tools.json`, no bin dir. The app runs with `a b` and its exit code 3 is the exit code | R-CM12, R-X1, R-X2, R-X3, R-X4, R-E1, R-B9, R-CC11, R-TF3, R-TF6 |
| 2 | `x acme/foo` | the entry matches (no selector, R-B1): no build, no download. The note of R-C6. The manifest is written again with the `last_run` of the run, the app runs | R-B1, R-B3, R-C6, R-X2 |
| 3 | `x foo` | the short name finds the entry (R-SC4, R-AD7), the same as run 2 | R-SC4, R-AD7 |
| 4 | `x acme/foo@1.0.0` | the selector is an exact version that the entry (1.1.0) does not have: 1.0.0 is built, a second entry | R-B2 |
| 5 | `x acme/bar` | the entry 1.0.0 matches (no selector), 1.1.0 is newer: the note and the line `using cached bar 1.0.0 (1.1.0 is available: tln x acme/bar@latest)`, no build | R-B1, R-B3 |
| 6 | `x acme/bar@latest` | `latest` is 1.1.0: the entry 1.0.0 is not enough, 1.1.0 is built | R-B2 |
| 7 | `x acme/bar` | two entries now (1.0.0, 1.1.0): the newest version wins, no `is available` line | R-B1 |
| 8 | `x acme/baz` | an installed tool and an entry with the same version: the installed tool runs in place (`<data>/bin/baz`), no write in `talon/x/` | R-B1, R-B5, R-X3 |
| 9 | `x acme/old` | the entry 0.9.0 is not a candidate of the release list (R-B3: yanked or deleted): it is not used, 1.0.0 is built. The `rename` of the new entry says `Exists` (another run made it first, R-CC11): the temp dir is deleted and the run goes on | R-B3, R-CC11 |
| 10 | `x acme/foo --json` | exit 2 (R-FL1): the JSON error line on stdout (the flag is not for `x`). No call after `args` | R-FL1, R-EC2 |
| 11 | `x nope` | a short name that no tool and no entry has: exit 2, no request (R-AD7, R-NM11) | R-AD7, R-NM11, R-SC4 |
| 12 | `x acme/baz -- boom` | the app does not start (`exec!` says `NotStarted`): exit 18 | R-X4, R-HF6 |
| 13 | `x acme/nobin` | an entry whose manifest is there but whose binary is not (question Q-X3): it is no match. The newest release is built, the old entry dir is deleted (before the `rename`), the new entry is in the same dir, the app runs | R-B1, R-X2 |
| 14 | `x acme/nofile` | (gap test, slice 049 verify) the build passes but makes no file: no entry is written, nothing runs, the failure of the build, the temp dir of the build is deleted | R-X2, R-CC2 |
"""
c = XCase("x1-run", RULES)
c.toolchain(PIN)
c.tools([{"key": "baz", "name": "acme/baz", "source": release("1.0.0", "acme/baz", "1.0.0", "baz-1.0.0")}])
c.files("baz", data="baz bin\n", entry="baz bin\n")
simple_repo(c, "acme/foo", [("1.1.0", "2026-09-01T12:00:00Z"), ("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/bar", [("1.1.0", "2026-09-01T12:00:00Z"), ("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/baz", [("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/old", [("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/nobin", [("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/nofile", [("1.0.0", "2026-08-01T12:00:00Z")])
c.platform()
c.xentry("acme/bar", "1.0.0")
c.xentry("acme/baz", "1.0.0")
c.xentry("acme/old", "0.9.0")
c.xentry("acme/nobin", "1.0.0", binary=False)
c.xraw("garbage", "this is not json\n")
c.xraw("future", '{"format":2,"name":"acme/future"}\n')
OLD_DIGEST = xdigest("acme/old", b58("old-1.0.0"))
c.write("fx/rename", f"exists /talon/x/{OLD_DIGEST}\n")
c.write("fx/exec", "foo a b\t3\nbaz boom\tnotstarted:permission denied\n")
c.finish(["x acme/foo -- a b", "x acme/foo", "x foo", "x acme/foo@1.0.0", "x acme/bar", "x acme/bar@latest", "x acme/bar", "x acme/baz", "x acme/old", "x acme/foo --json", "x nope", "x acme/baz -- boom", "x acme/nobin", "x acme/nofile"],
         [BUILD_OK] * 5 + [f"0\t{FIX}/build-pass.stdout\t-\t-"])

# ---------------------------------------------------------------- x/x2-offline
RULES = """Slice 049, `tln x` with no check online (entry `commands`): R-B7, R-B8, R-NI9. One home with the compiler installed, `TALON_NOW=2026-10-15T12:00:00Z`, `CI=true` (no person) and a fake tty (a run with `env:TALON_INTERACTIVE=1` has a person, R-NM2). `fx/answers` is `n`, then `y`.
`talon/x/` has entries of acme/foo 1.1.0 and 1.0.0, acme/qux 1.0.0, acme/net 1.0.0. acme/baz 1.0.0 is installed. The release list of acme/net cannot be reached (a transport error). No other repo has a route: a run that asks for a list gets 404.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `x acme/foo --offline` | no list is read. The newest entry (1.1.0) matches, so the prompt R-NI9 is due. No person and no flag: exit 13, the message names `--allow-unchecked` and `--yes`, nothing runs | R-B7, R-NI9, R-NM5 |
| 2 | `x acme/foo --offline --allow-unchecked` | the answer flag is Yes: the answer line on stderr, the manifest gets `last_run`, the app runs, exit 0 | R-B7, R-NI9, R-NM6 |
| 3 | `x acme/qux --offline --yes` | `--yes` is Yes too (R-NM8) | R-NI9, R-NM8 |
| 4 | `x acme/baz --offline` | the installed tool runs in place with the note `baz 1.0.0 is installed. tln did not check it online ...` and no prompt (no `tty`, no `ask`) | R-B8, R-B5 |
| 5 | `x acme/none --offline` | no installed tool and no entry: exit 15 | R-B7 |
| 6 | `x acme/foo@2.0.0 --offline` | an exact version that no build has: exit 15 | R-B7, R-B2 |
| 7 | `x acme/foo@1.0.0 --offline --yes` | an exact version that an entry has: it runs (not the newest entry) | R-B7, R-B10 |
| 8 | `x acme/foo --offline env:TALON_INTERACTIVE=1` | a person: the prompt (`ask`), the answer is `n`: exit 13, nothing runs | R-NI9, R-NM8, R-B7 |
| 9 | `x acme/foo --offline env:TALON_INTERACTIVE=1` | the answer is `y`: the app runs (each run asks `tty` and `ask`) | R-NI9, R-HF1 |
| 10 | `x acme/net --yes` | no `--offline`, but the list cannot be reached (kind `network`): the same path as offline. The entry is offered, `--yes` accepts, the app runs | R-B7 |
| 11 | `x acme/net2` | the list cannot be reached and no build matches: the failure of the request itself (exit 15, it names `--offline`) | R-B7 |
"""
c = XCase("x2-offline", RULES)
c.toolchain(PIN)
c.tools([{"key": "baz", "name": "acme/baz", "source": release("1.0.0", "acme/baz", "1.0.0", "baz-1.0.0")}])
c.files("baz", data="baz bin\n", entry="baz bin\n")
c.xentry("acme/foo", "1.1.0")
c.xentry("acme/foo", "1.0.0")
c.xentry("acme/qux", "1.0.0")
c.xentry("acme/net", "1.0.0")
for repo in ("acme/net", "acme/net2"):
    c.write(f"fx/http/api.github.com/repos/{repo}/releases?per_page=100", "[]\n")
    c.write(f"fx/http/api.github.com/repos/{repo}/releases?per_page=100.meta", "error failed connection refused\n")
c.finish(["x acme/foo --offline", "x acme/foo --offline --allow-unchecked", "x acme/qux --offline --yes", "x acme/baz --offline", "x acme/none --offline", "x acme/foo@2.0.0 --offline", "x acme/foo@1.0.0 --offline --yes",
          "x acme/foo --offline env:TALON_INTERACTIVE=1", "x acme/foo --offline env:TALON_INTERACTIVE=1", "x acme/net --yes", "x acme/net2"],
         [], answers=["n", "y"], tty=True, env_extra=["CI=true"])

# ---------------------------------------------------------------- tool/tk1-takeover
ROOT = "tests/commands/cases/tool"
RULES = """Slice 049, the take-over of an `x` cache entry by `tln tool install` (entry `commands`): R-B1 to R-B4, R-B7, R-NI9, R-PT13 (the copy is L0 only). One home with the compiler installed, `TALON_NOW=2026-10-15T12:00:00Z`, `CI=true` (no person), no tty.
`tools.json` has `qux` 1.0.0 (the data bin file and the bin dir entry are there). `talon/x/` has entries of acme/foo 1.1.0, acme/bar 1.0.0, acme/qux 2.0.0, acme/ren 1.0.0, acme/lat 1.0.0, acme/yank 0.9.0, acme/off 1.0.0 and acme/bad 1.0.0 (its binary was changed after the build). acme/foo, bar, ren, lat, off have 1.1.0 as the newest release (acme/foo: 1.1.0 and 1.0.0).
The fake `rename` of the binary of acme/ren to its temp name in the data bin dir says `Exists`: another file system.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool install acme/foo` | the entry 1.1.0 is the newest release: the note of R-C6, no `is available` line, no download, no build. Under the lock of `tools.json`: the sha256 of the entry binary, `rename` of the binary to the data bin dir, the bin dir entry (a hard link), `tools.json` from the manifest, then the entry dir is deleted | R-B1, R-B4, R-C6, R-T3, R-ST7, R-CC6 |
| 2 | `tool install acme/bar` | the entry 1.0.0 matches (no selector) and 1.1.0 is newer: the line `installed cached 1.0.0 (1.1.0 is available: tln tool install bar@latest)` (R-B3) | R-B1, R-B3, R-B4 |
| 3 | `tool install acme/qux@2.0.0` | an installed tool 1.0.0 and the entry 2.0.0: the exact selector is not the installed version, the entry is taken: `replaced qux 1.0.0 with 2.0.0` | R-B4, R-B2, R-T26, R-T27 |
| 4 | `tool install acme/ren` | the `rename` fails: the binary is copied, then the entry dir is deleted all the same | R-B4 |
| 5 | `tool install acme/lat@latest` | the entry 1.0.0 is not the newest release: no match, a normal build of 1.1.0. The old entry stays (it waits for GC) | R-B2, R-B4 |
| 6 | `tool install acme/yank` | the entry 0.9.0 is not a candidate of the list (R-B3): a normal build of 1.0.0 | R-B3 |
| 7 | `tool install acme/off --offline` | no list is read. The entry matches: the prompt R-NI9, no person: exit 13, nothing changed | R-B7, R-NI9, R-NM5 |
| 8 | `tool install acme/off --offline --allow-unchecked` | the answer flag: the entry is taken, with no note of R-B3 | R-B7, R-NI9, R-B4 |
| 9 | `tool install acme/foo` | foo 1.1.0 is installed (run 1): `foo 1.1.0 is installed`, no list of `talon/x` (R-T26 first) | R-T26 |
| 10 | `tool install acme/bad` | the binary of the entry has not the sha256 of its manifest (the file was changed): the check is before the move, exit 16 (kind integrity, question Q-T3: the design does not say what follows), nothing is changed, the entry stays | R-B4 |
"""
c = XCase("tk1-takeover", RULES)
c.toolchain(PIN)
c.tools([{"key": "qux", "name": "acme/qux", "source": release("1.0.0", "acme/qux", "1.0.0", "qux-1.0.0")}])
c.files("qux", data="old qux\n", entry="old qux\n")
simple_repo(c, "acme/foo", [("1.1.0", "2026-09-01T12:00:00Z"), ("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/bar", [("1.1.0", "2026-09-01T12:00:00Z"), ("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/qux", [("2.0.0", "2026-09-01T12:00:00Z"), ("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/ren", [("1.1.0", "2026-09-01T12:00:00Z"), ("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/lat", [("1.1.0", "2026-09-01T12:00:00Z"), ("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/yank", [("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/off", [("1.1.0", "2026-09-01T12:00:00Z"), ("1.0.0", "2026-08-01T12:00:00Z")])
simple_repo(c, "acme/bad", [("1.0.0", "2026-08-01T12:00:00Z")])
c.platform()
c.xentry("acme/bad", "1.0.0", content="changed after the build\n")
for name, version in (("acme/foo", "1.1.0"), ("acme/bar", "1.0.0"), ("acme/qux", "2.0.0"), ("acme/ren", "1.0.0"), ("acme/lat", "1.0.0"), ("acme/yank", "0.9.0"), ("acme/off", "1.0.0")):
    c.xentry(name, version)
c.write("fx/rename", "exists /share/talon/bin/ren.0123456789abcdef.tmp\n")
c.finish(["tool install acme/foo", "tool install acme/bar", "tool install acme/qux@2.0.0", "tool install acme/ren", "tool install acme/lat@latest", "tool install acme/yank", "tool install acme/off --offline", "tool install acme/off --offline --allow-unchecked", "tool install acme/foo", "tool install acme/bad"],
         [BUILD_OK] * 2, env_extra=["CI=true"])

# ---------------------------------------------------------------- gc/gc4-x
ROOT = "tests/commands/cases/gc"
RULES = """Slice 049, `tln cache gc` and the `x` entries (R-GC7, R-GC9, R-PT14): entry `commands`. `TALON_NOW=2026-10-15T12:00:00Z`, `gc-age` is the default (30 days: 2592000 s). The clock of the fake is 2026-10-15 too.
Entries of `talon/x/`: `fresh` (last run 1 day before), `boundary` (exactly 30 days before: stays), `over` (30 days and 1 s before: goes), `ancient` (2020: goes), `future` (a last run after TALON_NOW: stays), `garbage` (a manifest that does not parse: stays, question Q-G1),
`newer` (format 2: stays), `nomanifest` (a dir with only a binary: stays), `badtime` (a `last_run` that is no time: stays), and a stale temp dir `fresh.0123456789abcdef.tmp` (a temp: older than 1 day, it goes as a stale temp, R-GC6; it is no entry, so no manifest is read for it).
The `[tools]` exception (R-PT14) is L0 (`XCacheTest`): the reader of `[tools]` is slice 056, so `kept` is `[]` here.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `cache gc --dry-run` | the manifests of the 9 entry dirs are read (one `read_files`), `over` and `ancient` would go (with their sizes, in the one `tree_info`), the report line `would remove <path> (<size>)` | R-GC7, R-GC9, R-GC11 |
| 2 | `cache gc --json` | the real run: one `delete` with the stale temp and the 2 dirs (the order of the lines of the report). The `--json` list `builds` has the 2 dirs | R-GC7, R-GC9, R-J3 |
| 3 | `cache gc` | the second run removes nothing: `nothing to remove` | R-GC7 |
"""
c = XCase("gc4-x", RULES)


def gx(label, last_run, name="acme/foo", version="1.0.0", content=None):
    d = xdigest(name, b58(label))
    c.write(f"given/home/.cache/roc/talon/x/{d}/manifest.json", manifest(name, version, version, label, last_run=last_run))
    c.write(f"given/home/.cache/roc/talon/x/{d}/foo", content or xbin(name, version))
    return d


names = {}
names["fresh"] = gx("fresh", "2026-10-14T12:00:00Z")
names["boundary"] = gx("boundary", "2026-09-15T12:00:00Z")
names["over"] = gx("over", "2026-09-15T11:59:59Z")
names["ancient"] = gx("ancient", "2020-01-01T00:00:00Z", content=xbin("acme/foo", "0.0.1") * 3)
names["future"] = gx("future", "2026-11-01T00:00:00Z")
names["badtime"] = gx("badtime", "never")
d = xdigest("acme/foo", b58("garbage"))
c.write(f"given/home/.cache/roc/talon/x/{d}/manifest.json", "garbage\n")
c.write(f"given/home/.cache/roc/talon/x/{d}/foo", "g\n")
d = xdigest("acme/foo", b58("newer"))
c.write(f"given/home/.cache/roc/talon/x/{d}/manifest.json", '{"format":2}\n')
c.write(f"given/home/.cache/roc/talon/x/{d}/foo", "n\n")
d = xdigest("acme/foo", b58("nomanifest"))
c.write(f"given/home/.cache/roc/talon/x/{d}/foo", "m\n")
c.write(f"given/home/.cache/roc/talon/x/{names['fresh']}.0123456789abcdef.tmp/foo", "t\n")
c.write("fx/mtimes", f"x/{names['fresh']}.0123456789abcdef.tmp 1000000000\n")
c.finish(["cache gc --dry-run", "cache gc --json", "cache gc"], [])
# the case has no `fx/jobs` need and no network: finish() writes the generic files, which are harmless.
print("ok")
