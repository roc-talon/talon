import lib.Db
import lib.Fail
import lib.ShareQueue

SharequeueTest :: [].{}

# Slice 215 (docs/slices/215-share-queue.md). Pure: R-SH2 (the 5 conditions) and the 6 filters of R-SH3 for a fact that goes into the queue, the tool-app conditions, the line form of a row (R-TF7), the failure of the write.
# The tests call `admit` with one good fact and change one thing at a time, so each row of a table fails for one reason.

# D: 5 nightlies, oldest first (R-NS1), as in `MatrixTest`.
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

url = Url("https://registry.example.org")

on = { share: Ok(Bool.True), registry: url, offline: Bool.False, env: [] }

good = { origin: Probed, probe: Unit, compiler: { id: c2, recorded: Bool.True }, hash: "H1", target: "any", outcome: Pass, machine_error: Bool.False }

art = |hash| { hash, kind: Package, exposed: [], platform_hash: Err(None), roc_pin: Err(None), size: 10, deps: [], target_names: [] }

plat = { ..art("HP"), kind: Platform, target_names: ["x64musl", "arm64mac"] }

happ = { ..art("HA"), kind: App }

release = |hash| { log_index: 1, hash, group: "github.com/x/y/releases/download/{v}/", series: "1", version: "1.0.0", url: "https://github.com/x/y/releases/download/1.0.0/${hash}.tar.zst", tag: Ok("1.0.0"), roc_version: Err(None), repo: Ok("x/y"), published_at: 1790848800000, yanked: Bool.False, yank_reason: Err(None), withdrawn: Err(None), provenance: ["webhook"] }

answer = |artifacts, runs, nearest, unknown| { artifacts, releases: [], epochs: [], runs, nearest, hints: [], log_size: 40, unknown, checked: [], repos: [] }

plain = answer([art("H1"), art("H2")], [], [], [])

run = |hash, target, source, result, from, to| { hash, target, source, result, error_digest: Err(None), from, to }

near = |hash, target, source, result, nightly| { hash, target, source, result, error_digest: Err(None), nightly, side: Before }

version = "0.9.0"

at = "2026-11-03T10:00:00Z"

row = { hash: "H1", nightly: c2, target: "any", result: Pass, talon_version: version, queued_at: at }

go = |sharing, fact, answers| go_h(sharing, fact, answers, [])

go_h = |sharing, fact, answers, headers| ShareQueue.admit({ sharing, fact, answers, headers, domain, talon_version: version, queued_at: at })

# The result of each row below, and the rows that are not what they should be (shown by `dbg`).
wrong = |cases| {
	bad = cases.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad
}

# R-SH2, R-EV26: the 5 conditions, through the queue. A fact that passes all filters is queued only when `Share.state` is `On` (the same first false condition as `Share.state`, slice 213 D3).
# Condition 4: `DO_NOT_TRACK` set, not empty and not `0` (`1` and `true` stop, empty and `0` do not). Condition 5: `CI` is `true` or `1` in any case; `TALON_INTERACTIVE` does not change it.
# A condition that is false also stops a fact that fails a filter (the reason is the condition: it is the first test).
expect {
	queued = Queue(row)
	env = |pairs| { ..on, env: pairs }
	cases = [
		("all 5 conditions are true", go(on, good, [plain]), queued),
		("1: share is not set", go({ ..on, share: Err(Unset) }, good, [plain]), Skip(Off(Share))),
		("1: share is false", go({ ..on, share: Ok(Bool.False) }, good, [plain]), Skip(Off(Share))),
		("2: the registry is direct", go({ ..on, registry: Direct }, good, [plain]), Skip(Off(Registry))),
		("3: --offline", go({ ..on, offline: Bool.True }, good, [plain]), Skip(Off(Offline))),
		("4: DO_NOT_TRACK=1", go(env([("DO_NOT_TRACK", "1")]), good, [plain]), Skip(Off(DoNotTrack))),
		("4: DO_NOT_TRACK=true", go(env([("DO_NOT_TRACK", "true")]), good, [plain]), Skip(Off(DoNotTrack))),
		("4: DO_NOT_TRACK empty", go(env([("DO_NOT_TRACK", "")]), good, [plain]), queued),
		("4: DO_NOT_TRACK=0", go(env([("DO_NOT_TRACK", "0")]), good, [plain]), queued),
		("5: CI=true", go(env([("CI", "true")]), good, [plain]), Skip(Off(Ci))),
		("5: CI=TRUE", go(env([("CI", "TRUE")]), good, [plain]), Skip(Off(Ci))),
		("5: CI=1", go(env([("CI", "1")]), good, [plain]), Skip(Off(Ci))),
		("5: CI=false", go(env([("CI", "false")]), good, [plain]), queued),
		("5: CI=0", go(env([("CI", "0")]), good, [plain]), queued),
		("5: CI empty", go(env([("CI", "")]), good, [plain]), queued),
		("5: TALON_INTERACTIVE=1 does not change CI=true", go(env([("CI", "true"), ("TALON_INTERACTIVE", "1")]), good, [plain]), Skip(Off(Ci))),
		("the first false condition: DO_NOT_TRACK before CI", go(env([("CI", "true"), ("DO_NOT_TRACK", "1")]), good, [plain]), Skip(Off(DoNotTrack))),
		("the first false condition: share before the registry", go({ ..on, share: Err(Unset), registry: Direct }, good, [plain]), Skip(Off(Share))),
		("a condition before a filter: sharing off and a baseline check", go({ ..on, offline: Bool.True }, { ..good, probe: Baseline }, [plain]), Skip(Off(Offline))),
	]
	wrong(cases) == []
}

