import lib.Fail
import lib.Proxy

ProxyTest :: [].{}

a1 = "nightly-2026-10-09-258ab27"

a2 = "nightly-2026-10-14-38a3029"

a3 = "nightly-2026-10-14-0abcdef"

jul = "nightly-2026-July-23-abc1234"

num = "nightly-2026-07-23-abc1234"

# R-ST8 R-PX1 R-HF9: `tln` runs as the proxy when its program name is `roc`. The base name (after the last `/` or `\`) without a `.exe` at the end decides. A directory that is named `roc`, a name that only starts with `roc`, and
# `tln` are not the proxy.
expect {
	rows = [
		("roc", Bool.True),
		("./roc", Bool.True),
		("/usr/local/bin/roc", Bool.True),
		("/home/u/.local/share/talon/bin/roc", Bool.True),
		("roc.exe", Bool.True),
		("C:\\talon\\bin\\roc.exe", Bool.True),
		("C:\\talon\\bin\\roc", Bool.True),
		("tln", Bool.False),
		("tln.exe", Bool.False),
		("/usr/bin/tln", Bool.False),
		("rocky", Bool.False),
		("Roc", Bool.False),
		("roc.exe.bak", Bool.False),
		("roc/tln", Bool.False),
		("roc.exe/tln", Bool.False),
		("", Bool.False),
	]
	bad = rows.keep_if(|(name, want)| Proxy.is_proxy(name) != want).map(|(name, want)| (name, want))
	dbg bad
	bad == []
}

# R-SO1 R-PX3 R-PD17: `roc +<id> <arguments>`. Only the first argument can be `+<id>`. The other arguments go to roc as they are, in the same order, also an option and a `+` that is not first. The proxy has no flag of its own.
expect {
	rows = [
		("no argument", [], Err(Unset), []),
		("a command", ["check", "main.roc"], Err(Unset), ["check", "main.roc"]),
		("an id and a command", ["+${a2}", "check", "app.roc"], Ok(a2), ["check", "app.roc"]),
		("an id alone", ["+${a2}"], Ok(a2), []),
		("the id is not checked here", ["+x", "version"], Ok("x"), ["version"]),
		("a + alone is an argument", ["+"], Err(Unset), ["+"]),
		("a + that is not first", ["check", "+${a2}"], Err(Unset), ["check", "+${a2}"]),
		("an option first", ["--opt=speed", "+${a2}"], Err(Unset), ["--opt=speed", "+${a2}"]),
		("Talon-like flags go to roc (R-PD17)", ["--file", "x/main.roc", "--yes"], Err(Unset), ["--file", "x/main.roc", "--yes"]),
		("a second + goes to roc", ["+${a2}", "+${a1}", "check"], Ok(a2), ["+${a1}", "check"]),
	]
	bad = rows.keep_if(|(_, args, argument, rest)| Proxy.split(args) != { argument, rest }).map(|(label, args, argument, rest)| (label, { argument, rest }, Proxy.split(args)))
	dbg bad
	bad == []
}

