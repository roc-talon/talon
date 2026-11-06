#!/usr/bin/env python3
"""Slice 206e4: the given and fx files of the new L2 cases (not the expect files).
  registry/ap30-update-notes       R-AP29, R-AP30, R-FL4: `update` prints one index note for each stale repository (human, --json, --quiet)
  registry/ap30-held-move-notes    R-AP29, R-AP30, R-AP16: a held move has 2 answers: one note for each repository, the older time
  registry/ap30-outdated-notes     R-AP29, R-AP30, R-FL4: `outdated` prints the notes (human, --json, --quiet)
  share/sh49-update-share          R-SH2, R-SH3, R-SH4: `update` with probes queues the unit facts, sends the queue after the output
  share/sh50-update-share-off      R-SH2, R-SH3, R-SH4: DO_NOT_TRACK and CI: no queue write, no send. A stored fact is not queued
  share/sh51-send-install ...      R-SH4: each resolve command that sent a registry request sends the queue at its end
  share/sh56-no-request-no-send    R-SH4: a command that sent no registry request does not send the queue
  share/sh52-update-share-header   Q535, Q450, the header of a hash with no artifact record
Run from the repo root: python3 -I research/slice-206e4-revert/mkcases.py [<case name> ...]
It DELETES the dirs of these cases (expect/ and rules too): keep a copy before a run."""
import json, os, shutil, sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases")
HOST = "127.0.0.1%3A9"
ONLY = sys.argv[1:]

NOW_MS = 1792065600000  # 2026-10-15T12:00:00Z
H = "nightly-2026-10-14-38a3029"
HOUR = 3600 * 1000
DAY = 24 * HOUR
MIN = 60 * 1000
QROW = "1\tHA\t%s\tany\tpass\t0.0.1\t2026-10-19T10:00:00Z\n" % H
SHARE_JSON = '{"format":1,"id":"0123456789abcdeffedcba9876543210","sent":0,"counted":0,"first":0,"first_sent_at":null,"last_sent_at":null,"token":null,"token_expires_at":null,"account":null}\n'