# R-SH3 filter 1: the fact is the result of a probe that this command ran. An old fact of `compat.db`, a fact from the registry and an inferred fact (R-EP14) are not.
expect {
	cases = [
		("probed here", go(on, good, [plain]), Queue(row)),
		("an old fact of compat.db", go(on, { ..good, origin: Stored }, [plain]), Skip(NotProbed)),
		("a fact from the registry", go(on, { ..good, origin: Registry }, [plain]), Skip(NotProbed)),
		("an inferred fact", go(on, { ..good, origin: Inferred }, [plain]), Skip(NotProbed)),
	]
	wrong(cases) == []
}

# R-SH3 filter 2: a unit check of a package or a platform, or a smoke build of a platform. The baseline check, the whole-app check, an app build, the project file and a bundle file are stopped (they hold the code of the user).
expect {
	cases = [
		("a unit check", go(on, { ..good, probe: Unit }, [plain]), Queue(row)),
		("a smoke build", go(on, { ..good, probe: Smoke }, [plain]), Queue(row)),
		("the baseline check", go(on, { ..good, probe: Baseline }, [plain]), Skip(Kind)),
		("the whole-app check", go(on, { ..good, probe: WholeApp }, [plain]), Skip(Kind)),
		("an app build", go(on, { ..good, probe: AppBuild }, [plain]), Skip(Kind)),
		("the project file", go(on, { ..good, probe: ProjectFile }, [plain]), Skip(Kind)),
		("a bundle file", go(on, { ..good, probe: BundleFile }, [plain]), Skip(Kind)),
	]
	wrong(cases) == []
}

# R-SH3 filter 2, the build of a tool app (R-T21): the 3 conditions. 1: a `github.com` release bundle that the registry indexes with the kind `app`. 2: the header of the bundle with no change (no `--resolve`, no override).
# 3: not a build from a git ref (`--git`). One false condition stops the fact, each alone.
expect {
	tool_app = |indexed_app, changed, git_ref| { ..good, probe: ToolApp({ indexed_app, changed, git_ref }) }
	cases = [
		("all 3 conditions", go(on, tool_app(Bool.True, Bool.False, Bool.False), [plain]), Queue(row)),
		("1: not an indexed app bundle", go(on, tool_app(Bool.False, Bool.False, Bool.False), [plain]), Skip(Kind)),
		("2: --resolve or an override", go(on, tool_app(Bool.True, Bool.True, Bool.False), [plain]), Skip(Kind)),
		("3: a build from a git ref", go(on, tool_app(Bool.True, Bool.False, Bool.True), [plain]), Skip(Kind)),
		("1 and 3 false", go(on, tool_app(Bool.False, Bool.False, Bool.True), [plain]), Skip(Kind)),
		("all 3 false", go(on, tool_app(Bool.False, Bool.True, Bool.True), [plain]), Skip(Kind)),
	]
	wrong(cases) == []
}

