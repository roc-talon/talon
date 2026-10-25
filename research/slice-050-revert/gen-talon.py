#!/usr/bin/env python3
"""Writes the given files, the fx files, the entry and the rules of the L2 cases of slice 050 (`tln tool update talon`): ts1-update, ts2-stops, ts3-nostart, ts4-rocforeign, ts3b-foreign.
It writes no `expect/` file (the runner does, with UPDATE=1, and the agent reads each one: TW21). Usage: python3 research/slice-050-revert/gen-talon.py (from the repo root)."""
import hashlib, json, os, shutil

ROOT = "tests/commands/cases/tool"
SHA0 = "0" * 64
TAG_URL = "https://github.com/roc-talon/talon/releases/download"


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)


def asset(tag, name, size=1000):
    return {"name": name, "size": size, "browser_download_url": f"{TAG_URL}/{tag}/{name}"}


def release(tag, published, assets=("tln-x64musl", "tln-arm64musl", "sha256sums.txt"), draft=False, pre=False):
    return {
        "tag_name": tag,
        "draft": draft,
        "prerelease": pre,
        "published_at": published,
        "assets": [asset(tag, n) for n in assets],
    }


def binary(ver):
    return f"fake tln {ver}\n"


def sums_good(ver):
    return f"{sha(binary(ver))}  tln-x64musl\n{SHA0}  tln-arm64musl\n"


def entry_json(version, installed_at="2026-09-01T12:00:00Z"):
    return {
        "name": "roc-talon/talon",
        "source": {"kind": "prebuilt", "version": version, "url": f"{TAG_URL}/v{version}/tln-x64musl"},
        "build": {"hashes": [], "nightly": "", "target": "x64musl"},
        "sha256": sha("old tln\n"),
        "libs": [],
        "installed_at": installed_at,
    }


GP = {
    "name": "acme/gp",
    "source": {"kind": "git", "commit": "dd03c09e5f0a3b6c7d8e9f001122334455667788", "ref": "dd03c09e"},
    "build": {"hashes": ["GYSsHBiLMwr55ej1xUPJn141oVjjhaftyqg87fp5i3YM"], "nightly": "nightly-2026-10-14-38a3029", "target": "x64musl"},
    "sha256": SHA0,
    "libs": [],
    "installed_at": "2026-09-01T00:00:00Z",
}


def tools_json(talon=None, gp=True, extra=None):
    tools = {}
    if talon is not None:
        tools["talon"] = talon
    if gp:
        tools["gp"] = GP
    return json.dumps({"format": 1, "tools": tools}, separators=(",", ":"))


def case(name, rules, commands, releases, srcs, jobs, talon, gp=False, bin_tln="old tln\n", bin_roc="old tln\n", env_extra=(), entry_tools_json=None, no_roc=False, programs=("curl", "wget"), platform=None):
    d = f"{ROOT}/{name}"
    shutil.rmtree(d, ignore_errors=True)
    put(f"{d}/entry", "commands\n")
    put(f"{d}/rules", rules)
    home = f"{d}/given/home"
    put(f"{home}/.local/share/talon/tools.json", tools_json(talon, gp) + "\n")
    put(f"{home}/.local/share/talon/bin/tln", bin_tln)
    put(f"{home}/.local/bin/tln", bin_tln)
    if not no_roc:
        put(f"{home}/.local/bin/roc", bin_roc)
    if gp:
        put(f"{home}/.local/share/talon/bin/gp", "old gp\n")
        put(f"{home}/.local/bin/gp", "old gp\n")
    put(f"{d}/fx/commands", "".join(c + "\n" for c in commands))
    put(f"{d}/fx/env", "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_GITHUB_API=https://api.github.com\n" + "".join(e + "\n" for e in env_extra))
    put(f"{d}/fx/programs", "".join(p + "\n" for p in programs))
    if platform:
        put(f"{d}/fx/platform", platform + "\n")
    put(f"{d}/fx/http/api.github.com/repos/roc-talon/talon/releases?per_page=100", json.dumps(releases, separators=(",", ":")) + "\n")
    for fname, text in srcs.items():
        put(f"{d}/fx/src/{fname}", text)
    put(f"{d}/fx/jobs", jobs)
    # TW15: the time of the cache page is a value of the case (the fake gives the real time of the file otherwise): the offline line shows it.
    put(f"{d}/fx/mtimes", "talon/1.meta 1792065600\n")


