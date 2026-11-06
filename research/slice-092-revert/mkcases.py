#!/usr/bin/env python3
"""Makes the L2 case dirs of slices 092 and 093 (prebuilt project tool binaries): the fixed files of the cases
(given/, fx/), from the world of tests/commands/cases/ptool/pt3-move. The expected files come from UPDATE=1 and are
read by hand. Usage: mkcases.py <name> ...   (names: pt6 pt7 pt8 pt9 pt10 pt11 pt12 pt13)"""
import hashlib, json, os, shutil, sys
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CASES = REPO + "/tests/commands/cases/ptool"
BASE = CASES + "/pt3-move"
H = {"foo11": "AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY", "foo10": "GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW",
     "bar10": "2CLmeph6kVSdi6orXdVymPEDaudFDtB28sm3zpnsvmGN", "baz10": "4yUwFgumMQiw7gVYVnMSCTXy4LBkVmyhCUrdQHexZGRu",
     "pf": "CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA"}
C1 = "1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d"
C2 = "ffffffffffffffffffffffffffffffffffffffff"
WF = "https://github.com/acme/foo/.github/workflows/release.yml@refs/tags/1.1.0"
def sha(text): return hashlib.sha256(text.encode()).hexdigest()
def blob(target, version="1.1.0", app="foo"): return "binary of acme/%s %s for %s\n" % (app, version, target)
def url(app, ver, h): return "https://github.com/acme/%s/releases/download/%s/%s.tar.zst" % (app, ver, h)
def att(commit): return json.dumps([{"verificationResult": {"signature": {"certificate": {"sourceRepositoryDigest": commit, "buildSignerURI": WF}}}}], separators=(",", ":"))

def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)

def base(name, rules, entry="commands"):
    d = CASES + "/" + name
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d + "/fx/src"); os.makedirs(d + "/given/project")
    shutil.copytree(BASE + "/given/home", d + "/given/home")
    for f in ("gitdirs", "path-roc", "env", "probes"):
        shutil.copy(BASE + "/fx/" + f, d + "/fx/" + f)
    for f in ("platform-basic-cli.src", "foo-1.0.0.src", "foo-1.1.0.src"):
        shutil.copy(BASE + "/fx/src/" + f, d + "/fx/src/" + f)
    shutil.copytree(BASE + "/fx/http/api.github.com/repos/roc-lang", d + "/fx/http/api.github.com/repos/roc-lang")
    w(d + "/entry", entry + "\n")
    w(d + "/fx/programs", "curl\nwget\ntar\ngh\n")
    return d

def main_roc(d, p):
    shutil.copy(BASE + "/given/project/p1/main.roc", d + "/given/project/%s/main.roc" % p) if os.path.isdir(d + "/given/project/" + p) else (os.makedirs(d + "/given/project/" + p), shutil.copy(BASE + "/given/project/p1/main.roc", d + "/given/project/%s/main.roc" % p))

def releases(d, binaries, extra_assets=()):
    """The list of acme/foo (1.1.0 and 1.0.0) and the release 1.1.0 with binary assets and digests. binaries: {target: sha}."""
    lst = '[\n{"tag_name":"1.1.0","draft":false,"prerelease":false,"published_at":"2026-09-01T12:00:00Z","assets":[{"name":"%s.tar.zst","size":1048576,"browser_download_url":"%s"}]},\n{"tag_name":"1.0.0","draft":false,"prerelease":false,"published_at":"2026-08-01T12:00:00Z","assets":[{"name":"%s.tar.zst","size":1048576,"browser_download_url":"%s"}]}\n]\n' % (H["foo11"], url("foo", "1.1.0", H["foo11"]), H["foo10"], url("foo", "1.0.0", H["foo10"]))
    assets = [{"name": H["foo11"] + ".tar.zst", "size": 1048576, "digest": "sha256:" + "0" * 64}]
    for t, s in binaries.items():
        assets.append({"name": H["foo11"] + "-" + t + (".exe" if t == "x64win" else ""), "size": 100, "digest": "sha256:" + s})
    # Q9: in direct mode the digests are in the release list (R-DI2), no `releases/tags` call.
    src = {"name": H["foo11"] + ".tar.zst", "size": 1048576, "digest": "sha256:" + "0" * 64, "browser_download_url": url("foo", "1.1.0", H["foo11"])}
    old = '"assets":[{"name":"%s.tar.zst","size":1048576,"browser_download_url":"%s"}]},\n{"tag_name":"1.0.0"' % (H["foo11"], url("foo", "1.1.0", H["foo11"]))
    assert old in lst
    lst = lst.replace(old, '"assets":%s},\n{"tag_name":"1.0.0"' % json.dumps([src] + assets[1:]))
    w(d + "/fx/http/api.github.com/repos/acme/foo/releases%3Fper_page=100", lst)
    for t in binaries:
        w(d + "/fx/src/bin-" + t, blob(t))