# R-SH3 filter 3 (6.2, R-CV6): the compiler is an official nightly with the recorded sha256. A nightly with no recorded sha256, and a source build, a link or a copy (R-NS6, 6.6) are stopped, also with a recorded flag.
expect {
	using = |id, recorded| { ..good, compiler: { id, recorded } }
	cases = [
		("a nightly with a recorded sha256", go(on, using(c2, Bool.True), [plain]), Queue(row)),
		("a nightly with no recorded sha256", go(on, using(c2, Bool.False), [plain]), Skip(Compiler)),
		("a source build", go(on, using("git-mine", Bool.True), [plain]), Skip(Compiler)),
		("a link", go(on, using("link-mine", Bool.True), [plain]), Skip(Compiler)),
		("a copy", go(on, using("copy-mine", Bool.True), [plain]), Skip(Compiler)),
		("a local debug build", go(on, using("debug-abc1234", Bool.True), [plain]), Skip(Compiler)),
		("Q431: a release X.Y.Z with a recorded sha256", go(on, using("0.1.0", Bool.True), [plain]), Skip(Compiler)),
		("Q431: a release X.Y.Z with no recorded sha256", go(on, using("0.2.0", Bool.False), [plain]), Skip(Compiler)),
	]
	wrong(cases) == []
}

# R-SH3 filter 4 (R-AP17, Design Q432): the hash came in an answer of the registry in this command. The set is the `hash` of each `artifacts` row and of each `releases` row of all answers. A hash with no answer, a hash of no answer,
# a hash that is only in `unknown` (R-AP28: the registry does not index it), only a dep hash, only a `platform_hash`, or only in `runs`, `nearest` or `hints` (they name hashes of the records) are stopped.
expect {
	two = answer([art("H3")], [], [], [])
	only_unknown = answer([art("H2")], [], [], ["H1"])
	releases_only = { ..answer([], [], [], []), releases: [release("H1")] }
	dep = { alias: "d", hash: "H1", is_platform: Bool.False, group: "g", series: Ok("1"), version: Ok("1.0.0"), url: "u" }
	dep_only = answer([{ ..art("H2"), deps: [dep] }], [], [], [])
	platform_only = answer([{ ..art("H2"), platform_hash: Ok("H1") }], [], [], [])
	runs_only = answer([art("H2")], [run("H1", "any", Author, Pass, c1, c1)], [near("H1", "any", Author, Pass, c1)], [])
	hints_only = { ..answer([art("H2")], [], [], []), hints: [{ hash: "H1", nightly: c2, target: "any", pass_count: 3, fail_count: 0, crash_count: 0 }] }
	cases = [
		("the hash is in an answer", go(on, good, [plain]), Queue(row)),
		("the hash is in the second answer of the command", go(on, { ..good, hash: "H3" }, [plain, two]), Queue({ ..row, hash: "H3" })),
		("the hash is in no answer", go(on, { ..good, hash: "H9" }, [plain, two]), Skip(NotInAnswer)),
		("no answer (direct reads, a patched package)", go(on, good, []), Skip(NotInAnswer)),
		("the hash is only in unknown", go(on, good, [only_unknown]), Skip(NotInAnswer)),
		("Q432: the hash is only in a release row, with a header file (Q450)", go_h(on, good, [releases_only], [{ hash: "H1", kind: Package, names: [] }]), Queue(row)),
		("Q432: the hash is only the hash of a dep", go(on, good, [dep_only]), Skip(NotInAnswer)),
		("Q432: the hash is only a platform_hash", go(on, good, [platform_only]), Skip(NotInAnswer)),
		("Q432: the hash is only in runs and nearest", go(on, good, [runs_only]), Skip(NotInAnswer)),
		("Q432: the hash is only in hints", go(on, good, [hints_only]), Skip(NotInAnswer)),
	]
	wrong(cases) == []
}

