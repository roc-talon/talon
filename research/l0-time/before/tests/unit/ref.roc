app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Fail
import lib.Ref
import lib.Scope
import lib.Selector

main! = |_args| Ok({})

# The failure is one text (the stderr line): a record with a Bool as the error value made the pinned compiler
# crash in `roc test` (slice 001, "Compiler limits found").
view = |text, scope, git| match Ref.parse(text, scope, git) {
	Ok(r) => Ok((r.form, r.name, r.selector))
	Err(f) => Err(Fail.line(f))
}

# R-SL1 R-SC6 R-SC7 R-ID3 R-SL4 R-SL5: name forms and the selector, in a package scope.
# Bare: an alias or a short name. Full: owner/repo. HostPath: host/path (2 or more `/`, a `.` in the first part).
expect {
	rows = [
		("json", Ok((Bare, "json", Err(None)))),
		("parser@2.0.0", Ok((Bare, "parser", Ok(Selector.Exact("2.0.0"))))),
		("roc-lang/basic-cli", Ok((Full, "roc-lang/basic-cli", Err(None)))),
		("roc-lang/http@^2", Ok((Full, "roc-lang/http", Ok(Selector.Range("^2"))))),
		("roc-lang/http@2", Ok((Full, "roc-lang/http", Ok(Selector.Range("^2"))))),
		("roc-lang/basic-cli@0.25", Ok((Full, "roc-lang/basic-cli", Ok(Selector.Range("^0.25"))))),
		("owner/app@latest", Ok((Full, "owner/app", Ok(Selector.Latest)))),
		("example.com/pkgs/json", Ok((HostPath, "example.com/pkgs/json", Err(None)))),
		("example.com/pkgs/json@1.2.0", Ok((HostPath, "example.com/pkgs/json", Ok(Selector.Exact("1.2.0"))))),
	]
	bad = rows.keep_if(|(text, want)| view(text, Scope.Install, Bool.False) != want).map(|(text, want)| (text, want, view(text, Scope.Install, Bool.False)))
	dbg bad
	bad == []
}

# R-SL2 R-SL6 R-SL7 R-SC9 R-SL8 R-SL11: the scope `Roc`. `@sel` is `roc-lang/roc@sel`, and a full nightly tag with no `@`
# is the same ref. A text that is not a full tag (a prefix, `git-dd03`) stays a name for the prefix rules (R-SC9, P1).
# With `--git` a branch is a git ref.
expect {
	roc = |sel| Ok((Full, "roc-lang/roc", Ok(sel)))
	rows = [
		("@nightly-2026-10-09-258ab27", roc(Selector.Nightly("nightly-2026-10-09-258ab27"))),
		("nightly-2026-10-09-258ab27", roc(Selector.Nightly("nightly-2026-10-09-258ab27"))),
		("roc-lang/roc@nightly-2026-10-09-258ab27", roc(Selector.Nightly("nightly-2026-10-09-258ab27"))),
		("@-1", roc(Selector.Step(-1))),
		("@+2", roc(Selector.Step(2))),
		("@0.1.0", roc(Selector.Exact("0.1.0"))),
		("@latest", roc(Selector.Latest)),
		("git-dd03", Ok((Bare, "git-dd03", Err(None)))),
		("nightly-2026-10-09", Ok((Bare, "nightly-2026-10-09", Err(None)))),
	]
	bad = rows.keep_if(|(text, want)| view(text, Scope.Roc, Bool.False) != want).map(|(text, want)| (text, want, view(text, Scope.Roc, Bool.False)))
	dbg bad
	git = view("owner/app@main", Scope.Tool, Bool.True) == Ok((Full, "owner/app", Ok(Selector.GitRef("main"))))
	dbg git
	bad == [] and git
}

# R-SL1 R-SL2 R-SL6 R-SL7 R-SL12 R-SL13 R-EC2: bad refs are usage failures. The messages are a proposal (slice 004, "Output").
# `@sel` with no name, a compiler selector outside `tln roc`, a typo (no `--git`), an empty selector, a bad name.
expect {
	usage = |msg| Err("tln: error[usage]: ${msg}")
	rows = [
		("owner/app@mian", Scope.Install, usage("bad selector 'mian' in 'owner/app@mian': use --git for a branch or tag")),
		("owner/app@mian", Scope.Project, usage("bad selector 'mian' in 'owner/app@mian': use --git for a branch or tag")),
		("@1.2.0", Scope.Install, usage("'@1.2.0' has no name: a reference with only @selector is for 'tln roc'")),
		("@1.2.0", Scope.Project, usage("'@1.2.0' has no name: a reference with only @selector is for 'tln roc'")),
		("owner/app@nightly-2026-10-09-258ab27", Scope.Install, usage("selector 'nightly-2026-10-09-258ab27' in 'owner/app@nightly-2026-10-09-258ab27' is for a compiler: use it with 'tln roc'")),
		("json@-1", Scope.Project, usage("selector '-1' in 'json@-1' is for a compiler: use it with 'tln roc'")),
		("owner/app@+2", Scope.Tool, usage("selector '+2' in 'owner/app@+2' is for a compiler: use it with 'tln roc'")),
		("owner/app@", Scope.Install, usage("'owner/app@' has an empty selector after '@'")),
		("a/b/c", Scope.Install, usage("'a/b/c' is not a package name: use a short name, owner/repo or host/path")),
		("/x", Scope.Install, usage("'/x' is not a package name: use a short name, owner/repo or host/path")),
		("a/", Scope.Install, usage("'a/' is not a package name: use a short name, owner/repo or host/path")),
	]
	bad = rows.keep_if(|(text, scope, want)| view(text, scope, Bool.False) != want).map(|(text, scope, want)| (text, want, view(text, scope, Bool.False)))
	dbg bad
	bad == []
}

# R-SC1 R-SC2 R-SC3 R-SC4 R-SC5: the scope of each command (the long form of the words).
# A command with no names has no scope.
expect {
	rows = [
		(["install"], Ok(Scope.Install)),
		(["update"], Ok(Scope.Project)),
		(["upgrade"], Ok(Scope.Project)),
		(["remove"], Ok(Scope.Project)),
		(["why"], Ok(Scope.Project)),
		(["patch"], Ok(Scope.Project)),
		(["probe"], Ok(Scope.Project)),
		(["tool", "install"], Ok(Scope.Tool)),
		(["tool", "remove"], Ok(Scope.Tool)),
		(["x"], Ok(Scope.X)),
		(["roc", "use"], Ok(Scope.Roc)),
		(["roc", "install"], Ok(Scope.Roc)),
		(["list"], Err(NoScope)),
		(["verify"], Err(NoScope)),
		(["outdated"], Err(NoScope)),
		(["cache", "gc"], Err(NoScope)),
		(["setup"], Err(NoScope)),
	]
	bad = rows.keep_if(|(words, want)| Scope.of_command(words) != want).map(|(words, want)| (words, want, Scope.of_command(words)))
	dbg bad
	bad == []
}
