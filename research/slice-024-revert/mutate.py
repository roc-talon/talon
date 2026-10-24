#!/usr/bin/env python3
"""Revert check of the private reference (TW12): each mutation changes one small thing in cli/lib/Manage.roc or cli/lib/RocManage.roc,
then runs the tests that should catch it (L0 file, L2 cases, L3 case). The file is put back after each one. Filtered runs only.
Usage: python3 -I research/slice-024-revert/mutate.py [id ...]   Output: one line per mutation, and results.md."""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")
ENV = dict(os.environ, XDG_CACHE_HOME=ROOT + "/.work/cache", ROC_CACHE_DIR=ROOT + "/.work/cache/roc", ROC=ROC)
MANAGE = "cli/lib/Manage.roc"
RM = "cli/lib/RocManage.roc"
RUN = "cli/lib/Run.roc"

# id, file, old text, new text, layers that must catch it (l0, l2, l3)
M = [
    ("M01", MANAGE, 'else if id.starts_with("link-") {\n\t\tLink', 'else if id.starts_with("link-") {\n\t\tGit', "l0"),
    ("M02", MANAGE, "Ok(d) => Pin.same_id(d, f.id)", "Ok(d) => d == f.id", "l0"),
    ("M03", MANAGE, 'if r.is_default "*" else " "', 'if r.is_default " " else " "', "l0 l2 l3"),
    ("M04", MANAGE, 'Err(Unknown) => "-"\n}\n\n', 'Err(Unknown) => ""\n}\n\n', "l0 l2"),
    ("M05", MANAGE, '("last_use", time_or_null(r.last_use)),', '("last_use", time_or_null(r.installed_at)),', "l0 l2"),
    ("M06", MANAGE, 'Ok(Value.String(old)) => if old == facts.id {', 'Ok(Value.String(old)) => if old == "never" {', "l0 l2"),
    ("M07", MANAGE, 'Toml.replace(doc, ["default-roc"], Value.String(facts.id))', 'Toml.insert(doc, ["default-roc"], Value.String(facts.id)) |> Try.map_err(|_| NoEntry)', "l0"),
    ("M08", MANAGE, 'Toml.remove(doc, ["default-roc"])', 'Toml.remove(doc, ["nightly"])', "l0 l3"),
    ("M09", MANAGE, "Local => Bool.False\n\t\t\t}", "Local => Bool.True\n\t\t\t}", "l0 l2 l3"),
    ("M10", MANAGE, "Nightly => facts.nightly", "Nightly => Bool.True", "l0 l2 l3"),
    ("M11", MANAGE, "if Pin.order({ a: id, b: best, times: facts.times }) == After id else best", "if Pin.order({ a: id, b: best, times: facts.times }) == Before id else best", "l0 l2 l3"),
    ("M12", MANAGE, "Ok(pin) => Pin.same_id(pin, id)", "Ok(pin) => pin == id", "l0 l2"),
    ("M13", MANAGE, 'Ok((_, Text(id))) => Ok(id)', 'Ok((_, Text(_))) => Err(None)', "l0 l2 l3"),
    ("M14", MANAGE, '"${facts.item}.${facts.hex}.trash"', '"${facts.item}.${facts.hex}.tmp"', "l0 l2"),
    ("M15", MANAGE, 'name = match facts.verb {\n\t\t\tDefault => "default"\n\t\t\tRemove => "remove"', 'name = match facts.verb {\n\t\t\tDefault => "default"\n\t\t\tRemove => "rm"', "l0 l2"),
    ("M16", MANAGE, '"known projects that pin ${facts.id} (the proxy installs it again when one runs):\\n"', '"known projects that pin ${facts.id}:\\n"', "l0 l2 l3"),
    ("M17", RM, "Ok(c) => [Roots.item(roots, Item.Compat(c))]", "Ok(c) => [Roots.item(roots, Item.Compat(\"none-${c}\"))]", "l2 l3"),
    ("M18", RM, "match fx.with_lock!(item, Wait, || trash!(fx, roots, item, compat)) {", "match Ok(trash!(fx, roots, item, compat)?) |> Try.map_err(|e| Failed(e)) {", "l2"),
    ("M19", RM, "if was_default {\n\t\tmove_default!(fx, roots, next)?\n\t}", "if was_default and id.is_empty() {\n\t\tmove_default!(fx, roots, next)?\n\t}", "l2 l3"),
    ("M20", RM, "if typed.starts_with(\"@\") {\n\t\tErr(NoMatch(typed))\n\t} else {", "if !typed.is_empty() {\n\t\tErr(NoMatch(typed))\n\t} else {", "l2"),
    ("M21", RM, "if asked.answer != Yes return Err(Consent.roc_install_declined(offer.id))", "if asked.answer != Yes and offer.size == 0 return Err(Consent.roc_install_declined(offer.id))", "l2"),
    ("M22", RM, 'Install.nightly_of(env), toml: Err(Unset)', 'Err(Unset), toml: Err(Unset)', "l2 l3"),
    ("M23", RM, "Err(Ambiguous(found)) => return Err(Nightlies.failure(Ambiguous(found)))", "Err(Ambiguous(_)) => return Err(Fail.new(Internal, \"ambiguous\"))", "l2"),
    ("M24", RM, "paths = known.map(|e| e.path)\n\tresults = read_all!(fx, paths)", "paths = known.map(|e| e.path)\n\tresults = []", "l2 l3"),
    ("M25", RM, "Item.ToolchainLastUse(id)", "Item.ToolchainMeta(id)", "l2"),
    ("M26", RM, "second = read_text!(fx, path)?\n\t\t\tagain = if second == first Ok({ previous: found.previous, edit: Set(edited) })", "second = first\n\t\t\tagain = if second == first Ok({ previous: found.previous, edit: Set(edited) })", "l2"),
    ("M27", RUN, 'args.command == ["roc", "list"]', 'args.command == ["roc", "listx"]', "l2 l3"),
    ("M28", RM, "match fx.with_lock!(item, Wait, || trash!(fx, roots, item, compat)) {", "match fx.with_lock!(item, NoWait, || trash!(fx, roots, item, compat)) {", "l2"),
    ("M29", MANAGE, "Pin.order({ a: id, b: best, times: facts.times })", "Pin.order({ a: id, b: best, times: [] })", "l0"),
]


