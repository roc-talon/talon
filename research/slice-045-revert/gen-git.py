#!/usr/bin/env python3
"""Makes the given/ and fx/ files of the slice 045 L2 cases (test agent only). It writes no expect/ file (TW21):
`UPDATE=1 tests/commands/run.sh roc/gi` writes them, after a check by eye.
Usage: gen-git.py l2   (the L2 cases under tests/commands/cases/roc/gi*)   |   gen-git.py l3   (given/http and given/alt of tests/scenarios/compilers/gi1-git-install)"""
import hashlib, json, os, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FAKE_SHA = hashlib.sha256(b"fake").hexdigest()  # the fake `curl` writes the text `fake`
CASES = os.path.join(ROOT, "tests", "commands", "cases", "roc")
ZIG_INDEX = os.path.join(ROOT, "tests", "commands", "cases", "zig", "zi1-install", "fx", "http", "ziglang.org", "download", "index.json")
ZON = os.path.join(ROOT, "research", "slice-045-revert", "build.zig.zon.roc-cf42a74")  # the real file of roc-lang/roc at cf42a741 (read 2026-10-25)

# The commits (made up, except for the form). Each `sha8` is the id.
SHA = {
    "my-branch": "3b9f7c1d5e8a2f4b6c0d9e1a7f3b5c8d2e4f6a1b",
    "main": "5349569a1b2c3d4e5f60718293a4b5c6d7e8f901",   # the commit of nightly-2026-10-21-5349569 (R-R2)
    "dd03c09e": "dd03c09e5f0a3b6c7d8e9f001122334455667788",
    "wip": "9d9d9d9d0123456789abcdef0123456789abcdef",
    "stale": "0a1b2c3d" + "4e5f60718293a4b5c6d7e8f901234567",
}
for k, v in SHA.items():
    assert len(v) == 40 and all(c in "0123456789abcdef" for c in v), k


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def talon_json(id_, repo, sha, ref, at, compat="null"):
    return ('{"format":1,"id":"%s","repo":"https://github.com/%s","sha":"%s","ref":"%s","sha256":"%s","sha256_source":"computed","compat":%s,"installed_at":"%s"}\n'
            % (id_, repo, sha, ref, FAKE_SHA, compat, at))


def nightlies():
    def rel(tag, date, hour):
        name = "roc_nightly-linux_x86_64-%s-%s.tar.gz" % (date, tag.rsplit("-", 1)[1])
        return {"tag_name": tag, "draft": False, "prerelease": False, "published_at": "%sT%s:00:00Z" % (date, hour),
                "assets": [{"name": name, "size": 73000001, "digest": "sha256:" + FAKE_SHA,
                            "browser_download_url": "https://github.com/roc-lang/nightlies/releases/download/%s/%s" % (tag, name)}]}
    items = [rel("nightly-2026-10-21-5349569", "2026-10-21", "18"), rel("nightly-2026-10-14-38a3029", "2026-10-14", "15"), rel("nightly-2026-10-09-258ab27", "2026-10-09", "15")]
    return "[\n" + ",\n".join(json.dumps(i, separators=(",", ":")) for i in items) + "\n]\n"


