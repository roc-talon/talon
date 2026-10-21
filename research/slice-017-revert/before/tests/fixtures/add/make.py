#!/usr/bin/env python3
"""Makes the fixtures of the slice 007, 009 and 010 cases (docs/slices/007-commands-that-write.md, 009-update-verify.md, 010-closure-list.md).

Usage: python3 -I tests/fixtures/add/make.py            (from the repo root)

For each case it writes, from the table CASES below:
  <case>/given/home/.cache/roc/packages/<hash>/main.roc   the packages (the header URLs keep github.com, so nothing is fetched, R-EV24)
  the release pages of the fake GitHub API: L3 `given/http/api/repos/<owner>/<repo>/releases?per_page=100`,
  L2 `fx/http/api.github.com/repos/<owner>/<repo>/releases?per_page=100`
Slice 010: a package can have dependencies (DEPS: the header of its `main.roc` names them). A case can have these options (the 3rd value of CASES):
  skip     (repo, version) pairs that are not written to the cache (a package that the closure never needs)
  fetched  (repo, version) pairs that are not in the cache but are made by a fake download of the L2 case: the text of their `main.roc` is `fx/pkgs/<owner>_<repo>_<version>.roc`
  pages    False: no release pages. A list of repos: pages for these repos only. Default: pages for all repos of the case.
The cases hold the rest by hand (cmd, given/project, expect). A hash is the base58 text of 32 bytes: the 12 hashes of the slice 005 fixtures are kept, a new one is the
sha256 of its name, so a run of this script gives the same files again.
"""
import hashlib, json, os, sys

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58(data):
    n = int.from_bytes(data, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = ALPHABET[r] + out
    return "1" * (len(data) - len(data.lstrip(b"\0"))) + out

OLD = {  # the fixtures of the slice 005 cases
    ("acme/pf", "0.1.0"): "895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw",
    ("acme/pf", "0.2.0"): "GqCT1gibKhSDVNtziTGJcyq93kHA8SmamjrYH6si2ZQG",
    ("acme/json", "2.0.0"): "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21",
    ("acme/json", "2.0.5"): "8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f",
    ("acme/json", "2.1.0"): "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq",
    ("acme/json", "2.2.0"): "3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA",
    ("acme/parser", "1.0.0"): "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc",
    ("acme/parser", "1.1.0"): "u2J5ZhgwXSYn55Ac7xti1xFYVGz78yhBDqfZY2ZtFR6",
    ("acme/parser", "1.2.0"): "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt",
    ("acme/parser", "1.3.0"): "AJn26sZEXCwpyJNwjCgzYyLBXVC8HdvXhGWVD6bknvkq",
    ("acme/parser", "1.4.0"): "CPn9GfheMVLVbuEhuXk81TvvfeswKFFB4cAYUuvg57p2",
}

def h(repo, ver):
    if (repo, ver) in OLD:
        return OLD[(repo, ver)]
    return b58(hashlib.sha256(f"talon-add-fixture/{repo}/{ver}".encode()).digest())

PLATFORMS = ("acme/pf", "acme/pf2", "acme/pfx", "roc-lang/basic-webserver")

def url(repo, ver):
    return f"https://github.com/{repo}/releases/download/{ver}/{h(repo, ver)}.tar.zst"

def body(repo, ver):
    deps = DEPS.get((repo, ver), [])
    entries = "".join(f'\t{alias}: "{url(r, v)}",\n' for alias, r, v in deps)
    record = "{" + ("\n" + entries if deps else "") + "}"
    if repo in PLATFORMS:
        return f'platform "acme"\n\trequires {{}} {{ main! : () => {{}} }}\n\texposes [Std]\n\tpackages {record}\n\tprovides [main_for_host!]\n'
    return f"package [Lib] {record}\n"

# repo -> [(version, published_at, draft, prerelease)]
REPOS = {
    "acme/pf": [("0.1.0", "2026-07-01", 0, 0), ("0.2.0", "2026-09-20", 0, 0)],
    "acme/pf2": [("1.0.0", "2026-09-01", 0, 0)],
    "acme/pfx": [("0.1.0", "2026-07-01", 0, 0), ("0.1.1", "2026-09-20", 0, 0)],
    "acme/json": [("2.0.0", "2026-08-16", 0, 0), ("2.0.5", "2026-09-05", 0, 0), ("2.1.0", "2026-09-25", 0, 0), ("2.2.0", "2026-10-14", 0, 0)],
    "acme/parser": [("1.0.0", "2026-07-17", 0, 0), ("1.1.0", "2026-08-26", 0, 0), ("1.2.0", "2026-10-05", 0, 0), ("1.3.0", "2026-10-10", 0, 1), ("1.4.0", "2026-10-11", 1, 0)],
    "acme/util": [("1.0.0", "2026-08-01", 0, 0), ("1.1.0", "2026-09-01", 0, 0)],
    "acme/xml": [("1.0.0", "2026-07-10", 0, 0), ("1.1.0", "2026-08-10", 0, 0), ("1.2.0", "2026-09-10", 0, 0), ("2.0.0", "2026-10-01", 0, 0)],
    "acme/lex": [("1.0.0", "2026-07-01", 0, 0), ("1.1.0", "2026-08-20", 0, 0), ("1.2.0", "2026-10-01", 0, 0)],
    "acme/pre": [("1.0.0", "2026-08-15", 0, 0)],
    "acme/9lives": [("1.0.0", "2026-08-15", 0, 0)],
    # slice 010: the closure
    "acme/web": [("1.0.0", "2026-08-01", 0, 0)],
    "acme/mid": [("1.0.0", "2026-08-05", 0, 0)],
    "acme/core": [("1.0.0", "2026-07-20", 0, 0), ("1.1.0", "2026-09-01", 0, 0)],
    "acme/text": [("1.0.0", "2026-07-25", 0, 0), ("1.1.0", "2026-09-05", 0, 0), ("2.0.0", "2026-09-15", 0, 0)],
    # slice 011: the tie of the design example (R-SC14): 2 packages with the repo name basic-webserver in one closure
    "roc-lang/basic-webserver": [("0.1.0", "2026-08-01", 0, 0)],
    "someone/basic-webserver": [("1.0.0", "2026-08-02", 0, 0)],
    "acme/web-utils": [("1.0.0", "2026-08-03", 0, 0)],
}

# (repo, version) -> the entries of its dependency record: (alias, repo, version)
DEPS = {
    ("acme/web", "1.0.0"): [("core", "acme/core", "1.0.0"), ("text", "acme/text", "1.0.0")],
    ("acme/mid", "1.0.0"): [("text", "acme/text", "1.1.0")],
    ("acme/text", "1.0.0"): [("lex", "acme/lex", "1.0.0")],
    ("acme/text", "1.1.0"): [("core", "acme/core", "1.1.0")],
    ("acme/web-utils", "1.0.0"): [("ws", "someone/basic-webserver", "1.0.0")],
}

CASES = {
    "tests/scenarios/add/ad1-add-entries": ("l3", ["acme/pf", "acme/json", "acme/parser", "acme/util", "acme/xml", "acme/lex", "acme/pre", "acme/9lives"]),
    "tests/scenarios/add/ad2-platform-json": ("l3", ["acme/pf", "acme/pf2", "acme/json", "acme/lex", "acme/util"]),
    "tests/scenarios/install/in1-workspace-frozen-rename": ("l3", ["acme/json", "acme/util"]),
    "tests/commands/cases/install/in1-flow": ("l2", ["acme/pf", "acme/json", "acme/lex", "acme/util"]),
    "tests/scenarios/update/up1-update-entries": ("l3", ["acme/pfx", "acme/json", "acme/parser", "acme/lex"]),
    "tests/scenarios/verify/vf1-verify": ("l3", ["acme/pfx", "acme/json", "acme/parser"]),
    "tests/commands/cases/update/up1-flow": ("l2", ["acme/pfx", "acme/json", "acme/parser"]),
    "tests/commands/cases/verify/vf1-flow": ("l2", ["acme/pfx", "acme/json", "acme/parser"]),
    # slice 010: a header with a path entry, a foreign URL and 2 series of acme/text. acme/core 1.0.0 and acme/text 1.0.0 are named by a package and never selected: they are not in the cache.
    "tests/scenarios/list/ls1-list": ("l3", ["acme/pfx", "acme/web", "acme/mid", "acme/core", "acme/text"], {"skip": [("acme/text", "1.0.0")], "pages": False}),
    # slice 010: the 4 gaps that slice 009 moved here (verify and update -i).
    "tests/commands/cases/gaps/g1-slice009": ("l2", ["acme/pfx", "acme/json", "acme/parser"]),
    # slice 010: the closure fetch. These 4 packages are made by the fake download of the case.
    "tests/commands/cases/closure/cl1-flow": ("l2", ["acme/pfx", "acme/web", "acme/mid", "acme/core", "acme/text", "acme/lex"], {"fetched": [("acme/core", "1.0.0"), ("acme/text", "1.0.0"), ("acme/lex", "1.0.0"), ("acme/text", "1.1.0")], "skip": [("acme/lex", "1.1.0"), ("acme/lex", "1.2.0")], "pages": ["acme/pfx", "acme/web", "acme/text"]}),
    # slice 011: `tln why` (the closure of ls1-list, and a project with the tie of the design example). text 1.0.0 is named by a package and never selected.
    "tests/scenarios/why/wy1-why": ("l3", ["acme/pfx", "acme/web", "acme/mid", "acme/core", "acme/text", "roc-lang/basic-webserver", "someone/basic-webserver", "acme/web-utils"], {"skip": [("acme/text", "1.0.0")], "pages": False}),
    # slice 011: R-C2 over the full closure and `why`. Only text 1.1.0 (the second level of the chain mid, text, core) is made by the fake download of the case.
    "tests/commands/cases/closure/cl2-chain": ("l2", ["acme/pfx", "acme/mid", "acme/core", "acme/text"], {"fetched": [("acme/text", "1.1.0")], "skip": [("acme/text", "1.0.0"), ("acme/text", "2.0.0")], "pages": ["acme/pfx", "acme/mid", "acme/core"]}),
}

def page(repo):
    items = []
    for ver, date, draft, pre in REPOS[repo]:
        name = h(repo, ver) + ".tar.zst"
        items.append({
            "tag_name": ver, "draft": bool(draft), "prerelease": bool(pre), "published_at": date + "T12:00:00Z",
            "assets": [{"name": name, "size": 1000, "browser_download_url": f"https://github.com/{repo}/releases/download/{ver}/{name}"}],
        })
    return json.dumps(items, separators=(",", ":"))

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)

