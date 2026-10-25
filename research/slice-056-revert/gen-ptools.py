#!/usr/bin/env python3
"""Slice 056: makes the `given/`, `fx/`, `entry` and `rules` files of the L2 cases ptool/pt1-add, ptool/pt2-install, ptool/pt3-move, gc/gc5-project-tools and tool/tk2-takeover-project
(no `expect/`: UPDATE=1 writes it from the reference, TW21). Run from the repo root: python3 research/slice-056-revert/gen-ptools.py. It writes only under tests/commands/cases/ptool/, tests/commands/cases/gc/gc5-project-tools/ and
tests/commands/cases/tool/tk2-takeover-project/. It reads the classes of research/slice-049-revert/gen-x.py (the text before its first case: the file is read, never run as a whole, so the cases of slices 048 and 049 are not rewritten).
The hashes are the base58 of the sha256 of a label, so they are valid package hashes and stay the same on each run."""
import hashlib, json, os, shutil

src = open("research/slice-049-revert/gen-x.py").read().split("# ---------------------------------------------------------------- x/x1-run")[0]
exec(src)

NOW_S = "2026-10-15T12:00:00Z"
WASM_PF_HASH = b58("wasm-platform")
WASM_PF = f"https://github.com/acme/wasmpf/releases/download/0.1.0/{WASM_PF_HASH}.tar.zst"
ROOT = "tests/commands/cases/ptool"


def app_text(pf=PF, pin=PIN, deps=(JSON_URL,)):
    """The header of an app that has the platform `pf`."""
    lines = ["app [main!] {", f'\tpf: platform "{pf}",']
    for i, d in enumerate(deps):
        lines.append(f'\tdep{i}: "{d}",')
    if pin:
        lines.append(f'\troc: "{pin}",')
    lines += ["}", "", "main! = |_args| Ok({})"]
    return "\n".join(lines) + "\n"


def tool_url(repo, version, tag=None):
    return rel_url(repo, tag or version, f"{repo.split('/')[1]}-{version}")


def tool_entry(key, ref, url=None):
    if url is None:
        return f'{key} = {{ ref = "{ref}" }}'
    return f'{key} = {{ ref = "{ref}", url = "{url}" }}'


def tools_toml(entries, extra=""):
    return extra + "[tools]\n" + "\n".join(entries) + "\n"


class PCase(XCase):
    """A case with project dirs (`given/project/<name>/main.roc` and `talon.toml`) and tool releases."""

    def __init__(self, name, rules):
        super().__init__(name, rules)
        self.unbundle.insert(0, f"version\t0\tRoc compiler version {PIN}\t-\t-")
        self.write("fx/gitdirs", ".\n")
        self.write("fx/path-roc", "# a tln of 5000 bytes and a roc of 1000 bytes: the sizes differ, so no file is hashed.\nexe /fake/bin/tln 5000 1700000000\nfile /fake/bin/roc 1000 1700000000\n")

    def project(self, name, toml=None, header=None):
        self.write(f"given/project/{name}/main.roc", header if header is not None else app_text(deps=()))
        if toml is not None:
            self.write(f"given/project/{name}/talon.toml", toml)

    def package(self, h, text):
        """A package that is in the cache already."""
        self.write(f"given/home/.cache/roc/packages/{h}/main.roc", text)

    def platform_cached(self):
        """The platform is in the package cache (no fetch of it)."""
        text = open(f"{self.dir}/fx/src/platform-basic-cli.src").read()
        self.package(PF_HASH, text)

    def wasm_platform(self):
        text = 'platform ""\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}\n\texposes []\n\tpackages {}\n\tprovides { "roc_main": main_for_host! }\n\ttargets: {\n\t\twasm32: { inputs: ["host.wasm", app] },\n\t}\n'
        self.write("fx/src/platform-wasm.src", text)
        self.unbundle.append(f"unbundle {WASM_PF_HASH}.tar.zst\t0\t-\t-\tdir:{{cwd}}/{WASM_PF_HASH};copy:{{cwd}}/{WASM_PF_HASH}/main.roc={{w}}/fx/src/platform-wasm.src")

    def finish_p(self, commands, builds=0, **kw):
        probes = [BUILD_OK] * builds
        self.finish(commands, probes, **kw)


def releases(c, repo, versions, text=None):
    """versions: (version, published_at) newest first. Each release is an app."""
    name = repo.split("/")[1]
    c.repo(repo, [(v, f"{name}-{v}", at, text if text is not None else app_text()) for v, at in versions])


OLD = "2026-08-01T12:00:00Z"
MID = "2026-09-01T12:00:00Z"
YOUNG = "2026-10-14T12:00:00Z"


def x_manifest_entry(c, name, version, **kw):
    return c.xentry(name, version, **kw)


