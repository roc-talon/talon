#!/usr/bin/env python3
"""Slice 047: makes the `given/` and `fx/` files of the L2 cases `tool/ti3-compiler` and `tool/ti4-nothing` (no `expect/`: UPDATE=1 writes it from the reference, TW21).
Run from the repo root: python3 research/slice-047-revert/gen-compiler.py. It only writes under tests/commands/cases/tool/ti3-compiler and ti4-nothing (rules, entry, fx, given). It never touches ti1-install or ti2-refusals
(do not import research/slice-046-revert/gen-tools.py: it rewrites those two cases). The hashes are the base58 of the sha256 of a label, so they are valid package hashes and stay the same on each run."""
import hashlib, json, os, shutil

ROOT = "tests/commands/cases/tool"
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
PF = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst"
PF_HASH = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"
JSON_URL = "https://github.com/acme/json/releases/download/2.1.0/3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm.tar.zst"
JSON_HASH = "3zDZDG7iHnTKLRPPd5KSrCj4pJq6CPjeT1HyqHAFp6Wm"
PIN = "nightly-2026-10-11-1a2b3c4"  # the pin of each app: not installed, in the nightly list of the case (73.7 MB)
A = "nightly-2026-10-14-38a3029"
B = "nightly-2026-10-12-2664a27"
C = "nightly-2026-10-05-aaaaaaa"
DD = "nightly-2026-10-01-bbbbbbb"
HOST = "x64musl"
FIX = "../fixtures/check/out"


