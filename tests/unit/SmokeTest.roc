import lib.Db
import lib.Smoke

SmokeTest :: [].{}

# Slice 218 (docs/slices/218-smoke-builds.md; Resolution 4 R-SM2, R-SM3, R-SM4, R-SM7; CLI 1 R-TF7): the pure part of the smoke build. The flow is the L2 cases `share/sh70` to `share/sh75`, the real SQL is the L3 case `fx/sq3-real-fx-smoke`.
# `choose` gets one good key and one thing changes at a time, so each row fails for one reason.

# D: 5 nightlies, oldest first (R-NS1), as in `SharequeueTest`.
c1 = "nightly-2026-10-01-aaaaaaa"

c2 = "nightly-2026-10-03-ccccccc"

c3 = "nightly-2026-10-05-eeeeeee"

c4 = "nightly-2026-10-07-0a0a0a0"

c5 = "nightly-2026-10-09-0b0b0b0"

# The other tag form of `c2` (R-CV1).
c2_long = "nightly-2026-October-03-ccccccc"

day_s = 86400

rel = |id, day| { id, published_at: 1790812800 + day * day_s, asset: Err(NoAsset) }

domain = [rel(c1, 0), rel(c2, 2), rel(c3, 4), rel(c4, 6), rel(c5, 8)]

art = |hash| { hash, kind: Package, exposed: [], platform_hash: Err(None), roc_pin: Err(None), size: 10, deps: [], target_names: [] }

plat = { ..art("HP"), kind: Platform, target_names: ["x64musl", "arm64mac"] }

release = |hash| { log_index: 1, hash, group: "github.com/x/y/releases/download/{v}/", series: "1", version: "1.0.0", url: "https://github.com/x/y/releases/download/1.0.0/${hash}.tar.zst", tag: Ok("1.0.0"), roc_version: Err(None), repo: Ok("x/y"), published_at: 1790848800000, yanked: Bool.False, yank_reason: Err(None), withdrawn: Err(None), provenance: ["webhook"] }

answer = |artifacts, runs, nearest, hints, unknown| { artifacts, releases: [], epochs: [], runs, nearest, hints, log_size: 40, unknown, checked: [], repos: [] }

# The answer of a command that has the platform HP.
plain = answer([plat], [], [], [], [])

run = |hash, target, source, result, from, to| { hash, target, source, result, error_digest: Err(None), from, to }

near = |hash, target, source, result, nightly| { hash, target, source, result, error_digest: Err(None), nightly, side: Before }

hint = |hash, nightly, target, pass_count, fail_count, crash_count| { hash, nightly, target, pass_count, fail_count, crash_count }

key = |id, target| { hash: "HP", nightly: id, target }

good = { built: [key(c2, "x64musl")], installed: [c2], done: [], recorded: [c2], answers: [plain], domain }

short = |id| if id == c2 "c2" else if id == c3 "c3" else id

# The choices as text: `<nightly> <target> <verdict>`, in the order of the choices.
view = |input| Smoke.choose(input).map(
	|c| {
		verdict = match c.verdict {
			Build => "build"
			Skip(NotInstalled) => "not-installed"
			Skip(Done) => "done"
			Skip(BotRow) => "bot-row"
			Skip(Hints) => "hints"
			Skip(Compiler) => "compiler"
			Skip(NotInAnswer) => "not-in-answer"
		}
		"${short(c.key.nightly)} ${c.key.target} ${verdict}"
	},
)

# The result of each row below, and the rows that are not what they should be (shown by `dbg`).
wrong = |cases| {
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad
}

smoke_row = |id, target, outcome| { hash: "HP", nightly: id, target, outcome }

# R-SM7: the list of the machine errors is a constant. The first one is `WindowsSDKNotFound`.
expect {
	Smoke.machine_errors == ["WindowsSDKNotFound"]
}

