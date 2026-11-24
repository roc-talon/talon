#!/usr/bin/env python3
# Slice 261c (test agent): makes the inputs of the L2 cases tests/commands/cases/logproof/* from 2 old cases (registry/ad35-add-latest, registry/ix6-update-offline),
# and the fake logs with tests/tools/mk-log.mjs. It writes no expected file: the expected files are written by hand (docs/slices/261-log-inclusion-proofs.md section 14).
# Usage (repo root): python3 research/slice-261c-tests/mk-cases.py
import json, os, shutil, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tests/commands/cases")
OUT = os.path.join(CASES, "logproof")
ADD_BASE = os.path.join(CASES, "registry/ad35-add-latest")
OFF_BASE = os.path.join(CASES, "registry/ix6-update-offline")

KNOWN = "github.com/acme/known/releases/download/{v}/"
L1 = f"{KNOWN} 1.0.0 5UVYbRk4zTJP7MLG5AAaTwK2TmX3U1bdndvNzddMyTaV 1790848800000"
L2 = f"{KNOWN} 1.1.0 24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL 1790848800000"
L2_OTHER = f"{KNOWN} 1.1.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK 1790848800000"
KEY_L8 = "127.0.0.1:8/log+103a4665+AVe39KgFjJZCyKJq5RMF6DDELMicWhqw/y2J3GSpbE2P"
ADD = "add acme/known --no-check --file p1/main.roc"
EVIL = "https://github.com/acme/known/releases/download/1.1.0/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst"  # the group form and version of acme/known, another hash (section 15)
GOOD = "https://github.com/acme/known/releases/download/1.1.0/24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL.tar.zst"
LOG = {"host": "127.0.0.1:9", "leaves": {"1": L1, "2": L2}}


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def case(name, base, commands, rules, spec=None, key=True, env_extra="", config=None, project=None, mtimes=None, url=None):
    d = os.path.join(OUT, name)
    if os.path.isdir(d):
        shutil.rmtree(d)
    shutil.copytree(base, d, ignore=shutil.ignore_patterns("expect", "rules"))
    put(os.path.join(d, "fx/commands"), "".join(c + "\n" for c in commands))
    put(os.path.join(d, "rules"), rules + "\n")
    line = ""
    if spec is not None:
        put(os.path.join(d, "mk-log.json"), json.dumps(spec, indent=1) + "\n")
        line = subprocess.run(["node", os.path.join(ROOT, "tests/tools/mk-log.mjs"), d], check=True, capture_output=True, text=True).stdout.strip()
    env = open(os.path.join(d, "fx/env")).read()
    if key and line:
        env += line + "\n"
    env += env_extra
    put(os.path.join(d, "fx/env"), env)
    if config is not None:
        put(os.path.join(d, "given/home/.config/talon/config.toml"), config)
    if project is not None:
        put(os.path.join(d, "given/project/p1/main.roc"), project)
    if mtimes is not None:
        put(os.path.join(d, "fx/mtimes"), mtimes)
    if url is not None:
        for f in ["fx/http/127.0.0.1%3A9/v1/closure.POST", "fx/http/127.0.0.1%3A9/v1/packages/acme/known/releases"]:
            p = os.path.join(d, f)
            put(p, open(p).read().replace(GOOD, url))
        # Section 15: the hash of that URL has an artifact record in the closure answer, so the closure walk needs no download before the check.
        p = os.path.join(d, "fx/http/127.0.0.1%3A9/v1/closure.POST")
        a = json.loads(open(p).read())
        a["artifacts"].append({"hash": url.split("/")[-1].removesuffix(".tar.zst"), "kind": "package", "exposed": [], "platform_hash": None, "roc_pin": None, "size": 1000, "deps": [], "target_names": []})
        put(p, json.dumps(a, separators=(",", ":")))


def serve(*sizes, **kw):
    s = dict(LOG)
    s["serve"] = [{"file": "checkpoint" if i == 0 else f"checkpoint.{i + 1}", "size": n} for i, n in enumerate(sizes)]
    s.update(kw)
    return s


R = "(slice 261c, entry `commands`; the world of registry/ad35-add-latest: `tln add acme/known` picks known 1.1.0, log index 2, from the registry http://127.0.0.1:9 of config.toml)."
case("lp1-add-proof", ADD_BASE, [ADD],
     f"R-LV1 R-LV2 R-LV3 R-LV4 R-LV5 R-LV6 R-LV7 R-LV8 R-LV12 R-IX8 R-EV30 {R} TALON_LOG_KEY is a test key with the name 127.0.0.1:9/log (tests/tools/mk-log.mjs, mk-log.json). The log has size 3. The check runs after the closure query and before the header write: the kept checkpoint (none), one checkpoint read, one read of the tile copies (none), the entry bundle and the level 0 tile with http_get_bytes, then one write of the copies (text form) and of the checkpoint, then the header. Exit 0, no new output line (R-LV12).",
     serve(3))
