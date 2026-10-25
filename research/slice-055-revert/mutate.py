# Slice 055, revert check of the test agent: 10 hand mutations of the most tricky behaviors of the private reference, filtered runs only (no full sweep).
# (The reference was deleted at the review, 2026-10-24: the script is a record.) Run from the repo root with the reference in cli/lib: python3 -I research/slice-055-revert/mutate.py [id ...]
# Each mutation changes one file of cli/lib, runs `roc check` and the tests that must see it, and puts the file back from reference/.
# A mutation that no test catches is printed as OPEN. At the end the files of cli/lib must equal the reference.
import subprocess, sys, os, shutil

ROOT = os.getcwd()
REF = "research/slice-055-revert/reference/cli/lib"
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = ["env", "XDG_CACHE_HOME=" + ROOT + "/.work/cache", "ROC_CACHE_DIR=" + ROOT + "/.work/cache/roc"]


def l0(driver):
    return (driver, ENV + [ROC, "test", "--no-cache", "tests/unit/" + driver + ".roc"])


def l2(*filters):
    return ("l2 " + " ".join(filters), ["tests/commands/run.sh", *filters])


L3 = ("l3 path", ["tests/run.sh", "path/"])

# id, file, old text, new text, tests
MUTATIONS = [
    ("M1 entry_starts: any bracket after a comma starts an entry (R-IN8)", "InitStub.roc",
     '(with_open and next.text == "[")', '(with_open and is_kind(next, Open))', [l0("l0-3")]),
    ("M2 entry_starts: any word after a comma starts an entry, not `name :` only (R-IN8)", "InitStub.roc",
     "or (is_kind(next, Word) and is_kind(tok_at(toks, $k + 2), Colon))", "or is_kind(next, Word)", [l0("l0-3"), l2("init/it2-platform")]),
    ("M3 stub_of: `()` counts as one argument (R-SM2)", "InitStub.roc",
     "count = if args.len() == 2 and is_kind(tok_at(args, 0), Open) and is_kind(tok_at(args, 1), Close) 0 else pieces(args).len()", "count = pieces(args).len()", [l0("l0-3"), l2("init/it2-platform", "init/it1-app")]),
    ("M4 tokens: a comment is read as tokens (R-IN8)", "InitStub.roc",
     "if b == '#' {", "if b == '#' and Bool.False {", [l0("l0-3"), l2("init/it2-platform")]),
    ("M5 stub_of: the message names the whole record type, not the field (OP8)", "InitStub.roc",
     "value = stub_of(f.drop_first(2), indent + 1)?", "value = stub_of(f.drop_first(2), indent + 1) ? |_| type_text(toks)", [l0("l0-3")]),
    ("M6 pick: a path entry is seen from the project file, not from its directory (R-PTH1)", "PathCmd.roc",
     "Text.resolve(Text.dir_of(x.file), row.value)", "Text.resolve(x.file, row.value)", [l0("l0-7"), l2("path/pt1-entry"), L3]),
    ("M7 run!: the project is not recorded (R-PTH4)", "PathFlow.roc",
     "Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, project), now: start.now })?", "{}", [l2("path/pt1-entry"), L3]),
    ("M8 init: the default platform also gets the stub (R-IN1, OP8)", "Init.roc",
     "if name == InitText.default_platform {", "if Bool.False and name == InitText.default_platform {", [l2("init/it2-platform")]),
    ("M9 init: --offline does not reach the fetch of the platform (R-FE7)", "Init.roc",
     "urls: [facts.url], offline: facts.offline", "urls: [facts.url], offline: Bool.False", [l2("init/it2-platform")]),
    ("M10 run!: a file in the directory of the entry is read (R-PTH5)", "PathFlow.roc",
     "\tOk(entry)\n}", "\t_ = fx.read_files!([\"${entry.dir}/main.roc\"])\n\tOk(entry)\n}", [l2("path/pt1-entry")]),
    # the changes of the review (2026-10-24): one mutation each
    ("R1 Q1: path at a workspace root with no current member does not check the member", "PathFlow.roc",
     "Install.check_member(Bool.True, project)?", "Install.check_member(Bool.False, project)?", [l2("path/pt1-entry")]),
    ("R2 Q4: init does not make the stub again after the platform moved", "Init.roc",
     "or !here.moved.any(|m| m.alias == \"pf\")", "or Bool.True", [l2("init/it3-platform-moved")]),
    ("R3 Q6: a clause with 2 or more entries gets the stub of its entries", "InitStub.roc",
     "} else if $out.len() > 1 {", "} else if $out.len() > 100 {", [l0("l0-3")]),
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
            rc, out = run(ENV + [ROC, "check", "cli/lib/main.roc"])
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
            shutil.copyfile(f"{REF}/{name}", path)
    bad = [n for n in os.listdir(REF) if open(f"{REF}/{n}").read() != open(f"cli/lib/{n}").read()]
    print("files that differ from the reference:", bad or "none")


main()
