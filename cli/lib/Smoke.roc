import records.Closure as Wire
import Compiler
import Db
import InitStub
import Matrix
import Nightlies
import PinOrder
import Probe

## The smoke build (slice 218; Resolution 4 R-SM1 to R-SM5, R-SM7; CLI 1 R-SH3 filters 2 and 6, R-TF7). Part A (pure): which of the built keys get a smoke build (R-SM3), the class of a smoke result (R-SM4, R-SM7, R-P3), and the smoke app (R-SM2).
## The command code (after the work of a command and before `ShareHook.send!`, only with R-SH2 true) calls these functions, `Fx.probes!` for the builds and `ShareRound.enqueue!` for the queue: no helper of its own.
##
## | Part | Does | Rule |
## | --- | --- | --- |
## | `choose` | For each built key (platform hash, nightly, target), once: the 4 conditions of R-SM3 rows 2 to 5 in order, the first false one is the reason | R-SM3 |
## | `result` | The class of the output of a smoke build: a stored `Row`, a `Machine` error (no row, not queued), or `NoFact` (no row) | R-SM4, R-SM7, R-P3, R-RC1 to R-RC4 |
## | `app_text` | The text of `main.roc` of the smoke app of a platform header (the generator of `InitStub.app_text` with the body `crash "talon smoke test"`), or `NoSmoke` | R-SM2 |
## | `machine_errors` | The list of the errors that come from the build machine, a constant of Talon (the bot has its own copy) | R-SM7 |
Smoke :: [].{

	## R-SM7: the errors of the build machine, not of the platform. The first one is `WindowsSDKNotFound` (nightly 10-06). A new one found later goes into this list.
	machine_errors : List(Str)
	machine_errors = ["WindowsSDKNotFound"]

	## Why a built key gets no smoke build: the first false condition of R-SM3, in the order of the table. `NotInstalled`: row 2. `Done`: row 3 (`compat.db` has a smoke result for the key, of any outcome). `BotRow`, `Hints`: row 4.
	## `Compiler`, `NotInAnswer`: row 5, the filters 3 and 4 of R-SH3 (a nightly tag with a recorded sha256, and the platform hash in an answer of the command).
	Why : [NotInstalled, Done, BotRow, Hints, Compiler, NotInAnswer]

	## The decision for one key. `Build`: build it. The keys come in the order of their first appearance in `built`, and a key that is in `built` more than once gives one choice (R-SM3: one build for each key).
	Choice : { key : Db.Key, verdict : [Build, Skip(Why)] }

	## R-SM3, rows 1 to 5 (the condition "only when sharing is on" is R-SH2, checked by the command before it calls this). The input is what the command knows after its work:
	##
	## | Field | Is |
	## | --- | --- |
	## | `built` | The key (platform hash, compiler id, target) of each build that the command ran or skipped (R-BS1), ladder step 3. Row 1: the `target` of the key is the target of that build, and a smoke build uses it |
	## | `installed` | The compiler ids that have a program (an installed toolchain, or the `roc` on `PATH` of that id: `Compiler.find`). Row 2: the id of the key is in it. A smoke build never downloads |
	## | `done` | The rows of the table `smoke` for these keys. Row 3: no row has the key |
	## | `recorded` | The compiler ids that have a recorded sha256 for the target of this machine (`Pinned`, R-CV6): the `recorded` of filter 3 |
	## | `answers`, `domain` | The closure answers of the command and its compilers. Row 4: no `bot` row for the key (`Matrix.rows`, the compiler compared with `PinOrder.same_id`), and no row of `hints` for the key with `pass_count` + `fail_count` + `crash_count` of 3 or more (first guess). Row 5: filter 3 (`Compiler.kind` is `Nightly` and the id is in `recorded`), then filter 4 (the hash is the `hash` of an `artifacts` row or a `releases` row of an answer) |
	##
	## The key of `done`, `bot` and `hints` rows is compared by hash and target, and the compiler with `PinOrder.same_id` (R-CV1).
	choose : { built : List(Db.Key), installed : List(Str), done : List(Db.SmokeRow), recorded : List(Str), answers : List(Wire.Answer), domain : List(Nightlies.Release) } -> List(Smoke.Choice)
	choose = |x| {
		keys = x.built.fold([], |found, k| if found.contains(k) found else found.append(k))
		hashes = x.answers.join_map(|a| a.artifacts.map(|r| r.hash).concat(a.releases.map(|r| r.hash)))
		bots = x.answers
			.join_map(|a| Matrix.rows({ runs: a.runs, nearest: a.nearest, domain: x.domain }))
			.keep_if(|r| r.source == Bot)
		hints = x.answers.join_map(|a| a.hints)
		keys.map(
			|k| {
				done = x.done.any(|r| r.hash == k.hash and r.target == k.target and PinOrder.same_id(r.nightly, k.nightly))
				bot = bots.any(|r| r.hash == k.hash and r.target == k.target and PinOrder.same_id(r.nightly, k.nightly))
				hinted = hints.any(
					|h| h.hash == k.hash and h.target == k.target and PinOrder.same_id(h.nightly, k.nightly) and h.pass_count + h.fail_count + h.crash_count >= 3,
				)
				verdict = if !x.installed.contains(k.nightly) {
					Skip(NotInstalled)
				} else if done {
					Skip(Done)
				} else if bot {
					Skip(BotRow)
				} else if hinted {
					Skip(Hints)
				} else if !(Compiler.kind(k.nightly) == Nightly and x.recorded.contains(k.nightly)) {
					Skip(Compiler)
				} else if !hashes.contains(k.hash) {
					Skip(NotInAnswer)
				} else {
					Build
				}
				{ key: k, verdict }
			},
		)
	}

	## What the command does with the output of one smoke build (`Fx.probes!`).
	##
	## | # | Output | Result | Rule |
	## | --- | --- | --- | --- |
	## | 1 | A line of stderr, with no white space at its end, is exactly `Error: <name>` for a name of `machine_errors`, whatever the exit code. Stdout is not read, a substring does not count (Design Q548) | `Machine`: no row in `smoke`, nothing queued, a later command builds the key again | R-SM7, R-SM4 |
	## | 2 | `Probe.classify` gives `Pass`, `Fail`, `Hang` or `Crash` | `Row(<that outcome>)`: a row in `smoke`, and the queue (R-SH3) | R-SM4, R-RC1 to R-RC4 |
	## | 3 | `Probe.classify` gives `NoFact` (a signal from outside, not started, no result) | `NoFact`: no row, a later command builds the key again | R-P3 |
	##
	## The first row that is true wins. A result with a machine error is `Machine` also when it would be a `Pass`, a `Fail`, a `Crash` or a `NoFact`.
	result : Probe.Output -> [Row(Db.Outcome), Machine, NoFact]
	result = |output| {
		machine = output.stderr.split_on("\n").any(
			|line| {
				text = line.trim_end()
				text.starts_with("Error: ") and Smoke.machine_errors.contains(text.drop_prefix("Error: "))
			},
		)
		if machine {
			Machine
		} else {
			match Probe.classify(output) {
				Pass => Row(Pass)
				Fail(_) => Row(Fail)
				Hang => Row(Hang)
				Crash(_) => Row(Crash)
				NoFact(_) => NoFact
			}
		}
	}

	## R-SM2: the text of `main.roc` of the smoke app of a platform. `text` is the text of the `main.roc` of the platform release (the header), `url` the URL of the platform. The text is the one of `InitStub.app_text` (`tln init --platform`, R-IN8), with one change:
	## the body of each stub is `crash "talon smoke test"` (`crash "write the app"` in `init`). `NoSmoke`: a `requires` clause that R-SM2 gives no smoke app for (a value of another type, a clause with 2 or more entries, the text is no platform header).
	app_text : { url : Str, text : Str } -> Try(Str, [NoSmoke])
	app_text = |x| match InitStub.app_text({ name: "", url: x.url, text: x.text }) {
		Ok(text) => Ok(text.replace_each("crash \"write the app\"", "crash \"talon smoke test\""))
		Err(_) => Err(NoSmoke)
	}
}