# R-SM3 row 1: one build for each key (platform hash, nightly, target) that the command built. The target of the key is the target of that build, a key that is in `built` more than once is one build, and a key of another target, nightly or hash is its own build.
# The order is the order of the first appearance.
expect {
	both = { ..good, built: [key(c2, "x64musl"), key(c2, "arm64mac")] }
	twice = { ..good, built: [key(c2, "x64musl"), key(c3, "x64musl"), key(c2, "x64musl")], installed: [c2, c3], recorded: [c2, c3] }
	other_hash = { ..good, built: [{ hash: "HQ", nightly: c2, target: "x64musl" }, key(c2, "x64musl")], answers: [answer([plat, { ..plat, hash: "HQ" }], [], [], [], [])] }
	cases = [
		("one key that passes each condition", view(good), ["c2 x64musl build"]),
		("no key", view({ ..good, built: [] }), []),
		("2 targets of one nightly", view(both), ["c2 x64musl build", "c2 arm64mac build"]),
		("a key twice is one build, in the order of the first appearance", view(twice), ["c2 x64musl build", "c3 x64musl build"]),
		("2 hashes", view(other_hash), ["c2 x64musl build", "c2 x64musl build"]),
		("one target is done, the other is not: each its own decision", view({ ..both, done: [smoke_row(c2, "x64musl", Pass)] }), ["c2 x64musl done", "c2 arm64mac build"]),
	]
	wrong(cases) == []
}

# R-SM3 row 2: the nightly is installed. A smoke build never downloads, so a compiler with no program is no build.
expect {
	cases = [
		("the nightly is installed", view(good), ["c2 x64musl build"]),
		("no compiler is installed", view({ ..good, installed: [] }), ["c2 x64musl not-installed"]),
		("another nightly is installed", view({ ..good, installed: [c3] }), ["c2 x64musl not-installed"]),
	]
	wrong(cases) == []
}

# R-SM3 row 3: `compat.db` has no smoke result for the key. A result of any outcome (a hang too, R-SM4 table) stops the build. A row of another target, nightly or hash does not.
expect {
	cases = [
		("a pass", view({ ..good, done: [smoke_row(c2, "x64musl", Pass)] }), ["c2 x64musl done"]),
		("a fail", view({ ..good, done: [smoke_row(c2, "x64musl", Fail)] }), ["c2 x64musl done"]),
		("a hang", view({ ..good, done: [smoke_row(c2, "x64musl", Hang)] }), ["c2 x64musl done"]),
		("a crash", view({ ..good, done: [smoke_row(c2, "x64musl", Crash)] }), ["c2 x64musl done"]),
		("a row of another target", view({ ..good, done: [smoke_row(c2, "arm64mac", Pass)] }), ["c2 x64musl build"]),
		("a row of another nightly", view({ ..good, done: [smoke_row(c3, "x64musl", Pass)] }), ["c2 x64musl build"]),
		("a row of another hash", view({ ..good, done: [{ hash: "HQ", nightly: c2, target: "x64musl", outcome: Pass }] }), ["c2 x64musl build"]),
	]
	wrong(cases) == []
}

# R-SM3 row 4: no answer of the command has a `bot` row for the key (the run interval holds the nightly, or a `nearest` row), and no row of `hints` for the key with a total count of 3 or more (first guess: the total is pass, fail and crash counts).
# A bot row of any result stops the build (a pass too: R-SM6 says a pass is not a pass of step 3, but the key has a result already). An `author` row, a bot row of another target (the unit check has the target `any`), of another hash, or of an interval without the nightly, does not.
expect {
	with_runs = |runs| { ..good, answers: [answer([plat], runs, [], [], [])] }
	with_near = |rows| { ..good, answers: [answer([plat], [], rows, [], [])] }
	with_hints = |rows| { ..good, answers: [answer([plat], [], [], rows, [])] }
	cases = [
		("a bot fail in the interval", view(with_runs([run("HP", "x64musl", Bot, Fail, c1, c3)])), ["c2 x64musl bot-row"]),
		("a bot pass in the interval", view(with_runs([run("HP", "x64musl", Bot, Pass, c2, c2)])), ["c2 x64musl bot-row"]),
		("an author row", view(with_runs([run("HP", "x64musl", Author, Pass, c1, c3)])), ["c2 x64musl build"]),
		("a bot row of the unit check (target any)", view(with_runs([run("HP", "any", Bot, Pass, c1, c3)])), ["c2 x64musl build"]),
		("a bot row of another hash", view(with_runs([run("HQ", "x64musl", Bot, Pass, c1, c3)])), ["c2 x64musl build"]),
		("a bot interval before the nightly", view(with_runs([run("HP", "x64musl", Bot, Pass, c1, c1)])), ["c2 x64musl build"]),
		("a bot nearest row of the other tag form", view(with_near([near("HP", "x64musl", Bot, Fail, c2_long)])), ["c2 x64musl bot-row"]),
		("a bot row in the second answer", view({ ..good, answers: [plain, answer([plat], [run("HP", "x64musl", Bot, Pass, c2, c2)], [], [], [])] }), ["c2 x64musl bot-row"]),
		("hints: 1 pass, 1 fail, 1 crash is a total of 3", view(with_hints([hint("HP", c2, "x64musl", 1, 1, 1)])), ["c2 x64musl hints"]),
		("hints: 3 pass", view(with_hints([hint("HP", c2, "x64musl", 3, 0, 0)])), ["c2 x64musl hints"]),
		("hints: a total of 2", view(with_hints([hint("HP", c2, "x64musl", 1, 1, 0)])), ["c2 x64musl build"]),
		("hints: the other tag form of the nightly", view(with_hints([hint("HP", c2_long, "x64musl", 0, 3, 0)])), ["c2 x64musl hints"]),
		("hints: another target", view(with_hints([hint("HP", c2, "any", 5, 0, 0)])), ["c2 x64musl build"]),
		("hints: another nightly", view(with_hints([hint("HP", c3, "x64musl", 5, 0, 0)])), ["c2 x64musl build"]),
		("hints: another hash", view(with_hints([hint("HQ", c2, "x64musl", 5, 0, 0)])), ["c2 x64musl build"]),
	]
	wrong(cases) == []
}

