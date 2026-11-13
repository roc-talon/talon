#!/usr/bin/env python3
# Slice 244 (docs/slices/244-audit.md): makes the L2 cases of `tln audit` with a registry in tests/commands/cases/audit/.
# It writes given/ (the projects, the package headers in the cache, the kept privacy answers, config.toml), fx/ (env, commands, the closure answer, programs), rules and entry.
# The expected files (stdout, stderr, exit, calls.log) are literal texts in this file (the TW24 proposal of the slice file and the guessed Fx calls). tree.diff is made with tree_diff of tests/lib.sh, never by hand.
# Run from the repo root: python3 -I tests/tools/mk-audit.py. It replaces the case dirs that it makes.
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/audit")
A = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
PIN = "nightly-2026-10-13-5e6f7a8"
NOW = 1792065600  # TALON_NOW 2026-10-15T12:00:00Z


def b58(data):
    n = int.from_bytes(data, "big")
    s = ""
    while n:
        n, r = divmod(n, 58)
        s = A[r] + s
    return s


def h(name):
    return b58(hashlib.sha256(("audit244-" + name).encode()).digest())


def url(repo, version, hash_):
    return f"https://github.com/{repo}/releases/download/{version}/{hash_}.tar.zst"


def form(repo):
    return f"github.com/{repo}/releases/download/{{v}}/"


def series(version):
    major, minor, _ = version.split(".")
    return major if major != "0" else f"0.{minor}"


# The packages: key -> (repo, version, kind).
PKG = {
    "pf": ("acme/pfx", "0.1.0", "platform"),
    "json": ("acme/json", "2.1.0", "package"),
    "json200": ("acme/json", "2.0.0", "package"),
    "parser": ("acme/parser", "1.0.2", "package"),
    "util": ("someone/roc-util", "0.3.0", "package"),
    "csv": ("someone/roc-csv", "1.1.0", "package"),
    "xml": ("someone/roc-xml", "0.4.0", "package"),
    "old": ("someone/roc-old", "1.0.0", "package"),
    "pre": ("acme/pre", "1.0.0", "package"),
    "fmt": ("acme/fmt", "1.0.0", "app"),
    "web": ("acme/web", "1.0.0", "package"),
    "gone": ("someone/roc-gone", "1.0.0", "package"),
    "loop": ("127.0.0.1:9/x", "1.0.0", "package"),
}
# The deps of a package header (alias -> key), sorted by alias (R-AP49).
DEPS = {"json": [("parser", "parser"), ("util", "util")]}


def u(key):
    repo, version, _ = PKG[key]
    if key == "loop":
        return f"http://127.0.0.1:9/x/{version}/{h(key)}.tar.zst"
    return url(repo, version, h(key))


def dep_item(alias, key):
    repo, version, _ = PKG[key]
    return {"alias": alias, "hash": h(key), "is_platform": False, "group": form(repo), "series": series(version), "version": version, "url": u(key)}


def artifact(key):
    _, _, kind = PKG[key]
    deps = [dep_item(a, k) for a, k in DEPS.get(key, [])]
    return {"hash": h(key), "kind": kind, "exposed": [], "platform_hash": None, "roc_pin": None, "size": 1000, "deps": deps, "target_names": ["x64musl"] if kind == "platform" else []}


def release(key, log_index, yanked=False, yank_reason=None, withdrawn=None):
    repo, version, _ = PKG[key]
    return {
        "log_index": log_index,
        "hash": h(key),
        "group": form(repo),
        "series": series(version),
        "version": version,
        "url": u(key),
        "tag": version,
        "roc_version": None,
        "repo": repo,
        "published_at": 1782907200000 + log_index * 86400000,
        "yanked": yanked,
        "yank_reason": yank_reason,
        "withdrawn": withdrawn,
        "provenance": ["webhook"],
    }


def repo_item(name, state="active", successor=None):
    return {"name": name, "state": state, "successor": successor, "state_at": 1790000000000}


def answer(keys, states, repos, unknown=()):
    rels = []
    for i, k in enumerate(keys):
        rels.append(release(k, i + 2, **states.get(k, {})))
    return {
        "artifacts": sorted([artifact(k) for k in keys], key=lambda a: a["hash"]),
        "releases": rels,
        "epochs": [],
        "runs": [],
        "nearest": [],
        "hints": [],
        "log_size": 50,
        "unknown": list(unknown),
        "checked": [],
        "repos": sorted(repos, key=lambda r: r["name"]),
    }


def header(entries):
    lines = ["app [main!] {"]
    for alias, key, platform in entries:
        lines.append(f'\t{alias}: {"platform " if platform else ""}"{u(key)}",')
    lines.append(f'\troc: "{PIN}",')
    lines.append("}")
    lines.append("")
    lines.append("main! = |_args| Ok({})")
    return "\n".join(lines) + "\n"


def package_header(key):
    _, _, kind = PKG[key]
    if kind == "platform":
        return 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
    deps = DEPS.get(key, [])
    if not deps:
        return "package [Lib] {}\n"
    inner = ", ".join(f'{a}: "{u(k)}"' for a, k in deps)
    return f"package [Lib] {{ {inner} }}\n"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def body(hashes):
    return json.dumps({"compilers": {"from": PIN, "to": PIN}, "groups": [], "hashes": hashes}, separators=(",", ":"))


START = """args
env_all
{tty}env_all
clock
cwd
canonical $PROJECT/{p}/main.roc
list_dirs $PROJECT/{p}
list_dirs $PROJECT
read_files $PROJECT/{p}/main.roc
canonical $PROJECT/{p}/main.roc
lock $HOME/.cache/roc/talon/projects.json nowait: held
list_dirs $HOME/.cache/roc/talon
read_files $HOME/.cache/roc/talon/projects.json
{write}unlock $HOME/.cache/roc/talon/projects.json
read_files $PROJECT/{p}/main.roc $PROJECT/{p}/talon.toml $HOME/.config/talon/config.toml
"""