# R-SO8 R-PD7: the target file. The first argument that names a `.roc` file, in the arguments that are left after `+<id>`. With no such argument, a command that compiles a file reads `main.roc` of the current
# directory (`Main`, as roc does). A command with no file (`version`, `help`, `install`, `run` with a bundle URL or an installed name) has no target (`NoFile`), so rank 3 does not apply.
expect {
	rows = [
		("a file", ["app.roc"], File("app.roc")),
		("check a file", ["check", "app.roc"], File("app.roc")),
		("options before the file", ["--opt=speed", "--no-cache", "app.roc"], File("app.roc")),
		("a path", ["build", "./sub/app.roc", "--output=out"], File("./sub/app.roc")),
		("an absolute path", ["test", "/abs/dir/t.roc"], File("/abs/dir/t.roc")),
		("run a file", ["run", "./a/b.roc"], File("./a/b.roc")),
		("the first file wins, the arguments of the app follow", ["app.roc", "--", "other.roc"], File("app.roc")),
		("no argument: main.roc", [], Main),
		("check", ["check"], Main),
		("build with an option", ["build", "--opt=speed"], Main),
		("test", ["test"], Main),
		("docs", ["docs"], Main),
		("deps", ["deps"], Main),
		("run with no source", ["run"], Main),
		("run with an option only", ["run", "--opt=speed"], Main),
		("version", ["version"], NoFile),
		("version with an option", ["version", "--verbose"], NoFile),
		("help", ["help"], NoFile),
		("install", ["install", "tokei", "https://example.com/tokei/1.0.0/abc.tar.zst"], NoFile),
		("run a bundle URL", ["run", "https://example.com/tool/1.2.3/abc.tar.zst"], NoFile),
		("run an installed name", ["run", "tokei"], NoFile),
		("a URL with .roc inside is no file", ["run", "https://example.com/pkg.roc/1.0.0/abc.tar.zst"], NoFile),
		("an option with .roc inside is no file", ["check", "--cache=a.roc.d"], Main),
		("a URL that ends in .roc is no file", ["run", "https://example.com/x/app.roc"], NoFile),
		("an option that ends in .roc is no file", ["check", "--main=app.roc"], Main),
	]
	bad = rows.keep_if(|(_, args, want)| Proxy.target(args) != want).map(|(label, args, want)| (label, want, Proxy.target(args)))
	dbg bad
	bad == []
}

