#!/usr/bin/env python3
"""Slice 046: makes the `given/` and `fx/` files of the L2 cases `tool/ti1-install` and `tool/ti2-refusals` (no `expect/`: UPDATE=1 writes it from the reference, TW21).
Run from the repo root: python3 research/slice-046-revert/gen-tools.py. It only writes under tests/commands/cases/tool/<case>/ (rules, entry, fx, given). The hashes are
the base58 of the sha256 of a label, so they are valid package hashes (32 bytes) and stay the same on each run."""
import hashlib, json, os, shutil

ROOT = "tests/commands/cases/tool"
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
PF = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst"
JSON_URL = "https://github.com/acme/json/releases/download/2.1.0/3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm.tar.zst"
PIN = "nightly-2026-10-14-38a3029"
OLD_PIN = "nightly-2026-10-11-1a2b3c4"


def b58(label):
    n = int.from_bytes(hashlib.sha256(label.encode()).digest(), "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


WASM_PF = "https://github.com/acme/wasm-pf/releases/download/0.1.0/" + b58("wasm-pf-0.1.0") + ".tar.zst"


def app(pin=PIN, deps=(JSON_URL,), pf=PF):
    lines = ["app [main!] {", f'\tpf: platform "{pf}",']
    for i, d in enumerate(deps):
        lines.append(f'\tdep{i}: "{d}",')
    if pin:
        lines.append(f'\troc: "{pin}",')
    lines.append("}")
    lines.append("")
    lines.append("main! = |_args| Ok({})")
    return "\n".join(lines) + "\n"


def package():
    return f'package [Foo] {{\n\tdep0: "{JSON_URL}",\n}}\n'


class Case:
    def __init__(self, name, rules):
        self.dir = f"{ROOT}/{name}"
        shutil.rmtree(f"{self.dir}/fx", ignore_errors=True)
        shutil.rmtree(f"{self.dir}/given", ignore_errors=True)
        os.makedirs(f"{self.dir}/fx/src")
        os.makedirs(f"{self.dir}/given/home")
        open(f"{self.dir}/entry", "w").write("commands\n")
        open(f"{self.dir}/rules", "w").write(rules)
        self.jobs = []
        self.probes = []
        self.hooks = []

    def write(self, rel, text):
        path = f"{self.dir}/{rel}"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w").write(text)

    def repo(self, repo, releases):
        """releases: (tag, label, published_at, source text). One bundle each (hash of the label)."""
        items = []
        for tag, label, published, text in releases:
            h = b58(label)
            items.append(
                {"tag_name": tag, "draft": False, "prerelease": False, "published_at": published,
                 "assets": [{"name": f"{h}.tar.zst", "size": 1048576, "browser_download_url": f"https://github.com/{repo}/releases/download/{tag}/{h}.tar.zst"}]})
            self.write(f"fx/src/{label}.src", text)
            self.jobs.append(f"unbundle {h}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{h};copy:{{cwd}}/{h}/main.roc={{w}}/fx/src/{label}.src")
        body = "[\n" + ",\n".join(json.dumps(i, separators=(",", ":")) for i in items) + "\n]\n" if items else "[]\n"
        self.write(f"fx/http/api.github.com/repos/{repo}/releases?per_page=100", body)

    def platform(self, url, label, targets):
        """The platform package of an app: one bundle (the header has `targets`, slice 054). The app fetches it before the build (R-T2)."""
        h = url.rsplit("/", 1)[1].split(".tar.zst")[0]
        names = "".join(f'\t\t{t}: {{ inputs: ["libhost.a", app] }},\n' for t in targets)
        text = 'platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}\n\texposes []\n\tpackages {}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n' + names + "\t}\n"
        self.write(f"fx/src/{label}.src", text)
        self.jobs.append(f"unbundle {h}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{h};copy:{{cwd}}/{h}/main.roc={{w}}/fx/src/{label}.src")

    def finish(self, commands, env_extra=(), programs=("curl", "wget", "tar")):
        self.write("fx/commands", "\n".join(commands) + "\n")
        self.write("fx/env", "\n".join(["HOME={w}/home", "TALON_NOW=2026-10-15T12:00:00Z", "TALON_GITHUB_API=https://api.github.com", *env_extra]) + "\n")
        self.write("fx/programs", "\n".join(programs) + "\n")
        self.write("fx/jobs", "# R-DA3 the download, R-FE2 `roc unbundle`, R-HF5 the extract, R-HF2 the chmod, R-GC10 the compat check. The first rule whose needle is in the arguments answers.\n" +
                   "\n".join(self.jobs) + "\n")
        build = "../fixtures/check/out/build-pass.stdout"
        self.write("fx/probes", "# One row for each build, in order (the build probes of the case).\n" + "\n".join(self.probes) + "\n")
        if self.hooks:
            self.write("fx/hooks", "\n".join(self.hooks) + "\n")


def tools_json(entries):
    tools = {}
    for key, name, source in entries:
        tools[key] = {"name": name, "source": source, "build": {"hashes": [], "nightly": PIN, "target": "x64musl"}, "sha256": "0" * 64, "libs": [], "installed_at": "2026-09-01T00:00:00Z"}
    return json.dumps({"format": 1, "tools": tools}, separators=(",", ":")) + "\n"


def toolchain(case, tag):
    case.write(f"given/home/.cache/roc/toolchains/{tag}/.talon.json", json.dumps({"format": 1, "id": tag, "compat": "bbbbbbb"}, separators=(",", ":")) + "\n")


BUILD_OK = "0\t../fixtures/check/out/build-pass.stdout\t-\tfile:{out}"
BUILD_NOFILE = "0\t../fixtures/check/out/build-pass.stdout\t-\t-"
BUILD_FAIL = "1\t../fixtures/check/out/build-errors.stdout\t../fixtures/check/out/build-errors.stderr\t-"
GENERIC_JOBS = [
    "curl --fail\t0\t-\t-\tfile:{out}",
    ".zip -C\t0\t-\t-\tfile:{dir}/roc.exe;file:{dir}/LICENSE;file:{dir}/legal_details",
    "tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details",
    "chmod 0755\t0\t-\t-\t-",
    "nightly-2026-10-11-1a2b3c4.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{w}/home/.cache/roc/compat-1a2b3c4",
]

# ---------------------------------------------------------------- ti1-install
RULES1 = """Slice 046, `tln tool install` for a release (entry `commands`). One home with the compiler `nightly-2026-10-14-38a3029` installed (the pin of each app), no `config.toml` (`min-release-age` is 2 days), `TALON_NOW=2026-10-15T12:00:00Z`.
`tools.json` has one tool, `baz` (acme/baz, built from a git ref, the old binary and its bin dir entry are there). The fake `roc build` writes the output file (the 4th field of `fx/probes`).
acme/foo has 4 releases: 1.0.0 (app), 1.1.0 (app), 1.2.0 (a package, not an app) and 1.3.0 (an app, 1 day old: `min-release-age` hides it).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool install acme/foo` | the newest visible release is 1.2.0, its bundle is a package: dropped. 1.1.0 is built (no `--target`), the binary is in the data bin dir, the bin dir entry is a hard link, `tools.json` has `foo` next to `baz`. The lock of `tools.json` is taken after the build. No `roc:` resolve, no probe of the project | R-CM16, R-T1, R-T2, R-T3, R-T4, R-T5, R-T8, R-T9, R-T10, R-T11, R-T12, R-SE8, R-ST15, R-LY2, R-LY3, R-CC6 |
| 2 | `tool install acme/foo` | foo 1.1.0 is installed and no selector: no build, `foo 1.1.0 is installed` | R-T26 |
| 3 | `tool install foo@1.0.0` | the short name finds the installed tool, the exact version 1.0.0 is not the installed one: built, `tools.json` and the files are replaced (the entry is made again) | R-T26, R-T27, R-ST15 |
| 4 | `tool install acme/foo@1.3.0` | an exact version that is 1 day old: the note on stderr, built and replaced | R-T9, R-T26 |
| 5 | `tool install acme/baz` | `baz` was built from a git ref: the release install replaces it. The hard link of the entry fails: a copy | R-T27, R-ST7, R-ST15 |
| 6 | `tool install acme/qux --as q --json` | the binary name is `q` (`--as`); the envelope has the data | R-T28, R-J1 to R-J4, R-OUT2 |
| 7 | `tool install acme/qux` | acme/qux is installed under the key `q` (run 6) and the command has no `--as`: it is the same tool (review 2). No build, no download, `q 2.0.0 is installed` | R-T26, R-T28 |
| 8 | `tool install acme/qux --as other` | `--as` differs from the installed key `q`: exit 2, `acme/qux is installed as q already` (D2), before any request | R-T27, R-T28 |
"""
c = Case("ti1-install", RULES1)
toolchain(c, PIN)
c.repo("acme/foo", [
    ("1.3.0", "foo-1.3.0", "2026-10-14T12:00:00Z", app()),
    ("1.2.0", "foo-1.2.0", "2026-09-20T12:00:00Z", package()),
    ("1.1.0", "foo-1.1.0", "2026-09-01T12:00:00Z", app()),
    ("1.0.0", "foo-1.0.0", "2026-08-01T12:00:00Z", app(deps=())),
])
c.repo("acme/baz", [("1.0.0", "baz-1.0.0", "2026-08-01T12:00:00Z", app())])
c.repo("acme/qux", [("2.0.0", "qux-2.0.0", "2026-08-01T12:00:00Z", app())])
c.platform(PF, "platform-basic-cli", ["x64mac", "arm64mac", "x64musl", "arm64musl"])
c.jobs.append(GENERIC_JOBS[0])
c.probes = [BUILD_OK] * 5
c.write("given/home/.local/share/talon/tools.json", tools_json([("baz", "acme/baz", {"kind": "git", "commit": "dd03c09e5f0a3b6c7d8e9f001122334455667788", "ref": "main"})]))
c.write("given/home/.local/share/talon/bin/baz", "old baz\n")
c.write("given/home/.local/bin/baz", "old baz\n")
c.write("fx/hardlink", "fail baz.0123456789abcdef.tmp\n")
c.finish(["tool install acme/foo", "tool install acme/foo", "tool install foo@1.0.0", "tool install acme/foo@1.3.0", "tool install acme/baz", "tool install acme/qux --as q --json", "tool install acme/qux", "tool install acme/qux --as other"])

# ---------------------------------------------------------------- ti2-refusals
RULES2 = """Slice 046, the stops of `tln tool install` (entry `commands`). Same home as `ti1-install` (the compiler `nightly-2026-10-14-38a3029` installed, `TALON_NOW=2026-10-15T12:00:00Z`), and `tools.json` with the tool `foo` (acme/foo 1.1.0).
`<bin>/qux` is a file that tln did not write. The builds of the runs 7, 8, 9, 12 and 14 are the rows of `fx/probes` in order: pass, build errors (5 errors), pass, pass, pass with no output file. The platform of the apps (basic-cli) has native targets; the platform of acme/wasm has only `wasm32`. The tool `z` (acme/z 1.0.0) is installed.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool install other/foo` | `foo` is the binary name of acme/foo: exit 2 that names `--as`, before any request | R-T28, R-NM11 |
| 2 | `tool install acme/lib` | the one release is a package: no candidate, exit 2 with `--git acme/lib@1.0.0` | R-T10 |
| 3 | `tool install acme/none env:TALON_GITHUB_API= env:GITHUB_TOKEN=ghp_fake` | no release at all: one request for the default branch, exit 2 with `--git acme/none@trunk`. The token variable is set and `TALON_GITHUB_API` is not (the test hook sends no token): the list request and the default branch request both have `Authorization` (review 2, C1: the same rule as the other GitHub requests, 045 Q1) | R-T10, R-RG3 |
| 4 | `tool install acme/fresh` | the only release is 1 hour old: exit 2 | R-T9 |
| 5 | `tool install acme/nopin` | the app header has no `roc:` entry: exit 2 (question Q3) | R-T11 |
| 6 | `tool install acme/old` | the pin `nightly-2026-10-11-1a2b3c4` is not installed, no flag: exit 13 that names the flags, nothing is downloaded or built | R-T6, R-T16 |
| 7 | `tool install acme/old --roc pinned` | `--roc pinned` is the consent: the compiler is downloaded and installed (the list, curl, tar, chmod, the compat check), then the build with it. It is the first compiler: the default | R-T6, R-T12, R-DL1, R-SO15 |
| 8 | `tool install acme/broken` | the build gives 5 errors: exit 11, nothing in the data bin dir, no lock, the temp dir is deleted | R-T11, R-CC2 |
| 9 | `tool install acme/qux --as q` | another process adds the tool `q` (acme-other/q) while the build runs (`fx/hooks`): under the lock the clash is found: exit 2, no binary, no entry | R-T28, R-CC6 |
| 10 | `tool install acme/qux` | `<bin>/qux` is a file that tln did not write: exit 2 before the download and before the build (the early check, review of Q8): no fetch, no probe, no lock | R-ST6, R-ST11 |
| 11 | `tool install acme/wasm` | the platform has only the target `wasm32` (`BuildTarget.targets_of`): exit 2, no build. The platform is fetched like `roc build` does | R-T2 |
| 12 | `tool install acme/z@2.0.0` | `<bin>/z` is the link of the installed `z`: the early check passes. Another process replaces it during the build (`fx/hooks`): under the lock the check finds a foreign file: exit 2, the binary is not written | R-ST6, R-ST11, R-CC6 |
| 13 | `tool install example.com/pkgs/json` | a `host/path` name (gap row C2): exit 2, `is not an owner/repo name`, no request | R-T10 (as used) |
| 14 | `tool install acme/nofile` | the build passes and makes no file (gap row C6, the 5th row of `fx/probes`): found by the copy under the lock, exit 1, `made no file`, no binary, the temp dir is deleted | R-T11, R-CC2 |
"""
c = Case("ti2-refusals", RULES2)
toolchain(c, PIN)
c.repo("acme/lib", [("1.0.0", "lib-1.0.0", "2026-08-01T12:00:00Z", package())])
c.repo("acme/none", [])
c.write("fx/http/api.github.com/repos/acme/none/@", '{"id":1,"name":"none","default_branch":"trunk"}\n')
c.repo("acme/fresh", [("1.0.0", "fresh-1.0.0", "2026-10-15T11:00:00Z", app())])
c.repo("acme/nopin", [("1.0.0", "nopin-1.0.0", "2026-08-01T12:00:00Z", app(pin=None))])
c.repo("acme/old", [("1.0.0", "old-1.0.0", "2026-08-01T12:00:00Z", app(pin=OLD_PIN))])
c.repo("acme/broken", [("1.0.0", "broken-1.0.0", "2026-08-01T12:00:00Z", app())])
c.repo("acme/qux", [("2.0.0", "qux-2.0.0", "2026-08-01T12:00:00Z", app())])
c.repo("acme/wasm", [("1.0.0", "wasm-1.0.0", "2026-08-01T12:00:00Z", app(pf=WASM_PF))])
c.repo("acme/z", [("2.0.0", "z-2.0.0", "2026-08-01T12:00:00Z", app())])
c.repo("acme/nofile", [("1.0.0", "nofile-1.0.0", "2026-08-01T12:00:00Z", app())])
c.platform(PF, "platform-basic-cli", ["x64mac", "arm64mac", "x64musl", "arm64musl"])
c.platform(WASM_PF, "platform-wasm", ["wasm32"])
shutil.copy("tests/commands/cases/roc/ri1-flow/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100", "/tmp/_nightlies.json")
os.makedirs(f"{c.dir}/fx/http/api.github.com/repos/roc-lang/nightlies", exist_ok=True)
shutil.copy("/tmp/_nightlies.json", f"{c.dir}/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100")
c.jobs.extend(GENERIC_JOBS)
c.probes = [BUILD_OK, BUILD_FAIL, BUILD_OK, BUILD_OK, BUILD_NOFILE]
c.write("given/home/.local/share/talon/tools.json", tools_json([
    ("foo", "acme/foo", {"kind": "release", "version": "1.1.0", "url": "https://github.com/acme/foo/releases/download/1.1.0/" + b58("foo-1.1.0") + ".tar.zst"}),
    ("z", "acme/z", {"kind": "release", "version": "1.0.0", "url": "https://github.com/acme/z/releases/download/1.0.0/" + b58("z-1.0.0") + ".tar.zst"}),
]))
c.write("given/home/.local/share/talon/bin/z", "old z\n")
c.write("given/home/.local/bin/z", "old z\n")
c.write("given/home/.local/share/talon/bin/foo", "old foo\n")
c.write("given/home/.local/bin/foo", "old foo\n")
c.write("given/home/.local/bin/qux", "not from tln\n")
c.hooks.append('after-probes\t4\thome/.local/bin/z\told z\tforeign z')
c.hooks.append('after-probes\t3\thome/.local/share/talon/tools.json\t"tools":{\t"tools":{"q":{"name":"acme-other/q","source":{"kind":"release","version":"1.0.0","url":"https://github.com/acme-other/q/releases/download/1.0.0/x.tar.zst"}},')
c.finish(["tool install other/foo", "tool install acme/lib", "tool install acme/none env:TALON_GITHUB_API= env:GITHUB_TOKEN=ghp_fake", "tool install acme/fresh", "tool install acme/nopin", "tool install acme/old",
          "tool install acme/old --roc pinned", "tool install acme/broken", "tool install acme/qux --as q", "tool install acme/qux", "tool install acme/wasm", "tool install acme/z@2.0.0", "tool install example.com/pkgs/json", "tool install acme/nofile"])
# The sources of the apps are `.src` files, not `.roc`: `scripts/test.sh` runs `roc fmt --check` on each .roc file of tests/ (not in given/), and `roc fmt` writes the pin of the pinned compiler in the `roc:` entry of an app
# header (so an app with the pin of another compiler cannot be a .roc file here).
print("ok")
