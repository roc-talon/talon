#!/usr/bin/env python3
"""Writes the given/ and fx/ files of the L2 cases of slice 024 (roc/ls1-list, roc/df1-default, roc/rm1-remove).
The expected files are not made here: they come from the private reference (research/slice-024-revert/reference/) and are read by eye (TW21).
Run: python3 -I research/slice-024-revert/mk-fixtures.py"""
import os
import shutil

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tests", "commands", "cases", "roc")
HEADER = 'app [main!] {{\n\tpf: platform "https://github.com/acme/pf/releases/download/0.1.0/895yiekWBru1NBsyGpzBzHzqjLdBGbe5MkhtZ4325wWw.tar.zst",{roc}\n}}\n\nmain! = |_args| Ok({{}})\n'


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def meta(id, installed, published=None, compat=None):
    c = "null" if compat is None else '"%s"' % compat
    p = "" if published is None else ',"published_at":"%s"' % published
    return ('{"format":1,"id":"%s","url":"http://127.0.0.1:1/dl/%s","sha256":"00","sha256_source":"github-digest","typed":"%s","compat":%s,"installed_at":"%s"%s}\n'
            % (id, id, id, c, installed, p))


def toolchain(home, id, text=None, last_use=None):
    d = os.path.join(home, ".cache/roc/toolchains", id)
    put(os.path.join(d, "roc"), "fake")
    if text is not None:
        put(os.path.join(d, ".talon.json"), text)
    if last_use is not None:
        put(os.path.join(d, ".last-use"), last_use)


def case(name, entry="commands"):
    d = os.path.join(ROOT, name)
    for sub in ("given", "fx"):
        shutil.rmtree(os.path.join(d, sub), ignore_errors=True)
    put(os.path.join(d, "entry"), entry)
    return d