def want(name): return not ONLY or name in ONLY


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def fresh(area, name, src):
    d = os.path.join(CASES, area, name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    for part in ("entry", "fx", "given"):
        p = os.path.join(src, part)
        if os.path.isdir(p): shutil.copytree(p, os.path.join(d, part))
        else: shutil.copy(p, os.path.join(d, part))
    return d


def route(d, file="closure.POST"):
    return os.path.join(d, "fx/http", HOST, "v1", file)


def checked(d, items, file="closure.POST"):
    p = route(d, file)
    a = json.load(open(p))
    a["checked"] = [{"name": n, "checked_at": t, "stale": s} for (n, t, s) in items]
    write(p, json.dumps(a, separators=(",", ":")))


def rules(d, text): write(os.path.join(d, "rules"), text)


def commands(d, lines): write(os.path.join(d, "fx/commands"), "\n".join(lines) + "\n")


def share_on(d, queue=True, share_json=True, route_status=201, body=None, nightly_pin=False):
    """share = true, a queue row of the running version, the share.json, the answer of POST /v1/compat."""
    cfg = os.path.join(d, "given/home/.config/talon/config.toml")
    write(cfg, open(cfg).read().rstrip("\n") + "\nshare = true\n")
    t = os.path.join(d, "given/home/.cache/roc/talon")
    if queue: write(os.path.join(t, "share_queue.tsv"), QROW)
    if share_json: write(os.path.join(d, "given/home/.local/share/talon/share.json"), SHARE_JSON)
    meta = {201: "status 201", 503: "status 503\nheader Retry-After: 1"}[route_status]
    write(route(d, "compat.POST"), body if body is not None else ('{"written":3,"first":2,"skipped":[]}' if route_status == 201 else '{"type":"/errors/busy","title":"Busy","status":503}'))
    write(route(d, "compat.POST.meta"), meta + "\nheader Content-Type: application/json\nheader Cache-Control: no-store\nrequire content-type: application/json\nrequire talon-contributor: 0123456789abcdeffedcba9876543210\nrequire-none authorization\nrequire user-agent: tln/0.0.1\n")


def drop_ci(d):
    p = os.path.join(d, "fx/env")
    write(p, "".join(l for l in open(p) if l.strip() != "CI=true"))


def pinned_row(d):
    """The sha256 of (H, linux_x86_64) is recorded (R-CV6): filter 3 of R-SH3."""
    p = os.path.join(d, "given/home/.cache/roc/talon/compat.tsv")
    write(p, "format\t1\npinned\t%s\tlinux_x86_64\t%s\tregistry\n" % (H, "ab" * 32))


UPD = os.path.join(CASES, "registry/al2-update-query")
SP24 = os.path.join(CASES, "registry/sp24-update-held-move")
OUTD = os.path.join(CASES, "registry/cv1-outdated-query")
HELD = os.path.join(CASES, "registry/ef1-rank2-held")
DI1 = os.path.join(CASES, "registry/di1-install-no-free")

if want("ap30-update-notes"):
    d = fresh("registry", "ap30-update-notes", UPD)
    shutil.rmtree(os.path.join(d, "fx/http/localhost%3A9"))
    # acme/json: stale, 3 days and 2 hours ago. acme/parser: fresh, but an old time (the Worker decides: R-AP29). acme/pfx: stale, never read.
    checked(d, [("acme/json", NOW_MS - 3 * DAY - 2 * HOUR, True), ("acme/parser", NOW_MS - 40 * DAY, False), ("acme/pfx", None, True)])
    commands(d, ["update --no-check --dry-run --file u1/main.roc", "update --no-check --dry-run --json --file u1/main.roc", "update --no-check --dry-run --quiet --file u1/main.roc"])
    rules(d, """R-AP29 R-AP30 R-FL4 R-J6 R-OUT2 (slice 206e4, Design Q406 to Q408): `tln update` with a registry (the world of registry/al2-update-query, TALON_NOW 2026-10-15T12:00:00Z) and an answer with 3 `checked` items: acme/json stale, checked 3 days and 2 hours ago; acme/parser NOT stale with a time 40 days old (the Worker computes `stale`, R-AP29: no note); acme/pfx stale with a null time. All runs are --no-check --dry-run (no probe).
Run 1: after the other notes (here there are none, so the first lines), one `note:` line for each stale repository, sorted by name: `note: index: acme/json checked 3d ago`, `note: index: acme/pfx not checked since its first ingest` (R-AP30; the `note:` prefix and the place are a proposal, R-OUT2). Exit code 0 (R-AP30).
Run 2 (--json): `data.notes` has the 2 texts (without `note: `), and `data.index_notes` (new member, last) has the 2 elements {kind, name, checked_at (ms or null), text} (Q407). The human text on stderr as in other --json runs.
Run 3 (--quiet): R-FL4 hides notes: no index note. The answer lines stay.
""")

if want("ap30-held-move-notes"):
    d = fresh("registry", "ap30-held-move-notes", SP24)
    # first answer (log 40): acme/yaml stale 12 min ago, acme/json stale 5 hours ago, acme/pfx fresh.
    checked(d, [("acme/json", NOW_MS - 5 * HOUR, True), ("acme/pfx", NOW_MS - 2 * DAY, False), ("acme/yaml", NOW_MS - 12 * MIN, True)], "closure.POST")
    # second answer (log 45): acme/json stale 2 days ago (older: this one counts), acme/pfx stale, never read.
    checked(d, [("acme/json", NOW_MS - 2 * DAY, True), ("acme/pfx", None, True)], "closure.POST.2")
    commands(d, ["update yaml@1.1.0 --no-check --dry-run --file u1/main.roc", "update yaml@1.1.0 --no-check --dry-run --json --file u1/main.roc"])
    rules(d, """R-AP29 R-AP30 R-AP16 R-SP24 (slice 206e4, Design Q408): run 1 of registry/sp24-update-held-move (a held move: the first answer, then the second query) with `checked` in both answers.
First answer: acme/json stale 5 hours ago, acme/pfx fresh (2 days old time), acme/yaml stale 12 minutes ago. Second answer: acme/json stale 2 days ago, acme/pfx stale with a null time.
One note for each repository, from the stale items of both answers: acme/json: the older time (the second answer): `2d`; acme/pfx: the fresh item and the stale item: the stale one, `not checked since its first ingest`; acme/yaml: only in the first answer: `12m`. Sorted by name. Exit code 0.
Run 2: the same with --json: `data.notes` and `data.index_notes` have the 3 elements in that order (Q407, Q408).
""")

if want("ap30-outdated-notes"):
    d = fresh("registry", "ap30-outdated-notes", OUTD)
    checked(d, [("acme/json", NOW_MS - 3 * DAY - 2 * HOUR, True), ("acme/parser", NOW_MS - 40 * DAY, False), ("acme/pfx", None, True)])
    commands(d, ["outdated --file u1/main.roc", "outdated --json --file u1/main.roc", "outdated --quiet --file u1/main.roc"])
    rules(d, """R-AP29 R-AP30 R-FL4 R-J6 R-OUT2 (slice 206e4, Design Q406 to Q408): `tln outdated` with a registry (the world of registry/cv1-outdated-query) and the `checked` items of registry/ap30-update-notes: acme/json stale (3d), acme/parser not stale (no note), acme/pfx stale with a null time.
Run 1: the table, then one `note:` line for each stale repository, sorted by name (a proposal, R-OUT2: after the table). Exit code 0 (R-AP30, R-E7).
Run 2 (--json): `data` has the member `index_notes` after `members` (Q407). `outdated` has no `notes` list, so none is added (proposal).
Run 3 (--quiet): R-FL4 hides the notes: the table only.
""")

if want("sh49-update-share"):
    d = fresh("share", "sh49-update-share", HELD)
    drop_ci(d)
    pinned_row(d)
    share_on(d)
    commands(d, ["update --dry-run --file u1/main.roc", "update --dry-run --file u1/main.roc"])
    rules(d, f"""R-SH2 R-SH3 R-SH4 R-SH5 R-SH6 R-AP10 R-PP4 R-LF4 (slice 206e4): `tln update` with the world of registry/ef1-rank2-held (held compiler {H}; the round 1 unit probes of parser 1.2.0 and pf 0.1.1; json 2.2.0 has a rank 2 fact), but `share = true` in config.toml, no `CI`, a share.json, `pinned` has the sha256 of ({H}, linux_x86_64) (R-CV6, filter 3), and the queue has one row of 0.0.1 (seq 1, hash HA).
Run 1: the 2 unit facts of round 1 (parser EiSZ, platform 9LFk, target any, pass) came from a probe of this command, in the answer, with no `bot` row, on a recorded nightly: they go in the queue (R-SH3), in the order of the probe results (R-PP3). The build fact of the platform is an app build (filter 2) and is not queued: its `db_write` has no queue write. The queue write follows the facts write of the round (R-PP4): one `db_query` of `pinned` for the compiler, one `clock` (the time of `queued_at`, R-TF7), one `db_write` with `queue=2`. After the output, the send (R-SH4): the 3 rows of 0.0.1 in one POST /v1/compat (seq order), 201, `unqueue=3`, the totals of share.json. The output, the stderr and the exit code are those of ef1-rank2-held (R-SH4).
Run 2: every fact is now stored, so no probe and no queue write (filter 1: a stored fact is not the result of a probe of this command). The queue is empty: after the output only the read of the queue (no request).
""")

if want("sh50-update-share-off"):
    d = fresh("share", "sh50-update-share-off", HELD)
    drop_ci(d)
    pinned_row(d)
    share_on(d, body='{"written":1,"first":1,"skipped":[]}')
    commands(d, ["update --dry-run --file u1/main.roc env:DO_NOT_TRACK=1", "update --dry-run --file u1/main.roc env:CI=true", "update --dry-run --file u1/main.roc"])
    rules(d, f"""R-SH2 R-SH3 R-SH4 R-EV26 R-NM1 (slice 206e4): the world of share/sh49-update-share (`share = true`, a queue row HA of 0.0.1, `pinned` for {H}), with R-SH2 false in runs 1 and 2.
Run 1 (`DO_NOT_TRACK=1`, R-SH2 condition 4): the round 1 unit probes run, their facts are stored, but nothing goes in the queue and nothing is sent: no queue call at all (no `pinned` query, no `clock`, no queue write, no `queue_rows`). R-SH2 is checked when a fact goes into the queue and again before the send.
Run 2 (`CI=true`, condition 5): no probe (the facts are stored), no send: no queue call.
Run 3 (no variable): the stored facts of run 1 are NOT queued (filter 1: they are old facts, not a probe of this command), only the row HA is sent: one POST with 1 row, 201, `unqueue=1`.
""")

SEND = [
    ("install", "registry/al2-install-query", "install --no-check --dry-run --file u1/main.roc", "install"),
    ("verify", "registry/al2-verify-query", "verify --no-check --file u1/main.roc", "verify"),
    ("upgrade", "registry/al2-upgrade-query", "upgrade json --no-check --dry-run --file u1/main.roc", "upgrade json"),
    ("outdated", "registry/cv1-outdated-query", "outdated --file u1/main.roc", "outdated"),
    ("why", "registry/cm7-why-registry", "why json --file u1/main.roc", "why json"),
]
for (short, src, cmd, label) in SEND:
    name = "sh51-send-" + short
    if want(name):
        d = fresh("share", name, os.path.join(CASES, src))
        share_on(d, route_status=503)
        if short in ("install", "verify"):  # Q537: a stale item, and no index note
            checked(d, [("acme/json", NOW_MS - 3 * DAY - 2 * HOUR, True), ("acme/pfx", None, True)])
        commands(d, [cmd])
        rules(d, f"""R-SH4 R-SH2 R-AP34 (slice 206e4): `tln {label}` with the world of {src} (run 2 of it, or run 1 for outdated and why) and `share = true`, a share.json and a queue row HA of 0.0.1. The command sent its closure request to the registry, so it sends the queue at its end, after its output (R-SH4): one `queue_rows` read, the read of share.json, `clock`, one POST /v1/compat with the row (`timeout=5`). The answer is 503 (`Retry-After: 1`): the row stays, no second request, no wait, no write, no message, and the output, `--json` and exit code (0) are those of the command with no send (R-SH4).
""")

if want("sh56-no-request-no-send"):
    d = fresh("share", "sh56-no-request-no-send", DI1)
    share_on(d)
    commands(d, ["install --frozen --file u1/main.roc", "install --no-check --dry-run --json --file u2/main.roc"])
    rules(d, """R-SH4 R-SH2 R-DI1 R-LF1 (slice 206e4): the world of registry/di1-install-no-free (runs 2 and 3 of it) with `share = true`, a share.json and a queue row HA of 0.0.1. Run 1 (`install --frozen`) and run 2 (a header with no group and no hash, Design Q469) send no request to the registry. R-SH4: only a command that sent a request to the registry sends the queue, so no `queue_rows` read, no POST /v1/compat. The calls and the output are those of the world with no share.
""")

# Q535: the headers that R-DI7 read are reused, no second read.
if want("sh52-update-share-header"):
    d = fresh("share", "sh52-update-share-header", HELD)
    drop_ci(d)
    pinned_row(d)
    share_on(d)
    p = route(d)
    a = json.load(open(p))
    gone = ("EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt", "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK")
    a["artifacts"] = [r for r in a["artifacts"] if r["hash"] not in gone]
    write(p, json.dumps(a, separators=(",", ":")))
    commands(d, ["update --dry-run --file u1/main.roc"])
    rules(d, f"""R-SH3 R-SH4 R-DI7 R-LD2 (slice 206e4, Design Q450): the world of share/sh49-update-share, run 1 only, but the answer has NO artifact record for parser 1.2.0 (EiSZ) and pf 0.1.1 (9LFk): each has a release row only. Filter 7 of R-SH3 (the kind and the targets of the hash) then comes from the header of `packages/<hash>/main.roc` (R-DI7, Q450): a package (`package [...]`) takes target `any`, and the platform header (no `targets` section) takes `any`. The unit facts are queued as in sh49: the same 2 rows.
The flow reads the header files with `read_files` (the probe of the row had the archive, so the files are there) for the facts with no artifact record, before the queue write. The calls that the world makes without this slice stay.
""")


FREE = os.path.join(CASES, "registry/cv1-upgrade-free")
UPG = os.path.join(CASES, "registry/al2-upgrade-query")

if want("ap30-update-error-notes"):
    d = fresh("registry", "ap30-update-error-notes", SP24)
    checked(d, [("acme/yaml", NOW_MS - 12 * MIN, True)], "closure.POST")
    commands(d, ["update yaml@1.1.0 --no-check --dry-run --snapshot log:30 --file u1/main.roc", "update yaml@1.1.0 --no-check --dry-run --snapshot log:30 --json --file u1/main.roc"])
    rules(d, """R-AP30 R-SP16 R-AP16 R-E6 (slice 206e4, Design Q533): run 2 of registry/sp24-update-held-move (--snapshot log:30: no tuple, exit 10) with `checked` in the first answer: acme/yaml stale, 12 minutes ago.
The command ends with an error, and the answer was read: the index note is printed after the error text, on stderr: `note: index: acme/yaml checked 12m ago`. Exit code 10 (R-AP30: unchanged). Run 2 (--json): the same lines on stderr, and the error object on stdout has no note.
""")

if want("ap30-upgrade-notes"):
    d = fresh("registry", "ap30-upgrade-notes", UPG)
    checked(d, [("acme/json", NOW_MS - 3 * DAY - 2 * HOUR, True), ("acme/parser", NOW_MS - 40 * DAY, False), ("acme/pfx", None, True)])
    commands(d, ["upgrade json --no-check --dry-run --file u1/main.roc"])
    rules(d, """R-AP29 R-AP30 (slice 206e4, Design Q537): `tln upgrade json` with a registry (run 2 of registry/al2-upgrade-query) and the `checked` items of registry/ap30-update-notes. `upgrade` with names prints the index notes: one `note:` line for json and one for pfx (parser is not stale), after the other notes and before `check:`. Exit code 0.
""")

if want("sh57-send-after-error"):
    d = fresh("share", "sh57-send-after-error", SP24)
    share_on(d, route_status=503)
    commands(d, ["update yaml@1.1.0 --no-check --dry-run --snapshot log:30 --file u1/main.roc"])
    rules(d, """R-SH4 R-AP34 (slice 206e4, Design Q533): run 2 of registry/sp24-update-held-move (--snapshot log:30: no tuple, exit 10) with `share = true`, a share.json and a queue row HA of 0.0.1. The command ended with an error (exit 10) after an answer of the registry: the send still runs after the error text (one POST, a 503: the row stays). The exit code stays 10.
""")

if want("sh57-no-send-exit15"):
    d = fresh("share", "sh57-no-send-exit15", UPD)
    shutil.rmtree(os.path.join(d, "fx/http/localhost%3A9"))
    share_on(d)
    write(route(d, "closure.POST"), '{"type":"/errors/rate-limited","title":"Rate limited","status":429}')
    write(route(d, "closure.POST.meta"), "status 429\nheader Content-Type: application/problem+json\nheader Cache-Control: no-store\nheader Retry-After: 60\n")
    commands(d, ["update --no-check --dry-run --file u1/main.roc"])
    rules(d, """R-SH4 R-AP25 R-E6 (slice 206e4, Design Q533): `tln update` with a registry whose closure answer is 429 (exit 15) and `share = true`, a share.json and a queue row HA of 0.0.1. Exit 15: the send is skipped (the registry did not give an answer): no queue call, no POST /v1/compat. The exit code is 15.
""")

if want("sh58-send-upgrade-roc"):
    d = fresh("share", "sh58-send-upgrade-roc", FREE)
    shutil.rmtree(os.path.join(d, "share"), ignore_errors=True)
    share_on(d, route_status=503)
    checked(d, [("acme/json", NOW_MS - 3 * DAY - 2 * HOUR, True), ("acme/pfx", None, True)])
    commands(d, ["upgrade roc --dry-run --file u1/main.roc"])
    rules(d, """R-SH4 R-AP30 R-CV1 (slice 206e4, Design Q541): `tln upgrade roc` with the world of registry/cv1-upgrade-free (run 1) and `share = true`, a share.json and a queue row HA of 0.0.1. It sent the closure query, so it sends the queue at its end (one POST, a 503: the row stays) and prints the index notes of the stale items (json 3d, pfx null): `note: index: ...` lines after the other notes. Exit 0.
""")

# sh59 (a roc update guard) was dropped: `roc update` reads GitHub, not the registry, so no registry world exists for it.

# Q543 (round 4): the ladder unit facts are queued after the facts write of the ladder round. Expect files by hand (the code does not queue them yet).
if want("sh60-ladder-share"):
    d = fresh("share", "sh60-ladder-share", os.path.join(CASES, "registry/ef1-rank2-verify"))
    drop_ci(d)
    pinned_row(d)
    share_on(d)
    p = os.path.join(d, "fx/jobs")
    write(p, open(p).read().rstrip("\n") + "\nchmod 0600\t0\t-\t-\t-\n")
    rules(d, f"""R-SH2 R-SH3 R-SH4 R-LD2 R-PP4 (slice 206e4, Design Q543): `tln verify` with the world of registry/ef1-rank2-verify (held {H}; the tuple json 2.2.0, parser 1.2.0, pf 0.1.1; json 2.2.0 has a rank 2 `bot` `pass`), but `share = true`, no `CI`, `pinned` has the sha256 of ({H}, linux_x86_64), a share.json and a queue row HA of 0.0.1.
`verify` has no search probe. Ladder round 1 probes the baseline and the unit checks of parser 1.2.0 and pf 0.1.1 (`probes 3`, `db_write facts=2`). Right after that facts write the 2 unit facts are queued (filter 2: the baseline is not, and the later app build row is not): `platform`, `db_query pinned=1`, `clock`, `db_write queue=2`. The json fact is not probed (rank 2), so not queued. After the output the send: HA and the 2 unit rows in one POST, 201, `unqueue=3`, totals.
Written by hand: the code does not queue ladder facts yet.
""")

# Q450, Q535 in the ladder: a unit hash with no artifacts row gets its kind from the kept header text.
if want("sh61-ladder-share-header"):
    d = fresh("share", "sh61-ladder-share-header", os.path.join(CASES, "share/sh60-ladder-share"))
    p = route(d)
    a = json.load(open(p))
    a["artifacts"] = [r for r in a["artifacts"] if r["hash"] != "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt"]
    write(p, json.dumps(a, separators=(",", ":")))
    rules(d, f"""R-SH3 R-SH4 R-DI7 R-LD2 (slice 206e4, Design Q450, Q535, Q543): the world of share/sh60-ladder-share, but the answer has NO artifact record for parser 1.2.0 (EiSZ): a release row only. Its header `packages/EiSZ.../main.roc` (a package: target `any`) is there. Filter 7 takes the kind from the kept header text (read once for R-DI7, no second read). The ladder unit facts of parser and platform are queued as in sh60: `queue=2`, the same send of 3 rows.
Written by hand from sh60: the code skips this fact today.
""")