# ---------------------------------------------------------------- ptool/pt1-add
RULES = """Slice 056, `tln add --tool` and `tln remove --tool` (entry `commands`): R-PT1 to R-PT6, R-PT12, R-PT16, R-FL7, R-FL12, R-CC7, R-PD9, R-DT4, R-C7, R-DL7, R-LF4. One home with the compiler `nightly-2026-10-14-38a3029` installed (the pin of each app), the platform in the package cache,
`TALON_NOW=2026-10-15T12:00:00Z`, no `config.toml` (`min-release-age` is 2 days). The fake `roc build` writes the output file. No `tools.json`, no bin dir: a project tool never uses them (R-PT12).
Project `p1` has a header and no `talon.toml` (the first run makes it). Project `p2` has a `talon.toml` with comments and a `[dependencies]` table.
acme/foo has 1.1.0 and 1.0.0, acme/bar has 1.1.0 and 1.0.0, acme/snap has 1.1.0 (2026-09-01) and 1.0.0 (2026-08-01), acme/wasm has 1.0.0 (its platform has only the target wasm32), acme/bad has 1.0.0 (its build fails), acme/young has 1.0.0 (1 day old).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `add --tool acme/foo --file p1/main.roc` | `talon.toml` is made. The newest release 1.1.0 is chosen and built (the platform line and the build line on stderr, no `--target`), the binary is in `talon/x/<digest>/` (not in a bin dir), then the entry `foo = { ref = "acme/foo@^1.1.0", url = ... }` is written (the build comes first, R-PT3). The project is recorded. No `tools.json`, no lock, no probe of the header | R-PT3, R-PT4, R-PT6, R-PT12, R-PD9, R-X2 |
| 2 | `add --tool acme/bar@^1.0 --as b --file p1/main.roc` | the key is `--as`, the `ref` has the selector as typed. A second entry of the table | R-PT3, R-PT1 |
| 3 | `add --tool acme/foo --file p1/main.roc` | the key `foo` has the same app: the command acts as `update foo`: 1.1.0 is the url already, nothing is built or written | R-PT3 |
| 4 | `add --tool acme/bar --as foo --file p1/main.roc` | the key `foo` is a tool of acme/foo: exit 2, nothing is built or written | R-PT3 |
| 5 | `add --tool acme/wasm --file p1/main.roc` | the platform of the app has only wasm32: exit 2 before the build, nothing is written | R-PT16, R-T2 |
| 6 | `add --tool acme/snap --snapshot 2026-08-15T00:00:00Z --file p1/main.roc` | the release 1.1.0 is hidden by the snapshot: 1.0.0 is built and written | R-PT4, R-DT4 |
| 7 | `add --tool acme/foo --as dry --dry-run --json --file p1/main.roc` | the build of acme/foo 1.1.0 is in the `x` cache already (R-PT9): no build. `--dry-run` writes no file. The lines are on stderr, the envelope has `data.tools` | R-PT3, R-LF4, R-J3, R-PT6 |
| 8 | `remove --tool b --file p1/main.roc` | the entry `b` goes. The `x` entry of the build stays (GC decides) | R-PT3 |
| 9 | `remove --tool nope --file p1/main.roc` | exit 2: `no key 'nope' in [tools] of ...` with the keys | R-PT3 |
| 10 | `add --tool acme/bad --file p1/main.roc` | the build fails: exit 11, nothing is written (the entry comes after the build) | R-PT3, R-PT6 |
| 11 | `add --tool acme/young --file p1/main.roc` | the only release is younger than `min-release-age`: exit 2 | R-PT4, R-C7 |
| 12 | `add --tool acme/bar --file p2/main.roc` | `p2` has a `talon.toml`: the new `[tools]` table is added at its end, after a blank line. The comments and the other tables stay | R-PT3, R-CC7 |
| 13 | `add --tool acme/foo@dd03c09e --file p1/main.roc` | a git sha is no release selector: exit 2, no call after `args` | R-PT1, R-FL7 |
| 14 | `add --tool acme/foo --no-pin --file p1/main.roc` | `--no-pin` is not a flag of `--tool`: exit 2, no call after `args` | R-PT3, R-FL7 |
| 15 | `add --tool acme/foo@1.0.0 --as old --dry-run --file p1/main.roc` | the release 1.0.0 has no `x` entry: `--dry-run` builds nothing and writes nothing. It prints the lines of the plan (`added tool`, `would build tool`, the file line) and `dry run: nothing was written`. No fetch of the bundle, no compiler call (D8 of the review) | R-PT3, R-PT6, R-LF4 |
| 16 | `add --tool acme/foo --as nf` (no `--file`) | the directory of the run has no project file and no `talon.toml` above it: the command makes `talon.toml` in the current directory (Q3 of the review). The build of acme/foo 1.1.0 is in the `x` cache (run 1). The file is recorded as a project (R-PD9, NC1) | R-PT3, R-PD9 |
"""
c = PCase("pt1-add", RULES)
c.toolchain(PIN)
c.platform()
c.platform_cached()
c.wasm_platform()
releases(c, "acme/foo", [("1.1.0", MID), ("1.0.0", OLD)])
releases(c, "acme/bar", [("1.1.0", MID), ("1.0.0", OLD)])
releases(c, "acme/snap", [("1.1.0", MID), ("1.0.0", OLD)])
releases(c, "acme/young", [("1.0.0", YOUNG)])
releases(c, "acme/bad", [("1.0.0", OLD)])
c.repo("acme/wasm", [("1.0.0", "wasm-1.0.0", OLD, app_text(pf=WASM_PF))])
c.project("p1")
c.project("p2", toml="# the settings of the project\n[dependencies]\njson = \"^1\"  # the parser\n\n# end\n")
c.finish(
    [
        "add --tool acme/foo --file p1/main.roc",
        "add --tool acme/bar@^1.0 --as b --file p1/main.roc",
        "add --tool acme/foo --file p1/main.roc",
        "add --tool acme/bar --as foo --file p1/main.roc",
        "add --tool acme/wasm --file p1/main.roc",
        "add --tool acme/snap --snapshot 2026-08-15T00:00:00Z --file p1/main.roc",
        "add --tool acme/foo --as dry --dry-run --json --file p1/main.roc",
        "remove --tool b --file p1/main.roc",
        "remove --tool nope --file p1/main.roc",
        "add --tool acme/bad --file p1/main.roc",
        "add --tool acme/young --file p1/main.roc",
        "add --tool acme/bar --file p2/main.roc",
        "add --tool acme/foo@dd03c09e --file p1/main.roc",
        "add --tool acme/foo --no-pin --file p1/main.roc",
        "add --tool acme/foo@1.0.0 --as old --dry-run --file p1/main.roc",
        "add --tool acme/foo --as nf",
    ],
    [BUILD_OK, BUILD_OK, BUILD_OK, BUILD_FAIL, BUILD_OK],
)

