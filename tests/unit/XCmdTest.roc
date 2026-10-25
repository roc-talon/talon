import lib.Answer
import lib.Args
import lib.Prompt
import lib.XCmd

XCmdTest :: [].{}

# Slice 049 (docs/slices/049-x.md): the line of `tln x` and the texts of build reuse. The expected value of each row is the design text (CLI 1: R-CM12, R-FL1; CLI 4: R-NI9; CLI 6.4: R-X1, R-B3, R-B7, R-B8; Resolution 2: R-C6) or the slice file text, not the code.
# Texts that the design does not give are the proposals of the slice file (TW24). The Fx calls and the files are in the L2 cases `x/x1-run` and `x/x2-offline`.

# R-CM12 R-FL1 R-X1 R-NM11: the line of `tln x`. The words after `--` are the arguments of the app, never flags (R-CM12). `--json` is refused by `Args.parse` (R-FL1, exit 2). The git source and a new resolution are not built yet (slice 059 and later). A selector is read as for `tool install`.
# The text of a failure is `usage` (exit 2). The row shows the app, `--roc`, `--allow-unchecked` and the arguments.
expect {
	cmd = |words| match Args.parse(words) {
		Ok(args) => match XCmd.read(args) {
			Ok(plan) => {
				sel = match plan.ref.selector {
					Ok(Exact(v)) => "=${v}"
					Ok(Range(r)) => r
					Ok(Latest) => "latest"
					Ok(_) => "other"
					Err(None) => "-"
				}
				roc = match plan.roc {
					Auto => "auto"
					Pinned => "pinned"
					Installed => "installed"
				}
				"${plan.ref.name} ${sel} roc=${roc} unchecked=${Str.inspect(plan.unchecked)} args=[${Str.join_with(plan.args, " ")}]"
			}
			Err(fail) => fail.line()
		}
		Err(stop) => "parse: ${stop.fail.line()}"
	}
	line = |text| "tln: error[usage]: ${text}"
	rows = [
		(cmd(["x", "acme/foo"]), "acme/foo - roc=auto unchecked=False args=[]"),
		(cmd(["x", "acme/foo", "--", "a", "--json", "-i"]), "acme/foo - roc=auto unchecked=False args=[a --json -i]"),
		(cmd(["x", "foo"]), "foo - roc=auto unchecked=False args=[]"),
		(cmd(["x", "acme/foo@1.3.0"]), "acme/foo =1.3.0 roc=auto unchecked=False args=[]"),
		(cmd(["x", "acme/foo@latest", "--roc", "pinned"]), "acme/foo latest roc=pinned unchecked=False args=[]"),
		(cmd(["x", "acme/foo@1", "--roc=installed", "--allow-unchecked", "--yes", "--offline", "--quiet"]), "acme/foo ^1 roc=installed unchecked=True args=[]"),
		(cmd(["x", "acme/foo", "--slots", "4", "--", "run"]), "acme/foo - roc=auto unchecked=False args=[run]"),
		(cmd(["x", "acme/foo", "--json"]), "parse: tln: error[usage]: flag '--json' is not for 'x'"),
		(cmd(["x", "acme/foo", "--as", "q"]), "parse: tln: error[usage]: flag '--as' is not for 'x'"),
		(cmd(["x"]), line("tln x needs one app: owner/app")),
		(cmd(["x", "a/b", "c/d"]), line("tln x takes one app, got 2")),
		(cmd(["x", "acme/foo", "--git"]), line("tln x --git is not built yet")),
		(cmd(["x", "acme/foo@main", "--git"]), line("tln x --git is not built yet")),
		(cmd(["x", "acme/foo", "--path", "apps/cli"]), line("tln x --path is not built yet")),
		(cmd(["x", "acme/foo", "--resolve"]), line("tln x --resolve is not built yet")),
		(cmd(["x", "acme/foo@dd03c09e"]), line("'dd03c09e' in 'acme/foo@dd03c09e' is a git ref: a git ref needs --git (not built yet)")),
		(cmd(["x", "acme/foo", "--roc", "newest"]), line("--roc must be pinned or installed, not 'newest'")),
		(cmd(["x", "acme/foo@nightly-2026-10-09-258ab27"]), line("selector 'nightly-2026-10-09-258ab27' in 'acme/foo@nightly-2026-10-09-258ab27' is for a compiler: use it with 'tln roc'")),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-B3 R-C6 R-B8: the texts of reuse. The note of R-C6 and the form of the note of R-B3 are the design text (`installed cached 1.2.0 (1.4.0 is available: tln tool install foo@latest)`). `x` names itself and the full name in the remedy (a proposal). R-B8: the note of an installed tool that runs with no network.
expect {
	av = |via| XCmd.available({ via, key: "foo", name: "acme/foo", have: "1.2.0", newest: "1.4.0" })
	rows = [
		(XCmd.no_data, "no yank and advisory data without a registry"),
		(av(TakeOver), "installed cached 1.2.0 (1.4.0 is available: tln tool install foo@latest)"),
		(av(RunCached), "using cached foo 1.2.0 (1.4.0 is available: tln x acme/foo@latest)"),
		(av(RunInstalled), "using installed foo 1.2.0 (1.4.0 is available: tln x acme/foo@latest)"),
		(XCmd.offline_installed({ key: "foo", version: "1.2.0" }), "foo 1.2.0 is installed. tln did not check it online for yanks and advisories."),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-B7 R-NI9 R-NM5 R-NM8 R-NR2 R-NR6: the prompt for a cached build that was not checked online. The question of `tool install` is the design text (`foo 1.2.0 is in the cache. It was not checked online for yanks and advisories. Install it?`). It is a Required prompt with the answer flag `--allow-unchecked`, yes/no, the interactive default is No.
# So with no person and no flag the run stops with exit 13 and names `--allow-unchecked` and `--yes`. `--yes` and the flag answer Yes (R-NM8: `--yes` is not the answer of Enter). The answer line is printed for an answer with no person (R-NM6). A No is a failure of kind consent (exit 13).
expect {
	p = XCmd.unchecked_prompt({ via: TakeOver, key: "foo", version: "1.2.0" })
	r = XCmd.unchecked_prompt({ via: Run, key: "foo", version: "1.2.0" })
	decide = |prompt, mode, yes, flag| match Prompt.decide(prompt, { mode, yes, flag }) {
		Ask => "ask"
		NeedTty => "need-tty"
		Use(a) => "use ${Str.inspect(a)}"
		Stop(f) => "stop ${Str.inspect(f.kind)} ${f.message}"
	}
	rows = [
		(p.id, "use-unchecked"),
		(Prompt.text(p), "foo 1.2.0 is in the cache. It was not checked online for yanks and advisories. Install it? [y/N] "),
		(Prompt.text(r), "foo 1.2.0 is in the cache. It was not checked online for yanks and advisories. Run it? [y/N] "),
		(decide(p, NonInteractive, Bool.False, Err(NoFlag)), "stop Consent using the cached foo 1.2.0, which was not checked online needs consent. Pass --allow-unchecked or --yes."),
		(decide(p, NonInteractive, Bool.True, Err(NoFlag)), "use Yes"),
		(decide(p, NonInteractive, Bool.False, Ok(Yes)), "use Yes"),
		(decide(p, Interactive, Bool.False, Err(NoFlag)), "ask"),
		(decide(p, NeedsTty, Bool.False, Err(NoFlag)), "need-tty"),
		(Prompt.reply(p, "") |> Str.inspect, "Ok(No)"),
		(Prompt.reply(p, "y") |> Str.inspect, "Ok(Yes)"),
		((p.answer_line)(Yes), "using cached foo 1.2.0, not checked online"),
		((p.answer_line)(No), "not using cached foo 1.2.0"),
		(XCmd.declined({ via: TakeOver, key: "foo", version: "1.2.0" }).line(), "tln: error[consent]: foo 1.2.0 is in the cache, but it was not checked online and you did not accept it. Nothing was installed."),
		(XCmd.declined({ via: Run, key: "foo", version: "1.2.0" }).line(), "tln: error[consent]: foo 1.2.0 is in the cache, but it was not checked online and you did not accept it. Nothing was run."),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-B7 R-E1 R-HF6: the failure with no matching build and no way to resolve is kind network (exit 15). A missing app is kind environment (exit 18).
expect {
	rows = [
		(XCmd.offline_no_build("acme/foo").line(), "tln: error[network]: no installed or cached build of acme/foo matches, and --offline is set. Run the command without --offline."),
		(XCmd.start_failed({ program: "/c/x/d1/foo", text: "permission denied" }).line(), "tln: error[environment]: cannot run /c/x/d1/foo: permission denied"),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}
