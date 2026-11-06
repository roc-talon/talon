#!/usr/bin/env python3
"""Slice 206e3: the given and fx files of the new L2 cases (not the expect files).
  registry/ef1-rank2-free       R-EF1 rank 2, R-EP12: a bot pass of the answer is the fact of a pair of a free nightly (wide!): no unit probe
  registry/ef1-rank2-held       R-EF1 rank 2, R-EP12: the same for the held compiler of `update` (the lookup of a probe round)
  registry/ef3-bot-author       R-EF3, Q393: a bot row wins over an author row; a rank 2 fail does not decide alone (local unit probe)
  registry/ep15-epoch-no-probe  R-EP15, R-EP6 (a), R-EP9: an epoch of the answer infers a fail on N under --no-probe
  registry/al4-shared-order     R-AL4, Q395, R-EF3 rank 6: the order of a cut round with the hints of the answer
  registry/cm7-why-registry     R-CM7, R-DI1, Q499 (round 2): `why` with a registry: one query, ranks 2 and 6, the R-EF3 note; direct and --offline: no query
  registry/ef3-note-tuple       R-EF3, Q500 (round 2): the note for the pairs of the chosen tuple on the compiler of the run only
  registry/pb3-outdated-runs    R-PB3, R-EP12, R-EP15, R-EF3, R-CM6: the nightly range of `outdated` from the runs and epochs of the answer
Run from the repo root: python3 -I research/slice-206e3-revert/mkcases.py [<case name> ...]
It DELETES the dirs of these cases (expect/ and rules too): keep a copy before a run."""
import json, os, shutil, sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases/registry")
HOST = "127.0.0.1%3A9"
ONLY = sys.argv[1:]

N10_11 = "nightly-2026-10-11-1a2b3c4"
N10_12 = "nightly-2026-10-12-2664a27"
N10_13 = "nightly-2026-10-13-5e6f7a8"
H = "nightly-2026-10-14-38a3029"
N = "nightly-2026-10-16-5e6f7a8"
PF0 = "6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL"   # pfx 0.1.0 (header)
PF1 = "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK"   # pfx 0.1.1
JSON0 = "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21"  # json 2.0.0 (header)
JSON22 = "3CjxCHLyKRMyh9nKodyVQYJcsttYAyPLjYTpoH2fnZtA" # json 2.2.0
PARSER0 = "EUQ59oYxaBxvFpFSYhbkNUcMgDyiuG8TvXSTXttvA9jc" # parser 1.0.0 (header)
PARSER12 = "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt" # parser 1.2.0


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


def answer(d, runs=(), epochs=(), hints=(), nearest=()):
    p = os.path.join(d, "fx/http", HOST, "v1/closure.POST")
    a = json.load(open(p))
    assert a["runs"] == [] and a["epochs"] == [] and a["hints"] == [] and a["nearest"] == []
    a["runs"], a["epochs"], a["hints"], a["nearest"] = list(runs), list(epochs), list(hints), list(nearest)
    write(p, json.dumps(a, separators=(",", ":")))


def rules(d, text): write(os.path.join(d, "rules"), text)


FREE = os.path.join(CASES, "cv1-upgrade-free")
ONE_RUN = "upgrade roc --dry-run --file u1/main.roc\n"

if want("ef1-rank2-free"):
    d = fresh("ef1-rank2-free", FREE)
    write(os.path.join(d, "fx/commands"), ONE_RUN)
    answer(d, runs=[run(h, "bot", "pass", N, N) for h in (JSON0, PARSER0, PF0)])
    rules(d, f"""R-EF1 R-EP12 R-EF2 R-AL4 (slice 206e3): run 1 of registry/cv1-upgrade-free (`tln upgrade roc`, a free nightly, N = {N}), with `runs` in the answer: a `bot` `pass` of each header hash (json 2.0.0, parser 1.0.0, pf 0.1.0) on N.
A rank 2 fact is a real fact (R-EF1, R-EP12): the 3 pairs on N have a fact, so the command runs no unit probe (cv1-upgrade-free has `probes 3` with the 3 unit probes and their `db_write`). The local db is still asked first (the `facts=12` query of D: rank 1 wins, R-EF3).
The whole-app check and the build still run (R-EF2). The pin moves to N with 3 probes (cv1-upgrade-free: 6).
""")

