#!/usr/bin/env python3
"""Makes the fixtures of the slice 007 cases (docs/slices/007-commands-that-write.md).

Usage: python3 -I tests/fixtures/add/make.py            (from the repo root)

For each case it writes, from the table CASES below:
  <case>/given/home/.cache/roc/packages/<hash>/main.roc   the packages (the header URLs keep github.com, so nothing is fetched, R-EV24)
  the release pages of the fake GitHub API: L3 `given/http/api/repos/<owner>/<repo>/releases?per_page=100`,
  L2 `fx/http/api.github.com/repos/<owner>/<repo>/releases?per_page=100`
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

PLATFORM = 'platform "acme"\n\trequires {} { main! : () => {} }\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n'
PACKAGE = "package [Lib] {}\n"

# repo -> [(version, published_at, draft, prerelease)]
REPOS = {
    "acme/pf": [("0.1.0", "2026-07-01", 0, 0), ("0.2.0", "2026-09-20", 0, 0)],
    "acme/pf2": [("1.0.0", "2026-09-01", 0, 0)],
    "acme/json": [("2.0.0", "2026-08-16", 0, 0), ("2.0.5", "2026-09-05", 0, 0), ("2.1.0", "2026-09-25", 0, 0), ("2.2.0", "2026-10-14", 0, 0)],
    "acme/parser": [("1.0.0", "2026-07-17", 0, 0), ("1.1.0", "2026-08-26", 0, 0), ("1.2.0", "2026-10-05", 0, 0), ("1.3.0", "2026-10-10", 0, 1), ("1.4.0", "2026-10-11", 1, 0)],
    "acme/util": [("1.0.0", "2026-08-01", 0, 0), ("1.1.0", "2026-09-01", 0, 0)],
    "acme/xml": [("1.0.0", "2026-07-10", 0, 0), ("1.1.0", "2026-08-10", 0, 0), ("1.2.0", "2026-09-10", 0, 0), ("2.0.0", "2026-10-01", 0, 0)],
    "acme/lex": [("1.0.0", "2026-07-01", 0, 0), ("1.1.0", "2026-08-20", 0, 0), ("1.2.0", "2026-10-01", 0, 0)],
    "acme/pre": [("1.0.0", "2026-08-15", 0, 0)],
    "acme/9lives": [("1.0.0", "2026-08-15", 0, 0)],
}

CASES = {
    "tests/scenarios/add/ad1-add-entries": ("l3", ["acme/pf", "acme/json", "acme/parser", "acme/util", "acme/xml", "acme/lex", "acme/pre", "acme/9lives"]),
    "tests/scenarios/add/ad2-platform-json": ("l3", ["acme/pf", "acme/pf2", "acme/json", "acme/lex", "acme/util"]),
    "tests/scenarios/install/in1-workspace-frozen-rename": ("l3", ["acme/json", "acme/util"]),
    "tests/commands/cases/install/in1-flow": ("l2", ["acme/pf", "acme/json", "acme/lex", "acme/util"]),
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
    for case, (layer, repos) in CASES.items():
        for repo in repos:
            for ver, _, _, _ in REPOS[repo]:
                body = PLATFORM if repo in ("acme/pf", "acme/pf2") else PACKAGE
                write(f"{case}/given/home/.cache/roc/packages/{h(repo, ver)}/main.roc", body)
            if layer == "l3":
                write(f"{case}/given/http/api/repos/{repo}/releases?per_page=100", page(repo))
            else:
                write(f"{case}/fx/http/api.github.com/repos/{repo}/releases?per_page=100", page(repo))
    with open("tests/fixtures/add/hashes.txt", "w") as f:
        for repo in REPOS:
            for ver, date, draft, pre in REPOS[repo]:
                f.write(f"{repo} {ver} {h(repo, ver)}\n")

main()
