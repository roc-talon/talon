#!/usr/bin/env python3
"""Slice 206e3b: the given and fx files of the new L2 cases (not the expect files).
  registry/ef1-rank2-verify     R-EF1, R-DI1, P1: `verify`: ladder step 1 uses the rank 2 fact of the answer (no unit probe of a pair that has it)
  registry/ef1-rank2-ladder     R-EF1, R-DI1, P1: `update json`: the pairs that the search did not look up get their rank 2 facts in ladder step 1
  registry/sp24-second-evidence R-SP24, R-EF1, R-EP12, P2: the `runs` of the SECOND answer of a held move are evidence of the second search
  registry/cm7-why-flag         R-CM7, R-DI1, R-FL7, Q499: `why --registry <url>` is accepted (no config.toml)
  registry/ef3-note-verify      R-EF3, Q501: `verify` prints the note for the pairs of the tuple (stdout, data.notes)
  registry/cm7-why-pin-unset    R-CM7, R-DI1, R-WS4, Q521: a member with no pin gets the workspace pin (no difference); with different pins its block shows the selected compiler
  registry/sp24-second-epochs-hints R-SP24, R-AL4, Q522: the `hints` of the SECOND answer order a cut round of the second search
  registry/cm7-why-pins         R-CM7, R-DI1, R-WS4, Q502: `why` in a workspace with 2 `roc:` pins: no `compilers`, each block of its own pin
Run from the repo root: python3 -I research/slice-206e3b-revert/mkcases.py [<case name> ...]
It DELETES the dirs of these cases (expect/ and rules too): keep a copy before a run."""
import json, os, shutil, sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "127.0.0.1%3A9"
ONLY = sys.argv[1:]

N10_12 = "nightly-2026-10-12-2664a27"
N10_13 = "nightly-2026-10-13-5e6f7a8"
H = "nightly-2026-10-14-38a3029"
N = "nightly-2026-10-16-5e6f7a8"
JSON0 = "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21"  # json 2.0.0 (header)
JSON22 = "3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA" # json 2.2.0
PARSER0 = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc" # parser 1.0.0 (header)
PARSER12 = "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt" # parser 1.2.0
PF0 = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"   # pfx 0.1.0 (header)
PF1 = "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK"   # pfx 0.1.1 (cv1-upgrade-free)
PFX11 = "7fhUdr5pButQ8RG6Z9DSquPQiRuBsetQgfCa7AebQj7M"  # pfx 0.1.1 (sp24-update-held-move)


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


def run(hash_, source, result, frm, to, digest=None):
    return {"hash": hash_, "target": "any", "source": source, "result": result, "error_digest": digest, "from": frm, "to": to}


def answer(d, file="closure.POST", runs=(), epochs=(), hints=(), nearest=()):
    p = os.path.join(d, "fx/http", HOST, "v1", file)
    a = json.load(open(p))
    assert a["runs"] == [] and a["epochs"] == [] and a["hints"] == [] and a["nearest"] == []
    a["runs"], a["epochs"], a["hints"], a["nearest"] = list(runs), list(epochs), list(hints), list(nearest)
    write(p, json.dumps(a, separators=(",", ":")))


def rules(d, text): write(os.path.join(d, "rules"), text)


FREE = os.path.join(CASES, "cv1-upgrade-free")
HELD = os.path.join(CASES, "cv1-held-offer")
SP24 = os.path.join(CASES, "sp24-update-held-move")
CM7 = os.path.join(CASES, "cm7-why-registry")

