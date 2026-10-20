#!/usr/bin/env python3
"""Revert check of slice 002 (TW12): break the code of each rule in one small way, run the tests that should catch it,
put the file back. Usage: research/slice-002-revert/revert.py [id-filter ...]. Writes the table to stdout.
A compile error of a mutation is reported as INVALID (it is not a catch)."""
import os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROC = os.environ.get("ROC", f"{ROOT}/cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc")

# (rule ids, file under cli/, old text, new text, test)   test: l0:<unit file> | l2:<filter> | l3:<filter>
M = [
    ("R-PD1", "lib/Project.roc", 'full = if facts.path.starts_with("/") facts.path else "${facts.base}/${facts.path}"', 'full = facts.path', "l0:project"),
    ("R-PD2 git", "lib/Project.roc", 'facts.names.contains(".git") or facts.dir == facts.home', 'facts.dir == facts.home', "l0:project"),
    ("R-PD2 home", "lib/Project.roc", 'facts.names.contains(".git") or facts.dir == facts.home', 'facts.names.contains(".git")', "l0:project"),
    ("R-PD2 listing", "lib/Project.roc", 'if Project.stops({ dir, names, home }) {', 'if Project.stops({ dir, names: [], home }) {', "l2:pd-search"),
    ("R-PD3 nearest root", "lib/Project.roc", 'Ok(Ok(patterns)) => Ok(Ok({ dir: d.dir, patterns }))', 'Ok(Ok(_)) => root_search(above)', "l0:project"),
    ("R-PD3 glob", "lib/Members.roc", 'name.starts_with(first) and', 'name.contains(first) and', "l0:members"),
    ("R-PD3 expand", "lib/Members.roc", 'Need(Text.sorted_unique(needs))', 'Need(needs)', "l0:members"),
    ("R-PD4 two members", "lib/Project.roc", '[only] => Ok(Ok(only))', '[only, ..] => Ok(Ok(only))', "l0:project"),
    ("R-PD5 non-member", "lib/Project.roc", '(Ok(dir), Bool.True) =>', '(Ok(dir), _) =>', "l0:project"),
    ("R-PD5 order of calls", "lib/Project.roc", 'listed_walk = walk!(fx, start, facts.home, [])', 'listed_walk = walk!(fx, start, facts.home, []).drop_last(1)', "l2:pd-search"),
    ("R-PD6", "lib/Project.roc", 'Ok(_) => if root_dir == Ok(dir) Err(NoToml) else Ok(Text.join(dir, "talon.toml"))', 'Ok(_) => Ok(Text.join(dir, "talon.toml"))', "l0:project"),
    ("R-PD8", "lib/Project.roc", 'Err(Fail.new(Usage, "${facts.path} has no app', 'Err(Fail.new(Input, "${facts.path} has no app', "l0:project"),
    ("R-PD9", "lib/Known.roc", 'if facts.files.is_empty() return Ok({})', 'if facts.files.len() < 100 return Ok({})', "l2:cc-locked"),
    ("R-PD10", "lib/Projects.roc", 'Ok(seconds) => now > last_use and now - last_use > seconds', 'Ok(seconds) => now > last_use and now - last_use >= seconds', "l0:projects"),
    ("R-PD11", "lib/Projects.roc", 'is_skipped = |cache, file| file.starts_with("${cache}/talon/tmp/") or file.starts_with("${cache}/packages/")', 'is_skipped = |_cache, _file| Bool.False', "l0:projects"),
    ("R-PD12 sort", "lib/Projects.roc", 'Ok(Write(write_text(loaded, done.items.sort_with(|a, b| Text.compare(a.path, b.path)))))', 'Ok(Write(write_text(loaded, done.items)))', "l0:projects"),
    ("R-PD12 always", "lib/Projects.roc", 'Always => last_use != now', 'Always => Bool.False', "l0:projects"),
    ("R-PD13", "lib/Projects.roc", 'keeps = |item| facts.valid.contains(item.path) and', 'keeps = |item| Bool.True and', "l0:projects"),
    ("R-LY1 R-LY2", "lib/Roots.roc", 'Toolchain(id) => Text.join(roots.cache, "toolchains/${id}")', 'Toolchain(id) => Text.join(roots.cache, "toolchain/${id}")', "l0:roots"),
    ("R-LY3", "lib/Lock.roc", 'dir = |item| "${item}.lock"', 'dir = |item| "${item}.lck"', "l0:lock"),
    ("R-LY4", "lib/Setting.roc", 'pick = |layers| match layers.flag {', 'pick = |layers| match layers.env {', "l0:roots"),
    ("R-LY5", "lib/Roots.roc", 'cache = Text.join(base("XDG_CACHE_HOME", ".cache")?, "roc")', 'cache = base("XDG_CACHE_HOME", ".cache")?', "l0:roots"),
    ("R-LY6", "lib/Roots.roc", 'config: Text.join(base("XDG_CONFIG_HOME", ".config")?, "talon")', 'config: Text.join(base("XDG_CONFIG_HOME", ".config")?, "talonx")', "l0:roots"),
    ("R-LY7", "lib/Roots.roc", 'data: Text.join(base("XDG_DATA_HOME", ".local/share")?, "talon")', 'data: Text.join(base("XDG_CONFIG_HOME", ".local/share")?, "talon")', "l0:roots"),
    ("R-EV13", "lib/Roots.roc", 'Ok(dir) => dir\n\t\t\t\tErr(Unset) => cache', 'Ok(_) => cache\n\t\t\t\tErr(Unset) => cache', "l0:roots"),
    ("R-CR1", "lib/Roots.roc", 'pkgs: Text.join(cache, "packages"),', 'pkgs: Text.join(match var_of("ROC_CACHE_DIR") {\n\t\t\t\tOk(dir) => dir\n\t\t\t\tErr(Unset) => cache\n\t\t\t}, "packages"),', "l0:roots"),
    ("R-TF1 order", "lib/TalonFile.roc", '[("format", JsonDoc.Num(facts.format.to_i64_wrap()))].concat(facts.fields)', 'facts.fields.concat([("format", JsonDoc.Num(facts.format.to_i64_wrap()))])', "l0:talonfile"),
    ("R-TF1 parse", "lib/JsonDoc.roc", 'Ok(93) => Ok({ val: Arr(more), next: after + 1 })', 'Ok(93) | Ok(44) => Ok({ val: Arr(more), next: after + 1 })', "l0:talonfile"),
    ("R-TF2", "lib/TalonFile.roc", 'fields: pairs.keep_if(|(key, _)| key != "format")', 'fields: pairs.keep_if(|(key, _)| key == "projects")', "l0:talonfile"),
    ("R-TF3", "lib/TalonFile.roc", 'if format > facts.newest {', 'if format > facts.newest + 1 {', "l0:talonfile"),
    ("R-TF4", "lib/Project.roc", '_ => Err(NotText)', '_ => Ok("x")', "l0:project"),
    ("R-TF5", "lib/Project.roc", 'line = 1 + facts.text', 'line = 0 + facts.text', "l0:project"),
    ("R-TF6", "lib/TalonFile.roc", 'Err(Fail.new(Input, "${facts.path}: the content does not parse"))', 'Err(Fail.new(Usage, "${facts.path}: the content does not parse"))', "l0:talonfile"),
    ("R-CC1 name", "lib/Temp.roc", 'name = |facts| "${facts.target}.${facts.hex}.tmp"', 'name = |facts| "${facts.target}.${facts.hex}.temp"', "l0:temp"),
    ("R-CC1 in place", "RealFx.roc", 'tmp = Path.utf8(Temp.name({ target: file.path, hex: Temp.hex(draw!()) }))', 'tmp = Path.utf8(file.path)', "l3:cc1-atomic"),
    ("R-CC1 parents", "RealFx.roc", '\tparent = Text.dir_of(file.path)\n\tif !parent.is_empty() {\n\t\t_ = Path.create_all!(Path.utf8(parent))\n\t}\n\ttmp', '\ttmp', "l3:cc1-atomic"),
    ("R-CC11", "RealFx.roc", 'Ok(_) => match Path.rename!(tmp, Path.utf8(file.path)) {', 'Ok(_) => match Path.rename!(tmp, Path.utf8("${file.path}.x")) {', "l3:cc1-atomic"),
    ("R-CC2 holder", "lib/Known.roc", '_ = fx.delete!(temps)', '_ = temps', "l2:cc-locked"),
    ("R-CC2 holder L3", "lib/Known.roc", '_ = fx.delete!(temps)', '_ = temps', "l3:cc1-atomic"),
    ("R-CC2 item", "lib/Temp.roc", 'rest.ends_with(".tmp") and is_hex16(rest.drop_suffix(".tmp"))', 'rest.ends_with(".tmp")', "l0:temp"),
    ("R-CC2 gc age", "lib/Temp.roc", 'now > mtime and now - mtime > 86400', 'now > mtime and now - mtime >= 86400', "l0:temp"),
    ("R-CC3 unlock", "lib/Fx.roc", '\t\t\t\tfx.unlock!(lock)\n', '\t\t\t\t_ = lock\n', "l2:cc-locked"),
    ("R-CC3 busy", "lib/Fx.roc", 'Busy => Err(Busy)', 'Busy => body!().map_err(|e| Failed(e))', "l2:cc-locked"),
    ("R-CC5", "lib/Fx.roc", 'fx.err!(Lock.waiting_line(item))', '{}', "l2:cc-locked"),
    ("R-CC5 text", "lib/Lock.roc", '"waiting for another tln: ${Text.last_segment(item)}\\n"', '"waiting for another tln: ${item}\\n"', "l0:lock"),
    ("R-CC6", "lib/Known.roc", 'fx.with_lock!(item, Wait,', 'fx.with_lock!(item, NoWait,', "l2:cc-locked"),
    ("R-CC7", "lib/Guard.roc", 'f.read != f.now and f.spans_read != f.spans_now', 'Bool.False', "l0:guard"),
    ("R-CC12 state", "lib/Lock.roc", 'facts.now - stamp > 30', 'facts.now - stamp >= 30', "l0:lock"),
    ("R-CC12 owns", "lib/Lock.roc", '[first, ..] => first == facts.token and !facts.token.is_empty()', '[first, ..] => first.starts_with(facts.token)', "l0:lock"),
    ("R-CC12 take stale", "RealFx.roc", 'Lock.state({ now: clock!(), beat, dir: made })', 'Lock.state({ now: 0, beat, dir: made })', "l3:cc12-lock-contract"),
    ("R-CC12 unlock owner", "RealFx.roc", 'if Lock.owns({ owner, token: lock.token }) {', 'if Lock.owns({ owner, token: lock.token }) or owner != "" {', "l3:cc12-heartbeat"),
    ("R-CC12 heartbeat R-HF3", "RealFx.roc", 'if $polls % 10 == 0 {', 'if $polls % 10 == 99 {', "l3:cc12-heartbeat"),
    ("R-CC12 parents", "RealFx.roc", '\tparent = Text.dir_of(item)\n\tif !parent.is_empty() {\n\t\t_ = Path.create_all!(Path.utf8(parent))\n\t}\n\tvar $polls', '\tvar $polls', "l3:cc12-lock-contract"),
    ("R-CC12 stale dir kept", "RealFx.roc", '_ = Path.delete_all!(gone)', '{}', "l3:cc12-lock-contract"),
    ("R-HF3 nowait", "RealFx.roc", 'NoWait => Busy\n\t\tWait => Waiting', 'NoWait => Waiting\n\t\tWait => Waiting', "l3:cc12-lock-contract"),
]


