#!/usr/bin/env python3
"""Slice 206f: makes the L2 cases of tests/commands/cases/registry/ and share/ (hand-made expected files, TW21).
Run it from the repo root:  python3 -I research/slice-206f-revert/mkcases.py   (a record: the baselines in ref/ were deleted after the run; the case files are the result)
The tool and x cases are the direct run 1 of tool/ti1-install and x/x1-run (a baseline of the current code, `UPDATE=1`),
with the 3 calls of the GitHub release list replaced by the calls of the guard and of R-AP1 (FullName.read!, slices 203, 212)."""
import sys, os
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib206f import *

R = "research/slice-206f-revert"
MD5 = {"acme/foo": "acdd588cd97481e5777473efe4eb1ee2", "acme/known": "ae7fcf36e6e344437c63dea9b236a7cd"}


def registry_variant(new, src, base, repo, cmds, rules, gh_file):
    """new: the case dir name under registry/; src: the dir of the source case in tests/commands/cases; base: the baseline case in ref/."""
    dst = os.path.join(CASES, "registry", new)
    fresh(dst)
    copy_tree(os.path.join(CASES, src, "given"), os.path.join(dst, "given"))
    copy_tree(os.path.join(CASES, src, "fx"), os.path.join(dst, "fx"))
    w(os.path.join(dst, "entry"), "commands\n")
    w(os.path.join(dst, "fx", "commands"), cmds)
    cfg = os.path.join(dst, "given", "home", ".config", "talon", "config.toml")
    old = rd(cfg) if os.path.exists(cfg) else ""
    w(cfg, 'registry = "http://127.0.0.1:9"\n' + old)
    gh_path = os.path.join(http_dir(dst), "api.github.com", "repos", *repo.split("/"), "releases%3Fper_page=100")
    gh = rd(gh_path)
    os.remove(gh_path)
    body = ap1_body(repo, gh)
    put_registry_list(dst, repo, body)
    put_guard(dst, repo)
    md5 = MD5[repo]
    # the calls: the 3 lines of the GitHub list become the guard and R-AP1
    calls = rd(os.path.join(REF, base, "expect", "calls.log")).split("\n")
    gdir = "$HOME/.cache/roc/talon/index/github/%s" % repo
    i = calls.index("list_dirs %s" % gdir)
    assert calls[i + 1].startswith("http_get https://api.github.com/repos/%s/releases?per_page=100" % repo), calls[i + 1]
    assert calls[i + 3].startswith("write_atomic %s/1.json" % gdir), calls[i + 3]
    calls[i:i + 4] = guard_lines(repo, gh=False) + registry_get_lines(repo, md5)
    w(os.path.join(dst, "expect", "calls.log"), "\n".join(calls))
    for f in ("stdout", "stderr", "exit"):
        p = os.path.join(REF, base, "expect", f)
        if os.path.exists(p):
            shutil.copy(p, os.path.join(dst, "expect", f))
    h = hunks(rd(os.path.join(REF, base, "expect", "tree.diff")))
    for k in list(h):
        if k.startswith("home/.cache/roc/talon/index/github/%s/1." % repo):
            del h[k]
    g = "home/.cache/roc/talon/index/github/%s/repo.json" % repo
    h[g] = hunk_new(g, '{"id":1,"full_name":"%s","private":false,"fork":false}' % repo)
    rj = "home/.cache/roc/talon/index/registry/http_127.0.0.1_9/get/%s.json" % md5
    h[rj] = hunk_new(rj, body)
    rm = rj[:-5] + ".meta"
    h[rm] = hunk_new(rm, 'url /v1/packages/%s/releases\netag "r1"\nmax-age 60\n' % repo)
    w(os.path.join(dst, "expect", "tree.diff"), join_hunks(h))
    w(os.path.join(dst, "rules"), rules)