# ---------------------------------------------------------------- ptool/pt2-install
RULES = """Slice 056, `tln install` and `tln install --frozen` with `[tools]` (entry `commands`): R-PT5 to R-PT7, R-PT9, R-PT12, R-PT15, R-PT16, R-LF1, R-SO14, R-SO22, R-DL7, R-FL13, R-I5, G1, G2, R-CC7. One home with the compiler `nightly-2026-10-14-38a3029` installed, the platform in the package cache,
`TALON_NOW=2026-10-15T12:00:00Z`. The headers of the projects have only the platform, so the header flow has nothing to change. `acme/cc` 1.0.0 has an `x` entry (a build), the other tools have none.
Projects: `p1` has `a` (a `ref`, no `url`), `b` (a `ref` and the `url` of acme/bar 1.0.0, no binary) and `c` (a `url` and its binary). `p2` has an entry with no `url`. `p3` has a `url` of 1.1.0 and the `ref` `^2`. `p4` has an entry with the `url` of another app than its `ref`.
`p5` has a `url` with no binary (acme/qq). `p6` has a `url` with its binary (acme/cc). `p7` has a `url` whose bundle is not in the cache. `p8` has 2 entries whose `x` entry has no binary (a directory with the name of the binary, and another file). `p9` has an app with a wasm platform. `p10` has a tool whose app pins a compiler that is not installed.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `install --file p1/main.roc` | the header: nothing to change. `a`: the newest release of acme/foo in `^1` (1.1.0) is chosen, built, and its `url` is written (`locked tool a`). `b`: the `url` has no binary: the bundle is fetched, the build runs (`built tool b`), no release list is read. `c`: its binary is there, nothing. One write of `talon.toml` | R-PT5, R-PT6, R-PT4, R-I5, G1, R-PT9 |
| 2 | `install --file p1/main.roc` | every tool has its `url` and its binary: no fetch, no build, no write: `nothing to change` | R-PT6, R-PT9 |
| 3 | `install --frozen --file p2/main.roc` | an entry has no `url`: exit 14, the message names the entry and the file. Nothing is fetched or built | R-PT7, R-LF1 |
| 4 | `install --frozen --file p3/main.roc` | the version of the `url` (1.1.0) is not in the range of the `ref` (`^2`): exit 14 | R-PT7 |
| 5 | `install --frozen --file p4/main.roc` | the app of the `url` is not the app of the `ref`: exit 14 | R-PT7 |
| 6 | `install --frozen --file p5/main.roc` | the `url` is locked and has no binary: the bundle is fetched, built (a compiler is needed for this build only), the `x` entry is made. No index call, no write of `talon.toml` | R-PT6, R-PT7, R-LF1, R-SO22 |
| 7 | `install --frozen --file p6/main.roc` | the binary is there: no fetch, no build, no compiler call | R-SO14, R-SO22, R-PT9 |
| 8 | `install --frozen --offline --file p7/main.roc` | the bundle is not in the cache and `--offline`: exit 15 | R-PT15, R-FL3 |
| 9 | `install --frozen --file p8/main.roc` | an `x` entry whose dir has a directory with the name of the binary, and an entry whose dir has another file: neither has the binary (follow-up of slice 049): both are built, the old dir is deleted before the new dir is made | R-PT6, R-B9, R-X2 |
| 10 | `install --frozen --file p9/main.roc` | the platform has only wasm32: exit 2 before the build | R-PT16, R-T2 |
| 11 | `install --file p1/main.roc --offline` | all tools have a binary: with `--offline` no network is needed | R-PT15, R-FL3 |
| 12 | `install --frozen --file p10/main.roc` | the build needs the compiler `nightly-2026-10-12-2664a27` (the pin of the app of the tool), which is not installed. The download is a required download (R-DL2): no person and no `TALON_AUTO_INSTALL`, so exit 13 (the text names `--allow-downloads` and `TALON_AUTO_INSTALL=yes`, the ways that the command takes, Q-A of the review) | R-DL7, R-DL2, R-SO22, R-DL4 |
| 13 | `install --dry-run --file p11/main.roc` | the entry `d` has no `url` and the exact selector 1.0.0, which has no `x` entry. `--dry-run` builds nothing and writes nothing: `locked tool d 1.0.0`, `would build tool d 1.0.0`, the file line, `dry run: nothing was written`. No `nothing to change` (the tools change, D16 of the review) | R-PT4, R-PT6, R-PT5, R-LF4 |
| 14 | `install --frozen --allow-downloads --file p10/main.roc` | the flag answers the required download of the compiler (R-DL5): no exit 13. The run goes on to the download (the fake nightly list has no such release: the failure is the last line of `stderr`) | R-DL5, R-DL7, R-SO22 |
"""
c = PCase("pt2-install", RULES)
c.toolchain(PIN)
c.platform()
c.platform_cached()
c.wasm_platform()
releases(c, "acme/foo", [("1.1.0", MID), ("1.0.0", OLD)])
for repo in ("acme/bar", "acme/qq", "acme/n1", "acme/n2", "acme/cc"):
    releases(c, repo, [("1.0.0", OLD)])