def sh(cmd, **kw):
    return subprocess.run(cmd, shell=True, cwd=ROOT, env=ENV, capture_output=True, text=True, **kw)


def run_layers(layers):
    """Returns the layers that failed."""
    failed = []
    if "l0" in layers:
        r = sh(f"{ROC} test tests/unit/manage.roc")
        if r.returncode != 0:
            failed.append("l0")
    if "l2" in layers:
        r = sh("tests/commands/run.sh ls1-list df1-default rm1-remove")
        if r.returncode != 0:
            failed.append("l2")
    if "l3" in layers:
        b = sh(f"{ROC} build cli/main.roc --opt=dev --output=.work/mut/tln")
        if b.returncode != 0:
            failed.append("l3(build)")
        else:
            r = sh("TLN=$PWD/.work/mut/tln tests/run.sh mg1-manage")
            if r.returncode != 0:
                failed.append("l3")
    return failed


def main():
    want = sys.argv[1:]
    os.makedirs(os.path.join(ROOT, ".work/mut"), exist_ok=True)
    results = []
    for mid, path, old, new, layers in M:
        if want and mid not in want:
            continue
        full = os.path.join(ROOT, path)
        original = open(full).read()
        if old not in original:
            results.append((mid, "NOT APPLIED", layers, ""))
            print(mid, "NOT APPLIED")
            continue
        shutil.copy(full, full + ".orig")
        open(full, "w").write(original.replace(old, new, 1))
        try:
            check = sh(f"{ROC} check cli/main.roc")
            if check.returncode != 0:
                results.append((mid, "DOES NOT COMPILE", layers, check.stdout[-300:]))
                print(mid, "DOES NOT COMPILE")
            else:
                failed = run_layers(layers.split()) if layers else []
                missing = [l for l in layers.split() if l not in failed]
                state = "caught" if not missing and layers else ("not tested" if not layers else "NOT CAUGHT by " + " ".join(missing))
                results.append((mid, state, layers, " ".join(failed)))
                print(mid, state, "(failed:", " ".join(failed) + ")")
        finally:
            shutil.move(full + ".orig", full)
    with open(os.path.join(ROOT, "research/slice-024-revert/results.md"), "w") as f:
        f.write("| Id | Result | Layers that must catch it | Layers that failed |\n| --- | --- | --- | --- |\n")
        for mid, state, layers, failed in results:
            f.write(f"| {mid} | {state} | {layers} | {failed} |\n")


main()
