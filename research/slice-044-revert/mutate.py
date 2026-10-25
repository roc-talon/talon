#!/usr/bin/env python3
"""Revert check of slice 044 (test agent only): each mutation changes the private reference in cli/lib in one small way, then the filtered tests run:
L0 `tests/unit/l0-6.roc`, L2 `tests/commands/run.sh zig/`, L3 `tests/run.sh compilers/zi1`. The reference is put back after each run.
Usage: mutate.py [id ...]   Output: one line for each mutation in research/slice-044-revert/mutate.log"""
import os, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
R = "research/slice-044-revert"
ROC = os.environ.get("ROC") or open(os.path.join(ROOT, "scripts/env.sh")).read() and None

M = [
    ("M1", "cli/lib/Zig.roc", "in_order = [Env, Path, Installed].join_map", "in_order = [Path, Env, Installed].join_map", "search order: PATH before ZIG"),
    ("M2", "cli/lib/Zig.roc", "(Ok(w), Ok(s)) => s == w", "(Ok(_), Ok(_)) => f.version == facts.need", "match by the whole version, not the major and minor"),
    ("M3", "cli/lib/Zig.roc", 'e.is_dir and e.name.starts_with("zig-") and is_release(e.name.drop_prefix("zig-"))', 'e.is_dir and e.name.starts_with("zig-")', "a temp dir, a lock dir and zig-dev count as an installed Zig"),
    ("M4", "cli/lib/ZigInstall.roc", "Toolchain.check_download({ id: id_of(ctx), want: entry.sha256, got })?", "_ = Toolchain.check_download({ id: id_of(ctx), want: entry.sha256, got })", "the sha256 check does not stop the install"),
    ("M5", "cli/lib/Zig.roc", "is_sha256 = |text| text.count_utf8_bytes() == 64 and", "is_sha256 = |text| text.count_utf8_bytes() >= 0 and", "any shasum text is accepted (short, not hex)"),
    ("M6", "cli/lib/Zig.roc", "\t\t\t\t_ => Err(Other)\n\t\t\t},\n\t\t)\n\t\tbest", "\t\t\t\t(Err(_), Obj(fields)) => if key == \"master\" and master_fits(fields, want) Ok({ key, rank: { major: want.major, minor: want.minor, patch: 999 }, fields }) else Err(Other)\n\t\t\t\t_ => Err(Other)\n\t\t\t},\n\t\t)\n\t\tbest", "the master entry counts when its version has the series"),
    ("M7", "cli/lib/Zig.roc", '\t\tMacosX64 => "x86_64-macos"\n\t\tMacosApple => "aarch64-macos"', '\t\tMacosX64 => "aarch64-macos"\n\t\tMacosApple => "x86_64-macos"', "the keys of the 2 macOS hosts are swapped"),
    ("M8a", "cli/lib/Consent.roc", "\t\t\tdefault: Yes,\n\t\t\tquestion: \"Install zig", "\t\t\tdefault: No,\n\t\t\tquestion: \"Install zig", "the interactive default of the Zig prompt is No"),
    ("M8b", "cli/lib/Consent.roc", "\t\t\tid: \"zig-install\",\n\t\t\tkind: Default,", "\t\t\tid: \"zig-install\",\n\t\t\tkind: Required([\"--allow-downloads\"]),", "the Zig prompt is Required (non-interactive stops with exit 13)"),
    ("M9", "cli/lib/ZigInstall.roc", "\tif asked.answer != Yes return Err(Consent.zig_install_declined(entry.version))\n", "\t_ = asked\n", "a No answer does not stop the install"),
    ("M10", "cli/lib/ZigInstall.roc", "\tif facts.offline return Err(", "\tif facts.offline and facts.need.is_empty() return Err(", "--offline does not stop before the request"),
    ("M11", "cli/lib/ZigInstall.roc", "\tif !stale.is_empty() {", "\tif !stale.is_empty() and stale.len() > 99 {", "stale temps are not deleted"),
    ("M12", "cli/lib/Zig.roc", "\t\tLinuxX64 | LinuxArm64 => facts.archive.ends_with(\".tar.xz\")\n\t\t_ => Bool.False", "\t\t_ => facts.archive.ends_with(\".tar.xz\")", "xz is needed on every host"),
    ("M13", "cli/lib/ZigInstall.roc", "\t\tif !facts.quiet {\n\t\t\tfx.err!(Zig.deps(", "\t\tif facts.quiet or !facts.quiet {\n\t\t\tfx.err!(Zig.deps(", "--quiet does not hide the dependency list"),
    ("M14", "cli/lib/ZigInstall.roc", "\tif entries.any(|e| e.is_dir and e.name == name) return Ok(Present)\n", "\tif entries.any(|e| e.is_dir and e.name == name and name.is_empty()) return Ok(Present)\n", "no check for the dir under the lock"),
]
MASTER_FN = '''
master_fits : List((Str, JsonDoc)), { major : U64, minor : U64 } -> Bool
master_fits = |fields, want| match field(fields, "version") {
	Ok(Text(v)) => match Zig.series(v) {
		Ok(s) => s == want
		Err(_) => Bool.False
	}
	_ => Bool.False
}
'''


def sh(cmd, timeout=900):
    p = subprocess.run(["/bin/bash", "-c", cmd], cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout + p.stderr


def main():
    want = sys.argv[1:]
    log = open(os.path.join(ROOT, R, "mutate.log"), "a")
    for mid, path, old, new, note in M:
        if want and mid not in want:
            continue
        sh(f"{R}/ref-apply.sh")
        full = os.path.join(ROOT, path)
        text = open(full).read()
        assert text.count(old) == 1, (mid, text.count(old))
        text = text.replace(old, new)
        if mid == "M6":
            text += MASTER_FN
        open(full, "w").write(text)
        env = 'ROC=$(. scripts/env.sh; echo $ROC)'
        rc0, out0 = sh(". scripts/env.sh; $ROC test tests/unit/l0-6.roc --no-cache --jobs=2")
        rc2, out2 = sh("tests/commands/run.sh zig/")
        rc3, out3 = sh("tests/run.sh compilers/zi1")
        compile = ("compiler error" in out0 and "0 compiler errors" not in out0) or "build of" in out2 + out3
        res = lambda rc: "pass" if rc == 0 else "FAIL"
        line = f"{mid} | {note} | l0 {res(rc0)} | l2 {res(rc2)} | l3 {res(rc3)}" + (" | COMPILE?" if compile else "")
        print(line, flush=True)
        log.write(line + "\n")
        log.flush()
        open(os.path.join(ROOT, R, f"mutate-{mid}.out"), "w").write("== l0\n" + out0[-3000:] + "\n== l2\n" + out2[-3000:] + "\n== l3\n" + out3[-3000:])
    sh(f"{R}/ref-apply.sh")


main()
