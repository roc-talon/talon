import lib.Db
import lib.Mode
import lib.NoRank
import lib.Prompt

NoRankTest :: [].{}

# The expected value of each row is the design text or the slice file text, not the code (docs/slices/072b-no-rank-download.md). A wrong row prints with `dbg`.
# Texts that the design does not give are the proposals of the slice file (TW24).

n1 = "nightly-2026-10-14-38a3029"

n2 = "nightly-2026-10-16-1df370f"

n3 = "nightly-2026-10-18-5349569"

auto = [n1, n2, n3]

# One row of `compat.db`. A check row has the target `any`.
fact : Str, Str, Str, Db.Outcome -> Db.Fact
fact = |hash, nightly, target, outcome| { hash, nightly, target, outcome, modules: [], closure: "" }

check_pass = |hash, nightly| fact(hash, nightly, "any", Pass)

# R-SO14, R-EF1, R-RU1: the compiler to download. Outside a project it is the latest in the channel (the last id of `auto`). In a project it is the newest compiler of the channel that has a recorded `pass` (a check row, target `any`) for
# each hash of the header entries that has a fact. A hash is known when a check row of that hash exists, with any outcome and any compiler. A hash with no check row (no fact, or only a build row) is ignored. If no compiler suits, or no hash is known,
# the answer is the latest. The newest by the order of `auto`.
expect {
	# a passes on n2 and fails on n3, b passes on all 3: n2 suits both
	two = [check_pass("a", n2), fact("a", n3, "any", Fail), check_pass("b", n1), check_pass("b", n2), check_pass("b", n3)]
	# a passes on n2 and n3, b passes on n1 and n2: n3 passes for a and not for b, so only n2 suits both
	split = [check_pass("a", n2), check_pass("a", n3), check_pass("b", n1), check_pass("b", n2)]
	pick = |scope, facts| NoRank.pick({ auto, scope, facts })
	rows = [
		("R-SO14 (2): outside a project, the latest", pick(Outside, two), Ok(n3)),
		("R-SO14: no compiler in the channel", NoRank.pick({ auto: [], scope: Outside, facts: [] }), Err(Empty)),
		("R-SO14: no compiler in the channel, in a project", NoRank.pick({ auto: [], scope: Project(["a"]), facts: two }), Err(Empty)),
		("R-SO14 (1): the newest that passes for each known hash", pick(Project(["a", "b"]), two), Ok(n2)),
		("R-SO14 (1): the order of the hashes does not matter", pick(Project(["b", "a"]), two), Ok(n2)),
		("R-SO14 (1): a project with no hash", pick(Project([]), two), Ok(n3)),
		("R-SO14 (1): no fact for the hash: every compiler suits, so the latest", pick(Project(["c"]), two), Ok(n3)),
		("R-SO14 (1): a hash with no fact is ignored", pick(Project(["a", "c"]), two), Ok(n2)),
		("R-SO14 (1): a pass for each known hash is needed, not for some", pick(Project(["a", "b"]), split), Ok(n2)),
		("R-SO14 (1): no compiler suits: the latest", pick(Project(["a", "b"]), [check_pass("a", n1), check_pass("b", n2)]), Ok(n3)),
		("R-SO14 (1): a known hash that fails everywhere: the latest", pick(Project(["d"]), [fact("d", n1, "any", Fail), fact("d", n3, "any", Crash)]), Ok(n3)),
		("R-EF1: a hang is no pass", pick(Project(["a"]), [check_pass("a", n1), fact("a", n2, "any", Hang)]), Ok(n1)),
		("R-EF1: a build row is no evidence and does not make the hash known", pick(Project(["a"]), [fact("a", n3, "x64musl", Pass)]), Ok(n3)),
		("R-EF1: a build row does not make a pass", pick(Project(["a"]), [check_pass("a", n1), fact("a", n2, "x64musl", Pass)]), Ok(n1)),
		("R-CV1: the other tag form of the same nightly is the same compiler", pick(Project(["a"]), [check_pass("a", "nightly-2026-October-16-1df370f"), fact("a", n3, "any", Fail)]), Ok(n2)),
		("R-SO14: a repeat of a hash changes nothing", pick(Project(["a", "a", "b"]), two), Ok(n2)),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rows
	bad_rows == []
}

# R-EF1, R-CC8 (one `db_query!` for the pick): the keys. One key for each hash and each id of `auto`, target `any`. The hashes are sorted and have no repeat, and for each hash the ids are in the order of `auto`. No hash or no id: no key (and then no call).
expect {
	a_keys = [{ hash: "a", nightly: n1, target: "any" }, { hash: "a", nightly: n2, target: "any" }]
	b_keys = [{ hash: "b", nightly: n1, target: "any" }, { hash: "b", nightly: n2, target: "any" }]
	got = NoRank.keys({ hashes: ["b", "a", "b"], auto: [n1, n2] })
	dbg got
	got == a_keys.concat(b_keys)
		and NoRank.keys({ hashes: [], auto: [n1, n2] }) == []
			and NoRank.keys({ hashes: ["a"], auto: [] }) == []
}

# R-SO14, R-DL5, R-DL10, R-EC13: the refusals that need no list. `--offline` is exit code 13 (kind Consent) also with an answer (no download can start). `TALON_AUTO_INSTALL=no` is exit code 13 when no answer is given; an answer on the command line wins over
# the variable (`--yes`, `--allow-downloads`). Else `Go`. Both texts name the way out (a proposal, TW24).
expect {
	gate = |want, yes, flag, offline| NoRank.gate({ auto: want, yes, flag, offline })
	shown = |result| match result {
		Go => "go"
		Stop(fail) => "stop ${Str.inspect(fail.kind)} ${fail.message}"
	}
	offline_text = "stop Consent no compiler is selected, and --offline stops the download. Run: tln roc install @latest when you are online, then tln roc default <id>."
	auto_text = "stop Consent no compiler is selected. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install @latest, then tln roc default <id>, pass --allow-downloads, or set TALON_AUTO_INSTALL=yes."
	rows = [
		("ask", shown(gate(Ask, Bool.False, Err(NoFlag), Bool.False)), "go"),
		("auto yes", shown(gate(Yes, Bool.False, Err(NoFlag), Bool.False)), "go"),
		("auto no, no answer", shown(gate(No, Bool.False, Err(NoFlag), Bool.False)), auto_text),
		("auto no, --yes wins", shown(gate(No, Bool.True, Err(NoFlag), Bool.False)), "go"),
		("auto no, --allow-downloads wins", shown(gate(No, Bool.False, Ok(Yes), Bool.False)), "go"),
		("--offline", shown(gate(Ask, Bool.False, Err(NoFlag), Bool.True)), offline_text),
		("--offline with --yes: no download can start", shown(gate(Yes, Bool.True, Ok(Yes), Bool.True)), offline_text),
		("--offline and auto no: the offline text first", shown(gate(No, Bool.False, Err(NoFlag), Bool.True)), offline_text),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rows
	bad_rows == []
}

# R-NI5, R-DL1, R-DL3, R-SO14, R-NM5 (the prompt, a proposal, TW24): a required download that the command does not name, so the interactive default is No. The question names the compiler, the size, and that it becomes the default compiler.
# The answer line is the one of the other downloads (R-NM6) with the default added.
expect {
	id = n2
	prompt = NoRank.prompt({ id, size: 73861067 })
	decide = |mode, yes, flag| match Prompt.decide(prompt, { mode, yes, flag }) {
		Ask => "ask"
		NeedTty => "need-tty"
		Use(a) => "use ${Str.inspect(a)}"
		Stop(f) => "stop ${Str.inspect(f.kind)} ${f.message}"
	}
	rows = [
		("no person, no flag: stop", decide(NonInteractive, Bool.False, Err(NoFlag)), "stop Consent the download of ${id} needs consent. Pass --allow-downloads or TALON_AUTO_INSTALL=yes or --yes."),
		("--yes", decide(NonInteractive, Bool.True, Err(NoFlag)), "use Yes"),
		("--allow-downloads", decide(Interactive, Bool.False, Ok(Yes)), "use Yes"),
		("a person: ask (the default is No)", decide(Interactive, Bool.False, Err(NoFlag)), "ask"),
		("not known yet", decide(NeedsTty, Bool.False, Err(NoFlag)), "need-tty"),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rows
	texts = [
		(prompt.id, "no-rank-download"),
		(Prompt.text(prompt), "No compiler is selected. Download ${id}, 73.9 MB? It becomes the default compiler. [y/N] "),
		((prompt.answer_line)(Yes), "downloading ${id} (73.9 MB), the default compiler"),
		((prompt.answer_line)(No), "no download of ${id}"),
		(prompt.subject, "the download of ${id}"),
	]
	bad_texts = texts.keep_if(|(got, want)| got != want)
	dbg bad_texts
	bad_rows == [] and bad_texts == []
}

# R-SO14 (1) (a) and (b), R-FE4, R-NS6, R-CV1, R-EF1, R-EF3, R-P4 (slice 072c, docs/slices/072c-no-rank-installed-first.md): the installed compilers before any download. Step (a) is the newest installed compiler that has a recorded `pass` for each known hash
# (a hash is known when a check row of it exists; at least one hash must be known). Step (b) is the list of the installed compilers to probe, newest first, with the compilers skipped that have a recorded `fail` for a hash of the project (a fact never expires, R-P4).
# Only a nightly or a release counts (R-NS6: no `git-`, `link-`, `copy-` build). A recorded `Hang` or `Crash` skips a compiler like a `Fail` (R-P7, decided 2026-10-26).
expect {
	i = |installed, hashes, facts| NoRank.first({ installed, hashes, facts })
	fail_row = |hash, nightly| fact(hash, nightly, "any", Fail)
	other_form = "nightly-2026-October-16-1df370f"
	# a passes on n1 and n2 and fails on n3. b passes on all 3.
	ab = [check_pass("a", n1), check_pass("a", n2), fail_row("a", n3), check_pass("b", n1), check_pass("b", n2), check_pass("b", n3)]
	rows = [
		("(a): the newest that passes for each known hash", i([n1, n2, n3], ["a", "b"], ab), Use(n2)),
		("(a): the order of the installed list does not matter", i([n2, n3, n1], ["a", "b"], ab), Use(n2)),
		("(a): the order of the hashes does not matter", i([n1, n2, n3], ["b", "a"], ab), Use(n2)),
		("(a): a repeated hash changes nothing", i([n1, n2, n3], ["a", "a", "b"], ab), Use(n2)),
		("(a): only the installed compilers count, not the channel", i([n1], ["a", "b"], ab), Use(n1)),
		("(a): a hash with no fact is ignored", i([n1, n2], ["a", "c"], [check_pass("a", n1)]), Use(n1)),
		("(a): a pass for each known hash, not for some", i([n1, n2, n3], ["a", "b"], [check_pass("a", n3), check_pass("b", n2)]), Probe([n3, n2, n1])),
		("(a): no hash has a fact: nothing resolves", i([n1, n2], ["c"], [check_pass("a", n1)]), Probe([n2, n1])),
		("(a): no hash in the project", i([n1, n2], [], ab), Probe([n2, n1])),
		("(a): the pass is of a compiler that is not installed", i([n1, n2], ["a"], [check_pass("a", n3)]), Probe([n2, n1])),
		("(a): a build row is no evidence and makes no hash known", i([n1, n2], ["a"], [fact("a", n2, "x64musl", Pass)]), Probe([n2, n1])),
		("(a): the other tag form of the same nightly is the same compiler, and the result is the installed name", i([other_form], ["a"], [check_pass("a", n2)]), Use(other_form)),
		("(b): a compiler with a recorded fail for a hash is skipped", i([n1, n2, n3], ["a"], [fail_row("a", n3)]), Probe([n2, n1])),
		("(b): a fail for any hash of the project skips the compiler", i([n1, n2, n3], ["a", "b"], [check_pass("a", n2), fail_row("b", n2)]), Probe([n3, n1])),
		("(b): a fail of a hash that is not in the project does not skip", i([n1, n2], ["a"], [fail_row("z", n2)]), Probe([n2, n1])),
		("(b): a fail row of the other tag form skips the compiler", i([other_form, n3], ["a"], [fail_row("a", n2)]), Probe([n3])),
		("(b): a recorded hang skips the compiler (R-P7)", i([n1, n2, n3], ["a"], [fact("a", n3, "any", Hang)]), Probe([n2, n1])),
		("(b): a recorded crash skips the compiler (R-P7)", i([n1, n2, n3], ["a"], [fact("a", n3, "any", Crash)]), Probe([n2, n1])),
		("(b): a hang of another hash skips it too", i([n1, n2], ["a", "b"], [check_pass("a", n2), fact("b", n2, "any", Hang)]), Probe([n1])),
		("(a): a hang or a crash is no pass, and the hash is known", i([n1, n2], ["a"], [fact("a", n2, "any", Hang), fact("a", n1, "any", Crash)]), Probe([])),
		("R-NS6: a local build with a recorded pass is not used", i(["link-dev", n1], ["a"], [check_pass("a", "link-dev"), fact("a", n1, "any", Fail)]), Probe([])),
		("(b): a build fail row does not skip", i([n1, n2], ["a"], [fact("a", n2, "x64musl", Fail)]), Probe([n2, n1])),
		("(b): a pass of one hash does not stop the skip by a fail of another", i([n1, n2], ["a", "b"], [check_pass("a", n2), fail_row("b", n2), check_pass("b", n1)]), Probe([n1])),
		("(b): every installed compiler has a fail: nothing to probe", i([n1, n2], ["a"], [fail_row("a", n1), fail_row("a", n2)]), Probe([])),
		("(b): no installed compiler", i([], ["a"], ab), Probe([])),
		("R-NS6: a local build is never used or probed", i(["link-dev", "git-mine", "copy-x", n1], ["a"], [check_pass("a", n1)]), Use(n1)),
		("R-NS6: only local builds: nothing to probe", i(["link-dev", "copy-x"], ["a"], ab), Probe([])),
		("R-NS1: a release is older than each nightly", i(["0.1.0", n1], ["c"], []), Probe([n1, "0.1.0"])),
		("R-NS1: two nightlies of one day are ordered by the tag text", i(["nightly-2026-10-14-aaaaaaa", n1], ["c"], []), Probe(["nightly-2026-10-14-aaaaaaa", n1])),
	]
	bad_rows = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, _)| (name, got))
	dbg bad_rows
	bad_rows == []
}