def jobs(d, extra=()):
    lines = ["# R-PT20: `gh` (the help run, auth, the verify runs), the downloads, R-FE2 `roc unbundle`. The first rule whose needle is in the arguments answers. `@<n>|` is for the n-th run only."]
    lines += list(extra)
    base_jobs = open(BASE + "/fx/jobs").read().splitlines()
    keep = [l for l in base_jobs if l.startswith("version") or l.startswith("unbundle " + H["pf"]) or l.startswith("unbundle " + H["foo11"]) or l.startswith("unbundle " + H["foo10"])]
    lines += keep + ["curl --fail\t0\t-\t-\tfile:{out}"]
    w(d + "/fx/jobs", "\n".join(lines) + "\n")

def dl(t, ver="1.1.0", app="foo", h=None):
    h = h or H["foo11"]
    return "releases/download/%s/%s-%s%s\t0\t-\t-\tcopy:{out}={w}/fx/src/bin-%s" % (ver, h, t, ".exe" if t == "x64win" else "", t)

def gh_rules(verify):
    """verify: {target: ('ok', commit) | ('fail', text)}; the bundle always gives C1."""
    r = ["--help\t0\t-\t-\t-", "gh auth status\t0\t-\t-\t-", "tar.zst --repo acme/foo\t0\t%s\t-\t-" % att(C1)]
    for t, (kind, v) in verify.items():
        r.append("%s --repo acme/foo\t%s" % (t, ("0\t%s\t-\t-" % att(v)) if kind == "ok" else ("1\t-\t%s\t-" % v)))
    return r

def tools_toml(d, p, text):
    w(d + "/given/project/%s/talon.toml" % p, text)
    main_roc(d, p)

def foo_line(ver, h, bin_=None, key="foo", ref="acme/foo@^1"):
    b = ""
    if bin_ is not None:
        b = ", bin = false" if bin_ is False else ", bin = { %s }" % ", ".join("%s = \"%s\"" % kv for kv in sorted(bin_.items()))
    return "%s = { ref = \"%s\", url = \"%s\"%s }\n" % (key, ref, url("foo", ver, h), b)

def cmds(d, lines): w(d + "/fx/commands", "\n".join(lines) + "\n")

def rules(d, text): w(d + "/rules", text)

SHAS = {t: sha(blob(t)) for t in ("x64musl", "arm64mac", "x64mac", "x64win", "arm64musl")}
PF = ""

def pt6():
    d = base("pt6-bin-lock", None)
    releases(d, {"x64musl": SHAS["x64musl"], "arm64mac": SHAS["arm64mac"], "x64mac": SHAS["x64mac"]})
    verify = {"x64musl": ("ok", C1), "arm64mac": ("ok", C2), "x64mac": ("fail", "Error: no attestations found")}
    extra = ["@3|arm64mac --repo acme/foo\t0\t%s\t-\t-" % att(C1)] + gh_rules(verify) + [dl(t) for t in ("x64musl", "arm64mac", "x64mac")]
    jobs(d, extra)
    tools_toml(d, "p1", "[tools]\n" + foo_line("1.0.0", H["foo10"]))
    cmds(d, ["update --tool --json --file p1/main.roc"] + ["update --tool --file p1/main.roc"] * 2)
    rules(d, open(os.path.dirname(__file__) + "/rules/pt6.txt").read())