def jobs_text(rows):
    head = "# R-DA3 the download of the binary and of sha256sums.txt, R-HF2 chmod, R-S3 `--version` of the new file. The first rule whose needle is in the arguments answers. `{out}` is the file of the `--output` of the curl job.\n"
    return head + "".join("\t".join(r) + "\n" for r in rows)


def ok_rows(ver):
    return [
        (f"v{ver}/sha256sums.txt", "0", "-", "-", f"copy:{{out}}={{w}}/fx/src/sums-{ver}"),
        (f"v{ver}/tln-x64musl", "0", "-", "-", f"copy:{{out}}={{w}}/fx/src/bin-{ver}"),
    ]


TAIL = [("chmod 0755", "0", "-", "-", "-"), ("--version", "0", "tln 0.3.4", "-", "-")]
COMMON_RELEASES = [
    release("v0.3.5", "2026-10-14T12:00:00Z"),
    release("v0.3.9", "2026-10-01T12:00:00Z", draft=True),
    release("v0.4.0-rc1", "2026-10-02T12:00:00Z", pre=True),
    release("nightly", "2026-10-03T12:00:00Z"),
]

# ts1-update: the prebuilt path (Linux): the young release is skipped, the entry says 0.3.1.
case(
    "ts1-update",
    """Slice 050, `tln tool update talon` (entry `commands`). One home: `tools.json` has the entry `talon` (prebuilt 0.3.1) and the tool `gp` (a commit ref: no request). `<data>/bin/tln` and the entries `~/.local/bin/tln` and `roc` have the text `old tln` (the same sha256: the entries are Talon's, R-ST11).
`TALON_NOW=2026-10-15T12:00:00Z`, `min-release-age` 2 days. The release list of roc-talon/talon: v0.3.5 (1 day old, too young), v0.3.4 (the answer), a draft, a prerelease and a tag that is no version (all left out), v0.3.1.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon` | the list (one request), v0.3.4 picked (R-T9: v0.3.5 is too young), the entries (checked before the download), one download job for the binary and one for sha256sums.txt, the sha256 check, `chmod 0755`, `--version`, then under the lock: `tools.json` read again, the check again, the rename over `<data>/bin/tln`, the entries `tln` and `roc` again (hard link to a temp name, rename), `tools.json` written. `updated talon 0.3.1 to 0.3.4 (roc-talon/talon)`. The temp file and the scratch dir are deleted | R-S2, R-S3, R-T22, R-T9, R-ST9, R-SE13, R-DA3, R-DA4, R-HF2, R-CC1, R-CC2, R-CC6, R-T4 |
| 2 | `tool update talon` | the entry says 0.3.4: `talon 0.3.4 is up to date`, no download, no write. The page is cached (no request) | R-S2, R-S4 |
| 3 | `tool update roc-talon/talon --json` | the full name is the same operand. The envelope has the outcome `up_to_date` | R-J1 to R-J4, R-CM16 |
| 4 | `tool list` | `tools.json` has the entry `talon`: it is read, and it is not a row of the list. Only `gp` | R-T4, Q-S2 |
| 5 | `tool update` | no name: all tools. `gp` is pinned to a commit (no request). `talon` is not one of them | R-T25, Q-S2 |
""",
    ["tool update talon", "tool update talon", "tool update roc-talon/talon --json", "tool list", "tool update"],
    [release("v0.3.4", "2026-10-01T12:00:00Z"), release("v0.3.1", "2026-09-01T12:00:00Z")] + COMMON_RELEASES,
    {"bin-0.3.4": binary("0.3.4"), "sums-0.3.4": sums_good("0.3.4")},
    jobs_text(ok_rows("0.3.4") + TAIL),
    entry_json("0.3.1"),
    gp=True,
)