# R-SH3 filter 5 (R-EF3): no answer of this command had a `bot` row for the pair (hash, nightly, target). A `bot` run holds each release of D in its interval, a `nearest` row has its own nightly. The tag forms of a release are one (R-CV1).
# A `bot` row of another hash, another target or another compiler, and an `author` row, stop nothing. A `bot` row of any result stops the fact (a rank 2 row gives the pair already).
expect {
	with_runs = |runs, nearest| answer([art("H1"), art("H2")], runs, nearest, [])
	cases = [
		("a bot run that holds the compiler", go(on, good, [with_runs([run("H1", "any", Bot, Pass, c1, c3)], [])]), Skip(BotRow)),
		("a bot run whose interval ends before the compiler", go(on, good, [with_runs([run("H1", "any", Bot, Pass, c1, c1)], [])]), Queue(row)),
		("a bot run that starts after the compiler", go(on, good, [with_runs([run("H1", "any", Bot, Pass, c3, c5)], [])]), Queue(row)),
		("a bot run of the compiler only", go(on, good, [with_runs([run("H1", "any", Bot, Pass, c2, c2)], [])]), Skip(BotRow)),
		("a bot row of another hash", go(on, good, [with_runs([run("H2", "any", Bot, Pass, c1, c3)], [])]), Queue(row)),
		("a bot row of another target", go(on, good, [with_runs([run("H1", "x64musl", Bot, Pass, c1, c3)], [])]), Queue(row)),
		("an author row", go(on, good, [with_runs([run("H1", "any", Author, Pass, c1, c3)], [])]), Queue(row)),
		("a bot row with a fail", go(on, good, [with_runs([run("H1", "any", Bot, Fail, c2, c2)], [])]), Skip(BotRow)),
		("a bot row with a hang", go(on, good, [with_runs([run("H1", "any", Bot, Hang, c2, c2)], [])]), Skip(BotRow)),
		("a nearest bot row of the same nightly", go(on, good, [with_runs([], [near("H1", "any", Bot, Pass, c2)])]), Skip(BotRow)),
		("a nearest bot row of another nightly", go(on, good, [with_runs([], [near("H1", "any", Bot, Pass, c3)])]), Queue(row)),
		("a nearest author row", go(on, good, [with_runs([], [near("H1", "any", Author, Pass, c2)])]), Queue(row)),
		("a bot row in the second answer", go(on, good, [plain, with_runs([run("H1", "any", Bot, Pass, c2, c2)], [])]), Skip(BotRow)),
		("R-CV1: the other tag form of the compiler in the run", go(on, good, [with_runs([run("H1", "any", Bot, Pass, c2_long, c2_long)], [])]), Skip(BotRow)),
		("R-CV1: the other tag form of the compiler in the fact", go(on, { ..good, compiler: { id: c2_long, recorded: Bool.True } }, [with_runs([run("H1", "any", Bot, Pass, c2, c2)], [])]), Skip(BotRow)),
		("a smoke fact and a bot smoke row of its target", go(on, { ..good, probe: Smoke, target: "x64musl" }, [with_runs([run("H1", "x64musl", Bot, Fail, c2, c2)], [])]), Skip(BotRow)),
	]
	wrong(cases) == []
}

# R-SH3 filter 6 (R-RC1 to R-RC4, R-SM7): the result is `pass`, `fail` or `crash`, and a `fail` is not a machine error. A hang (R-RC3) is stopped.
expect {
	cases = [
		("a pass", go(on, { ..good, outcome: Pass }, [plain]), Queue({ ..row, result: Pass })),
		("a fail", go(on, { ..good, outcome: Fail }, [plain]), Queue({ ..row, result: Fail })),
		("a crash", go(on, { ..good, outcome: Crash }, [plain]), Queue({ ..row, result: Crash })),
		("a hang", go(on, { ..good, outcome: Hang }, [plain]), Skip(Result)),
		("a fail that is a machine error", go(on, { ..good, outcome: Fail, machine_error: Bool.True }, [plain]), Skip(Result)),
	]
	wrong(cases) == []
}

