# Slice 054, revert check of the code agent: 10 hand mutations of the most tricky parts, filtered runs only (no full sweep).
# Run from the repo root: python3 -I research/slice-054-revert/agent-mutate.py [id ...]
# Each mutation changes one file of cli/lib, runs `roc check` and the tests that must see it, and puts the file back from code-final/.
# A mutation that no test catches is printed as OPEN. At the end `sha256sum -c code-final.sha256` must pass.
import subprocess, sys, os, shutil

ROOT = os.getcwd()
FINAL = "research/slice-054-revert/code-final/cli/lib"
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")

L0 = ("l0-3", ["env", "XDG_CACHE_HOME=" + ROOT + "/.work/cache", "ROC_CACHE_DIR=" + ROOT + "/.work/cache/roc", ROC, "test", "tests/unit/l0-3.roc"])


def l2(*filters):
    return ("l2 " + " ".join(filters), ["tests/commands/run.sh", *filters])


# id, file, old text, new text, tests
MUTATIONS = [
    ("M1 host: glibc before musl (R-TG1 rule 2)", "BuildTarget.roc",
     '(Linux, X64) => ["x64musl", "x64glibc"]', '(Linux, X64) => ["x64glibc", "x64musl"]', [L0, l2("target/tg1-ladder")]),
    ("M2 pick: rule 2 takes the order of the platform list, not of the host (R-TG1)", "BuildTarget.roc",
     "match x.host.find_first(|name| list.contains(name))", "match list.find_first(|name| x.host.contains(name))", [L0]),
    ("M3 pick: the one platform target wins over [build] target (R-TG1 rule 1)", "BuildTarget.roc",
     "Ok(name) => Ok(Named(name))\n\t\tErr(Unset) => match x.found {",
     "Ok(name) => match x.found {\n\t\t\tOk([one]) => Ok(Named(one))\n\t\t\t_ => Ok(Named(name))\n\t\t}\n\t\tErr(Unset) => match x.found {", [L0]),
    ("M4 R-C10: the solver gets the facts with no gate", "PickLoop.roc",
     "snapshot: input.snapshot, facts: gated,", "snapshot: input.snapshot, facts: state.facts,", [l2("target/tg3-constraint")]),
    ("M5 R-C10: no release is exit 2, not exit 10", "BuildTarget.roc",
     "no_release = |x| Fail.new(NoTuple,", "no_release = |x| Fail.new(Usage,", [L0, l2("target/tg3-constraint")]),
    ("M6 R-TG5: the member file has no target (member_target is always Unset)", "ResolveBase.roc",
     "Ok(t) => t.intent.build.target", "Ok(_) => Err(Unset)", [l2("target/tg2-workspace", "target/tg1-ladder")]),
    ("M7 R-TG4: the [build] of a package file is exit 19", "Intent.roc",
     "(App, Ok(note)) =>", "(_, Ok(note)) =>", [L0, l2("target/tg1-ladder")]),
    ("M8 R-TG2: the build gets no --target but the key has the target", "BuildFlow.roc",
     "id: Ok({ key, digest }), target: chosen })", "id: Ok({ key, digest }), target: Unlisted })", [l2("target/tg1-ladder", "target/tg2-workspace")]),
    ("M9 R-C10: the platform of the header is not read first", "PickLoop.roc",
     "if !unread.is_empty() return", "if Bool.False and !unread.is_empty() return", [l2("target/tg3-constraint", "target/tg2-workspace")]),
    ("M10 R-TG2: --target at the end of the arguments", "LadderPlan.roc",
     '["build", "--target=${name}"].concat(rest)', '["build"].concat(rest).append("--target=${name}")', [L0, l2("target/tg1-ladder")]),
]


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    return r.returncode, r.stdout + r.stderr


def main():
    want = sys.argv[1:]
    for title, name, old, new, tests in MUTATIONS:
        mid = title.split()[0]
        if want and mid not in want:
            continue
        path = "cli/lib/" + name
        text = open(path).read()
        if text.count(old) != 1:
            print(f"{mid}: SKIP, the old text occurs {text.count(old)} times")
            continue
        open(path, "w").write(text.replace(old, new))
        try:
            rc, out = run([ROC, "check", "cli/lib/main.roc"])
            if rc != 0:
                print(f"{mid}: DOES NOT COMPILE\n{out[-600:]}")
                continue
            caught = []
            for label, cmd in tests:
                rc, out = run(cmd)
                if rc != 0:
                    caught.append(label)
            print(f"{title}: " + ("CAUGHT by " + ", ".join(caught) if caught else "OPEN (not caught)"), flush=True)
        finally:
            shutil.copyfile(f"{FINAL}/{name}", path)
    bad = [n for n in os.listdir(FINAL) if open(f"{FINAL}/{n}").read() != open(f"cli/lib/{n}").read()]
    print("files that differ from code-final:", bad or "none")


main()