case("lp2-kept-copies", ADD_BASE, [ADD],
     f"R-LV6 R-LV7 R-IX8 {R} The kept checkpoint (size 3) and the tile copies are in the given home: the check reads them and sends no request and writes no copy.",
     dict(LOG, kept={"size": 3}))
case("lp3-bad-signature", ADD_BASE, [ADD, ADD + " --json"],
     f"R-LV4 R-LV11 R-EC16 R-J7 {R} The checkpoint is signed by another test key with the same name (another key id): exit 16, T3 with the key 127.0.0.1:9/log+56ce7b6e and the source TALON_LOG_KEY. No tile read, no write. Run 2: --json, error.details with size, index and release null (a proposal).",
     dict(serve(3), serve=[{"file": "checkpoint", "size": 3, "key": "talon slice 261c test key M"}]))
case("lp4-entry-differs", ADD_BASE, [ADD],
     f"R-LV2 R-LV11 R-EC16 {R} The entry at log index 2 has another hash: exit 16, T1, nothing written (no header, no copy).",
     dict(serve(3), leaves={"1": L1, "2": L2_OTHER}))
case("lp5-tile-tampered", ADD_BASE, [ADD],
     f"R-LV3 R-LV11 R-EC16 {R} The served level 0 tile has one changed byte in the hash of index 1: the proof does not give the signed root: exit 16, T2, nothing written.",
     serve(3, tamper=[{"path": "tile/0/000.p/3", "byte": 40}]))
case("lp6-behind", ADD_BASE, [ADD],
     f"R-LV9 R-LV6 R-LV12 {R} The checkpoint has size 1 on reads 1 and 2 and size 3 on read 3 (checkpoint.2, checkpoint.3): sleep 2000 and sleep 4000 before reads 2 and 3, then the proof passes: exit 0.",
     serve(1, 1, 3))
case("lp6b-behind-four-reads", ADD_BASE, [ADD],
     f"R-LV9 R-LV11 R-EC15 {R} The checkpoint has size 1 on each of the 4 reads (sleep 2000, 4000, 8000 before reads 2 to 4): exit 15, T5, nothing written.",
     serve(1))
case("lp7-no-answer", ADD_BASE, [ADD, ADD + " --json"],
     f"R-LV11 R-EC15 R-RG9 R-J7 {R} Run 1: the checkpoint route answers 404: exit 15, T6 with the cause `status 404`. Run 2 (--json): the 2nd checkpoint request ends in a timeout (checkpoint.2.meta): exit 15, T6 with `timeout`, error.details with size null.",
     None)
put(os.path.join(OUT, "lp7-no-answer/fx/http/127.0.0.1%3A9/log/checkpoint.2.meta"), "error timeout\n")
case("lp7b-tile-missing", ADD_BASE, [ADD, ADD + " --json"],
     f"R-LV7 R-LV11 R-EC15 R-J7 {R} The level 0 tile of size 3 answers 404: exit 15, T6b with the tile path and `status 404`, nothing written. Run 2: --json, error.details (index and release null, a proposal).",
     serve(3, omit=["tile/0/000.p/3"]))
case("lp8-fork", ADD_BASE, [ADD],
     f"R-LV10 R-LV11 R-EC16 R-IX8 {R} The kept checkpoint has size 1 and another leaf 1; the served checkpoint (size 3) does not contain it: exit 16, T4 with the kept size, the date of the kept file (fx/mtimes: 2026-10-14) and its path, nothing written. The consistency tile comes first in the tile reads.",
     dict(serve(3), kept={"size": 1, "leaves": {"1": f"{KNOWN} 1.0.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK 1790848800000"}, "tiles": False}),
     mtimes="log/http_127.0.0.1_9/checkpoint 1791979200\n")
RO = "(slice 261c, entry `commands`; the world of registry/ix6-update-offline: `tln update --offline` moves json to 2.1.0 (log index 25) and parser to 1.2.0 (log index 35) from the kept index copies of http://127.0.0.1:9)."
OFF = {"host": "127.0.0.1:9", "leaves": {"25": "github.com/acme/json/releases/download/{v}/ 2.1.0 4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq 1790337600000",
                                        "35": "github.com/acme/parser/releases/download/{v}/ 1.2.0 EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt 1791201600000"}}
case("lp9-offline", OFF_BASE, ["update --no-check --dry-run --offline --file u1/main.roc"],
     f"R-IX8 R-IX6 R-LV6 R-LV7 R-LV8 {RO} The kept checkpoint (size 36) and the tile copies prove both releases: no request, no write, exit 0.",
     dict(OFF, kept={"size": 36}))