def stage_tool_x():
    registry_variant(
        "sc3-tool-install", "tool/ti1-install", "tool/ti1-install", "acme/foo", "tool install acme/foo\n",
        "R-SC3 R-AD35 R-AD2 R-RG4 R-RG5 R-AP1 R-DI14 R-T10 R-IX3 R-CM16 (slice 206f): `tln tool install acme/foo` with a registry (entry `commands`). The home, the fakes and the build are run 1 of tool/ti1-install: the same 4 releases, the same bundle fetch, the same build, the same output. The registry is in config.toml (`registry`), TALON_GITHUB_API is set (no token source: no `programs gh`).\n"
        "The only change: the release list is the registry list (R-SC3). The calls are the guard (R-RG4: the kept answer, `GET /repos/acme/foo`, a write), then R-AP1 (`GET /v1/packages/acme/foo/releases`, the copy) instead of the 3 calls of the GitHub list. R-AP1 answers 200, so no GitHub release list, no `programs curl` for an ingest, no ingest (R-AD35 starts at a 404). The bundle is fetched and its header read as in `direct` (R-T10): the registry has no kind of an app bundle in this answer.\n"
        "Reading (D1): `ToolFlow` calls `FullName.read!` where it called `Github.releases!`, and turns the answer into the same candidates (`Index.Candidate`).\n",
        "")
    registry_variant(
        "sc3-tool-nomatch", "tool/ti1-install", "tool/ti1-nomatch", "acme/foo", "tool install acme/foo@9.9.9\n",
        "R-SC3 R-AD35 R-SL3 R-T10 R-EC2 Q430 (slice 206f): `tln tool install acme/foo@9.9.9` with a registry: R-AP1 answers 200, the selector keeps no candidate (`FullName.read!` gives `NoMatch`). The text is the text of the command, as in `direct` (Q430): `acme/foo has no release 9.9.9`, exit 2. The guard and R-AP1 only: no GitHub list, no ingest, no download.\n",
        "")
    registry_variant(
        "sc4-x-registry", "x/x1-run", "x/x1-run", "acme/foo", "x acme/foo -- a b\n",
        "R-SC4 R-AD35 R-AD2 R-RG4 R-RG5 R-AP1 R-DI14 R-X1 R-X2 R-X3 R-X4 R-B9 R-E1 (slice 206f): `tln x acme/foo -- a b` with a registry (entry `commands`). The home, the fakes, the build and the output are run 1 of x/x1-run: no entry matches, the newest release 1.1.0 is built, the app runs with `a b`, exit 3 is the exit code.\n"
        "The only change: the release list is the registry list (R-SC4). The guard and R-AP1 replace the 3 calls of the GitHub list (see registry/sc3-tool-install). No ingest (R-AP1 answers 200).\n",
        "")
    registry_variant(
        "sc4-x-nomatch", "x/x1-run", "x/x1-nomatch", "acme/foo", "x acme/foo@9.9.9\n",
        "R-SC4 R-AD35 R-SL3 R-X1 R-EC2 Q430 (slice 206f): `tln x acme/foo@9.9.9` with a registry: R-AP1 answers 200 and the selector keeps no candidate (`NoMatch`). The text is the text of `x` as in `direct` (Q430), exit 2. No download, no build.\n",
        "")



def src_calls(case, base="registry"):
    lines = rd(os.path.join(CASES, base, case, "expect", "calls.log")).rstrip("\n").split("\n")
    assert lines[0] == "env_all"
    return lines[1:]


def src_tree(case):
    p = os.path.join(CASES, "registry", case, "expect", "tree.diff")
    return hunks(rd(p)) if os.path.exists(p) else {}


def one_run_failure(new, src, cmd, code, rules):
    dst = command_case("registry/" + new, ["registry/" + src], [cmd], None, rules)
    calls = first_prefix() + src_calls(src)
    w(os.path.join(dst, "expect", "calls.log"), "\n".join(calls) + "\n")
    w(os.path.join(dst, "expect", "stdout"), run_stdout(cmd, code))
    shutil.copy(os.path.join(CASES, "registry", src, "expect", "stderr"), os.path.join(dst, "expect", "stderr"))
    h = first_tree_hunks()
    h.update(src_tree(src))
    w(os.path.join(dst, "expect", "tree.diff"), join_hunks(h))
    w(os.path.join(dst, "expect", "exit"), "0\n")
    return dst