# R-SM3 row 5: the platform passes the filters 3 and 4 of R-SH3. Filter 3: a nightly tag that has a recorded sha256 (a release id `X.Y.Z` is refused, Design Q431). Filter 4: the hash is the `hash` of an `artifacts` row or a `releases` row of an answer of the command (not `unknown`).
expect {
	released = { ..plain, artifacts: [], releases: [release("HP")] }
	cases = [
		("a recorded nightly, the hash in an artifacts row", view(good), ["c2 x64musl build"]),
		("the nightly has no recorded sha256", view({ ..good, recorded: [] }), ["c2 x64musl compiler"]),
		("another nightly is recorded", view({ ..good, recorded: [c3] }), ["c2 x64musl compiler"]),
		("a release id, also installed and recorded", view({ ..good, built: [key("0.1.0", "x64musl")], installed: ["0.1.0"], recorded: ["0.1.0"] }), ["0.1.0 x64musl compiler"]),
		("a named build, also installed and recorded", view({ ..good, built: [key("link-mine", "x64musl")], installed: ["link-mine"], recorded: ["link-mine"] }), ["link-mine x64musl compiler"]),
		("the hash is in a releases row only", view({ ..good, answers: [released] }), ["c2 x64musl build"]),
		("the hash is in the second answer", view({ ..good, answers: [answer([art("H1")], [], [], [], []), plain] }), ["c2 x64musl build"]),
		("the hash is in no answer", view({ ..good, answers: [answer([art("H1")], [], [], [], [])] }), ["c2 x64musl not-in-answer"]),
		("the hash is only in unknown", view({ ..good, answers: [answer([], [], [], [], ["HP"])] }), ["c2 x64musl not-in-answer"]),
		("no answer", view({ ..good, answers: [] }), ["c2 x64musl not-in-answer"]),
	]
	wrong(cases) == []
}

# R-SM3: the first false condition gives the reason, in the order of the table: row 2, row 3, row 4 (the bot row, then the hints), then the filter 3, then the filter 4.
expect {
	all_false = { built: [key(c2, "x64musl")], installed: [], done: [smoke_row(c2, "x64musl", Pass)], recorded: [], answers: [answer([], [run("HP", "x64musl", Bot, Pass, c2, c2)], [], [hint("HP", c2, "x64musl", 3, 0, 0)], [])], domain }
	cases = [
		("every condition false", view(all_false), ["c2 x64musl not-installed"]),
		("installed: the smoke row comes first", view({ ..all_false, installed: [c2] }), ["c2 x64musl done"]),
		("no smoke row: the bot row comes first", view({ ..all_false, installed: [c2], done: [] }), ["c2 x64musl bot-row"]),
		("no bot row: the hints", view({ ..all_false, installed: [c2], done: [], answers: [answer([], [], [], [hint("HP", c2, "x64musl", 3, 0, 0)], [])] }), ["c2 x64musl hints"]),
		("no hints: the compiler filter before the answer filter", view({ ..all_false, installed: [c2], done: [], answers: [answer([], [], [], [], [])] }), ["c2 x64musl compiler"]),
		("recorded: the answer filter", view({ ..all_false, installed: [c2], done: [], recorded: [c2], answers: [answer([], [], [], [], [])] }), ["c2 x64musl not-in-answer"]),
	]
	wrong(cases) == []
}