# R-SH3 filter 7 (Design Q432, Registry R-CT2): the target is one that the Worker takes for the kind of the record. A package: `any`. A platform: `any` or a name of its `target_names`. An app: any target.
# Else the whole hint request would be a 400. A smoke fact of a platform has a real target, a unit check has `any`.
expect {
	on_kind = |hash, probe, target| go(on, { ..good, hash, probe, target }, [answer([art("H1"), plat, happ], [], [], [])])
	cases = [
		("a package, any", on_kind("H1", Unit, "any"), Queue(row)),
		("a package with a real target", on_kind("H1", Unit, "x64musl"), Skip(Target)),
		("a platform, any", on_kind("HP", Unit, "any"), Queue({ ..row, hash: "HP" })),
		("a platform, a target of target_names", on_kind("HP", Smoke, "x64musl"), Queue({ ..row, hash: "HP", target: "x64musl" })),
		("a platform, another target of target_names", on_kind("HP", Smoke, "arm64mac"), Queue({ ..row, hash: "HP", target: "arm64mac" })),
		("a platform, a target that it does not build", on_kind("HP", Smoke, "riscv"), Skip(Target)),
		("an app, any", on_kind("HA", ToolApp({ indexed_app: Bool.True, changed: Bool.False, git_ref: Bool.False }), "any"), Queue({ ..row, hash: "HA" })),
		("an app, a real target", on_kind("HA", ToolApp({ indexed_app: Bool.True, changed: Bool.False, git_ref: Bool.False }), "riscv"), Queue({ ..row, hash: "HA", target: "riscv" })),
	]
	wrong(cases) == []
}

# R-SH3 filter 7 (Design Q450): a hash with no `artifacts` row in the answers (a release row only) takes its kind and names from the header of `packages/<hash>/main.roc`, which the caller reads and gives as `headers`.
# A header that gives the kind and the names is used as an `artifacts` row is: pass and fail. No entry (no file): the fact fails and is not queued. An `artifacts` row wins over a `headers` entry of the same hash.
expect {
	rel_only = { ..answer([], [], [], []), releases: [release("H1"), release("HP"), release("HA")] }
	h = |hash, kind, names| { hash, kind, names }
	on_header = |hash, target, headers| go_h(on, { ..good, hash, target }, [rel_only], headers)
	cases = [
		("a package header, any", on_header("H1", "any", [h("H1", Package, [])]), Queue(row)),
		("a package header, a real target", on_header("H1", "x64musl", [h("H1", Package, [])]), Skip(Target)),
		("a platform header, a target of its list", on_header("HP", "x64musl", [h("HP", Platform, ["x64musl", "arm64mac"])]), Queue({ ..row, hash: "HP", target: "x64musl" })),
		("a platform header, any", on_header("HP", "any", [h("HP", Platform, ["x64musl"])]), Queue({ ..row, hash: "HP", target: "any" })),
		("a platform header, a target that it does not build", on_header("HP", "riscv", [h("HP", Platform, ["x64musl", "arm64mac"])]), Skip(Target)),
		("an app header, a real target", on_header("HA", "riscv", [h("HA", App, [])]), Queue({ ..row, hash: "HA", target: "riscv" })),
		("no header file for the hash", on_header("H1", "any", []), Skip(Target)),
		("no header file for the hash, a real target", on_header("HP", "x64musl", []), Skip(Target)),
		("the header of another hash", on_header("H1", "any", [h("HP", Platform, ["x64musl"])]), Skip(Target)),
		("an artifacts row wins over a header", go_h(on, { ..good, target: "x64musl" }, [plain], [h("H1", App, [])]), Skip(Target)),
	]
	wrong(cases) == []
}

# The order of the tests: the first one that is false gives the reason (R-SH2 conditions, then the filters 1 to 6). A fact that fails all of them gives `Off`. Each step makes one more thing right.
expect {
	all_bad = { origin: Stored, probe: Baseline, compiler: { id: "link-x", recorded: Bool.False }, hash: "H9", target: "any", outcome: Hang, machine_error: Bool.True }
	bot = answer([art("H1")], [run("H9", "any", Bot, Pass, c1, c5)], [], [])
	off = { ..on, offline: Bool.True }
	cases = [
		("everything is wrong: the condition", go(off, all_bad, [bot]), Skip(Off(Offline))),
		("filter 1 first", go(on, all_bad, [bot]), Skip(NotProbed)),
		("filter 2 next", go(on, { ..all_bad, origin: Probed }, [bot]), Skip(Kind)),
		("filter 3 next", go(on, { ..all_bad, origin: Probed, probe: Unit }, [bot]), Skip(Compiler)),
		("filter 4 next", go(on, { ..all_bad, origin: Probed, probe: Unit, compiler: { id: c2, recorded: Bool.True } }, [bot]), Skip(NotInAnswer)),
		("filter 5 next", go(on, { ..all_bad, origin: Probed, probe: Unit, compiler: { id: c2, recorded: Bool.True } }, [answer([art("H9")], [run("H9", "any", Bot, Pass, c1, c5)], [], [])]), Skip(BotRow)),
		("filter 6 next", go(on, { ..all_bad, origin: Probed, probe: Unit, compiler: { id: c2, recorded: Bool.True }, target: "x64musl" }, [answer([art("H9")], [], [], [])]), Skip(Result)),
		("filter 7 last", go(on, { ..all_bad, origin: Probed, probe: Unit, compiler: { id: c2, recorded: Bool.True }, target: "x64musl", outcome: Pass, machine_error: Bool.False }, [answer([art("H9")], [], [], [])]), Skip(Target)),
	]
	wrong(cases) == []
}

