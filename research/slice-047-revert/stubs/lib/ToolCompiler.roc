import Answer
import Db
import Fail
import Mode
import Probe
import Prompt
import Roots
import ToolInstall

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
	Run : { env : List((Str, Str)), roots : Roots, now : U64, target : Str, name : Str, version : Str, bundle : Str, pin : Try(Str, [NoPin]), pf : Try(Str, [None]), hashes : List(Str), roc : [Auto, Pinned, Installed], timeout : U64 }

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
	candidates = |_installed| crash "todo: slice 047"

	## R-T13, R-T21, R-BS2: the digest of the closure of a tool, for the key of a build fact (`BuildSkip.digest`). The closure is the hash of the app bundle and the `hashes` of its header (D-E1 of the slice file). The order and the repeats do not matter.
	digest : { bundle : Str, hashes : List(Str) } -> Str
	digest = |_facts| crash "todo: slice 047"

	## R-T13 (D-E1): the keys of the `db_query!` of the evidence pass. One key for each id: (hash of the platform, the id, `target`, as `BuildSkip.key`). `pf` is `Err(None)`: no key, so no evidence.
	evidence_keys : { pf : Try(Str, [None]), target : Str, ids : List(Str) } -> List(Db.Key)
	evidence_keys = |_facts| crash "todo: slice 047"

	## R-T13, R-T17 (D-E1, D-E2): the release that has a recorded pass for this closure, or none. `ids` are the `candidates`. The first id, in that order, for which `BuildSkip.decide` says `Skip` is the result: a row of the key (platform hash, id, target) with the
	## `closure` of `digest` and the outcome `Pass`, and no `Fail`, `Hang` or `Crash` row of that digest. A check row, a row of another digest, of another id or of another target never counts. `facts` are the rows that the query for `evidence_keys` gave.
	evidence : { ids : List(Str), pf : Try(Str, [None]), target : Str, digest : Str, facts : List(Db.Fact) } -> Try(Str, [None])
	evidence = |_run| crash "todo: slice 047"

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
	decide = |_run| crash "todo: slice 047"

	## R-NI8, R-T14, R-T15, R-T20, R-NR2, R-NR6 (D-E4): the prompt. Kind `Required(["--roc pinned", "--roc installed", "TALON_AUTO_INSTALL=yes"])` (`Prompt.decide` adds `--yes`), options 1 to 3, the interactive default is option 1. `size` is the asset size of the pin in bytes
	## (`Toolchain.size_text`). `installed` is the number of releases that option 2 can try: 0 (R-T15, and the prompt after option 2, R-T20) has no line for option 2 but keeps the numbers (`1)` and `3)`). `tried` are the releases that failed, in order (R-T20: empty for the first prompt).
	##
	## | Field | Text |
	## | --- | --- |
	## | `id` | `tool-compiler` |
	## | `question` | the lines below, ending with `Select an option` (`Prompt.text` adds ` [1-3, default 1] `) |
	## | `subject` | `the compiler <pin>` |
	## | `answer_line` | `Option(1)`: `downloading <pin> (<size>)`. `Option(2)`: `ToolCompiler.trying_line(installed)`. `Option(3)` and any other: `cancelled` |
	##
	## ```text
	## acme/foo 1.4.0 was tested with compiler release nightly-2026-10-09-258ab27. It is not installed.
	## <only with tried> No installed compiler release built it:
	## <only with tried>   <ToolCompiler.tried_text of each, in order>
	##
	##   1) Download nightly-2026-10-09-258ab27 (70 MB)    [default]
	##   2) Try the 4 installed compiler releases            <only with installed above 0, `release` for 1>
	##   3) Cancel
	##
	## Select an option
	## ```
	prompt : { name : Str, version : Str, pin : Str, size : U64, installed : U64, tried : List(Tried) } -> Prompt
	prompt = |_facts| crash "todo: slice 047"

	## R-NI8 (D-E4): is the answer one of the options that the prompt shows? Option 1 and option 3 always. Option 2 only with `installed` above 0. Any other answer is not allowed: the command asks again.
	allowed : { answer : Answer, installed : U64 } -> Bool
	allowed = |_facts| crash "todo: slice 047"

	## R-NI8, R-NM6 (D-E4): the line on stderr when option 2 starts with no person to ask (`--roc installed`): `trying <n> installed compiler releases` (`release` for 1).
	trying_line : U64 -> Str
	trying_line = |_count| crash "todo: slice 047"

	## R-NI8 option 3: the failure when the person cancels. Kind `Consent` (exit 13), a proposal: `the compiler <pin> is not installed. Nothing was downloaded and nothing was built. Run: tln roc install <pin>, pass --roc pinned, or set TALON_AUTO_INSTALL=yes.`
	declined : Str -> Fail
	declined = |_pin| crash "todo: slice 047"

	## R-T13: the line on stderr when the build uses a release that is not the pin (an evidence pass, or option 2). The text of the design: `built with <id> (pin: <pin>)`.
	built_line : { id : Str, pin : Str } -> Str
	built_line = |_facts| crash "todo: slice 047"

	## R-T18: the probe of the check of option 2: `roc check main.roc` in the dir of the app bundle (`ToolInstall.Layout.dir`), with the release `id`. `program` and `env` are those of `Launch.program!` and `Launch.child_env!`. The timeout is `probe.timeout`
	## (`Run.timeout`). The weight is `Probe.weight(Check)`.
	check_spec : { id : Str, program : Str, env : List((Str, Str)), dir : Str, timeout : U64 } -> Probe.Spec
	check_spec = |_facts| crash "todo: slice 047"

	## R-T21, R-P4, R-P3 (D-E1): the fact of the check of option 2: `Facts.of_probe` for a check of the bundle: the hash of the app bundle, the id, the target `any`, no closure. `NoFact` (a download error, a signal from outside): no row.
	check_row : { bundle : Str, id : Str, target : Str, class : Probe.Class, errors : List(Probe.Err) } -> Try(Db.Fact, [NoFact])
	check_row = |_facts| crash "todo: slice 047"

	## R-T21, R-BS2 (D-E1): the fact of the build of option 2: `BuildSkip.row` for the key (platform hash, id, target) and the `digest` of the closure. `pf` is `Err(None)`: no key, no row (`NoKey`). `NoFact`: no row.
	build_row : { pf : Try(Str, [None]), id : Str, target : Str, digest : Str, class : Probe.Class, errors : List(Probe.Err) } -> Try(Db.Fact, [NoFact, NoKey])
	build_row = |_facts| crash "todo: slice 047"

	## R-T20: the record of one failed release. `errors` are the errors of the probe (`Probe.errors`); the title of the first one is the `title`.
	tried_of : { id : Str, stage : [Check, Build], class : Probe.Class, errors : List(Probe.Err) } -> Tried
	tried_of = |_facts| crash "todo: slice 047"

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
	tried_text = |_t| crash "todo: slice 047"

	## R-T20, R-T16, R-NM5 (D-E5): the failure of a run with no person after option 2 (`--roc installed`, or no person to ask the prompt again). Kind `Consent` (exit 13). The text (a proposal) names each release and the flags:
	## `no installed compiler release built <name> <version> (<tried_text>; <tried_text>). The compiler <pin> is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes.` With no release tried: `no compiler release is installed to try for <name> <version>. The compiler <pin> is not installed. Pass ...`.
	all_failed : { name : Str, version : Str, pin : Str, tried : List(Tried) } -> Fail
	all_failed = |_facts| crash "todo: slice 047"
}
