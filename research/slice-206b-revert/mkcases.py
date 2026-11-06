#!/usr/bin/env python3
"""Slice 206b: the given and fx files of tests/commands/cases/registry/al2-update-query (not the expect files)."""
import json, os, sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "tests", "commands", "cases", "registry", "al2-update-query")

def ms(day):  # "2026-08-16" -> ms of 12:00 UTC
    import datetime
    d = datetime.datetime.strptime(day + "T12:00:00", "%Y-%m-%dT%H:%M:%S").replace(tzinfo=datetime.timezone.utc)
    return int(d.timestamp()) * 1000

def g(repo):
    return f"github.com/acme/{repo}/releases/download/{{v}}/"

def url(repo, v, h):
    return f"https://github.com/acme/{repo}/releases/download/{v}/{h}.tar.zst"

# (repo, version, series, hash, log_index, published day, withdrawn, kind)
REL = [
    ("pfx", "0.1.0", "0.1", "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL", 2, "2026-07-01", None, "platform"),
    ("json", "2.0.5", "2", "8FNd42oEnQP2CUSB4YWEqcsHBwCq8z26bL1Xk3PwDQ8f", 20, "2026-09-05", None, "package"),
    ("json", "2.1.0", "2", "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq", 25, "2026-09-25", None, "package"),
    ("pfx", "0.1.1", "0.1", "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK", 33, "2026-09-20", None, "platform"),
    ("parser", "1.2.0", "1", "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt", 35, "2026-10-05", None, "package"),
    ("parser", "1.1.0", "1", "u2J5ZhgwXSYn55Ac7xti1xFYVGz78yhBDqfZY2ZtFR6", 36, "2026-08-26", None, "package"),
    ("parser", "1.3.0", "1", "AJn26sZEXCwpyJNwjCgzYyLBXVC8HdvXhGWVD6bknvkq", 37, "2026-10-06", "prereleased", "package"),
    ("json", "2.2.0", "2", "3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA", 40, "2026-10-14", None, "package"),
    # The header values, indexed late (ingest): above log:30, kept by the keep list (Q403).
    ("parser", "1.0.0", "1", "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc", 42, "2026-07-17", None, "package"),
    ("json", "2.0.0", "2", "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21", 44, "2026-08-16", None, "package"),
]

def answer():
    arts = []
    rels = []
    for (repo, v, s, h, li, day, wd, kind) in REL:
        arts.append({"hash": h, "kind": kind, "exposed": [], "platform_hash": None, "roc_pin": None, "size": 1000, "deps": [],
                     "target_names": ["x64musl"] if kind == "platform" else []})
        rels.append({"log_index": li, "hash": h, "group": g(repo), "series": s, "version": v, "url": url(repo, v, h), "tag": v,
                     "roc_version": None, "repo": f"acme/{repo}", "published_at": ms(day), "yanked": False, "yank_reason": None,
                     "withdrawn": wd, "provenance": ["webhook"]})
    arts.sort(key=lambda a: a["hash"])
    return {"artifacts": arts, "releases": rels, "epochs": [], "runs": [], "nearest": [], "hints": [], "log_size": 50, "unknown": [],
            "checked": [{"name": f"acme/{r}", "checked_at": ms("2026-10-15"), "stale": False} for r in ("json", "parser", "pfx")],
            "repos": [{"name": f"acme/{r}", "state": "active", "successor": None, "state_at": 1700000000000} for r in ("json", "parser", "pfx")]}

META = "status 200\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire-none authorization\n"

def write(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(text)

body = json.dumps(answer(), separators=(",", ":"))
for host in ("127.0.0.1%3A9", "localhost%3A9"):
    write(f"fx/http/{host}/v1/closure.POST", body)
    write(f"fx/http/{host}/v1/closure.POST.meta", META)
# The privacy guard (R-RG4): acme/json and acme/pfx are kept public answers (R-RG5); acme/parser is asked once.
for repo in ("json", "pfx"):
    write(f"given/home/.cache/roc/talon/index/github/acme/{repo}/repo.json", json.dumps({"id": 1, "full_name": f"acme/{repo}", "private": False}, separators=(",", ":")))
write("fx/http/api.github.com/repos/acme/parser/@", json.dumps({"id": 2, "full_name": "acme/parser", "private": False, "fork": False}, separators=(",", ":")))
write("fx/http/api.github.com/repos/acme/parser.meta", "status 200\nheader Content-Type: application/json\n")
write("given/home/.config/talon/config.toml", 'registry = "http://127.0.0.1:9"\n')
write("fx/env", "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n")
write("fx/commands", "\n".join([
    "update --no-check --dry-run --registry direct --file u1/main.roc env:TALON_REGISTRY=http://127.0.0.1:9",
    "update --no-check --dry-run --json --snapshot log:30 --file u1/main.roc",
    "update --no-check --file u1/main.roc env:TALON_REGISTRY=ftp://127.0.0.1:9",
    "update --no-check --registry http://example.org --file u1/main.roc",
    "update --no-check --file u1/main.roc env:TALON_REGISTRY=HTTP://LocalHost:9/",
]) + "\n")

# Case 2 (Design Q437, Q438): registry/al2-update-window. No `roc:` pin and no compiler on PATH; every run has --no-check.
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "tests", "commands", "cases", "registry", "al2-update-window")
for host in ("127.0.0.1%3A9",):
    write(f"fx/http/{host}/v1/closure.POST", body)
    write(f"fx/http/{host}/v1/closure.POST.meta", META)
for repo in ("json", "parser", "pfx"):
    write(f"given/home/.cache/roc/talon/index/github/acme/{repo}/repo.json", json.dumps({"id": 1, "full_name": f"acme/{repo}", "private": False}, separators=(",", ":")))
write("given/home/.config/talon/config.toml", 'registry = "http://127.0.0.1:9"\n')
write("fx/env", "HOME={w}/home\nTALON_NOW=2026-10-15T12:00:00Z\n")
write("fx/gitdirs", ".\n")
write("entry", "commands\n")
src = open(os.path.join(os.path.dirname(__file__), "..", "..", "tests", "commands", "cases", "update", "up1-flow", "given", "project", "u1", "main.roc")).read()
write("given/project/u1/main.roc", "".join(l for l in src.splitlines(keepends=True) if "roc:" not in l))
write("fx/commands", "\n".join([
    "update --no-check --dry-run --file u1/main.roc",
    "update --no-check --dry-run --snapshot 2026-10-01T00:00:00Z --file u1/main.roc",
]) + "\n")
