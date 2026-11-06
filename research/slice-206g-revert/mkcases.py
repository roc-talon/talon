#!/usr/bin/env python3
"""Slice 206g: the L2 cases of the registry compiler list in the roc commands (R-CV1, R-IX4, R-IX6, R-CV5).
The fixtures (given, fx) are made here. The expect files of the cases with a world that exists are made from the expect files of the
direct run of that world (the GitHub list), with one change: each read of the compiler list is the registry read (R-CV1, R-IX4, R-IX6).
  python3 -I research/slice-206g-revert/mkcases.py base    the worlds with a GitHub list, into research/slice-206g-revert/ref/cases/ (a private reference tree).
                                                           Run each with: UPDATE=1 L2BIN=research/slice-206g-revert/ref/l2bin CASES=research/slice-206g-revert/ref/cases tests/commands/run.sh
  python3 -I research/slice-206g-revert/mkcases.py final   the cases of tests/commands/cases/registry/ and the 3 sh62 guards of share/ (rows, routes, expect)
`final` DELETES and makes again the dirs of the NEW cases, and rewrites the expect of the 3 guards from research/slice-206g-revert/before/.
No code of cli/ is used."""
import datetime, json, os, re, shutil, sys

ROOT = os.getcwd()
CASES = os.path.join(ROOT, "tests/commands/cases")
REGC = os.path.join(CASES, "registry")
SHARE = os.path.join(CASES, "share")
HERE = os.path.join(ROOT, "research/slice-206g-revert")
REF = os.path.join(HERE, "ref/cases")
BEFORE = os.path.join(HERE, "before")
HOST = "127.0.0.1%3A9"
RDIR = "$HOME/.cache/roc/talon/index/registry/http_127.0.0.1_9"
GH = "api.github.com/repos/roc-lang/nightlies"
GHFILE = "releases%3Fper_page=100"
TC_META = "status 200\nheader content-type: application/json\nheader cache-control: max-age=300\n"
CFG = 'registry = "http://127.0.0.1:9"\n'


def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def rd(path):
    with open(path) as f:
        return f.read()