def main():
    for case, spec in CASES.items():
        layer, repos = spec[0], spec[1]
        opts = spec[2] if len(spec) > 2 else {}
        skip = set(opts.get("skip", [])) | set(opts.get("fetched", []))
        pages = opts.get("pages", True)
        for repo in repos:
            for ver, _, _, _ in REPOS[repo]:
                if (repo, ver) not in skip:
                    write(f"{case}/given/home/.cache/roc/packages/{h(repo, ver)}/main.roc", body(repo, ver))
            if pages is True or (pages and repo in pages):
                if layer == "l3":
                    write(f"{case}/given/http/api/repos/{repo}/releases?per_page=100", page(repo))
                else:
                    write(f"{case}/fx/http/api.github.com/repos/{repo}/releases?per_page=100", page(repo))
        for repo, ver in opts.get("fetched", []):
            # the fake download copies this file as main.roc: the layout of `roc fmt`, because `scripts/test.sh` checks the format of fx/
            text = body(repo, ver)
            if (repo, ver) in DEPS and repo not in PLATFORMS:
                rows = "".join(f'\t\t{alias}: "{url(r, v)}",\n' for alias, r, v in DEPS[(repo, ver)])
                text = "package\n\t[Lib]\n\t{\n" + rows + "\t}\n"
            write(f"{case}/fx/pkgs/{repo.replace('/', '_')}_{ver}.roc", text)
    with open("tests/fixtures/add/hashes.txt", "w") as f:
        for repo in REPOS:
            for ver, date, draft, pre in REPOS[repo]:
                f.write(f"{repo} {ver} {h(repo, ver)}\n")

main()