if want("ef1-rank2-verify"):
    d = fresh("ef1-rank2-verify", FREE)
    write(os.path.join(d, "fx/commands"), "verify --file u1/main.roc\n")
    answer(d, runs=[run(JSON22, "bot", "pass", N10_12, N)])
    rules(d, f"""R-EF1 R-EP12 R-DI1 R-CM11 R-LD2 (slice 206e3b, plan note P1 of 206e3): `tln verify` with the world of registry/ef1-rank2-held (held H = {H}; the tuple json 2.2.0, parser 1.2.0, pf 0.1.1; the answer has a `bot` `pass` of json 2.2.0 from {N10_12} to {N}), with the check (no --no-check).
The search is the one of `update` (round 1: json has its rank 2 fact, only parser and pf get a unit probe, `probes 2`). Ladder step 1 (R-LD2) then reads the facts of the tuple on H. The rank 2 fact is a fact of the same answer (R-DI1: "the evidence ... come[s] from one answer"), so ladder step 1 has the pass of json 2.2.0 and starts no unit probe for it: round 1 of the ladder has only the baseline check.
Reading of the test (the same as `update`, ef1-rank2-held): `verify` hands the facts of the search to the ladder, so the ladder asks the db for no key that the search looked up. Today the ladder asks for the 3 keys (`db_query facts=3`) and probes json 2.2.0 again (a third unit probe).
""")

if want("ef1-rank2-ladder"):
    d = fresh("ef1-rank2-ladder", FREE)
    write(os.path.join(d, "fx/commands"), "update json --dry-run --file u1/main.roc\n")
    answer(d, runs=[run(h, "bot", "pass", H, H) for h in (JSON22, PARSER0, PF0)])
    rules(d, f"""R-EF1 R-EP12 R-DI1 R-LD2 R-AL4 (slice 206e3b, plan note P1 of 206e3): `tln update json` with the world of registry/cv1-upgrade-free (held H = {H}). Only json is named, so parser 1.0.0 and pf 0.1.0 keep their header value and the search does not look up their pairs; ladder step 1 does (the closure of the candidate has the 3 hashes).
The answer has a `bot` `pass` on H of json 2.2.0, parser 1.0.0 and pf 0.1.0. The pass of json 2.2.0 is read by the search (round 1 of 206e3). The passes of parser 1.0.0 and pf 0.1.0 are read by ladder step 1: it asks the db for the 2 keys that the search did not look up (`db_query facts=2`), then takes their rank 2 facts after the db rows (R-EF3: rank 1 wins), so the ladder starts no unit probe: round 1 has only the baseline check.
Today the ladder has only the db rows, so it probes parser 1.0.0 and pf 0.1.0.
""")

if want("sp24-second-evidence"):
    d = fresh("sp24-second-evidence", SP24)
    write(os.path.join(d, "fx/commands"), "update yaml@1.1.0 --dry-run --file u1/main.roc\n")
    for n in range(3, 9):
        for suffix in ("", ".meta"):
            p = os.path.join(d, "fx/http", HOST, "v1", f"closure.POST.{n}{suffix}")
            if os.path.exists(p): os.remove(p)
    shutil.rmtree(os.path.join(d, "given/project/u2"))
    # the unit probes need the package dirs (a probe in a dir that is not in the tree is NotStarted, FakeFx `units`): copies of the dirs of registry/ef1-rank2-held
    pk = "given/home/.cache/roc/packages"
    for src, dst in (("9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK", PFX11), ("EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt", "HpZmFVX91J55hZj16ga8KSE5cu3zqbmNWCUVsfTPtgnF")):
        write(os.path.join(d, pk, dst, "main.roc"), open(os.path.join(FREE, pk, src, "main.roc")).read())
    answer(d, file="closure.POST.2", runs=[run(PFX11, "bot", "pass", H, H)])
    rules(d, f"""R-SP24 R-SP16 R-EF1 R-EP12 R-AP16 R-DI1 (slice 206e3b, plan note P2 of 206e3): run 1 of registry/sp24-update-held-move (`update yaml@1.1.0`: the first search has no tuple, the second query holds json and pfx; pf moves to 0.1.1), with the check (no --no-check) and one change: the SECOND answer has a `bot` `pass` run of pfx 0.1.1 ({PFX11}) on H = {H}.
The runs of the second answer are evidence of the second search, as the runs of the first answer (R-SP24: "a second answer ... the evidence of the command is still one set"; R-EF1 rank 2). So the pair (pfx 0.1.1, H) has a real fact and the search starts no unit probe for it; yaml 1.1.0 and json 2.0.0 are probed. Today the second search reads the `runs` of the first answer only (`second_index!` merges `releases` and `artifacts` only), so it probes pfx 0.1.1 too.
""")