# R-SH3, R-TF7: the row. The key is (hash, nightly, target) with the real target of a build: a smoke build has the key (platform hash, nightly, target), the build of a tool app the key (app hash, nightly, target). `nightly` is the compiler id.
# `talon_version` and `queued_at` are as given. A queued fact holds no error text (the row type has no such member).
expect {
	typed = answer([art("H1"), plat, happ], [], [], [])
	smoke = go(on, { ..good, probe: Smoke, hash: "HP", target: "x64musl", outcome: Fail }, [typed])
	tool = go(on, { ..good, probe: ToolApp({ indexed_app: Bool.True, changed: Bool.False, git_ref: Bool.False }), hash: "HA", target: "arm64mac", outcome: Crash }, [typed])
	smoke == Queue({ hash: "HP", nightly: c2, target: "x64musl", result: Fail, talon_version: version, queued_at: at })
		and tool == Queue({ hash: "HA", nightly: c2, target: "arm64mac", result: Crash, talon_version: version, queued_at: at })
}

# R-SH4, R-TF7: the cap is 10,000 rows (first guess). The line of a row has the 7 columns of R-TF7 in order, `seq` first, and the `result` word of `Db.outcome_word`; the reverse reads it back.
# A line with a wrong word count, a `seq` that is not a number or an unknown result word is `BadLine`.
expect {
	r = { hash: "H1", nightly: c2, target: "any", result: Fail, talon_version: version, queued_at: at }
	line = "7\tH1\t${c2}\tany\tfail\t${version}\t${at}"
	back = |text| Db.queue_of(text)
	Db.queue_cap == 10000
		and Db.queue_line({ seq: 7, row: r }) == line
			and back(line) == Ok({ seq: 7, row: r })
				and back(Db.queue_line({ seq: 12345, row: { ..r, result: Pass } })) == Ok({ seq: 12345, row: { ..r, result: Pass } })
					and back(Db.queue_line({ seq: 1, row: { ..r, result: Crash } })) == Ok({ seq: 1, row: { ..r, result: Crash } })
						and back("7\tH1\t${c2}\tany\tfail\t${version}") == Err(BadLine)
							and back("7\tH1\t${c2}\tany\tfail\t${version}\t${at}\textra") == Err(BadLine)
								and back("x\tH1\t${c2}\tany\tfail\t${version}\t${at}") == Err(BadLine)
									and back("7\tH1\t${c2}\tany\tmaybe\t${version}\t${at}") == Err(BadLine)
										and back("") == Err(BadLine)
}

# R-SH4, R-CC8, R-TF3 (proposal, TW24, as `Share.clear_err`): the failure of the `Queue` write. A busy file and any other failure are a warning (the queue never changes the exit code, R-SH4). A newer file is `Db.on_err` for a write (exit 19).
expect {
	path = "$HOME/.cache/roc/talon/compat.db"
	too_new = match ShareQueue.err({ err: TooNew(2), path }) {
		Stop(fail) => fail == Fail.new(Input, "${path} has format 2. This tln writes format 1. Run: tln tool update talon")
		Warn(_) => Bool.False
	}
	busy = ShareQueue.err({ err: Busy, path }) == Warn("compat.db is busy: the shared results are not queued")
	failed = ShareQueue.err({ err: Failed("disk full"), path }) == Warn("cannot use ${path} (disk full): the shared results are not queued")
	too_new and busy and failed
}