c.repo("acme/wasm", [("1.0.0", "wasm-1.0.0", OLD, app_text(pf=WASM_PF))])
# the entry of acme/cc 1.0.0: a build that is there already
c.xentry("acme/cc", "1.0.0")
# p8: an entry with a directory, an entry with another file
for repo, kind in (("acme/n1", "dir"), ("acme/n2", "file")):
    d = c.xentry(repo, "1.0.0", binary=False)
    base = f"given/home/.cache/roc/talon/x/{d}"
    if kind == "dir":
        c.write(f"{base}/{repo.split('/')[1]}/inner", "not the binary\n")
    else:
        c.write(f"{base}/other", "not the binary\n")
c.project("p1", toml=tools_toml([tool_entry("a", "acme/foo@^1"), tool_entry("b", "acme/bar@^1", tool_url("acme/bar", "1.0.0")), tool_entry("c", "acme/cc@^1", tool_url("acme/cc", "1.0.0"))]))
c.project("p2", toml=tools_toml([tool_entry("a", "acme/foo@^1")]))
c.project("p3", toml=tools_toml([tool_entry("a", "acme/foo@^2", tool_url("acme/foo", "1.1.0"))]))
c.project("p4", toml=tools_toml([tool_entry("a", "acme/bar@^1", tool_url("acme/foo", "1.1.0"))]))
c.project("p5", toml=tools_toml([tool_entry("q", "acme/qq@^1", tool_url("acme/qq", "1.0.0"))]))
c.project("p6", toml=tools_toml([tool_entry("c", "acme/cc", tool_url("acme/cc", "1.0.0"))]))
c.project("p7", toml=tools_toml([tool_entry("z", "acme/zz@^1", tool_url("acme/zz", "1.0.0"))]))
c.project("p8", toml=tools_toml([tool_entry("n1", "acme/n1@^1", tool_url("acme/n1", "1.0.0")), tool_entry("n2", "acme/n2@^1", tool_url("acme/n2", "1.0.0"))]))
c.project("p9", toml=tools_toml([tool_entry("w", "acme/wasm@^1", tool_url("acme/wasm", "1.0.0"))]))
releases(c, "acme/yy", [("1.0.0", OLD)], text=app_text(pin=PIN2))
c.project("p10", toml=tools_toml([tool_entry("y", "acme/yy@^1", tool_url("acme/yy", "1.0.0"))]))
c.project("p11", toml=tools_toml([tool_entry("d", "acme/foo@1.0.0")]))
c.finish(
    [
        "install --file p1/main.roc",
        "install --file p1/main.roc",
        "install --frozen --file p2/main.roc",
        "install --frozen --file p3/main.roc",
        "install --frozen --file p4/main.roc",
        "install --frozen --file p5/main.roc",
        "install --frozen --file p6/main.roc",
        "install --frozen --offline --file p7/main.roc",
        "install --frozen --file p8/main.roc",
        "install --frozen --file p9/main.roc",
        "install --file p1/main.roc --offline",
        "install --frozen --file p10/main.roc",
        "install --dry-run --file p11/main.roc",
        "install --frozen --allow-downloads --file p10/main.roc",
    ],
    [BUILD_OK] * 5,
)