def calls_run(p, repos, hashes, first, tty, query=True):
    text = START.format(p=p, tty="tty\n" if tty else "", write="write_atomic $HOME/.cache/roc/talon/projects.json\n" if first else "")
    if query:
        text += "read_files " + " ".join(f"$HOME/.cache/roc/talon/index/github/{r}/repo.json" for r in repos) + "\n"
        text += "http_send POST http://127.0.0.1:9/v1/closure timeout=20\n  User-Agent: tln/0.0.1\n  Content-Type: application/json\n"
        text += f"  <body> {body(hashes)}\n"
    return text


def make(name, rules, project, files, keys, states, repos, guard, commands, stdout, stderr, exits, calls, unknown=(), direct=False, routes=None, kept=None, cache=()):
    d = os.path.join(CASES, name)
    # The calls.log of a case is baked from the real run after the review (slice 244 review). A baked file is kept; the literal guess is written only when the case has none.
    baked = None
    if os.path.isfile(os.path.join(d, "expect/calls.log")):
        with open(os.path.join(d, "expect/calls.log")) as f:
            baked = f.read()
    shutil.rmtree(d, ignore_errors=True)
    write(os.path.join(d, "entry"), "commands\n")
    write(os.path.join(d, "rules"), rules + "\n")
    write(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n" + ("TALON_REGISTRY=direct\n" if direct else ""))
    write(os.path.join(d, "fx/programs"), "curl\n")
    write(os.path.join(d, "fx/gitdirs"), ".\n")
    write(os.path.join(d, "fx/commands"), commands)
    if not direct:
        ans = json.dumps(answer(keys, states, repos, unknown), separators=(",", ":"))
        write(os.path.join(d, "fx/http/127.0.0.1%3A9/v1/closure.POST"), ans)
        write(os.path.join(d, "fx/http/127.0.0.1%3A9/v1/closure.POST.meta"), "status 200\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire-none authorization\n")
        write(os.path.join(d, "given/home/.config/talon/config.toml"), 'registry = "http://127.0.0.1:9"\n')
    for path, text in (routes or {}).items():
        write(os.path.join(d, "fx/http", path), text)
    for r in guard:
        write(os.path.join(d, f"given/home/.cache/roc/talon/index/github/{r}/repo.json"), json.dumps({"id": 1, "full_name": r, "private": False}, separators=(",", ":")))
    for k in list(keys) + list(cache) + [h_key for h_key in PKG if h(h_key) in unknown]:
        write(os.path.join(d, f"given/home/.cache/roc/packages/{h(k)}/main.roc"), package_header(k))
    for rel, text in files.items():
        write(os.path.join(d, "given/project", rel), text)
    write(os.path.join(d, "expect/stdout"), stdout)
    if stderr:
        write(os.path.join(d, "expect/stderr"), stderr)
    write(os.path.join(d, "expect/exit"), "0\n")
    write(os.path.join(d, "expect/calls.log"), baked if baked is not None else calls)
    tree(d, project, kept or {})


# tree.diff: tree_diff (tests/lib.sh) over a copy of given/ and the same copy with the one change of the runs: projects.json gets the project file (Known.record!, R-PD9).
def tree(d, project, kept=None):
    w = os.path.join(ROOT, ".tmp/mk-audit", os.path.basename(d))
    shutil.rmtree(w, ignore_errors=True)
    os.makedirs(os.path.join(w, "orig"))
    for part in ["home", "project"]:
        shutil.copytree(os.path.join(d, "given", part), os.path.join(w, "orig", part))
        shutil.copytree(os.path.join(d, "given", part), os.path.join(w, part))
    if project:
        write(os.path.join(w, "home/.cache/roc/talon/projects.json"), json.dumps({"format": 1, "projects": [{"path": f"{w}/project/{project}/main.roc", "last_use": NOW}]}, separators=(",", ":")) + "\n")
    for path, text in (kept or {}).items():
        write(os.path.join(w, "home/.cache/roc/talon/index/github", path), text)
    out = subprocess.run(["bash", "-c", f'. tests/lib.sh && tree_diff "{w}"'], capture_output=True, text=True, check=True).stdout
    write(os.path.join(d, "expect/tree.diff"), out)


def env_line(cmd, code):
    return f"== {cmd}\n", f"exit {code}\n"


P1 = [("pf", "pf", True), ("json", "json", False), ("csv", "csv", False), ("xml", "xml", False), ("old", "old", False)]
P1_KEYS = ["pf", "json", "csv", "xml", "old", "parser", "util"]
P1_STATES = {
    "json": {"yanked": True, "yank_reason": "parse bug, use 2.1.1"},
    "csv": {"withdrawn": "repo-missing"},
    "old": {"yanked": True},
    "parser": {"withdrawn": "asset-replaced"},
    "util": {"withdrawn": "deleted"},
}
P1_REPOS = [repo_item("acme/pfx"), repo_item("acme/json"), repo_item("someone/roc-csv", "missing"), repo_item("someone/roc-xml", "moved", "acme/roc-xml"), repo_item("someone/roc-old"), repo_item("acme/parser"), repo_item("someone/roc-util")]
P1_GUARD = ["acme/pfx", "acme/json", "someone/roc-csv", "someone/roc-xml", "someone/roc-old"]
P1_HASHES = [h("pf"), h("json"), h("csv"), h("xml"), h("old")]

FAIL_MSG = "findings that fail: {items}. To accept one, add it to [audit] ignore in talon.toml"


def finding(key, alias, via, reason, fails, ignored, since, yank, successor, fix, tool=None, members=None, new_hash=None):
    repo, version, _ = PKG[key]
    return {
        "name": repo,
        "group": form(repo),
        "version": version,
        "hash": h(key),
        "alias": alias,
        "via": via,
        "tool": tool,
        "members": members if members is not None else [],
        "reason": reason,
        "fails": fails,
        "ignored": ignored,
        "since": since,
        "yank": yank,
        "new_hash": new_hash,
        "successor": successor,
        "fix": fix,
    }


def env_ok(data):
    return json.dumps({"schema": 1, "command": "audit", "ok": True, "data": data, "error": None}, separators=(",", ":")) + "\n"


def env_fail(message, data):
    return json.dumps({"schema": 1, "command": "audit", "ok": False, "data": None, "error": {"kind": "findings", "code": 21, "message": message, "details": data}}, separators=(",", ":")) + "\n"


SINCE = "2026-09-21T14:13:20Z"  # state_at 1790000000000
FIX_CSV = "tln remove csv, then tln add another package, or add the item to [audit] ignore"
FIX_PARSER = "tln update json (tln why acme/parser), or use [overrides]; ask the author to release a new version"


def p1_findings(member, ignored=()):
    m = [member]
    return [
        finding("json", "json", [], "yanked", True, "acme/json@2.1.0:yanked" in ignored, None, {"reason": "parse bug, use 2.1.1"}, None, "tln update json", members=m),
        finding("csv", "csv", [], "repo-missing", True, "someone/roc-csv@1.1.0:repo-missing" in ignored, SINCE, None, None, FIX_CSV, members=m),
        finding("xml", "xml", [], "moved", False, False, SINCE, None, "acme/roc-xml", "tln update xml", members=m),
        finding("old", "old", [], "yanked", True, "someone/roc-old@1.0.0:yanked" in ignored, None, {"reason": None}, None, "tln update old", members=m),
        finding("parser", None, ["json"], "asset-replaced", True, "acme/parser@1.0.2:asset-replaced" in ignored, None, None, None, FIX_PARSER, members=m),
        finding("util", None, ["json"], "release-missing", False, False, None, None, None, "tln update json (tln why someone/roc-util), or use [overrides]", members=m),
    ]


NOTE_REG = "note: the registry has no yank and advisory data yet\n"


def au1():
    cmds = "# R-AU1 R-AU2 R-AU3 R-AU8 R-AU13 R-OUT2 (slice 244): the project p1 with a registry. Header: pf, json (yanked), csv (repo-missing: withdrawn and the repos state missing), xml (moved), old (yanked, no reason). json needs parser (asset-replaced) and util (deleted: release-missing).\n"
    cmds += "# Run 1: the report on stdout (4 that fail, 2 warnings, the fix line, the R-AU4 note), the failure line on stderr, exit 21.\n"
    cmds += "audit --file p1/main.roc\n"
    cmds += "# Run 2 (R-AU5 R-J4 R-J5): --json: ok false, error.kind findings, the report in error.details. stdout is only the envelope; stderr has the failure line.\n"
    cmds += "audit --json --file p1/main.roc\n"
    items = "acme/json@2.1.0:yanked, someone/roc-csv@1.1.0:repo-missing, someone/roc-old@1.0.0:yanked, acme/parser@1.0.2:asset-replaced"
    msg = FAIL_MSG.format(items=items)
    text = (
        "audit: 7 packages checked (registry)\n"
        'yanked          json 2.1.0    acme/json        "parse bug, use 2.1.1"                header: json\n'
        "repo missing    csv 1.1.0     someone/roc-csv  the repository is deleted or private  header: csv\n"
        "yanked          old 1.0.0     someone/roc-old  no reason given                       header: old\n"
        "asset replaced  parser 1.0.2  acme/parser      the asset of the header is gone       via json\n"
        "warning: moved  xml 0.4.0  someone/roc-xml  successor: acme/roc-xml  header: xml\n"
        "warning: release missing  util 0.3.0  someone/roc-util  via json\n"
        "4 findings, 2 warnings, 0 ignored.\n"
        f"fix: json: tln update json. csv: {FIX_CSV}. xml: tln update xml. old: tln update old. parser: {FIX_PARSER}.\n" + NOTE_REG
    )
    data = {"index": "registry", "checked": 7, "notes": [{"kind": "no-yank-data"}], "findings": p1_findings("$PROJECT/p1/main.roc")}
    stdout = "== audit --file p1/main.roc\n" + text + "exit 21\n" + "== audit --json --file p1/main.roc\n" + env_fail(msg, data) + "exit 21\n"
    stderr = f"tln: error[findings]: {msg}\n" * 2
    calls = calls_run("p1", P1_GUARD, P1_HASHES, True, True) + calls_run("p1", P1_GUARD, P1_HASHES, False, False)
    make("au1-findings", "R-CM14 R-AU1 R-AU2 R-AU3 R-AU4 R-AU5 R-AU8 R-AU13 R-AP17 R-AP32 R-AP49 R-EC21 R-J4 R-J5 R-OUT2 (slice 244): tln audit with a registry, findings that fail. See fx/commands.", "p1",
         {"p1/main.roc": header(P1)}, P1_KEYS, P1_STATES, P1_REPOS, P1_GUARD, cmds, stdout, stderr, None, calls)


def au3_clean():
    entries = [("pf", "pf", True), ("json", "json200", False)]
    keys = ["pf", "json200"]
    repos = [repo_item("acme/pfx"), repo_item("acme/json")]
    guard = ["acme/pfx", "acme/json"]
    hashes = [h("pf"), h("json200")]
    cmds = "# R-AU3 R-AU4 R-C6 (slice 244, Q-244-1, Q-244-2): no finding: exit 0. With a registry before P3 the last line is the note of no yank data (its own text, not the text of direct).\n"
    cmds += "audit --file p2/main.roc\n"
    cmds += "# R-OUT2 R-J4: --json: data with checked 2, the note no-yank-data, no finding. Nothing on stderr.\n"
    cmds += "audit --json --file p2/main.roc\n"
    text = "audit: 2 packages checked (registry)\n0 findings, 0 warnings, 0 ignored.\n" + NOTE_REG
    data = {"index": "registry", "checked": 2, "notes": [{"kind": "no-yank-data"}], "findings": []}
    stdout = "== audit --file p2/main.roc\n" + text + "exit 0\n== audit --json --file p2/main.roc\n" + env_ok(data) + "exit 0\n"
    calls = calls_run("p2", guard, hashes, True, True) + calls_run("p2", guard, hashes, False, False)
    make("au3-clean", "R-CM14 R-AU3 R-AU4 R-C6 R-OUT2 (slice 244): no finding, exit 0, the note of no yank data. See fx/commands.", "p2",
         {"p2/main.roc": header(entries)}, keys, {}, repos, guard, cmds, stdout, "", None, calls)


def au3_warnings():
    entries = [("pf", "pf", True), ("xml", "xml", False), ("util", "util", False), ("pre", "pre", False)]
    keys = ["pf", "xml", "util", "pre"]
    states = {"util": {"withdrawn": "unpublished"}, "pre": {"withdrawn": "edited"}}
    repos = [repo_item("acme/pfx"), repo_item("someone/roc-xml", "moved", "acme/roc-xml"), repo_item("someone/roc-util"), repo_item("acme/pre")]
    guard = ["acme/pfx", "someone/roc-xml", "someone/roc-util", "acme/pre"]
    hashes = [h("pf"), h("xml"), h("util"), h("pre")]
    cmds = "# R-AU2 R-AU3 R-AU8 R-OUT2 (slice 244): only findings that do not fail: xml moved (successor acme/roc-xml), util unpublished (release-missing), pre edited (prerelease). Exit 0, 3 warning lines, the fix line names xml only (no successor for the other two).\n"
    cmds += "audit --file p3/main.roc\n"
    cmds += "# R-OUT2: --json: each finding has fails false; exit 0.\n"
    cmds += "audit --json --file p3/main.roc\n"
    text = (
        "audit: 4 packages checked (registry)\n"
        "warning: moved  xml 0.4.0  someone/roc-xml  successor: acme/roc-xml  header: xml\n"
        "warning: release missing  util 0.3.0  someone/roc-util  header: util\n"
        "warning: prerelease  pre 1.0.0  acme/pre  header: pre\n"
        "0 findings, 3 warnings, 0 ignored.\n"
        "fix: xml: tln update xml.\n" + NOTE_REG
    )
    m = ["$PROJECT/p3/main.roc"]
    data = {
        "index": "registry",
        "checked": 4,
        "notes": [{"kind": "no-yank-data"}],
        "findings": [
            finding("xml", "xml", [], "moved", False, False, SINCE, None, "acme/roc-xml", "tln update xml", members=m),
            finding("util", "util", [], "release-missing", False, False, None, None, None, "tln update util", members=m),
            finding("pre", "pre", [], "prerelease", False, False, None, None, None, "tln update pre", members=m),
        ],
    }
    stdout = "== audit --file p3/main.roc\n" + text + "exit 0\n== audit --json --file p3/main.roc\n" + env_ok(data) + "exit 0\n"
    calls = calls_run("p3", guard, hashes, True, True) + calls_run("p3", guard, hashes, False, False)
    make("au3-warnings", "R-CM14 R-AU2 R-AU3 R-AU8 R-OUT2 (slice 244): only warnings, exit 0. See fx/commands.", "p3",
         {"p3/main.roc": header(entries)}, keys, states, repos, guard, cmds, stdout, "", None, calls)


def au9_ignore():
    toml = '[resolution]\nsnapshot = "log:1"\n\n[audit]\nignore = [\n\t"acme/json@2.1.0:yanked",\n\t"someone/roc-csv@1.1.0:repo-missing",\n\t"someone/roc-old@1.0.0:yanked",\n\t"someone/roc-gone@1.0.0:yanked",\n]\n'
    cmds = "# R-AU9 R-AU10 R-AU11 R-AU3 (slice 244): p4 is p1 with [audit] ignore in its talon.toml: json (yanked), csv (repo-missing), old (yanked), and roc-gone (no finding: unused).\n"
    cmds += "# R-AU1 R-YK5: talon.toml also has [resolution] snapshot = \"log:1\". tln audit uses the state of now: the snapshot hides no release (parser and util have log index 7 and 8, and are still findings in each run).\n"
    cmds += "# Run 1: the flag ignores parser too. The two sources are joined: no finding that fails is left, exit 0. Each ignored finding is a line `ignored: <item>`; the unused item is a line `unused ignore: <item>`.\n"
    cmds += "audit --file p4/main.roc --ignore acme/parser@1.0.2:asset-replaced\n"
    cmds += "# Run 2: the same with --json: ignored true on 4 findings, the note unused-ignore. Exit 0.\n"
    cmds += "audit --json --file p4/main.roc --ignore acme/parser@1.0.2:asset-replaced\n"
    cmds += "# Run 3: the items of talon.toml only: parser still fails, exit 21.\n"
    cmds += "audit --file p4/main.roc\n"
    cmds += "# Run 4: an item of parser with another reason ignores nothing (R-AU9: the reason is required): exit 21, and the item is unused (R-AU11). The name matches with any case.\n"
    cmds += "audit --file p4/main.roc --ignore ACME/Parser@1.0.2:yanked\n"
    head = "audit: 7 packages checked (registry)\n"
    ign = "ignored: acme/json@2.1.0:yanked\nignored: someone/roc-csv@1.1.0:repo-missing\nignored: someone/roc-old@1.0.0:yanked\n"
    warn = "warning: moved  xml 0.4.0  someone/roc-xml  successor: acme/roc-xml  header: xml\nwarning: release missing  util 0.3.0  someone/roc-util  via json\n"
    parser_row = "asset replaced  parser 1.0.2  acme/parser  the asset of the header is gone  via json\n"
    run1 = head + warn + ign + "ignored: acme/parser@1.0.2:asset-replaced\nunused ignore: someone/roc-gone@1.0.0:yanked\n0 findings, 2 warnings, 4 ignored.\nfix: xml: tln update xml.\n" + NOTE_REG
    run3 = head + parser_row + warn + ign + "unused ignore: someone/roc-gone@1.0.0:yanked\n1 finding, 2 warnings, 3 ignored.\n" + f"fix: xml: tln update xml. parser: {FIX_PARSER}.\n" + NOTE_REG
    run4 = head + parser_row + warn + ign + "unused ignore: someone/roc-gone@1.0.0:yanked\nunused ignore: ACME/Parser@1.0.2:yanked\n1 finding, 2 warnings, 3 ignored.\n" + f"fix: xml: tln update xml. parser: {FIX_PARSER}.\n" + NOTE_REG
    all4 = ("acme/json@2.1.0:yanked", "someone/roc-csv@1.1.0:repo-missing", "someone/roc-old@1.0.0:yanked", "acme/parser@1.0.2:asset-replaced")
    data = {"index": "registry", "checked": 7, "notes": [{"kind": "no-yank-data"}, {"kind": "unused-ignore", "item": "someone/roc-gone@1.0.0:yanked"}], "findings": p1_findings("$PROJECT/p4/main.roc", all4)}
    msg = FAIL_MSG.format(items="acme/parser@1.0.2:asset-replaced")
    stdout = (
        "== audit --file p4/main.roc --ignore acme/parser@1.0.2:asset-replaced\n" + run1 + "exit 0\n"
        "== audit --json --file p4/main.roc --ignore acme/parser@1.0.2:asset-replaced\n" + env_ok(data) + "exit 0\n"
        "== audit --file p4/main.roc\n" + run3 + "exit 21\n"
        "== audit --file p4/main.roc --ignore ACME/Parser@1.0.2:yanked\n" + run4 + "exit 21\n"
    )
    stderr = f"tln: error[findings]: {msg}\n" * 2
    calls = calls_run("p4", P1_GUARD, P1_HASHES, True, True) + calls_run("p4", P1_GUARD, P1_HASHES, False, False) + calls_run("p4", P1_GUARD, P1_HASHES, False, True) + calls_run("p4", P1_GUARD, P1_HASHES, False, True)
    make("au9-ignore", "R-AU9 R-AU10 R-AU11 R-AU12 R-AU3 R-AU1 R-YK5 R-OUT2 (slice 244): [audit] ignore and --ignore. See fx/commands.", "p4",
         {"p4/main.roc": header(P1), "p4/talon.toml": toml}, P1_KEYS, P1_STATES, P1_REPOS, P1_GUARD, cmds, stdout, stderr, None, calls)


def au12_bad_items():
    toml = '[audit]\nignore = ["acme/json@2.1.0:yanked", "acme/json@2.1.0"]\n'
    cmds = "# R-AU12 R-EC19 R-EC2 R-CM14 (slice 244): items that do not parse.\n"
    cmds += "# Run 1: an item of [audit] ignore in talon.toml with no reason: exit 19 (input), the path and the line of the key. The run stops after the load: no closure query.\n"
    cmds += "audit --file p5/main.roc\n"
    cmds += "# Run 2: a --ignore item with no reason: exit 2 (usage), before the environment, the project and talon.toml are read.\n"
    cmds += "audit --ignore acme/json@2.1.0 --file p5/main.roc\n"
    cmds += "# Run 3: tln audit takes no operand: exit 2.\n"
    cmds += "audit json\n"
    stdout = "== audit --file p5/main.roc\nexit 19\n== audit --ignore acme/json@2.1.0 --file p5/main.roc\nexit 2\n== audit json\nexit 2\n"
    stderr = (
        "tln: error[input]: $PROJECT/p5/talon.toml:2: audit.ignore: 'acme/json@2.1.0' is not <full name>@<version>:<reason>, for example roc-lang/json@2.1.0:yanked\n"
        "tln: error[usage]: --ignore: 'acme/json@2.1.0' is not <full name>@<version>:<reason>, for example roc-lang/json@2.1.0:yanked\n"
        "tln: error[usage]: tln audit takes no operand\n"
    )
    calls = calls_run("p5", [], [], True, True, query=False) + "args\nenv_all\ntty\n" + "args\nenv_all\ntty\n"
    make("au12-bad-items", "R-AU12 R-AU9 R-EC2 R-EC19 R-CM14 (slice 244): ignore items that do not parse. See fx/commands.", "p5",
         {"p5/main.roc": header([("pf", "pf", True), ("json", "json", False)]), "p5/talon.toml": toml}, ["pf", "json"], {}, [repo_item("acme/pfx"), repo_item("acme/json")], ["acme/pfx", "acme/json"], cmds, stdout, stderr, None, calls)


def au1_tool():
    entries = [("pf", "pf", True), ("json", "json200", False)]
    toml = f'[tools]\nfmt = {{ ref = "acme/fmt@^1", url = "{u("fmt")}" }}\n'
    keys = ["pf", "json200", "fmt"]
    states = {"fmt": {"yanked": True, "yank_reason": "bad build"}}
    repos = [repo_item("acme/pfx"), repo_item("acme/json"), repo_item("acme/fmt")]
    guard = ["acme/pfx", "acme/json", "acme/fmt"]
    hashes = [h("pf"), h("json200"), h("fmt")]
    cmds = "# R-AU1 R-PT8 R-AU3 (slice 244, Q-244-7): the hash of the url of a project tool is checked (only that hash). Its hash is in the hashes of the closure query, after the header hashes. fmt 1.0.0 is yanked: exit 21. The last column is `tool: <key>`, the fix is `tln update --tool fmt`.\n"
    cmds += "audit --file p6/main.roc\n"
    msg = FAIL_MSG.format(items="acme/fmt@1.0.0:yanked")
    text = (
        "audit: 3 packages checked (registry)\n"
        'yanked  fmt 1.0.0  acme/fmt  "bad build"  tool: fmt\n'
        "1 finding, 0 warnings, 0 ignored.\n"
        "fix: fmt: tln update --tool fmt.\n" + NOTE_REG
    )
    stdout = "== audit --file p6/main.roc\n" + text + "exit 21\n"
    stderr = f"tln: error[findings]: {msg}\n"
    calls = calls_run("p6", guard, hashes, True, True)
    make("au1-tool", "R-AU1 R-PT8 R-AU3 R-AU8 R-OUT2 (slice 244): a project tool URL is checked. See fx/commands.", "p6",
         {"p6/main.roc": header(entries), "p6/talon.toml": toml}, keys, states, repos, guard, cmds, stdout, stderr, None, calls)


def gh_release(repo, tag, assets, prerelease=False, draft=False):
    return {
        "tag_name": tag,
        "draft": draft,
        "prerelease": prerelease,
        "published_at": "2026-07-01T12:00:00Z",
        "html_url": f"https://github.com/{repo}/releases/tag/{tag}",
        "assets": [{"name": a, "size": 1000, "browser_download_url": f"https://github.com/{repo}/releases/download/{tag}/{a}"} for a in assets],
    }


def gh_page(releases):
    return json.dumps(releases, separators=(",", ":"))


def list_route(repo):
    return f"api.github.com/repos/{repo}/releases%3Fper_page=100"


def table(rows):
    w = [max(len(r[i]) for r in rows) + 2 for i in range(len(rows[0]) - 1)]
    return "".join("".join(c.ljust(w[i]) for i, c in enumerate(r[:-1])) + r[-1] + "\n" for r in rows)


LIST_CALLS = "list_dirs $HOME/.cache/roc/talon/index/github/{r}\nprograms gh\nhttp_get https://api.github.com/repos/{r}/releases?per_page=100\n  User-Agent: tln/0.0.1\n"
WRITE_CALLS = "write_atomic $HOME/.cache/roc/talon/index/github/{r}/1.json $HOME/.cache/roc/talon/index/github/{r}/1.meta\n"
NOTE_DIRECT = "note: no yank and advisory data without a registry\n"


def walk_calls(levels):
    text = "random\nlist_dirs $HOME/.cache/roc/packages\n"
    for level in levels:
        text += "read_files " + " ".join(f"$HOME/.cache/roc/packages/{h(k)}/main.roc" for k in level) + "\n"
    return text


def ad1_direct():
    entries = [("pf", "pf", True), ("json", "json", False), ("csv", "csv", False), ("xml", "xml", False), ("pre", "pre", False)]
    keys = ["pf", "json", "csv", "xml", "pre", "parser", "util"]
    lists = {
        "acme/pfx": gh_page([gh_release("acme/pfx", "0.1.0", [h("pf") + ".tar.zst"])]),
        "acme/json": gh_page([gh_release("acme/json", "2.0.0", [h("json200") + ".tar.zst"]), gh_release("acme/json", "2.1.0", [h("json2") + ".tar.zst", "docs.tar.gz"])]),
        "acme/pre": gh_page([gh_release("acme/pre", "1.0.0", [h("pre") + ".tar.zst"], prerelease=True)]),
        "acme/parser": gh_page([gh_release("acme/parser", "1.0.2", [h("parser") + ".tar.zst"])]),
        "someone/roc-util": gh_page([gh_release("someone/roc-util", "0.4.0", [h("old") + ".tar.zst"])]),
    }
    routes = {list_route(r): text for r, text in lists.items()}
    # someone/roc-csv: no route, the fake answers 404 (deleted or private). someone/roc-xml: renamed, GitHub answers 301 to the repository id (Q-244b-1).
    routes[list_route("someone/roc-xml")] = ""
    routes[list_route("someone/roc-xml") + ".meta"] = "status 301\nheader Location: https://api.github.com/repositories/42/releases?per_page=100\n"
    routes["api.github.com/repositories/42/releases%3Fper_page=100"] = gh_page([gh_release("acme/roc-xml", "0.4.0", [h("xml") + ".tar.zst"])])
    kept = {}
    for r, text in lists.items():
        kept[f"{r}/1.json"] = text
        kept[f"{r}/1.meta"] = ""
    cmds = "# R-AU1 R-AU2 (the direct column) R-AU3 R-AU4 R-AU13 R-DI2 R-DI3 R-DI4 R-DI15 (slice 244b): TALON_REGISTRY=direct. q1: pf, json 2.1.0 (the tag 2.1.0 has another package asset now: asset-replaced, new hash known),\n"
    cmds += "# csv (the list answers 404: repo-missing), xml (the list answers 301: moved, successor from the html_url of the new list, Q-244b-1), pre (prerelease). json needs parser (fine) and util (the tag 0.3.0 is not in the list: release-missing).\n"
    cmds += "# The release list of each repository is read once (R-DI2), also for the transitive ones (R-AU1). The pages of a 200 list are kept (R-DI2); a 404 and a redirected list are not (Q-244b-1). No closure query, no privacy guard (no registry request).\n"
    cmds += "# Run 1: the report, exit 21. The last line is the note of R-C6 (R-AU4).\n"
    cmds += "audit --file q1/main.roc\n"
    cmds += "# Run 2: --json, exit 21. The pages of run 1 are younger than 60 s (R-DI2, the clock is TALON_NOW): no request (Q-244b-4).\n"
    cmds += "audit --json --file q1/main.roc\n"
    new6 = h("json2")[:6]
    rows = [
        ["asset replaced", "json 2.1.0", "acme/json", f"GitHub has {new6}..., the header has {h('json')[:6]}...", "header: json"],
        ["repo missing", "csv 1.1.0", "someone/roc-csv", "the repository is deleted or private", "header: csv"],
    ]
    fix_json = "ask the author to release a new version, then run tln update json"
    text = (
        "audit: 7 packages checked (direct)\n" + table(rows)
        + "warning: moved  xml 0.4.0  someone/roc-xml  successor: acme/roc-xml  header: xml\n"
        + "warning: prerelease  pre 1.0.0  acme/pre  header: pre\n"
        + "warning: release missing  util 0.3.0  someone/roc-util  via json\n"
        + "2 findings, 3 warnings, 0 ignored.\n"
        + f"fix: json: {fix_json}. csv: {FIX_CSV}. xml: tln update xml.\n" + NOTE_DIRECT
    )
    m = ["$PROJECT/q1/main.roc"]
    data = {
        "index": "direct",
        "checked": 7,
        "notes": [{"kind": "no-yank-data"}],
        "findings": [
            finding("json", "json", [], "asset-replaced", True, False, None, None, None, fix_json, members=m, new_hash=h("json2")),
            finding("csv", "csv", [], "repo-missing", True, False, None, None, None, FIX_CSV, members=m),
            finding("xml", "xml", [], "moved", False, False, None, None, "acme/roc-xml", "tln update xml", members=m),
            finding("pre", "pre", [], "prerelease", False, False, None, None, None, "tln update pre", members=m),
            finding("util", None, ["json"], "release-missing", False, False, None, None, None, "tln update json (tln why someone/roc-util), or use [overrides]", members=m),
        ],
    }
    msg = FAIL_MSG.format(items="acme/json@2.1.0:asset-replaced, someone/roc-csv@1.1.0:repo-missing")
    stdout = "== audit --file q1/main.roc\n" + text + "exit 21\n== audit --json --file q1/main.roc\n" + env_fail(msg, data) + "exit 21\n"
    stderr = f"tln: error[findings]: {msg}\n" * 2
    order = ["acme/pfx", "acme/json", "someone/roc-csv", "someone/roc-xml", "acme/pre", "acme/parser", "someone/roc-util"]
    run1 = calls_run("q1", [], [], True, True, query=False) + walk_calls([["pf", "json", "csv", "xml", "pre"], ["parser", "util"]])
    for r in order:
        run1 += LIST_CALLS.format(r=r)
        if r == "someone/roc-xml":
            run1 += "http_get https://api.github.com/repositories/42/releases?per_page=100\n  User-Agent: tln/0.0.1\n"
        if r in lists:
            run1 += WRITE_CALLS.format(r=r)
    run2 = calls_run("q1", [], [], False, False, query=False) + walk_calls([["pf", "json", "csv", "xml", "pre"], ["parser", "util"]])
    for r in order:
        if r in lists:
            run2 += f"list_dirs $HOME/.cache/roc/talon/index/github/{r}\nread_files $HOME/.cache/roc/talon/index/github/{r}/1.meta $HOME/.cache/roc/talon/index/github/{r}/1.json\n"
        else:
            run2 += LIST_CALLS.format(r=r)
            if r == "someone/roc-xml":
                run2 += "http_get https://api.github.com/repositories/42/releases?per_page=100\n  User-Agent: tln/0.0.1\n"
    make("ad1-direct", "R-CM14 R-AU1 R-AU2 R-AU3 R-AU4 R-AU13 R-DI2 R-DI3 R-DI4 R-DI15 R-C6 R-OUT2 (slice 244b, Q-244b-1, Q-244b-2, Q-244b-4): tln audit with direct. See fx/commands.", "q1",
         {"q1/main.roc": header(entries)}, keys, {}, [], [], cmds, stdout, stderr, None, run1 + run2, direct=True, routes=routes, kept=kept)


def ad2_direct_clean():
    entries = [("pf", "pf", True), ("json", "json200", False), ("x", "loop", False)]
    keys = ["pf", "json200", "loop"]
    lists = {
        "acme/pfx": gh_page([gh_release("acme/pfx", "0.1.0", [h("pf") + ".tar.zst"])]),
        "acme/json": gh_page([gh_release("acme/json", "2.0.0", [h("json200") + ".tar.zst"])]),
    }
    routes = {list_route(r): text for r, text in lists.items()}
    kept = {}
    for r, text in lists.items():
        kept[f"{r}/1.json"] = text
        kept[f"{r}/1.meta"] = ""
    cmds = "# R-AU1 R-AU3 R-AU4 R-C6 R-DI11 (slice 244b): TALON_REGISTRY=direct. q2: pf and json are fine. x is a loopback URL (R-EV25), a host with no index in direct mode (R-DI11): not checked, not counted, one note (TW24).\n"
    cmds += "# Run 1: exit 0; the notes after the count line, the R-C6 note last. Nothing on stderr.\n"
    cmds += "audit --file q2/main.roc\n"
    cmds += "# Run 2: --json, exit 0: data.notes has no-yank-data and not-indexed.\n"
    cmds += "audit --json --file q2/main.roc\n"
    name = "127.0.0.1:9/x/1.0.0"
    text = "audit: 2 packages checked (direct)\n0 findings, 0 warnings, 0 ignored.\n" + f"note: not checked: {name} 1.0.0: no index without a registry\n" + NOTE_DIRECT
    data = {"index": "direct", "checked": 2, "notes": [{"kind": "no-yank-data"}, {"kind": "not-indexed", "name": name, "version": "1.0.0", "hash": h("loop")}], "findings": []}
    stdout = "== audit --file q2/main.roc\n" + text + "exit 0\n== audit --json --file q2/main.roc\n" + env_ok(data) + "exit 0\n"
    run1 = calls_run("q2", [], [], True, True, query=False) + walk_calls([["pf", "json200", "loop"]])
    for r in lists:
        run1 += LIST_CALLS.format(r=r) + WRITE_CALLS.format(r=r)
    run2 = calls_run("q2", [], [], False, False, query=False) + walk_calls([["pf", "json200", "loop"]])
    for r in lists:
        run2 += f"list_dirs $HOME/.cache/roc/talon/index/github/{r}\nread_files $HOME/.cache/roc/talon/index/github/{r}/1.meta $HOME/.cache/roc/talon/index/github/{r}/1.json\n"
    make("ad2-direct-clean", "R-CM14 R-AU1 R-AU3 R-AU4 R-C6 R-DI11 R-OUT2 (slice 244b): direct with no finding, a host with no index. See fx/commands.", "q2",
         {"q2/main.roc": header(entries)}, keys, {}, [], [], cmds, stdout, "", None, run1 + run2, direct=True, routes=routes, kept=kept)


def ad9_guard():
    entries = [("pf", "pf", True), ("json", "json200", False), ("gone", "gone", False)]
    keys = ["pf", "json200"]
    repos = [repo_item("acme/pfx"), repo_item("acme/json")]
    cmds = "# Design Q620 item 9 (Q-244-9) R-RG4 R-RG6 R-AU2 (slice 244b): a registry. gone (someone/roc-gone) has no kept public answer, and GitHub answers 404 for the repository (no route): for tln audit only,\n"
    cmds += "# this is a repo-missing finding of gone (counted in checked), and its hash is not in the closure query (R-RG4 holds). The other hashes are checked. The walk reads the header of gone from the cache. Exit 21.\n"
    cmds += "audit --file p8/main.roc\n"
    rows = [["repo missing", "gone 1.0.0", "someone/roc-gone", "the repository is deleted or private", "header: gone"]]
    fix_gone = "tln remove gone, then tln add another package, or add the item to [audit] ignore"
    text = "audit: 3 packages checked (registry)\n" + table(rows) + "1 finding, 0 warnings, 0 ignored.\n" + f"fix: gone: {fix_gone}.\n" + NOTE_REG
    msg = FAIL_MSG.format(items="someone/roc-gone@1.0.0:repo-missing")
    stdout = "== audit --file p8/main.roc\n" + text + "exit 21\n"
    stderr = f"tln: error[findings]: {msg}\n"
    calls = calls_run("p8", ["acme/pfx", "acme/json", "someone/roc-gone"], [h("pf"), h("json200")], True, True)
    marker = "http_send POST"
    i = calls.index(marker)
    calls = calls[:i] + "programs gh\nhttp_get https://api.github.com/repos/someone/roc-gone\n  User-Agent: tln/0.0.1\n" + calls[i:] + walk_calls([["gone"]])
    make("ad9-guard", "Q620 R-RG4 R-RG6 R-AU2 R-AU3 (slice 244b, Q-244-9): the privacy guard refuses a repository: repo-missing. See fx/commands.", "p8",
         {"p8/main.roc": header(entries)}, keys, {}, repos, ["acme/pfx", "acme/json"], cmds, stdout, stderr, None, calls, cache=["gone"])


def ad_redirect(name, project, location):
    # Mutation gap G2 (slice 244b, d12): Q621 item 1 follows a redirect of the list only to the same API base. Another host, or no Location: the list fails (exit 15), and no second request goes out (the token never goes to another host).
    entries = [("pf", "pf", True), ("xml", "xml", False)]
    keys = ["pf", "xml"]
    lists = {"acme/pfx": gh_page([gh_release("acme/pfx", "0.1.0", [h("pf") + ".tar.zst"])])}
    routes = {list_route(r): text for r, text in lists.items()}
    routes[list_route("someone/roc-xml")] = ""
    routes[list_route("someone/roc-xml") + ".meta"] = "status 301\n" + (f"header Location: {location}\n" if location else "")
    # A route on the other host: a request to it would show in calls.log (it must not).
    routes["evil.example/repositories/42/releases%3Fper_page=100"] = gh_page([gh_release("acme/roc-xml", "0.4.0", [h("xml") + ".tar.zst"])])
    kept = {}
    for r, text in lists.items():
        kept[f"{r}/1.json"] = text
        kept[f"{r}/1.meta"] = ""
    what = f"Location {location} (another host)" if location else "no Location header"
    cmds = f"# Q621 item 1 (Q-244b-1) R-DI2 (slice 244b, mutation gap G2): TALON_REGISTRY=direct. The list of someone/roc-xml answers 301 with {what}.\n"
    cmds += "# Only a Location on the same API base is followed. Here no second request goes out: exit 15, GitHub answered 301 for <the list URL>.\n"
    cmds += f"audit --file {project}/main.roc\n"
    url_ = "https://api.github.com/repos/someone/roc-xml/releases?per_page=100"
    stdout = f"== audit --file {project}/main.roc\nexit 15\n"
    stderr = f"tln: error[network]: GitHub answered 301 for {url_}\n"
    calls = calls_run(project, [], [], True, True, query=False) + walk_calls([["pf", "xml"]])
    calls += LIST_CALLS.format(r="acme/pfx") + WRITE_CALLS.format(r="acme/pfx") + LIST_CALLS.format(r="someone/roc-xml")
    make(name, "R-CM14 R-DI2 (slice 244b, Q621 item 1, Q-244b-1): a redirect of the list off the API base is not followed. See fx/commands.", project,
         {f"{project}/main.roc": header(entries)}, keys, {}, [], [], cmds, stdout, stderr, None, calls, direct=True, routes=routes, kept=kept)


def au4_not_indexed():
    entries = [("pf", "pf", True), ("json", "json200", False), ("web", "web", False)]
    keys = ["pf", "json200"]
    repos = [repo_item("acme/pfx"), repo_item("acme/json")]
    guard = ["acme/pfx", "acme/json", "acme/web"]
    hashes = [h("pf"), h("json200"), h("web")]
    cmds = "# Q-244-4 (Design Q620) R-AU1 R-OUT2 (slice 244 review): the header entry web (acme/web 1.0.0) is in `unknown` of the closure answer: the registry has no release of it. It is not checked (checked 2), gives no finding,\n"
    cmds += "# and gives one note: `note: not checked: acme/web 1.0.0: the registry has no release of it` in the report on stdout, before the R-AU4 note. No ingest (audit writes nothing to the registry). Exit 0. The walk reads the header of web from the cache.\n"
    cmds += "audit --file p7/main.roc\n"
    cmds += "# The same with --json: the note {\"kind\":\"not-indexed\",\"name\",\"version\",\"hash\"} in data.notes, after no-yank-data. Nothing on stderr.\n"
    cmds += "audit --json --file p7/main.roc\n"
    cmds += "# Q-244-8 (Design Q620): --offline is exit 2 (usage), before any read: tln audit reads the index of now.\n"
    cmds += "audit --offline --file p7/main.roc\n"
    note = "note: not checked: acme/web 1.0.0: the registry has no release of it\n"
    text = "audit: 2 packages checked (registry)\n0 findings, 0 warnings, 0 ignored.\n" + note + NOTE_REG
    data = {"index": "registry", "checked": 2, "notes": [{"kind": "no-yank-data"}, {"kind": "not-indexed", "name": "acme/web", "version": "1.0.0", "hash": h("web")}], "findings": []}
    stdout = "== audit --file p7/main.roc\n" + text + "exit 0\n== audit --json --file p7/main.roc\n" + env_ok(data) + "exit 0\n== audit --offline --file p7/main.roc\nexit 2\n"
    stderr = "tln: error[usage]: tln audit reads the index of now, so it does not take --offline\n"
    calls = calls_run("p7", guard, hashes, True, True) + calls_run("p7", guard, hashes, False, False) + "args\nenv_all\ntty\n"
    make("au4-not-indexed", "Q620 R-AU1 R-OUT2 R-OUT4 R-CM14 R-EC2 (slice 244, Q-244-4, Q-244-8): a closure hash with no release in the answer; --offline. See fx/commands.", "p7",
         {"p7/main.roc": header(entries)}, keys, {}, repos, guard, cmds, stdout, stderr, None, calls, unknown=[h("web")])


if __name__ == "__main__":
    if not os.path.isfile(os.path.join(ROOT, "tests/lib.sh")):
        sys.exit("run from the repo root")
    au1()
    au3_clean()
    au3_warnings()
    au9_ignore()
    au12_bad_items()
    au1_tool()
    au4_not_indexed()
    ad1_direct()
    ad2_direct_clean()
    ad9_guard()
    ad_redirect("ad10-redirect-host", "r1", "https://evil.example/repositories/42/releases?per_page=100")
    ad_redirect("ad11-redirect-none", "r2", None)
    shutil.rmtree(os.path.join(ROOT, ".tmp/mk-audit"), ignore_errors=True)