def b58(label):
    n = int.from_bytes(hashlib.sha256(label.encode()).digest(), "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return out


def digest(bundle):
    """BuildSkip.digest of the closure of a tool (D-E1): the bundle hash and the hashes of the header, sorted, one per line."""
    hashes = sorted(set([bundle, PF_HASH, JSON_HASH]))
    return hashlib.sha256(("".join(h + "\n" for h in hashes)).encode()).hexdigest()


def app():
    return "\n".join(["app [main!] {", f'\tpf: platform "{PF}",', f'\tdep0: "{JSON_URL}",', f'\troc: "{PIN}",', "}", "", "main! = |_args| Ok({})"]) + "\n"


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

    def write(self, rel, text):
        path = f"{self.dir}/{rel}"
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w").write(text)

    def repo(self, repo, label, published="2026-08-01T12:00:00Z", tag="1.0.0"):
        h = b58(label)
        item = {"tag_name": tag, "draft": False, "prerelease": False, "published_at": published,
                "assets": [{"name": f"{h}.tar.zst", "size": 1048576, "browser_download_url": f"https://github.com/{repo}/releases/download/{tag}/{h}.tar.zst"}]}
        self.write(f"fx/src/{label}.src", app())
        self.jobs.append(f"unbundle {h}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{h};copy:{{cwd}}/{h}/main.roc={{w}}/fx/src/{label}.src")
        self.write(f"fx/http/api.github.com/repos/{repo}/releases?per_page=100", "[\n" + json.dumps(item, separators=(",", ":")) + "\n]\n")
        return h

    def platform(self):
        text = 'platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}\n\texposes []\n\tpackages {}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n' + "".join(f'\t\t{t}: {{ inputs: ["libhost.a", app] }},\n' for t in ["x64mac", "arm64mac", "x64musl", "arm64musl"]) + "\t}\n"
        self.write("fx/src/platform-basic-cli.src", text)
        self.jobs.append(f"unbundle {PF_HASH}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{PF_HASH};copy:{{cwd}}/{PF_HASH}/main.roc={{w}}/fx/src/platform-basic-cli.src")

    def finish(self, commands, probes, units=(), answers=(), tty=True, programs=("curl", "wget", "tar")):
        self.write("fx/commands", "\n".join(commands) + "\n")
        self.write("fx/env", "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_GITHUB_API=https://api.github.com\n")
        self.write("fx/programs", "\n".join(programs) + "\n")
        self.write("fx/jobs", "# R-DA3 the download, R-FE2 `roc unbundle`, R-HF5 the extract, R-HF2 the chmod, R-GC10 the compat check. The first rule whose needle is in the arguments answers.\n" + "\n".join(self.jobs) + "\n")
        self.write("fx/probes", "# One row for each build, in order (the build probes of the case; a check of an app in a package dir is a unit probe: fx/units).\n" + "\n".join(probes) + "\n")
        if units:
            self.write("fx/units", "# <bundle hash>:<compiler id> <TAB> code <TAB> stdout <TAB> stderr. A check with no row passes.\n" + "\n".join(units) + "\n")
        if answers is not None and len(answers):
            self.write("fx/answers", "\n".join(answers) + "\n")
        if tty:
            self.write("fx/tty", "stdin=true\nstderr=true\n")


BUILD_OK = f"0\t{FIX}/build-pass.stdout\t-\tfile:{{out}}"
BUILD_FAIL = f"1\t{FIX}/build-errors.stdout\t{FIX}/build-errors.stderr\t-"
GENERIC_JOBS = [
    "curl --fail\t0\t-\t-\tfile:{out}",
    ".zip -C\t0\t-\t-\tfile:{dir}/roc.exe;file:{dir}/LICENSE;file:{dir}/legal_details",
    "tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details",
    "chmod 0755\t0\t-\t-\t-",
    "nightly-2026-10-11-1a2b3c4.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{w}/home/.cache/roc/compat-1a2b3c4",
]


def toolchain(case, tag):
    case.write(f"given/home/.cache/roc/toolchains/{tag}/.talon.json", json.dumps({"format": 1, "id": tag, "compat": "bbbbbbb"}, separators=(",", ":")) + "\n")


def nightlies(case):
    os.makedirs(f"{case.dir}/fx/http/api.github.com/repos/roc-lang/nightlies", exist_ok=True)
    shutil.copy("tests/commands/cases/roc/ri1-flow/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100", f"{case.dir}/fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100")


def fact(hash_, nightly, target, outcome, closure):
    return f"fact\t{hash_}\t{nightly}\t{target}\t{outcome}\t\t{closure}"


# ---------------------------------------------------------------- ti3-compiler
RULES3 = """Slice 047, the compiler choice of `tln tool install` when the pin is not installed (entry `commands`). One home with 4 installed compilers (A = nightly-2026-10-14-38a3029, B = nightly-2026-10-12-2664a27, C = nightly-2026-10-05-aaaaaaa, D = nightly-2026-10-01-bbbbbbb), no pin of any app installed
(the pin of each app is nightly-2026-10-11-1a2b3c4, in the nightly list of the case), `config.toml` with `[probe] timeout = 20`, `TALON_NOW=2026-10-15T12:00:00Z`, a fake tty (a person, so a run with no `env:TALON_INTERACTIVE=0` can be asked) and the answers of `fx/answers` in the order of the `ask` calls.
`compat.tsv` has the facts for acme/ev (the build keys (basic-cli, release, x64musl) and the digest of the closure of acme/ev): a fail of A, a pass of B, a pass of C; a check pass of the bundle on A; and the pass of D for acme/evp. Nothing for the other apps.
The builds are the rows of `fx/probes` in order: ev on B pass, two on B fail, two on C pass, three on B fail, dl on the pin pass (evp builds with D). The checks of an app in its package dir are the rows of `fx/units`.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool install acme/ev` | evidence: one `db_query` with the 4 build keys, A has a fail (blocked), B and C have a pass, D has none: B is first in the order (newer before older). `built with B (pin: P)`, no prompt, no `tty`, no check probe, one build with B | R-T13, R-T17, R-T21, R-BS1 |
| 2 | `tool install acme/two` (answer `2`) | no evidence (the facts of the digest of acme/ev are no evidence for another bundle): the prompt with the 4 options lines. Option 2: one round of 4 checks (A fails, B, C and D pass, `timeout=20`), one `db_write` with the 4 rows. Then the builds in order: B fails (a row), C passes (a row): installed with C. D is never built (the first pass stops the tries). `built with C (pin: P)` | R-T14, R-NI8, R-T17, R-T18, R-T19, R-T21, R-PP2, R-PP3, R-NR2 |
| 3 | `tool install acme/three --roc installed` (`env:TALON_INTERACTIVE=0`) | the flag is option 2: `trying 4 installed compiler releases`. A, C and D fail the check, B fails the build. No release built the app: exit 13 that lists the 3 releases with the first error line and names the flags. The facts are written | R-T16, R-T17, R-T19, R-T20, R-T21, R-NM3, R-NM6 |
| 4 | `tool install acme/again` (answers `2`, `3`) | option 2: the 4 checks fail (one round), no build. The prompt again, with the list and the options 1 and 3. `3`: exit 13, nothing downloaded or built | R-T14, R-T20, R-NI8, R-NM5 |
| 5 | `tool install acme/cancel` (answer `3`) | option 3: exit 13, no download, no probe | R-NI8, R-T14 |
| 6 | `tool install acme/evp --roc pinned` | the evidence (a pass of D for acme/evp) comes before the flag (D-E2): `built with D (pin: P)`, no download, no check, one build with D | R-T13, R-T6, R-T16 |
| 7 | `tool install acme/redo` (answers `2`, `1`) | review 2 (C3): option 2: the checks of A, C, D fail, B passes the check and fails the build (the `platform` line is printed for this build; this run is before the download run 8, because run 8 installs the pin). All failed: the prompt again with the list and options 1 and 3. `1`: download the pin (73.7 MB) and build with it. The `platform` line is printed once for the command (R-SE8): the build with the pin prints only the line `building ...` | R-SE8, R-T19, R-T20, R-NI8, R-DL1 |
| 8 | `tool install acme/dl` (answer Enter) | the default is option 1: download the pin (the list gives the size 73.7 MB), build with it | R-NI8, R-T14, R-T6, R-DL1, R-DL3, R-NR2 |
"""
c = Case("ti3-compiler", RULES3)
for t in (A, B, C, DD):
    toolchain(c, t)
apps = {"ev": b58("ev-1.0.0"), "two": b58("two-1.0.0"), "three": b58("three-1.0.0"), "again": b58("again-1.0.0"), "cancel": b58("cancel-1.0.0"), "evp": b58("evp-1.0.0"), "dl": b58("dl-1.0.0"), "redo": b58("redo-1.0.0")}
for name in apps:
    c.repo(f"acme/{name}", f"{name}-1.0.0")
c.platform()
nightlies(c)
c.jobs.extend(GENERIC_JOBS)
d_ev = digest(apps["ev"])
c.write("given/home/.cache/roc/talon/compat.tsv", "\n".join([
    "format\t1",
    fact(PF_HASH, A, HOST, "fail", d_ev),
    fact(PF_HASH, B, HOST, "pass", d_ev),
    fact(PF_HASH, C, HOST, "pass", d_ev),
    fact(apps["ev"], A, "any", "pass", ""),
    fact(PF_HASH, DD, HOST, "pass", digest(apps["evp"])),
]) + "\n")
c.write("given/home/.config/talon/config.toml", "[probe]\ntimeout = 20\n")
SYN = f"1\t-\t{FIX}/syntax.stderr"
TYP = f"1\t-\t{FIX}/app-errors.stderr"
units = [
    f"{apps['two']}:{A}\t{SYN}",
    f"{apps['three']}:{A}\t{SYN}",
    f"{apps['three']}:{C}\t{TYP}",
    f"{apps['three']}:{DD}\t{TYP}",
    f"{apps['again']}:{A}\t{SYN}",
    f"{apps['again']}:{B}\t{TYP}",
    f"{apps['again']}:{C}\t{SYN}",
    f"{apps['again']}:{DD}\t{TYP}",
    f"{apps['redo']}:{A}\t{SYN}",
    f"{apps['redo']}:{C}\t{SYN}",
    f"{apps['redo']}:{DD}\t{TYP}",
]
c.finish(
    ["tool install acme/ev", "tool install acme/two", "tool install acme/three --roc installed env:TALON_INTERACTIVE=0", "tool install acme/again", "tool install acme/cancel", "tool install acme/evp --roc pinned", "tool install acme/redo", "tool install acme/dl"],
    [BUILD_OK, BUILD_FAIL, BUILD_OK, BUILD_FAIL, BUILD_OK, BUILD_FAIL, BUILD_OK, BUILD_OK],
    units,
    ["2", "2", "3", "3", "2", "1", ""],
)

# ---------------------------------------------------------------- ti4-nothing
RULES4 = """Slice 047, the compiler choice when no compiler release is installed (entry `commands`): the prompt has the options 1 and 3 (R-T15), `--roc installed` has nothing to try, and the evidence pass makes no query. Same pin as `ti3-compiler` (nightly-2026-10-11-1a2b3c4, not installed, in the nightly list), a fake tty, `TALON_NOW=2026-10-15T12:00:00Z`.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool install acme/x` (answers `2`, `3`) | the prompt has no option 2 (no release is installed): `2` is not offered, so the command asks again; `3` is exit 13. No `db_query` (no key), no probe | R-T15, R-NI8, R-T13 |
| 2 | `tool install acme/x --roc installed` (`env:TALON_INTERACTIVE=0`) | option 2 has no release: exit 13 `no compiler release is installed to try`, no line `trying`, no probe | R-T16, R-T20 |
| 3 | `tool install acme/x` (`env:TALON_INTERACTIVE=0`) | no person and no flag: exit 13 that names `--roc pinned`, `--yes` and `TALON_AUTO_INSTALL=yes` (no query, no download) | R-T15, R-T16, R-NM5 |
"""
c = Case("ti4-nothing", RULES4)
c.repo("acme/x", "x-1.0.0")
c.platform()
nightlies(c)
c.jobs.extend(GENERIC_JOBS)
c.finish(["tool install acme/x", "tool install acme/x --roc installed env:TALON_INTERACTIVE=0", "tool install acme/x env:TALON_INTERACTIVE=0"], [], (), ["2", "3"])
print("ok")
