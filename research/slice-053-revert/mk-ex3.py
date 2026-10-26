#!/usr/bin/env python3
"""Makes the given/ files of the L3 case tests/scenarios/exit/ex3-no-tuple-yaml (slice 053). Run by hand: python3 -I research/slice-053-revert/mk-ex3.py

The world of the design example of Resolution 5 (TW16): an app that uses basic-cli 0.25.0 and roc-parser 2.0.0 and imports parser.Yaml.
The data is real: the 22 nightlies and the results of `roc check` of conformance/compat-sweep (run 2026-10-13), and the real package headers
from the cache of this machine (the dir PKGS below, a copy of ~/.cache/roc/packages of a run of `tln upgrade`). The module files are stubs that hold only the import lines.
It writes: given/facts.tsv (the rows for talon/compat.db, read by the cmd), given/http/ (the nightly list, the 2 release lists), given/home/.cache/roc/packages/,
given/project/, given/env, given/version.stdout, given/roc.tsv and the check answers.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CASE = os.path.join(ROOT, "tests/scenarios/exit/ex3-no-tuple-yaml")
SWEEP = os.path.join(ROOT, "conformance/compat-sweep")
PKGS = os.environ.get("PKGS", os.path.expanduser("~/.cache/roc/packages"))

PARSER = "7CLzCK6qUz7zmj6nvBxMEFu11HPwQTnCovKiyWzDSLTW"  # roc-parser 2.0.0
PF25 = "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"  # basic-cli 0.25.0
PF24 = "AEjfyaMFFbh8FJrkkHJy68riVNPr3Qp6c6PawWQjBwMH"  # basic-cli 0.24.0
UNICODE = "4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w"
HTTP = "6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS"
HELD = "nightly-2026-09-30-4c37850"


def put(rel, text):
    p = os.path.join(CASE, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write(text)


tags = [t.strip() for t in open(os.path.join(SWEEP, "tags.txt")) if t.strip()]
# facts: the three hashes on the 22 nightlies. A parser fail names the module Yaml.roc (the unit fails in Yaml, R-UM1). A basic-cli fail names no module (a hard fail).
rows = []
for line in open(os.path.join(SWEEP, "results.tsv")):
    nightly, h, out = line.rstrip("\n").split("\t")[:3]
    if h in (PARSER, PF25, PF24):
        assert out in ("pass", "fail"), (nightly, h, out)
        mods = "Yaml.roc" if (h == PARSER and out == "fail") else ""
        rows.append("\t".join([h, nightly, "any", out, mods, ""]))
assert len(rows) == 66, len(rows)
put("given/facts.tsv", "\n".join(rows) + "\n")

# the nightly list (fake HTTP, tests/tools/mk-nightly.sh), newest first as GitHub gives it
subprocess.check_call(["sh", os.path.join(ROOT, "tests/tools/mk-nightly.sh"), os.path.join(CASE, "given/http")] + list(reversed(tags)), env=dict(os.environ, ARCHIVE="probe"))


def release(tag, name, owner_repo, date):
    return {"tag_name": tag, "draft": False, "prerelease": False, "published_at": date, "assets": [
        {"name": name + ".tar.zst", "size": 1000,
         "browser_download_url": "https://github.com/%s/releases/download/%s/%s.tar.zst" % (owner_repo, tag, name)}]}


def routes(owner_repo, rels):
    put("given/http/api/repos/%s/releases?per_page=100" % owner_repo, json.dumps(rels, indent=1) + "\n")


routes("roc-lang/basic-cli", [release("0.25.0", PF25, "roc-lang/basic-cli", "2026-10-09T20:02:05Z"), release("0.24.0", PF24, "roc-lang/basic-cli", "2026-10-05T07:08:18Z")])
routes("lukewilliamboswell/roc-parser", [release("2.0.0", PARSER, "lukewilliamboswell/roc-parser", "2026-10-05T12:00:00Z")])

# the packages of the cache: the real headers, stub modules
for h in (PARSER, PF25, PF24, UNICODE, HTTP):
    put("given/home/.cache/roc/packages/%s/main.roc" % h, open(os.path.join(PKGS, h, "main.roc")).read())
for m, imports in (("Parser", ""), ("Utf8", "import Parser\n"), ("Yaml", "import Parser exposing [Parser]\nimport Utf8\n")):
    put("given/home/.cache/roc/packages/%s/%s.roc" % (PARSER, m), imports + "\nmodule []\n")
for h in (PF25, PF24):
    put("given/home/.cache/roc/packages/%s/Stdout.roc" % h, "module []\n")

PFURL = "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/%s.tar.zst" % PF25
PAURL = "https://github.com/lukewilliamboswell/roc-parser/releases/download/2.0.0/%s.tar.zst" % PARSER
put("given/project/main.roc", 'app [main!] { pf: platform "%s", parser: "%s", roc: "%s" }\n\nimport pf.Stdout\nimport parser.Yaml\n\nmain! = |_args| Ok({})\n' % (PFURL, PAURL, HELD))
put("given/project/talon.toml", '[dependencies]\nparser = "=2.0.0"\npf = "0.25.*"\n')
put("given/env", "TALON_NOW=2026-10-22T12:00:00Z\n")
put("given/version.stdout", "Roc compiler version %s\n" % HELD)
# given/pass.stdout and given/build-pass.stdout are copies of the files of tests/scenarios/update/up2-unit-flags/given/
put("given/roc.tsv", "version\t0\tversion.stdout\t-\ncheck *\t0\tpass.stdout\t-\nbuild *\t0\tbuild-pass.stdout\t-\n")
print("ok", len(rows), "facts")
