#!/usr/bin/env python3
# Plant one mutation at a time in roc-app-header package/, run the L0 test apps and
# the fuzz targets, restore the file, and print one result line per mutation.
# Usage: mutate-roc-app-header.py ORIG_PACKAGE_DIR [M-ID ...]
# Env: NOFUZZ=1 skips the fuzz targets. MRUNS sets the fuzz run count (default 20000).
import os, re, shutil, subprocess, sys, filecmp

HERE = os.path.dirname(os.path.abspath(__file__))
TALON = os.path.normpath(os.path.join(HERE, "../../.."))
# The package checkout is next to the Talon checkout.
REPO = os.environ.get("REPO", os.path.join(os.path.dirname(TALON), "roc-app-header"))
ROC = os.environ.get("ROC", os.path.join(TALON, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ORIG = sys.argv[1]  # the copy of package/ from step 0
W = os.path.join(REPO, ".work", "nightly-2026-10-14-38a3029")
env = dict(os.environ, XDG_CACHE_HOME=W + "/xdg", ROC_CACHE_DIR=W + "/xdg/roc")

P, V, H, I = "PackageUrl.roc", "Mvs.roc", "Header.roc", "Imports.roc"

M = [
    # PackageUrl.parse: the one X.Y.Z run (R-DI5, D3)
    ("M1 two runs accepted (first run used)", P, "\t\t\t[one] => one\n\t\t\t_ => return Err(ManyVersions)", "\t\t\t[one, ..] => one"),
    ("M2 no run gives ManyVersions", P, "[] => return Err(NoVersion)", "[] => return Err(ManyVersions)"),
    ("M3 0.0.0 accepted", P, "if run.major == 0 and run.minor == 0 and run.patch == 0 {", "if text.count_utf8_bytes() > 1000000000 {"),
    # Run limits (S5)
    ("M4 1.2.3.4 is a run", P, "[major, minor, patch] if number.fits =>", "[major, minor, patch, ..] if number.fits =>"),
    ("M5 leading zero part is not a run", P, "[major, minor, patch] if number.fits =>", "[major, minor, patch] if number.fits and !(at(bytes, $i) == '0' and is_digit(at(bytes, $i + 1))) =>"),
    ("M6 part above U64 is a run", P, "$fits = Bool.False", "$fits = Bool.True"),
    ("M20 host not searched (S6)", P, "\tvar $i = 0\n\twhile $i < bytes.len() {", "\tvar $i = bytes.find_first_index(|b| b == '/') ?? 0\n\twhile $i < bytes.len() {"),
    # Series and group (R-ID1, R-ID2, R-DI5)
    ("M7 series of 1.x is 0.minor", P, "if url.major >= 1 url.major.to_str()", "if url.major > 1 url.major.to_str()"),
    ("M15 group series is major only", P, "group = |url| { form: url.form, series: url.series() }", "group = |url| { form: url.form, series: url.major.to_str() }"),
    ("M8 hash segment in group form", P, "len: cut - run.end", "len: bytes.len() - run.end"),
    ("M9 tag prefix v not in group", P, "before = bytes.take_first(run.start)", "before = bytes.take_first(if run.start > 0 and at(bytes, run.start - 1) == 'v' run.start - 1 else run.start)"),
    ("M10 tag suffix -rcN not in group", P, "after = bytes.sublist({ start: run.end, len: cut - run.end })", "after = bytes.sublist({ start: run.end, len: cut - run.end }).drop_first(if at(bytes, run.end) == '-' 4 else 0)"),
    # Accessors
    ("M11 to_str drops https://", P, "to_str = |url| url.text", "to_str = |url| url.text.drop_prefix(\"https://\")"),
    ("M12 version swaps minor and patch", P, "version = |url| { major: url.major, minor: url.minor, patch: url.patch }", "version = |url| { major: url.major, minor: url.patch, patch: url.minor }"),
    ("M13 hash keeps .tar.zst", P, "Ok({ hash: after.drop_suffix(\".tar.zst\")", "Ok({ hash: after"),
    ("M14 url_form has the scheme", P, "url_form = |url| url.form", "url_form = |url| \"https://${url.form}\""),
    # Error order (S8) and hash (S9)
    ("M16 NoHash before BadScheme", P, "\t\trest = after_scheme(text)?\n", "\t\t_ = hash_segment(text)?\n\t\trest = after_scheme(text)?\n"),
    ("M17 ZeroVersion before ManyVersions", P, "\t\trun = match runs(bytes) {", "\t\tif runs(bytes).any(|r| r.major == 0 and r.minor == 0 and r.patch == 0) {\n\t\t\treturn Err(ZeroVersion)\n\t\t}\n\t\trun = match runs(bytes) {"),
    ("M18 NoVersion before NoHash", P, "\t\t{ hash, cut } = hash_segment(rest)?\n", "\t\tif runs(rest.to_utf8()).is_empty() {\n\t\t\treturn Err(NoVersion)\n\t\t}\n\t\t{ hash, cut } = hash_segment(rest)?\n"),
    ("M19 empty hash accepted", P, " and after != \".tar.zst\"", ""),
    # Mvs.select (Design 2 MVS, S1 to S4)
    ("M21 lowest version wins", V, "|best, u| if newer(u, best) u else best", "|best, u| if newer(best, u) u else best"),
    ("M22 minor compares by first digit (1.9 > 1.10)", V, "x.minor > y.minor", "(x.minor.to_str().to_utf8().first() ?? 0) > (y.minor.to_str().to_utf8().first() ?? 0)"),
    ("M23 deps of all reached versions followed", V, "record = (nodes.get(url.to_str()) ?? { url, deps: [] }).deps\n\t\t\t\t$followed = $followed.concat(record.map(|e| { edge: e, by: By(url) }))", "_record = (nodes.get(url.to_str()) ?? { url, deps: [] }).deps\n\t\t\t\t$followed = $followed.concat(unique_texts(into.map(|f| f.edge.url)).join_map(|u| (nodes.get(u.to_str()) ?? { url: u, deps: [] }).deps.map(|e| { edge: e, by: By(u) })))"),
    ("M24 self group edge is no cycle", V, "with_to.update(from, |old| Ok((old ?? Set.empty()).insert(to)))", "if to == from with_to else with_to.update(from, |old| Ok((old ?? Set.empty()).insert(to)))"),
    ("M25 Cycle reported as RootConflict", V, "Err(cycle) => return Err(Cycle(cycle))", "Err(cycle) => return Err(RootConflict(cycle))"),
    ("M26 RootConflict check removed", V, "if !root_conflicts.is_empty() {", "if root.len() > 1000000000 {"),
    ("M27 same root URL twice is RootConflict", V, "urls.keep_if(|u| urls.any(|other| other.group() == u.group() and other.version() != u.version()))", "urls.keep_if(|u| urls.count_if(|other| other.group() == u.group()) > 1)"),
    ("M28 ContentConflict check removed", V, "if !content.is_empty() {", "if root.len() > 1000000000 {"),
    ("M29 ContentConflict only for selected version (S2)", V, "content = content_conflicts(followed)", "content = content_conflicts(followed.keep_if(|f| chosen.any(|c| c.group() == f.edge.url.group() and c.version() == f.edge.url.version())))"),
    ("M30 VersionConflict when dep is lower than pin", V, "and newer(f.edge.url, r.url))", "and newer(r.url, f.edge.url))"),
    ("M31 VersionConflict check removed", V, "if !versions.is_empty() {", "if root.len() > 1000000000 {"),
    ("M32 root edge does not win in its group", V, "if !roots.is_empty() {", "if roots.len() > 1000000000 {"),
    ("M33 last URL text in byte order wins (S4)", V, "if bytes_before(u.to_str().to_utf8(), best.to_str().to_utf8()) u else best", "if bytes_before(best.to_str().to_utf8(), u.to_str().to_utf8()) u else best"),
    ("M34 PlatformMismatch checks root edges only", V, "followed.keep_if(|f| f.edge.is_platform)", "followed.keep_if(|f| f.edge.is_platform and f.by == Root)"),
    ("M35 PlatformMismatch ignores hash", V, " and a.hash() == b.hash()", ""),
    ("M36 error order: RootConflict before Cycle", V, "\t\tnodes = reach(root, deps)\n", "\t\tif !root_conflicts_of(root).is_empty() {\n\t\t\treturn Err(RootConflict(root_conflicts_of(root)))\n\t\t}\n\t\tnodes = reach(root, deps)\n"),
    ("M37 error order: VersionConflict before ContentConflict", V, "\t\tcontent = content_conflicts(followed)\n", "\t\tif !version_conflicts(root, followed).is_empty() {\n\t\t\treturn Err(VersionConflict(version_conflicts(root, followed)))\n\t\t}\n\t\tcontent = content_conflicts(followed)\n"),
    ("M38 error order: PlatformMismatch before VersionConflict", V, "\t\tversions = version_conflicts(root, followed)\n", "\t\tif !platform_mismatches(followed).is_empty() {\n\t\t\treturn Err(PlatformMismatch(platform_mismatches(followed)))\n\t\t}\n\t\tversions = version_conflicts(root, followed)\n"),
    # Header.parse, kind, exposed, entries, span (R-PK5, R-H1)
    ("M41 package header kind is App", H, "list_and_record(bytes, start, after, Package)", "list_and_record(bytes, start, after, App)"),
    ("M42 platform name keeps quotes", H, "kind: Platform(Lex.text(bytes, name_start + 1, name_end - 1))", "kind: Platform(Lex.text(bytes, name_start, name_end))"),
    ("M43 platform exposes list empty", H, "$exposed = list.names", "$exposed = []"),
    ("M44 exposed list drops last name", H, "Ok({ names: $names, end: $i + 1 })", "Ok({ names: $names.drop_last(1), end: $i + 1 })"),
    ("M45 entry span end included (end - 1)", H, "span: { start: i, end },", "span: { start: i, end: end - 1 },"),
    ("M46 value_span end includes closing quote", H, "end }, value_span })", "end }, value_span: { start: value_span.start, end: value_span.end + 1 } })"),
    ("M47 is_platform always false", H, "value_span.end), is_platform, span:", "value_span.end), is_platform: Bool.False, span:"),
    ("M48 header span end - 1 (app, package)", H, "span: { start, end: record.end }", "span: { start, end: record.end - 1 }"),
    ("M49 platform header span starts at 0", H, "span: { start, end: $end }", "span: { start: start * 0, end: $end }"),
    ("M69 NoHeader reported as BadHeader", H, "return Err(NoHeader)", "return Err(BadHeader({ offset: start }))"),
    # set_value (R-H1, S12)
    ("M51 set_value trims the end of the file", H, "Ok(splice(source.to_utf8(), entry.value_span, value))", "Ok(splice(source.to_utf8(), entry.value_span, value).trim_end())"),
    ("M53 $ in a value accepted", H, " or b == '$'", ""),
    ("M54 line break in a value accepted", H, "b == '$' or b == '\\n' or", "b == '$' or"),
    ("M55 set_value BadValue check removed", H, "if bad_value(value) {", "if value.count_utf8_bytes() > 1000000000 {"),
    # add_entry (S10)
    ("M56 add one line: no space after comma", H, 'splice(bytes, { start: after, end: after }, ", ${text}")', 'splice(bytes, { start: after, end: after }, ",${text}")'),
    ("M57 add many lines: fixed tab indent", H, '"${indent(bytes, last.span.start)}${text},${nl}"', '"\\t${text},${nl}"'),
    ("M58 add many lines: no comma added after last entry", H, 'if has_comma with_line else splice(with_line.to_utf8(), { start: after, end: after }, ",")', "with_line"),
    ("M59 add to {}: no spaces", H, '"{ ${text} }"', '"{${text}}"'),
    ("M60 add_entry Exists check removed", H, "if header.entries.any(|e| e.name == entry.name) {", "if entry.name.count_utf8_bytes() > 1000000000 {"),
    ("M62 add after first entry, not last", H, "header.entries.last()", "header.entries.first()"),
    ("M63 add_entry BadValue check removed", H, "if bad_value(entry.value) {", "if entry.value.count_utf8_bytes() > 1000000000 {"),
    # remove_entry (S11)
    ("M64 remove many lines: line break stays", H, "{ start: line, end: eol + 1 }", "{ start: line, end: eol }"),
    ("M65 remove many lines: line above goes too", H, "line = Lex.line_start(bytes, entry.start)", "line = Lex.line_start(bytes, Lex.line_start(bytes, entry.start).max(1) - 1)"),
    ("M66 remove many lines: end comment stays", H, "eol = if Lex.at(bytes, after_comma) == '#' Lex.line_end(bytes, after_comma) else after_comma", "eol = after_comma"),
    ("M67 remove one line: space after comma stays", H, "{ start: entry.start, end: after_comma }", "{ start: entry.start, end: comma + 1 }"),
    ("M68 remove only entry: spaces stay", H, "{ start: record.open + 1, end: record.close }", "{ start: entry.start, end: entry.end }"),
    ("M70 remove last entry of one line: comma before stays", H, "if Lex.at(bytes, before) == ',' and before > record.open {", "if Lex.at(bytes, before) == ',' and before > bytes.len() {"),
    # Imports.scan (R-UM1, D8)
    ("M71 package import is Local", I, "Ok({ from: Package(Str.from_utf8_lossy(alias)), name:", "Ok({ from: Local, name:"),
    ("M72 local nested type kept", I, "mod_name = before_dot(path.drop_first(prefix))", "mod_name = path.drop_first(prefix)"),
    ("M73 package nested type kept", I, "mod_name = before_dot(path.drop_first(alias.len() + 1))", "mod_name = path.drop_first(alias.len() + 1)"),
    ("M74 import in a comment counts", I, "text = drop_spaces(line)", "text = drop_spaces(line.drop_if(|b| b == '#'))"),
    ("M75 importer is an import", I, "if !text.starts_with(keyword) or !is_space(text.get(keyword.len()) ?? 0) {", "if !text.starts_with(keyword) {"),
    ("M76 line numbers from 0", I, "var $line = 1", "var $line = 0"),
    ("M77 local path prefix dropped", I, "name: Str.from_utf8_lossy(path.take_first(prefix + mod_name.len()))", "name: Str.from_utf8_lossy(mod_name)"),
]

only = sys.argv[2:]
tests = sorted(f for f in os.listdir(REPO + "/tests") if f.endswith(".roc"))
fuzz = sorted(f[:-4] for f in os.listdir(REPO + "/fuzz") if f.endswith(".roc"))
runs = os.environ.get("MRUNS", "20000")
os.makedirs(W + "/fuzz", exist_ok=True)


def same_tree():
    for root, _, files in os.walk(ORIG):
        for f in files:
            o = os.path.join(root, f)
            p = os.path.join(REPO, "package", os.path.relpath(o, ORIG))
            if not os.path.exists(p) or not filecmp.cmp(o, p, shallow=False):
                return False
    for root, _, files in os.walk(REPO + "/package"):
        for f in files:
            p = os.path.join(root, f)
            if not os.path.exists(os.path.join(ORIG, os.path.relpath(p, REPO + "/package"))):
                return False
    return True


def ids_for(test_file, lines):
    # The rule ids or settled answers named in the comment above each failing expect.
    src = open(os.path.join(REPO, "tests", test_file)).read().split("\n")
    out = []
    for ln in lines:
        k = ln - 1
        while k >= 0 and not src[k].startswith("#"):
            k -= 1
        if k >= 0:
            m = re.findall(r"R-[A-Z]+\d+|Settled Q\d+|Design \d+(?:\.\d+)?", src[k])
            out.extend(m[:1])
    return sorted(set(out))


for name, rel, old, new in M:
    mid = name.split()[0]
    if only and mid not in only:
        continue
    assert same_tree(), "package changed before " + name
    src, orig_f = os.path.join(REPO, "package", rel), os.path.join(ORIG, rel)
    orig = open(orig_f).read()
    if orig.count(old) != 1:
        print(f"{name} || {rel} || SKIP old text count {orig.count(old)}", flush=True)
        continue
    open(src, "w").write(orig.replace(old, new))
    lineno = orig[: orig.index(old)].count("\n") + 1
    res = []
    try:
        chk = subprocess.run([ROC, "check", "package/main.roc"], cwd=REPO, env=env, capture_output=True, text=True)
        if chk.returncode != 0:
            res.append("CHECK-ERROR " + (chk.stdout + chk.stderr)[:300].replace("\n", " "))
        for t in tests:
            p = subprocess.run([ROC, "test", "tests/" + t, "--no-cache"], cwd=REPO, env=env, capture_output=True, text=True)
            out = p.stdout + p.stderr
            if p.returncode != 0:
                m = re.search(r"(\d+) of (\d+) tests? failed|(\d+) failed", out)
                fl = sorted(set(int(x) for x in re.findall(r"tests/" + re.escape(t) + r":(\d+)", out)))
                res.append(f"{t}:{m.group(0) if m else 'fail'} lines={fl[:8]} ids={ids_for(t, fl)}")
        if os.environ.get("NOFUZZ") != "1":
            for f in fuzz:
                b = subprocess.run([ROC, "build", "--fuzz", f"fuzz/{f}.roc", f"--output={W}/fuzz/m-{f}"], cwd=REPO, env=env, capture_output=True, text=True)
                if b.returncode != 0:
                    res.append(f"{f}:build-fail")
                    continue
                shutil.rmtree(f"{W}/fuzz/mart-{f}", ignore_errors=True)
                os.makedirs(f"{W}/fuzz/mart-{f}", exist_ok=True)
                r = subprocess.run([f"{W}/fuzz/m-{f}", "run", f"--runs={runs}", "--seed=1", "--time=0", f"--artifact-dir={W}/fuzz/mart-{f}"], cwd=REPO, env=env, capture_output=True, text=True)
                if r.returncode != 0:
                    res.append(f"{f}:fuzz-fail(exit {r.returncode})")
    finally:
        shutil.copyfile(orig_f, src)
    assert same_tree()
    print(f"{name} || {rel}:{lineno} || {'; '.join(res) if res else 'NOT CAUGHT'}", flush=True)
