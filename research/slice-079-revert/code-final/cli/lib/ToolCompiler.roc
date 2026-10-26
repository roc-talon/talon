import Answer
import BuildSkip
import Compiler
import Consent
import Db
import Facts
import Fail
import Mode
import Pin
import Probe
import Prompt
import Roots
import Text
import ToolInstall
import Toolchain

## The pure decisions of the compiler choice of `tln tool install` (slice 047, CLI 6.4: R-T13 to R-T21, R-NI8, R-PP2 option 2). Part A (TESTING.md 2.2). The command code is `ToolCompilerFlow` (the evidence, the prompt) and `ToolTry` (option 2). The texts are
## proposals (R-OUT2, TW24): the human accepts or changes them at the review.
##
## ```mermaid
## flowchart TD
##     A["the pin is installed (ToolInstall.compiler): use it (R-T12)"] --> Z["build"]
##     B["the pin is missing"] --> C["evidence: an installed release has a recorded build pass for the closure (R-T13)"]
##     C -->|"found"| Z
##     C -->|"none"| D{"decide: flags, mode (R-T14 to R-T16)"}
##     D -->|"Download"| E["option 1: download the pin (R-T6)"] --> Z
##     D -->|"TryInstalled"| F["option 2: checks in one round, then builds in order (R-T17 to R-T19, R-PP2)"]
##     D -->|"Ask"| G["the prompt R-NI8: 1, 2, 3"]
##     D -->|"Stop"| X["exit 13"]
##     G --> E
##     G --> F
##     G -->|"3"| X
##     F -->|"a build passed"| Z
##     F -->|"all failed (R-T20)"| H["the prompt again with options 1 and 3, and the list"]
##     H --> E
##     H -->|"3, or no person"| X
## ```
ToolCompiler :: [].{

	## What the compiler step knows (the facts of the steps 2 to 8 of `ToolFlow`). `bundle` is the hash of the app bundle (the source of the tool, R-T10). `hashes` are the hashes of the release URL entries of the header, in header order (D13 of slice 046: the platform first).
	## `pf` is the hash of the platform (`Err(None)` for a path entry or a foreign URL: then the build has no key, `BuildSkip.pf_hash`). `roc` is `--roc`. `timeout` is `probe.timeout` in seconds (R-T18: `Probe.settings` of `config.toml`).
	## Slice 079 (R-T30, Q-A1): `selected` is the compiler that the command selects (`Fetch.selected`, `ToolBuild.Facts.selected`: the `default-roc` of `config.toml`), `""` for none. The try of R-T30 step 3 starts with it, when it is installed.
	Run : { env : List((Str, Str)), roots : Roots, now : U64, target : Str, name : Str, version : Str, bundle : Str, pin : Try(Str, [NoPin]), pf : Try(Str, [None]), hashes : List(Str), roc : [Auto, Pinned, Installed], timeout : U64, selected : Str }

	## What one build of a release gave (the build of the `roc build` probe of `ToolFlow.attempt!`): the class of the result, its errors (`Probe.errors`) and the paths of the attempt (`ToolInstall.layout`: the output is in `layout.output`).
	Attempt : { class : Probe.Class, errors : List(Probe.Err), layout : ToolInstall.Layout }

	## One release that option 2 tried and that gave no build (R-T20): `stage` is the step that failed, `class` its result, `title` the title of the first error (`Probe.Err.title`).
	Tried : { id : Str, stage : [Check, Build], class : Probe.Class, title : Try(Str, [None]) }

	## What `decide` gives. `Download`: option 1, with no prompt. `TryInstalled`: option 2, with no prompt. `Ask`: the prompt R-NI8 (the mode is interactive). `NeedTty`: the caller asks the terminal (`Mode.with_tty`, R-HF1) and calls again. `Stop(fail)`: exit 13.
	Want : [Download, TryInstalled, Ask, NeedTty, Stop(Fail)]

	## R-T17, R-EP4 (P1: no registry, so no release is swept and each release is an epoch of its own, so no release is "in the epoch of the pin" and the pin is not installed here): the releases that option 2 tries and that the evidence pass reads, from the
	## installed ids of `Launch.toolchains!`. A local build (`git-<name>`, `link-<name>`, `copy-<name>`, `Compiler.kind` `Local`) is not a release and is dropped. The others are ordered newer before older (`Pin.order` with no times: the day of a nightly tag, then the tag text; a release version
	## has no day, so it is older than each nightly, and two versions are ordered by `Semver`). The result has no repeat.
	candidates : List(Str) -> List(Str)
	candidates = |installed| Text.sorted_unique(installed)
		.keep_if(|id| Compiler.kind(id) != Local)
		.sort_with(|x, y| Pin.order({ a: y, b: x, times: [] }))

	## R-T13, R-T21, R-BS2: the digest of the closure of a tool, for the key of a build fact (`BuildSkip.digest`). The closure is the hash of the app bundle and the `hashes` of its header (D-E1 of the slice file). The order and the repeats do not matter.
	digest : { bundle : Str, hashes : List(Str) } -> Str
	digest = |facts| BuildSkip.digest(facts.hashes.append(facts.bundle).map(|hash| { hash, path: "" }))

	## R-T13 (D-E1): the keys of the `db_query!` of the evidence pass. One key for each id: (hash of the platform, the id, `target`, as `BuildSkip.key`). `pf` is `Err(None)`: no key, so no evidence.
	evidence_keys : { pf : Try(Str, [None]), target : Str, ids : List(Str) } -> List(Db.Key)
	evidence_keys = |facts| match facts.pf {
		Ok(hash) => facts.ids.map(|id| { hash, nightly: id, target: facts.target })
		Err(None) => []
	}

	## R-T13, R-T17 (D-E1, D-E2): the release that has a recorded pass for this closure, or none. `ids` are the `candidates`. The first id, in that order, for which `BuildSkip.decide` says `Skip` is the result: a row of the key (platform hash, id, target) with the
	## `closure` of `digest` and the outcome `Pass`, and no `Fail`, `Hang` or `Crash` row of that digest. A check row, a row of another digest, of another id or of another target never counts. `facts` are the rows that the query for `evidence_keys` gave.
	evidence : { ids : List(Str), pf : Try(Str, [None]), target : Str, digest : Str, facts : List(Db.Fact) } -> Try(Str, [None])
	evidence = |run| match run.pf {
		Err(None) => Err(None)
		Ok(hash) => {
			recorded = |id| match BuildSkip.decide({ facts: run.facts, key: { hash, nightly: id, target: run.target }, digest: run.digest }) {
				Skip => Bool.True
				Build => Bool.False
			}
			match run.ids.find_first(recorded) {
				Ok(id) => Ok(id)
				Err(_) => Err(None)
			}
		}
	}

	## R-T30 step 3, R-T17, Q-A1 (slice 079): the installed releases that the try runs, in the order of the try. `ids` are the `candidates` (R-T17 order: newer before older, no local build). `selected` is the compiler that the command selects (`""` for none).
	## The first row that holds wins:
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `roc` is `Pinned` (`--roc pinned` skips step 3) | `[]` |
	## | 2 | `selected` is one of `ids` (R-CV1: the other tag form of the same nightly is the same release; the result has the name that `ids` has) | `selected` first, then the other `ids` in their order |
	## | 3 | Any other case (nothing is selected, or the selected compiler is not installed or is a local build) | `ids` as they are |
	##
	## A selected local build (`link-`, `copy-`, `git-`) is never tried (decided 2026-10-26, R-NS6, R-T5: `ids` has no local build, so it is not in the list). `--roc installed` is the same as `Auto` here (the flag changes what follows a failed try, not the try).
	try_order : { ids : List(Str), selected : Str, roc : [Auto, Pinned, Installed] } -> List(Str)
	try_order = |facts| match facts.roc {
		Pinned => []
		_ => match facts.ids.find_first(|id| facts.selected != "" and Pin.same_id(id, facts.selected)) {
			Ok(first) => facts.ids.keep_if(|id| id != first).prepend(first)
			Err(_) => facts.ids
		}
	}

	## R-T30, R-SO2, R-SO6, R-SO7, R-SO10 (slice 079, Q3 of the review): the compiler that the tool command selects (`Run.selected`, `ToolBuild.Facts.selected`). A tool has no project, so the ranks 3 to 5 do not apply. The first row that holds wins:
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `env` (`ROC_TOOLCHAIN`, rank 2) is not empty | `env` |
	## | 2 | `default` (`default-roc` of `config.toml`, rank 6) is not empty | `default` |
	## | 3 | `path` is `Ok(id)`: the id of the `roc` on `PATH` (rank 7, `OnPath.file!`) | `id` |
	## | 4 | Any other case | `""` (no compiler is selected, R-SO14) |
	##
	## A selected id that is not an installed nightly or release (a `PATH` `roc` with another id is a local build, R-SO10) selects a compiler (so `sets_default` is false and no default is set) but `try_order` never tries it. A `PATH` `roc` with a nightly or release id is tried first when a toolchain dir has that id.
	selected_of : { env : Str, default : Str, path : Try(Str, [NoCompiler]) } -> Str
	selected_of = |facts| if !facts.env.is_empty() {
		facts.env
	} else if !facts.default.is_empty() {
		facts.default
	} else {
		facts.path ?? ""
	}

	## R-T30 (4), R-SO14, R-SO15, R-SO23 (slice 079): does a download of step 4 become `default-roc`? Yes when no compiler is selected (`selected` is `""`) and no default is set now (`default_now` is `""`: the unpack of the app bundle can have set it, R-FE4, so the flow reads `config.toml` again before step 4).
	## The same test decides the prompt line `It becomes the default compiler.` and the call of `RocInstall.first_default!` after the download. `tool update` and `tool rebuild` use it too (R-NI17: the first compiler that they download).
	sets_default : { selected : Str, default_now : Str } -> Bool
	sets_default = |facts| facts.selected.is_empty() and facts.default_now.is_empty()

	## R-T16, R-T20, R-NM5 (slice 079, a proposal, TW24): the failure of step 4 when `decide` gave `Stop(fail)` (no person and no flag, `TALON_AUTO_INSTALL=no`, a pin that cannot be downloaded) after the try. With no release tried (`tried` is empty: no release is installed, or `--roc pinned`): `fail` as it is.
	## With releases tried: the same `kind` and `details`, and the message `no installed compiler release built <name> <version> (<tried_text>; <tried_text>), and <fail.message>`. The stop text names the flags of the command (a command that is not `tool install` has other flags), so it is kept. Each `decide` stop text starts with `the compiler <id> is not installed`.
	after_try : { fail : Fail, name : Str, version : Str, pin : Str, tried : List(Tried) } -> Fail
	after_try = |facts| if facts.tried.is_empty() {
		facts.fail
	} else {
		list = Str.join_with(facts.tried.map(ToolCompiler.tried_text), "; ")
		{ ..facts.fail, message: "no installed compiler release built ${facts.name} ${facts.version} (${list}), and ${facts.fail.message}" }
	}

	## R-T14 to R-T16, R-NM5, R-NM9, R-DL5 (D-E3): what the command does when the pin is not installed and no installed release has evidence. `id` is the pin. `auto` is `TALON_AUTO_INSTALL` (`Consent.auto_install`), `yes` is `--yes`, `roc` is `--roc`.
	## `mode` is the mode of the run (`Mode.from_env`, then `Mode.with_tty` for `NeedTty`). The first row that holds wins:
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `roc` is `Installed` | `TryInstalled` (option 2: R-T16). It wins over `auto`, `yes` and the mode. No download is made, so `TALON_AUTO_INSTALL=no` does not stop it. |
	## | 2 | `Consent.required_want` is `Install` (`roc` is `Pinned`, or `yes`, or `auto` is `Yes`) | `Download` (option 1, the default, R-NM9) |
	## | 3 | It is `Ask` | `Ask` |
	## | 4 | It is `NeedTty` | `NeedTty` |
	## | 5 | Any other result (`Refuse`: the pin is not a nightly tag, `AutoNo`, `NeedsConsent`: no person and no answer) | `Stop` with the failure of `ToolInstall.want` (exit 13: `ToolInstall.consent_stop`, `Consent.download_refused`, or `the compiler <id> is not installed. Run: tln roc install <id>.`) |
	decide : { id : Str, roc : [Auto, Pinned, Installed], auto : [Ask, Yes, No], yes : Bool, mode : Mode } -> Want
	decide = |run| match run.roc {
		Installed => TryInstalled
		_ => {
			flag = match run.roc {
				Pinned => Ok(Yes)
				_ => Err(NoFlag)
			}
			match Consent.required_want({ id: run.id, auto: run.auto, mode: run.mode, yes: run.yes, flag }) {
				Install => Download
				Ask => Ask
				NeedTty => NeedTty
				_ => match ToolInstall.want({ id: run.id, roc: run.roc, auto: run.auto, yes: run.yes }) {
					Install => Download
					Stop(fail) => Stop(fail)
				}
			}
		}
	}

	## R-NI8, R-T14, R-T15, R-T20, R-T30, R-NR2, R-NR6 (slice 079): the prompt. Kind `Required(["--roc pinned", "--roc installed", "TALON_AUTO_INSTALL=yes"])` (`Prompt.decide` adds `--yes`), options 1 and 3 (option 2 is gone: the try ran before the prompt, R-T30 step 3), the interactive default is option 1.
	## `size` is the asset size of the pin in bytes (`Toolchain.size_text`). `tried` are the releases that the try gave no build, in order (empty: nothing was tried, R-T15). `becomes_default` is `ToolCompiler.sets_default` (the proposal of R-T30).
	##
	## | Field | Text |
	## | --- | --- |
	## | `id` | `tool-compiler` |
	## | `question` | the lines below, ending with `Select an option` (`Prompt.text` adds ` [1-3, default 1] `) |
	## | `subject` | `the compiler <pin>` |
	## | `answer_line` | `Option(1)`: `downloading <pin> (<size>)`, and `, the default compiler` after it when `becomes_default`. Any other answer: `cancelled` |
	##
	## ```text
	## acme/foo 1.4.0 was tested with compiler release nightly-2026-10-09-258ab27. It is not installed.
	## <only with becomes_default> It becomes the default compiler.
	## <only with tried> No installed compiler release built it:
	## <only with tried>   <ToolCompiler.tried_text of each, in order>
	##
	##   1) Download nightly-2026-10-09-258ab27 (70 MB)    [default]
	##   3) Cancel
	##
	## Select an option
	## ```
	prompt : { name : Str, version : Str, pin : Str, size : U64, tried : List(Tried), becomes_default : Bool } -> Prompt
	prompt = |facts| {
		size = Toolchain.size_text(facts.size)
		default_line = if facts.becomes_default "\nIt becomes the default compiler." else ""
		failed = if facts.tried.is_empty() "" else "\nNo installed compiler release built it:${facts.tried.fold("", |acc, t| "${acc}\n  ${ToolCompiler.tried_text(t)}")}"
		Prompt.{
			id: "tool-compiler",
			kind: Required(["--roc pinned", "--roc installed", "TALON_AUTO_INSTALL=yes"]),
			shape: Options(3),
			default: Option(1),
			question: "${facts.name} ${facts.version} was tested with compiler release ${facts.pin}. It is not installed.${default_line}${failed}\n\n  1) Download ${facts.pin} (${size})    [default]\n  3) Cancel\n\nSelect an option",
			subject: "the compiler ${facts.pin}",
			answer_line: |answer| match answer {
				Option(1) => "downloading ${facts.pin} (${size})${if facts.becomes_default ", the default compiler" else ""}"
				_ => "cancelled"
			},
		}
	}

	## R-NI8 (slice 079): is the answer one of the options that the prompt shows? Option 1 and option 3. Any other answer (option 2 is gone, R-T30) is not allowed: the command asks again.
	allowed : { answer : Answer } -> Bool
	allowed = |facts| match facts.answer {
		Option(1) | Option(3) => Bool.True
		_ => Bool.False
	}

	## R-NI8, R-NM6 (D-E4): the line on stderr when option 2 starts with no person to ask (`--roc installed`): `trying <n> installed compiler releases` (`release` for 1).
	trying_line : U64 -> Str
	trying_line = |count| "trying ${count.to_str()} installed compiler ${if count == 1 "release" else "releases"}"

	## R-NI8 option 3: the failure when the person cancels. Kind `Consent` (exit 13), a proposal: `the compiler <pin> is not installed. Nothing was downloaded and nothing was built. Run: tln roc install <pin>, pass --roc pinned, or set TALON_AUTO_INSTALL=yes.`
	declined : Str -> Fail
	declined = |pin| Fail.new(Consent, "the compiler ${pin} is not installed. Nothing was downloaded and nothing was built. Run: tln roc install ${pin}, pass --roc pinned, or set TALON_AUTO_INSTALL=yes.")

	## R-T13: the line on stderr when the build uses a release that is not the pin (an evidence pass, or option 2). The text of the design: `built with <id> (pin: <pin>)`.
	built_line : { id : Str, pin : Str } -> Str
	built_line = |facts| "built with ${facts.id} (pin: ${facts.pin})"

	## R-T18: the probe of the check of option 2: `roc check main.roc` in the dir of the app bundle (`ToolInstall.Layout.dir`), with the release `id`. `program` and `env` are those of `Launch.program!` and `Launch.child_env!`. The timeout is `probe.timeout`
	## (`Run.timeout`). The weight is `Probe.weight(Check)`.
	check_spec : { id : Str, program : Str, env : List((Str, Str)), dir : Str, timeout : U64 } -> Probe.Spec
	check_spec = |facts| {
		compiler: facts.id,
		program: facts.program,
		args: Probe.args({ command: Check, file: "main.roc" }),
		dir: facts.dir,
		env: facts.env,
		timeout: facts.timeout,
		weight: Probe.weight(Check),
	}

	## R-T21, R-P4, R-P3 (D-E1): the fact of the check of option 2: `Facts.of_probe` for a check of the bundle: the hash of the app bundle, the id, the target `any`, no closure. `NoFact` (a download error, a signal from outside): no row.
	check_row : { bundle : Str, id : Str, target : Str, class : Probe.Class, errors : List(Probe.Err) } -> Try(Db.Fact, [NoFact])
	check_row = |facts| Facts.of_probe({ hash: facts.bundle, nightly: facts.id, host: facts.target, command: Check, class: facts.class, errors: facts.errors, closure: "" })

	## R-T21, R-BS2 (D-E1): the fact of the build of option 2: `BuildSkip.row` for the key (platform hash, id, target) and the `digest` of the closure. `pf` is `Err(None)`: no key, no row (`NoKey`). `NoFact`: no row.
	build_row : { pf : Try(Str, [None]), id : Str, target : Str, digest : Str, class : Probe.Class, errors : List(Probe.Err) } -> Try(Db.Fact, [NoFact, NoKey])
	build_row = |facts| match facts.pf {
		Err(None) => Err(NoKey)
		Ok(hash) => match BuildSkip.row({ key: { hash, nightly: facts.id, target: facts.target }, digest: facts.digest, class: facts.class, errors: facts.errors }) {
			Ok(row) => Ok(row)
			Err(NoFact) => Err(NoFact)
		}
	}

	## R-T20: the record of one failed release. `errors` are the errors of the probe (`Probe.errors`); the title of the first one is the `title`.
	tried_of : { id : Str, stage : [Check, Build], class : Probe.Class, errors : List(Probe.Err) } -> Tried
	tried_of = |facts| {
		title = match facts.errors {
			[first, ..] => Ok(first.title)
			[] => Err(None)
		}
		{ id: facts.id, stage: facts.stage, class: facts.class, title }
	}

	## R-T20: the line of one failed release, with the first error line. `<stage>` is `check` or `build`.
	##
	## | Class | Text |
	## | --- | --- |
	## | `Fail(_)` with a title | `<id>: <stage> failed: <title>` |
	## | `Fail(_)` with no title | `<id>: <stage> failed` |
	## | `Hang` | `<id>: <stage> did not end in time` |
	## | `Crash(text)`, `NoFact(text)` | `<id>: <stage> gave no result: <text>` |
	## | `Pass` | `<id>: <stage> passed` (a build that made no output file) |
	tried_text : Tried -> Str
	tried_text = |t| {
		stage = match t.stage {
			Check => "check"
			Build => "build"
		}
		match t.class {
			Fail(_) => match t.title {
				Ok(title) => "${t.id}: ${stage} failed: ${title}"
				Err(None) => "${t.id}: ${stage} failed"
			}
			Hang => "${t.id}: ${stage} did not end in time"
			Crash(text) | NoFact(text) => "${t.id}: ${stage} gave no result: ${text}"
			Pass => "${t.id}: ${stage} passed"
		}
	}

	## R-T20, R-T16, R-NM5 (D-E5): the failure of a run with no person after option 2 (`--roc installed`, or no person to ask the prompt again). Kind `Consent` (exit 13). The text (a proposal) names each release and the flags:
	## `no installed compiler release built <name> <version> (<tried_text>; <tried_text>). The compiler <pin> is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes.` With no release tried: `no compiler release is installed to try for <name> <version>. The compiler <pin> is not installed. Pass ...`.
	all_failed : { name : Str, version : Str, pin : Str, tried : List(Tried) } -> Fail
	all_failed = |facts| {
		flags = "The compiler ${facts.pin} is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes."
		what = "${facts.name} ${facts.version}"
		if facts.tried.is_empty() {
			Fail.new(Consent, "no compiler release is installed to try for ${what}. ${flags}")
		} else {
			Fail.new(Consent, "no installed compiler release built ${what} (${Str.join_with(facts.tried.map(ToolCompiler.tried_text), "; ")}). ${flags}")
		}
	}
}