# ts2-stops: each run picks another release through TALON_NOW (the page is cached after run 1: a time in the future gives age 0).
REL2 = [
    release("v0.2.5", "2026-07-01T12:00:00Z", assets=("tln-x64musl", "tln-arm64musl")),
    release("v0.2.6", "2026-07-10T12:00:00Z"),
    release("v0.3.1", "2026-09-01T12:00:00Z"),
    release("v0.3.2", "2026-09-10T12:00:00Z"),
    release("v0.3.4", "2026-10-01T12:00:00Z"),
    release("v0.3.5", "2026-10-14T12:00:00Z"),
]
bad_sums = f"{SHA0}  tln-x64musl\n{SHA0}  tln-arm64musl\n"
unlisted = f"{SHA0}  tln-arm64musl\n"
case(
    "ts2-stops",
    """Slice 050, the stops of `tln tool update talon` (entry `commands`). The entry says 0.1.0. Each run sets `TALON_NOW`, so another release is the newest that is old enough (R-T9). The page of the list is read once: the next runs find it younger than the clock.
Each failed run leaves no file: the bin dir, the data bin dir and `talon/tmp` are as they were (the file `tree.diff` shows only the last run).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon` (2026-07-05) | v0.2.5 has no sha256sums.txt: exit 16, no download, no entry check | R-S1, R-SE13 |
| 2 | `tool update talon` (2026-07-15) | v0.2.6: sha256sums.txt does not list tln-x64musl: exit 16. The download ran, the scratch dir and the temp file are deleted | R-S1, R-SE13, R-CC2 |
| 3 | `tool update talon` (2026-09-03) | v0.3.1: the download of the binary ends with curl exit 22 (404): exit 15, the temp file and the scratch dir are deleted | R-DA7, R-CC2 |
| 4 | `tool update talon` (2026-09-12) | v0.3.2: the sha256 differs: exit 16, the old tln stays, nothing is renamed, the temp file is deleted | R-S1, R-SE13, R-S3, R-DA4 |
| 5 | `tool update talon --offline` | the cached page, v0.3.4: exit 15 (the download is needed), no entry check, no download | R-DI12 |
| 6 | `tool update talon` | v0.3.4 works: the first run that changes a file | R-S2, R-S3 |
| 7 | `tool update talon` | up to date (the entry says 0.3.4) | R-S2 |
""",
    [
        "tool update talon env:TALON_NOW=2026-07-05T12:00:00Z",
        "tool update talon env:TALON_NOW=2026-07-15T12:00:00Z",
        "tool update talon env:TALON_NOW=2026-09-03T12:00:00Z",
        "tool update talon env:TALON_NOW=2026-09-12T12:00:00Z",
        "tool update talon --offline",
        "tool update talon",
        "tool update talon",
    ],
    REL2,
    {"sums-0.2.6": unlisted, "bin-0.2.6": binary("0.2.6"), "sums-0.3.1": sums_good("0.3.1"), "sums-0.3.2": bad_sums, "bin-0.3.2": binary("0.3.2"), "bin-0.3.4": binary("0.3.4"), "sums-0.3.4": sums_good("0.3.4")},
    jobs_text(
        [
            ("v0.2.6/sha256sums.txt", "0", "-", "-", "copy:{out}={w}/fx/src/sums-0.2.6"),
            ("v0.2.6/tln-x64musl", "0", "-", "-", "copy:{out}={w}/fx/src/bin-0.2.6"),
            ("v0.3.1/sha256sums.txt", "0", "-", "-", "copy:{out}={w}/fx/src/sums-0.3.1"),
            ("v0.3.1/tln-x64musl", "22", "-", "curl: (22) The requested URL returned error: 404", "-"),
            ("v0.3.2/sha256sums.txt", "0", "-", "-", "copy:{out}={w}/fx/src/sums-0.3.2"),
            ("v0.3.2/tln-x64musl", "0", "-", "-", "copy:{out}={w}/fx/src/bin-0.3.2"),
        ]
        + ok_rows("0.3.4")
        + TAIL
    ),
    entry_json("0.1.0"),
)