# R-SM4, R-SM7 (Design Q548), R-P3, R-RC1 to R-RC4: the class of the output of a smoke build. A machine error is a line of stderr, without white space at its end, that is exactly `Error: <name>` for a name of the list, with any exit code; stdout is not read and a substring does not count. A stored row for a pass, a fail, a hang and a crash (the table `smoke` has the 4 words). A machine error: no row and no queue, also when the output would be a fail. A result with no fact: no row.
expect {
	out = |ended, stdout, stderr| { ended, stdout, stderr }
	built_ok = "0 errors and 0 warnings found in 166ms while successfully building:\n\n    /tmp/t/tln-probe.out\n"
	built_bad = "5 errors and 0 warnings found in 94ms while successfully building:\n\n    /tmp/t/tln-probe.out\n"
	header = |title| "── ✗ ${title} ────────────────────────────────────────────────\n\nthe text of the report\n"
	show = |r| match r {
		Row(Pass) => "row pass"
		Row(Fail) => "row fail"
		Row(Hang) => "row hang"
		Row(Crash) => "row crash"
		Machine => "machine"
		NoFact => "no fact"
	}
	cases = [
		("pass", show(Smoke.result(out(Exited(0), built_ok, ""))), "row pass"),
		("a build with errors", show(Smoke.result(out(Exited(1), built_bad, ""))), "row fail"),
		("a target error with no summary line", show(Smoke.result(out(Exited(1), "", header("unsupported target")))), "row fail"),
		("a link error", show(Smoke.result(out(Exited(1), "", "${header("LINKER FAILED")}ld: library not found for -lSystem\n"))), "row fail"),
		("timed out", show(Smoke.result(out(TimedOut, "", ""))), "row hang"),
		("SIGSEGV", show(Smoke.result(out(Signaled(11), "", ""))), "row crash"),
		("exit 139", show(Smoke.result(out(Exited(139), "", ""))), "row crash"),
		("SIGKILL is no fact (the OOM killer, R-P3)", show(Smoke.result(out(Signaled(9), "", ""))), "no fact"),
		("SIGTERM is no fact", show(Smoke.result(out(Signaled(15), "", ""))), "no fact"),
		("not started is no fact", show(Smoke.result(out(NotStarted("NotFound"), "", ""))), "no fact"),
		("exit 1 and no text is no fact", show(Smoke.result(out(Exited(1), "", ""))), "no fact"),
		("WindowsSDKNotFound as a line of stderr (research/smoke-errors, Q548)", show(Smoke.result(out(Exited(1), "", "Error: WindowsSDKNotFound\n"))), "machine"),
		("the line after a linker report, as roc 10-06 prints it", show(Smoke.result(out(Exited(1), "", "${header("linker failed")}The linker failed while building for target x64win.\n\nError: WindowsSDKNotFound\n"))), "machine"),
		("any exit code: exit 139", show(Smoke.result(out(Exited(139), "", "Error: WindowsSDKNotFound\n"))), "machine"),
		("any exit code: exit 0", show(Smoke.result(out(Exited(0), built_ok, "Error: WindowsSDKNotFound\n"))), "machine"),
		("white space at the end of the line does not count", show(Smoke.result(out(Exited(1), "", "Error: WindowsSDKNotFound \r\n"))), "machine"),
		("a substring is no machine error: the name in a title", show(Smoke.result(out(Exited(1), "", header("WindowsSDKNotFound")))), "row fail"),
		("a substring is no machine error: a longer line", show(Smoke.result(out(Exited(1), "", "${header("linker failed")}note: Error: WindowsSDKNotFound happened\n"))), "row fail"),
		("a substring is no machine error: a longer name", show(Smoke.result(out(Exited(1), "", "${header("linker failed")}Error: WindowsSDKNotFoundAtAll\n"))), "row fail"),
		("stdout is not read", show(Smoke.result(out(Exited(1), "Error: WindowsSDKNotFound\n", ""))), "no fact"),
		("a ld64.lld error is a platform fault", show(Smoke.result(out(Exited(1), "", "${header("linker failed")}ld64.lld: error: library not found for -lSystem\n"))), "row fail"),
	]
	wrong(cases) == []
}