# ---- ls1-list
d = case("ls1-list")
h = os.path.join(d, "given/home")
put(os.path.join(h, ".config/talon/config.toml"), 'default-roc = "nightly-2026-10-14-38a3029"\n')
toolchain(h, "nightly-2026-10-09-258ab27", meta("nightly-2026-10-09-258ab27", "2026-10-20T12:00:00Z", "2026-10-09T15:00:00Z"), "2026-10-22T08:30:00Z\n")
toolchain(h, "nightly-2026-10-14-38a3029", meta("nightly-2026-10-14-38a3029", "2026-10-21T09:00:00Z", "2026-10-14T13:00:00Z"))
toolchain(h, "git-dd03c09e", '{"format":1,"id":"git-dd03c09e"}\n')
toolchain(h, "link-dev", '{"format":1,"id":"link-dev","path":"{w}/roc-src/zig-out/bin/roc","installed_at":"2026-10-21T09:30:00Z"}\n', "2026-10-21T10:00:00Z\n")
toolchain(h, "copy-fix-1", None, "2026-10-19T00:00:00Z\n")
t = os.path.join(h, ".cache/roc/toolchains")
put(os.path.join(t, "zig-0.17.0/zig"), "fake")
put(os.path.join(t, "nightly-2026-10-09-258ab27.lock"), "lock")
put(os.path.join(t, "nightly-2026-10-11-1a2b3c4.0123456789abcdef.tmp/roc"), "partial")
put(os.path.join(t, "notes.txt"), "not a compiler")
h2 = os.path.join(d, "given/home2")
put(os.path.join(h2, ".config/talon/config.toml"), 'default-roc = "nightly-2026-10-01-aaaaaaa"\n')
toolchain(h2, "nightly-2026-10-09-258ab27", meta("nightly-2026-10-09-258ab27", "2026-10-20T12:00:00Z"))
put(os.path.join(d, "given/home3/.config/talon/config.toml"), "nightly = false\n")
put(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\n")
put(os.path.join(d, "fx/commands"), """# R-CM15, R-CM19: `ls` is `list`. The table: the default has a star, a time is a date, `-` is no time (a missing file, a bad file). Not listed (R-LY1): a lock, a temp dir, zig, a file.
roc ls
# R-J3: --json has the envelope only. The same data.
roc list --json
# A default that is not installed: the warning on stderr, the table stays
roc ls env:HOME={w}/home2
# No toolchains dir
roc ls env:HOME={w}/home3
""")

# ---- df1-default
d = case("df1-default")
h = os.path.join(d, "given/home")
for id, at, pub in (("nightly-2026-10-09-258ab27", "2026-10-20T12:00:00Z", "2026-10-09T15:00:00Z"), ("nightly-2026-10-11-1a2b3c4", "2026-10-20T12:00:00Z", "2026-10-11T15:00:00Z"), ("nightly-2026-10-14-38a3029", "2026-10-20T12:00:00Z", "2026-10-14T15:00:00Z")):
    toolchain(h, id, meta(id, at, pub))
toolchain(h, "git-dd03c09e", '{"format":1,"id":"git-dd03c09e"}\n')
toolchain(h, "link-dev", '{"format":1,"id":"link-dev","path":"{w}/roc-src/zig-out/bin/roc"}\n')
toolchain(h, "copy-fix-1", '{"format":1,"id":"copy-fix-1"}\n')


def release(tag, size, digest="b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78"):
    day = tag.split("-")
    name = "roc_nightly-linux_x86_64-%s-%s-%s-%s.tar.gz" % (day[1], day[2], day[3], day[4])
    return ('{"tag_name":"%s","draft":false,"prerelease":false,"published_at":"%s-%s-%sT15:00:00Z","assets":[{"name":"%s","size":%d,"digest":"sha256:%s","browser_download_url":"https://github.com/roc-lang/nightlies/releases/download/%s/%s"}]}'
            % (tag, day[1], day[2], day[3], name, size, digest, tag, name))


put(os.path.join(d, "fx/http/api.github.com/repos/roc-lang/nightlies/releases?per_page=100"),
    "[\n" + ",\n".join([release("nightly-2026-10-17-601b54c", 73100000), release("nightly-2026-10-13-91fa0c2", 73500000), release("nightly-2026-10-12-2664a27", 73600000)]) + "\n]\n")
put(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\nTALON_INTERACTIVE=1\n")
put(os.path.join(d, "fx/answers"), "\nn\n\n")
put(os.path.join(d, "fx/tty"), "stdin=true\nstderr=true\n")
put(os.path.join(d, "fx/programs"), "curl\nwget\ntar\n")
put(os.path.join(d, "fx/platform"), "os=linux arch=x64\nos=linux arch=x64\nos=linux arch=x64\nos=linux arch=x64\nos=linux arch=x64\n")
put(os.path.join(d, "given/home2/.gitkeep"), "")
put(os.path.join(d, "given/home3/.gitkeep"), "")
put(os.path.join(d, "fx/jobs"), "# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod, R-GC10 the compat check. The first rule whose needle is in the arguments answers.\n"
    "curl --fail\t0\t-\t-\tfile:{out}\n"
    "tar -xf\t0\t-\t-\tfile:{dir}/roc;file:{dir}/LICENSE;file:{dir}/legal_details\n"
    "chmod 0755\t0\t-\t-\t-\n"
    "nightly-2026-10-17-601b54c.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{w}/home/.cache/roc/compat-601b54c\n"
    "/home2/.cache/roc/toolchains/nightly-2026-10-13-91fa0c2.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{w}/home2/.cache/roc/compat-91fa0c2\n"
    "/home3/.cache/roc/toolchains/nightly-2026-10-13-91fa0c2.0123456789abcdef.tmp/roc check\t1\t-\t1 error and 0 warnings\tdir:{w}/home3/.cache/roc/compat-91fa0c2\n")
put(os.path.join(d, "fx/commands"), """# R-CS2, R-CC6: no config.toml: it is made, one line
roc default nightly-2026-10-09-258ab27
# R-CS2, R-CC6: the value is replaced (comments and order: L0 `default_set`, L3 `mg1-manage`)
roc default nightly-2026-10-11-1a2b3c4
# R-SC13, R-SC10: a unique prefix of an installed id gives the full id. It is the default already: no write.
roc default nightly-2026-10-11
# R-R5, R-SC9: a prefix of an installed git build (no list has it). The full id is stored.
roc default git-dd03
# R-SC10: an ambiguous prefix lists the ids: exit 2, no change
roc default nightly-2026-10-1
# R-CM15: no operand, and 2 operands: exit 2
roc default
roc default link-dev copy-fix-1
# R-R5, R-J3: a link, chosen by name. --json has the envelope only.
roc default link-dev --json
# R-DL3, R-NI6, R-CC4: a compiler that is not installed is the download of roc install (the prompt, Enter is yes). Then it is the default.
roc default nightly-2026-10-17-601b54c
# R-DL3: a declined prompt: exit 13, the default stays
roc default nightly-2026-10-12-2664a27
# R-DI12: --offline and the compiler is not installed (the list is cached now): exit 15, the default stays
roc default nightly-2026-10-13-91fa0c2 --offline
# Q7 (manager answer): the text and `changed` describe the whole command, compared with the state before it. HOME is home2: no config.toml, so the download writes the first default (R-SO15) and the command has changed it. Text: `installed <id>`, then `<id> is now the default compiler`.
roc default nightly-2026-10-13-91fa0c2 env:HOME={w}/home2
# Q7: the same with --json (home3, no prompt in a json run): `changed` is true
roc default nightly-2026-10-13-91fa0c2 --json env:HOME={w}/home3
""")

# ---- rm1-remove
d = case("rm1-remove")
h = os.path.join(d, "given/home")
put(os.path.join(h, ".config/talon/config.toml"), '# tln settings\nnightly = true\ndefault-roc = "nightly-2026-October-14-38a3029"   # tln roc default writes it\n')
toolchain(h, "nightly-2026-10-09-258ab27", meta("nightly-2026-10-09-258ab27", "2026-10-20T12:00:00Z", "2026-10-09T15:00:00Z", "258ab27"))
toolchain(h, "nightly-2026-10-11-1a2b3c4", meta("nightly-2026-10-11-1a2b3c4", "2026-10-20T12:00:00Z", "2026-10-11T15:00:00Z"))
toolchain(h, "nightly-2026-10-12-2664a27", meta("nightly-2026-10-12-2664a27", "2026-10-20T12:00:00Z", "2026-10-12T15:00:00Z"))
toolchain(h, "nightly-2026-10-14-38a3029", meta("nightly-2026-10-14-38a3029", "2026-10-20T12:00:00Z", "2026-10-14T13:00:00Z", "38a3029"))
toolchain(h, "git-dd03c09e", '{"format":1,"id":"git-dd03c09e"}\n')
toolchain(h, "link-dev", '{"format":1,"id":"link-dev","path":"{w}/project/roc-src/zig-out/bin/roc","installed_at":"2026-10-21T09:30:00Z"}\n')
put(os.path.join(h, ".cache/roc/compat-258ab27/cache.bin"), "build cache")
put(os.path.join(h, ".cache/roc/compat-38a3029/cache.bin"), "build cache")
put(os.path.join(h, ".cache/roc/compat-other/cache.bin"), "build cache of a compiler that Talon did not install")
put(os.path.join(d, "given/project/roc-src/zig-out/bin/roc"), "the compiler that the link points to")
p = os.path.join(d, "given/project")
put(os.path.join(p, "a/main.roc"), HEADER.format(roc='\n\troc: "nightly-2026-10-14-38a3029",'))
put(os.path.join(p, "b/main.roc"), HEADER.format(roc='\n\troc: "nightly-2026-October-14-38a3029",'))
put(os.path.join(p, "c/main.roc"), HEADER.format(roc='\n\troc: "nightly-2026-10-09-258ab27",'))
put(os.path.join(p, "d/main.roc"), 'app [main!] { pf: platform "')
put(os.path.join(p, "e/main.roc"), HEADER.format(roc=""))
entries = ",".join('{"path":"{w}/project/%s/main.roc","last_use":1792065600}' % n for n in ("a", "b", "c", "d", "e", "gone"))
put(os.path.join(h, ".cache/roc/talon/projects.json"), '{"format":1,"projects":[%s]}\n' % entries)
put(os.path.join(d, "fx/env"), "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\nTALON_INTERACTIVE=1\n")
put(os.path.join(d, "fx/tty"), "stdin=true\nstderr=true\n")
# Review of Q2: `rm` waits for the item lock. The lock of link-dev is held by another process at first (the fake gives Held at the wait).
put(os.path.join(d, "fx/locks"), "busy toolchains/link-dev\n")
put(os.path.join(d, "fx/commands"), """# R-SC10: an ambiguous prefix lists the ids, and no match: exit 2. R-CM15: no operand, and 2 operands: exit 2. Nothing is removed.
roc rm nightly-2026-10-1
roc rm nightly-2099
roc rm
roc remove nightly-2026-10-11-1a2b3c4 nightly-2026-10-12-2664a27
# R-CM19, R-GC3, R-RR2: `rm` is `remove`. Not the default. The project c pins it: it is listed, no prompt (TALON_INTERACTIVE=1 and no ask call). The compat dir goes with it, the compat dir of another compiler stays.
roc rm nightly-2026-10-09-258ab27
# R-RR1, R-RR2, R-CV1: the default (a prefix). config.toml stores it in the other tag form (nightly-2026-October-14-38a3029), and the compiler is the same one (Pin.same_id). The projects a and b pin it (b in the other tag form). The default moves to the newest installed nightly by published_at: 2026-10-12, not 2026-10-11. config.toml: the value changes, the comment stays.
roc remove nightly-2026-10-14
# R-RR1, R-NS3: the default again, and the nightly switch is off (the environment beats config.toml): no compiler can take the default, so the line default-roc goes.
roc rm nightly-2026-10-12-2664a27 env:TALON_NIGHTLY=false
# R-RR3, R-RM2: a link. The dir of the link goes, the target stays (project/roc-src).
roc rm link-dev
# R-J3: --json has the envelope only. A git build is never the next default (R-NS6).
roc rm git-dd --json
""")
print("done")