# ts3-nostart: the new file does not start.
case(
    "ts3-nostart",
    """Slice 050, `tln tool update talon` with a new file that does not start (R-S3). One run. The release v0.3.4 downloads and has the right sha256, `chmod` works, and `<temp> --version` exits with 1.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon` | exit 1 `the new tln 0.3.4 does not start (exit 1). The old tln stays.` No rename, no entry, no write of `tools.json`. The temp file and the scratch dir are deleted | R-S3, R-CC2 |
""",
    ["tool update talon"],
    [release("v0.3.4", "2026-10-01T12:00:00Z")],
    {"bin-0.3.4": binary("0.3.4"), "sums-0.3.4": sums_good("0.3.4")},
    jobs_text(ok_rows("0.3.4") + [("chmod 0755", "0", "-", "-", "-"), ("--version", "1", "-", "Segmentation fault", "-")]),
    entry_json("0.3.1"),
)

# ts3b-foreign: the entry of tln is not Talon's.
case(
    "ts3b-foreign",
    """Slice 050, `tln tool update talon` when `~/.local/bin/tln` is a file that tln did not write (R-ST6, R-ST11). One run: exit 2 before any download. The check reads the bin dir and the hashes only.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon` | exit 2 `<path> is not a file that tln wrote, so tln does not replace it. ...`, no download, no change | R-ST6, R-ST11, R-ST9 |
""",
    ["tool update talon"],
    [release("v0.3.4", "2026-10-01T12:00:00Z")],
    {"bin-0.3.4": binary("0.3.4"), "sums-0.3.4": sums_good("0.3.4")},
    jobs_text(ok_rows("0.3.4") + TAIL),
    entry_json("0.3.1"),
    bin_tln="old tln\n",
)
# the entry is a different file: write it after the case is made
put(f"{ROOT}/ts3b-foreign/given/home/.local/bin/tln", "another program\n")

# ts4-rocforeign: no entry of talon in tools.json, a roc that is not Talon's.
case(
    "ts4-rocforeign",
    """Slice 050, `tln tool update talon` with no entry `talon` in `tools.json` (the installed version is `Help.version`, 0.0.0) and a `roc` in the bin dir that tln did not write (a system roc that `tln setup` did not replace, R-ST2). The entry `tln` is Talon's.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon` | v0.3.4 works. `roc` stays (R-ST6) with the warning, `tln` is made again. `tools.json` gets the entry `talon` (the last entry). `updated talon 0.0.0 to 0.3.4 (roc-talon/talon)` | R-ST6, R-ST9, R-ST11, R-S3, R-T4, Q-E1, Q-M1 |
""",
    ["tool update talon"],
    [release("v0.3.4", "2026-10-01T12:00:00Z")],
    {"bin-0.3.4": binary("0.3.4"), "sums-0.3.4": sums_good("0.3.4")},
    jobs_text(ok_rows("0.3.4") + TAIL),
    None,
    gp=True,
    bin_roc="system roc\n",
)

