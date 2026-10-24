#!/usr/bin/env python3
"""Revert check of the code of slice 020 (TW12, filtered runs only, no full sweep).

For each mutation: one small change in one file of cli/lib, a `roc check`, then only the tests that should catch it. The first test that fails ends the run
of that mutation (CAUGHT). The final code is kept in research/slice-020-revert/code-final/. Both files are copied from there at the start of each mutation
and after it, so a kill between 2 mutations leaves the final code. `compare` at the end shows that the code is the same.

Usage: python3 -I research/slice-020-revert/code-mutate.py [id ...]     (from the repo root)
Output: one line for each mutation: id, CAUGHT or NOT CAUGHT, the test that failed.
"""
import os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", os.path.join(ROOT, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ENV = dict(os.environ, XDG_CACHE_HOME=os.path.join(ROOT, ".work/cache"), ROC_CACHE_DIR=os.path.join(ROOT, ".work/cache/roc"))
LIB = os.path.join(ROOT, "cli/lib")
FINAL = os.path.join(ROOT, "research/slice-020-revert/code-final")
FILES = ["Nightlies.roc", "Github.roc"]
TIMEOUT = {"l0": 120, "l2": 300, "l3": 300}
L0 = ["l0:nightlies"]
CL = ["l3:compilers/cl1", "l3:compilers/cl2"]

# (id, file, [(old, new)], [tests], what the change breaks)
M = [
    ("T1", "Nightlies.roc", [('MacosApple => "macos_apple_silicon"', 'MacosApple => "macos_apple"')], L0, "R-CV8: the target of macOS arm"),
    ("T2", "Nightlies.roc", [("Ok(i) => Ok(i + 1)", "Ok(i) => Ok(i)")], L0, "R-CV1: a month name gives its index from 0"),
    ("R1", "Nightlies.roc", [(" or Nightlies.parts(tag) == Err(NotNightly)", "")], L0, "R-CV1: a tag that is no nightly stays"),
    ("R2", "Nightlies.roc", [('is_true(pairs, "draft") or ', "")], L0, "R-DI3: a draft stays"),
    ("R3", "Nightlies.roc", [(' or is_true(pairs, "prerelease")', "")], L0, "R-DI3: a prerelease stays"),
    ("R4", "Nightlies.roc", [("read_release(facts.host, acc, doc).map_err(|_| BadPage(n))", "read_release(facts.host, acc, doc).map_err(|_| BadPage(1))")], L0, "R-CV1: the number of the bad page"),
    ("A1", "Nightlies.roc", [('"roc_nightly-${Nightlies.target(host)}-"', '"roc_nightly-${Nightlies.target(host)}"')], L0, "R-CV2: the prefix has no `-` after the target"),
    ("A2", "Nightlies.roc", [("WindowsX64 | WindowsArm64 => \".zip\"", "WindowsX64 => \".zip\"")], L0, "R-CV7: Windows arm64 has .tar.gz"),
    ("A3", "Nightlies.roc", [("name.ends_with(extension)", 'name.ends_with(extension) or name.ends_with(".zip") or name.ends_with(".tar.gz")')], L0, "R-CV7: each extension is accepted"),
    ("A4", "Nightlies.roc", [("[one] => Ok(one)\n\t\t[] => Err(NoAsset)\n\t\tmany => Err(Several(many.len()))", "[one, .. as _rest] => Ok(one)\n\t\t[] => Err(NoAsset)")], L0, "R-CV2: 2 assets give the first"),
    ("A5", "Nightlies.roc", [("hex.count_utf8_bytes() == 64", "hex.count_utf8_bytes() >= 64")], L0, "R-CV3: a sha256 of more than 64 digits"),
    ("A6", "Nightlies.roc", [('digest.starts_with("sha256:") and ', "")], L0, "R-CV3: a digest with no `sha256:`"),
    ("A7", "Nightlies.roc", [("n.to_u64_wrap() else 0", "0 else 0")], L0, "R-CV2: the size is 0"),
    ("A8", "Nightlies.roc", [('url: text_field(pairs, "browser_download_url")', 'url: text_field(pairs, "name")')], L0, "R-CV2: the URL is the name"),
    ("O1", "Nightlies.roc", [("[p.year, p.month, p.day, r.published_at]", "[p.year, p.month, p.day]")], L0, "R-NS1: no `published_at` in the order"),
    ("O2", "Nightlies.roc", [("Same => Text.compare(a.id, b.id)", "Same => Same")], L0, "R-NS1: no tag text in the order"),
    ("V1", "Nightlies.roc", [("age >= facts.min_age", "age > facts.min_age")], L0, "R-RU1: exactly the age is hidden"),
    ("V2", "Nightlies.roc", [("r.published_at <= at", "r.published_at < at")], L0, "R-DT4: a release at the snapshot time is hidden"),
    ("V3", "Nightlies.roc", [("facts.keep.contains(r.id) or ", "")], L0, "R-C9: a kept id is hidden"),
    ("C1", "Nightlies.roc", [("list.keep_if(|r| r.asset.is_ok())", "list.keep_if(|r| r.asset.is_ok() or !r.asset.is_ok())")], L0, "R-CV2: each nightly is a candidate"),
    ("P1", "Nightlies.roc", [("facts.auto.last()", "facts.auto.first()")], L0, "R-SL5: @latest is the oldest"),
    ("P2", "Nightlies.roc", [("target = i.to_i64_wrap() + n", "target = i.to_i64_wrap() - n")], L0, "R-SL7: the sign of a step"),
    ("P3", "Nightlies.roc", [("auto.find_first_index(|id| id == b or same_nightly(id, b))", "auto.find_first_index(|id| id == b)")], L0, "R-CV1: the base in the other tag form is not found"),
    ("P4", "Nightlies.roc", [("Err(NotFound) => Err(BaseNotListed(b))", "Err(NotFound) => Err(NoBase)")], L0, "Q3: a base that is not listed"),
    ("P5", "Nightlies.roc", [("if target < 0 {\n\t\t\t\tErr(OutOfRange({ base: from, step: n }))", "if target < 0 {\n\t\t\t\tErr(OutOfRange({ base: from, step: 0 }))")], L0, "R-SL7: the step in OutOfRange"),
    ("P6", "Nightlies.roc", [("(Ok(x), Ok(y)) => x == y", "(Ok(x), Ok(y)) => x.year == y.year and x.month == y.month and x.day == y.day")], L0, "R-CV1: the other tag form with another sha"),
    ("P7", "Nightlies.roc", [("ids => Err(Ambiguous({ text, ids }))", "[first, .. as _rest] => Ok(first)")], L0, "R-SC10: an ambiguous prefix gives the first id"),
    ("P8", "Nightlies.roc", [('facts.text.drop_prefix("@")', "facts.text")], L0, "D8: the `@` is not dropped"),
    ("F1", "Nightlies.roc", [("Empty => Fail.new(NoTuple,", "Empty => Fail.new(Usage,")], L0, "R-NS2: the kind of Empty"),
    ("F2", "Nightlies.roc", [('if step < 0 "older" else "newer"', 'if step < 0 "newer" else "older"')], L0, "the words older and newer are swapped"),
    ("L1", "Nightlies.roc", [('repo: "nightlies"', 'repo: "nightly"')], CL, "R-DI2: the repository"),
    ("L2", "Nightlies.roc", [('Err(Fail.new(Network, "page', 'Err(Fail.new(Usage, "page')], CL, "R-DI2: the kind of a bad page"),
    ("G1", "Github.roc", [("Ok(Arr(_)) => Bool.True", "Ok(_) => Bool.True")], CL, "G3: a page that is no array is cached"),
]