case("lp9b-offline-no-proof", OFF_BASE, ["update --no-check --dry-run --offline --file u1/main.roc"],
     f"R-IX8 R-IX6 R-LV11 R-EC15 {RO} No kept checkpoint: exit 15, T7 for the first release in log index order (json), no request.",
     OFF)
case("lp10-no-key", ADD_BASE, [ADD],
     f"R-LV5 {R} TALON_LOG_KEY names the log 127.0.0.1:8/log, and no key applies to http://127.0.0.1:9: no check, no log request, no note. The output is the output of today.",
     None, env_extra=f"TALON_LOG_KEY={KEY_L8}\n")
case("lp11-bad-env", ADD_BASE, [ADD + " env:TALON_LOG_KEY=xyz", ADD + " --json env:TALON_LOG_KEY=xyz"],
     f"R-LV5 R-EV30 R-LV11 R-J7 {R} TALON_LOG_KEY=xyz: exit 2, T8b, at the check point (after the closure query, a proposal), nothing written. Run 2: --json, reason bad-key.",
     None)
case("lp11b-bad-config", ADD_BASE, [ADD, ADD + " --json"],
     f"R-LV5 R-TF4 R-LV11 R-J7 {R} log-key = \"xyz\" in config.toml (line 2): exit 19, T8, nothing written. Run 2: --json.",
     None, config='registry = "http://127.0.0.1:9"\nlog-key = "xyz"\n')
case("lp11c-trimmed-env", ADD_BASE, [ADD],
     f"R-LV5 R-EV30 (slice 261 13.7 N1) {R} TALON_LOG_KEY has a space before the key and a tab after it: the trimmed key applies: the proof of lp1-add-proof, exit 0.",
     serve(3), key=False)
case("lp11d-trimmed-config", ADD_BASE, [ADD],
     f"R-LV5 (slice 261 13.7 N1) {R} log-key in config.toml has spaces around the key: the trimmed key applies: the proof of lp1-add-proof, exit 0.",
     serve(3), key=False)
case("lp11e-space-inside", ADD_BASE, [ADD],
     f"R-LV5 R-TF4 R-LV11 (slice 261 13.7 N1) {R} log-key in config.toml has a space inside the key: exit 19, T8 with the text (trimmed), nothing written.",
     serve(3), key=False)
case("lp12-dry-run-json", ADD_BASE, [ADD + " --dry-run", ADD + " --dry-run --json"],
     f"R-LV8 R-LV2 R-LV11 R-J7 {R} --dry-run and --no-check check too: the entry at log index 2 has another hash: exit 16, T1. Run 2: --json, error.details of T1.",
     dict(serve(3), leaves={"1": L1, "2": L2_OTHER}))
case("lp13-kept-values", ADD_BASE, ["install --no-check --file p1/main.roc", "update --no-check --file p1/main.roc"],
     f"R-LV1 (Design R-SE2) {R} The header has known 1.1.0 already. install and update write no new value, so nothing is checked: no log request (the log has no route, so a request would fail the run).",
     None, project='app [main!] {\n\tpf: platform "https://github.com/acme/pfx/releases/download/0.1.0/6ELEWECd4np7xs4pF1M2Acyy9ZXcKsJN36LKrNFDuoBL.tar.zst",\n\tknown: "' + GOOD + '",\n\troc: "nightly-2026-10-14-38a3029",\n}\n\nmain! = |_args| Ok({})\n')
case("lp15-url-differs", ADD_BASE, [ADD],
     f"R-LV2 R-LV11 R-EC16 {R} The registry rows of known 1.1.0 have a URL with the group form and version of acme/known and another hash (closure answer and R-AP1 answer; the closure answer has an artifact record of that hash); the leaf has the row hash: exit 16, T2b, nothing written.",
     serve(3), url=EVIL)

# The trimmed and bad keys of lp11c to lp11e.
key_l9 = subprocess.run(["node", os.path.join(ROOT, "tests/tools/mk-log.mjs"), os.path.join(OUT, "lp1-add-proof")], check=True, capture_output=True, text=True).stdout.strip().split("=", 1)[1]
d = os.path.join(OUT, "lp11c-trimmed-env/fx/env")
put(d, open(d).read() + f"TALON_LOG_KEY= {key_l9}\t\n")
put(os.path.join(OUT, "lp11d-trimmed-config/given/home/.config/talon/config.toml"), f'registry = "http://127.0.0.1:9"\nlog-key = "  {key_l9}  "\n')
name, kid, data = key_l9.split("+", 2)
put(os.path.join(OUT, "lp11e-space-inside/given/home/.config/talon/config.toml"), f'registry = "http://127.0.0.1:9"\nlog-key = "{name}+{kid} +{data}"\n')
print("ok")