def run(test):
    kind, what = test.split(":")
    env = dict(os.environ)
    if kind == "l0":
        cmd = [ROC, "test", f"tests/unit/{what}.roc", "--no-cache"]
    elif kind == "l2":
        cmd = ["tests/commands/run.sh", what]
    else:
        cmd = ["tests/run.sh", what]
        env["CASE_TIMEOUT"] = "40"
    p = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=300)
    out = p.stdout + p.stderr
    return p.returncode, out


def main():
    flt = sys.argv[1:]
    print("| Rule | Mutation (file) | Result |\n| --- | --- | --- |")
    caught = invalid = 0
    total = 0
    for ids, rel, old, new, test in M:
        if flt and not any(f in ids for f in flt):
            continue
        path = f"{ROOT}/cli/{rel}"
        text = open(path).read()
        if old not in text:
            print(f"| {ids} | {rel}: pattern not found | INVALID |")
            invalid += 1
            continue
        total += 1
        open(path, "w").write(text.replace(old, new, 1))
        try:
            rc, out = run(test)
        finally:
            open(path, "w").write(text)
        compile_error = re.search(r"[1-9][0-9]* compiler error", out) is not None or "Compilation failed" in out or "build of" in out or "build of the L2 app failed" in out
        if rc == 0:
            result = "NOT CAUGHT"
        elif compile_error:
            result = "INVALID (compile error)"
            invalid += 1
            total -= 1
        else:
            result = f"caught by {test}"
            caught += 1
        print(f"| {ids} | {rel}: `{old[:50].strip()}` | {result} |", flush=True)
    print(f"\ncaught {caught} of {total}, invalid {invalid}")


main()
