#!/usr/bin/env python3
"""Makes the given and fx files of the L2 case tests/commands/cases/roc/cv1-pins (slice 030b). Run from the repo root: python3 -I research/slice-030b-revert/mkcase-cv1.py
The list is the list of the case roc/ri1-flow (10 nightlies, 2 targets) with 2 changes: every digest is b5d5... (the sha256 of the fake archive), except 2026-10-12 (2d71...: the download check must fail)."""
import json, os, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CASE = os.path.join(ROOT, "tests/commands/cases/roc/cv1-pins")
RI1 = os.path.join(ROOT, "tests/commands/cases/roc/ri1-flow")
DL3 = os.path.join(ROOT, "tests/commands/cases/consent/dl3-rank4")
GOOD = "b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78"
BAD = "2d711642b726b04401627ca9fbac32f5c8530fb1903cc4db02258717921a4881"
A, B, C = "a" * 64, "b" * 64, "c" * 64

shutil.rmtree(CASE, ignore_errors=True)
for d in ["fx", "given/home/.cache/roc/talon", "given/home2/.cache/roc/talon", "given/home3/.cache/roc/talon"]:
    os.makedirs(os.path.join(CASE, d))

def put(path, text):
    full = os.path.join(CASE, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write(text)

# the list
src = os.path.join(RI1, "fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100")
lines = open(src).read().split("\n")
out = []
for line in lines:
    if line.startswith('{"tag_name"'):
        tail = "," if line.endswith("},") else ""
        rel = json.loads(line.rstrip(","))
        for asset in rel["assets"]:
            asset["digest"] = "sha256:" + (BAD if rel["tag_name"] == "nightly-2026-10-12-2664a27" else GOOD)
        line = json.dumps(rel, separators=(",", ":")) + tail
    out.append(line)
put("fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100", "\n".join(out))
# the acme routes and the packages of the case consent/dl3-rank4
for name in ["pf", "parser", "json"]:
    p = "fx/http/api.github.com/repos/acme/%s/releases?per_page=100" % name
    os.makedirs(os.path.dirname(os.path.join(CASE, p)), exist_ok=True)
    shutil.copy(os.path.join(DL3, p), os.path.join(CASE, p))
for home in ["home", "home2"]:
    shutil.copytree(os.path.join(DL3, "given/home/.cache/roc/packages"), os.path.join(CASE, "given", home, ".cache/roc/packages"))

# recorded sha256 values (R-CV6): 3 tags changed, one is the same
def tsv(rows):
    return "format\t1\n" + "".join("pinned\t%s\tlinux_x86_64\t%s\tgithub-digest\n" % r for r in rows)
rows = [("nightly-2026-10-13-91fa0c2", C), ("nightly-2026-10-14-38a3029", GOOD), ("nightly-2026-10-16-1df370f", B), ("nightly-2026-10-18-5349569", A)]
put("given/home/.cache/roc/talon/compat.tsv", tsv(rows))
put("given/home2/.cache/roc/talon/compat.tsv", tsv([r for r in rows if r[1] != GOOD]))
put("given/home3/.cache/roc/talon/compat.tsv", tsv([rows[0]]))
# an installed compiler whose tag changed (R-CV6: it stays in use)
tid = "nightly-2026-10-18-5349569"
put("given/home/.cache/roc/toolchains/%s/roc" % tid, "fake")
put("given/home/.cache/roc/toolchains/%s/.talon.json" % tid, json.dumps({"format": 1, "id": tid, "url": "http://127.0.0.1:1/dl/" + tid, "sha256": A, "sha256_source": "github-digest", "typed": tid, "compat": None, "installed_at": "2026-10-20T12:00:00Z", "published_at": "2026-10-18T15:00:00Z"}, separators=(",", ":")) + "\n")
# projects
hdr = """app [main!] {
	pf: platform "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst",
	json: "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst",
%s}

main! = |_args| Ok({})
"""
put("given/project/p1/main.roc", hdr % '\troc: "nightly-2026-10-14-38a3029",\n')
put("given/project/p-pin/main.roc", hdr % '\troc: "nightly-2026-10-13-91fa0c2",\n')
put("given/project/p-range/main.roc", hdr % "")
put("given/project/p-range/talon.toml", '[toolchain]\nroc = ">=nightly-2026-10-12-0000000"\n\n[dependencies]\n')
# fx
put("fx/env", "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
put("fx/tty", "stdin=true\nstderr=true\n")
put("fx/answers", "n\n")
put("fx/programs", "curl\nwget\ntar\n")
put("fx/gitdirs", ".\n")
jobs = ["# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod, R-GC10 the compat check (as slice 021). The first rule whose needle is in the arguments answers.",
        "curl --fail\t0\t-\t-\tfile:{out}", "tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details", "chmod 0755\t0\t-\t-\t-"]
for home, tag, short in [("home", "nightly-2026-10-14-38a3029", "38a3029"), ("home", "nightly-2026-10-15-38e6c42", "38e6c42"), ("home", "nightly-2026-10-16-1df370f", "1df370f"),
                         ("home", "nightly-2026-10-17-601b54c", "601b54c"), ("home3", "nightly-2026-10-09-258ab27", "258ab27")]:
    jobs.append("%s.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{w}/%s/.cache/roc/compat-%s" % (tag, home, short))
jobs.append("version\t0\tRoc compiler version nightly-2026-09-01-abcdef0\t-\t-")
put("fx/jobs", "\n".join(jobs) + "\n")

put("entry", "commands\n")
put("fx/db", """# The errors of compat.db, one rule for each call (the number counts db_query and db_write calls over the whole case).
1: busy
2: failed unable to open database file
3: busy
4: busy
16: busy
17: version 2
""")
put("fx/commands", """# R-CC8 R-CV6 (Q2): the first read of compat.db is busy (call 1). The warning says that Talon goes on with no saved facts, nothing is recorded (no db_write), and the install goes on. The list is fetched once (the first run).
roc install nightly-2026-10-15-38e6c42 --yes
# R-CC8 (Q2): the read fails (call 2): the warning names the file and the fix, nothing is recorded, the install goes on.
roc install nightly-2026-10-14-38a3029 --yes
# R-CV6 R-CC8 (Q2): 2026-10-16 has another sha256 in the recorded rows, but the read is busy (call 3): Talon does not know it, and goes on. The sha256 of the download is the listed one, so it passes (the check of R-CV4 is not the check of R-CV6).
roc install nightly-2026-10-16-1df370f --yes
# R-CV4 R-CC8 (Q2): the read is busy (call 4) and the listed digest of 2026-10-12 is not the digest of the download: exit 16 from the download check. The check against the list still runs when compat.db is busy.
roc install nightly-2026-10-12-2664a27 --yes
# R-CV6 R-CV3 R-C7: the read works (calls 5 and 6). The rows 2026-10-18, 2026-10-16 and 2026-10-13 have another recorded sha256: they are no candidates, so @latest is 2026-10-17 (warnings, one for each). 6 new rows are recorded in one write, 2026-10-14 is the same. The list is the cached one: a cached list is recorded too. 2026-10-16 is installed (run 3) but stays in the warnings.
roc install @latest --yes
# R-CV6: an installed compiler whose tag changed stays in use: it is installed, so there is no list read and no db call. Exit 0.
roc install nightly-2026-10-18-5349569 --yes
# R-CV6: `roc default` of that installed compiler works too, with no list read and no db call.
roc default nightly-2026-10-18-5349569
# R-CV6 R-CV1 R-EC16: a command that names a changed tag that is not installed stops with exit 16 and the text of R-CV6. No prompt, no download, no write. The list is the cached one, one db_query (call 7) and no write: no new row.
roc install nightly-2026-10-13-91fa0c2 --yes
# R-CV6 R-SC10: a prefix of exactly one changed tag names it (call 8).
roc install nightly-2026-10-13 --yes
# R-CV6: `roc default` names the tag (call 9).
roc default nightly-2026-10-13-91fa0c2
# R-CV6: `roc use` names the tag (call 10): exit 16 before any probe or write.
roc use nightly-2026-10-13-91fa0c2 --file p1/main.roc
# R-CV6 R-SO22 R-DL1: the pin of the project is the changed tag, which is not installed (call 11): the first probe needs it, the offer stops with exit 16. No prompt.
update json --file p-pin/main.roc
# R-CV6 R-SO13 R-C7: rank 4. HOME is home2, which has no compiler. The range of p-range holds 5 releases. The newest, 2026-10-18, and 2026-10-16 and 2026-10-13 are changed (calls 12 and 13: the new rows are recorded; the ladder reads the list a second time for the offer, call 14: no write), so the required download is 2026-10-17. The warnings (once, from the offer), then the prompt (the answer is n: exit 13).
env:HOME={w}/home2 update json --file p-range/main.roc
# R-CC8 R-CV6: HOME is home3, which has one recorded row (2026-10-13, changed). The read works (call 15) and the write of the 9 new rows is busy (call 16): the warning says that the facts are not saved, and the install goes on. The change is known from the read, so the warning for 2026-10-13 is printed too.
env:HOME={w}/home3 roc install nightly-2026-10-09-258ab27 --yes
# R-TF3 R-CV6: a db with a newer format (call 17): exit 19, no list use, no install. The same for each command that reads the list.
env:HOME={w}/home4 roc install @latest --yes
# R-CV6 R-SC10: HOME is home2 (the list is cached, call 18 reads the rows: nothing new). The text names no compiler and no changed tag (2030 is a prefix of no tag): the failure is the usual one (exit 2), and the warnings of the 3 changes come before it.
env:HOME={w}/home2 roc install nightly-2030 --yes
""")
put("rules", """R-CV6 R-CV3 R-CV1 R-CV4 R-CC8 R-TF3 R-EC16 R-EC19 R-SC10 R-C7 R-SO13 R-SO22 R-DL1 (slice 030b): the first sha256 of each compiler asset in compat.db, with the fake Fx. Every list that `Nightlies.list!` reads (live or cached) records the sha256 of the asset of the host for each release, in one read and at most one write. A tag with another recorded sha256 is no candidate (@latest, ranges, names). A command that names the tag stops with exit 16 (`roc install`, `roc default`, `roc use`, the pin of a project). An installed compiler with that tag stays in use. A busy or failed db: the warning of R-CC8, nothing is recorded, the command goes on. The command is `Run.run!` for each line of `fx/commands` (entry `commands`). The comment above each line says what it shows. `fx/db` has the errors of compat.db (the call number counts db_query and db_write over the case). `given/home*/.cache/roc/talon/compat.tsv` has the recorded rows.
Run 1 to 4: a busy read (call 1), a failed read (call 2), a busy read for a tag that changed (call 3: it goes on and installs), a busy read and a download with a wrong listed digest (call 4: exit 16 from R-CV4). Run 5: the read works: 3 changed tags are dropped, @latest is 2026-10-17, 6 new rows in one write (a cached list). Run 6 and 7: an installed compiler with a changed tag: no list, no db call. Run 8 to 12: the tag is named (the id, a prefix, `roc default`, `roc use`, a project pin): exit 16. Run 13 (home2): rank 4 gives the newest unchanged release in the range. Run 14 (home3): a busy write: the warning, the install goes on. Run 15 (home4): a newer format: exit 19. Run 16 (home2): no changed tag is named: the warnings, then the usual failure (exit 2). Run 17 (home5): a cached list (`--offline`) is recorded too: calls 19 and 20.
The tree diff covers the dirs `home` and `project` only, so the effects in home2 to home4 are in `calls.log`.
""")

# home5: a cached list and no compat.db: `--offline` reads the cached list (source Cached) and records it (R-CV3: a list from either source, live or cached)
put("given/home5/.cache/roc/talon/index/github/roc-lang/nightlies/1.json", open(os.path.join(CASE, "fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100")).read())
put("given/home5/.cache/roc/talon/index/github/roc-lang/nightlies/1.meta", "")
open(os.path.join(CASE, "fx/commands"), "a").write("""# R-CV3 R-CV6 R-DI12: HOME is home5, which has a cached list and no compat.db. --offline reads the cached list, and a cached list is recorded too (calls 19 and 20: all 10 rows are new). The compiler is not installed and --offline is set: exit 15.
env:HOME={w}/home5 roc install nightly-2026-10-14-38a3029 --offline
""")

# Review Q1: an installed compiler with a changed tag stays the base of a relative step (R-C9), and the step never lands on a changed tag
open(os.path.join(CASE, "fx/commands"), "a").write("""# R-CV6 R-C9 R-SL7 (review of slice 030b, Q1): HOME is home. The default is 2026-10-18 (run 7), installed, with a changed tag: it stays the base of a step (call 21: the list is the cached one, no write). @-2 is 2026-10-15, not 2026-10-16: that tag changed too, so the step does not land on it. 2026-10-15 is installed. Exit 0.
roc install @-2 --yes
""")
s = open(os.path.join(CASE, "rules")).read().replace("Run 17 (home5): a cached list (`--offline`) is recorded too: calls 19 and 20.", "Run 17 (home5): a cached list (`--offline`) is recorded too: calls 19 and 20. Run 18 (review Q1): an installed changed tag is the base of `@-2`, and the step skips the changed tag 2026-10-16.")
open(os.path.join(CASE, "rules"), "w").write(s)