# R-EV7 R-PX7 R-EV17 R-SO9: `TALON_PROXY=0` opts out, `TALON_IN_PROXY=1` marks a child of a proxy. Only that value counts. Other values and no variable are false.
expect {
	opt = |env| Proxy.opted_out(env)
	inside = |env| Proxy.in_proxy(env)
	rows = [
		("opt: 0", opt([("TALON_PROXY", "0")]), Bool.True),
		("opt: 0 between other variables", opt([("HOME", "/h"), ("TALON_PROXY", "0"), ("PATH", "/bin")]), Bool.True),
		("opt: 1", opt([("TALON_PROXY", "1")]), Bool.False),
		("opt: empty", opt([("TALON_PROXY", "")]), Bool.False),
		("opt: not set", opt([("HOME", "/h")]), Bool.False),
		("opt: the other variable", opt([("TALON_IN_PROXY", "0")]), Bool.False),
		("in: 1", inside([("TALON_IN_PROXY", "1")]), Bool.True),
		("in: 1 between other variables", inside([("HOME", "/h"), ("TALON_IN_PROXY", "1")]), Bool.True),
		("in: 0", inside([("TALON_IN_PROXY", "0")]), Bool.False),
		("in: empty", inside([("TALON_IN_PROXY", "")]), Bool.False),
		("in: not set", inside([]), Bool.False),
		("in: the other variable", inside([("TALON_PROXY", "1")]), Bool.False),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-SO1 R-SO2 R-SO3 R-SO4 R-SO5 R-SO6 R-SO7 R-SO10 R-SO12 R-SO13 R-SO14 R-CV1 R-PX2 R-EV17 R-NS3 (slice 023): the ranks of the proxy. Rank 1 `roc +<id>`, rank 2 `ROC_TOOLCHAIN`, rank 3 the `roc:` pin of the header, then the ranks 4 to 7 of
# `Compiler.select`. A pin has no range check and no `nightly` switch (R-SO19: the proxy has no gate). A pin that is not installed is `Missing` and never falls through to a lower rank. The other tag form of one nightly is the
# same compiler (R-CV1): the installed id is the result. The id of the `roc` on `PATH` is installed (R-SO10).
expect {
	base = { argument: Err(Unset), env: Err(Unset), req: Err(Unset), nightly: Bool.True, has_toml: Bool.False, version_file: Err(None), default: Err(Unset), path: Err(NoCompiler), installed: [], times: [] }
	pick = |pin, facts| Proxy.select({ pin, facts })
	shown = |r| match r {
		Ok(sel) => Ok((sel.id, sel.rank, sel.state))
		Err(e) => Err(e)
	}
	all = Ok(Any)
	rows = [
		("no rank has a value (R-SO14)", pick(Err(NoPin), base), Err(NoCompiler)),
		("the pin, installed", pick(Ok(a2), { ..base, installed: [a1, a2] }), Ok((a2, Pin, Installed))),
		("the pin beats rank 4 (R-SO3)", pick(Ok(a1), { ..base, req: all, installed: [a1, a2] }), Ok((a1, Pin, Installed))),
		("the pin is outside the range: no range check (R-SO19)", pick(Ok(a1), { ..base, req: Ok(Exactly(a2)), installed: [a1, a2] }), Ok((a1, Pin, Installed))),
		("the pin is a nightly and the switch is off: no gate (R-SO19)", pick(Ok(a1), { ..base, nightly: Bool.False, installed: [a1] }), Ok((a1, Pin, Installed))),
		("the pin beats ranks 5 to 7", pick(Ok(a1), { ..base, version_file: Ok(a2), default: Ok(a2), path: Ok(a2), installed: [a1, a2] }), Ok((a1, Pin, Installed))),
		("the pin is not installed: Missing, no fall through (R-SO12)", pick(Ok(a1), { ..base, req: all, default: Ok(a2), path: Ok(a2), installed: [a2] }), Ok((a1, Pin, Missing))),
		("the pin is the id of the roc on PATH (R-SO10)", pick(Ok(a2), { ..base, path: Ok(a2) }), Ok((a2, Pin, Installed))),
		("the pin in the July form, the number form installed (R-CV1)", pick(Ok(jul), { ..base, installed: [num] }), Ok((num, Pin, Installed))),
		("the pin in the number form, the July form installed (R-CV1)", pick(Ok(num), { ..base, installed: [jul] }), Ok((jul, Pin, Installed))),
		("the pin in the other form of the id on PATH (R-CV1, R-SO10)", pick(Ok(jul), { ..base, path: Ok(num) }), Ok((num, Pin, Installed))),
		("rank 2 beats the pin", pick(Ok(a1), { ..base, env: Ok(a3), installed: [a1, a3] }), Ok((a3, Env, Installed))),
		("rank 1 beats rank 2 and the pin", pick(Ok(a1), { ..base, argument: Ok(a2), env: Ok(a3), installed: [a1, a2, a3] }), Ok((a2, Argument, Installed))),
		("rank 1, not installed: Missing (R-SO12)", pick(Err(NoPin), { ..base, argument: Ok(a2), installed: [a1] }), Ok((a2, Argument, Missing))),
		("rank 2, not installed: Missing, the pin does not replace it", pick(Ok(a1), { ..base, env: Ok(a2), installed: [a1] }), Ok((a2, Env, Missing))),
		("no pin: rank 4, the newest installed in the range", pick(Err(NoPin), { ..base, req: all, installed: [a1, a2] }), Ok((a2, Range, Installed))),
		("no pin: rank 4 has none in the range (R-SO13)", pick(Err(NoPin), { ..base, req: Ok(Exactly(a3)), default: Ok(a1), installed: [a1] }), Err(NoneInRange)),
		("no pin: rank 5, no talon.toml (R-SO5)", pick(Err(NoPin), { ..base, version_file: Ok(a1), default: Ok(a2), installed: [a1, a2] }), Ok((a1, VersionFile, Installed))),
		("no pin: rank 6", pick(Err(NoPin), { ..base, default: Ok(a2), installed: [a2] }), Ok((a2, Default, Installed))),
		("no pin: rank 7, the roc on PATH (R-SO7)", pick(Err(NoPin), { ..base, path: Ok(a3) }), Ok((a3, Path, Installed))),
		("no pin: rank 7 is off when the caller gives no PATH id (R-EV17)", pick(Err(NoPin), { ..base, installed: [a1] }), Err(NoCompiler)),
	]
	bad = rows.keep_if(|(_, got, want)| shown(got) != want).map(|(label, got, want)| (label, want, shown(got)))
	dbg bad
	bad == []
}

# R-DL8 R-DL10 R-E1 (slice 023): the 2 failures. The program, the variables for the compiler and the text of `.last-use` are in `tests/unit/launch.roc` (slice 023c moved them to `Launch`). The texts are a proposal (TW24).
expect {
	fail_rows = [
		("missing, rank 1", Proxy.missing({ id: a2, rank: Argument }), Fail.new(Consent, "the compiler ${a2} (roc +${a2}) is not installed. Run: tln roc install ${a2}, or set TALON_AUTO_INSTALL=yes.")),
		("missing, rank 2", Proxy.missing({ id: a2, rank: Env }), Fail.new(Consent, "the compiler ${a2} (ROC_TOOLCHAIN) is not installed. Run: tln roc install ${a2}, or set TALON_AUTO_INSTALL=yes.")),
		("missing, the pin", Proxy.missing({ id: a2, rank: Pin }), Fail.new(Consent, "the compiler ${a2} (the roc: entry of the header) is not installed. Run: tln roc install ${a2}, or set TALON_AUTO_INSTALL=yes.")),
		("missing, rank 5", Proxy.missing({ id: "0.1.0", rank: VersionFile }), Fail.new(Consent, "the compiler 0.1.0 (.roc-version) is not installed. Run: tln roc install 0.1.0, or set TALON_AUTO_INSTALL=yes.")),
		("missing, rank 6", Proxy.missing({ id: a1, rank: Default }), Fail.new(Consent, "the compiler ${a1} (the global default) is not installed. Run: tln roc install ${a1}, or set TALON_AUTO_INSTALL=yes.")),
		("the child did not start", Proxy.start_failed({ program: "/h/roc", text: "NotFound" }), Fail.new(Environment, "cannot run /h/roc: NotFound")),
	]
	bad_fail = fail_rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want.message, got.message))
	dbg bad_fail
	bad_fail == []
}