# ts5-windows: the machine is Windows (R-ST10): the `.del` renames, no chmod, the names with `.exe`. The bin dir of Windows is `<USERPROFILE>\\.local\\bin` (R-LY8): in the fake, the dir `home\\.local\\bin` of the case dir.
def windows():
    name = "ts5-windows"
    d = f"{ROOT}/{name}"
    shutil.rmtree(d, ignore_errors=True)
    put(f"{d}/entry", "commands\n")
    put(
        f"{d}/rules",
        """Slice 050, `tln tool update talon` on Windows (R-ST10, R-S3). The fake machine is `os=windows arch=x64`, so the asset is `tln-x64win.exe` and the files have `.exe`. The bin dir of Windows is `<USERPROFILE>\\.local\\bin` (R-LY8): in the case it is the dir `home\\.local\\bin` (a name with `\\`). `tln.exe` and `roc.exe` of it and `<data>/bin/tln.exe` have the text `old tln`.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon` | no `chmod` job. Under the lock, before the rename over the file: `rename!` of `<data>/bin/tln.exe`, then of the entries `tln.exe` and `roc.exe` to `<name>.<hex>.del` (the hex of the one `random!`), then the rename of the temp file, then the entries again (hard link to a temp name, rename). The 3 `.del` files stay: no later start deletes them in this slice (Q-W1) | R-ST10, R-S3, R-ST9, R-HF2 |
| 2 | `tool update talon` | up to date | R-S2 |
""",
    )
    home = f"{d}/given/home"
    put(f"{home}/.local/share/talon/tools.json", json.dumps({"format": 1, "tools": {"talon": dict(entry_json("0.3.1"), source={"kind": "prebuilt", "version": "0.3.1", "url": f"{TAG_URL}/v0.3.1/tln-x64win.exe"}, build={"hashes": [], "nightly": "", "target": "x64win"})}}, separators=(",", ":")) + "\n")
    put(f"{home}/.local/share/talon/bin/tln.exe", "old tln\n")
    put(f"{d}/given/home\\.local\\bin/tln.exe", "old tln\n")
    put(f"{d}/given/home\\.local\\bin/roc.exe", "old tln\n")
    put(f"{d}/fx/commands", "tool update talon\ntool update talon\n")
    put(f"{d}/fx/env", "HOME={w}/home\nUSERPROFILE={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_GITHUB_API=https://api.github.com\n")
    put(f"{d}/fx/programs", "curl\nwget\n")
    put(f"{d}/fx/platform", "os=windows arch=x64\n")
    put(f"{d}/fx/mtimes", "talon/1.meta 1792065600\n")
    rels = [release("v0.3.4", "2026-10-01T12:00:00Z", assets=("tln-x64win.exe", "sha256sums.txt")), release("v0.3.5", "2026-10-14T12:00:00Z", assets=("tln-x64win.exe", "sha256sums.txt"))]
    put(f"{d}/fx/http/api.github.com/repos/roc-talon/talon/releases?per_page=100", json.dumps(rels, separators=(",", ":")) + "\n")
    put(f"{d}/fx/src/bin-0.3.4", binary("0.3.4"))
    put(f"{d}/fx/src/sums-0.3.4", f"{sha(binary('0.3.4'))}  tln-x64win.exe\n")
    put(
        f"{d}/fx/jobs",
        jobs_text(
            [
                ("v0.3.4/sha256sums.txt", "0", "-", "-", "copy:{out}={w}/fx/src/sums-0.3.4"),
                ("v0.3.4/tln-x64win.exe", "0", "-", "-", "copy:{out}={w}/fx/src/bin-0.3.4"),
                ("--version", "0", "tln 0.3.4", "-", "-"),
            ]
        ),
    )


windows()


