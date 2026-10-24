#!/usr/bin/env python3
"""Revert check of the code of slice 024 (TW12, filtered runs only, no full sweep).

For each mutation: the 4 files are put back from code-final/ first (a kill is safe), then one small change in one file, a `roc check`, then the tests that
should catch it, in the order l0, l2, l3. The first layer that fails ends the run of that mutation (CAUGHT). At the end the files are put back and compared
with code-final/ (the sha256 file code-final.sha256).

Usage: python3 -I research/slice-024-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the layer that failed, the test.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.join(ROOT, "research/slice-024-revert")
FINAL = os.path.join(HERE, "code-final")
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"), ROC=ROC)
FILES = ["Manage.roc", "RocManage.roc", "RocInstall.roc", "Run.roc"]
LIB = "cli/lib/"
TIMEOUT = {"l0": 180, "l2": 300, "l3": 400}
MA, RM, RI, RU = "Manage.roc", "RocManage.roc", "RocInstall.roc", "Run.roc"

# (id, file, old, new, layers that must catch it, what the change breaks)
M = [
    ("K01", MA, 'else if id.starts_with("link-") {\n\t\tLink', 'else if id.starts_with("link-") {\n\t\tGit', "l0", "R-LY1: a link is a git build"),
    ("K02", MA, "Ok(default) => Pin.same_id(default, item.id)", "Ok(default) => default == item.id", "l0", "R-CV1: the other tag form is not the default"),
    ("K03", MA, 'mark: if r.is_default "* " else "  ",', 'mark: if r.is_default "  " else "  ",', "l0", "R-OUT2: no star"),
    ("K04", MA, 'Err(Unknown) => "-"\n}', 'Err(Unknown) => ""\n}', "l0", "R-OUT2: no dash for an unknown time"),
    ("K05", MA, '("last_use", time_json(row.last_use)),', '("last_use", time_json(row.installed_at)),', "l0", "R-J3: last_use shows installed_at"),
    ("K06", MA, "Ok(Value.String(old)) if old == facts.id =>", 'Ok(Value.String(old)) if old == "never" =>', "l0", "R-CS2: the same value is a write"),
    ("K07", MA, "{ previous: Ok(old), edit: Set(done.to_str()) }", "{ previous: Ok(\"${old}x\"), edit: Set(done.to_str()) }", "l0", "R-J3: previous is lost on a replace"),
    ("K08", MA, 'Toml.remove(doc, ["default-roc"])', 'Toml.remove(doc, ["nightly"])', "l0", "R-RR1: another key is unset"),
    ("K09", MA, "\t\t\tRelease => Bool.True\n\t\t\t_ => Bool.False", "\t\t\tRelease => Bool.True\n\t\t\t_ => Bool.True", "l0", "R-NS6: a git build can be the next default"),
    ("K10", MA, "Nightly => facts.nightly", "Nightly => Bool.True", "l0", "R-NS3: the switch is ignored"),
    ("K11", MA, "== After id else best", "== Before id else best", "l0", "R-RR1: the oldest, not the newest"),
    ("K12", MA, "Ok(pin) => Pin.same_id(pin, facts.id)", "Ok(pin) => pin == facts.id", "l0", "R-RR2: the other tag form is not a pin"),
    ("K13", MA, "Ok(Text(id)) => Ok(id)", "Ok(Text(_)) => Err(None)", "l0", "R-GC3: no compat dir"),
    ("K14", MA, '"${facts.item}.${facts.hex}.trash"', '"${facts.item}.${facts.hex}.tmp"', "l0", "R-CC10: a temp name, not a trash name"),
    ("K15", MA, 'Remove => "remove"', 'Remove => "rm"', "l0", "R-CM19: the text names the short form"),
    ("K16", MA, '"known projects that pin ${facts.id} (the proxy installs it again when one runs):\\n"', '"known projects that pin ${facts.id}:\\n"', "l0", "R-RR2: the line of the projects"),
    ("K17", MA, 'Usage, "tln roc list takes no operand, got', 'Usage, "tln roc list takes no argument, got', "l0", "R-CM15: the text of `roc list x`"),
    ("K18", MA, 'if facts.installed ["installed ${facts.id}\\n", now] else [now]', "if facts.installed [now] else [now]", "l0", "R-OUT2: no `installed` line"),
    ("K19", MA, '("was_default", JsonDoc.Flag(facts.was_default)),', '("was_default", JsonDoc.Flag(Bool.False)),', "l0", "R-J3: was_default is always false"),
    ("K20", MA, '("default", text_or_null(facts.default.map_err(|Unset| None))),', '("default", JsonDoc.Null),', "l0", "R-J3: no default in the list data"),
    ("K21", RM, "Ok(compat) => [Roots.item(roots, Item.Compat(compat))]", 'Ok(compat) => [Roots.item(roots, Item.Compat("none-${compat}"))]', "l2", "R-GC3: another compat dir goes"),
    ("K22", RM, "fx.with_lock!(facts.item, Wait,", "fx.with_lock!(facts.item, NoWait,", "l2", "R-CC10: no wait for the item lock"),
    ("K23", RM, "if was_default {\n\t\tmove_default!(fx, roots, next)?\n\t}", "if was_default and id.is_empty() {\n\t\tmove_default!(fx, roots, next)?\n\t}", "l2", "R-RR1: the default does not move"),
    ("K24", RM, "Pin.switch({ env: Install.nightly_of(env),", "Pin.switch({ env: Err(Unset),", "l2", "R-NS3: TALON_NIGHTLY is not read"),
    ("K25", RM, 'if facts.text.starts_with("@") {', "if !facts.text.is_empty() {", "l2", "D1: the installed ids are not read first"),
    ("K26", RI, "if asked.answer == Yes Ok({}) else", "if asked.answer == Yes or asked.answer != Yes Ok({}) else", "l2", "R-NI6: a decline downloads"),
    ("K27", RM, "Err(error) => Err(Nightlies.failure(error))\n\t\t}", 'Err(_) => Err(Fail.new(Internal, "ambiguous"))\n\t\t}', "l2", "R-SC10: an ambiguous prefix is another failure"),
    ("K28", RM, "reads = fx.read_files!(entries.map(|entry| entry.path))", "reads = []", "l2", "R-RR2: the project files are not read"),
    ("K29", RM, "second = RocInstall.read_text!(fx, path)?", "second = first", "l2", "R-CC7: no second read before the write"),
    ("K30", RM, "Roots.item(roots, ToolchainLastUse(id))", "Roots.item(roots, ToolchainMeta(id))", "l2", "R-CC9: the wrong file for the last use"),
    ("K31", RU, 'args.command == ["roc", "list"]', 'args.command == ["roc", "listx"]', "l2", "R-CM19: no dispatch for `roc list`"),
    ("K32", RM, "Ok(default) => Pin.same_id(default, id)", "Ok(default) => default == id", "l2 l3", "R-CV1: the other tag form is not the default"),
    ("K33", RM, "reads = if ids.is_empty() [] else fx.read_files!(paths)", "reads = fx.read_files!(paths)", "l2", "D9: a read call with no path"),
    ("K35", RM, "first_default: done.default == Set,", "first_default: Bool.False,", "l2", "Q7: a download that sets the first default reports `already`"),
    ("K34", RM, "installed: done.how == Installed,", "installed: Bool.False,", "l2", "R-OUT2: a download is not reported"),
]

TESTS = {
    "l0": [ROC, "test", "tests/unit/manage.roc", "--no-cache"],
    "l2": ["tests/commands/run.sh", "ls1-list", "df1-default", "rm1-remove"],
    "l3": ["tests/run.sh", "mg1-manage"],
}


def restore():
    for f in FILES:
        shutil.copy(os.path.join(FINAL, f), os.path.join(ROOT, LIB, f))


def run(cmd, kind):
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, r.stdout + r.stderr


def run_layer(kind):
    if kind == "l3":
        out = os.path.join(ROOT, ".work/mut/tln")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        built = subprocess.run([ROC, "build", "cli/main.roc", "--opt=dev", f"--output={out}"], cwd=ROOT, env=ENV, capture_output=True, text=True)
        if built.returncode != 0:
            return True, "build failed: " + built.stdout[-200:]
        env = dict(ENV, TLN=out)
        try:
            r = subprocess.run(TESTS["l3"], cwd=ROOT, env=env, capture_output=True, text=True, timeout=TIMEOUT["l3"])
        except subprocess.TimeoutExpired:
            return True, "timeout"
        return r.returncode != 0, r.stdout + r.stderr
    return run(TESTS[kind], kind)


def main():
    want = set(sys.argv[1:])
    for mid, fname, old, new, layers, what in M:
        if want and mid not in want:
            continue
        restore()
        path = os.path.join(ROOT, LIB, fname)
        text = open(path).read()
        if text.count(old) != 1:
            print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
            continue
        open(path, "w").write(text.replace(old, new))
        try:
            built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
            if built.returncode != 0:
                print(f"{mid}: DID NOT COMPILE ({what}) " + (built.stdout + built.stderr)[:300].replace("\n", " "), flush=True)
                continue
            caught = None
            for kind in ["l0", "l2", "l3"]:
                if kind in layers.split():
                    failed, _ = run_layer(kind)
                    if failed:
                        caught = kind
                        break
            print(f"{mid}: {'CAUGHT' if caught else 'NOT CAUGHT'} by {caught or '-'} ({what})", flush=True)
        finally:
            restore()
    restore()
    same = subprocess.run(["sha256sum", "-c", os.path.join(HERE, "code-final.sha256")], cwd=ROOT, capture_output=True, text=True)
    print("compare with code-final:", "SAME" if same.returncode == 0 else "DIFFERENT\n" + same.stdout, flush=True)


main()