# Slice 025: the rows of `TALON_AUTO_INSTALL` moved to `tests/unit/consent.roc` (`Consent.auto_install`: the commands read it too).

# R-PX4 R-DL3 R-DL4 R-DL8 R-DL9 R-DL10 R-NI5 R-CV1 (slice 023b): what the proxy does for a compiler that is not installed, before any request. The nightly tag of the pin, in both forms, is downloaded. `no` never. `yes` always (no prompt, no `tty!` call).
# `ask` (the default) prompts when a person is there, asks the terminal first when that is not known (`NeedsTty`), and refuses in non-interactive mode. A text that is not a nightly tag is never downloaded (question Q2), and never asks the terminal.
expect {
	want = |id, auto, mode| Proxy.want({ id, auto, mode })
	nightly_rows = [
		("ask, a person", want(a2, Ask, Interactive), Ask),
		("ask, not known yet", want(a2, Ask, NeedsTty), NeedTty),
		("ask, no person (R-DL8)", want(a2, Ask, NonInteractive), Refuse),
		("yes, a person (R-DL9)", want(a2, Yes, Interactive), Install),
		("yes, not known yet: no tty call", want(a2, Yes, NeedsTty), Install),
		("yes, no person", want(a2, Yes, NonInteractive), Install),
		("no, a person (R-DL10)", want(a2, No, Interactive), Refuse),
		("no, not known yet: no tty call", want(a2, No, NeedsTty), Refuse),
		("no, no person", want(a2, No, NonInteractive), Refuse),
		("the July form", want(jul, Yes, NonInteractive), Install),
		("the July form, ask", want(jul, Ask, Interactive), Ask),
	]
	other_rows = [
		("a prefix", want("nightly-2026-10", Yes, Interactive), Refuse),
		("a prefix, not known yet", want("nightly-2026-10", Ask, NeedsTty), Refuse),
		("a link build", want("link-dev", Yes, Interactive), Refuse),
		("a git build", want("git-0123abcd", Yes, NonInteractive), Refuse),
		("a copy build", want("copy-x", Ask, Interactive), Refuse),
		("a release version", want("0.1.0", Yes, Interactive), Refuse),
		("the empty text", want("", Yes, Interactive), Refuse),
	]
	bad_nightly = nightly_rows.keep_if(|(_, got, want_)| got != want_).map(|(label, got, want_)| (label, want_, got))
	bad_other = other_rows.keep_if(|(_, got, want_)| got != want_).map(|(label, got, want_)| (label, want_, got))
	dbg bad_nightly
	dbg bad_other
	bad_nightly == [] and bad_other == []
}