# ---------------------------------------------------------------- ptool/pt3-move
RULES = """Slice 056, `tln update`, `tln upgrade`, `update --tool` and `upgrade --tool` with `[tools]` (entry `commands`): R-PT4, R-PT5, R-PT12, R-UP5, R-WS5, R-PT2, R-CC7, R-FL12. One home with the compiler installed, the platform in the package cache, `TALON_NOW=2026-10-15T12:00:00Z`.
The headers have only the platform (alias `pf`), so the header flow has nothing to change. acme/foo has 2.0.0, 1.1.0 and 1.0.0, acme/bar has 2.0.0 and 1.0.0, acme/baz has 2.0.0, 1.2.0 and 1.0.0, acme/fmt has 1.1.0 and 1.0.0, acme/pfx has 1.1.0 and 1.0.0.
Project `p1` has `foo` (`acme/foo@^1`, the `url` of 1.0.0), `bar` (`acme/bar@1.0.0`, the `url` of 1.0.0) and `baz` (`acme/baz@>=1.0, <1.5`, the `url` of 1.0.0). Project `p2` has `fmt` (`acme/fmt@^1`, 1.0.0). Project `p3` has `pf` (`acme/pfx@^1`): the key is also the alias of its platform entry.
Workspace `w` has `[workspace]` and `[tools]` (`foo`, 1.0.0) in its root file, and the member `w/m1`. Workspace `w2` has a `[tools]` table in the file of a member.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `update --tool --file p1/main.roc` | each tool moves inside its `ref`: `foo` to 1.1.0 (built, new `url`), `bar` has an exact version: it stays (no build), `baz` to 1.2.0. No header entry is read (the header is not resolved). One write | R-PT5, R-PT4, R-PT12 |
| 2 | `update --tool --file p1/main.roc` | nothing is newer inside the ranges: no build, no write: `nothing to change` | R-PT5 |
| 3 | `upgrade --tool foo bar --file p1/main.roc` | the newest release: `foo` to 2.0.0 with the `ref` `^2` (R-UP5), `bar` to 2.0.0 with the exact `ref` `acme/bar@2.0.0`. `baz` is not named | R-PT5, R-UP5 |
| 4 | `upgrade --tool --file p1/main.roc` | `baz` has a range with no form (`>=1.0, <1.5`): the note on stderr, it does not move. `foo` and `bar` are the newest already | R-PT5, R-UP5 |
| 5 | `update --tool zed --file p1/main.roc` | exit 2: the key is not in `[tools]`, the message lists the keys | R-PT5, R-FL12 |
| 6 | `update --tool acme/foo --file p1/main.roc` | exit 2: an operand of `--tool` is a key, not a ref | R-PT5, R-FL12 |
| 7 | `update fmt --file p2/main.roc` | the only name is a key of `[tools]` and no alias: the tool moves to 1.1.0, the header flow does not run (no pick, no closure) | R-PT5 |
| 8 | `update --file p2/main.roc` | no names: the header (nothing to change) and each tool (`fmt` is at 1.1.0 already) | R-PT5 |
| 9 | `update pf --file p3/main.roc` | `pf` is the alias of the platform and a key of `[tools]`: exit 2, the message names `--tool` | R-PT5 |
| 10 | `upgrade --tool pf --file p3/main.roc` | with `--tool` the name is a key: the tool moves to 1.1.0 (the `ref` `^1` admits it) | R-PT5 |
| 11 | `update --tool --file w/m1/main.roc` | a member of a workspace: the `[tools]` of the root file `w/talon.toml` is read and written (R-PT2). `foo` moves to 1.1.0 | R-PT2, R-WS5, R-PT5 |
| 12 | `install --file w2/m1/main.roc` | the member file has `[tools]`: exit 19, the message names the file, the line and the table | R-PT2, R-WS5 |
| 13 | `update fmt --file p2/main.roc` | the only name is a key and `fmt` is at 1.1.0 already (run 7): the header flow does not run and no tool changes. The line `nothing to change` is printed once (D16 of the review) | R-PT5 |
| 14 | `update pf --file p2/main.roc` | gap test (decision C7 of 056c): the name `pf` is a header entry (the platform alias) and no key of `[tools]`, and `p2` has `[tools]`. The header flow runs for `pf` and the tools step does not run: no read of the index of acme/fmt, no call for a tool | R-PT5 |
"""
c = PCase("pt3-move", RULES)
c.toolchain(PIN)
c.platform()
c.platform_cached()
releases(c, "acme/foo", [("2.0.0", YOUNG_OK := "2026-09-20T12:00:00Z"), ("1.1.0", MID), ("1.0.0", OLD)])
releases(c, "acme/bar", [("2.0.0", MID), ("1.0.0", OLD)])
releases(c, "acme/baz", [("2.0.0", YOUNG_OK), ("1.2.0", MID), ("1.0.0", OLD)])
releases(c, "acme/fmt", [("1.1.0", MID), ("1.0.0", OLD)])
releases(c, "acme/pfx", [("1.1.0", MID), ("1.0.0", OLD)])
# the release list of the platform: the header flow of a run with no names reads it (`update` frees the platform inside its range)
c.write(
    "fx/http/api.github.com/repos/roc-lang/basic-cli/releases?per_page=100",
    "[\n" + json.dumps({"tag_name": "0.25.0", "draft": False, "prerelease": False, "published_at": OLD, "assets": [{"name": f"{PF_HASH}.tar.zst", "size": 1048576, "browser_download_url": PF}]}, separators=(",", ":")) + "\n]\n",
)
c.project("p1", toml=tools_toml([tool_entry("foo", "acme/foo@^1", tool_url("acme/foo", "1.0.0")), tool_entry("bar", "acme/bar@1.0.0", tool_url("acme/bar", "1.0.0")), tool_entry("baz", "acme/baz@>=1.0, <1.5", tool_url("acme/baz", "1.0.0"))]))
c.project("p2", toml=tools_toml([tool_entry("fmt", "acme/fmt@^1", tool_url("acme/fmt", "1.0.0"))]))
c.project("p3", toml=tools_toml([tool_entry("pf", "acme/pfx@^1", tool_url("acme/pfx", "1.0.0"))]))
c.write("given/project/w/talon.toml", '[workspace]\nmembers = ["m1/main.roc"]\n\n' + tools_toml([tool_entry("foo", "acme/foo@^1", tool_url("acme/foo", "1.0.0"))]))
c.write("given/project/w/m1/main.roc", app_text(deps=()))
c.write("given/project/w2/talon.toml", '[workspace]\nmembers = ["m1/main.roc"]\n')
c.write("given/project/w2/m1/main.roc", app_text(deps=()))
c.write("given/project/w2/m1/talon.toml", tools_toml([tool_entry("foo", "acme/foo@^1")]))
c.finish(
    [
        "update --tool --file p1/main.roc",
        "update --tool --file p1/main.roc",
        "upgrade --tool foo bar --file p1/main.roc",
        "upgrade --tool --file p1/main.roc",
        "update --tool zed --file p1/main.roc",
        "update --tool acme/foo --file p1/main.roc",
        "update fmt --file p2/main.roc",
        "update --file p2/main.roc",
        "update pf --file p3/main.roc",
        "upgrade --tool pf --file p3/main.roc",
        "update --tool --file w/m1/main.roc",
        "install --file w2/m1/main.roc",
        "update fmt --file p2/main.roc",
        "update pf --file p2/main.roc",
    ],
    [BUILD_OK] * 8,
)


