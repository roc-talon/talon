#!/usr/bin/env python3
"""Slice 048: makes the `given/`, `fx/`, `entry` and `rules` files of the L2 cases tool/tm1-manage, tg1-git, tg2-gitstops, tr1-rebuild, tr2-rebuildstops and tu1-update
(no `expect/`: UPDATE=1 writes it from the reference, TW21). Run from the repo root: python3 research/slice-048-revert/gen-manage.py. It only writes under tests/commands/cases/tool/<case>/
for these 6 cases. It never imports gen-tools.py or gen-compiler.py (they rewrite the cases of slices 046 and 047). The hashes are the base58 of the sha256 of a label, so they are
valid package hashes and stay the same on each run."""
import hashlib, json, os, shutil

ROOT = "tests/commands/cases/tool"
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
PF = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst"
PF_HASH = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"
JSON_URL = "https://github.com/acme/json/releases/download/2.1.0/3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm.tar.zst"
PIN = "nightly-2026-10-14-38a3029"      # installed, the pin of most apps
PIN2 = "nightly-2026-10-12-2664a27"     # in the nightly list of the case
OLD = "nightly-2026-10-11-1a2b3c4"      # in the nightly list of the case
FIX = "../fixtures/check/out"


def b58(label):
    n = int.from_bytes(hashlib.sha256(label.encode()).digest(), "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def app(pin=PIN, deps=(JSON_URL,)):
    lines = ["app [main!] {", f'\tpf: platform "{PF}",']
    for i, d in enumerate(deps):
        lines.append(f'\tdep{i}: "{d}",')
    if pin:
        lines.append(f'\troc: "{pin}",')
    lines += ["}", "", "main! = |_args| Ok({})"]
    return "\n".join(lines) + "\n"


def package():
    return f'package [Foo] {{\n\tdep0: "{JSON_URL}",\n}}\n'


def rel_url(repo, tag, label):
    return f"https://github.com/{repo}/releases/download/{tag}/{b58(label)}.tar.zst"


class Case:
    def __init__(self, name, rules):
        self.dir = f"{ROOT}/{name}"
        shutil.rmtree(f"{self.dir}/fx", ignore_errors=True)
        shutil.rmtree(f"{self.dir}/given", ignore_errors=True)
        os.makedirs(f"{self.dir}/fx/src")
        os.makedirs(f"{self.dir}/given/home")
        open(f"{self.dir}/entry", "w").write("commands\n")
        open(f"{self.dir}/rules", "w").write(rules)
        self.unbundle = []
        self.tar = []
        self.probes = []
        self.answers = []
        self.nightlies = False

    def write(self, rel, text):
        path = f"{self.dir}/{rel}"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w").write(text)

    def bundle(self, label, text):
        """The app bundle (or package) of a release: the file `fx/src/<label>.src` and the unbundle job."""
        h = b58(label)
        self.write(f"fx/src/{label}.src", text)
        self.unbundle.append(f"unbundle {h}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{h};copy:{{cwd}}/{h}/main.roc={{w}}/fx/src/{label}.src")

    def repo(self, repo, releases):
        """releases: (tag, label, published_at, source text)."""
        items = []
        for tag, label, published, text in releases:
            h = b58(label)
            items.append({"tag_name": tag, "draft": False, "prerelease": False, "published_at": published,
                          "assets": [{"name": f"{h}.tar.zst", "size": 1048576, "browser_download_url": f"https://github.com/{repo}/releases/download/{tag}/{h}.tar.zst"}]})
            self.bundle(label, text)
        self.write(f"fx/http/api.github.com/repos/{repo}/releases?per_page=100", "[\n" + ",\n".join(json.dumps(i, separators=(",", ":")) for i in items) + "\n]\n")

    def platform(self):
        text = 'platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}\n\texposes []\n\tpackages {}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n' + "".join(f'\t\t{t}: {{ inputs: ["libhost.a", app] }},\n' for t in ["x64mac", "arm64mac", "x64musl", "arm64musl"]) + "\t}\n"
        self.write("fx/src/platform-basic-cli.src", text)
        self.unbundle.append(f"unbundle {PF_HASH}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{PF_HASH};copy:{{cwd}}/{PF_HASH}/main.roc={{w}}/fx/src/platform-basic-cli.src")

    def commit(self, repo, ref, sha=None, status=None):
        """The answer of the commit request of a ref: the sha as text, or a status (no body)."""
        base = f"fx/http/api.github.com/repos/{repo}/commits/{ref}"
        if sha:
            self.write(base, sha)
        if status:
            self.write(base + ".meta", f"status {status}\n")
            self.write(base, '{"message":"Not Found","status":"404"}')

    def tarball(self, files):
        """The fake tar of a source archive: (path in the source, label of the .src file) for each file."""
        actions = []
        for rel, label in files:
            if "/" in rel:
                actions.append("dir:{dir}/" + rel.rsplit("/", 1)[0])
            actions.append("copy:{dir}/" + rel + "={w}/fx/src/" + label + ".src")
        self.tar = ["source.tar.gz -C\t0\t-\t-\t" + (";".join(actions) if actions else "-")]

    def toolchain(self, tag):
        self.write(f"given/home/.cache/roc/toolchains/{tag}/.talon.json", json.dumps({"format": 1, "id": tag, "compat": "bbbbbbb"}, separators=(",", ":")) + "\n")

    def with_nightlies(self):
        self.nightlies = True
        os.makedirs(f"{self.dir}/fx/http/api.github.com/repos/roc-lang/nightlies", exist_ok=True)
        shutil.copy("tests/commands/cases/roc/ri1-flow/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100", f"{self.dir}/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100")

    def tools(self, entries):
        """entries: dicts with key, name, source, and optional path, nightly, libs."""
        tools = {}
        for e in entries:
            source = dict(e["source"])
            if e.get("path"):
                source["path"] = e["path"]
            tools[e["key"]] = {"name": e["name"], "source": source, "build": {"hashes": [b58("h-" + e["key"])], "nightly": e.get("nightly", PIN), "target": "x64musl"},
                               "sha256": "0" * 64, "libs": e.get("libs", []), "installed_at": e.get("at", "2026-09-01T00:00:00Z")}
        self.write("given/home/.local/share/talon/tools.json", json.dumps({"format": 1, "tools": tools}, separators=(",", ":")) + "\n")

    def files(self, key, data=None, entry=None):
        if data is not None:
            self.write(f"given/home/.local/share/talon/bin/{key}", data)
        if entry is not None:
            self.write(f"given/home/.local/bin/{key}", entry)

    def finish(self, commands, probes=(), answers=(), tty=False, env_extra=(), programs=("curl", "wget", "tar")):
        self.write("fx/commands", "\n".join(commands) + "\n")
        self.write("fx/env", "\n".join(["HOME={w}/home", "TALON_NOW=2026-10-15T12:00:00Z", "TALON_GITHUB_API=https://api.github.com", *env_extra]) + "\n")
        self.write("fx/programs", "\n".join(programs) + "\n")
        generic = ["curl --fail\t0\t-\t-\tfile:{out}"]
        if self.nightlies:
            generic += [
                ".zip -C\t0\t-\t-\tfile:{dir}/roc.exe;file:{dir}/LICENSE;file:{dir}/legal_details",
                "tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details",
                "chmod 0755\t0\t-\t-\t-",
                f"{OLD}.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{{w}}/home/.cache/roc/compat-1a2b3c4",
                f"{PIN2}.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{{w}}/home/.cache/roc/compat-2664a27",
            ]
        self.write("fx/jobs", "# R-DA3 the download, R-FE2 `roc unbundle`, R-T23 the source archive (`source.tar.gz`, before the generic `tar -xf`), R-GC10 the compat check. The first rule whose needle is in the arguments answers.\n" +
                   "\n".join(self.unbundle + self.tar + generic) + "\n")
        self.write("fx/probes", "# One row for each build, in order (the build probes of the case).\n" + "\n".join(probes) + "\n")
        if answers:
            self.write("fx/answers", "\n".join(answers) + "\n")
        if tty:
            self.write("fx/tty", "stdin=true\nstderr=true\n")


BUILD_OK = f"0\t{FIX}/build-pass.stdout\t-\tfile:{{out}}"
BUILD_FAIL = f"1\t{FIX}/build-errors.stdout\t{FIX}/build-errors.stderr\t-"
AAAA = "aaaaaaaa5e8a2f4b6c0d9e1a7f3b5c8d2e4f6a1b"
BBBB = "bbbbbbbb5e8a2f4b6c0d9e1a7f3b5c8d2e4f6a1c"
DD03 = "dd03c09e5f0a3b6c7d8e9f001122334455667788"
OLDC = "1111111111111111111111111111111111111111"


def release(version, repo, tag, label):
    return {"kind": "release", "version": version, "url": rel_url(repo, tag, label)}


def git(commit, ref):
    return {"kind": "git", "commit": commit, "ref": ref}


# ---------------------------------------------------------------- tm1-manage
RULES = """Slice 048, `tln tool list` (`ls`) and `tln tool remove` (`rm`) (entry `commands`). One home, no network, no compiler. `tools.json` has 3 tools: `foo` (acme/foo 1.1.0, one run-time library, the file in the data bin dir and the bin dir entry have the same content: it is Talon's),
`g` (acme/g, built from main, `--path apps/cli`, the bin dir entry is another file: not Talon's) and `z` (acme/z 2.0.0, the data bin file only: the entry is gone).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool ls` | the table with the column LIBS (foo has a library): one line for each tool in the order of the file, a git tool shows `git main@aaaaaaaa apps/cli`. No `clock`, no `platform`, no request, no lock | R-T4, R-T5, R-T8, R-CM16 |
| 2 | `tool ls --json` | the envelope with `tools` (the 3 objects) | R-J1 to R-J4, R-OUT4 |
| 3 | `tool rm nope` | no installed tool has the short name: exit 2, the lookup failure | R-SC3, R-AD6 |
| 4 | `tool rm acme/zzz` | a full name that no tool has: exit 2 `is not an installed tool`, no lock | R-SC3 |
| 5 | `tool rm talon` | `talon` is slices 050 and 051: exit 2 `is not built yet`, no call | R-CM16 |
| 6 | `tool rm foo --dry-run` | the flag is for `tool rm talon`: exit 2, no call | R-FL12 |
| 7 | `tool rm foo` | under the lock of `tools.json`: the entry is Talon's (same sha256): the entry and the binary are deleted, then `tools.json` is written without `foo`. Nothing is written in `talon/x/` | R-B6, R-ST11, R-CC6, R-PT12 |
| 8 | `tool rm g --json` | the entry is not Talon's: kept, the warning on stderr, the binary is deleted, `tools.json` has no `g`. The envelope has `kept` | R-B6, R-ST6, R-J3 |
| 9 | `tool rm acme/z` | the entry is gone already: only the binary is deleted, no warning | R-B6, R-ST6 |
| 10 | `tool ls` | no tool: `no tool is installed. Run: tln tool install owner/app`. `tools.json` is `{"format":1,"tools":{}}` | R-T4, R-B6 |
| 11 | `tool rm foo` | `foo` is not installed any more: exit 2 | R-SC3 |
| 12 | `tool update` | gap test (C6): no tool is installed (`tools.json` is `{"tools":{}}`): the line `no tool is installed. ...` on stdout, exit 0, no request, no lock | R-T25, R-T7 |
| 13 | `tool rebuild` | the same line, exit 0 | R-T7 |
| 14 | `tool update --json` | the line goes to stderr, the envelope on stdout has `"tools":[]` | R-J1 to R-J4 |
| 15 | `tool rebuild --json` | the same | R-J1 to R-J4 |
"""
c = Case("tm1-manage", RULES)
c.tools([
    {"key": "foo", "name": "acme/foo", "source": release("1.1.0", "acme/foo", "1.1.0", "foo-1.1.0"), "libs": ["libm.so.6"], "at": "2026-10-01T10:00:00Z"},
    {"key": "g", "name": "acme/g", "source": git(AAAA, "main"), "path": "apps/cli", "nightly": OLD, "at": "2026-09-02T08:00:00Z"},
    {"key": "z", "name": "acme/z", "source": release("2.0.0", "acme/z", "2.0.0", "z-2.0.0"), "at": "2026-09-03T08:00:00Z"},
])
c.files("foo", data="foo bin\n", entry="foo bin\n")
c.files("g", data="g bin\n", entry="not from tln\n")
c.files("z", data="z bin\n")
c.finish(["tool ls", "tool ls --json", "tool rm nope", "tool rm acme/zzz", "tool rm talon", "tool rm foo --dry-run", "tool rm foo", "tool rm g --json", "tool rm acme/z", "tool ls", "tool rm foo", "tool update", "tool rebuild", "tool update --json", "tool rebuild --json"])

# ---------------------------------------------------------------- tg1-git
RULES = """Slice 048, `tln tool install --git` (entry `commands`). One home with the compiler `nightly-2026-10-14-38a3029` (the pin of each app), `TALON_NOW=2026-10-15T12:00:00Z`. `tools.json` has `gapp` (acme/gapp 1.0.0, a release; the binary and the entry are Talon's).
The fake API gives the commit of each ref (`fx/http/.../commits/<ref>`): acme/gapp main is aaaaaaaa, acme/gapp v2 is bbbbbbbb, acme/sub dd03c09e is dd03c09e. The fake tar writes `main.roc` (an app), `apps/cli/main.roc` (an app with no dependency) and `pkg/main.roc` (a package). The builds are the 3 rows of `fx/probes`.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool install --git acme/gapp@main` | the commit (media type, no token), the entry check, curl, the archive by the full sha, tar in `<tmp>/src`, `main.roc` read, the platform, the build with the pin, the install under the lock. A git install replaces the release tool. The scratch dir is deleted. `tools.json` has the commit and the ref | R-T23, R-T27, R-T2, R-T3, R-T4, R-R3, R-R7, R-SE12, R-CC2, R-CC6 |
| 2 | the same | the head is the installed commit: `Present`, no download, no build, no lock | R-T26 |
| 3 | `tool install acme/sub@dd03c09e --path apps/cli` | a sha selector needs no `--git` (R-SL10): the repo name `sub` is the binary name; the app is `apps/cli/main.roc`, `tools.json` has the `path` | R-T23, R-SL10, R-T28, R-SE12 |
| 4 | `tool install --git acme/gapp@v2 --json` | another ref with another commit: built and replaced (`replaced gapp git main with git v2@bbbbbbbb`). The envelope | R-T23, R-T26, R-T27, R-J1 to R-J4 |
| 5 | `tool install --git acme/gapp@main --as other` | `gapp` is installed as `gapp` already: exit 2 before any request | R-T27, R-T28 |
| 6 | `tool install --git acme/gapp@main --path pkg` | `pkg/main.roc` is a package: exit 2, no build, the scratch dir is deleted | R-T23, R-T10 |
| 7 | `tool install --git acme/gapp@main --path nodir` | no `main.roc` in `nodir`: exit 2, the scratch dir is deleted | R-T23, R-SE12 |
"""
c = Case("tg1-git", RULES)
c.toolchain(PIN)
c.tools([{"key": "gapp", "name": "acme/gapp", "source": release("1.0.0", "acme/gapp", "1.0.0", "gapp-1.0.0")}])
c.files("gapp", data="old gapp\n", entry="old gapp\n")
c.write("fx/src/gapp.src", app())
c.write("fx/src/cli.src", app(deps=()))
c.write("fx/src/pkg.src", package())
c.platform()
c.commit("acme/gapp", "main", AAAA)
c.commit("acme/gapp", "v2", BBBB)
c.commit("acme/sub", "dd03c09e", DD03)
c.tarball([("main.roc", "gapp"), ("apps/cli/main.roc", "cli"), ("pkg/main.roc", "pkg")])
c.finish(["tool install --git acme/gapp@main", "tool install --git acme/gapp@main", "tool install acme/sub@dd03c09e --path apps/cli", "tool install --git acme/gapp@v2 --json",
          "tool install --git acme/gapp@main --as other", "tool install --git acme/gapp@main --path pkg", "tool install --git acme/gapp@main --path nodir"], [BUILD_OK] * 3)

# ---------------------------------------------------------------- tg2-gitstops
RULES = """Slice 048, the stops of `tln tool install --git` (entry `commands`). Same home as `tg1-git` (the compiler installed, `tools.json` with `gapp` = acme/gapp 1.0.0, a release), and the file `<bin>/fe`, which tln did not write. The fake tar writes no file.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool install --git acme/empty@main` | the source has no `main.roc` at its top: exit 2 that names `--path`, the scratch dir is deleted, no build | R-T23, R-T10 |
| 2 | `tool install --git acme/gapp@nosuch` | the API answers 422: exit 2, no download | R-T23, R-SL13 |
| 3 | `tool install --git acme/gapp@main --offline` | exit 15, no request | R-DI12 |
| 4 | `tool install --git acme/gapp@main` with `TALON_DOWNLOADER=wget` | the commit is found, then exit 18 (the message names curl): no download | R-DA3, R-SE12 |
| 5 | `tool install --git acme/gapp` | no ref: exit 2, no call | R-SL13 |
| 6 | `tool install --git acme/gapp@main --path ../x` | the path leaves the repository: exit 2, no call | R-SE12 |
| 7 | `tool install --git other/gapp@main` | `gapp` is the binary name of acme/gapp: exit 2 that names `--as`, before any request | R-T28, R-NM11 |
| 8 | `tool install --git acme/fe@main` | `<bin>/fe` is a file that tln did not write: after the commit request, exit 2 before the download and the build | R-ST6, R-ST11 |
| 9 | `tool install --git acme/gapp@main --resolve` | `--resolve` is a later slice: exit 2 `is not built yet`, no call | R-T1 |
"""
c = Case("tg2-gitstops", RULES)
c.toolchain(PIN)
c.tools([{"key": "gapp", "name": "acme/gapp", "source": release("1.0.0", "acme/gapp", "1.0.0", "gapp-1.0.0")}])
c.files("gapp", data="old gapp\n", entry="old gapp\n")
c.write("given/home/.local/bin/fe", "not from tln\n")
c.platform()
c.commit("acme/empty", "main", AAAA)
c.commit("acme/gapp", "nosuch", status=422)
c.commit("acme/gapp", "main", AAAA)
c.commit("acme/fe", "main", BBBB)
c.tarball([])
c.finish(["tool install --git acme/empty@main", "tool install --git acme/gapp@nosuch", "tool install --git acme/gapp@main --offline", "tool install --git acme/gapp@main env:TALON_DOWNLOADER=wget",
          "tool install --git acme/gapp", "tool install --git acme/gapp@main --path ../x", "tool install --git other/gapp@main", "tool install --git acme/fe@main", "tool install --git acme/gapp@main --resolve"])

# ---------------------------------------------------------------- tr1-rebuild
RULES = """Slice 048, `tln tool rebuild` (entry `commands`). One home with the compilers `nightly-2026-10-14-38a3029` (the pin of each app) and `nightly-2026-10-12-2664a27`. `tools.json` has `foo` (acme/foo 1.1.0, built with `nightly-2026-10-12-2664a27`, which is not the pin of the header) and
`g` (acme/g from main at aaaaaaaa, `--path apps/cli`, built with `nightly-2026-10-11-1a2b3c4`, which is not installed; it is in the nightly list). The builds are the rows of `fx/probes` in order: pass, pass, pass, pass, build errors.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool rebuild foo` | the bundle of the URL of `tools.json` is fetched, the platform checked, then the build with the compiler of `tools.json` (2664a27, not the pin 38a3029). The entry and the binary are made again, `tools.json` has the new `sha256` and `installed_at`. No request for the release list | R-T7, R-T5, R-ST9, R-CC6 |
| 2 | `tool rebuild g` (`env:TALON_INTERACTIVE=0`) | the compiler of the build is not installed, no person and no flag: exit 13, nothing is built or changed. The source archive was fetched before (the plan is complete first) and the scratch dir is deleted | R-T5, R-T25, R-DL1, R-DL4 |
| 3 | `tool rebuild g --yes` (`env:TALON_INTERACTIVE=0`) | the compiler is downloaded again (R-T5), then the archive of the recorded commit (no commit request) is built with it, in `apps/cli` | R-T7, R-T5, R-T23, R-DL1 |
| 4 | `tool rebuild --json` | all tools in the order of the file: foo, then g (both compilers are installed now). The text on stderr, the envelope on stdout | R-T7, R-T25, R-J1 to R-J4 |
| 5 | `tool rebuild foo` | the build has errors: exit 11, `tools.json` and the files are as before, the temp dir is deleted | R-T7, R-CC2 |
"""
c = Case("tr1-rebuild", RULES)
c.toolchain(PIN)
c.toolchain(PIN2)
c.with_nightlies()
c.tools([
    {"key": "foo", "name": "acme/foo", "source": release("1.1.0", "acme/foo", "1.1.0", "foo-1.1.0"), "nightly": PIN2},
    {"key": "g", "name": "acme/g", "source": git(AAAA, "main"), "path": "apps/cli", "nightly": OLD},
])
c.files("foo", data="old foo\n", entry="old foo\n")
c.files("g", data="old g\n", entry="old g\n")
c.bundle("foo-1.1.0", app())
c.write("fx/src/cli.src", app(deps=()))
c.platform()
c.tarball([("apps/cli/main.roc", "cli")])
c.finish(["tool rebuild foo", "tool rebuild g env:TALON_INTERACTIVE=0", "tool rebuild g --yes env:TALON_INTERACTIVE=0", "tool rebuild --json", "tool rebuild foo"], [BUILD_OK, BUILD_OK, BUILD_OK, BUILD_OK, BUILD_FAIL])

# ---------------------------------------------------------------- tr2-rebuildstops
RULES = """Slice 048, the stops of `tln tool rebuild` (entry `commands`). One home with the compiler `nightly-2026-10-14-38a3029`. `tools.json` has `foo` (acme/foo 1.1.0, built with the installed compiler), `fe` (acme/fe 1.0.0; `<bin>/fe` is a file that tln did not write), `zz` (a release URL that is no release URL) and `gh` (a git tool whose name is `host/a/b`).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool rebuild fe` | the entry is not Talon's: exit 2 before the bundle is fetched, no build | R-ST6, R-ST11, R-T7 |
| 2 | `tool rebuild zz` | the URL of the manifest has no bundle hash: exit 19 that names the tool, no call after the file read | R-T7, R-TF1 |
| 3 | `tool rebuild gh` | the name is not owner/repo, so the archive is not known: exit 19 | R-T7, R-T23 |
| 4 | `tool rebuild` | all tools: `foo` is planned (the bundle is fetched), `fe` stops the plan: exit 2, nothing is built or changed (foo has the old files) | R-T7, R-T25, R-CC6 |
| 5 | `tool rebuild nope` | no installed tool has the short name: exit 2 | R-SC3 |
| 6 | `tool rebuild talon` | `talon` is slices 050 and 051: exit 2 `is not built yet`, no call | R-CM16 |
"""
c = Case("tr2-rebuildstops", RULES)
c.toolchain(PIN)
c.tools([
    {"key": "foo", "name": "acme/foo", "source": release("1.1.0", "acme/foo", "1.1.0", "foo-1.1.0")},
    {"key": "fe", "name": "acme/fe", "source": release("1.0.0", "acme/fe", "1.0.0", "fe-1.0.0")},
    {"key": "zz", "name": "acme/zz", "source": {"kind": "release", "version": "1.0.0", "url": "https://x/zz.tar.zst"}},
    {"key": "gh", "name": "host/a/b", "source": git(AAAA, "main")},
])
c.files("foo", data="old foo\n", entry="old foo\n")
c.files("fe", data="old fe\n")
c.write("given/home/.local/bin/fe", "not from tln\n")
c.bundle("foo-1.1.0", app())
c.platform()
c.finish(["tool rebuild fe", "tool rebuild zz", "tool rebuild gh", "tool rebuild", "tool rebuild nope", "tool rebuild talon"])

# ---------------------------------------------------------------- tu1-update
RULES = """Slice 048, `tln tool update` (entry `commands`). One home with the compiler `nightly-2026-10-14-38a3029` only (`TALON_NOW=2026-10-15T12:00:00Z`, `min-release-age` 2 days). `tools.json` has 5 tools:
`foo` (acme/foo 1.1.0; the repo has 1.2.0, an app whose pin is `nightly-2026-10-11-1a2b3c4`, not installed), `bar` (acme/bar 1.0.0, the newest), `gm` (acme/gm from main at 1111111, the head is bbbbbbbb; the app pin is `nightly-2026-10-12-2664a27`, not installed),
`gs` (acme/gs from stable, the head is the installed commit) and `gp` (acme/gp from the ref `dd03c09e`, a commit). Both compilers are in the nightly list. The builds are the 2 rows of `fx/probes`. A fake tty (a person) and the answers of `fx/answers` in order.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update` (`env:TALON_INTERACTIVE=0`) | the plan: the release lists of foo and bar, the heads of gm and gs, the source of gm, the platform. gp: no call. 2 compilers are not installed, no person and no flag: exit 13 that names `--yes`, nothing is built or changed, the scratch dir is deleted | R-T24, R-T25, R-DL1, R-DL4 |
| 2 | `tool update` (answer `n`) | one prompt for both downloads (the offers read the nightly list first): No is exit 13, no tool is changed | R-T25, R-DL1, R-NM5 |
| 3 | `tool update` (answer `y`) | the same prompt, Yes: both compilers are downloaded, then foo is built with the pin of 1.2.0 and gm with its pin. One line for each tool in the order of the file: updated, up to date, updated, up to date, pinned. gp is `gp: pinned to commit dd03c09e` | R-T24, R-T25, R-T9, R-T26, R-DL1 |
| 4 | `tool update --json` | all tools are current now: no build, no prompt; the envelope has the 5 outcomes | R-T24, R-J1 to R-J4 |
| 5 | `tool update foo` | one tool: the release list, `foo 1.2.0 is up to date` | R-T24, R-T26 |
| 6 | `tool update gp` | a commit: `pinned to commit dd03c09e`, no request at all | R-T24 |
| 7 | `tool update nope` | no installed tool has the short name: exit 2 | R-SC3 |
| 8 | `tool update talon` | `talon` is slices 050 and 051: exit 2 `is not built yet`, no call | R-CM16 |
"""
c = Case("tu1-update", RULES)
c.toolchain(PIN)
c.with_nightlies()
c.tools([
    {"key": "foo", "name": "acme/foo", "source": release("1.1.0", "acme/foo", "1.1.0", "foo-1.1.0")},
    {"key": "bar", "name": "acme/bar", "source": release("1.0.0", "acme/bar", "1.0.0", "bar-1.0.0")},
    {"key": "gm", "name": "acme/gm", "source": git(OLDC, "main")},
    {"key": "gs", "name": "acme/gs", "source": git(AAAA, "stable")},
    {"key": "gp", "name": "acme/gp", "source": git(DD03, "dd03c09e")},
])
for k in ("foo", "bar", "gm", "gs", "gp"):
    c.files(k, data=f"old {k}\n", entry=f"old {k}\n")
c.repo("acme/foo", [("1.2.0", "foo-1.2.0", "2026-09-01T12:00:00Z", app(pin=OLD)), ("1.1.0", "foo-1.1.0", "2026-08-01T12:00:00Z", app())])
c.repo("acme/bar", [("1.0.0", "bar-1.0.0", "2026-08-01T12:00:00Z", app())])
c.commit("acme/gm", "main", BBBB)
c.commit("acme/gs", "stable", AAAA)
c.write("fx/src/gm.src", app(pin=PIN2))
c.platform()
c.tarball([("main.roc", "gm")])
c.finish(["tool update env:TALON_INTERACTIVE=0", "tool update", "tool update", "tool update --json", "tool update foo", "tool update gp", "tool update nope", "tool update talon"],
         [BUILD_OK, BUILD_OK], answers=["n", "y"], tty=True)
print("ok")