def stage_add():
    one_run_failure(
        "ad35-add-nomatch", "ad35-known", "add acme/known@9.9.9 --no-check --dry-run --file p1/main.roc", 2,
        "R-AD2 R-AD35 R-SL3 R-SL12 R-RG4 R-RG5 R-AP1 R-EC2 R-DI14 Q430 (slice 206f): `tln add acme/known@9.9.9` with a registry (config.toml), the project p1 (a platform and a `roc:` pin, no talon.toml). R-AP1 answers 200 with 2 releases (1.0.0, 1.1.0), the selector keeps none (`FullName.read!` gives `NoMatch`).\n"
        "The text is the text of `add` (Q430): `Add.no_release`, with the close versions of R-SL12 (the 3 nearest to the exact version: 1.1.0, 1.0.0). Exit 2. The calls after the load of the project and of config.toml are those of `FullName.read!` (the guard, R-AP1) and nothing else: no closure query, no GitHub list, no ingest, no write of the project.\n"
        "Reading (D1): `add` calls `FullName.read!` right after the load and the setting, before the first closure query (R-AP16: the group of `tln add` is known only after R-AP1). The calls of the guard and R-AP1 are the calls of registry/ad35-known (the word `fullname`).\n")
    one_run_failure(
        "ad36-add-snapshot", "ad36-snapshot", "add acme/snap --snapshot log:40 --no-check --dry-run --file p1/main.roc", 2,
        "R-AD35 R-AD36 R-RG4 R-DT3 R-EC2 Q396 (slice 206f): `tln add acme/snap --snapshot log:40` with a registry: R-AP1 answers 404 (a repository that the registry did not index). With a log snapshot Talon sends no ingest: exit 2, `acme/snap has no release in the log at size 40. A snapshot sends no ingest.` No GitHub release list (Q396), no `programs curl`, no POST. The calls after the load are those of registry/ad36-snapshot (the guard, one R-AP1 read).\n")
    one_run_failure(
        "ad37-add-offline", "ad37-offline", "add acme/off --offline --no-check --dry-run --file p1/main.roc", 15,
        "R-AD37 R-DI12 R-IX6 R-EC2 (slice 206f): `tln add acme/off --offline` with a registry and no cached page of R-AP1: no request at all (no guard request, R-RG4), exit 15, the text names `--offline`. The calls after the load are those of registry/ad37-offline (one `list_dirs` of the copies).\n")
    one_run_failure(
        "ad35-add-ingest-429", "ad35-rate-limited", "add acme/limit --no-check --dry-run --file p1/main.roc", 15,
        "R-AD35 R-AD2 R-AP25 R-AP9 R-AP34 R-DA8 R-E6 R-RG4 (slice 206f): `tln add acme/limit` with a registry: R-AP1 answers 404, the GitHub list has 2 candidates, the first ingest is answered 201 and the second 429 with `Retry-After: 30`. Exit 15 (R-AP25), `Try again in 30 s.`, no second R-AP1 read, no closure query. The calls after the load are those of registry/ad35-rate-limited: the guard, R-AP1, the GitHub list (with its write), `programs curl`, one `http_all` of 2 POSTs. The GitHub token is `GITHUB_TOKEN=tok1`, so there is no `programs gh`.\n")
    # e6: the first R-AP1 read gets a 502, a 429 or a 302: 3 runs
    base = os.path.join(REF, "registry", "h-e6")
    calls = rd(os.path.join(base, "expect", "calls.log")).rstrip("\n").split("\n")[1:]
    chunks, cur = [], None
    for l in calls:
        if l.startswith("read_files $HOME/.cache/roc/talon/index/github/acme/e"):
            cur = []
            chunks.append(cur)
        cur.append(l)
    assert len(chunks) == 3
    cmds = ["add acme/e%d --no-check --dry-run --file p1/main.roc" % i for i in (1, 2, 3)]
    dst = command_case("registry/e6-add-first-read", ["registry/ad35-rate-limited"], cmds, None,
        "R-AD35 R-AP1 R-AP52 R-AP34 R-E6 R-IX7 R-RG4 R-EC15 (slice 206f): the first R-AP1 read of `tln add` with a registry gets an answer that Talon cannot use: run 1 a 502 `/errors/upstream`, run 2 a 429 `/errors/rate-limited` with `Retry-After: 30`, run 3 a 302. Each run is exit 15 with the text of the registry error (the same code as every registry read, slice 202). No retry (R-AP34), no GitHub list, no ingest (R-AD35 starts at a 404), no closure query, no write of the project. Each run has its own repository, so the kept public answer of a run does not change the next.\n"
        "Run 1 is a first run on p1 (projects.json and path-roc.json are written, the fake tty is read). Runs 2 and 3 have the later prefix (the pattern of registry/al2-install-query run 2).\n")
    for f in os.listdir(os.path.join(dst, "fx", "http")):
        pass
    shutil.rmtree(os.path.join(dst, "fx", "http"))
    copy_tree(os.path.join(base, "fx", "http"), os.path.join(dst, "fx", "http"))
    out = []
    for i, ch in enumerate(chunks):
        out += (first_prefix() if i == 0 else later_prefix()) + ch
    w(os.path.join(dst, "expect", "calls.log"), "\n".join(out) + "\n")
    codes = [15, 15, 15]
    w(os.path.join(dst, "expect", "stdout"), "".join(run_stdout(c, k) for c, k in zip(cmds, codes)))
    shutil.copy(os.path.join(base, "expect", "stderr"), os.path.join(dst, "expect", "stderr"))
    h = first_tree_hunks()
    h.update(hunks(rd(os.path.join(base, "expect", "tree.diff"))))
    w(os.path.join(dst, "expect", "tree.diff"), join_hunks(h))
    w(os.path.join(dst, "expect", "exit"), "0\n")