if want("ef1-rank2-held"):
    d = fresh("ef1-rank2-held", FREE)
    write(os.path.join(d, "fx/commands"), "update --dry-run --file u1/main.roc\n")
    answer(d, runs=[run(JSON22, "bot", "pass", N10_12, N)])
    rules(d, f"""R-EF1 R-EP12 R-EF3 R-AL4 (slice 206e3): `tln update` with the world of registry/cv1-upgrade-free: the held compiler H = {H} (the pin and the roc on PATH). The tuple is json 2.2.0, parser 1.2.0 and pf 0.1.1 of the answer (parser 1.3.0 is withdrawn).
The answer has one run: a `bot` `pass` of json 2.2.0 from {N10_12} to {N}. H is between the ends in R-NS1 order (the dates of the tags), so the run holds H (R-AP17 run, Matrix.rows): a rank 2 fact of the pair (json 2.2.0, H).
The probe round looks the pairs up in the db first (rank 1 wins, R-EF3), then uses the rank 2 fact: only parser 1.2.0 and pf 0.1.1 get a unit probe on H, not json 2.2.0. Reading of the test: the run is placed with the tags of its ends; the command reads no compiler list for it (none is read in this run before).
""")

if want("ef3-bot-author"):
    d = fresh("ef3-bot-author", FREE)
    write(os.path.join(d, "fx/commands"), ONE_RUN)
    answer(d, runs=[
        run(JSON0, "bot", "fail", N, N, "error: e1"),
        run(JSON0, "author", "pass", N, N),
        run(PARSER0, "author", "fail", N, N, "error: e2"),
        run(PARSER0, "bot", "pass", N, N),
    ])
    rules(d, f"""R-EF3 R-EF1 R-EP8 R-UM1 Q393 (slice 206e3): run 1 of registry/cv1-upgrade-free (`tln upgrade roc`, N = {N}) with `bot` and `author` rows of 2 header hashes on N.
parser 1.0.0: an `author` `fail`, then a `bot` `pass`. The `bot` row wins (R-EF3, also when the author row comes first): a real pass, no unit probe.
json 2.0.0: a `bot` `fail` and an `author` `pass`. The `bot` row wins: a rank 2 fail, which has an unknown set of modules (Q393). It does not decide alone (R-EP8): the solver asks for the local unit probe of (json 2.0.0, N). The fake probe passes, so N is chosen.
pf 0.1.0 has no row: its unit probe runs. So one round with 2 unit probes (json, pf), not 3, and no probe of parser. If the author row won, json would need no probe and parser would.
""")

if want("ep15-epoch-no-probe"):
    d = fresh("ep15-epoch-no-probe", FREE)
    write(os.path.join(d, "fx/commands"), "upgrade roc --no-probe --dry-run --file u1/main.roc\n")
    answer(d, runs=[run(JSON0, "bot", "fail", N10_12, N10_12, "error: e1")], epochs=[{"target": "any", "from": N10_12, "to": N}])
    rules(d, f"""R-EP15 R-EP6 R-EP9 R-EP2 R-EP3 R-EP4 R-EF3 Q393 (slice 206e3): `tln upgrade roc --no-probe` (probe mode Off) with the world of registry/cv1-upgrade-free.
The answer has the epoch {N10_12} .. {N} (target `any`, R-AP17) and one run: a `bot` `fail` of json 2.0.0 (the header value) on {N10_12} only.
D is the registry list. With the matrix (R-EP15), the epoch holds 2026-10-12, H and N, and case (a) of R-EP6 infers a fail of json 2.0.0 on H and on N (an unknown set, Q393: it touches each used module). One hash only gives no case (b) boundary (R-EP3).
With `--no-probe` an inferred fact decides (R-EP9): N fails for json, so the compiler stays H (the assumed pass of the header value on H wins over an inferred fact). With no matrix each release is its own epoch (R-EP4) and N has no fact, so N would be fit and chosen.
""")