def put_back():
    for f in FILES:
        shutil.copyfile(os.path.join(FINAL, f), os.path.join(LIB, f))


def run(test):
    kind, _, arg = test.partition(":")
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{arg}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh"] + arg.split()
    else:
        cmd = ["tests/run.sh"] + arg.split()
    try:
        r = subprocess.run(cmd, cwd=ROOT, env=ENV, capture_output=True, text=True, timeout=TIMEOUT[kind])
    except subprocess.TimeoutExpired:
        return True, "timeout"
    return r.returncode != 0, (r.stdout + r.stderr)


def main():
    want = set(a for a in sys.argv[1:] if a != "compare")
    if "compare" in sys.argv[1:]:
        same = all(open(os.path.join(FINAL, f)).read() == open(os.path.join(LIB, f)).read() for f in FILES)
        print("code is the same as before the mutations" if same else "CODE DIFFERS")
        return
    for mid, fname, edits, tests, what in M:
        if want and mid not in want:
            continue
        put_back()
        path = os.path.join(LIB, fname)
        text = open(path).read()
        for old, new in edits:
            if text.count(old) != 1:
                print(f"{mid}: BAD EDIT ({text.count(old)} matches of {old[:60]!r})", flush=True)
                break
            text = text.replace(old, new)
        else:
            try:
                open(path, "w").write(text)
                built = subprocess.run([ROC, "check", "cli/lib/main.roc"], cwd=ROOT, env=ENV, capture_output=True, text=True)
                if built.returncode != 0:
                    print(f"{mid}: DID NOT COMPILE ({what}) " + built.stdout[:300].replace("\n", " "), flush=True)
                    continue
                caught_by = None
                for t in tests:
                    failed, _ = run(t)
                    if failed:
                        caught_by = t
                        break
                print(f"{mid}: {'CAUGHT' if caught_by else 'NOT CAUGHT'} by {caught_by or '-'} ({what})", flush=True)
            finally:
                put_back()


main()