# ts6-source: `--from-source` (part b), as tg1-git builds a git tool.
def source():
    name = "ts6-source"
    d = f"{ROOT}/{name}"
    shutil.rmtree(d, ignore_errors=True)
    put(f"{d}/entry", "commands\n")
    put(
        f"{d}/rules",
        """Slice 050, part b: `tln tool update talon --from-source` (R-S2). The installed Talon is the prebuilt 0.3.1. The release list has v0.3.4 (the answer) and v0.3.5 (too young). The tag v0.3.4 has the commit `d0d0d0d0...`. The source archive has `cli/main.roc`, an app with the pin of the installed compiler `nightly-2026-10-14-38a3029` (no download, no prompt). The build is one row of `fx/probes`.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool update talon --from-source` | the list, the commit of the tag (`http_get`), the entries (checked before), `programs`, the source archive of the commit (curl, tar, `cli/main.roc` read), the platform of the app, the compiler (installed), the build in the source with no `--target`, the install under the lock (the entry `talon` is a git tool: commit, ref `v0.3.4`, path `cli`, the compiler), the entry `tln`, then the entry `roc`. `updated talon 0.3.1 to git v0.3.4@d0d0d0d0 (roc-talon/talon)`. No `--version` run (Q-F2). The scratch dir is deleted | R-S2, R-T22, R-ST9, R-T4, R-T5, R-T23, R-CC1, R-CC2, R-CC6 |
| 2 | `tool update talon --from-source` | the commit of the tag is the one of the entry: `talon git v0.3.4@d0d0d0d0 is up to date`, no build | R-S2, R-T24 |
| 3 | `tool update talon` | no flag: the installed version is the version of the tag ref of the entry (0.3.4): `talon 0.3.4 is up to date` | R-S2, R-S4 |
| 4 | `tool update talon --from-source --offline` | exit 15, no request | R-DI12, R-T23 |
""",
    )
    home = f"{d}/given/home"
    put(f"{home}/.local/share/talon/tools.json", tools_json(entry_json("0.3.1"), gp=False) + "\n")
    put(f"{home}/.local/share/talon/bin/tln", "old tln\n")
    put(f"{home}/.local/bin/tln", "old tln\n")
    put(f"{home}/.local/bin/roc", "old tln\n")
    put(f"{home}/.cache/roc/toolchains/nightly-2026-10-14-38a3029/.talon.json", '{"format":1,"id":"nightly-2026-10-14-38a3029","compat":"bbbbbbb"}\n')
    put(f"{d}/fx/commands", "tool update talon --from-source\ntool update talon --from-source\ntool update talon\ntool update talon --from-source --offline\n")
    put(f"{d}/fx/env", "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_GITHUB_API=https://api.github.com\n")
    put(f"{d}/fx/programs", "curl\nwget\ntar\n")
    put(f"{d}/fx/mtimes", "talon/1.meta 1792065600\n")
    rels = [release("v0.3.4", "2026-10-01T12:00:00Z"), release("v0.3.5", "2026-10-14T12:00:00Z")]
    put(f"{d}/fx/http/api.github.com/repos/roc-talon/talon/releases?per_page=100", json.dumps(rels, separators=(",", ":")) + "\n")
    put(f"{d}/fx/http/api.github.com/repos/roc-talon/talon/commits/v0.3.4", "d0d0d0d05e8a2f4b6c0d9e1a7f3b5c8d2e4f6a1c")
    for f in ["platform-basic-cli.src", "gapp.src"]:
        shutil.copy(f"{ROOT}/tg1-git/fx/src/{f}", f"{d}/fx/src/{f}") if os.path.isdir(f"{d}/fx/src") else (os.makedirs(f"{d}/fx/src"), shutil.copy(f"{ROOT}/tg1-git/fx/src/{f}", f"{d}/fx/src/{f}"))
    put(
        f"{d}/fx/jobs",
        "# R-DA3 the download, R-FE2 `roc unbundle`, R-T23 the source archive (`source.tar.gz`, before the generic `tar -xf`). The first rule whose needle is in the arguments answers.\n"
        "unbundle CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst\t0\t-\t-\tdir:{cwd}/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA;copy:{cwd}/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA/main.roc={w}/fx/src/platform-basic-cli.src\n"
        "source.tar.gz -C\t0\t-\t-\tdir:{dir}/cli;copy:{dir}/cli/main.roc={w}/fx/src/gapp.src\n"
        "curl --fail\t0\t-\t-\tfile:{out}\n",
    )
    put(f"{d}/fx/probes", "# One row for each build, in order (the build probes of the case).\n0\t../fixtures/check/out/build-pass.stdout\t-\tfile:{out}\n")


source()
print("ok")