def home_with(d, name, config):
    shutil.copytree(d + "/given/home", d + "/given/" + name)
    w(d + "/given/%s/.config/talon/config.toml" % name, config)

def comment(text): return "# " + text

def pt7():
    d = base("pt7-bin-skip", None)
    releases(d, {"x64musl": SHAS["x64musl"], "arm64mac": SHAS["arm64mac"]})
    verify = {"x64musl": ("ok", C1), "arm64mac": ("ok", C1)}
    extra = ["@1|--help\t1\t-\tError: unknown flag: --source-ref\t-", "@2|gh auth status\t1\t-\tYou are not logged into any GitHub hosts. To log in, run: gh auth login\t-", "@3|tar.zst --repo acme/foo\t1\t-\tError: no attestations found for the file\t-"] + gh_rules(verify) + [dl(t) for t in ("x64musl", "arm64mac")]
    jobs(d, extra)
    for p in ("p1", "p2", "p3"):
        tools_toml(d, p, "[tools]\n" + foo_line("1.0.0", H["foo10"]))
    cmds(d, ["update --tool%s --file p%d/main.roc" % (" --json" if n == 1 else "", n) for n in (1, 2, 3)])

def pt7b():
    d = base("pt7b-bin-no-gh", None)
    releases(d, {"x64musl": SHAS["x64musl"]})
    jobs(d, gh_rules({"x64musl": ("ok", C1)}) + [dl("x64musl")])
    w(d + "/fx/programs", "curl\nwget\ntar\n")
    tools_toml(d, "p1", "[tools]\n" + foo_line("1.0.0", H["foo10"]))
    cmds(d, ["update --tool --file p1/main.roc"])

def pt8():
    d = base("pt8-bin-update", None)
    releases(d, {"x64musl": SHAS["x64musl"], "arm64mac": SHAS["arm64mac"], "x64mac": SHAS["x64mac"]})
    verify = {"x64musl": ("ok", C1), "arm64mac": ("ok", C1), "x64mac": ("ok", C1)}
    jobs(d, gh_rules(verify) + [dl(t) for t in ("x64musl", "arm64mac", "x64mac")])
    home_with(d, "home2", "tool-binaries = false\n")
    stale = {"x64musl": "a" * 64}
    tools_toml(d, "p1", "[tools]\n" + foo_line("1.1.0", H["foo11"], stale))
    tools_toml(d, "p2", "[tools]\n" + foo_line("1.1.0", H["foo11"], False))
    tools_toml(d, "p3", "[tools]\n" + foo_line("1.1.0", H["foo11"], stale))
    tools_toml(d, "p4", "[tools]\n" + foo_line("1.0.0", H["foo10"], stale))
    cmds(d, ["update --tool --file p1/main.roc", "update --tool --file p2/main.roc", "env:HOME={w}/home2 update --tool --file p3/main.roc", "env:HOME={w}/home2 update --tool --file p4/main.roc", "add --tool acme/foo --file p2/main.roc"])

def pt9():
    d = base("pt9-bin-digest", None)
    releases(d, {"x64musl": SHAS["x64musl"], "arm64mac": SHAS["arm64mac"]})
    # the release digest of x64musl is not the sha256 of the file
    p = d + "/fx/http/api.github.com/repos/acme/foo/releases%3Fper_page=100"
    text = open(p).read()
    open(p, "w").write(text.replace(SHAS["x64musl"], "0" * 64))
    jobs(d, gh_rules({"x64musl": ("ok", C1), "arm64mac": ("ok", C1)}) + [dl(t) for t in ("x64musl", "arm64mac")])
    tools_toml(d, "p1", "[tools]\n" + foo_line("1.0.0", H["foo10"]))
    cmds(d, ["update --tool --file p1/main.roc"])

