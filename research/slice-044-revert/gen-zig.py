#!/usr/bin/env python3
"""Makes the given/ and fx/ files of the slice 044 cases (test agent only). It writes no expect/ file (TW21):
`UPDATE=1 tests/commands/run.sh zig/` and `UPDATE=1 tests/run.sh compilers/zi1` write them, after a check by eye.
Usage: gen-zig.py l2   (the L2 cases under tests/commands/cases/zig/)   |   gen-zig.py l3"""
import hashlib, json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FAKE_SHA = hashlib.sha256(b"fake").hexdigest()  # the fake `curl` writes the text `fake`
OTHER_SHA = hashlib.sha256(b"other bytes").hexdigest()


def put(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def target_obj(base, version, key, size, sha):
    ext = "zip" if key.endswith("windows") else "tar.xz"
    return {"tarball": f"{base}/{version}/zig-{key}-{version}.{ext}", "shasum": sha, "size": str(size)}


def release(base, version, keys, sizes, sha_of, date):
    obj = {"date": date, "docs": f"https://ziglang.org/documentation/{version}/", "stdDocs": f"https://ziglang.org/documentation/{version}/std/"}
    obj["src"] = {"tarball": f"{base}/{version}/zig-{version}.tar.xz", "shasum": "f" * 64, "size": "17000000"}
    for key in keys:
        obj[key] = target_obj(base, version, key, sizes[key], sha_of(version, key))
    return obj


def index(base, versions, keys, sha_of):
    """versions: list of (version, date). The first key is `master` (a dev version of the next series)."""
    sizes = {"x86_64-linux": 54227812, "aarch64-linux": 50100000, "x86_64-macos": 52300000, "aarch64-macos": 48000001, "x86_64-windows": 79000000, "aarch64-windows": 74999999}
    out = {"master": {"version": "0.18.0-dev.5+abcdef", "date": "2026-10-20", "x86_64-linux": {"tarball": f"{base}/builds/zig-x86_64-linux-0.18.0-dev.5+abcdef.tar.xz", "shasum": "9" * 64, "size": "1"}}}
    for version, date in versions:
        out[version] = release(base, version, keys, sizes, sha_of, date)
    return json.dumps(out, indent=2) + "\n"


def l2():
    base = os.path.join(ROOT, "tests/commands/cases/zig")
    url = "https://ziglang.org/download"
    env = "HOME={w}/home\nTALON_NOW=2026-10-22T12:00:00Z\nTALON_INTERACTIVE=1\n"
    tty = "stdin=true\nstderr=true\n"

    # zs1-search: the search order, no download (R-D1, R-D3, R-EV11)
    c = os.path.join(base, "zs1-search")
    put(f"{c}/entry", "zig\n")
    put(f"{c}/fx/env", env)
    put(f"{c}/fx/programs", "zig\n")
    put(f"{c}/fx/platform", "os=linux arch=x64\n" * 6 + "os=windows arch=x64\n")
    put(f"{c}/fx/jobs", "# R-D1: `zig version` of the program of ZIG, and of `zig` on PATH. The first rule whose needle is in the arguments answers.\n"
        "/opt/z17/zig version\t0\t0.17.1\t-\t-\n"
        "/opt/z16/zig version\t0\t0.16.9\t-\t-\n"
        "zig version\t0\t0.16.0\t-\t-\n")
    put(f"{c}/fx/runs", "# 1: nothing fits (PATH has 0.16.0, the installed dirs are 0.18.0 and no Zig), --offline: exit 15 after the list\n"
        "0.17.0 offline\n"
        "# 2: ZIG fits and comes first\n"
        "0.17.0 offline env:ZIG=/opt/z17/zig\n"
        "# 3: PATH, the same major and minor (0.16.0 for 0.16.2)\n"
        "0.16.2 offline\n"
        "# 4: an installed Zig (0.18.0 for 0.18.1)\n"
        "0.18.1 offline\n"
        "# 5: --quiet hides the list\n"
        "0.16.2 offline quiet\n"
        "# 6: ZIG and PATH both fit: ZIG comes first\n"
        "0.16.2 offline env:ZIG=/opt/z16/zig\n"
        "# 7: a Windows host runs zig.exe\n"
        "0.18.1 offline\n")
    t = f"{c}/given/home/.cache/roc/toolchains"
    put(f"{t}/zig-0.18.0/zig", "fake zig 0.18.0\n")
    put(f"{t}/zig-0.17.0.00000000000000aa.tmp/partial", "a stale temp: not an installed Zig\n")
    put(f"{t}/zig-0.17.0.lock/owner", "a lock dir: not an installed Zig\n")
    put(f"{t}/zig-0.17.5", "a file: not an installed Zig\n")
    put(f"{t}/nightly-2026-10-09-258ab27/roc", "fake roc\n")

    # zi1-install: the install flow (R-D2, R-CC4, R-NI6, R-DL1, R-DL3, R-DL4, R-EV16, R-EV21)
    c = os.path.join(base, "zi1-install")
    put(f"{c}/entry", "zig\n")
    put(f"{c}/fx/env", env)
    put(f"{c}/fx/tty", tty)
    put(f"{c}/fx/programs", "curl\nwget\ntar\nxz\n")
    put(f"{c}/fx/platform", "os=linux arch=x64\nos=linux arch=x64\nos=windows arch=x64\n" + "os=linux arch=x64\n" * 9)
    put(f"{c}/fx/answers", "\nn\n")
    put(f"{c}/fx/locks", "busy toolchains/zig-0.14.1 creates:{w}/home/.cache/roc/toolchains/zig-0.14.1\n")
    put(f"{c}/fx/jobs", "# R-DA3 the download, R-HF5 the extract, R-HF2 the chmod. The first rule whose needle is in the arguments answers.\n"
        "0.7.0.tar.xz https://\t22\t-\tcurl: (22) The requested URL returned error: 404\t-\n"
        "zig-x86_64-linux-0.8.0.tar.xz -C\t2\t-\ttar: Removing leading `/' from member names: bad archive\t-\n"
        "curl --fail\t0\t-\t-\tfile:{out}\n"
        "zig-x86_64-windows-0.16.2.zip -C\t0\t-\t-\tfile:{dir}/zig.exe;file:{dir}/LICENSE;dir:{dir}/lib\n"
        "tar -xf\t0\t-\t-\tfile:{dir}/zig;file:{dir}/LICENSE;dir:{dir}/lib\n"
        "chmod 0755\t0\t-\t-\t-\n")
    versions = [("0.17.0", "2026-09-01"), ("0.16.2", "2026-03-10"), ("0.15.1", "2025-08-19"), ("0.14.1", "2025-05-21"), ("0.13.0", "2024-06-07"), ("0.12.1", "2024-06-08"), ("0.8.0", "2021-06-04"), ("0.7.0", "2020-11-08")]

    def sha_of(version, key):
        return OTHER_SHA if version == "0.13.0" else FAKE_SHA
    put(f"{c}/fx/http/ziglang.org/download/index.json", index(url, versions, ["x86_64-linux", "x86_64-windows"], sha_of))
    runs = [
        "# 1: nothing is there, interactive, Enter is Yes. A stale temp is deleted (R-CC4 step 5). The full install, the order of the calls",
        "0.17.0",
        "# 2: now installed: found, no request, no lock",
        "0.17.0",
        "# 3: a Windows host (.zip, zig.exe, no chmod, no xz), --yes",
        "0.16.2 yes",
        "# 4: the person answers n: exit 13, no lock, nothing downloaded",
        "0.15.1",
        "# 5: a busy lock, the holder makes the dir: found under the lock, no download (R-CC4 step 4)",
        "0.14.1 yes",
        "# 6: the sha256 of the index differs from the download: exit 16, the temp dir is deleted",
        "0.13.0 yes",
        "# 7: non-interactive (no --yes): the answer line, no prompt, the download starts (R-DL4, R-NI6)",
        "0.12.1 env:TALON_INTERACTIVE=0",
        "# 8: TALON_ZIG_INDEX replaces the URL (R-EV16, R-EV21). The route does not exist: exit 15",
        "0.10.1 yes env:TALON_ZIG_INDEX=http://127.0.0.1:9/zig/index.json",
        "# 9: the index has no release of the series: exit 18, no prompt",
        "0.99.0",
        "# 10: tar fails: exit 16 (as for a compiler), the temp dir is deleted",
        "0.8.0 yes",
        "# 11: curl fails with 404: exit 15, the temp dir is deleted",
        "0.7.0 yes",
        "# 12: --offline and nothing fits: exit 15, no request",
        "0.17.9 offline",
    ]
    # run 12: 0.17.9 has the series of the installed 0.17.0 -> found, so use a series that is not installed
    runs[-1] = "0.6.0 offline"
    put(f"{c}/fx/runs", "\n".join(runs) + "\n")
    put(f"{c}/given/home/.cache/roc/toolchains/zig-0.17.0.00000000000000aa.tmp/partial", "a stale temp of the install of run 1\n")
    put(f"{c}/given/home/.cache/roc/toolchains/nightly-2026-10-09-258ab27/roc", "fake roc\n")

    # zi2-xz: R-EC18, R-HF5: `.tar.xz` needs `xz` on Linux, and not on macOS
    c = os.path.join(base, "zi2-xz")
    put(f"{c}/entry", "zig\n")
    put(f"{c}/fx/env", env)
    put(f"{c}/fx/tty", tty)
    put(f"{c}/fx/programs", "curl\ntar\n")
    put(f"{c}/fx/platform", "os=linux arch=x64\nos=macos arch=arm64\n")
    put(f"{c}/fx/jobs", "curl --fail\t0\t-\t-\tfile:{out}\ntar -xf\t0\t-\t-\tfile:{dir}/zig;file:{dir}/LICENSE;dir:{dir}/lib\nchmod 0755\t0\t-\t-\t-\n")
    put(f"{c}/fx/runs", "# 1: Linux, no xz on PATH: exit 18 that names xz, before any download. Nothing is made.\n0.17.0 yes\n# 2: macOS, no xz: tar reads .tar.xz itself, so the install works (chmod runs)\n0.17.0 yes\n")
    put(f"{c}/fx/http/ziglang.org/download/index.json", index(url, [("0.17.0", "2026-09-01")], ["x86_64-linux", "aarch64-macos"], lambda v, k: FAKE_SHA))


if __name__ == "__main__":
    if sys.argv[1:] == ["l2"]:
        l2()
    elif sys.argv[1:] == ["l3"]:
        sys.exit("l3: see gen-zig-l3.sh")
    else:
        sys.exit(__doc__)