if want("cm7-why-flag"):
    d = fresh("cm7-why-flag", CM7)
    os.remove(os.path.join(d, "given/home/.config/talon/config.toml"))
    write(os.path.join(d, "fx/commands"), "why json --registry http://127.0.0.1:9 --file u1/main.roc\n")
    rules(d, f"""R-CM7 R-DI1 R-FL7 R-RG2 Q499 (slice 206e3b): run 1 of registry/cm7-why-registry with the registry from the flag `--registry http://127.0.0.1:9` and no `config.toml`. Q499: `why --registry <url>` is accepted, as the registry is the source of the index, not a resolve flag (R-FL7). Today `Opts.reads_registry` refuses it (`no registry exists in this version of tln`, exit 2).
The output and the calls are those of run 1 of cm7-why-registry: the guard, one POST /v1/closure (no `groups`, the 3 header hashes, the window H .. H), the block with the rank 2 lines, the rank 6 line and the note.
""")

if want("ef3-note-verify"):
    d = fresh("ef3-note-verify", FREE)
    write(os.path.join(d, "fx/commands"), "verify --file u1/main.roc\nverify --json --file u1/main.roc\n")
    answer(d, runs=[
        run(JSON22, "bot", "pass", H, H),
        run(JSON22, "author", "fail", H, H, "error: e3"),
        run(PARSER12, "bot", "pass", N, N),
        run(PARSER12, "author", "fail", N, N, "error: e4"),
        run(PARSER0, "bot", "pass", H, H),
        run(PARSER0, "author", "fail", H, H, "error: e5"),
    ])
    rules(d, f"""R-EF3 R-AL7 R-CM11 Q500 Q501 (slice 206e3b): `tln verify` with the world of registry/ef3-note-tuple (the same answer: 3 pairs where a `bot` row and an `author` row differ; the tuple json 2.2.0, parser 1.2.0, pf 0.1.1 on H = {H}), with the check.
Q501: `verify` prints the note of Q500: one note, for (json 2.2.0, H) (in the tuple, on the compiler of the run). Not for (parser 1.2.0, {N}) (another compiler) and not for (parser 1.0.0, H) (not in the tuple). The text is the text of `install`: `note: acme/json 2.2.0: the bot and the author rows differ on {H}: bot pass, author fail`, after the platform note and before `check:` (as ef3-note-tuple).
Run 2: `--json`: the note is an item of `data.notes`, after the platform note (the order of `verify`: the pick notes, the platform notes, the differ notes, the notes of the ladder).
Today `verify` prints no such note.
""")

if want("cm7-why-pins"):
    d = fresh("cm7-why-pins", CM7)
    write(os.path.join(d, "fx/commands"), "why json\n")
    src = open(os.path.join(HELD, "given/project/u1/main.roc")).read()
    assert f'roc: "{N10_13}"' in src
    shutil.rmtree(os.path.join(d, "given/project/u1"))
    write(os.path.join(d, "given/project/talon.toml"), '[workspace]\nmembers = ["apps/*/main.roc"]\n')
    write(os.path.join(d, "given/project/apps/a/main.roc"), src)
    write(os.path.join(d, "given/project/apps/b/main.roc"), src.replace(N10_13, H))
    p = os.path.join(d, "fx/http", HOST, "v1/closure.POST")
    a = json.load(open(p))
    a["runs"] = [run(JSON0, "bot", "fail", N10_13, N10_13, "error: e1"), run(JSON0, "bot", "pass", H, H)]
    a["hints"] = []
    write(p, json.dumps(a, separators=(",", ":")))
    rules(d, f"""R-CM7 R-DI1 R-EF1 R-WS4 R-AL8 Q502 (slice 206e3b): `tln why json` (no --file: every member) in a workspace of 2 members with different `roc:` pins: apps/a {N10_13}, apps/b {H}. The header of both is the one of registry/cv1-held-offer (json 2.0.0, parser 1.0.0, pf 0.1.0), the registry is in config.toml.
Q502: the members do not agree on a nightly, so the query has no `compilers` member (Q437: the whole domain). There is one query, not one for each pin (R-AP3), and the pin of the first member is not used. Each member block shows the facts of its own pin: apps/a has the `bot` `fail` of json 2.0.0 on {N10_13}, apps/b has the `bot` `pass` on {H}. No R-EF3 note (no `author` row).
Not tested here: members that agree (the window is the nightly of the workspace, `Pin.decide`): it is the window of registry/cm7-why-registry with one member.
""")