def stage_short():
    sn = "registry/sn6-short-names"
    lines = rd(os.path.join(CASES, sn, "expect", "calls.log")).rstrip("\n").split("\n")[1:]
    # the requests of the runs `Parser` (1 request, 4 lines) and `pars` (2 requests, 8 lines): the 3rd and 4th run of sn6
    i = [n for n, l in enumerate(lines) if l.startswith("http_get http://127.0.0.1:9/v1/packages?short=Parser")][0] - 1
    run_parser = lines[i:i + 4]
    run_pars = lines[i + 4:i + 12]
    assert run_pars[1].endswith("?short=pars") and run_pars[5].endswith("?q=pars"), run_pars
    cmds = ["install Parser --no-check --dry-run --file p1/main.roc", "install pars --no-check --dry-run --file p1/main.roc"]
    dst = command_case("registry/sn6-install-short", [sn], cmds, None,
        "R-AD34 R-SN1 R-SN2 R-SN4 R-AD3 R-AD4 R-AD5 R-I8 R-EC2 R-RG4 (slice 206f): `tln install <short name>` with a registry (config.toml), the project p1. The short name is read with `GET /v1/packages?short=<name>` (R-AD34, slice 211). No guard call (R-RG4: `?short=` carries only what the user typed).\n"
        "Run 1 `install Parser`: the match set has 2 packages (R-AD4): exit 2, the block of the matches on stderr, then `\"Parser\" matches 2 packages. Use a name from the list.` The text and the block are those of `Lookup.registry` (registry/sn6-short-names, the run `Parser`). Run 2 `install pars`: no match (R-AD5): one `?q=pars` read for the suggestions, exit 2, `Similar names:` and the list, then `\"pars\" matches no indexed package.` No other call: no R-AP1 read, no closure query, no write of the project (R-I8: the names are all read first).\n"
        "Reading (D2): `install` and `add` with a name that is not a full name and not an alias read the short names of the command in one request, after the load of the project files and `config.toml` and the setting, before `FullName.read!`. A short name that matches one package goes on as the full name (not tested here: the run goes on to the closure query, held for question Q1, research/slice-206f-revert/held/).\n"
        "The R-AP1 read of the one match and the ingest are tested by registry/ad35-add-*.\n")
    out = first_prefix() + run_parser + later_prefix() + run_pars
    w(os.path.join(dst, "expect", "calls.log"), "\n".join(out) + "\n")
    w(os.path.join(dst, "expect", "stdout"), "".join(run_stdout(c, 2) for c in cmds))
    err = rd(os.path.join(CASES, sn, "expect", "stderr")).split("\n")
    a = err.index('"Parser" matches 2 packages:')
    parser_err = err[a:a + 4]
    b = err.index("Similar names:")
    pars_err = err[b:b + 4]
    assert parser_err[3].startswith("tln: error[usage]: \"Parser\"") and pars_err[3].startswith("tln: error[usage]: \"pars\""), (parser_err, pars_err)
    w(os.path.join(dst, "expect", "stderr"), "\n".join(parser_err + pars_err) + "\n")
    h = first_tree_hunks()
    t = hunks(rd(os.path.join(CASES, sn, "expect", "tree.diff")))
    for k, v in t.items():
        if any(m in k for m in ("665b62ee04aaa9659d1239515ecf23ee", "947d731c7b74c15b7bb7102ed7caf64c", "0a8eb6471c886ef3d869244d78128901")):
            h[k] = v
    assert len(h) == 1 + 6, list(h)
    w(os.path.join(dst, "expect", "tree.diff"), join_hunks(h))
    w(os.path.join(dst, "expect", "exit"), "0\n")