# R-SM2: the smoke app. It is the app of `init --platform` (`InitStub.app_text`, R-IN8) with the body `crash "talon smoke test"` for each stub: a lambda with one `_` for each argument (`()` has none), a record of stubs, `Alias : {}` for each alias, and the app exposes each alias and each name.
# A value of another type (a constant would crash when roc compiles it), a clause with 2 or more entries, and a text that is no platform have no smoke build.
expect {
	url = "https://github.com/acme/pf/releases/download/0.1.0/h.tar.zst"
	hdr = |clause| "platform \"acme\"\n\trequires ${clause}\n\texposes [Std]\n\tpackages {}\n\tprovides [main_for_host!]\n"
	view_text = |text| match Smoke.app_text({ url, text }) {
		Ok(found) => found
		Err(NoSmoke) => "no smoke"
	}
	view_app = |clause| view_text(hdr(clause))
	smoke_app = |names, body| "app [${names}] {\n\tpf: platform \"${url}\",\n}\n\n${body}"
	crashes = "crash \"talon smoke test\""
	cases = [
		("a function of one argument (the new form)", view_app("{\n\t\tmain! : List(Str) => Try({}, [Exit(I32), ..])\n\t}"), smoke_app("main!", "main! = |_| ${crashes}\n")),
		("the old form with 2 records, `()` is no argument", view_app("{} { main! : () => {} }"), smoke_app("main!", "main! = || ${crashes}\n")),
		(
			"an alias and a record of functions",
			view_app("{\n\t\t[Context : context] for program : {\n\t\t\tinit! : () => Try(context, Str),\n\t\t\trespond! : Request, context => Try(Response, Str),\n\t\t}\n\t}"),
			smoke_app("Context, program", "Context : {}\n\nprogram = {\n\tinit!: || ${crashes},\n\trespond!: |_, _| ${crashes},\n}\n"),
		),
		("a value of another type", view_app("{ name : Str }"), "no smoke"),
		("a record with a field of another type", view_app("{ main! : { go! : () => {}, port : U16 } }"), "no smoke"),
		("a clause with 2 entries", view_app("{} { main! : () => {}, helper! : Str => {}, }"), "no smoke"),
		("no platform: a package header", view_text("package [Lib] {}\n"), "no smoke"),
	]
	wrong(cases) == []
}

# R-TF7, Design Q201: the line of a row of the table `smoke` (the form of the fake `Fx` file `smoke.tsv` and of the L3 dump): `hash<TAB>nightly<TAB>target<TAB>outcome`. The round trip, the 4 words, and the lines that are not a row.
expect {
	line = |outcome| Db.smoke_line({ hash: "HP", nightly: c2, target: "x64musl", outcome })
	back = |text| match Db.smoke_of(text) {
		Ok(row) => Db.smoke_line(row)
		Err(BadLine) => "bad"
	}
	cases = [
		("pass", line(Pass), "HP\t${c2}\tx64musl\tpass"),
		("fail", line(Fail), "HP\t${c2}\tx64musl\tfail"),
		("hang", line(Hang), "HP\t${c2}\tx64musl\thang"),
		("crash", line(Crash), "HP\t${c2}\tx64musl\tcrash"),
		("round trip", back("HP\t${c2}\tx64musl\tcrash"), "HP\t${c2}\tx64musl\tcrash"),
		("the row", if Db.smoke_of("HP\t${c2}\tx64musl\thang") == Ok({ hash: "HP", nightly: c2, target: "x64musl", outcome: Hang }) "the row" else "other", "the row"),
		("3 fields", back("HP\t${c2}\tx64musl"), "bad"),
		("5 fields", back("HP\t${c2}\tx64musl\tpass\textra"), "bad"),
		("a wrong word", back("HP\t${c2}\tx64musl\tok"), "bad"),
		("the empty text", back(""), "bad"),
	]
	wrong(cases) == []
}
