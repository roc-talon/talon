#!/usr/bin/env python3
"""Makes the L2 cases tests/commands/cases/roc/us2-workspace and us3-step (slice 026b). Run from the repo root.
It writes only the inputs. The expected files come from UPDATE=1 and are read by hand (TW21)."""
import os, shutil

N = "nightly-2026-10-14-38a3029"   # the new compiler
O = "nightly-2026-10-09-258ab27"
M = "nightly-2026-10-13-91fa0c2"
PF = "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst"
JSON = "https://github.com/acme/json/releases/download/2.0.0/7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21.tar.zst"

def header(pin):
    lines = ["app [main!] {", f'\tpf: platform "{PF}",', f'\tjson: "{JSON}",']
    if pin:
        lines.append(f'\troc: "{pin}",')
    lines += ["}", "", "main! = |_args| Ok({})", ""]
    return "\n".join(lines)

def meta(cid):
    day = cid.split("-")
    return ('{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":null,"installed_at":"2026-10-20T12:00:00Z","published_at":"%s-%s-%sT15:00:00Z"}'
            % (cid, cid, cid, day[1], day[2], day[3]))

class Case:
    def __init__(self, root):
        self.root = root
        if os.path.exists(root):
            shutil.rmtree(root)
    def put(self, path, text):
        full = os.path.join(self.root, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as f:
            f.write(text)
    def installed(self, home, cid):
        self.put(f"given/{home}/.cache/roc/toolchains/{cid}/roc", "fake")
        self.put(f"given/{home}/.cache/roc/toolchains/{cid}/.talon.json", meta(cid))
    def common(self, commands):
        self.put("entry", "commands\n")
        self.put("fx/commands", "\n".join(f"{c}\n{r}" for c, r in commands) + "\n")
        self.put("fx/env", "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
        self.put("fx/gitdirs", ".\n")
        self.put("fx/programs", "curl\nwget\ntar\n")
        self.put("fx/tty", "stdin=true\nstderr=true\n")

PASS = "0\t../fixtures/check/out/pass.stdout\t../fixtures/check/out/pass.stderr"
BUILD = "0\t../fixtures/check/out/build-pass.stdout\t../fixtures/check/out/build-pass.stderr"

# --- us2-workspace
c = Case("tests/commands/cases/roc/us2-workspace")
c.put("given/project/talon.toml", '[workspace]\nmembers = ["apps/*/main.roc"]\n')
c.put("given/project/apps/a/main.roc", header(O))
c.put("given/project/apps/b/main.roc", header(M))
c.put("given/project/apps/c/main.roc", header(None))
c.put("given/project/apps/d/main.roc", header("nightly-2026-October-14-38a3029"))
c.put("given/project/w2/talon.toml", '[workspace]\nmembers = ["apps/*/main.roc"]\n')
c.put("given/project/w2/apps/a/main.roc", header(O))
c.put("given/project/w2/apps/b/main.roc", header(O))
for cid in (O, N, M):
    c.installed("home", cid)
c.put("given/home/.config/talon/config.toml", f'default-roc = "{O}"\n')
c.common([
    (f"# R-CS1 R-WS13 R-WS4 R-U3 R-BL1 R-RP3 R-H1 (question Q5): a workspace of 4 members, in the root (no current member). apps/a has the pin O, apps/b has the pin M (two pins: `update` and `install` stop for this with exit 2, and name `tln roc use`: R-WS4), apps/c has no pin (its baseline is the global default O), apps/d has the pin N already, in the other tag form (R-H1: no probe, no write, no line). `roc use` writes the entry of each member that changes. Each member has its own baseline (the compiler of its own pin), so each member that changes is checked: 3 rounds of probes, the lines have the file of the member in front. Nothing is written before all 3 passed.",
     f"roc use {N}"),
    (f"# R-U3 R-H6 R-WS13 R-EC11 (question Q5): a second workspace (w2) with 2 members. apps/b has a new error in the candidate. The check of apps/a passed, but no member is written: exit 11, both headers stay.",
     f"roc use {N} --file w2/apps/a/main.roc"),
])
probes = ["# run 1: 3 members, each with the baseline, the candidate check and the build", PASS, PASS, BUILD, PASS, PASS, BUILD, PASS, PASS, BUILD,
          "# run 2: apps/a passes all 3 probes, apps/b has a new error in an app file (main.roc has a duplicate definition): exit 11", PASS, PASS, BUILD, PASS,
          "1\t../fixtures/check/out/dup.stdout\t../fixtures/check/out/dup.stderr"]
c.put("fx/probes", "\n".join(probes) + "\n")

# --- us3-step
s = Case("tests/commands/cases/roc/us3-step")
s.put("given/project/main.roc", header(N))
shutil.copytree("tests/commands/cases/roc/up1-update/fx/http", "tests/commands/cases/roc/us3-step/fx/http")
for cid in (N, M):
    s.installed("home", cid)
s.common([
    (f"# R-SL7 R-PD16 R-CS1 R-U3: a step as the operand. The base is the compiler that Resolution 13 selects for main.roc of the current directory: the pin N (rank 3), so @-1 is M, which is installed (no download). The baseline runs on N, the candidate and the build on M. The same command moves a pin to an older nightly.",
     "roc use @-1"),
])