def cp(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.isdir(src):
        shutil.copytree(src, dst, symlinks=True, dirs_exist_ok=True)
    else:
        shutil.copy(src, dst)


def fresh(path):
    shutil.rmtree(path, ignore_errors=True)
    os.makedirs(path)


def j(v):
    return json.dumps(v, separators=(",", ":"))


def ms(iso):
    t = datetime.datetime.strptime(iso, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
    return int(t.timestamp()) * 1000


def rows_of(gh_text):
    """The registry rows of a GitHub list of nightlies: the linux_x86_64 asset of each release, the log index grows with the date."""
    rels = sorted(json.loads(gh_text), key=lambda r: r["published_at"])
    rows = []
    for i, r in enumerate(rels):
        a = [x for x in r["assets"] if "linux_x86_64" in x["name"]][0]
        rows.append({"tag": r["tag_name"], "target": "linux_x86_64", "asset_name": a["name"], "sha256": a["digest"][len("sha256:"):],
                     "size": a["size"], "published_at": ms(r["published_at"]), "log_index": (i + 1) * 10})
    return rows


def put_route(case_fx, rows):
    v1 = os.path.join(case_fx, "http", HOST, "v1")
    w(os.path.join(v1, "toolchains%3Fafter=0"), j({"toolchains": rows, "more": False}))
    w(os.path.join(v1, "toolchains%3Fafter=0.meta"), TC_META)


def drop_github(case_fx):
    d = os.path.join(case_fx, "http", GH)
    shutil.rmtree(d, ignore_errors=True)
    parent = os.path.dirname(d)
    while parent != os.path.join(case_fx, "http") and os.path.isdir(parent) and not os.listdir(parent):
        os.rmdir(parent)
        parent = os.path.dirname(parent)


def kept_file(rows):
    return j({"format": 1, "rows": rows}) + "\n"


# ---------------------------------------------------------------- the transform of an expect (direct -> registry)
FIRST = re.compile(r"list_dirs (\$HOME/\.cache/roc/talon/index/github/roc-lang/nightlies)\nprograms gh\nhttp_get https://api\.github\.com/repos/roc-lang/nightlies/releases\?per_page=100\n  User-Agent: tln/0\.0\.1\n"
                   r"write_atomic \S+/1\.json \S+/1\.meta\n(db_query \S+ busy_ms=5000 format=1 pinned=\d+\n)(db_write \S+ busy_ms=5000 format=1 pinned=\d+\n)")
LATER = re.compile(r"list_dirs \$HOME/\.cache/roc/talon/index/github/roc-lang/nightlies\nread_files \S+/1\.meta \S+/1\.json\n(db_query \S+ busy_ms=5000 format=1 pinned=\d+\n)")


def calls_to_registry(text, offline_first=False):
    tj = RDIR + "/toolchains.json"
    first = [0]

    def f1(m):
        first[0] += 1
        if offline_first:
            return f"read_files {tj}\nlist_dirs {RDIR}\n{m.group(2)}{m.group(3)}"
        return (f"read_files {tj}\nhttp_get http://127.0.0.1:9/v1/toolchains?after=0\n  User-Agent: tln/0.0.1\n"
                f"write_atomic {tj}\n{m.group(2)}{m.group(3)}")

    def f2(m):
        return f"read_files {tj}\nlist_dirs {RDIR}\n{m.group(1)}"

    # the first read of a run is the one with the request; a second one (a run after it in the same file, or a later read) is a kept read
    out, pos, seen = [], 0, False
    pat = re.compile(FIRST.pattern + "|" + LATER.pattern)
    for m in pat.finditer(text):
        out.append(text[pos:m.start()])
        if m.group(0).startswith("list_dirs") and "programs gh" in m.group(0):
            m1 = FIRST.match(m.group(0))
            out.append(f1(m1) if not seen else (_ for _ in ()).throw(SystemExit("two first reads")))
            seen = True
        else:
            out.append(f2(LATER.match(m.group(0))))
        pos = m.end()
    out.append(text[pos:])
    res = "".join(out)
    if "nightlies" in res and "index/github/roc-lang/nightlies" in res or "api.github.com/repos/roc-lang/nightlies" in res:
        raise SystemExit("GitHub nightlies call left:\n" + "\n".join(l for l in res.splitlines() if "nightlies" in l and "releases/download" not in l))
    return res


def hunks_of(text):
    out, cur = [], None
    for line in text.splitlines(keepends=True):
        if line.startswith("--- "):
            cur = [line.split(" ", 1)[1].strip(), [line]]
            out.append(cur)
        else:
            cur[1].append(line)
    return out


def tree_to_registry(text, rows=None):
    hs = [h for h in hunks_of(text) if h[0] != "home/.cache/roc/talon/index/github/roc-lang/nightlies/1.json"]
    if rows is not None:
        p = "home/.cache/roc/talon/index/registry/http_127.0.0.1_9/toolchains.json"
        hs.append([p, [f"--- {p}\n", f"+++ {p}\n", "@@ -0,0 +1 @@\n", "+" + kept_file(rows)]])
    hs.sort(key=lambda h: h[0].encode())
    return "".join("".join(h[1]).replace("github-digest", "registry") for h in hs)


def transform_case(src_expect, dst_expect, rows, offline_first=False, kept=False):
    os.makedirs(dst_expect, exist_ok=True)
    for name in os.listdir(src_expect):
        s = rd(os.path.join(src_expect, name))
        if name == "calls.log":
            s = calls_to_registry(s, offline_first)
        elif name == "tree.diff":
            s = tree_to_registry(s, None if kept else rows)
        w(os.path.join(dst_expect, name), s)


# ---------------------------------------------------------------- the worlds
def world_install_like(dst, src, gh_in_src, commands, *, keep_given):
    """A fresh case dir `dst` from the dir `src`: entry, fx (all), and the listed given paths."""
    fresh(dst)
    cp(os.path.join(src, "entry"), os.path.join(dst, "entry"))
    cp(os.path.join(src, "fx"), os.path.join(dst, "fx"))
    for g in keep_given:
        cp(os.path.join(src, "given", g), os.path.join(dst, "given", g))
    w(os.path.join(dst, "fx/commands"), commands)



def put_share(d):
    """`share = true` and a share.json (as share/sh62-no-send-roc-install): with no share.json a registry run asks for the share consent (FirstRun), which these cases do not test."""
    cp(os.path.join(SHARE, "sh62-no-send-roc-install/given/home/.local/share/talon/share.json"), os.path.join(d, "given/home/.local/share/talon/share.json"))

def build(name, mode):
    """mode base: the world with the GitHub list (the reference tree). mode final: the registry route, no GitHub list."""
    root = REF if mode == "base" else REGC
    d = os.path.join(root, name)
    return d


def finish(d, mode, rows, cfg_home="home"):
    if mode == "final":
        put_route(os.path.join(d, "fx"), rows)
        drop_github(os.path.join(d, "fx"))


def make(mode):
    shutil.rmtree(REF, ignore_errors=True) if mode == "base" else None
    R = os.path.join(CASES, "roc")
    # ---- cv1-roc-use: `roc use` with N missing (us1-use run 5: home2, p6)
    src = os.path.join(R, "us1-use")
    d = build("cv1-roc-use", mode)
    world_install_like(d, src, True, "roc use nightly-2026-10-14-38a3029 --file p6/main.roc\n", keep_given=["project/p6"])
    cp(os.path.join(src, "given/home2/.cache"), os.path.join(d, "given/home/.cache"))
    shutil.rmtree(os.path.join(d, "fx/hooks"), ignore_errors=True)
    # the fx/env of us1-use has HOME home; the run of the case is in home2: set it in fx/env
    w(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
    w(os.path.join(d, "fx/jobs"), rd(os.path.join(src, "fx/jobs")).replace("home2", "home") + "")
    w(os.path.join(d, "given/home/.config/talon/config.toml"), 'default-roc = "nightly-2026-10-09-258ab27"\n' + CFG + "share = true\n")
    put_share(d)
    rows_use = rows_of(rd(os.path.join(src, "fx/http", GH, GHFILE)))
    finish(d, mode, rows_use)
    # ---- cv1-roc-default: `roc default N`, N missing, no default yet (df1-default, home2: a registry in config.toml and nothing else)
    src = os.path.join(R, "df1-default")
    d = build("cv1-roc-default", mode)
    world_install_like(d, src, True, "roc default nightly-2026-10-13-91fa0c2\n", keep_given=[])
    # `share = true` and a share.json: with no share.json the first default of a registry run asks for the share consent (FirstRun), which this case does not test
    w(os.path.join(d, "given/home/.config/talon/config.toml"), CFG + "share = true\n")
    cp(os.path.join(SHARE, "sh62-no-send-roc-install/given/home/.local/share/talon/share.json"), os.path.join(d, "given/home/.local/share/talon/share.json"))
    w(os.path.join(d, "fx/answers"), "\n")
    rows_def = rows_of(rd(os.path.join(src, "fx/http", GH, GHFILE)))
    finish(d, mode, rows_def)
    # ---- cv1-proxy-range: the proxy, rank 4 (a range, no installed compiler), a person (px2-install, run p2)
    src = os.path.join(CASES, "proxy/px2-install")
    d = build("cv1-proxy-range", mode)
    world_install_like(d, src, True, "@roc check p2/main.roc\n", keep_given=["project/p2"])
    w(os.path.join(d, "given/home/.config/talon/config.toml"), CFG)
    rows_px = rows_of(rd(os.path.join(src, "fx/http", GH, GHFILE)))
    finish(d, mode, rows_px)
    # ---- ix6-roc-update-offline: `roc update --offline`, a kept toolchains.json, the newest allowed compiler installed (base: the same world online with the GitHub list)
    src = os.path.join(R, "up1-update")
    d = build("ix6-roc-update-offline", mode)
    world_install_like(d, src, True, "roc update --offline\n" if mode == "final" else "roc update\n", keep_given=[])
    rows_up = rows_of(rd(os.path.join(src, "fx/http", GH, GHFILE)))
    for tc in ("nightly-2026-10-09-258ab27", "nightly-2026-10-18-5349569"):
        cp(os.path.join(src, "given/home8/.cache/roc/toolchains", tc), os.path.join(d, "given/home/.cache/roc/toolchains", tc))
    w(os.path.join(d, "given/home/.config/talon/config.toml"), 'default-roc = "nightly-2026-10-18-5349569"\n' + CFG + "share = true\n")
    put_share(d)
    # no GitHub list is needed by the run of the registry: drop the other GitHub routes (the nightlies list stays in the base tree only)
    shutil.rmtree(os.path.join(d, "fx/http/api.github.com/repos/acme"), ignore_errors=True)
    if mode == "final":
        w(os.path.join(d, "given/home/.cache/roc/talon/index/registry/http_127.0.0.1_9/toolchains.json"), kept_file(rows_up))
        drop_github(os.path.join(d, "fx"))
    # ---- cv1-roc-install-unread: no route for the compiler list (404, not problem details): the failure of the list is exit 15
    if mode == "final":
        src = os.path.join(SHARE, "sh62-no-send-roc-install")
        d = build("cv1-roc-install-unread", mode)
        fresh(d)
        cp(os.path.join(src, "entry"), os.path.join(d, "entry"))
        for f in ("answers", "tty", "env", "jobs", "programs", "platform", "locks"):
            cp(os.path.join(src, "fx", f), os.path.join(d, "fx", f))
        w(os.path.join(d, "fx/commands"), "roc install nightly-2026-10-09-258ab27\n")
        w(os.path.join(d, "given/home/.config/talon/config.toml"), CFG + "share = true\n")
        cp(os.path.join(src, "given/home/.local/share/talon/share.json"), os.path.join(d, "given/home/.local/share/talon/share.json"))
    return {"cv1-roc-use": rows_use, "cv1-roc-default": rows_def, "cv1-proxy-range": rows_px, "ix6-roc-update-offline": rows_up}


RULES = {
    "cv1-roc-install-unread": "R-CV1 R-E6 R-EC15 (slice 206g, Design Q489): `tln roc install nightly-2026-10-09-258ab27` with the registry of config.toml and a compiler list that cannot be read (`GET /v1/toolchains?after=0` answers 404, an error answer that is not problem details). The rule of `direct` applies (Q489: a list that cannot be read is not an empty list): the command must choose a compiler, so it fails with the failure of the list, exit 15, and the text of RegistryToolchains (as registry/cv1-upgrade-unread, run 2). One request, no GitHub call, no prompt, nothing written. The share files are those of share/sh62-no-send-roc-install (share = true, a share.json), so the first-run notice of the share consent does not enter the case.",
    "ix6-roc-update-offline": "R-IX6 R-IX4 R-CV1 R-RU1 R-CV5 (slice 206g, Design Q490): `tln roc update --offline` with the registry of config.toml and a kept `toolchains.json` (12 rows, as the GitHub list of roc/up1-update). The compiler list is the kept rows at any age: no request, no GitHub cache, no exit 15. Both 258ab27 and the newest allowed nightly (5349569, 4 days old, min-release-age 2 days) are installed and 5349569 is the default, so the text is `<id> is the newest` and nothing is written except the first-sighting rows of `pinned` (source `registry`, R-CV6; as registry/ix6-offline-upgrade). No `index: cached at` line (Q490: toolchains.json is not a copy for that line).",
    "cv1-roc-use": "R-CV1 R-IX4 R-CV5 R-U2 R-CS1 (slice 206g): `tln roc use nightly-2026-10-14-38a3029 --file p6/main.roc` with the registry of config.toml. HOME has 258ab27 (the pin of p6 and the default); the new compiler 38a3029 is the one download (run 5 of roc/us1-use). The compiler list is `GET /v1/toolchains?after=0`, read once for the command (R-IX4): `calls.log` has one `http_get` of /v1/toolchains and no `api.github.com` call. The download has the size of the row, and `.talon.json` has `sha256_source` `registry` (R-CV5). The pins of the rows are recorded in `compat.db` with the source `registry` (R-CV6).",
    "cv1-roc-default": "R-CV1 R-IX4 R-CV5 R-CS2 R-SO15 (slice 206g): `tln roc default nightly-2026-10-13-91fa0c2` with the registry of config.toml. The compiler is not installed, so it is the download of `roc install` (a person: Enter). The list is `GET /v1/toolchains?after=0` (3 rows), no GitHub call, `.talon.json` has `sha256_source` `registry`. HOME has no compiler, so the install sets the first default (R-SO15). The share files are those of share/sh62-no-send-roc-install.",
    "cv1-proxy-range": "R-CV1 R-IX4 R-CV5 R-PX4 R-SO13 R-DL3 (slice 206g): the proxy (`@roc check p2/main.roc`, run 12 of proxy/px2-install) with the registry of config.toml. p2 has no pin and the range >=nightly-2026-10-17: no compiler is installed, so rank 4 reads the list for the newest release in the range (`range_id!`), and the offer of that compiler reads it again. The proxy has no flag: the registry setting is the key of config.toml (R-RG1). The list is `GET /v1/toolchains?after=0`, ONE request for the command (R-IX4): the second read is the kept file. A person answers Enter, the install has `sha256_source` `registry`, the run follows. No GitHub call.",
}

GUARDS = {
    "sh62-no-send-roc-install": "`roc install`",
    "sh62-no-send-roc-update": "`roc update`",
    "sh62-no-send-init": "`init`",
}


def final():
    all_rows = make("final")
    # the unread case: by hand (the prefix of the guard, then the request and its failure)
    d = os.path.join(REGC, "cv1-roc-install-unread")
    g = rd(os.path.join(BEFORE, "sh62-no-send-roc-install/expect/calls.log"))
    prefix = g.split(f"list_dirs $HOME/.cache/roc/talon/index/github/roc-lang/nightlies\n")[0]
    calls = prefix + f"read_files {RDIR}/toolchains.json\nhttp_get http://127.0.0.1:9/v1/toolchains?after=0\n  User-Agent: tln/0.0.1\n"
    w(os.path.join(d, "expect/calls.log"), calls)
    w(os.path.join(d, "expect/stdout"), "== roc install nightly-2026-10-09-258ab27\nexit 15\n")
    w(os.path.join(d, "expect/stderr"), "tln: error[network]: http://127.0.0.1:9 answered 404 and the answer is not problem details. Check the registry setting.\n")
    w(os.path.join(d, "expect/exit"), "0\n")
    w(os.path.join(d, "expect/tree.diff"), "")
    # the cases of a baseline run: ref/cases/<name>/expect -> the registry expect
    for name, text in RULES.items():
        w(os.path.join(REGC, name, "rules"), text + "\n")
    for name, rows in all_rows.items():
        src = os.path.join(REF, name, "expect")
        if not os.path.isdir(src):
            raise SystemExit(f"no baseline for {name}: run the base step and UPDATE=1 first")
        transform_case(src, os.path.join(REGC, name, "expect"), rows, offline_first=(name == "ix6-roc-update-offline"), kept=(name == "ix6-roc-update-offline"))
        if name == "ix6-roc-update-offline":
            so = os.path.join(REGC, name, "expect/stdout")
            w(so, rd(so).replace("== roc update\n", "== roc update --offline\n", 1))
    # the guards: from the copies of before/
    for name in GUARDS:
        gd = os.path.join(SHARE, name)
        gh = os.path.join(gd, "fx/http", GH, GHFILE)
        if os.path.exists(gh):
            rows = rows_of(rd(gh))
        else:
            rows = rows_of(rd(os.path.join(BEFORE, name, "fx/http", GH, GHFILE)))
        transform_case(os.path.join(BEFORE, name, "expect"), os.path.join(gd, "expect"), rows)
        r = rd(os.path.join(BEFORE, name, "rules")).rstrip("\n")
        w(os.path.join(gd, "rules"), r + f"\nSlice 206g (R-CV1, R-IX4, R-CV5): {GUARDS[name]} now reads the compiler list with `GET /v1/toolchains?after=0` (the registry of config.toml), not the GitHub list, so the registry calls of this case are those of the registry read, the pins have the source `registry`, `.talon.json` has `sha256_source` `registry`, and `toolchains.json` is in the tree. The queue calls stay absent (Q541).\n")
        put_route(os.path.join(gd, "fx"), rows)
        drop_github(os.path.join(gd, "fx"))
        # the cache of GitHub pages that the world of `init` has for the nightlies list stays (a registry run does not read it)


if __name__ == "__main__":
    if sys.argv[1:] == ["base"]:
        make("base")
    elif sys.argv[1:] == ["final"]:
        final()
    else:
        raise SystemExit(__doc__)