def pt10():
    d = base("pt10-bin-dry-run", None)
    releases(d, {"x64musl": SHAS["x64musl"], "arm64mac": SHAS["arm64mac"]})
    jobs(d, gh_rules({"x64musl": ("ok", C1), "arm64mac": ("ok", C1)}) + [dl(t) for t in ("x64musl", "arm64mac")])
    tools_toml(d, "p1", "[tools]\n" + foo_line("1.0.0", H["foo10"]))
    tools_toml(d, "p2", "[tools]\n" + foo_line("1.1.0", H["foo11"], {"x64musl": "a" * 64}))
    cmds(d, ["update --tool --dry-run --file p1/main.roc", "update --tool --dry-run --json --file p2/main.roc"])

def pt11():
    d = base("pt11-bin-use", None)
    releases(d, {"x64musl": SHAS["x64musl"]})
    jobs(d, [dl("x64musl")])
    ok = {"x64musl": SHAS["x64musl"]}
    tools_toml(d, "p1", "[tools]\n" + foo_line("1.1.0", H["foo11"], ok))
    tools_toml(d, "p2", "[tools]\n" + foo_line("1.1.0", H["foo11"], {"x64musl": "b" * 64}))
    tools_toml(d, "p3", "[tools]\n" + foo_line("1.1.0", H["foo11"], {"arm64mac": SHAS["arm64mac"]}))
    cmds(d, ["install --frozen --json --file p1/main.roc", "install --frozen --file p1/main.roc", "install --frozen --file p2/main.roc", "install --frozen --file p3/main.roc"])

def pt12():
    d = base("pt12-bin-fallback", None)
    releases(d, {"x64musl": SHAS["x64musl"]})
    jobs(d, ["releases/download/1.1.0/%s-x64musl\t22\t-\tcurl: (22) The requested URL returned error: 404\t-" % H["foo11"], dl("x64musl")])
    ok = {"x64musl": SHAS["x64musl"]}
    home_with(d, "home2", "tool-binaries = false\n")
    shutil.copytree(d + "/given/home", d + "/given/home3")
    tools_toml(d, "p1", "[tools]\n" + foo_line("1.1.0", H["foo11"], ok))
    tools_toml(d, "p2", "[tools]\n" + foo_line("1.1.0", H["foo11"], ok))
    tools_toml(d, "p3", "[tools]\n" + foo_line("1.1.0", H["foo11"], False))
    cmds(d, ["install --frozen --file p1/main.roc", "env:HOME={w}/home2 install --frozen --file p2/main.roc", "env:HOME={w}/home3 install --frozen --file p3/main.roc"])

def pt13():
    d = base("pt13-bin-frozen-stop", None)
    for app, ver, key in (("bar", "1.0.0", "bar"), ("baz", "1.0.0", "baz")):
        pass
    jobs(d, [dl("x64musl"), dl("x64musl", "1.0.0", "bar", H["bar10"]).replace("copy:{out}={w}/fx/src/bin-x64musl", "copy:{out}={w}/fx/src/bar-x64musl"), dl("x64musl", "1.0.0", "baz", H["baz10"])])
    releases(d, {"x64musl": SHAS["x64musl"]})
    w(d + "/fx/src/bar-x64musl", blob("x64musl", "1.0.0", "bar"))
    toml = "[tools]\n" + foo_line("1.1.0", H["foo11"], {"x64musl": SHAS["x64musl"]})
    toml += "bar = { ref = \"acme/bar@^1\", url = \"%s\", bin = { x64musl = \"%s\" } }\n" % (url("bar", "1.0.0", H["bar10"]), "c" * 64)
    toml += "baz = { ref = \"acme/baz@^1\", url = \"%s\", bin = { x64musl = \"%s\" } }\n" % (url("baz", "1.0.0", H["baz10"]), SHAS["x64musl"])
    tools_toml(d, "p1", toml)
    cmds(d, ["install --frozen --file p1/main.roc"])

def pt14():
    d = base("pt14-bin-none", None)
    releases(d, {})
    jobs(d, [])
    tools_toml(d, "p1", "[tools]\n" + foo_line("1.0.0", H["foo10"]))
    cmds(d, ["update --tool --file p1/main.roc"] * 2)

if __name__ == "__main__":
    for n in sys.argv[1:]:
        globals()[n]()
