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


def make(name, rules, project, files, keys, states, repos, guard, commands, stdout, stderr, exits, calls, unknown=(), direct=False, routes=None, kept=None, cache=(), jobs=""):
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
    if jobs:
        write(os.path.join(d, "fx/jobs"), jobs)
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
        finding("xml", "xml", [], "moved", False, False, SINCE, None, "acme/roc-xml", None, members=m),
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
        f"fix: json: tln update json. csv: {FIX_CSV}. old: tln update old. parser: {FIX_PARSER}.\n" + NOTE_REG
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
    cmds = "# R-AU2 R-AU3 R-AU8 R-OUT2 (slice 244): only findings that do not fail: xml moved (successor acme/roc-xml), util unpublished (release-missing), pre edited (prerelease). Exit 0, 3 warning lines, no fix line (Q-244c-4: moved has no fix before P3, the others do not fail).\n"
    cmds += "audit --file p3/main.roc\n"
    cmds += "# R-OUT2: --json: each finding has fails false; exit 0.\n"
    cmds += "audit --json --file p3/main.roc\n"
    text = (
        "audit: 4 packages checked (registry)\n"
        "warning: moved  xml 0.4.0  someone/roc-xml  successor: acme/roc-xml  header: xml\n"
        "warning: release missing  util 0.3.0  someone/roc-util  header: util\n"
        "warning: prerelease  pre 1.0.0  acme/pre  header: pre\n"
        "0 findings, 3 warnings, 0 ignored.\n"
        + NOTE_REG
    )
    m = ["$PROJECT/p3/main.roc"]
    data = {
        "index": "registry",
        "checked": 4,
        "notes": [{"kind": "no-yank-data"}],
        "findings": [
            finding("xml", "xml", [], "moved", False, False, SINCE, None, "acme/roc-xml", None, members=m),
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
    run1 = head + warn + ign + "ignored: acme/parser@1.0.2:asset-replaced\nunused ignore: someone/roc-gone@1.0.0:yanked\n0 findings, 2 warnings, 4 ignored.\n" + NOTE_REG
    run3 = head + parser_row + warn + ign + "unused ignore: someone/roc-gone@1.0.0:yanked\n1 finding, 2 warnings, 3 ignored.\n" + f"fix: parser: {FIX_PARSER}.\n" + NOTE_REG
    run4 = head + parser_row + warn + ign + "unused ignore: someone/roc-gone@1.0.0:yanked\nunused ignore: ACME/Parser@1.0.2:yanked\n1 finding, 2 warnings, 3 ignored.\n" + f"fix: parser: {FIX_PARSER}.\n" + NOTE_REG
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
        + f"fix: json: {fix_json}. csv: {FIX_CSV}.\n" + NOTE_DIRECT
    )
    m = ["$PROJECT/q1/main.roc"]
    data = {
        "index": "direct",
        "checked": 7,
        "notes": [{"kind": "no-yank-data"}],
        "findings": [
            finding("json", "json", [], "asset-replaced", True, False, None, None, None, fix_json, members=m, new_hash=h("json2")),
            finding("csv", "csv", [], "repo-missing", True, False, None, None, None, FIX_CSV, members=m),
            finding("xml", "xml", [], "moved", False, False, None, None, "acme/roc-xml", None, members=m),
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


# ---- Slice 244c (R-AU7, R-AU14, R-FE10): the audit warnings of a resolve. The cases are copies of registry/di1-install-no-free (project u1: pf, json, parser, all held; no talon.toml),
# with a changed closure answer. Run 1 of di1 is `install --no-check --dry-run --json --file u1/main.roc`: its calls are the calls of these runs (R-AU7: no extra request).
REG = os.path.join(ROOT, "tests/commands/cases/registry")
BASE = os.path.join(REG, "di1-install-no-free")
H_JSON = "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21"
H_PARSER = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc"
U_JSON = f"https://github.com/acme/json/releases/download/2.0.0/{H_JSON}.tar.zst"
PARSER_REPO = '{"id":2,"full_name":"acme/parser","private":false,"fork":false}'


def base_calls():
    # Run 1 of di1 (--json, first run): from the first `args` to the closure query.
    with open(os.path.join(BASE, "expect/calls.log")) as f:
        lines = f.read().split("\n")
    end = [i for i, l in enumerate(lines) if l == "args"][1]
    return lines[:end]


def run_calls(first, tty):
    # A later run: projects.json is not written again, path-roc.json is kept (no `roc version`), the privacy answer of acme/parser is kept (no GitHub request). A human run calls `tty`.
    out = []
    skip = 0
    for l in base_calls():
        if skip:
            skip -= 1
            continue
        if not first and l == "write_atomic $HOME/.cache/roc/talon/projects.json":
            continue
        if not first and l == "spawn_all limit=1":
            skip = 2  # the job line and the write of path-roc.json
            continue
        if not first and l == "programs gh":
            skip = 3  # the GitHub request, its header line and the write of repo.json
            continue
        out.append(l)
        if tty and l == "env_all" and out.count("env_all") == 1:
            out.append("tty")
    return "\n".join(out) + "\n"


def copy_base(name, rules, commands, change, stdout, stderr, calls, drop_cache=(), programs=None, jobs_extra="", files=None, kept=None):
    d = os.path.join(REG, name)
    baked = None
    if os.path.isfile(os.path.join(d, "expect/calls.log")):
        with open(os.path.join(d, "expect/calls.log")) as f:
            baked = f.read()
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(BASE, d)
    shutil.rmtree(os.path.join(d, "expect"))
    shutil.rmtree(os.path.join(d, "given/project/u2"))
    for k in drop_cache:
        shutil.rmtree(os.path.join(d, "given/home/.cache/roc/packages", k))
    ans_path = os.path.join(d, "fx/http/127.0.0.1%3A9/v1/closure.POST")
    with open(ans_path) as f:
        ans = json.load(f)
    change(ans)
    write(ans_path, json.dumps(ans, separators=(",", ":")))
    write(os.path.join(d, "rules"), rules + "\n")
    write(os.path.join(d, "fx/commands"), commands)
    for rel, text in (files or {}).items():
        write(os.path.join(d, "given/project", rel), text)
    if programs is not None:
        write(os.path.join(d, "fx/programs"), programs)
    if jobs_extra:
        with open(os.path.join(d, "fx/jobs")) as f:
            jobs = f.read()
        write(os.path.join(d, "fx/jobs"), jobs + jobs_extra)
    write(os.path.join(d, "expect/stdout"), stdout)
    if stderr:
        write(os.path.join(d, "expect/stderr"), stderr)
    write(os.path.join(d, "expect/exit"), "0\n")
    write(os.path.join(d, "expect/calls.log"), baked if baked is not None else calls)
    tree(d, "u1", {"acme/parser/repo.json": PARSER_REPO} if kept is None else kept)


def repo_state(ans, name, state, successor=None):
    for r in ans["repos"]:
        if r["name"] == name:
            r["state"] = state
            r["successor"] = successor


def au7_install():
    def change(ans):
        repo_state(ans, "acme/json", "missing")
        repo_state(ans, "acme/parser", "moved", "acme/roc-parser")
    fix_json = "tln remove json, then tln add another package, or add the item to [audit] ignore"
    line_json = f"json: acme/json 2.0.0 is in a deleted or private repository. Fix: {fix_json}."
    line_parser = "parser: moved to acme/roc-parser"
    warn = f"warning: {line_json}\nwarning: {line_parser}\n"
    cmds = "# R-AU7 R-AU14 R-FL4 R-J2 R-OUT4 (slice 244c, Q-244c-1 to Q-244c-4): tln install with a registry, all entries held (the world of registry/di1-install-no-free, project u1).\n"
    cmds += "# The closure answer says: acme/json is missing (repo-missing, json 2.0.0 is a header entry), acme/parser moved to acme/roc-parser (a rename). pf is fine.\n"
    cmds += "# One warning line on stderr for each closure hash with a reason, in the order of the walk; for moved the line of R-PU28 (P2 text, Q-244c-4). No extra request, exit 0.\n"
    cmds += "install --no-check --dry-run --file u1/main.roc\n"
    cmds += "# --json: data.audit_warnings (new member after written, TW24); the human lines stay on stderr (R-J2).\n"
    cmds += "install --no-check --dry-run --json --file u1/main.roc\n"
    cmds += "# --quiet hides the notes and the answer lines, not the warnings (R-FL4).\n"
    cmds += "install --no-check --dry-run --quiet --file u1/main.roc\n"
    docs = [
        {"name": "acme/json", "group": "github.com/acme/json/releases/download/{v}/", "version": "2.0.0", "hash": H_JSON, "alias": "json", "via": [], "reason": "repo-missing", "successor": None, "text": line_json},
        {"name": "acme/parser", "group": "github.com/acme/parser/releases/download/{v}/", "version": "1.0.0", "hash": H_PARSER, "alias": "parser", "via": [], "reason": "moved", "successor": "acme/roc-parser", "text": line_parser},
    ]
    data = {"snapshot": "log:50", "log_size": 50, "probes": 0, "downloads": 0, "dry_run": True, "check": None, "build": None, "added": [], "moved": [], "kept": [], "pinned": None, "toml": [], "renamed": [], "notes": [], "written": [], "audit_warnings": docs}
    env = json.dumps({"schema": 1, "command": "install", "ok": True, "data": data, "error": None}, separators=(",", ":"))
    done = "nothing to change\ndry run: nothing was written\n"
    stdout = "== install --no-check --dry-run --file u1/main.roc\n" + done + "exit 0\n"
    stdout += "== install --no-check --dry-run --json --file u1/main.roc\n" + env + "\nexit 0\n"
    stdout += "== install --no-check --dry-run --quiet --file u1/main.roc\nexit 0\n"
    stderr = warn + warn + done + warn
    calls = run_calls(True, True) + run_calls(False, False) + run_calls(False, True)
    copy_base("au7-install-warnings", "R-AU7 R-AU14 R-FL4 R-J2 R-OUT4 (slice 244c): the audit warnings of tln install with a registry. See fx/commands.", cmds, change, stdout, stderr, calls)


def fe10_install_404():
    def change(ans):
        ans["artifacts"] = [a for a in ans["artifacts"] if a["hash"] != H_JSON]
        for r in ans["releases"]:
            if r["hash"] == H_JSON:
                r["withdrawn"] = "asset-replaced"
    cmds = "# R-FE10 R-FE6 R-AU6 (slice 244c): tln install with a registry (project u1 of registry/di1-install-no-free). The answer has the release row of json 2.0.0 with withdrawn asset-replaced,\n"
    cmds += "# and no artifact record of it, so the resolve downloads the archive (Gather, R-AL8 source 4). The download answers 404 (no mirror before P3): exit 15. The message gives the reason and the fix (R-AU8) of that state.\n"
    cmds += "install --no-check --dry-run --file u1/main.roc\n"
    tmp = f"$HOME/.cache/roc/packages/{H_JSON}.0123456789abcdef.tmp"
    calls = run_calls(True, True)
    calls += "random\nlist_dirs $HOME/.cache/roc/packages\nprograms curl wget\n"
    calls += f"make_dirs {tmp}\nspawn_all limit=8\n  job - curl --fail --location --silent --show-error --proto =https,http --proto-redir =https --retry 2 --connect-timeout 30 --output {tmp}/{H_JSON}.tar.zst {U_JSON}\ndelete {tmp}\n"
    msg = f"tln: error[network]: download of acme/json 2.0.0 failed: 404 ({U_JSON}). The registry says: the asset was replaced. Ask the author to release a new version, then run tln update json.\n"
    copy_base("fe10-install-404", "R-FE10 R-FE6 R-AU6 R-AU8 (slice 244c): a download 404 of a closure URL whose release state the command has. See fx/commands.", cmds, change,
              "== install --no-check --dry-run --file u1/main.roc\nexit 15\n", msg, calls, drop_cache=[H_JSON], programs="roc\ncurl\n",
              jobs_extra=f"{H_JSON}.tar.zst\t22\t-\tcurl: (22) The requested URL returned error: 404\t-\n")


# ---- Slice 244c mutation gaps (research/slice-244c-revert/RESULT.md).
def au7_no_finding():
    # G3 (c11), R-J6: a --json resolve with a closure answer and no finding has no `audit_warnings` member: the output of di1 run 1 as it is.
    cmds = "# R-AU7 R-J6 (slice 244c, mutation gap G3): the answer of registry/di1-install-no-free (all repositories active, no withdrawn row in the closure). --json: data has no audit_warnings member (no output of today changes).\n"
    cmds += "install --no-check --dry-run --json --file u1/main.roc\n"
    with open(os.path.join(BASE, "expect/stdout")) as f:
        first = f.read().split("\n")[1]
    stdout = "== install --no-check --dry-run --json --file u1/main.roc\n" + first + "\nexit 0\n"
    copy_base("au7-no-finding", "R-AU7 R-J6 (slice 244c, mutation gap G3): no finding, no audit_warnings member. See fx/commands.", cmds, lambda ans: None,
              stdout, "nothing to change\ndry run: nothing was written\n", run_calls(True, False))


def au7_ignore():
    # G2 (c3b), Q-244c-3: a bad item of [audit] ignore does not drop the good items, and does not stop the resolve.
    def change(ans):
        repo_state(ans, "acme/json", "missing")
        repo_state(ans, "acme/parser", "moved", "acme/roc-parser")
    cmds = "# R-AU7 R-AU9 (slice 244c, Q-244c-3, mutation gap G2): the answer of au7-install-warnings (json repo-missing, parser moved). u1/talon.toml has [audit] ignore with the json item and a bad item.\n"
    cmds += "# The json finding is ignored: no line. The bad item is skipped: no stop, no line about it (only tln audit reports it). The parser line stays. Exit 0.\n"
    cmds += "install --no-check --dry-run --file u1/main.roc\n"
    toml = '[audit]\nignore = ["acme/json@2.0.0:repo-missing", "bad"]\n'
    copy_base("au7-ignore", "R-AU7 R-AU9 (slice 244c, Q-244c-3): [audit] ignore in a resolve, with a bad item. See fx/commands.", cmds, change,
              "== install --no-check --dry-run --file u1/main.roc\nnothing to change\ndry run: nothing was written\nexit 0\n",
              "warning: parser: moved to acme/roc-parser\n", run_calls(True, True), files={"u1/talon.toml": toml})


def au7_held_move():
    # G1 (c1), Q-244c-2: with a held move the second answer is searched first. Run 1 of registry/ap30-held-move-notes (update yaml@1.1.0 moves pf, held).
    # The first answer gets the release row of json 2.0.0 (a held header entry) with acme/json active; the second answer says acme/json is missing.
    base = os.path.join(REG, "ap30-held-move-notes")
    d = os.path.join(REG, "au7-held-move")
    baked = None
    if os.path.isfile(os.path.join(d, "expect/calls.log")):
        with open(os.path.join(d, "expect/calls.log")) as f:
            baked = f.read()
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(base, d)
    v1 = os.path.join(d, "fx/http/127.0.0.1%3A9/v1")
    for n in range(3, 9):
        for ext in ("", ".meta"):
            os.remove(os.path.join(v1, f"closure.POST.{n}{ext}"))
    with open(os.path.join(v1, "closure.POST")) as f:
        first = json.load(f)
    with open(os.path.join(v1, "closure.POST.2")) as f:
        second = json.load(f)
    row = [r for r in second["releases"] if r["hash"] == H_JSON][0]
    first["releases"].append(row)
    first["repos"].append({"name": "acme/json", "state": "active", "successor": None, "state_at": 1700000000000})
    repo_state(second, "acme/json", "missing")
    write(os.path.join(v1, "closure.POST"), json.dumps(first, separators=(",", ":")))
    write(os.path.join(v1, "closure.POST.2"), json.dumps(second, separators=(",", ":")))
    cmd = "update yaml@1.1.0 --no-check --dry-run --file u1/main.roc"
    write(os.path.join(d, "fx/commands"), "# R-AU7 (slice 244c, Q-244c-2, mutation gap G1): run 1 of registry/ap30-held-move-notes. The first answer says acme/json is active (with the row of json 2.0.0), the second answer of the held move says it is missing.\n# The second answer is searched first: one repo-missing line for json.\n" + cmd + "\n")
    write(os.path.join(d, "rules"), "R-AU7 R-AP16 R-SP24 (slice 244c, Q-244c-2): the state of a hash comes from the second answer of a held move first. See fx/commands.\n")
    with open(os.path.join(base, "expect/stdout")) as f:
        out = f.read()
    out = out[: out.index("== ", 3)]
    with open(os.path.join(base, "expect/stderr")) as f:
        err = f.read().split("\n")[:2]
    fix_json = "tln remove json, then tln add another package, or add the item to [audit] ignore"
    # The warning comes after the closure notes, before the lines of the held moves (the real order).
    err = f"warning: json: acme/json 2.0.0 is in a deleted or private repository. Fix: {fix_json}.\n" + "\n".join(err) + "\n"
    write(os.path.join(d, "expect/stdout"), out)
    write(os.path.join(d, "expect/stderr"), err)
    with open(os.path.join(base, "expect/calls.log")) as f:
        lines = f.read().split("\n")
    end = [i for i, l in enumerate(lines) if l == "args"][1]
    write(os.path.join(d, "expect/calls.log"), baked if baked is not None else "\n".join(lines[:end]) + "\n")


# ---- Slice 244d (docs/slices/244-audit.md, part 244d).
def gh_rel_json(repo, tag, hashes, published):
    return {"tag_name": tag, "draft": False, "prerelease": False, "published_at": published,
            "assets": [{"name": f"{x}.tar.zst", "size": 1000, "browser_download_url": f"https://github.com/{repo}/releases/download/{tag}/{x}.tar.zst"} for x in hashes]}


def keep_baked(d):
    out = {}
    for f in ("calls.log",):
        path = os.path.join(d, "expect", f)
        if os.path.isfile(path):
            with open(path) as fh:
                out[f] = fh.read()
    return out


DIRECT_STDOUT = """== update json --no-check --dry-run --file u1/main.roc
@STDOUT@exit 0
"""


def au7_direct_series(name="update/au7-direct-series", rules=None, cmds=None, stdout=None, stderr=None, adjust=None, mtimes="", kept_repos=("acme/json",)):
    # Item 1 (R-AU7 with direct, Q622 items 1, 2, 5): the world of registry/ap30-update-notes with no registry (direct), and 2 more series of acme/json in the header:
    # json1 (1.0.0: the list has no tag 1.0.0 any more: release-missing) and json3 (3.0.0: the tag has another package asset now: asset-replaced with a known new hash, R-DI15).
    # `update json` frees json (series 2) only, so json1 and json3 are held; the pick reads the list of acme/json once (R-DI2).
    base = os.path.join(REG, "ap30-update-notes")
    d = os.path.join(ROOT, "tests/commands/cases", name)
    baked = keep_baked(d)
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(base, d)
    shutil.rmtree(os.path.join(d, "expect"))
    shutil.rmtree(os.path.join(d, "fx/http/127.0.0.1%3A9"))
    os.remove(os.path.join(d, "given/home/.config/talon/config.toml"))
    for r in ("pfx", "json"):
        shutil.rmtree(os.path.join(d, f"given/home/.cache/roc/talon/index/github/acme/{r}"), ignore_errors=True)
    h1, h3, h3n = h("json1"), h("json3"), h("json3new")
    main = os.path.join(d, "given/project/u1/main.roc")
    with open(main) as f:
        text = f.read()
    extra = (f'\tjson1: "https://github.com/acme/json/releases/download/1.0.0/{h1}.tar.zst",\n'
             f'\tjson3: "https://github.com/acme/json/releases/download/3.0.0/{h3}.tar.zst",\n')
    text = text.replace("\troc:", extra + "\troc:")
    write(main, text)
    for k in (h1, h3):
        write(os.path.join(d, f"given/home/.cache/roc/packages/{k}/main.roc"), "package [Lib] {}\n")
    route = os.path.join(d, "fx/http/api.github.com/repos/acme/json/releases%3Fper_page=100")
    with open(route) as f:
        rels = json.load(f)
    rels.append(gh_rel_json("acme/json", "1.1.0", [h("json11")], "2026-08-01T12:00:00Z"))
    rels.append(gh_rel_json("acme/json", "3.0.0", [h3n], "2026-08-02T12:00:00Z"))
    write(route, json.dumps(rels))
    if adjust:
        adjust(d, h1)
    if mtimes:
        write(os.path.join(d, "fx/mtimes"), mtimes)
    write(os.path.join(d, "rules"), rules or "R-AU7 R-DI2 R-DI15 (slice 244d item 1, Q622 items 1, 2, 5): the audit warnings of a resolve with direct, from the release list that the pick read. See fx/commands.\n")
    base_cmds = "# R-AU7 (slice 244d, Q622): direct (no registry). u1 has json (acme/json 2.0.0), json1 (acme/json 1.0.0) and json3 (acme/json 3.0.0). update json reads the list of acme/json (one request).\n"
    base_cmds += "# The list has no tag 1.0.0: one release-missing line for json1. The tag 3.0.0 has another package asset: the R-DI15 warning of today, and no R-AU7 line (Q622 item 5). No extra request: calls.log is the run of today.\n"
    base_cmds += "update json --no-check --dry-run --file u1/main.roc\n"
    cmds = cmds or base_cmds
    write(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_REGISTRY=direct\n")
    write(os.path.join(d, "fx/commands"), cmds)
    write(os.path.join(d, "expect/stdout"), stdout if stdout is not None else DIRECT_STDOUT.replace("@STDOUT@", AU7_DIRECT_OUT))
    write(os.path.join(d, "expect/stderr"), stderr if stderr is not None else AU7_DIRECT_ERR)
    write(os.path.join(d, "expect/exit"), "0\n")
    write(os.path.join(d, "expect/calls.log"), baked.get("calls.log", "(guess: the calls of today; baked from the real run)\n"))
    kept = {}
    for r in kept_repos:
        with open(os.path.join(d, "fx/http", list_route(r))) as f:
            kept[f"{r}/1.json"] = f.read()
        kept[f"{r}/1.meta"] = ""
    tree(d, "u1", kept)


AU7_DIRECT_OUT = 'check: skipped\n$PROJECT/u1/main.roc\n  ~ json: acme/json 2.0.0 -> 2.1.0\nresolved at 2026-10-15T12:00:00Z, 0 probes\ndry run: nothing was written\n'
# The stderr of today (the R-DI15 warning of Index.candidates, the R-C8 closure note), then the new R-AU7 line (after the closure notes).
AU7_DIRECT_ERR = 'warning: acme/json 3.0.0: the release has the hash CN1mAUVH23GpH5gUcJWbD3aTrsc2KMeGEEmHa7n8qju3, but Talon knows https://github.com/acme/json/releases/download/3.0.0/6hQqfPCHRKKyu51zWmUVkrvjg1isMDorbhCfd42F4atP.tar.zst with the hash 6hQqfPCHRKKyu51zWmUVkrvjg1isMDorbhCfd42F4atP. It is not a candidate.\nwarning: acme/json has 3 series in the closure: 2 via json, 1 via json1, 3 via json3. The types of the 3 series are different types.\n' + 'warning: json1: acme/json 1.0.0 has a deleted release. Fix: tln update json1.\n'
AU7_DIRECT_KEPT = {"acme/json/1.json": None, "acme/json/1.meta": ""}


def gone_job(key):
    return f"{h(key)}.tar.zst\t22\t-\tcurl: (22) The requested URL returned error: 404\t-\n"


def fetch_gone(key):
    tmp = f"$HOME/.cache/roc/packages/{h(key)}.0123456789abcdef.tmp"
    return (f"random\nlist_dirs $HOME/.cache/roc/packages\nprograms curl wget\nmake_dirs {tmp}\nspawn_all limit=8\n"
            f"  job - curl --fail --location --silent --show-error --proto =https,http --proto-redir =https --retry 2 --connect-timeout 30 --output {tmp}/{h(key)}.tar.zst {u(key)}\ndelete {tmp}\n")


def gone_note(key):
    repo, version, _ = PKG[key]
    return f"note: not checked: the deps of {repo} {version}: its archive is gone\n"


def gone_doc(key):
    repo, version, _ = PKG[key]
    return {"kind": "deps-not-checked", "name": repo, "version": version, "hash": h(key)}


def ad12_archive_gone():
    # Item 2 (Q621 item 3, Q-244b-3) with direct: json is not in the cache and its archive answers 404. For tln audit it is a leaf: its finding comes from the list
    # (the tag 2.1.0 has another package asset: asset-replaced with the new hash), its deps (parser, util) are not checked, one note. Exit 21 (the finding fails).
    entries = [("pf", "pf", True), ("json", "json", False)]
    lists = {
        "acme/pfx": gh_page([gh_release("acme/pfx", "0.1.0", [h("pf") + ".tar.zst"])]),
        "acme/json": gh_page([gh_release("acme/json", "2.1.0", [h("json2") + ".tar.zst"])]),
    }
    routes = {list_route(r): text for r, text in lists.items()}
    kept = {}
    for r, text in lists.items():
        kept[f"{r}/1.json"] = text
        kept[f"{r}/1.meta"] = ""
    cmds = "# Q621 item 3 (Q-244b-3) R-AU1 R-AU2 R-DI7 (slice 244d item 2): TALON_REGISTRY=direct. q3: pf (in the cache, fine), json 2.1.0 (NOT in the cache; its download answers 404).\n"
    cmds += "# For tln audit only, json is a leaf: its finding from the list (asset-replaced, new hash known), its deps not checked, the note of Q621 item 3 (after the fix line, before the R-C6 note). Exit 21.\n"
    cmds += "audit --file q3/main.roc\n"
    cmds += "# --json: data.notes has the note kind deps-not-checked (TW24) after no-yank-data. The download is tried again (no file of a gone archive is kept).\n"
    cmds += "audit --json --file q3/main.roc\n"
    fix_json = "ask the author to release a new version, then run tln update json"
    rows = [["asset replaced", "json 2.1.0", "acme/json", f"GitHub has {h('json2')[:6]}..., the header has {h('json')[:6]}...", "header: json"]]
    text = ("audit: 2 packages checked (direct)\n" + table(rows) + "1 finding, 0 warnings, 0 ignored.\n" + f"fix: json: {fix_json}.\n" + gone_note("json") + NOTE_DIRECT)
    m = ["$PROJECT/q3/main.roc"]
    data = {"index": "direct", "checked": 2, "notes": [{"kind": "no-yank-data"}, gone_doc("json")],
            "findings": [finding("json", "json", [], "asset-replaced", True, False, None, None, None, fix_json, members=m, new_hash=h("json2"))]}
    msg = FAIL_MSG.format(items="acme/json@2.1.0:asset-replaced")
    stdout = "== audit --file q3/main.roc\n" + text + "exit 21\n== audit --json --file q3/main.roc\n" + env_fail(msg, data) + "exit 21\n"
    stderr = f"tln: error[findings]: {msg}\n" * 2
    walk = fetch_gone("json") + f"read_files $HOME/.cache/roc/packages/{h('pf')}/main.roc\n"
    run1 = calls_run("q3", [], [], True, True, query=False) + walk
    for r in lists:
        run1 += LIST_CALLS.format(r=r) + WRITE_CALLS.format(r=r)
    run2 = calls_run("q3", [], [], False, False, query=False) + walk
    for r in lists:
        run2 += f"list_dirs $HOME/.cache/roc/talon/index/github/{r}\nread_files $HOME/.cache/roc/talon/index/github/{r}/1.meta $HOME/.cache/roc/talon/index/github/{r}/1.json\n"
    make("ad12-archive-gone", "Q621 R-AU1 R-AU2 R-DI7 R-OUT2 (slice 244d item 2, Q-244b-3): direct, a package whose archive is gone is a leaf for tln audit. See fx/commands.", "q3",
         {"q3/main.roc": header(entries)}, ["pf"], {}, [], [], cmds, stdout, stderr, None, run1 + run2, direct=True, routes=routes, kept=kept, jobs=gone_job("json"))


def ad13_guard_gone():
    # Item 2 with a registry: the world of ad9-guard, but gone is not in the cache and its archive answers 404: a leaf, its repo-missing finding (Q620 item 9), the note.
    entries = [("pf", "pf", True), ("json", "json200", False), ("gone", "gone", False)]
    keys = ["pf", "json200"]
    repos = [repo_item("acme/pfx"), repo_item("acme/json")]
    cmds = "# Q621 item 3 (Q-244b-3) Q620 item 9 R-RG4 (slice 244d item 2): the world of ad9-guard (gone: the guard refuses someone/roc-gone, so its hash is not in the query),\n"
    cmds += "# but gone is not in the cache and its download answers 404. For tln audit it is a leaf: its repo-missing finding, the note of Q621 item 3. Exit 21.\n"
    cmds += "audit --file p9/main.roc\n"
    rows = [["repo missing", "gone 1.0.0", "someone/roc-gone", "the repository is deleted or private", "header: gone"]]
    fix_gone = "tln remove gone, then tln add another package, or add the item to [audit] ignore"
    text = "audit: 3 packages checked (registry)\n" + table(rows) + "1 finding, 0 warnings, 0 ignored.\n" + f"fix: gone: {fix_gone}.\n" + gone_note("gone") + NOTE_REG
    msg = FAIL_MSG.format(items="someone/roc-gone@1.0.0:repo-missing")
    calls = calls_run("p9", ["acme/pfx", "acme/json", "someone/roc-gone"], [h("pf"), h("json200")], True, True)
    marker = "http_send POST"
    i = calls.index(marker)
    calls = calls[:i] + "programs gh\nhttp_get https://api.github.com/repos/someone/roc-gone\n  User-Agent: tln/0.0.1\n" + calls[i:] + fetch_gone("gone")
    make("ad13-guard-gone", "Q621 Q620 R-RG4 R-AU2 (slice 244d item 2, Q-244b-3): a refused repository whose archive is gone is a leaf for tln audit. See fx/commands.", "p9",
         {"p9/main.roc": header(entries)}, keys, {}, repos, ["acme/pfx", "acme/json"], cmds, "== audit --file p9/main.roc\n" + text + "exit 21\n", f"tln: error[findings]: {msg}\n", None, calls, jobs=gone_job("gone"))


def au7_frozen():
    # Q-244c-1 (Q622 item 1): --frozen sends no closure query, so it prints no audit warning, also when the registry would say json is missing (the answer of au7-install-warnings is not asked for).
    def change(ans):
        repo_state(ans, "acme/json", "missing")
        repo_state(ans, "acme/parser", "moved", "acme/roc-parser")
    cmds = "# R-AU7 R-AU6 R-LF1 (slice 244d, Q-244c-1): tln install --frozen with the registry of au7-install-warnings. No closure query, no audit warning, exit 0. calls.log: the real run (no http call).\n"
    cmds += "install --frozen --file u1/main.roc\n"
    copy_base("au7-frozen", "R-AU7 R-AU6 R-LF1 (slice 244d, Q-244c-1): --frozen prints no audit warning. See fx/commands.", cmds, change,
              "== install --frozen --file u1/main.roc\nthe header satisfies talon.toml\nexit 0\n", "", "(guess: baked from the real run)\n", kept={})


def au7_direct_held_move():
    # Q623 item 3 ("the last read of each repository", Q-244d-3): direct, a held move. u1: pf, json (acme/json 2.0.0), json1 (acme/json 1.0.0, another series), yaml (acme/yaml 1.0.0).
    # update yaml@1.1.0: the first search lists acme/yaml only; yaml 1.1.0 needs json 2.1.0 and json is held, so the first search has no tuple. The second search frees json and lists acme/json
    # (its first read in the run). That list has no tag 1.0.0: the R-AU7 line for json1 comes only from a list of the second search.
    d = os.path.join(ROOT, "tests/commands/cases/update/au7-direct-held-move")
    baked = keep_baked(d)
    shutil.rmtree(d, ignore_errors=True)
    h_pf, h_json, h_json21, h_yaml = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL", H_JSON, "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq", "67RGmW5jLihk6Dbbcr7fH8b66zZx8qZDsG2qNkdxJKiZ"
    h1, hy11 = h("json1"), h("yaml11")
    gh = lambda repo, ver, x: f"https://github.com/{repo}/releases/download/{ver}/{x}.tar.zst"
    main = "app [main!] {\n" + "".join([
        f'\tpf: platform "{gh("acme/pfx", "0.1.0", h_pf)}",\n',
        f'\tjson: "{gh("acme/json", "2.0.0", h_json)}",\n',
        f'\tjson1: "{gh("acme/json", "1.0.0", h1)}",\n',
        f'\tyaml: "{gh("acme/yaml", "1.0.0", h_yaml)}",\n',
        '\troc: "nightly-2026-10-14-38a3029",\n']) + "}\n\nmain! = |_args| Ok({})\n"
    write(os.path.join(d, "given/project/u1/main.roc"), main)
    pfh = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
    pkgs = {h_pf: pfh, h_json: "package [Lib] {}\n", h_json21: "package [Lib] {}\n", h1: "package [Lib] {}\n", h_yaml: "package [Lib] {}\n",
            hy11: 'package [Lib] { json: "' + gh("acme/json", "2.1.0", h_json21) + '" }\n'}
    for k, text in pkgs.items():
        write(os.path.join(d, f"given/home/.cache/roc/packages/{k}/main.roc"), text)
    lists = {
        "acme/yaml": [gh_rel_json("acme/yaml", "1.0.0", [h_yaml], "2026-08-01T12:00:00Z"), gh_rel_json("acme/yaml", "1.1.0", [hy11], "2026-09-01T12:00:00Z")],
        "acme/json": [gh_rel_json("acme/json", "2.0.0", [h_json], "2026-08-16T12:00:00Z"), gh_rel_json("acme/json", "2.1.0", [h_json21], "2026-09-25T12:00:00Z")],
        "acme/pfx": [gh_rel_json("acme/pfx", "0.1.0", [h_pf], "2026-07-01T12:00:00Z")],
    }
    kept = {}
    for r, rels in lists.items():
        text = json.dumps(rels)
        write(os.path.join(d, "fx/http", list_route(r)), text)
        kept[f"{r}/1.json"] = text
        kept[f"{r}/1.meta"] = ""
    for src in ("entry", "fx/gitdirs", "fx/path-roc", "fx/jobs", "fx/programs"):
        shutil.copy(os.path.join(REG, "ap30-held-move-notes", src), os.path.join(d, src))
    write(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\nTALON_REGISTRY=direct\n")
    write(os.path.join(d, "rules"), "R-AU7 R-SP16 R-SP24 R-DI2 (slice 244d, Q623 item 3): direct, the R-AU7 line from a list that only the second search of a held move read. See fx/commands.\n")
    cmds = "# R-AU7 (slice 244d, Q623 item 3, Q-244d-3): TALON_REGISTRY=direct. update yaml@1.1.0: the first search lists acme/yaml; yaml 1.1.0 needs json 2.1.0, json is held: the second search frees json and lists acme/json.\n"
    cmds += "# The list of acme/json has no tag 1.0.0: one release-missing line for json1, from the list of the second search. No extra request.\n"
    cmds += "update yaml@1.1.0 --no-check --dry-run --file u1/main.roc\n"
    write(os.path.join(d, "fx/commands"), cmds)
    write(os.path.join(d, "expect/stdout"), HELD_DIRECT_OUT)
    write(os.path.join(d, "expect/stderr"), HELD_DIRECT_ERR)
    write(os.path.join(d, "expect/exit"), "0\n")
    write(os.path.join(d, "expect/calls.log"), baked.get("calls.log", "(guess: baked from the real run)\n"))
    tree(d, "u1", kept)


HELD_DIRECT_OUT = '== update yaml@1.1.0 --no-check --dry-run --file u1/main.roc\ncheck: skipped\n$PROJECT/u1/main.roc\n  ~ json: acme/json 2.0.0 -> 2.1.0\n  ~ yaml: acme/yaml 1.0.0 -> 1.1.0\n$PROJECT/u1/talon.toml: yaml = "=1.1.0"\nresolved at 2026-10-15T12:00:00Z, 0 probes\ndry run: nothing was written\nexit 0\n'
# The stderr of today (the R-C8 closure note, the report of the held move), with the new R-AU7 line after the closure notes (the order of au7-held-move).
HELD_DIRECT_ERR = 'warning: acme/json has 2 series in the closure: 2 via json, 1 via json1. The types of the 2 series are different types.\nwarning: json1: acme/json 1.0.0 has a deleted release. Fix: tln update json1.\n~ json: acme/json 2.0.0 -> 2.1.0 (held): yaml 1.1.0 needs json >= 2.1.0\n  writes $PROJECT/u1/main.roc\n'


# ---- Slice 244d mutation gaps (research/slice-244d-revert/RESULT.md). The expected files are the real runs, read by eye (the code is right for these cases).
def g_verify():
    # G3 (e9): verify is fed too.
    cmds = "# R-AU7 R-CM11 (slice 244d, mutation gap G3): the world of update/au7-direct-series, with verify. The same audit lines as update when verify reads the list of acme/json.\n"
    cmds += "verify --no-check --file u1/main.roc\n"
    au7_direct_series("verify/au7-direct", "R-AU7 R-CM11 (slice 244d, mutation gap G3): verify prints the direct audit warnings. See fx/commands.\n", cmds, G_VERIFY_OUT, G_VERIFY_ERR, adjust=verify_world, kept_repos=("acme/json", "acme/parser", "acme/pfx"))


def verify_world(d, h1):
    # verify frees every header variable, so a header entry is always a candidate. The finding is on a transitive entry: each json 2.x header needs acme/json 1.0.0
    # (another series, fixed by the package header, not a variable); the list of acme/json has no tag 1.0.0. The newest candidates of parser and pfx are put in the cache.
    main = os.path.join(d, "given/project/u1/main.roc")
    with open(main) as f:
        text = f.read()
    text = "".join(l for l in text.splitlines(keepends=True) if not l.startswith("\tjson1:") and not l.startswith("\tjson3:"))
    write(main, text)
    shutil.rmtree(os.path.join(d, f"given/home/.cache/roc/packages/{h('json3')}"))
    dep = f'package [Lib] {{ old: "https://github.com/acme/json/releases/download/1.0.0/{h1}.tar.zst" }}\n'
    for k in ("7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21", "8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f", "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq", "3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA"):
        write(os.path.join(d, f"given/home/.cache/roc/packages/{k}/main.roc"), dep)
    for k in ("EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc", "u2J5ZhgwXSYn55Ac7xti1xFYVGz78yhBDqfZY2ZtFR6", "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt", "CPn9GfheMVLVbuEhuXk81TvvfeswKFFB4cAYUuvg57p2"):
        write(os.path.join(d, f"given/home/.cache/roc/packages/{k}/main.roc"), "package [Lib] {}\n")
    write(os.path.join(d, "given/home/.cache/roc/packages/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK/main.roc"),
          'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n')


def g_offline():
    # G4 (e11): --offline prints no direct warning (Q623 item 3), also with kept pages.
    cmds = "# R-AU7 R-DI12 (slice 244d, Q623 item 3, mutation gap G4): the world of update/au7-direct-series. Run 1 keeps the pages of acme/json (and prints the json1 line).\n"
    cmds += "update json --no-check --dry-run --file u1/main.roc\n"
    cmds += "# Run 2: --offline reads the kept pages: no request, no audit line (the R-DI15 warning and the R-C8 note stay).\n"
    cmds += "update json --offline --no-check --dry-run --file u1/main.roc\n"
    au7_direct_series("update/au7-direct-offline", "R-AU7 R-DI12 (slice 244d, Q623 item 3, mutation gap G4): --offline prints no direct audit warning. See fx/commands.\n", cmds, G_OFFLINE_OUT, G_OFFLINE_ERR, mtimes="acme/json/1.meta 1792065590\n")


def g_archive_status(name, job_tail, project, out, err, rules, note):
    # G2 (e6): only a 404 makes a leaf (Q623 item 1). The world of ad12, another failure of the download.
    entries = [("pf", "pf", True), ("json", "json", False)]
    lists = {
        "acme/pfx": gh_page([gh_release("acme/pfx", "0.1.0", [h("pf") + ".tar.zst"])]),
        "acme/json": gh_page([gh_release("acme/json", "2.1.0", [h("json2") + ".tar.zst"])]),
    }
    routes = {list_route(r): text for r, text in lists.items()}
    cmds = note + f"audit --file {project}/main.roc\n"
    make(name, rules, project, {f"{project}/main.roc": header(entries)}, ["pf"], {}, [], [], cmds, out, err, None, "(guess: baked from the real run)\n",
         direct=True, routes=routes, kept={}, jobs=f"{h('json')}.tar.zst\t{job_tail}\n")


def g_ls():
    # G1 (e3): only tln audit makes a leaf. tln why walks the closure too: a 404 of a header archive stops it (exit 15), no note.
    entries = [("pf", "pf", True), ("json", "json", False)]
    cmds = "# Q623 R-FE6 R-FE10 (slice 244d, mutation gap G1): TALON_REGISTRY=direct, the project of ad12 (json not in the cache, its download answers 404). tln why walks the closure:\n"
    cmds += "# the 404 stops it with exit 15 and the text of today (no state: Run tln audit). No leaf, no not-checked note: only tln audit makes a leaf.\n"
    cmds += "why json --file q3/main.roc\n"
    make("ad16-why-404", "Q623 R-FE6 R-FE10 (slice 244d, mutation gap G1): only tln audit makes a leaf. See fx/commands.", "q3", {"q3/main.roc": header(entries)}, ["pf"], {}, [], [], cmds,
         G_WHY_OUT, G_WHY_ERR, None, "(guess: baked from the real run)\n", direct=True, routes={}, kept={}, jobs=gone_job("json"))


def g_cases():
    g_verify()
    g_offline()
    url_json = u("json")
    g_archive_status("ad14-archive-500", "22\t-\tcurl: (22) The requested URL returned error: 500\t-", "q3",
                     "== audit --file q3/main.roc\nexit 15\n", f"tln: error[network]: download of acme/json 2.1.0 failed: 500 ({url_json}). Run tln audit to see why.\n",
                     "Q623 R-FE6 R-FE10 (slice 244d, Q-244d-1, mutation gap G2): a download 500 is no leaf. See fx/commands.",
                     "# Q623 item 1 (Q-244d-1, mutation gap G2): the world of ad12, but the download of json answers 500. Not a leaf: exit 15, the text of today, no note.\n")
    g_archive_status("ad15-archive-net", "6\t-\tcurl: (6) Could not resolve host: github.com\t-", "q3",
                     "== audit --file q3/main.roc\nexit 15\n", f"tln: error[network]: download of acme/json 2.1.0 failed: curl: (6) Could not resolve host: github.com ({url_json})\n",
                     "Q623 R-FE6 R-DA7 (slice 244d, Q-244d-1, mutation gap G2): a transport error of a download is no leaf. See fx/commands.",
                     "# Q623 item 1 (Q-244d-1, mutation gap G2): the world of ad12, but the download of json fails with a transport error (curl exit 6). Not a leaf: exit 15, no note.\n")
    g_ls()


G_VERIFY_OUT = '== verify --no-check --file u1/main.roc\nnote: platform changes: acme/pfx 0.1.0 -> acme/pfx 0.1.1\ncheck: skipped\n$PROJECT/u1/main.roc\n  ~ json: acme/json 2.0.0 -> 2.1.0\n  ~ parser: acme/parser 1.0.0 -> 1.2.0\n  ~ pf: acme/pfx 0.1.0 -> 0.1.1\nverified: the tuple passes. No project file was written.\nexit 0\n'
# The real run, with the head of the line as resolve_line gives it (`old via json`; the run of 2026-11-13 printed an empty edge: a code bug).
G_VERIFY_ERR = 'warning: acme/json has 2 series in the closure: 2 via json, 1 via json. The types of the 2 series are different types.\nwarning: old via json: acme/json 1.0.0 has a deleted release. Fix: tln update json (tln why acme/json@1), or use [overrides].\n'
G_OFFLINE_OUT = '== update json --no-check --dry-run --file u1/main.roc\ncheck: skipped\n$PROJECT/u1/main.roc\n  ~ json: acme/json 2.0.0 -> 2.1.0\nresolved at 2026-10-15T12:00:00Z, 0 probes\ndry run: nothing was written\nexit 0\n== update json --offline --no-check --dry-run --file u1/main.roc\ncheck: skipped\n$PROJECT/u1/main.roc\n  ~ json: acme/json 2.0.0 -> 2.1.0\nresolved at 2026-10-15T12:00:00Z, 0 probes\ndry run: nothing was written\nexit 0\n'
G_OFFLINE_ERR = 'warning: acme/json 3.0.0: the release has the hash CN1mAUVH23GpH5gUcJWbD3aTrsc2KMeGEEmHa7n8qju3, but Talon knows https://github.com/acme/json/releases/download/3.0.0/6hQqfPCHRKKyu51zWmUVkrvjg1isMDorbhCfd42F4atP.tar.zst with the hash 6hQqfPCHRKKyu51zWmUVkrvjg1isMDorbhCfd42F4atP. It is not a candidate.\nwarning: acme/json has 3 series in the closure: 2 via json, 1 via json1, 3 via json3. The types of the 3 series are different types.\nwarning: json1: acme/json 1.0.0 has a deleted release. Fix: tln update json1.\nwarning: acme/json 3.0.0: the release has the hash CN1mAUVH23GpH5gUcJWbD3aTrsc2KMeGEEmHa7n8qju3, but Talon knows https://github.com/acme/json/releases/download/3.0.0/6hQqfPCHRKKyu51zWmUVkrvjg1isMDorbhCfd42F4atP.tar.zst with the hash 6hQqfPCHRKKyu51zWmUVkrvjg1isMDorbhCfd42F4atP. It is not a candidate.\nindex: cached at 2026-10-15T11:59:50Z\nwarning: acme/json has 3 series in the closure: 2 via json, 1 via json1, 3 via json3. The types of the 3 series are different types.\n'
G_WHY_OUT = '== why json --file q3/main.roc\nexit 15\n'
G_WHY_ERR = 'tln: error[network]: download of acme/json 2.1.0 failed: 404 (https://github.com/acme/json/releases/download/2.1.0/532HKEYYDQqzMZhSYLoLRNM98SZvHgQMP3BfwzuyRoMV.tar.zst). Run tln audit to see why.\n'


def au7_transitive():
    # Slice 244d verify/au7-direct bug, registry path (Q622 R-AU7 text): json 2.0.0 (header) needs util (someone/roc-util 0.3.0, alias util in the record of json).
    # The answer has the release row of util with withdrawn "deleted": one line with the head `util via json`.
    hu = h("util")
    uu = u("util")
    def change(ans):
        for a in ans["artifacts"]:
            if a["hash"] == H_JSON:
                a["deps"] = [{"alias": "util", "hash": hu, "is_platform": False, "group": form("someone/roc-util"), "series": "0.3", "version": "0.3.0", "url": uu}]
        ans["artifacts"].append({"hash": hu, "kind": "package", "exposed": [], "platform_hash": None, "roc_pin": None, "size": 1000, "deps": [], "target_names": []})
        ans["artifacts"].sort(key=lambda a: a["hash"])
        ans["releases"].append({"log_index": 30, "hash": hu, "group": form("someone/roc-util"), "series": "0.3", "version": "0.3.0", "url": uu, "tag": "0.3.0", "roc_version": None,
                                "repo": "someone/roc-util", "published_at": 1782907200000, "yanked": False, "yank_reason": None, "withdrawn": "deleted", "provenance": ["webhook"]})
        ans["repos"].append({"name": "someone/roc-util", "state": "active", "successor": None, "state_at": 1700000000000})
        ans["repos"].sort(key=lambda r: r["name"])
    cmds = "# R-AU7 R-AU8 (slice 244c/244d, Q622): tln install with a registry (u1 of registry/di1-install-no-free). The record of json 2.0.0 needs util (someone/roc-util 0.3.0); its release is withdrawn (deleted).\n"
    cmds += "# One line for the transitive entry, with the head `<edge> via <aliases>`: util via json. No extra request, exit 0.\n"
    cmds += "install --no-check --dry-run --file u1/main.roc\n"
    line = "warning: util via json: someone/roc-util 0.3.0 has a deleted release. Fix: tln update json (tln why someone/roc-util), or use [overrides].\n"
    copy_base("au7-transitive", "R-AU7 R-AU8 (slice 244c/244d, Q622): the head of the line of a transitive entry in a resolve with a registry. See fx/commands.", cmds, change,
              "== install --no-check --dry-run --file u1/main.roc\nnothing to change\ndry run: nothing was written\nexit 0\n", line, run_calls(True, True))


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
    au7_install()
    fe10_install_404()
    au7_no_finding()
    au7_ignore()
    au7_held_move()
    au7_direct_series()
    ad12_archive_gone()
    ad13_guard_gone()
    au7_frozen()
    au7_direct_held_move()
    g_cases()
    au7_transitive()
    shutil.rmtree(os.path.join(ROOT, ".tmp/mk-audit"), ignore_errors=True)
