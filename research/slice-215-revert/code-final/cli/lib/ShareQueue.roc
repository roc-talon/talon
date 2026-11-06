import records.Closure as Wire
import Compiler
import Db
import Fail
import Fx
import Matrix
import Net
import Nightlies
import PinOrder
import Roots
import Share

## The share queue (slice 215; CLI 1 R-SH2, R-SH3, R-SH4, R-EV26; R-TF7). Part A (pure): which facts go into the queue. Part C: the write of the rows to `share_queue` of `compat.db` (one `db_write!`).
## The send is slice 216. A command that sends a registry request calls these functions: that call is slice 206b and later.
##
## `admit` applies R-SH2 and the 6 filters of R-SH3 to one fact, in this order. The first condition or filter that is false gives the reason (the same reading as `Share.state` for the 5 conditions, slice 213 D3):
##
## | # | Test | Reason when false | Rule |
## | --- | --- | --- | --- |
## | 0 | `Share.state` of `sharing` is `On` (the 5 conditions of R-SH2: `share = true`, a registry URL, no `--offline`, `DO_NOT_TRACK`, `CI`) | `Off(reason)`, the condition of `Share.Reason` | R-SH2, R-EV26 |
## | 1 | `origin` is `Probed`: the result of a probe that this command ran (not an old fact of `compat.db`, a fact from the registry, an inferred fact) | `NotProbed` | R-SH3 filter 1 |
## | 2 | `probe` is `Unit` or `Smoke`, or `ToolApp` with its 3 conditions true | `Kind` | R-SH3 filter 2 |
## | 3 | `compiler.id` is a nightly tag (`Compiler.kind` gives `Nightly`; a release `X.Y.Z` is refused, Design Q431) and `compiler.recorded` (the sha256 of its asset is in `compat.db`, R-CV6) | `Compiler` | R-SH3 filter 3 |
## | 4 | `hash` is in the set of hashes of `answers`: the `hash` of each `artifacts` row and of each `releases` row. Not a dep hash, a `platform_hash`, the hashes of `unknown`, `runs`, `nearest` or `hints` (Design Q432) | `NotInAnswer` | R-SH3 filter 4 |
## | 5 | No `bot` row of `answers` has the key (`hash`, `compiler.id`, `target`) (`Matrix.rows` with `domain`, the compiler compared with `PinOrder.same_id`) | `BotRow` | R-SH3 filter 5, R-EF3 |
## | 6 | `outcome` is `Pass`, `Fail` or `Crash`, and a `Fail` has no `machine_error` | `Result` | R-SH3 filter 6 |
## | 7 | `target` is one that the Worker takes for the kind of `hash`: `any` for a `Package`; `any` or a name of its `target_names` for a `Platform`; any target for an `App`. The kind comes from the first `artifacts` row of the hash, else from its `headers` entry (Design Q450), else the fact fails | `Target` | R-SH3 filter 7, Design Q432 |
##
## The row: `hash`, `nightly` (`compiler.id`), `target` and `outcome` of the fact, `talon_version` and `queued_at` as given. A queued fact holds no error text (R-SH3).
ShareQueue :: [].{

	## The facts of R-SH2: the same record as the input of `Share.state`.
	Sharing : { share : Try(Bool, [Unset]), registry : Net.Registry, offline : Bool, env : List((Str, Str)) }

	## Where the result came from (R-SH3 filter 1).
	Origin : [Probed, Stored, Registry, Inferred]

	## What the probe was (R-SH3 filter 2). `ToolApp` is the build of a tool app (R-T21): `indexed_app` is true when the app is a `github.com` release bundle that the registry indexes with the kind `app`,
	## `changed` is true when the build used a `--resolve` or an override of the header of the bundle, `git_ref` is true for a build from a git ref (`--git`). The other kinds are stopped.
	Kind : [Unit, Smoke, ToolApp({ indexed_app : Bool, changed : Bool, git_ref : Bool }), Baseline, WholeApp, AppBuild, ProjectFile, BundleFile]

	## One fact, as a command has it after a probe. `compiler.recorded`: the first-seen sha256 of the compiler asset is recorded (R-CV6). `machine_error`: the error is a machine error (R-SM7: a constant list, slice 218).
	## `target` is the real target of a build or a smoke build, `any` for a unit check.
	Fact : { origin : Origin, probe : Kind, compiler : { id : Str, recorded : Bool }, hash : Str, target : Str, outcome : Db.Outcome, machine_error : Bool }

	## The reason of a skip. Each is the first false test of the table above.
	Why : [Off(Share.Reason), NotProbed, Kind, Compiler, NotInAnswer, BotRow, Result, Target]

	## The decision for one fact. See the table above.
	## `headers` (Design Q450, filter 7): the kind and the names that the caller read from the header of `packages/<hash>/main.roc` (R-DI7, Registry R-RE20) for a hash with no `artifacts` row in `answers` (a release row only). `names` are the target names of a platform header (empty for the other kinds). One entry for each hash that has a file; a hash with no entry has no file.
	## Filter 7 takes the kind and the names from the first `artifacts` row of the hash, else from its `headers` entry, else the fact fails with `Target` (a guess could make the whole hint request 400). The flow that reads the files is the caller of `admit` (the command code of the probe flows, slice 206b and later).
	admit : { sharing : ShareQueue.Sharing, fact : ShareQueue.Fact, answers : List(Wire.Answer), headers : List({ hash : Str, kind : [Package, Platform, App], names : List(Str) }), domain : List(Nightlies.Release), talon_version : Str, queued_at : Str } -> [Queue(Db.Queued), Skip(ShareQueue.Why)]
	admit = |run| {
		fact = run.fact
		hashes = run.answers.join_map(|a| a.artifacts.map(|x| x.hash).concat(a.releases.map(|x| x.hash)))
		bots = run.answers
			.join_map(|a| Matrix.rows({ runs: a.runs, nearest: a.nearest, domain: run.domain }))
			.keep_if(|r| r.source == Bot)
		bot_row = bots.any(|r| r.hash == fact.hash and r.target == fact.target and PinOrder.same_id(r.nightly, fact.compiler.id))
		from_rows = run.answers.join_map(|a| a.artifacts).keep_if(|x| x.hash == fact.hash).map(|x| { kind: x.kind, names: x.target_names })
		from_headers = run.headers.keep_if(|x| x.hash == fact.hash).map(|x| { kind: x.kind, names: x.names })
		target_ok = match from_rows.concat(from_headers) {
			[] => Bool.False
			[first, ..] => match first.kind {
				Package => fact.target == "any"
				Platform => fact.target == "any" or first.names.contains(fact.target)
				App => Bool.True
			}
		}
		kind_ok = match fact.probe {
			Unit | Smoke => Bool.True
			ToolApp({ indexed_app, changed, git_ref }) => indexed_app and !changed and !git_ref
			_ => Bool.False
		}
		result_ok = match fact.outcome {
			Hang => Bool.False
			Fail => !fact.machine_error
			_ => Bool.True
		}
		why = match Share.state(run.sharing) {
			Off(reason) => Err(Off(reason))
			On => if fact.origin != Probed {
				Err(NotProbed)
			} else if !kind_ok {
				Err(Kind)
			} else if !(Compiler.kind(fact.compiler.id) == Nightly and fact.compiler.recorded) {
				Err(Compiler)
			} else if !hashes.contains(fact.hash) {
				Err(NotInAnswer)
			} else if bot_row {
				Err(BotRow)
			} else if !result_ok {
				Err(Result)
			} else if !target_ok {
				Err(Target)
			} else {
				Ok({})
			}
		}
		match why {
			Err(reason) => Skip(reason)
			Ok(_) => Queue({ hash: fact.hash, nightly: fact.compiler.id, target: fact.target, result: fact.outcome, talon_version: run.talon_version, queued_at: run.queued_at })
		}
	}

	## What a command does with a failed `Queue` write (proposal, TW24, as `Share.clear_err`). `TooNew` is `Db.on_err` for a write (exit 19). A busy file is the warning
	## `compat.db is busy: the shared results are not queued`. Any other failure is `cannot use <path> (<text>): the shared results are not queued`. The text has no `warning: ` and no line end.
	err : { err : Db.Err, path : Str } -> [Stop(Fail), Warn(Str)]
	err = |facts| match facts.err {
		TooNew(_) => match Db.on_err({ err: facts.err, what: Write, path: facts.path }) {
			Stop(fail) => Stop(fail)
			Warn(text) => Warn(text)
		}
		Busy => Warn("compat.db is busy: the shared results are not queued")
		Failed(text) => Warn("cannot use ${facts.path} (${text}): the shared results are not queued")
	}

	## The write of the rows (R-SH4, R-TF7). No row: no call. Else one `db_write!` with `Queue({ rows, cap: Db.queue_cap })` and `Db.Open` of `Roots.item(roots, CompatDb)`.
	## `Ok`: `Queued`. `Err(Busy)` and `Err(Failed)`: the line `warning: <err text>` on stderr (`fx.err!`), and the result is `Lost` (the rows are not queued, the command goes on: R-SH4, the queue never changes the exit code). `Err(TooNew)`: `Err(fail)` (exit 19). No row: `Queued`, no call.
	## `cap` is a field so that a test can use a small cap: a command gives `Db.queue_cap`.
	enqueue! : Fx, { roots : Roots, rows : List(Db.Queued), cap : U64 } => Try([Queued, Lost], Fail)
	enqueue! = |fx, run| {
		if run.rows.is_empty() {
			Ok(Queued)
		} else {
			path = Roots.item(run.roots, CompatDb)
			open = { path, busy_ms: Db.busy_ms, format: Db.format }
			match fx.db_write!(open, Queue({ rows: run.rows, cap: run.cap })) {
				Ok(_) => Ok(Queued)
				Err(failed) => match ShareQueue.err({ err: failed, path }) {
					Stop(fail) => Err(fail)
					Warn(text) => {
						fx.err!("warning: ${text}\n")
						Ok(Lost)
					}
				}
			}
		}
	}
}