def from_baseline(new, base, cmds, rules, given_cfg=None, expect_files=("stdout", "stderr", "calls.log", "tree.diff", "exit")):
    """A case whose expected files are those of a baseline in ref/ (the direct run of the same world), for other command words."""
    dst = os.path.join(CASES, "registry", new)
    fresh(dst)
    src = os.path.join(REF, "registry", base)
    copy_tree(os.path.join(src, "given"), os.path.join(dst, "given"))
    copy_tree(os.path.join(src, "fx"), os.path.join(dst, "fx"))
    w(os.path.join(dst, "entry"), "commands\n")
    w(os.path.join(dst, "fx", "commands"), "".join(c + "\n" for c in cmds))
    if given_cfg is not None:
        w(os.path.join(dst, "given", "home", ".config", "talon", "config.toml"), given_cfg)
    for f in expect_files:
        p = os.path.join(src, "expect", f)
        if os.path.exists(p):
            shutil.copy(p, os.path.join(dst, "expect", f)) if os.path.isdir(os.path.join(dst, "expect")) else (os.makedirs(os.path.join(dst, "expect")), shutil.copy(p, os.path.join(dst, "expect", f)))
    old = [l for l in rd(os.path.join(src, "fx", "commands")).split("\n") if l and not l.startswith("#")]
    out = os.path.join(dst, "expect", "stdout")
    if os.path.exists(out):
        text = rd(out)
        for o, n in zip(old, cmds):
            text = text.replace("== %s\n" % o, "== %s\n" % n, 1) if o != n else text
        # the same command word twice: replace in order
        lines, k = [], 0
        for l in rd(out).split("\n"):
            if l.startswith("== ") and k < len(cmds):
                l = "== " + cmds[k]
                k += 1
            lines.append(l)
        w(out, "\n".join(lines))
    w(os.path.join(dst, "rules"), rules)
    return dst


BAD_FORMS = "Use direct, an https:// URL, or an http:// URL of 127.0.0.1, [::1] or localhost, with no path."


def stage_no_refusal():
    from_baseline(
        "rg7-no-refusal", "remove-base2",
        ["remove nope --registry ftp://bad --file p1/main.roc", "remove nope --registry http://127.0.0.1:9 --file p1/main.roc"],
        "R-RG7 R-FL5 R-RG1 R-AU6 R-EC2 (slice 206f, plan row 206f: `Opts.check_registry` goes for every command): a command that uses no registry does not stop for `--registry`, also a bad one (R-RG7 row 6: the check runs when Talon reads the setting). `tln remove nope` in p1 with `--registry ftp://bad` (run 1) and a good URL (run 2): the P0 refusal `no registry exists in this version of tln` is gone, and each run ends as the same line with no flag: exit 2, `'nope' is not in the project`. No registry request. The expected files are those of the direct run with no flag (the same world, a baseline of the current code).\n"
        "The L0 rows of OptsTest, RemovalTest, ListingTest and ProbecmdTest show the same for `Opts.read`.\n")
    # E2: the bad config.toml value stops a command that uses no registry (R-RG7 row 6, R-TF4), also with a good flag
    dst = from_baseline(
        "rg7-remove-bad-config", "remove-base",
        ["remove nope --file p1/main.roc"],
        "R-RG7 R-TF4 R-EC19 R-C13 (slice 206f): `registry = \"ftp://bad\"` in config.toml stops a command that has no index call, as each other key of R-TF4 does (R-RG7 row 6: a bad config.toml value is exit 19). `tln remove nope`: exit 19 (`input`), the message names the file, the line, the key and the text (the text of `IndexQuery.setting`, slice 206b). It stops when the file is read, before the names are looked up: no `'nope' is not in the project`.\n"
        "Reading (D3): the check is made where `config.toml` is read for the command (the same read as the other keys), so every command that reads the file has it. The calls are those of the baseline up to the read of the 3 files, then nothing.\n"
        "Not tested (Q3): which commands that use no registry read `config.toml` at all.\n",
        given_cfg='registry = "ftp://bad"\n', expect_files=("calls.log", "tree.diff"))
    w(os.path.join(dst, "expect", "stdout"), run_stdout("remove nope --file p1/main.roc", 19))
    w(os.path.join(dst, "expect", "stderr"), "tln: error[input]: $HOME/.config/talon/config.toml:1: registry: 'ftp://bad' is not a registry URL. " + BAD_FORMS + "\n")
    w(os.path.join(dst, "expect", "exit"), "0\n")
    from_baseline(
        "rg7-frozen-flag", "frozen-base",
        ["install --frozen --registry http://127.0.0.1:9 --file p1/main.roc env:TALON_AUTO_INSTALL=no", "install --frozen --registry ftp://bad --file p1/main.roc env:TALON_AUTO_INSTALL=no"],
        "R-RG7 R-AU6 R-LF1 R-FL5 R-SO14 R-DL5 R-NI5 R-EC13 (slice 206f): `tln install --frozen` makes no index call (R-AU6), so it takes `--registry` and does not read it: no P0 refusal for a good URL (run 1) and no stop for a bad one (run 2). Each run is the run of `closure/cl3-frozen-none` (run 1): no compiler is selected and `TALON_AUTO_INSTALL=no` refuses the download, exit 13, no registry request, no compiler list, no write. The expected files are those of the direct run with no flag (a baseline of the current code).\n")


if __name__ == "__main__":
    stage_tool_x()
    stage_add()
    stage_short()
    stage_no_refusal()