N10_14 = H
if want("cm7-why-pin-unset"):
    d = fresh("cm7-why-pin-unset", CM7)
    src = open(os.path.join(HELD, "given/project/u1/main.roc")).read()
    nopin = src.replace(f'\troc: "{N10_13}",\n', "")
    assert nopin != src
    shutil.rmtree(os.path.join(d, "given/project/u1"))
    for ws, members in (("ws1", (("a", src), ("b", nopin), ("c", src))), ("ws2", (("a", src), ("b", src.replace(N10_13, H)), ("c", nopin)))):
        write(os.path.join(d, "given/project", ws, "talon.toml"), '[workspace]\nmembers = ["apps/*/main.roc"]\n')
        for name, text in members:
            write(os.path.join(d, "given/project", ws, "apps", name, "main.roc"), text)
    write(os.path.join(d, "fx/commands"), "cwd:ws1 why json\ncwd:ws2 why json\n")
    # the roc on PATH is the selected compiler of a member with no pin (R-SP1): 2026-10-12, so that its block is not that of a pin
    write(os.path.join(d, "fx/programs"), "roc\ncurl\n")
    write(os.path.join(d, "fx/jobs"), open(os.path.join(d, "fx/jobs")).read() + f"version\t0\tRoc compiler version {N10_12}\t-\t-\n")
    shutil.copy(os.path.join(CASES, "../evidence/ev5-workspace/fx/path-roc"), os.path.join(d, "fx/path-roc"))
    p = os.path.join(d, "fx/http", HOST, "v1/closure.POST")
    a = json.load(open(p))
    a["runs"] = [run(JSON0, "bot", "pass", N10_13, N10_13), run(JSON0, "bot", "fail", H, H, "error: e1"), run(JSON0, "bot", "pass", N10_12, N10_12)]
    a["hints"] = []
    write(p, json.dumps(a, separators=(",", ":")))
    rules(d, f"""R-CM7 R-DI1 R-EF1 R-WS4 Q521 (slice 206e3b round 2): `tln why json` in 2 workspaces of 3 members (header of registry/cv1-held-offer; the registry is in config.toml). The answer has a `bot` row of json 2.0.0: `pass` on {N10_13}, `fail` on {H}, `pass` on {N10_12}. The roc on PATH is {N10_12}.
Run 1 (cwd ws1): pins {N10_13} (apps/a), none (apps/b), {N10_13} (apps/c). Q521: a member with no pin gets the workspace value (R-WS4, `Pin.decide`), so the pins agree: one POST with `compilers` {N10_13} .. {N10_13}. The block of apps/b shows the facts of {N10_13} (`* 2 bot: pass`), as a and c.
Run 2 (cwd ws2): pins {N10_13} (apps/a), {H} (apps/b), none (apps/c). The pins differ: one POST with no `compilers` member (Q502). apps/c has no workspace value: its block shows the facts of the compiler that the command selects (R-SP1: the roc on PATH, {N10_12}, `* 2 bot: pass`). apps/a: {N10_13} pass. apps/b: {H} fail.
""")

