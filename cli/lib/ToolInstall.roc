import Age
import Args
import Clock
import Consent
import Fail
import Index
import JsonDoc
import Probe
import Ranges
import Ref
import Roots
import Scope
import Selector
import Setup
import Temp
import Text
import ToolsJson

## The pure decisions of `tln tool install` for a release (slice 046, CLI 6.4: R-CM16, R-T1 to R-T6, R-T8 to R-T12, R-T26 to R-T28, R-SE8, R-ST15, R-LY2, R-LY3, R-CC6). Part A (TESTING.md 2.2). The command code is `ToolFlow`.
## The texts and the `data` fields are proposals (R-OUT2, TW24): the human accepts or changes them at the review.
##
## ```mermaid
## flowchart TD
##     A["read: the app, --as, --roc"] --> B["Lookup (scope Tool): an installed tool or a full name"]
##     B --> C["key: the binary name. ToolsJson.clash (R-T28)"]
##     C --> D["the release list: pick (R-T9, R-T10)"]
##     D --> E["reuse (R-T26): Keep, or Build"]
##     E --> F["fetch the app bundle, read the header (R-T1): a bundle that is no app is dropped (R-T10)"]
##     F --> G["compiler: the pin is installed (R-T12), else want (R-T6)"]
##     G --> H["build_spec: roc build, no --target (R-T8)"]
##     H --> I["under the lock of tools.json (R-CC6): clash again, verdict (R-ST6), the files (R-T3, R-ST15), tools.json (R-T4)"]
## ```
ToolInstall :: [].{

	## The operand and the flags of one `tool install` line. `ref` is the app as typed (`Ref.parse` with the scope `Tool`). `as_name` is `--as` (R-T28). `roc` is `--roc`: `Pinned` counts as the consent for the pinned download (R-T6).
	Plan : { ref : Ref, as_name : Try(Str, [Unset]), roc : [Auto, Pinned, Installed] }

	## What `pick` gives: the candidates to try, newest first (the flow tries each one until its bundle is an app, R-T10), `young` (the first one is younger than `min-release-age`: only a named version, R-T9), and the note of `Index.new_entry` (other URL forms).
	## `kept` is the note of R-C16 (`Age.note`) when the first candidate is young and only a pattern of `exclude` keeps it visible (step 4 only).
	Picked : { order : List(Index.Candidate), young : Bool, note : Try(Str, [None]), kept : Try(Str, [None]) }

	## The compiler of the build (R-T11, R-T12). `Use(id)`: the pin is installed. `Missing(id)`: the pin is not installed (R-T6 decides). `NoPin`: the header has no `roc:` entry (question Q3).
	Compiler : [Use(Str), Missing(Str), NoPin]

	## The paths of one install (R-T3, R-LY2, R-CC1, R-CC2). `hex` is `Temp.hex(Fx.random!())`. `<file>` is the key, with `.exe` on Windows (R-ST15). The temp dir has the output of the build. Nothing else is in the cache.
	##
	## | Field | Path |
	## | --- | --- |
	## | `dir` | `<cache>/packages/<hash>`: the extracted app bundle. The build runs in it. |
	## | `temp` | `<cache>/talon/tmp/<hex>` |
	## | `output` | `<temp>/<file>`: the file that `roc build --output` writes |
	## | `data_bin` | `<data>/bin` (R-T3) |
	## | `data_file` | `<data bin>/<file>`: the binary of the tool (R-T3) |
	## | `data_tmp` | `<data bin>/<file>.<hex>.tmp`: the copy, then `rename` (R-CC1) |
	## | `bin` | The bin dir (`Setup.bin_dir`, R-LY8) |
	## | `entry` | `<bin>/<file>`: the bin dir entry (R-ST15) |
	## | `entry_tmp` | `<bin>/<file>.<hex>.tmp`: the link or the copy, then `rename` (R-ST7) |
	Layout : { dir : Str, temp : Str, output : Str, data_bin : Str, data_file : Str, data_tmp : Str, bin : Str, entry : Str, entry_tmp : Str }

	## What the install did: `Installed`, `Replaced(<old version>)` (a release tool, or a git tool: R-T26, R-T27), `Present` (R-T26: no build).
	How : [Installed, Replaced(Str), Present]

	## The operand and the flags (R-CM16, R-T28, R-T6). The checks, in order (all kind `Usage`, exit 2, the texts are proposals):
	##
	## | # | Case | Failure |
	## | --- | --- | --- |
	## | 1 | `--git`, `--path` or `--resolve` (slices 048 and later: R-T23, R-T1) | `tln tool install <flag> is not built yet` |
	## | 2 | No operand | `tln tool install needs one app: owner/app` |
	## | 3 | 2 operands or more | `tln tool install takes one app, got <n>` |
	## | 4 | `Ref.parse(operand, Scope.Tool, false)` fails (R-SL1 to R-SL13) | Its failure |
	## | 5 | The selector is a `GitSha` (`@dd03c09e`) | `'<sel>' in '<operand>' is a git ref: a git ref needs --git (not built yet)` |
	## | 6 | `--roc` with another value | `--roc must be pinned or installed, not '<value>'` |
	## | 7 | `--as` with a text that is not a binary name | `'<name>' is not a binary name: use letters, digits, '.', '_' and '-', and start with a letter or a digit` |
	##
	## A selector of the kinds `Nightly` and `Step` is refused by `Ref.parse` (it is for `tln roc`, R-SL6, R-SL7).
	read : Args -> Try(Plan, Fail)
	read = |args| {
		if later_flag(args) != "" return Err(usage("tln tool install ${later_flag(args)} is not built yet"))
		operand = match args.operands {
			[] => return Err(usage("tln tool install needs one app: owner/app"))
			[one] => one
			many => return Err(usage("tln tool install takes one app, got ${many.len().to_str()}"))
		}
		ref = Ref.parse(operand, Scope.Tool, Bool.False)?
		match ref.selector {
			Ok(GitSha(sel)) => return Err(usage("'${sel}' in '${operand}' is a git ref: a git ref needs --git (not built yet)"))
			_ => {}
		}
		flags = ToolInstall.read_flags(args)?
		Ok({ ref, as_name: flags.as_name, roc: flags.roc })
	}

	## Rows 6 and 7 of `read`, also for a git source (slice 048, `ToolGit.read`): `--roc` and `--as`.
	read_flags : Args -> Try({ as_name : Try(Str, [Unset]), roc : [Auto, Pinned, Installed] }, Fail)
	read_flags = |args| {
		roc = match option(args, "--roc") {
			Err(Unset) => Auto
			Ok("pinned") => Pinned
			Ok("installed") => Installed
			Ok(other) => return Err(usage("--roc must be pinned or installed, not '${other}'"))
		}
		as_name = option(args, "--as")
		match as_name {
			Ok(name) if !is_binary_name(name) => return Err(usage("'${name}' is not a binary name: use letters, digits, '.', '_' and '-', and start with a letter or a digit"))
			_ => {}
		}
		Ok({ as_name, roc })
	}

	## R-T26, R-T27 (review 2): the key under which the app `name` is installed already. The first entry with that full name gives its key. `Err(None)` when no entry has the name (a short name is no full name). The command uses it when there is no `--as`:
	## `tln tool install acme/qux` after an earlier `--as q` is the tool `q`.
	installed_key : { entries : List(ToolsJson.Entry), name : Str } -> Try(Str, [None])
	installed_key = |facts| match facts.entries.find_first(|e| e.name == facts.name) {
		Ok(e) => Ok(e.key)
		Err(_) => Err(None)
	}

	## R-T28, R-ST15: the binary name (the key of `tools.json`). `--as` gives it. Else (the command asks `installed_key` first) it is the repo name of the full name (the text after the last `/`): `acme/foo` is `foo`. Question Q1: the design does not say what the default is.
	key : { plan : Plan, name : Str } -> Str
	key = |facts| match facts.plan.as_name {
		Ok(name) => name
		Err(Unset) => Text.last_segment(facts.name)
	}

	## R-ST15, R-LY7: the name of the binary file in the data bin dir and of the bin dir entry: the key, and `.exe` on Windows.
	file_name : { os : Setup.Os, key : Str } -> Str
	file_name = |facts| if facts.os == Windows "${facts.key}.exe" else facts.key

	## R-T9, R-T10, R-DI3, R-DI6, R-C7: the releases to try, from the candidates of the repo (`Index.candidates`: a release with one package asset). `list` is not empty (the flow handles an empty list: R-T10).
	##
	## | # | Step | Rule |
	## | --- | --- | --- |
	## | 1 | The selector: `Exact(v)` keeps the candidates with the version `v`. `Range(text)` keeps those that `Ranges.admits`. `Latest` and no selector keep all. | R-B2 |
	## | 2 | Nothing is left: kind `Usage`, `<name> has no release <v>` (`Exact`) or `<name> has no release in <text>` (`Range`) | |
	## | 3 | `Exact`: no age rule. `young` is true when the first candidate (the newest of that version) is younger than `min_age` (`published_at + min_age > now`). The order is `Index.order(.., Highest)`. | R-T9 |
	## | 4 | Else: the candidates that `min-release-age` hides are dropped (`Age.hides`: a pattern of `exclude` that matches `name` keeps a young one), then `Index.new_entry`: the URL form of the newest one, as `tln add` (R-DI6). Then `Index.order(.., Highest)`. `kept` is the note of the first one. | R-T9, R-C7, R-C15, R-C16, R-DI6 |
	## | 5 | Nothing is left after step 4: kind `Usage`, `no release of <name> is old enough for min-release-age` | R-T9 |
	pick : { name : Str, list : List(Index.Candidate), selector : Try(Selector, [None]), now : U64, min_age : U64, exclude : List(Str) } -> Try(Picked, Fail)
	pick = |facts| {
		kept = match facts.selector {
			Ok(Exact(version)) => facts.list.keep_if(|c| c.ident.version == version)
			Ok(Range(text)) => facts.list.keep_if(|c| Ranges.admits({ ranges: [text], version: c.ident.version }))
			_ => facts.list
		}
		if kept.is_empty() {
			return match facts.selector {
				Ok(Exact(version)) => Err(usage("${facts.name} has no release ${version}"))
				Ok(Range(text)) => Err(usage("${facts.name} has no release in ${text}"))
				_ => Err(usage("${facts.name} has no release"))
			}
		}
		young = |c| c.published_at + facts.min_age > facts.now
		age = |c| { now: facts.now, min_age: facts.min_age, published_at: c.published_at, exclude: facts.exclude, name: Ok(facts.name) }
		match facts.selector {
			Ok(Exact(_)) => {
				order = Index.order(kept, Highest)
				first_young = match order.first() {
					Ok(c) => young(c)
					Err(_) => Bool.False
				}
				Ok({ order, young: first_young, note: Err(None), kept: Err(None) })
			}
			_ => {
				visible = kept.keep_if(|c| !Age.hides(age(c)))
				match Index.new_entry({ name: facts.name, list: visible }) {
					Ok(entry) => {
						order = Index.order(entry.list, Highest)
						kept_note = match order.first() {
							Ok(c) => Age.note({ id: facts.name, version: c.ident.version, now: facts.now, min_age: facts.min_age, published_at: c.published_at, exclude: facts.exclude, name: Ok(facts.name) })
							Err(_) => Err(None)
						}
						Ok({ order, young: Bool.False, note: entry.note, kept: kept_note })
					}
					Err(NoCandidate) => Err(usage("no release of ${facts.name} is old enough for min-release-age"))
				}
			}
		}
	}

	## R-T26, R-B1, R-B2: is the installed tool enough? `installed` is the tool with the key (`Err(None)`: none). `first` is the version of the first candidate of `pick` (the version that the selector means, R-B2).
	##
	## | Installed | Selector | Result |
	## | --- | --- | --- |
	## | None, or a git tool (R-T27) | any | `Build` |
	## | A release tool with version `v` | none | `Keep(v)` (R-B1: any build, no rebuild only because a newer version exists) |
	## | The same | `Exact(x)` | `Keep(v)` when `x == v`, else `Build` |
	## | The same | `Latest` or `Range` | `Keep(v)` when `first == v`, else `Build` (R-B2: the version is the newest release in the range) |
	reuse : { installed : Try(ToolsJson.Entry, [None]), selector : Try(Selector, [None]), first : Str } -> [Keep(Str), Build]
	reuse = |facts| match facts.installed {
		Err(None) => Build
		Ok(entry) => match entry.source {
			Git(_) => Build
			Release(rel) => match facts.selector {
				Err(None) => Keep(rel.version)
				Ok(Exact(wanted)) => if wanted == rel.version Keep(rel.version) else Build
				Ok(_) => if facts.first == rel.version Keep(rel.version) else Build
			}
		}
	}

	## R-T11, R-T12: the compiler release of the build. `pin` is the `roc:` entry of the app header (`Locked.read`), `installed` are the ids in `<cache>/toolchains` (`Launch.toolchains!`).
	## No pin: `NoPin`. The pin is in `installed`: `Use(pin)`. Else `Missing(pin)`.
	compiler : { pin : Try(Str, [NoPin]), installed : List(Str) } -> Compiler
	compiler = |facts| match facts.pin {
		Err(NoPin) => NoPin
		Ok(id) => if facts.installed.contains(id) Use(id) else Missing(id)
	}

	## R-T6, R-T16, R-DL1 to R-DL5: may the pinned compiler `id` be downloaded? `auto` is `TALON_AUTO_INSTALL` (`Consent.auto_install`), `yes` is `--yes`, `roc` is `--roc` (`Pinned` is the answer Yes). This is `Consent.required_want` with the mode
	## `NonInteractive` (slice 046 has no prompt: R-NI8 is slice 047, question Q5). `Install` gives `Install`. Every other case is `Stop`: `Refuse` (the pin is not a nightly tag: `Consent.required_want` row 1) is the failure of kind `Consent`
	## `the compiler <id> is not installed. Run: tln roc install <id>.`, `AutoNo` is `Consent.download_refused(id)`, and the others are `consent_stop(id)`.
	want : { id : Str, roc : [Auto, Pinned, Installed], auto : [Ask, Yes, No], yes : Bool } -> [Install, Stop(Fail)]
	want = |run| {
		flag = match run.roc {
			Pinned => Ok(Yes)
			_ => Err(NoFlag)
		}
		match Consent.required_want({ id: run.id, auto: run.auto, mode: NonInteractive, yes: run.yes, flag }) {
			Install => Install
			Refuse => Stop(Fail.new(Consent, "the compiler ${run.id} is not installed. Run: tln roc install ${run.id}."))
			AutoNo => Stop(Consent.download_refused(run.id))
			_ => Stop(ToolInstall.consent_stop(run.id))
		}
	}

	## R-T16, R-NM5: the stop of a required choice with no answer. Kind `Consent` (exit 13). It names the flags (a proposal, TW24): `the compiler <id> is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes. (--roc installed tries the installed compilers.)`
	consent_stop : Str -> Fail
	consent_stop = |id| Fail.new(Consent, "the compiler ${id} is not installed. Pass --roc pinned or --yes, or set TALON_AUTO_INSTALL=yes. (--roc installed tries the installed compilers.)")

	## R-T11, R-T12 (question Q3): a header with no `roc:` entry. Kind `Usage` (exit 2): `<name> <version> has no roc: pin in its app header, so tln cannot tell which compiler to build with`.
	no_pin : { name : Str, version : Str } -> Fail
	no_pin = |facts| usage("${facts.name} ${facts.version} has no roc: pin in its app header, so tln cannot tell which compiler to build with")

	## The paths of the table of `Layout`.
	layout : { roots : Roots, bin : Str, os : Setup.Os, key : Str, hash : Str, hex : Str } -> Layout
	layout = |facts| {
		file = ToolInstall.file_name({ os: facts.os, key: facts.key })
		temp = Roots.item(facts.roots, TalonTmp(facts.hex))
		data_bin = Roots.item(facts.roots, Bin)
		data_file = Text.join(data_bin, file)
		entry = Text.join(facts.bin, file)
		{
			dir: Roots.item(facts.roots, Package(facts.hash)),
			temp,
			output: Text.join(temp, file),
			data_bin,
			data_file,
			data_tmp: Temp.name({ target: data_file, hex: facts.hex }),
			bin: facts.bin,
			entry,
			entry_tmp: Temp.name({ target: entry, hex: facts.hex }),
		}
	}

	## R-T11, R-T8, R-T5: the probe of the build. `program` and `env` are those of `Launch.program!` and `Launch.child_env!` for the compiler `id` (R-PX6). The arguments are `build main.roc --opt=speed --output=<output> --no-cache` (R-LD8) and never
	## `--target` (R-T8: roc then uses the musl target of the platform, else its glibc target). `dir` is the extracted app bundle (`Layout.dir`). The timeout is 3600 s and the weight is `Probe.weight` of a build (question Q6: R-RC3 gives 30 s to a probe and a tool build is long).
	build_spec : { id : Str, program : Str, env : List((Str, Str)), dir : Str, output : Str } -> Probe.Spec
	build_spec = |facts| {
		args: Probe.build_args({ file: "main.roc", options: ["--opt=speed"], output: facts.output }),
		compiler: facts.id,
		program: facts.program,
		dir: facts.dir,
		env: facts.env,
		timeout: build_timeout,
		weight: Probe.weight(Build({ output: facts.output })),
	}

	## The failure of a build that did not pass (question Q7: the design gives no code; the proposal follows R-EC11 and R-EC1). `class` is `Probe.classify` of the result, `errors` are `Probe.errors` of its stderr (the first title is shown).
	##
	## | Class | Kind | Message |
	## | --- | --- | --- |
	## | `Fail(n)` | `AppError` (11) | `the build of <name> <version> with <id> failed: <n> error(s): <title of the first error>` (`<n> errors`, `1 error`, no `: <title>` without an error) |
	## | `Hang` | `Internal` (1) | `the build of <name> <version> with <id> did not end in <timeout> s` |
	## | `Crash(text)`, `NoFact(text)` | `Internal` | `the build of <name> <version> with <id> gave no result: <text>` |
	## | `Pass` | `Internal` | `the build of <name> <version> with <id> made no file <output>` (the build passed, the file is missing) |
	build_failed : { name : Str, version : Str, id : Str, class : Probe.Class, errors : List(Probe.Err), output : Str } -> Fail
	build_failed = |facts| {
		what = "the build of ${facts.name} ${facts.version} with ${facts.id}"
		match facts.class {
			Fail(n) => {
				count = if n == 1 "1 error" else "${n.to_str()} errors"
				title = match facts.errors.first() {
					Ok(first) => ": ${first.title}"
					Err(_) => ""
				}
				Fail.new(AppError, "${what} failed: ${count}${title}")
			}
			Hang => Fail.new(Internal, "${what} did not end in ${build_timeout.to_str()} s")
			Crash(text) | NoFact(text) => Fail.new(Internal, "${what} gave no result: ${text}")
			Pass => Fail.new(Internal, "${what} made no file ${facts.output}")
		}
	}

	## R-ST6, R-ST11, R-ST7: may the install write the bin dir entry? `old` is the sha256 of the binary that is in the data bin dir now (`Err(NotFound)` for a first install). `have` is the entry in the bin dir as `SetupIo.have_of!` gives it.
	## `Make`: no entry, or an entry of Talon (`Setup.judge`: its sha256 is the one of the old binary, so a stale link of a replaced file is Talon's too). `Foreign`: any other file or directory. Talon never overwrites it (R-ST6).
	verdict : { old : Try(Str, [NotFound]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [Make, Foreign]
	verdict = |facts| match facts.have {
		Absent => Make
		Dir | Unreadable => Foreign
		Sha(have) => match facts.old {
			Ok(old) => if old == have Make else Foreign
			Err(NotFound) => Foreign
		}
	}

	## Slice 078 (R-ST11, R-ST9, R-T4): `verdict` with the record of `tools.json` (`BinRecord.read`). `recorded` is the sha256 that `bin.<name>` has for this entry, or `Err(None)`. The entry is Talon's when its sha256 is the one of the data file `old` (R-ST11 (1)) or the recorded one (R-ST11 (2): a stale
	## entry that a step left on the old file, R-ST9). So `Make` for `Sha(h)` when `old` is `Ok(h)` or `recorded` is `Ok(h)`, also when the data file is gone (`old` is `Err(NotFound)`). `Absent` is `Make`. `Dir` and `Unreadable` are `Foreign` (the record does not count). Any other file is `Foreign`.
	## The flows use this function. `verdict` stays with the same results as before (`recorded: Err(None)`).
	verdict_bin : { old : Try(Str, [NotFound]), recorded : Try(Str, [None]), have : [Absent, Dir, Unreadable, Sha(Str)] } -> [Make, Foreign]
	verdict_bin = |facts| match facts.have {
		Absent => Make
		Dir | Unreadable => Foreign
		Sha(have) => if facts.old == Ok(have) or facts.recorded == Ok(have) Make else Foreign
	}

	## R-T28, R-NM11, R-CC6: the failure of a binary name that another tool has. Kind `Usage` (exit 2). It names the flag: `<key> is the binary name of <taken> already. Use --as <name> to install <name> under another binary name.` (`<taken>` is the full name of the other tool.)
	clash_failure : { key : Str, taken : Str, name : Str } -> Fail
	clash_failure = |facts| usage("${facts.key} is the binary name of ${facts.taken} already. Use --as <name> to install ${facts.name} under another binary name.")

	## R-T27, question Q2: the same app under another key. Kind `Usage`: `<name> is installed as <key> already. Remove it first: tln tool remove <key>`.
	elsewhere_failure : { key : Str, name : Str } -> Fail
	elsewhere_failure = |facts| usage("${facts.name} is installed as ${facts.key} already. Remove it first: tln tool remove ${facts.key}")

	## R-T2 (review of Q9): may the platform of the app make a native executable? `found` is `BuildTarget.targets_of` of the header of the platform (slice 054). A header with no readable `targets` (`Err(NoSection)`) is admitted (question Q1 of slice 054),
	## also `targets: {}`. A list that has names and only wasm names (`wasm32`, `wasm32v1`) is `WasmOnly(names)`. A list with one other name is `Native`.
	native : Try(List(Str), [NoSection]) -> [Native, WasmOnly(List(Str))]
	native = |found| match found {
		Ok(names) => if !names.is_empty() and names.all(|name| name.starts_with("wasm")) WasmOnly(names) else Native
		Err(NoSection) => Native
	}

	## R-T2: the failure for a platform that makes no native executable. Kind `Usage` (exit 2, a proposal, TW24): `<name> <version> needs the platform <hash>, which has no native target (targets: <names>). tln tool install makes a command line tool, so it needs a native platform.`
	not_native : { name : Str, version : Str, hash : Str, names : List(Str) } -> Fail
	not_native = |facts| usage("${facts.name} ${facts.version} needs the platform ${facts.hash}, which has no native target (targets: ${Str.join_with(facts.names, ", ")}). tln tool install makes a command line tool, so it needs a native platform.")

	## R-ST6 (question Q8): the failure of a bin dir entry that Talon did not write. Kind `Usage` (exit 2): `<path> is not a file that tln wrote, so tln does not replace it. Use --as <name> to install under another binary name.`
	foreign_failure : Str -> Fail
	foreign_failure = |path| usage("${path} is not a file that tln wrote, so tln does not replace it. Use --as <name> to install under another binary name.")

	## R-T10: the failure when no release is a candidate. Kind `Usage` (exit 2). `newest` is the tag of the newest release of the list (by `published_at`), `branch` is the default branch of the repo (`branch_of`). The messages (proposals):
	##
	## | `newest` | `branch` | Message |
	## | --- | --- | --- |
	## | `Ok(tag)` | any | `<name> has no release with an app bundle. tln does not build from source by itself. Run: tln tool install --git <name>@<tag>` |
	## | `Err` | `Ok(b)` | `<name> has no release. tln does not build from source by itself. Run: tln tool install --git <name>@<b>` |
	## | `Err` | `Err` | `<name> has no release, and its default branch is not known. tln does not build from source by itself. Run: tln tool install --git <name>@<branch>` |
	no_candidate : { name : Str, newest : Try(Str, [None]), branch : Try(Str, [None]) } -> Fail
	no_candidate = |facts| {
		git = "tln does not build from source by itself. Run: tln tool install --git ${facts.name}@"
		match (facts.newest, facts.branch) {
			(Ok(tag), _) => usage("${facts.name} has no release with an app bundle. ${git}${tag}")
			(Err(None), Ok(branch)) => usage("${facts.name} has no release. ${git}${branch}")
			(Err(None), Err(None)) => usage("${facts.name} has no release, and its default branch is not known. ${git}<branch>")
		}
	}

	## R-T10: the tag of the newest candidate by `published_at` (the first one wins a tie). `Err(None)` for no candidate.
	newest_tag : List(Index.Candidate) -> Try(Str, [None])
	newest_tag = |list| match list {
		[] => Err(None)
		[first, .. as rest] => Ok(rest.fold(first, |best, c| if c.published_at > best.published_at c else best).tag)
	}

	## R-T10: the default branch from the answer of `GET <api>/repos/<owner>/<repo>`. A status 200 and a JSON object with a text `default_branch` that is not empty give `Ok`. Any other answer is `Err(None)`.
	branch_of : { status : U16, body : Str } -> Try(Str, [None])
	branch_of = |facts| if facts.status != 200 {
		Err(None)
	} else {
		match JsonDoc.parse(facts.body) {
			Ok(Obj(pairs)) => match pairs.find_first(|(name, _)| name == "default_branch") {
				Ok((_, Text(branch))) if !branch.is_empty() => Ok(branch)
				_ => Err(None)
			}
			_ => Err(None)
		}
	}

	## R-T9: the note of a named version that is younger than `min-release-age`, on stderr. `published_at` is the release time. `<name> <version> was released at <time> (Clock.format_utc), less than min-release-age ago. It is installed because the version is named.`
	age_note : { name : Str, version : Str, published_at : U64 } -> Str
	age_note = |facts| "${facts.name} ${facts.version} was released at ${Clock.format_utc(facts.published_at)}, less than min-release-age ago. It is installed because the version is named."

	## R-SE8, R-T11: the lines on stderr before the build (`--quiet` hides them). Line 1: `platform <url> (hash <hash>)` for a platform URL that `Ident.of_url` reads, else `platform <value>`; no line for an app with no platform entry. Line 2: `building <name> <version> with <id>`.
	## `pf` is `Release.pf` of the header, `hash` is `Ident.hash` of it (`Err(None)` for a value that is no release URL).
	header_lines : { name : Str, version : Str, id : Str, pf : Try(Str, [None]), hash : Try(Str, [None]) } -> List(Str)
	header_lines = |facts| {
		building = "building ${facts.name} ${facts.version} with ${facts.id}"
		match (facts.pf, facts.hash) {
			(Ok(value), Ok(hash)) => ["platform ${value} (hash ${hash})", building]
			(Ok(value), Err(None)) => ["platform ${value}", building]
			(Err(None), _) => [building]
		}
	}

	## The answer on stdout (R-OUT2: a proposal). `Installed`: `installed <key> <version> (<name>)`. `Replaced(old)`: `replaced <key> <old> with <version> (<name>)`. `Present`: `<key> <version> is installed` (R-T26). One line each, with the line end.
	report : { how : How, key : Str, name : Str, version : Str } -> Str
	report = |facts| match facts.how {
		Installed => "installed ${facts.key} ${facts.version} (${facts.name})\n"
		Replaced(old) => "replaced ${facts.key} ${old} with ${facts.version} (${facts.name})\n"
		Present => "${facts.key} ${facts.version} is installed\n"
	}

	## R-J3, R-J4, R-OUT4 (a proposal): the `data` of `--json`, the keys in this order: `tool` (the key), `name`, `version`, `how` (`installed`, `replaced`, `present`), `previous` (the old version for `Replaced`, else null), `bin` (the bin dir entry), then for a build only:
	## `url` (the bundle), `nightly` (the compiler id), `target`, `sha256`, `entry` (`hard_link` or `copy`). `Present` has no build, so it has the first 6 keys.
	data : { how : How, key : Str, name : Str, version : Str, bin : Str, built : Try({ url : Str, nightly : Str, target : Str, sha256 : Str, entry : [HardLink, Copy] }, [None]) } -> JsonDoc
	data = |facts| {
		(how, previous) = match facts.how {
			Installed => ("installed", JsonDoc.Null)
			Replaced(old) => ("replaced", JsonDoc.Text(old))
			Present => ("present", JsonDoc.Null)
		}
		head = [
			("tool", JsonDoc.Text(facts.key)),
			("name", JsonDoc.Text(facts.name)),
			("version", JsonDoc.Text(facts.version)),
			("how", JsonDoc.Text(how)),
			("previous", previous),
			("bin", JsonDoc.Text(facts.bin)),
		]
		match facts.built {
			Err(None) => JsonDoc.Obj(head)
			Ok(built) => {
				entry = match built.entry {
					HardLink => "hard_link"
					Copy => "copy"
				}
				JsonDoc.Obj(
					head.concat([
						("url", JsonDoc.Text(built.url)),
						("nightly", JsonDoc.Text(built.nightly)),
						("target", JsonDoc.Text(built.target)),
						("sha256", JsonDoc.Text(built.sha256)),
						("entry", JsonDoc.Text(entry)),
					]),
				)
			}
		}
	}
}

build_timeout : U64
build_timeout = 3600

usage : Str -> Fail
usage = |message| Fail.new(Usage, message)

# The first flag of the line that a later slice builds (R-T23, R-T1), or the empty text.
later_flag : Args -> Str
later_flag = |args| match args.options.find_first(|(name, _)| ["--git", "--path", "--resolve"].contains(name)) {
	Ok((name, _)) => name
	Err(_) => ""
}

option : Args, Str -> Try(Str, [Unset])
option = |args, flag| match args.options.find_first(|(name, _)| name == flag) {
	Ok((_, Ok(value))) => Ok(value)
	_ => Err(Unset)
}

# R-ST15: a file name. It starts with a letter or a digit and has letters, digits, '.', '_' and '-'.
is_binary_name : Str -> Bool
is_binary_name = |name| {
	bytes = name.to_utf8()
	is_alnum = |b| (b >= '0' and b <= '9') or (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z')
	match bytes {
		[first, ..] => is_alnum(first) and bytes.all(|b| is_alnum(b) or b == '.' or b == '_' or b == '-')
		[] => Bool.False
	}
}