# ---------------------------------------------------------------- gc/gc5-project-tools
ROOT = "tests/commands/cases/gc"
RULES = """Slice 056, `tln cache gc` and the `[tools]` of known projects (R-PT14, R-GC4, R-GC7, R-PD9, R-PD12, R-PD13, R-GC9): entry `commands`. `TALON_NOW=2026-10-15T12:00:00Z`, `gc-age` is the default (30 days), the clock of the fake is 2026-10-15 too.
Every entry of `talon/x/` has the last run in 2020, and every package dir that is named below has its files from 2001: only the `[tools]` of a known project keeps them.
Known projects (`projects.json`): `p1/main.roc` (its `talon.toml` has `a`: the bundle of `kp1`), `w/m1/main.roc` (a member: the `talon.toml` of its directory is missing, the root file `w/talon.toml` has `[workspace]` and the tool `kws`), `t/talon.toml` (an entry of `tln run`: the file itself has the tool `ktl`),
`q/main.roc` (last used 40 days before TALON_NOW, over the GC age: its tool `kold` is not kept and the entry goes from `projects.json`), `gone/talon.toml` (the file is missing: the entry goes, its tool `kgone` is not kept).
`talon/x/` has the entries `kp1`, `kws`, `ktl`, `kold`, `kgone`, `kfree` (no project names it) and `kfresh` (a run 1 day before: it stays, the age rule). `packages/` has the bundle dirs of `kp1` and `kws` (kept) and of `kold` and `kfree` (go).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `cache gc --dry-run` | after the reads of `projects.json` and of the project files, the walk of the headers (the platform is not in the cache), and the manifests of the `x` entries: one `read_files` of the `talon.toml` files of the known projects (the `talon.toml` of each directory up to the first file with `[workspace]`, and the entry `t/talon.toml` itself). `kold`, `kgone`, `kfree` and the 2 package dirs would go, the 2 projects would go from `projects.json` | R-PT14, R-GC4, R-GC7, R-PD12, R-PD13 |
| 2 | `cache gc --json` | the real run: the same items are removed, `projects.json` has no more `q` and `gone` | R-PT14, R-GC7, R-GC4, R-J3, R-PD13 |
| 3 | `cache gc` | the second run: nothing to remove (the kept entries stay for the 3 live projects) | R-PT14 |
"""
c = XCase("gc5-project-tools", RULES)
ANCIENT = "2020-01-01T00:00:00Z"
LABELS = {"kp1": "ka", "kws": "kb", "ktl": "kc", "kold": "kd", "kgone": "ke", "kfree": "kf"}
for label, repo in LABELS.items():
    c.xentry(f"acme/{repo}", "1.0.0", label=label, last_run=ANCIENT)
