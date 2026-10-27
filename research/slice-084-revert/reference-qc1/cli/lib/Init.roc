import Age
import Args
import Clock
import Common
import Consent
import Fail
import Fetch
import Fx
import Github
import Help
import Ident
import Index
import InitStub
import InitText
import Locked
import Mode
import Item
import Net
import Opts
import RocInstall
import Roots
import Selector
import Start
import Text
import Update

## The command `tln init` (slice 041, R-CM1, CLI 5): a new app or package in the current directory, with the nightly as the `roc:` entry of the header and a CI file.
## It is direct style over `Fx` (TESTING.md 2.2, part C). `Init.read` and `Init.start` are the decisions (part A), `InitText` has the texts.
##
## The steps, in order (the L2 case `init/it1-app` fixes the calls):
##
## | # | Step | Rule |
## | --- | --- | --- |
## | 1 | `Init.read(args)`. A failure is printed as `Common.failed!` does (no `Fx` call). | R-CM1, R-FL12, R-EC2 |
## | 2 | `env_all!`, `Roots.from_env`, `Clock.now!`, `cwd!` | R-EV1, R-EV22 |
## | 3 | `read_files!` of `<cwd>/main.roc`. A file there: failure of kind `Usage` (exit 2), nothing is written. No search up or down (R-PD15). | R-IN7, R-PD15 |
## | 4 | An app: the release list of the platform (`Github.releases!`, `Index.candidates`), `config.toml` for `min-release-age` and `min-release-age-exclude`, then `Init.start` (no version; `Init.start_note` is the R-C16 note of the flow) or `Init.named` (a version: no age rule, the R-T9 age note on stderr, `<name> has no release <v>` is exit 2). A package has no platform. | R-IN1, R-C7, R-C15, R-C16, R-IN9 |
## | 4b | An app with another platform than `InitText.default_platform` (slice 055): `platform_header!`. `Fetch.packages!` for the start release (`random`, `list_dirs` of the packages dir, and a download when its dir is missing), then one `read_files!` of `<pkgs>/<hash>/main.roc`. A fetch failure is the failure of the run (`--offline` and a missing dir: exit 15). The default platform makes no call here. | R-IN8, R-FE2, R-FE7 |
## | 5 | `write_atomic!` of `<cwd>/main.roc` (an app: `InitText.app_file` for the default platform, else `InitStub.app_text` of the header of 4b, slice 055: a failure of it is exit 2 and nothing is written, the run stops before this step; a package: `InitText.package_file`): the header has no `roc:` entry | R-IN1, R-IN4, R-IN5, R-IN8 |
## | 6 | The flow of `tln upgrade` on that file: `Update.begin!` (it records the file in `projects.json`, R-PD9) and `Update.resolve!` with `command: Upgrade`, `names: []` (all packages and the nightly are free, R-UP12, R-UP6). The resolve writes the pin. With a named version (R-IN10) the flow is the one of `tln upgrade roc`: `names: ["roc"]` and `fixed: ["pf"]`, so the platform is held and never movable (R-SP23), and only the nightly is free. The R-C16 note of the start release is a note of the flow when the resolve did not move the platform. | R-IN2, R-IN3, R-IN10, R-NI12, R-PD9, R-C16 |
## | 6b | Slice 055 (question Q4, answer of the review): an app with another platform than the default, and the resolve moved the platform (`outcome.moved` has the alias `pf`): the release that the resolve chose is not the start release, so the stub is made again. One `read_files!` of `main.roc`, the `pf` URL of its header, `platform_header!` for that URL, `InitStub.app_text`, the `roc:` pin of the file put back (`Locked.edit` with `Pin`), one `write_atomic!` of `main.roc`. `init` made the file, so this overwrites no file of a user (R-IN7). A failure (exit 2 for a type with no stub, exit 15): the failure of the run, and step 7b removes `main.roc`. No move of the platform: no call here. | R-IN8, R-IN2, R-IN7 |
## | 7 | Not `--ci none`: `read_files!` of `<cwd>/.github/workflows/ci.yml`. Not there: `write_atomic!` of it (`InitText.ci_file(Help.version)`). There: it is not written, and the output has the line `note: .github/workflows/ci.yml exists, not written`, exit 0 (answer Q2). | R-IN6, R-IN7 |
## | 7b | A failure in step 6 or 7 (exit 10, 12, 13, a failed download): `delete!` of `<cwd>/main.roc`, which this run made, then the failure. A file that the run did not make is never deleted (answer Q1). | R-IN7 |
## | 8 | The output (below) | R-OUT1 |
##
## The output (a proposal, TW24): the lines of the flow of step 6 and the line R-DT5 (`Update.print!`), then `created main.roc` and, with a CI file, `created .github/workflows/ci.yml` (paths as seen from the current directory). With `--json` the envelope is
## the one of `Update.print!` with `command: "init"`: `data.written` has the files of the flow and then the CI file. The human text goes to stderr with `--json`, as in `Install`.
Init :: [].{

	## The options of an `init` line: the template, the platform name (`named` is `--platform`, a full name `owner/repo`; `Err(Unset)` is `InitText.default_platform`), the exact version of `--platform owner/repo@<version>` (R-IN9, `Err(Unset)` for none), and the CI file (`--ci`, default `Ci`).
	Plan : { template : [App, Package], named : Try(Str, [Unset]), version : Try(Str, [Unset]), ci : [Ci, NoCi] }

	## The checks of an `init` line, in this order (each failure has kind `Usage`, exit 2, R-EC2; the texts are a proposal, TW24):
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | 2 or more operands | `tln init takes one template name (app or package), got <n> names` | R-CM1 |
	## | 2 | One operand that is not `app` or `package` | `unknown template '<name>': use app or package` | R-IN1 |
	## | 3 | `--ci` with a value other than `github` or `none` | `--ci must be github or none, not '<value>'` | R-CM1 |
	## | 4 | `--platform` with the template `package` | `--platform does not work with the package template: a package has no platform` | R-IN1 (answer Q4) |
	## | 5 | `--platform` that is not `owner/repo` or `owner/repo@<text>` (the whole text: a name with no `/`, 2 or more `/`, an empty part, 2 or more `@`) | `'<text>' is not a platform name: use owner/repo or owner/repo@1.2.3` | R-IN1 (answer Q6), R-IN9 |
	## | 6 | The text after the `@` is not an exact version of 3 parts (`Selector.parse` is not `Exact`: a range, a series, `latest`, a nightly tag, a step, a git ref, an empty text) | `'<text>' is not an exact version: use owner/repo@1.2.3, or owner/repo for the newest release` | R-IN9 |
	##
	## No operand is `App`.
	read : Args -> Try(Init.Plan, Fail)
	read = |args| {
		template = match args.operands {
			[] | ["app"] => App
			["package"] => Package
			[other] => return Err(Fail.new(Usage, "unknown template '${other}': use app or package"))
			names => return Err(Fail.new(Usage, "tln init takes one template name (app or package), got ${names.len().to_str()} names"))
		}
		ci = match flag_value(args, "--ci") {
			Err(Unset) | Ok("github") => Ci
			Ok("none") => NoCi
			Ok(other) => return Err(Fail.new(Usage, "--ci must be github or none, not '${other}'"))
		}
		match (flag_value(args, "--platform"), template) {
			(Ok(_), Package) => Err(Fail.new(Usage, "--platform does not work with the package template: a package has no platform"))
			(Ok(text), App) => platform_of(text).map_ok(|given| { template, named: Ok(given.name), version: given.version, ci })
			(Err(Unset), _) => Ok({ template, named: Err(Unset), version: Err(Unset), ci })
		}
	}

	## The release that the template starts at (R-IN1, R-IN2, R-C7, R-C15): from the candidates of the repository, the releases that `min-release-age` does not hide (`Age.hides`: `published_at + min_age <= now`, or a pattern of `exclude` matches `name`), in the URL form of the newest of them
	## (`Index.new_entry`, R-DI6), and of those the highest version (`Index.order`). The resolve of the slice then moves it as `tln upgrade` does, so this is only the start. `Err(NoRelease)` when none is left.
	start : { name : Str, list : List(Index.Candidate), now : U64, min_age : U64, exclude : List(Str) } -> Try(Index.Candidate, [NoRelease])
	start = |facts| {
		visible = facts.list.keep_if(|c| !Age.hides({ now: facts.now, min_age: facts.min_age, published_at: c.published_at, exclude: facts.exclude, name: Ok(facts.name) }))
		match Index.new_entry({ name: facts.name, list: visible }) {
			Err(NoCandidate) => Err(NoRelease)
			Ok(entry) => match Index.order(entry.list, Highest) {
				[first, ..] => Ok(first)
				[] => Err(NoRelease)
			}
		}
	}

	## R-C16: the note of the start release `chosen` when it is young and only a pattern of `exclude` keeps it visible (`Age.note`, the text with no prefix). The flow adds it to its notes only when the resolve keeps the start release.
	start_note : { name : Str, chosen : Index.Candidate, now : U64, min_age : U64, exclude : List(Str) } -> Try(Str, [None])
	start_note = |facts| Age.note({ id: facts.name, version: facts.chosen.ident.version, now: facts.now, min_age: facts.min_age, published_at: facts.chosen.published_at, exclude: facts.exclude, name: Ok(facts.name) })

	## R-IN9, R-DI3, R-DI6: the release that `--platform owner/repo@<version>` names. The candidates with that version (`Index.candidates` has dropped drafts and prereleases), in the URL form of the newest of them (`Index.new_entry`), then `Index.order(.., Highest)` first.
	## No age rule (R-C7: the version is named). `note` is the R-T9 form when the release is younger than `min_age`: `<name> <version> was released at <time>, less than min-release-age ago. It is used because the version is named.` `Err(NoVersion)` when no candidate has the version.
	named : { name : Str, list : List(Index.Candidate), version : Str, now : U64, min_age : U64 } -> Try({ candidate : Index.Candidate, note : Try(Str, [None]) }, [NoVersion])
	named = |facts| {
		same = facts.list.keep_if(|c| c.ident.version == facts.version)
		ordered = match Index.new_entry({ name: facts.name, list: same }) {
			Ok(entry) => Index.order(entry.list, Highest)
			Err(NoCandidate) => []
		}
		match ordered {
			[first, ..] => {
				young = first.published_at + facts.min_age > facts.now
				note = if young Ok("${facts.name} ${facts.version} was released at ${Clock.format_utc(first.published_at)}, less than min-release-age ago. It is used because the version is named.") else Err(None)
				Ok({ candidate: first, note })
			}
			[] => Err(NoVersion)
		}
	}

	## The exit code of the command. Step 1 first (a failure is printed as `Common.failed!` does), then the steps above.
	##
	## The calls of steps 2 to 7 are fixed by `calls.log` of the L2 case `init/it1-app`. Notes that the log shows: the flow of step 6 calls `env_all!`, `clock!` and `cwd!` again (they are the first calls of `Update.begin!`, which is not changed); `Update.begin!` and `Update.resolve!` get
	## `{ ..args, operands: [], options: [], file: Ok(<cwd>/main.roc) }` and `Opts.read` of that record (`Opts.read` refuses `--platform` with no operand), so the project is found with `--file` and nothing above `<cwd>` is searched; the `Fx` of those two calls is the `shown` one
	## (`Common.shown_fx`), as in `Upgrade.run!`; the consent flags `--allow-downloads` and `--probe-downloads` stay in `options` of that record (answer Q3: `Args.allows` gets `init` for both flags, and `Opts.read` reads them); the min-release-age of step 4 is `config.min_release_age ?? 172800` of one `read_files!` of `config.toml`; the CI file is written after the flow, with one `write_atomic!` and `data.written` gets its absolute path at the end.
	run! : Fx, Args => I32
	run! = |fx, args| match Init.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match make!(fx, args, plan) {
			Ok({}) => 0
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# Steps 2 to 5: the directory, the start release, the first file. Then the rest, which removes that file on a failure (step 7b).
make! : Fx, Args, Init.Plan => Try({}, Fail)
make! = |fx, args, plan| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	net = Net.from_env(env)
	now = Clock.now!(fx, env)?
	cwd = fx.cwd!()
	main_path = Text.join(cwd, "main.roc")
	match fx.read_files!([main_path]) {
		[Ok(_)] => return Err(Fail.new(Usage, "main.roc is in ${cwd} already. tln init never overwrites a file."))
		[Err(NotFound)] => {}
		_ => return Err(Fail.new(Environment, "cannot read ${main_path}"))
	}
	made = match plan.template {
		Package => { text: InitText.package_file, start_note: Err(None) }
		App => {
			name = plan.named ?? InitText.default_platform
			started = start_url!(fx, { net, roots, now, offline: args.offline, name, version: plan.version })?
			url = started.url
			text =
				if name == InitText.default_platform {
					InitText.app_file({ name, url })
				} else {
					selected = Fetch.selected({ held: "", default: started.default_roc })
					header = platform_header!(fx, { net, roots, url, selected, downloads: downloads_of(args, env) })?
					InitStub.app_text({ name, url, text: header })?
				}
			{ text, start_note: started.note }
		}
	}
	text = made.text
	match fx.write_atomic!([{ path: main_path, content: text }]) {
		Ok(_) => {}
		Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
	}
	match after_first!(fx, args, plan, { cwd, main_path, roots, net, env, start_note: made.start_note }) {
		Ok({}) => Ok({})
		Err(fail) => {
			_ = fx.delete!([main_path])
			Err(fail)
		}
	}
}

# Steps 4 (app): the release that the template starts at, as a URL. `note` is the R-C16 note of a start release that only a pattern kept (no version). The R-T9 age note of a named version goes to stderr here.
start_url! : Fx, { net : Net.Settings, roots : Roots, now : U64, offline : Bool, name : Str, version : Try(Str, [Unset]) } => Try({ url : Str, default_roc : Str, note : Try(Str, [None]) }, Fail)
start_url! = |fx, facts| {
	(owner, repo) = match facts.name.split_on("/") {
		[o, r] => (o, r)
		_ => return Err(Fail.new(Usage, "'${facts.name}' is not a platform name: use owner/repo"))
	}
	# The line `index: cached at <time>` (R-DI12) is not printed here: the flow of step 6 reads the same list and prints it once.
	fetched = Github.releases!(fx, { net: facts.net, roots: facts.roots, owner, repo, now: facts.now, offline: facts.offline })?
	listed = match Index.candidates({ owner, repo, pages: fetched.pages, known: [] }) {
		Ok(got) => got
		Err(BadPage(n)) => return Err(Fail.new(Network, "the release list of ${facts.name} (page ${n.to_str()}) is not a list of releases"))
	}
	for w in listed.warnings {
		fx.err!("warning: ${w}\n")
	}
	config = RocInstall.read_config!(fx, facts.roots)?
	min_age = config.min_release_age ?? 172800
	exclude = config.min_release_age_exclude
	default_roc = config.default_roc ?? ""
	match facts.version {
		Ok(version) => match Init.named({ name: facts.name, list: listed.list, version, now: facts.now, min_age }) {
			Ok(found) => {
				match found.note {
					Ok(note) => fx.err!("${note}\n")
					Err(None) => {}
				}
				Ok({ url: found.candidate.url, default_roc, note: Err(None) })
			}
			Err(NoVersion) => Err(Fail.new(Usage, "${facts.name} has no release ${version}"))
		}
		Err(Unset) => match Init.start({ name: facts.name, list: listed.list, now: facts.now, min_age, exclude }) {
			Ok(chosen) => Ok({ url: chosen.url, default_roc, note: Init.start_note({ name: facts.name, chosen, now: facts.now, min_age, exclude }) })
			Err(NoRelease) => Err(Fail.new(Usage, "no release of ${facts.name} is old enough for min-release-age"))
		}
	}
}

# Step 4b (R-IN8): the header text of the platform release that the template starts at. The release is fetched when its dir is missing, as `tln path` and `tln install --frozen` fetch (R-FE2, R-FE3, R-FE7: `--offline` and a missing dir is exit 15).
platform_header! : Fx, { net : Net.Settings, roots : Roots, url : Str, selected : Str, downloads : Start.Downloads } => Try(Str, Fail)
platform_header! = |fx, facts| {
	hash = match Ident.of_url(facts.url) {
		Ok(ident) => ident.hash
		Err(Foreign) => return Err(Fail.new(Usage, "${facts.url} is not a package release URL"))
	}
	match Fetch.packages!(fx, { roots: facts.roots, urls: [facts.url], offline: facts.downloads.offline, unbundler: Choose({ selected: facts.selected, none: Download({ scope: Outside, exclude: [], downloads: facts.downloads }) }), downloader: facts.net.downloader }) {
		[Ok(_)] => {}
		[Err(fail)] => return Err(fail)
		_ => return Err(Fail.new(Internal, "the fetch of ${facts.url} gave no answer"))
	}
	file = Text.join(Roots.item(facts.roots, Item.Package(hash)), "main.roc")
	match fx.read_files!([file]) {
		[Ok(text)] => Ok(text)
		_ => Err(Fail.new(Environment, "cannot read ${file}"))
	}
}

# Steps 6 to 8: the flow of `tln upgrade` on the new file, the CI file, the output.
after_first! : Fx, Args, Init.Plan, { cwd : Str, main_path : Str, roots : Roots, net : Net.Settings, env : List((Str, Str)), start_note : Try(Str, [None]) } => Try({}, Fail)
after_first! = |fx, args, plan, here| {
	shown = Common.shown_fx(fx, args)
	consent = args.options.keep_if(|(name, _)| name == "--allow-downloads" or name == "--probe-downloads")
	given = { ..args, operands: [], options: consent, file: Ok(here.main_path) }
	opts = Opts.read(given)?
	begun = Update.begin!(shown, given)?
	# R-IN10: a named version is held and never movable (`fixed`), and the nightly is free, as `tln upgrade roc`.
	named = plan.version.is_ok()
	done = Update.resolve!(shown, given, opts, begun, { command: Upgrade, names: if named ["roc"] else [], fixed: if named [platform_alias] else [], fresh: Bool.True })?
	outcome = done.outcome
	remake!(fx, args, plan, { main_path: here.main_path, roots: here.roots, net: here.net, env: here.env, moved: outcome.moved })?
	ci_path = Text.join(here.cwd, ".github/workflows/ci.yml")
	ci = match plan.ci {
		NoCi => Skipped
		Ci => match fx.read_files!([ci_path]) {
			[Ok(_)] => Exists
			[Err(NotFound)] => {
				match fx.write_atomic!([{ path: ci_path, content: InitText.ci_file(Help.version) }]) {
					Ok(_) => Written
					Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
				}
			}
			_ => return Err(Fail.new(Environment, "cannot read ${ci_path}"))
		}
	}
	written = match ci {
		Written => outcome.written.append(ci_path)
		_ => outcome.written
	}
	# R-C16: the note of the start release, only when the resolve kept the start release in the header (a move has the note of the release that it chose).
	start_notes = match here.start_note {
		Ok(text) if !outcome.moved.any(|m| m.alias == platform_alias) => [text]
		_ => []
	}
	for note in start_notes {
		shown.out!("note: ${note}\n")
	}
	Update.print!(fx, shown, args, opts, { ..done, outcome: { ..outcome, written, notes: outcome.notes.concat(start_notes) } })
	shown.out!("created main.roc\n")
	match ci {
		Written => shown.out!("created .github/workflows/ci.yml\n")
		Exists => shown.out!("note: .github/workflows/ci.yml exists, not written\n")
		Skipped => {}
	}
	Ok({})
}

# Step 6b (slice 055, question Q4): the resolve moved the platform, so the release is not the start release. The stub is made again from the header of the chosen release, and the `roc:` pin that the resolve wrote is put back.
remake! : Fx, Args, Init.Plan, { main_path : Str, roots : Roots, net : Net.Settings, env : List((Str, Str)), moved : List({ alias : Str, from : { name : Str, version : Str }, to : { name : Str, version : Str } }) } => Try({}, Fail)
remake! = |fx, args, plan, here| {
	name = plan.named ?? InitText.default_platform
	if plan.template == Package or name == InitText.default_platform or !here.moved.any(|m| m.alias == platform_alias) {
		return Ok({})
	}
	text = match fx.read_files!([here.main_path]) {
		[Ok(read)] => read
		_ => return Err(Fail.new(Environment, "cannot read ${here.main_path}"))
	}
	locked = Locked.read({ path: here.main_path, text })?
	url = match locked.rows.find_first(|row| row.alias == platform_alias) {
		Ok(row) => row.value
		Err(_) => return Err(Fail.new(Internal, "${here.main_path} has no pf entry"))
	}
	header = platform_header!(fx, { net: here.net, roots: here.roots, url, selected: "", downloads: downloads_of(args, here.env) })?
	stub = InitStub.app_text({ name, url, text: header })?
	pins = match locked.roc {
		Ok(id) => [Pin(id)]
		Err(NoPin) => []
	}
	made = Locked.edit({ path: here.main_path, text: stub, ops: pins })?
	match fx.write_atomic!([{ path: here.main_path, content: made }]) {
		Ok(_) => Ok({})
		Err(failed) => Err(Fail.new(Environment, "cannot write ${failed.path}"))
	}
}

# R-SO14 (2), R-DL1 to R-DL6: the consent facts of the download of a compiler, when `init` fetches a platform with no compiler installed (`--allow-downloads` answers the question, R-NI5).
downloads_of : Args, List((Str, Str)) -> Start.Downloads
downloads_of = |args, env| {
	auto: Consent.auto_install(env),
	allow: if args.options.any(|(name, _)| name == "--allow-downloads") Ok(Yes) else Err(NoFlag),
	yes: args.yes,
	mode: Mode.from_env({ env: Dict.from_list(env), json: args.json }),
	quiet: args.quiet,
	offline: args.offline,
	env,
}

# The value of a flag that has one.
flag_value : Args, Str -> Try(Str, [Unset])
flag_value = |args, flag| match args.options.find_first(|(name, _)| name == flag) {
	Ok((_, value)) => value
	Err(NotFound) => Err(Unset)
}

# The alias of the platform entry that `init` writes.
platform_alias : Str
platform_alias = "pf"

# R-IN1 (answer Q6), R-IN9: check 5 and check 6 of `read`. The whole text is read: one `/`, at most one `@`, and the part before the `@` is `owner/repo`. The part after it is an exact version.
platform_of : Str -> Try({ name : Str, version : Try(Str, [Unset]) }, Fail)
platform_of = |text| {
	(name, version) = match text.split_on("@") {
		[only] => (only, Err(Unset))
		[before, after] => (before, Ok(after))
		_ => return Err(not_a_name(text))
	}
	# The whole text has one `/`: `acme/pfx@1.2.0/x` is not a name (review of 2026-10-27, T2).
	if !is_full_name(name) or text.split_on("/").len() != 2 {
		return Err(not_a_name(text))
	}
	match version {
		Err(Unset) => Ok({ name, version: Err(Unset) })
		Ok(after) => match Selector.parse(after, Bool.False) {
			Ok(Exact(v)) => Ok({ name, version: Ok(v) })
			_ => Err(Fail.new(Usage, "'${after}' is not an exact version: use owner/repo@1.2.3, or owner/repo for the newest release"))
		}
	}
}

not_a_name : Str -> Fail
not_a_name = |text| Fail.new(Usage, "'${text}' is not a platform name: use owner/repo or owner/repo@1.2.3")

# `owner/repo`: two parts at one `/`, none empty, no `@`.
is_full_name : Str -> Bool
is_full_name = |name| match name.split_on("/") {
	[owner, repo] => !owner.is_empty() and !repo.is_empty() and !name.contains("@")
	_ => Bool.False
}