if want("sp24-second-epochs-hints"):
    d = fresh("sp24-second-epochs-hints", SP24)
    write(os.path.join(d, "fx/commands"), "update yaml@1.1.0 --dry-run --file u1/main.roc\n")
    write(os.path.join(d, "given/home/.config/talon/config.toml"), 'registry = "http://127.0.0.1:9"\n\n[probe]\nmax = 1\n')
    for n in range(3, 9):
        for suffix in ("", ".meta"):
            p = os.path.join(d, "fx/http", HOST, "v1", f"closure.POST.{n}{suffix}")
            if os.path.exists(p): os.remove(p)
    shutil.rmtree(os.path.join(d, "given/project/u2"))
    pk = "given/home/.cache/roc/packages"
    for src, dst in (("9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK", PFX11), ("EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt", "HpZmFVX91J55hZj16ga8KSE5cu3zqbmNWCUVsfTPtgnF")):
        write(os.path.join(d, pk, dst, "main.roc"), open(os.path.join(FREE, pk, src, "main.roc")).read())
    answer(d, file="closure.POST.2", hints=[{"hash": PFX11, "nightly": H, "target": "any", "pass_count": 3, "fail_count": 0, "crash_count": 0}])
    rules(d, f"""R-SP24 R-AL4 R-EF1 R-P5 R-UP7 Q522 Q395 (slice 206e3b round 2): run 1 of registry/sp24-second-evidence with `probe.max = 1` and, in place of the run, a `hints` row in the SECOND answer: pfx 0.1.1 ({PFX11}) on {H}: 3 pass, 0 fail, 0 crash (a `pass` hint, rank 6).
The round of the second search has 2 pairs, (yaml 1.1.0, H) and (pfx 0.1.1, H), and the budget cuts it to 1 (R-P5), so the order counts (R-AL4, PairOrder.order_shared): the rank 6 `pass` group first. With the hints of the second answer, pfx 0.1.1 is probed and yaml 1.1.0 is not; exit 12 after the fact of pfx is saved (R-UP7: `1 unit check did not run`). Today the hints of the second answer are not read: the order is the order of the slots (yaml, then pfx) and yaml 1.1.0 is probed.
The `epochs` of the second answer (Q522) have an L0 test only (`LogsnapshotTest`, `LogSnapshot.merged`): the inference of a moved release is computed in `wide!` before the second answer is read, so no `update` run shows it (see the slice file, doubt D8).
""")

if want("sp24-second-epochs"):
    d = fresh("sp24-second-epochs", SP24)
    write(os.path.join(d, "fx/commands"), "update yaml@1.1.0 --no-probe --dry-run --file u1/main.roc\n")
    for n in range(3, 9):
        for suffix in ("", ".meta"):
            p = os.path.join(d, "fx/http", HOST, "v1", f"closure.POST.{n}{suffix}")
            if os.path.exists(p): os.remove(p)
    shutil.rmtree(os.path.join(d, "given/project/u2"))
    # the compiler list of the registry (D): as registry/cv1-upgrade-free
    for f in ("toolchains%3Fafter=0", "toolchains%3Fafter=0.meta"):
        shutil.copy(os.path.join(FREE, "fx/http", HOST, "v1", f), os.path.join(d, "fx/http", HOST, "v1", f))
    answer(d, file="closure.POST.2", runs=[run(PFX11, "bot", "fail", N10_12, N10_12, "error: e1")], epochs=[{"target": "any", "from": N10_12, "to": H}])
    rules(d, f"""R-SP24 R-EP15 R-EP6 R-EP9 Q522 Q393 (slice 206e3b round 3): `tln update yaml@1.1.0 --no-probe --dry-run` with the world of registry/sp24-update-held-move (the first search has no tuple: yaml 1.1.0 needs pf 0.1.1, pf is held), the compiler list of registry/cv1-upgrade-free (D = 2026-10-12, H = {H}, 2026-10-16, ...), and in the SECOND answer: an epoch {N10_12} .. {H} (target any) and a `bot` `fail` of pfx 0.1.1 ({PFX11}) on {N10_12} only. The first answer has no epoch.
The second search infers again with the epochs of both answers (Design Q522, `LogSnapshot.merged`): case (a) of R-EP6 infers a fail of pfx 0.1.1 on H (an unknown set, Q393). With `--no-probe` an inferred fail decides (R-EP9), so pf cannot move to 0.1.1 and the command has no tuple. With the epochs of the first answer only (none) each release is its own epoch (R-EP4): pfx 0.1.1 has no fact on H, it is assumed, and pf moves.
""")
