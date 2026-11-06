#!/usr/bin/env python3
"""Slice 209b: the given and fx files of the new L2 cases (not the expect files).
  registry/sm6-bot-fail         R-SM6, R-LD5, R-EF3: `verify`: a `bot` smoke `fail` of (pf 0.1.1, H, x64musl) is a fail of step 3 with no build probe
  registry/sm6-bot-fail-update  R-SM6, R-LD5, R-AL6, R-PH10: `update json`: the same row for the held pf 0.1.0 drops the tuple (`note: tuple dropped`), no build probe
  registry/sm6-pass-builds      R-SM6, R-BS1: a `bot` smoke `pass` is not a pass of step 3: the build runs, and its fail stops the command
  registry/sm6-interval         R-SM6, R-EP7, R-UM1, Q557: `upgrade roc`: smoke fails on 3 compilers: one drop at step 3, the other compilers are skipped by the learned interval (no step 3)
  registry/sm6-local-pass       R-SM6, R-EF3, R-P4, R-BS1, Q559: a local build `pass` of the key (another digest) wins over the smoke `fail`: step 3 runs
  registry/sm6-other-target     R-SM6, R-TG2: a `bot` smoke `fail` of another target, and one of the target on another compiler, are not used: the build runs and passes
Run from the repo root: python3 -I research/slice-209b-revert/mkcases.py [<case name> ...]
It DELETES the dirs of these cases (expect/ and rules too): keep a copy before a run. The expect files are made by hand (see the slice file)."""
import json, os, shutil, sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "127.0.0.1%3A9"
ONLY = sys.argv[1:]

N10_12 = "nightly-2026-10-12-2664a27"
N10_13 = "nightly-2026-10-13-5e6f7a8"
H = "nightly-2026-10-14-38a3029"
N = "nightly-2026-10-16-5e6f7a8"
JSON0 = "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21"   # json 2.0.0 (header)
JSON22 = "3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA"  # json 2.2.0
PARSER0 = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc"  # parser 1.0.0 (header)
PF0 = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"    # pfx 0.1.0 (header)
PF1 = "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK"    # pfx 0.1.1