def common(case, entry="commands"):
    d = os.path.join(CASES, case)
    if os.path.isdir(d):
        shutil.rmtree(os.path.join(d, "fx"), ignore_errors=True)
        shutil.rmtree(os.path.join(d, "given"), ignore_errors=True)
    put(os.path.join(d, "entry"), entry + "\n")
    put(os.path.join(d, "fx", "env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\nTALON_INTERACTIVE=1\n")
    put(os.path.join(d, "fx", "tty"), "stdin=true\nstderr=true\n")
    put(os.path.join(d, "fx", "platform"), "os=linux arch=x64\n")
    http = os.path.join(d, "fx", "http")
    put(os.path.join(http, "api.github.com", "repos", "roc-lang", "nightlies", "releases?per_page=100"), nightlies())
    put(os.path.join(d, "fx", "src", "build.zig.zon"), open(ZON).read())
    return d


def commit_route(d, host, owner, repo, ref, sha):
    put(os.path.join(d, "fx", "http", host, "repos", owner, repo, "commits", ref), sha)


def compat_rule(sha8):
    return "git-%s.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{w}/home/.cache/roc/compat-%s\n" % (sha8, sha8)


def gi1():
    d = common("gi1-install")
    api = "api.github.com"
    commit_route(d, api, "Karakatiza666", "roc", "my-branch", SHA["my-branch"])
    commit_route(d, api, "roc-lang", "roc", "main", SHA["main"])
    commit_route(d, api, "Karakatiza666", "roc", "wip", SHA["wip"])
    # the real API answers 422 and a JSON text for a ref that does not exist
    put(os.path.join(d, "fx", "http", api, "repos", "roc-lang", "roc", "commits", "nosuch"), '{"message":"Not Found","documentation_url":"https://docs.github.com/rest/commits/commits#get-a-commit","status":"404"}')
    put(os.path.join(d, "fx", "http", api, "repos", "roc-lang", "roc", "commits", "nosuch.meta"), "status 422\n")
    put(os.path.join(d, "fx", "programs"), "curl\nwget\ntar\nzig\n")
    jobs = ["# R-DA3 the source archive (curl), R-HF5 the extract, R-D4 `zig version`, R-R3 the build, R-GC10 the compat check. The first rule whose needle is in the arguments answers.\n",
            "zig version\t0\t0.17.1\t-\t-\n",
            "source.tar.gz -C\t0\t-\t-\tcopy:{dir}/build.zig.zon={w}/fx/src/build.zig.zon\n",
            "curl --fail\t0\t-\t-\tfile:{out}\n",
            "zig build roc -Doptimize=ReleaseFast -Dcompiler-version=git-\t0\t-\t-\tfile:{cwd}/zig-out/bin/roc\n"]
    for key in ("my-branch", "main", "dd03c09e"):
        jobs.append(compat_rule(SHA[key][:8]))
    put(os.path.join(d, "fx", "jobs"), "".join(jobs))
    put(os.path.join(d, "fx", "commands"), "\n".join([
        "roc install --git Karakatiza666/roc@my-branch",
        "roc install --git Karakatiza666/roc@my-branch",
        "roc install --git @main",
        "roc install @dd03c09e --json env:TALON_GITHUB_API=http://127.0.0.1:9/api",
        "roc install --git Karakatiza666/roc@my-branch --offline",
        "roc install --git @nosuch",
        "roc install --git Karakatiza666/roc@wip env:TALON_DOWNLOADER=wget",
        "roc default --git Karakatiza666/roc@my-branch",
        "roc default --git roc-lang/roc@my-branch",
        "roc default --git Karakatiza666/roc@my-branch --json",
        ""]))
    # the second API (R-EV19): the same routes under a loopback base
    for owner, repo, ref, key in (("roc-lang", "roc", "dd03c09e", "dd03c09e"),):
        commit_route(d, "127.0.0.1:9/api", owner, repo, ref, SHA[key])
    home = os.path.join(d, "given", "home")
    put(os.path.join(home, ".config", "talon", "config.toml"), 'default-roc = "nightly-2026-10-09-258ab27"\n')
    tc = os.path.join(home, ".cache", "roc", "toolchains")
    put(os.path.join(tc, "git-0a1b2c3d", ".talon.json"), talon_json("git-0a1b2c3d", "Karakatiza666/roc", SHA["stale"], "my-branch", "2026-10-01T09:00:00Z", '"aaaa0001"'))
    put(os.path.join(tc, "git-0a1b2c3d", "roc"), "fake\n")
    put(os.path.join(tc, "git-7e7e7e7e", ".talon.json"), talon_json("git-7e7e7e7e", "Karakatiza666/roc", "7e7e7e7e" + "0" * 32, "other", "2026-10-30T09:00:00Z", '"aaaa0002"'))
    put(os.path.join(tc, "git-7e7e7e7e", "roc"), "fake\n")
    put(os.path.join(tc, "git-5a5a5a5a", ".talon.json"), talon_json("git-5a5a5a5a", "roc-lang/roc", "5a5a5a5a" + "0" * 32, "my-branch", "2026-10-31T09:00:00Z", '"aaaa0003"'))
    put(os.path.join(tc, "git-5a5a5a5a", "roc"), "fake\n")
    put(os.path.join(d, "rules"), RULES_GI1)


def gi2():
    d = common("gi2-zig")
    api = "api.github.com"
    commit_route(d, api, "Karakatiza666", "roc", "my-branch", SHA["my-branch"])
    commit_route(d, api, "roc-lang", "roc", "main", SHA["main"])
    commit_route(d, api, "Karakatiza666", "roc", "wip", SHA["wip"])
    put(os.path.join(d, "fx", "programs"), "curl\nwget\ntar\nxz\n")
    os.makedirs(os.path.join(d, "fx", "http", "ziglang.org", "download"), exist_ok=True)
    shutil.copy(ZIG_INDEX, os.path.join(d, "fx", "http", "ziglang.org", "download", "index.json"))
    jobs = ["# The source archive and the Zig archive (curl), their extract (tar), `zig version`, the build, the compat check. The first rule whose needle is in the arguments answers.\n",
            "zig version\t0\t0.17.0\t-\t-\n",
            "source.tar.gz -C\t0\t-\t-\tcopy:{dir}/build.zig.zon={w}/fx/src/build.zig.zon\n",
            "zig-x86_64-linux-0.17.0.tar.xz -C\t0\t-\t-\tfile:{dir}/zig;file:{dir}/LICENSE;dir:{dir}/lib\n",
            "curl --fail\t0\t-\t-\tfile:{out}\n",
            "chmod 0755\t0\t-\t-\t-\n",
            "-Dcompiler-version=git-%s\t1\t-\terror: unable to build the std library\t-\n" % SHA["main"][:8],
            "zig build roc -Doptimize=ReleaseFast -Dcompiler-version=git-\t0\t-\t-\tfile:{cwd}/zig-out/bin/roc\n"]
    for key in ("my-branch", "wip"):
        jobs.append(compat_rule(SHA[key][:8]))
    put(os.path.join(d, "fx", "jobs"), "".join(jobs))
    put(os.path.join(d, "fx", "answers"), "n\n\n")
    put(os.path.join(d, "fx", "commands"), "\n".join([
        "roc install --git Karakatiza666/roc@my-branch",
        "roc install --git Karakatiza666/roc@my-branch",
        "roc install --git @main",
        "roc install --git Karakatiza666/roc@wip",
        ""]))
    put(os.path.join(d, "fx", "locks"), "busy toolchains/git-%s creates:{w}/home/.cache/roc/toolchains/git-%s\n" % (SHA["wip"][:8], SHA["wip"][:8]))
    os.makedirs(os.path.join(d, "given", "home"), exist_ok=True)
    put(os.path.join(d, "rules"), RULES_GI2)


RULES_GI1 = """Slice 045, `tln roc install --git` and `tln roc default --git` (entry `commands`, one line of `fx/commands` for each run). `zig` 0.17.1 is on `PATH` (the job `zig version`). The fake API gives the commit of
each ref (`fx/http/api.github.com/repos/<owner>/<repo>/commits/<ref>`: the sha as text, the media type of the request), the nightly list has `nightly-2026-10-21-5349569`. The fake curl writes the text `fake`
(so the sha256 of each archive is `b5d54c39...`), the fake tar writes the real `build.zig.zon` of roc-lang/roc (`fx/src/`, `minimum_zig_version = "0.17.0"`), the fake `zig build` writes `zig-out/bin/roc`.
`config.toml` has a default, so no install sets the default (R-SO15 is in `gi2-zig`). The home has an old build of the branch (`git-0a1b2c3d`), one of another ref (`git-7e7e7e7e`, a later `installed_at`) and one of another repo with the same ref (`git-5a5a5a5a`, the latest).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `--git Karakatiza666/roc@my-branch` | the branch moved: a new id `git-3b9f7c1d`, the old `git-0a1b2c3d` stays. The calls: commit (media type, no token), list, header line, the archive by the full sha, sha256, tar, `build.zig.zon`, Zig found, the build, the compat check, `.talon.json`, rename | R-R1, R-R3, R-R6, R-R7, R-R10, R-D1, R-D3, R-D4, R-DA3, R-SE12, R-CC4 |
| 2 | the same | the head is the same: `git-3b9f7c1d is already installed`, no download, no Zig, no lock | R-R6, R-CC4 step 1 |
| 3 | `--git @main` | the commit is a nightly: the note, then the build anyway, no prompt (`git-5349569a`) | R-R2, R-R9, R-R3 |
| 4 | `@dd03c09e --json`, `TALON_GITHUB_API` | a sha with no `--git`: `git-dd03c09e`. Both requests go to the loopback base. The envelope on stdout | R-R11, R-EV19, R-R1 |
| 5 | `--git Karakatiza666/roc@my-branch --offline` | exit 15, no request | R-DI12, R-R3 |
| 6 | `--git @nosuch` | the API answers 422: exit 2, no download, no scratch dir | R-R3, R-SL13 |
| 7 | `--git Karakatiza666/roc@wip`, `TALON_DOWNLOADER=wget` | exit 18, the message names curl, no download | R-DA3, R-R7, R-SE12 |
| 8 | `default --git Karakatiza666/roc@my-branch` | the newest build of that repo and ref (`git-3b9f7c1d`), not the newer ones of another ref or repo. `default-roc` changes | R-R5, R-R1, R-CS2 |
| 9 | `default --git roc-lang/roc@my-branch` | the build of the other repo (`git-5a5a5a5a`) | R-R5 |
| 10 | `default --git Karakatiza666/roc@my-branch --json` | back to `git-3b9f7c1d`, the envelope | R-R5, R-J3 |
"""

RULES_GI2 = """Slice 045, the Zig dependency and the failures of a source build (entry `commands`). No `zig` is on `PATH`, the home is empty (no compiler, no `config.toml`), the Zig index is the one of `zig/zi1-install`.
Interactive: the first `ask!` gets `n`, the second the Enter key. The fake `zig version` prints 0.17.0 (the Zig that run 2 installs).

| Run | Words | Result | Rules |
| --- | --- | --- | --- |
| 1 | `--git Karakatiza666/roc@my-branch`, the answer `n` | the source is downloaded and read, the list shows zig missing, the prompt, exit 13. No lock, no toolchain dir, the scratch dir is deleted | R-NI6, R-DL1, R-D1, R-D3, R-D4, R-CC2 |
| 2 | the same, Enter | Zig 0.17.0 is installed (its lock, then the build lock), the build runs with the program of that Zig, the first compiler is the default | R-D2, R-NI6, R-R3, R-SO15, R-CC3, R-CC4 |
| 3 | `--git @main` | Zig is installed: found. `zig build` exits 1: exit 1, the temp dir and the scratch dir are deleted, no toolchain dir | R-R3, R-CC2 |
| 4 | `--git Karakatiza666/roc@wip`, a busy lock whose holder makes the dir | under the lock the dir is there: no build, `is already installed` | R-CC3, R-CC4 steps 3, 4, R-CC5 |
"""


# L3: the shas of the case (made up). The branch `my-branch` moves from L3_SHA1 to L3_SHA2 (given/alt/my-branch is the new commit text).
L3_SHA1 = "a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e"
L3_SHA2 = "b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e4f"
L3_MAIN = "5349569a1b2c3d4e5f60718293a4b5c6d7e8f901"
L3_EVIL = "e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0"
L3_LOOP = "c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c1"
L3_NONE = "d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0"


def l3():
    case = os.path.join(ROOT, "tests", "scenarios", "compilers", "gi1-git-install")
    for s in (L3_SHA1, L3_SHA2, L3_MAIN, L3_EVIL, L3_LOOP, L3_NONE):
        assert len(s) == 40 and all(c in "0123456789abcdef" for c in s), s
    http = os.path.join(case, "given", "http")
    shutil.rmtree(http, ignore_errors=True)
    shutil.rmtree(os.path.join(case, "given", "alt"), ignore_errors=True)
    mk = os.path.join(ROOT, "tests", "tools", "mk-git.sh")
    subprocess.run([mk, http, "Karakatiza666/roc", "my-branch=" + L3_SHA1, "evil=" + L3_EVIL + "+evil", "loop=" + L3_LOOP + "+redirect", "nosuch=" + L3_NONE + "+unknown"], check=True)
    # the second commit of the branch: its archive is a route from the start, its commit text is in alt/ (the cmd copies it over the route)
    subprocess.run([mk, http, "Karakatiza666/roc", "moved=" + L3_SHA2], check=True)
    os.rename(os.path.join(http, "api", "repos", "Karakatiza666", "roc", "commits", "moved"), os.path.join(case, "given", "alt-moved"))
    os.makedirs(os.path.join(case, "given", "alt"), exist_ok=True)
    os.rename(os.path.join(case, "given", "alt-moved"), os.path.join(case, "given", "alt", "my-branch"))
    subprocess.run([mk, http, "roc-lang/roc", "main=" + L3_MAIN], check=True)
    env = dict(os.environ, TARGETS="linux_x86_64")
    subprocess.run([os.path.join(ROOT, "tests", "tools", "mk-nightly.sh"), http, "nightly-2026-10-21-" + L3_MAIN[:7] + "@2026-10-21T18:00:00Z", "nightly-2026-10-14-38a3029"], check=True, env=env)
    shutil.rmtree(os.path.join(http, "dl"))  # the list names assets, no case downloads one


if __name__ == "__main__":
    if sys.argv[1:] == ["l2"]:
        gi1()
        gi2()
    elif sys.argv[1:] == ["l3"]:
        l3()
    else:
        print(__doc__)
        sys.exit(2)