if want("al4-shared-order"):
    d = fresh("al4-shared-order", FREE)
    write(os.path.join(d, "fx/commands"), ONE_RUN)
    write(os.path.join(d, "given/home/.config/talon/config.toml"), 'registry = "http://127.0.0.1:9"\n\n[probe]\nmax = 2\n')
    answer(d, hints=[
        {"hash": JSON0, "nightly": N, "target": "any", "pass_count": 0, "fail_count": 2, "crash_count": 1},
        {"hash": PARSER0, "nightly": N, "target": "any", "pass_count": 3, "fail_count": 1, "crash_count": 0},
    ])
    rules(d, f"""R-AL4 R-EF1 R-EF3 R-SE5 R-P5 R-UP7 Q395 (slice 206e3): run 1 of registry/cv1-upgrade-free (`tln upgrade roc`, N = {N}) with `probe.max = 2` and `hints` in the answer (rank 6, R-EF1):
json 2.0.0 on N: 0 pass, 2 fail, 1 crash, a `fail` hint (R-EF3). parser 1.0.0 on N: 3 pass, 1 fail, a `pass` hint. pf 0.1.0: no hint.
The round has 3 pairs on N and the budget cuts it to 2 (R-P5), so the order counts (R-AL4, PairOrder.order_shared): the rank 6 `pass` group (parser), then the pairs with no hint (pf), then the rank 6 `fail` group (json, Q395).
The 2 probes that run are parser and pf; json does not run. Then exit 12 after the facts are saved (R-UP7). The hints only order the search (R-SE5): they are no fact.
""")

if want("pb3-outdated-runs"):
    d = fresh("pb3-outdated-runs", os.path.join(CASES, "cv1-outdated-query"))
    write(os.path.join(d, "fx/commands"), "outdated --file u1/main.roc\noutdated --json --file u1/main.roc\n")
    answer(d, runs=[
        run(JSON0, "bot", "pass", N10_11, N10_11),
        run(PARSER0, "bot", "pass", N10_11, N10_12),
        run(PARSER0, "author", "fail", N10_12, N10_13, "error: e2"),
        run(PF0, "bot", "pass", N10_11, N10_13),
    ], epochs=[{"target": "any", "from": N10_11, "to": N10_13}])
    write(os.path.join(d, "given/home/.cache/roc/talon/compat.tsv"), f"format\t1\nfact\t{PF0}\t{N10_13}\tany\tfail\t\t\n")
    rules(d, f"""R-PB3 R-CM6 R-EP12 R-EP15 R-EP3 R-EP6 R-EF3 R-AP17 (slice 206e3, 206e2 plan note P1): `tln outdated` with the world of registry/cv1-outdated-query (D = {N10_11}, {N10_12}, {N10_13}; compat.db has one row, of pf).
The nightly range of a row is R-PB3 over the EP facts: rank 1 and rank 2 (the `runs` of the answer, R-EP12) and the epochs of the answer (R-EP15).
json 2.0.0: a `bot` `pass` on 2026-10-11 and the epoch 2026-10-11 .. 2026-10-13 of the answer. parser and pf (below) both change from a pass on 10-12 to a fail on 10-13, so case (b) of R-EP3 (2 hashes, inside an epoch of the answer) makes the transition 10-12 -> 10-13 a boundary: the epoch splits into 10-11 .. 10-12 and 10-13.
Case (a) of R-EP6 makes 10-12 an inferred pass of json, and 10-13 is unknown: the range is 10-11 .. 10-12?, the lower end is the end of D (real), the upper end has no real fact next to it.
parser 1.0.0: a `bot` `pass` on 10-11 and 10-12, an `author` `fail` on 10-12 and 10-13. On 10-12 the `bot` row wins (R-EF3), so 10-12 is a pass and 10-13 a real fail: the range is 10-11 .. 10-12, both ends real.
pf 0.1.0: a `bot` `pass` from 10-11 to 10-13, and a local (rank 1) `fail` on 10-13 in compat.db: rank 1 wins (R-EF3), so the range is 10-11 .. 10-12, both ends real. Run 2: the same with `--json` (the `nightly_range` members of slice 040). Exit 0 (R-E7).
""")