def want(name): return not ONLY or name in ONLY


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def fresh(name, src):
    d = os.path.join(CASES, name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    for part in ("entry", "fx", "given"):
        p = os.path.join(src, part)
        if os.path.isdir(p): shutil.copytree(p, os.path.join(d, part))
        else: shutil.copy(p, os.path.join(d, part))
    return d


def run(hash_, source, result, frm, to, digest=None, target="any"):
    return {"hash": hash_, "target": target, "source": source, "result": result, "error_digest": digest, "from": frm, "to": to}


def answer(d, base, extra):
    p = os.path.join(d, "fx/http", HOST, "v1", "closure.POST")
    a = json.load(open(p))
    assert a["runs"] == base, a["runs"]  # the base case has these rows only
    a["runs"] = list(base) + list(extra)
    write(p, json.dumps(a, separators=(",", ":")))


def rules(d, text): write(os.path.join(d, "rules"), text)


FREE = os.path.join(CASES, "ef1-rank2-free")
VERIFY = os.path.join(CASES, "ef1-rank2-verify")
LADDER = os.path.join(CASES, "ef1-rank2-ladder")
SMOKE_FAIL = "undefined symbol: roc_alloc"

# the base answers (before the smoke rows): the `bot` `pass` of ef1-rank2-verify and ef1-rank2-ladder
BASE_VERIFY = [run(JSON22, "bot", "pass", N10_12, N)]
BASE_LADDER = [run(h, "bot", "pass", H, H) for h in (JSON22, PARSER0, PF0)]

if want("sm6-bot-fail"):
    d = fresh("sm6-bot-fail", VERIFY)
    answer(d, BASE_VERIFY, [run(PF1, "bot", "fail", N10_12, N, SMOKE_FAIL, "x64musl")])
    rules(d, f"""R-SM6 R-LD5 R-LD6 R-EF3 R-TG2 R-E1 (slice 209b): `tln verify` with the world of registry/ef1-rank2-verify (held H = {H}; the tuple json 2.2.0, parser 1.2.0, pf 0.1.1; the build target is the host target x64musl: the header of pf 0.1.1 has no `targets` list, so the key target is the host, R-TG1 rule 4, R-TG2).
The answer has one more run: a `bot` smoke `fail` of pf 0.1.1 (target x64musl, error digest `{SMOKE_FAIL}`) from {N10_12} to {N}, so it covers H. The unit rows (target any) are as in ef1-rank2-verify.
Ladder steps 1 and 2 are as in ef1-rank2-verify. Step 3 (R-LD5): the build key is (pf 0.1.1, H, x64musl). The `bot` smoke fail of that key is a fail of step 3 with no build (R-SM6 row 1): no build probe, and no fact is recorded for a build that did not run (R-P4). It is blamed on the platform for that target (R-LD5), so the command stops with kind `no_tuple` (exit 10), and the text names the host target, the platform and the digest of the row.
The calls of step 3 before the decision are those of a build that ran: `platform`, the read of the header of pf 0.1.1, the db query of the build key (`BuildFlow.before!`, as in ef1-rank2-verify): the smoke row is read after the target and the key are known. Today the build runs and passes.
""")

if want("sm6-bot-fail-update"):
    d = fresh("sm6-bot-fail-update", LADDER)
    answer(d, BASE_LADDER, [run(PF0, "bot", "fail", N10_12, N, SMOKE_FAIL, "x64musl")])
    rules(d, f"""R-SM6 R-LD5 R-AL6 R-PH10 R-EF3 R-TG2 R-E1 (slice 209b): `tln update json --dry-run` with the world of registry/ef1-rank2-ladder (held H = {H}; json moves to 2.2.0, the header pf 0.1.0 is not named, so it stays).
The answer has one more run: a `bot` smoke `fail` of pf 0.1.0 (target x64musl, error digest `{SMOKE_FAIL}`) from {N10_12} to {N}. Step 3 of the ladder takes it as a fail of the build with no build probe (R-SM6 row 1), as a fail of the build that ran: `Fail.of_tuple`, so the tuple is dropped (the line `note: tuple dropped: ...`, as `ladder/ld-ladder-flow` p6), the search runs again, and there is no other tuple (pf is not named, so no tuple has another platform): the command stops with the first failure (exit 10). Nothing is written (R-PH10).
The test does not fix how the second search finds that there is no other tuple: see question Q2 of slice 209b (the learned interval of the solver) and the doubts.
""")

if want("sm6-pass-builds"):
    d = fresh("sm6-pass-builds", VERIFY)
    answer(d, BASE_VERIFY, [run(PF1, "bot", "pass", N10_12, N, None, "x64musl")])
    write(os.path.join(d, "fx/probes"), "\n".join([
        "# the unit probes (a check in a dir of packages/) have no row here (FakeJobs). The rows: the baseline, the candidate check, the build",
        "0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr",
        "0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr",
        "1\t../fixtures/check/out/build-target.stdout\t../fixtures/check/out/build-target.stderr",
        ""]))
    rules(d, f"""R-SM6 R-LD5 R-LD6 R-BS1 R-E1 (slice 209b): `tln verify` as sm6-bot-fail, but the smoke row of pf 0.1.1 (target x64musl, from {N10_12} to {N}) is a `bot` `pass`.
R-SM6 row 2: a smoke `pass` is not a pass of step 3: a pass of the smoke app says nothing about the code of the app. The build runs (a build probe), and the fake build fails (`build-target`, as `ladder/bs2-build-skip-verify` run 7), so the command stops with exit 10 and the text of R-LD5 with the title of the real error. The build fact is recorded as for any build that ran (R-P4). A code that took the smoke pass for a pass of step 3 would skip the build and exit 0.
""")

if want("sm6-other-target"):
    d = fresh("sm6-other-target", VERIFY)
    answer(d, BASE_VERIFY, [
        run(PF1, "bot", "fail", N10_12, N, SMOKE_FAIL, "arm64mac"),
        run(PF1, "bot", "fail", N10_12, N10_13, SMOKE_FAIL, "x64musl"),
    ])
    rules(d, f"""R-SM6 R-TG2 R-LD5 (slice 209b): `tln verify` as sm6-bot-fail, but the 2 smoke rows of pf 0.1.1 are not for the key of the build: a `bot` `fail` of the target arm64mac from {N10_12} to {N} (it covers H, but it is another target: R-SM6 row 3, not used by the resolve), and a `bot` `fail` of the target x64musl from {N10_12} to {N10_13} (the right target, but it ends before H: another compiler, another key, R-TG2).
The build runs and passes as in ef1-rank2-verify (exit 0). A code that ignores the target or the compiler of the row fails the step.
""")

if want("sm6-interval"):
    d = fresh("sm6-interval", FREE)
    base = [run(h, "bot", "pass", N, N) for h in (JSON0, PARSER0, PF0)]
    answer(d, base, [run(PF0, "bot", "fail", N10_12, N, SMOKE_FAIL, "x64musl")])
    rules(d, f"""R-SM6 R-EP7 R-UM1 R-LD5 R-AL6 R-PH10 R-EF3 R-TG2 R-E1 (slice 209b, Design Q557): `tln upgrade roc --dry-run` with the world of registry/ef1-rank2-free (H = {H}, N = {N}; the compiler list has {N10_12}, H and N; the header hashes have a `bot` unit `pass` on N). The answer has one more run: a `bot` smoke `fail` of pf 0.1.0 (target x64musl, digest `{SMOKE_FAIL}`) from {N10_12} to {N}: the 3 compilers of the list.
The search picks N. Ladder step 3 on N: the smoke fail of (pf 0.1.0, N, x64musl) drops the tuple with no build (R-SM6 row 1: no build probe, no `.last-use` touch for it, no build fact). The ladder gives the next search a real `Fail` check of the platform release on each compiler of the smoke run (N10_12, H, N): they touch each module and decide alone (Q557), so R-EP7 learns not (pf 0.1.0 and roc in [{N10_12}, N]). The second search has no compiler left: no probe, no ladder, no step 3 for H or {N10_12} (without the learned interval the second search picks H and runs the ladder again). The command stops with the first failure (exit 10). Nothing is written (R-PH10).
Reading of the test: the second search needs no call (its facts are all known), so the log ends with the `delete` of the temp copy of the one ladder run. The downloads of N and the toolchain rows are those of ef1-rank2-free.
""")

if want("sm6-local-pass"):
    d = fresh("sm6-local-pass", VERIFY)
    answer(d, BASE_VERIFY, [run(PF1, "bot", "fail", N10_12, N, SMOKE_FAIL, "x64musl")])
    write(os.path.join(d, "given/home/.cache/roc/talon/compat.tsv"), "format\t1\nfact\t%s\t%s\tx64musl\tpass\t\t%s\n" % (PF1, H, "ab" * 32))
    rules(d, f"""R-SM6 R-EF3 R-P4 R-BS1 R-LD5 (slice 209b, Design Q559): `tln verify` as sm6-bot-fail (a `bot` smoke `fail` of pf 0.1.1, x64musl, from {N10_12} to {N}), but `compat.db` has a local build `pass` (rank 1) of the key (pf 0.1.1, H, x64musl) with the digest {"ab" * 32}, which is not the digest of the used modules of this app.
Q559: the local build `pass` of the same platform, compiler and target wins over the smoke row with any digest: the smoke row is not used for the key. The digest differs, so the build skip does not apply (R-BS1) and step 3 runs the build, which passes (exit 0). The new row (the digest of the app) is a second row of the key (R-BS2). Today the smoke row is not read at all, so this case passes today: it guards the rule for the code step.
""")