c.xentry("acme/kg", "1.0.0", label="kfresh", last_run="2026-10-14T12:00:00Z")
for label in ("kp1", "kws", "kold", "kfree"):
    h = b58(label)
    c.write(f"given/home/.cache/roc/packages/{h}/main.roc", app_text(deps=()))
mt = "".join(f"packages/{b58(label)}/main.roc 1000000000\n" for label in ("kp1", "kws", "kold", "kfree"))
c.write("fx/mtimes", mt)


def tool_of(label):
    return tool_entry("t", f"acme/{LABELS[label]}@^1", rel_url(f"acme/{LABELS[label]}", "1.0.0", label))


c.write("given/project/p1/main.roc", app_text(deps=()))
c.write("given/project/p1/talon.toml", tools_toml([tool_of("kp1")]))
c.write("given/project/w/talon.toml", '[workspace]\nmembers = ["m1/main.roc"]\n\n' + tools_toml([tool_of("kws")]))
c.write("given/project/w/m1/main.roc", app_text(deps=()))
c.write("given/project/t/talon.toml", tools_toml([tool_of("ktl")]))
c.write("given/project/q/main.roc", app_text(deps=()))
c.write("given/project/q/talon.toml", tools_toml([tool_of("kold")]))
now_s = 1792065600
entries = [
    ("p1/main.roc", now_s - 3 * 86400),
    ("w/m1/main.roc", now_s - 3 * 86400),
    ("t/talon.toml", now_s - 86400),
    ("q/main.roc", now_s - 40 * 86400),
    ("gone/talon.toml", now_s - 86400),
]
c.write("given/home/.cache/roc/talon/projects.json", json.dumps({"format": 1, "projects": [{"path": "{w}/project/" + p, "last_use": t} for p, t in entries]}, separators=(",", ":")) + "\n")
c.finish(["cache gc --dry-run", "cache gc --json", "cache gc"], [])

# ---------------------------------------------------------------- gc/gc6-held-no-package
ROOT = "tests/commands/cases/gc"
RULES = """Slice 056, `tln cache gc` reads `[tools]` when only an `x` entry can go (gap test, decision D9 of 056d): R-PT14, R-GC7, R-PD13. `TALON_NOW=2026-10-15T12:00:00Z`, `gc-age` is the default (30 days).
`talon/x/` has the entries `khold` (the last run in 2020: expired, and the `talon.toml` of a live project names its bundle), `kfree` (expired, no project names it) and `kfresh` (a run 1 day before). `packages/` has no dir. The only known project is `p1/main.roc` (used 3 days before).
No package dir can go, so only the `x` entries ask for the `[tools]` of the project.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `cache gc --dry-run` | one `read_files` of the `talon.toml` files of the project, although no package dir can go. `kfree` would go, `khold` and `kfresh` stay | R-PT14, R-GC7 |
| 2 | `cache gc` | the real run: `kfree` is deleted, `khold` and `kfresh` stay | R-PT14, R-GC7 |
| 3 | `cache gc` | nothing to remove. `khold` is still expired by its age, so the `[tools]` read is made again and keeps it | R-PT14, R-GC7 |
"""
c = XCase("gc6-held-no-package", RULES)
c.xentry("acme/ka", "1.0.0", label="khold", last_run=ANCIENT)
c.xentry("acme/kb", "1.0.0", label="kfree", last_run=ANCIENT)
c.xentry("acme/kg", "1.0.0", label="kfresh", last_run="2026-10-14T12:00:00Z")
c.write("given/project/p1/main.roc", app_text(deps=()))
c.write("given/project/p1/talon.toml", tools_toml([tool_entry("t", "acme/ka@^1", rel_url("acme/ka", "1.0.0", "khold"))]))
now_s = 1792065600
c.write("given/home/.cache/roc/talon/projects.json", json.dumps({"format": 1, "projects": [{"path": "{w}/project/p1/main.roc", "last_use": now_s - 3 * 86400}]}, separators=(",", ":")) + "\n")
c.finish(["cache gc --dry-run", "cache gc", "cache gc"], [])

