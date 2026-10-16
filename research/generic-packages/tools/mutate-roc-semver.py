#!/usr/bin/env python3
# Plant one mutation at a time in roc-semver package/, run the L0 test apps and
# the fuzz targets, restore the file, and print one result line per mutation.
# Usage: mutate-roc-semver.py ORIG_PACKAGE_DIR [M-ID ...]
import os, re, shutil, subprocess, sys, filecmp

HERE = os.path.dirname(os.path.abspath(__file__))
TALON = os.path.normpath(os.path.join(HERE, "../../.."))
# The package checkout is next to the Talon checkout.
REPO = os.environ.get("REPO", os.path.join(os.path.dirname(TALON), "roc-semver"))
ROC = os.environ.get("ROC", os.path.join(TALON, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ORIG = sys.argv[1]  # the copy of package/ from step 0
W = os.path.join(REPO, ".work")
env = dict(os.environ, XDG_CACHE_HOME=W + "/xdg", ROC_CACHE_DIR=W + "/xdg/roc")

S, L, P, C, V = "Semver.roc", "Internal/Lex.roc", "Internal/Precedence.roc", "Internal/Comparator.roc", "VersionReq.roc"

M = [
    # Precedence (semver 11)
    ("M1 major order reversed", P, "a1.order_relative_to(b1)", "b1.order_relative_to(a1)"),
    ("M2 minor order reversed", P, "a2.order_relative_to(b2)", "b2.order_relative_to(a2)"),
    ("M3 patch order reversed", P, "a3.order_relative_to(b3)", "b3.order_relative_to(a3)"),
    ("M4 numeric identifier after alphanumeric", P, "(True, False) => Before", "(True, False) => After"),
    ("M5 numeric identifiers compare as text", P, "then_order(xb.len().order_relative_to(yb.len()), |_| order_bytes(xb, yb))", "order_bytes(xb, yb)"),
    ("M6 pre-release after its release", P, "} else if a.is_empty() {\n\t\t\tAfter", "} else if a.is_empty() {\n\t\t\tBefore"),
    ("M7 build metadata used in order", S, "Same => Precedence.order_pre_release(a.pre_release, b.pre_release)",
     "Same => if a.build == b.build Precedence.order_pre_release(a.pre_release, b.pre_release) else a.build.len().order_relative_to(b.build.len())"),
    ("M8 more identifiers is before (11.4.4)", P, "([], []) => Same\n\t\t([], _) => Before\n\t\t(_, []) => After\n\t\t([x, .. as xs], [y, .. as ys]) => then_order",
     "([], []) => Same\n\t\t([], _) => After\n\t\t(_, []) => Before\n\t\t([x, .. as xs], [y, .. as ys]) => then_order"),
    ("M9 alphanumeric compare reversed", P, "(False, False) => order_bytes(xb, yb)", "(False, False) => order_bytes(yb, xb)"),
    # Lex: numbers and identifiers (semver 2, 9, 10)
    ("M10 leading zero accepted in M.m.p", L, "} else if has_leading_zero(digits) {", "} else if has_leading_zero(digits) and Bool.False {"),
    ("M11 leading zero accepted in numeric pre-release", L, "|chars| !has_leading_zero(chars) or", "|chars| Bool.True or"),
    ("M12 U64 overflow wraps (times)", L, "ten_times = $n.times_try(10) ? |_| InvalidNumber", "ten_times = $n.times_wrap(10)"),
    ("M13 U64 overflow wraps (plus)", L, "$n = ten_times.plus_try((d - '0').to_u64()) ? |_| InvalidNumber", "$n = ten_times.plus_wrap((d - '0').to_u64())"),
    ("M14 upper case letters not valid in identifiers", L, " or (b >= 'A' and b <= 'Z')", ""),
    ("M15 empty first identifier is EmptySegment always", L, "EmptySegment if !bytes.is_empty() => InvalidIdentifier", "EmptySegment if !bytes.is_empty() and Bool.False => InvalidIdentifier"),
    ("M16 build rejects leading zero", L, "build = |bytes| identifiers(bytes, |_| True)", "build = |bytes| identifiers(bytes, |chars| !has_leading_zero(chars) or !chars.all(Lex.is_digit))"),
    # Semver public functions
    ("M17 new swaps minor and patch", S, "new = |major, minor, patch| { major, minor, patch,", "new = |major, minor, patch| { major, minor: patch, patch: minor,"),
    ("M18 parse ignores suffix", S, "if rest.is_empty() Ok(version) else Err(UnexpectedSuffix(rest))", "if rest.is_empty() or Bool.True Ok(version) else Err(UnexpectedSuffix(rest))"),
    ("M19 parse_lazy drops the rest", S, "Lex.as_str(b7)))", "Lex.as_str(b7.take_first(0))))"),
    ("M20 empty text error tag", S, "Err(EmptySemver)", "Err(NoPeriodAfterMajorVersion)"),
    ("M21 minor error tag is patch tag", S, "Lex.number(b2) ? InvalidMinorVersion", "Lex.number(b2) ? InvalidPatchVersion"),
    ("M22 to_str: build before pre-release", S, "${pre}${build}\"", "${build}${pre}\""),
    ("M23 to_str: pre-release joined with -", S, "Str.join_with(v.pre_release, \".\")", "Str.join_with(v.pre_release, \"-\")"),
    ("M24 major accessor gives minor", S, "major = |v| v.major", "major = |v| v.minor"),
    ("M25 minor accessor gives patch", S, "minor = |v| v.minor", "minor = |v| v.patch"),
    ("M26 patch accessor gives major", S, "patch = |v| v.patch", "patch = |v| v.major"),
    ("M27 pre_release accessor gives build", S, "pre_release = |v| v.pre_release", "pre_release = |v| v.build"),
    ("M28 build accessor gives pre_release", S, "build = |v| v.build", "build = |v| v.pre_release"),
    # Caret (R-I7, Q1, Q2)
    ("M29 ^1.2.3 upper is <1.3.0", C, "if ma > 0 {\n\t\t\t\tafter_major(ma)", "if ma > 0 {\n\t\t\t\tafter_minor(ma, mi)"),
    ("M30 ^0.2.3 upper is <1.0.0", C, "} else if mi > 0 {\n\t\t\t\tafter_minor(0, mi)", "} else if mi > 0 {\n\t\t\t\tafter_major(0)"),
    ("M31 ^0.0.3 upper is <0.1.0", C, "after_patch(0, 0, pa)", "after_minor(0, pa * 0)"),
    ("M32 ^0 upper is <0.1.0", C, "\t\tMajor(ma) => after_major(ma)\n\t\tMinor(ma, mi) => if ma > 0", "\t\tMajor(ma) => if ma > 0 after_major(ma) else after_minor(0, 0)\n\t\tMinor(ma, mi) => if ma > 0"),
    ("M33 ^0.0 upper is <1.0.0", C, "Minor(ma, mi) => if ma > 0 after_major(ma) else after_minor(0, mi)", "Minor(ma, mi) => if ma > 0 after_major(ma) else if mi > 0 after_minor(0, mi) else after_major(0)"),
    ("M34 ^1.2 upper is <1.3.0", C, "Minor(ma, mi) => if ma > 0 after_major(ma) else", "Minor(ma, mi) => if ma > 0 after_minor(ma, mi) else"),
    ("M35 caret upper past U64 max not End", C, "after_major = |ma| if ma == U64.highest End else", "after_major = |ma| if ma == U64.highest At(ma, 0, 0) else"),
    # Bare forms (R-SL15)
    ("M36 bare 1.2 is exact (1.2.x)", C, "_ => if wild Eq else Caret", "_ => if wild or Bool.True Eq else Caret"),
    ("M37 bare 3 parts is caret", C, "Patch(_, _, _, _) => Eq\n", "Patch(_, _, _, _) => Caret\n"),
    ("M38 bare wildcard is caret", C, "_ => if wild Eq else Caret", "_ => if wild Caret else Caret"),
    # Wildcards (Q3, Q5)
    ("M39 X not a wildcard", C, "b == '*' or b == 'x' or b == 'X'", "b == '*' or b == 'x'"),
    ("M40 * not a wildcard", C, "b == '*' or b == 'x' or b == 'X'", "b == 'x' or b == 'X'"),
    ("M41 2.x.x: no skip of .x", C, "Ok((Major(major), True, skip_wildcards(b2, 1)))", "Ok((Major(major), True, b2))"),
    ("M42 x.x.x: skip only one .x", C, "Ok((Any, True, skip_wildcards(rest, 2)))", "Ok((Any, True, skip_wildcards(rest, 1)))"),
    # Operators (Q4, Q7, Q14)
    ("M43 = with fewer parts uses caret upper", C, "Eq => (floor(parts), next(parts))", "Eq => (floor(parts), caret_upper(parts))"),
    ("M44 > is >=", C, "Gt => (next(parts), End)", "Gt => (floor(parts), End)"),
    ("M45 >= is >", C, "Ge => (floor(parts), End)", "Ge => (next(parts), End)"),
    ("M46 < is <=", C, "Lt => (At(0, 0, 0), floor(parts))", "Lt => (At(0, 0, 0), next(parts))"),
    ("M47 <= is <", C, "Le => (At(0, 0, 0), next(parts))", "Le => (At(0, 0, 0), floor(parts))"),
    ("M48 ~1.2.3 upper is <2.0.0", C, "Patch(ma, mi, _, _) => after_minor(ma, mi)", "Patch(ma, _, _, _) => after_major(ma)"),
    ("M49 ~1 upper is <1.1.0", C, "\t\tMajor(ma) => after_major(ma)\n\t\tMinor(ma, mi) => after_minor(ma, mi)\n\t\tPatch(ma, mi, _, _)", "\t\tMajor(ma) => after_minor(ma, 0)\n\t\tMinor(ma, mi) => after_minor(ma, mi)\n\t\tPatch(ma, mi, _, _)"),
    ("M50 operator order: > before >=", C, "\t\t['>', '=', ..] => (Given(Ge), 2)\n\t\t['<', '=', ..] => (Given(Le), 2)\n\t\t['>', ..] => (Given(Gt), 1)\n",
     "\t\t['>', ..] => (Given(Gt), 1)\n\t\t['>', '=', ..] => (Given(Ge), 2)\n\t\t['<', '=', ..] => (Given(Le), 2)\n"),
    ("M51 > on partial: next of minor is next major", C, "\t\tMinor(ma, mi) => after_minor(ma, mi)\n\t\tPatch(ma, mi, pa, has_pre)", "\t\tMinor(ma, _) => after_major(ma)\n\t\tPatch(ma, mi, pa, has_pre)"),
    ("M52 >* matches all (Any next is lowest)", C, "\t\tAny => End\n\t\tMajor(ma) => after_major(ma)\n\t\tMinor(ma, mi) => after_minor(ma, mi)\n\t\tPatch(ma, mi, pa, has_pre)", "\t\tAny => At(0, 0, 0)\n\t\tMajor(ma) => after_major(ma)\n\t\tMinor(ma, mi) => after_minor(ma, mi)\n\t\tPatch(ma, mi, pa, has_pre)"),
    ("M53 no space after operator", C, "version = Lex.drop_spaces(start.drop_first(op_len))", "version = start.drop_first(op_len)"),
    ("M54 no space at start", C, "start = Lex.drop_spaces(bytes)", "start = bytes"),
    # Pre-release (Q6, Q12, semver 11.3)
    ("M55 pre-release versions can match", V, "version.pre_release().is_empty() and ", ""),
    ("M56 pre-release bound not below release", C, "if has_pre At(ma, mi, pa) else after_patch(ma, mi, pa)", "if has_pre and Bool.False At(ma, mi, pa) else after_patch(ma, mi, pa)"),
    # Build metadata (Q8, P1)
    ("M57 BuildMetadataNotAllowed check removed", C, "if rest.first() == Ok('+') {", "if rest.first() == Ok('+') and Bool.False {"),
    # Lists (Q7) and the limit of 32
    ("M58 comma list is OR", V, "req.comparators.all(|c| c.accepts(release))", "req.comparators.any(|c| c.accepts(release))"),
    ("M59 limit 33", V, "max_comparators = 32", "max_comparators = 33"),
    ("M60 limit check > (33 allowed)", V, "if found.len() >= max_comparators {", "if found.len() > max_comparators {"),
    ("M61 comparator error index + 1", V, "InvalidComparator({ index: found.len(), error })", "InvalidComparator({ index: found.len() + 1, error })"),
    # VersionReq public functions
    ("M62 star matches nothing above 1.0.0", C, "any = { text: \"*\", lower: At(0, 0, 0), upper: End }", "any = { text: \"*\", lower: At(0, 0, 0), upper: At(1, 0, 0) }"),
    ("M63 VersionReq.parse ignores suffix", V, "if rest.is_empty() Ok(req) else Err(UnexpectedSuffix(rest))", "if rest.is_empty() or Bool.True Ok(req) else Err(UnexpectedSuffix(rest))"),
    ("M64 VersionReq.parse_lazy drops the rest", V, "Lex.as_str(after)))", "Lex.as_str(after.take_first(0))))"),
    ("M65 VersionReq.to_str joins with ,", V, "Comparator.to_str), \", \")", "Comparator.to_str), \",\")"),
    ("M66 Comparator text drops the operator", C, "start.take_first(op_len).concat(", "start.take_first(0).concat("),
    ("M67 matches ignores lower bound", C, "accepts = |c, v| at_or_after(v, c.lower) and before(v, c.upper)", "accepts = |c, v| before(v, c.upper)"),
]

only = sys.argv[2:]
tests = sorted(f for f in os.listdir(REPO + "/tests") if f.endswith(".roc"))
fuzz = sorted(f[:-4] for f in os.listdir(REPO + "/fuzz") if f.endswith(".roc"))
runs = os.environ.get("MRUNS", "20000")


def same_tree():
    d = filecmp.dircmp(REPO + "/package", ORIG)
    def ok(d):
        if d.left_only or d.right_only or d.diff_files or d.funny_files:
            return False
        return all(ok(s) for s in d.subdirs.values())
    # dircmp compares shallow; also compare each file content
    for root, _, files in os.walk(ORIG):
        for f in files:
            o = os.path.join(root, f)
            p = os.path.join(REPO, "package", os.path.relpath(o, ORIG))
            if not os.path.exists(p) or not filecmp.cmp(o, p, shallow=False):
                return False
    return ok(d)


for name, rel, old, new in M:
    mid = name.split()[0]
    if only and mid not in only:
        continue
    assert same_tree(), "package changed before " + name
    src, orig_f = os.path.join(REPO, "package", rel), os.path.join(ORIG, rel)
    orig = open(orig_f).read()
    assert orig.count(old) == 1, name + ": old text count " + str(orig.count(old))
    open(src, "w").write(orig.replace(old, new))
    lineno = orig[: orig.index(old)].count("\n") + 1
    res = []
    try:
        chk = subprocess.run([ROC, "check", "package/main.roc"], cwd=REPO, env=env, capture_output=True, text=True)
        if chk.returncode != 0:
            co = chk.stdout + chk.stderr
            res.append("CHECK-WARNING" if re.search(r"\b0 errors and \d+ warning", co) else "CHECK-ERROR")
        for t in tests:
            p = subprocess.run([ROC, "test", "tests/" + t, "--no-cache"], cwd=REPO, env=env, capture_output=True, text=True)
            out = p.stdout + p.stderr
            if p.returncode != 0 and not re.search(r"All \(\d+\) tests passed", out):
                m = re.search(r"(\d+) of (\d+) tests? failed|(\d+) failed", out)
                ids = sorted(set(re.findall(r"T-(?:SV|VR)\d+", out)), key=lambda s: (s[:4], int(s[4:])))
                fl = sorted(set(int(x) for x in re.findall(r"tests/" + re.escape(t) + r":(\d+)", out)))
                res.append(f"{t}:{m.group(0) if m else 'fail'} lines={fl}" + (f" ids={ids}" if ids else ""))
        if os.environ.get("NOFUZZ") != "1":
            for f in fuzz:
                if os.path.exists(f"{W}/fuzz/m-{f}"):
                    os.remove(f"{W}/fuzz/m-{f}")
                b = subprocess.run([ROC, "build", "--fuzz", f"fuzz/{f}.roc", f"--output={W}/fuzz/m-{f}"], cwd=REPO, env=env, capture_output=True, text=True)
                if not os.path.exists(f"{W}/fuzz/m-{f}"):
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
    caught = [x for x in res if x not in ("CHECK-WARNING",)]
    print(f"{name} || {rel}:{lineno} || {'; '.join(res)}{'' if caught else (' ' if res else '') + 'NOT CAUGHT'}", flush=True)