# ------------------------------------------------ round 2 (Design Q499, Q500)
if want("cm7-why-registry"):
    d = fresh("cm7-why-registry", os.path.join(CASES, "cv1-held-offer"))
    write(os.path.join(d, "fx/commands"), "why json --file u1/main.roc\nwhy json --json --file u1/main.roc\nwhy json --registry direct --file u1/main.roc\nwhy json --offline --file u1/main.roc\n")
    answer(d, runs=[run(JSON0, "bot", "fail", N10_13, N10_13, "error: e1"), run(JSON0, "author", "pass", N10_13, N10_13)],
           hints=[{"hash": JSON0, "nightly": N10_13, "target": "any", "pass_count": 5, "fail_count": 1, "crash_count": 0}])
    rules(d, f"""R-CM7 R-DI1 R-EF1 R-EF3 R-AP17 R-RG4 Q499 Q394 (slice 206e3 round 2): `tln why json` with the registry of config.toml, on the project of registry/cv1-held-offer (pin `roc: {N10_13}` = H, the packages are in the cache).
The answer has a `bot` `fail` (digest `error: e1`) and an `author` `pass` of json 2.0.0 on H, and the rank 6 counts 5 pass, 1 fail, 0 crash of json 2.0.0 on H.
Run 1: `why` sends the closure query of R-DI1 (Design Q499): the privacy guard reads the kept answers (R-RG4), then one POST /v1/closure with no `groups`, the `hashes` of the header and the held nightly H as the window (from = to = H). The walk takes the header facts from the answer (R-AL8 source 2). The block on H has the rank 2 lines (the `bot` line wins and has the `*`, then the `author` line), the rank 6 line, and the note of R-EF3 (the results differ). No `db_write`, no probe, no download.
Run 2: the same with `--json`: both rank 2 items with `error_digest` (text or null, R-AP58) and the rank 6 item with the 3 counts (R-EF3 "`--json` gives both"), and the note in `notes`.
Run 3: `--registry direct`: no query and no request (R-DI1): the block has ranks 1, 3, 4 only (here none: no row, no pin in the package header, no `.roc-version` file).
Run 4: `--offline` with the registry: no query and no request (Q499): the same block as run 3.
""")

if want("ef3-note-tuple"):
    d = fresh("ef3-note-tuple", FREE)
    write(os.path.join(d, "fx/commands"), "update --dry-run --file u1/main.roc\nupdate --dry-run --json --file u1/main.roc\n")
    answer(d, runs=[
        run(JSON22, "bot", "pass", H, H),
        run(JSON22, "author", "fail", H, H, "error: e3"),
        run(PARSER12, "bot", "pass", N, N),
        run(PARSER12, "author", "fail", N, N, "error: e4"),
        run(PARSER0, "bot", "pass", H, H),
        run(PARSER0, "author", "fail", H, H, "error: e5"),
    ])
    rules(d, f"""R-EF3 R-AL7 R-EF1 Q500 (slice 206e3 round 2): `tln update` on H = {H} with the world of registry/cv1-upgrade-free (the tuple: json 2.2.0, parser 1.2.0, pf 0.1.1 on H, as registry/ef1-rank2-held).
The answer has 3 pairs where a `bot` row and an `author` row differ: (json 2.2.0, H): `bot` `pass`, `author` `fail`; (parser 1.2.0, {N}): another compiler of E; (parser 1.0.0, H): a release that is not in the chosen tuple.
Design Q500: the note is for the pairs of the chosen tuple on the compiler of the run only, so one note: `note: acme/json 2.2.0: the bot and the author rows differ on {H}: bot pass, author fail`, on stdout with the other notes of the resolve. The `bot` row wins (R-EF3): json 2.2.0 has a real pass on H and no unit probe; parser 1.2.0 and pf 0.1.1 are probed.
Run 2: the same with `--json`: the note is an item of `data.notes` (not `index_notes`).
""")