# ---------------------------------------------------------------- tool/tk2-takeover-project
ROOT = "tests/commands/cases/tool"
RULES = """Slice 056, the take-over of an `x` cache entry that a known project uses (entry `commands`): R-B4, R-PT13, R-PT14, R-PD9, R-PD12, NC3. One home with the compiler installed, `TALON_NOW=2026-10-15T12:00:00Z`, `CI=true` (no person), no tty, no `tools.json`.
`talon/x/` has an entry of each of acme/foo, acme/ws, acme/tl, acme/oth and acme/bar (the newest release of each: acme/oth has 1.1.0 and the entries are of 1.1.0, the others 1.0.0 or 1.1.0). `projects.json` has `p1/main.roc` (its `talon.toml` has the `url` of the acme/foo build), `w/m1/main.roc` (a member of a workspace: the root file `w/talon.toml` has the `url` of the acme/ws build),
`t/talon.toml` (an entry that `tln run` made: the file has the `url` of the acme/tl build) and `p2/main.roc` (its `talon.toml` has the `url` of acme/oth 1.0.0, not the build of 1.1.0).
The fake `rename` is not used: a take-over with a project that uses the entry is a copy.

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `tool install acme/foo` | the entry matches the newest release. A known project uses its bundle (the `url` of `p1/talon.toml`): the binary is copied (no `rename` of it), the entry dir stays. The calls before the sha256 check: `read_files` of `projects.json` and of the `talon.toml` files of the known projects | R-B4, R-PT13, R-PT14, NC3 |
| 2 | `tool install acme/ws` | the member `w/m1/main.roc` has no `talon.toml` of its own: the walk goes up to `w/talon.toml`, which has `[workspace]` and the tool. Copy, the entry stays | R-PT14, NC3, R-PD9 |
| 3 | `tool install acme/tl` | an entry of `projects.json` that is a `talon.toml` (R-PD9: `tln run` made it): the file itself is read. Copy, the entry stays | R-PT14, R-PD9, R-PD12 |
| 4 | `tool install acme/oth` | the project `p2` names the bundle of 1.0.0, the entry is the build of 1.1.0: no project uses it, the binary is moved and the entry dir is deleted | R-B4, R-PT13 |
| 5 | `tool install acme/bar` | no project names the bundle: move, the entry dir is deleted (as before this slice) | R-B4 |
"""
c = XCase("tk2-takeover-project", RULES)
c.toolchain(PIN)
simple_repo(c, "acme/foo", [("1.1.0", MID), ("1.0.0", OLD)])
simple_repo(c, "acme/ws", [("1.0.0", OLD)])
simple_repo(c, "acme/tl", [("1.0.0", OLD)])
simple_repo(c, "acme/oth", [("1.1.0", MID), ("1.0.0", OLD)])
simple_repo(c, "acme/bar", [("1.0.0", OLD)])
c.platform()
for name, version in (("acme/foo", "1.1.0"), ("acme/ws", "1.0.0"), ("acme/tl", "1.0.0"), ("acme/oth", "1.1.0"), ("acme/bar", "1.0.0")):
    c.xentry(name, version)


def tool_for(key, repo, version):
    return tool_entry(key, f"{repo}@^1", tool_url(repo, version))


c.write("given/project/p1/main.roc", app_text(deps=()))
c.write("given/project/p1/talon.toml", tools_toml([tool_for("foo", "acme/foo", "1.1.0")]))
c.write("given/project/w/talon.toml", '[workspace]\nmembers = ["m1/main.roc"]\n\n' + tools_toml([tool_for("ws", "acme/ws", "1.0.0")]))
c.write("given/project/w/m1/main.roc", app_text(deps=()))
c.write("given/project/t/talon.toml", tools_toml([tool_for("tl", "acme/tl", "1.0.0")]))
c.write("given/project/p2/main.roc", app_text(deps=()))
c.write("given/project/p2/talon.toml", tools_toml([tool_for("oth", "acme/oth", "1.0.0")]))
now_s = 1792065600
c.write("given/home/.cache/roc/talon/projects.json", json.dumps({"format": 1, "projects": [{"path": "{w}/project/" + p, "last_use": now_s - 86400} for p in ("p1/main.roc", "w/m1/main.roc", "t/talon.toml", "p2/main.roc")]}, separators=(",", ":")) + "\n")
c.finish(["tool install acme/foo", "tool install acme/ws", "tool install acme/tl", "tool install acme/oth", "tool install acme/bar"], [], env_extra=["CI=true"])

print("ok")
