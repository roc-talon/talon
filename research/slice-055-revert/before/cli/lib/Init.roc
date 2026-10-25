import Args
import Clock
import Common
import Fail
import Fx
import Github
import Help
import Index
import InitText
import Net
import Opts
import RocInstall
import Roots
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
## | 4 | An app: the release list of the platform (`Github.releases!`, `Index.candidates`), `config.toml` for `min-release-age`, `Init.start`. A package has no platform. | R-IN1, R-C7 |
## | 5 | `write_atomic!` of `<cwd>/main.roc` (`InitText.app_file` or `InitText.package_file`): the header has no `roc:` entry | R-IN1, R-IN4, R-IN5 |
## | 6 | The flow of `tln upgrade` on that file: `Update.begin!` (it records the file in `projects.json`, R-PD9) and `Update.resolve!` with `command: Upgrade`, `names: []` (all packages and the nightly are free, R-UP12, R-UP6). The resolve writes the pin. | R-IN2, R-IN3, R-NI12, R-PD9 |
## | 7 | Not `--ci none`: `read_files!` of `<cwd>/.github/workflows/ci.yml`. Not there: `write_atomic!` of it (`InitText.ci_file(Help.version)`). There: it is not written, and the output has the line `note: .github/workflows/ci.yml exists, not written`, exit 0 (answer Q2). | R-IN6, R-IN7 |
## | 7b | A failure in step 6 or 7 (exit 10, 12, 13, a failed download): `delete!` of `<cwd>/main.roc`, which this run made, then the failure. A file that the run did not make is never deleted (answer Q1). | R-IN7 |
## | 8 | The output (below) | R-OUT1 |
##
## The output (a proposal, TW24): the lines of the flow of step 6 and the line R-DT5 (`Update.print!`), then `created main.roc` and, with a CI file, `created .github/workflows/ci.yml` (paths as seen from the current directory). With `--json` the envelope is
## the one of `Update.print!` with `command: "init"`: `data.written` has the files of the flow and then the CI file. The human text goes to stderr with `--json`, as in `Install`.
Init :: [].{

	## The options of an `init` line: the template, the platform name (`named` is `--platform`, a full name `owner/repo`; `Err(Unset)` is `InitText.default_platform`), and the CI file (`--ci`, default `Ci`).
	Plan : { template : [App, Package], named : Try(Str, [Unset]), ci : [Ci, NoCi] }

	## The checks of an `init` line, in this order (each failure has kind `Usage`, exit 2, R-EC2; the texts are a proposal, TW24):
	##
	## | # | Case | Message | Rule |
	## | --- | --- | --- | --- |
	## | 1 | 2 or more operands | `tln init takes one template name (app or package), got <n> names` | R-CM1 |
	## | 2 | One operand that is not `app` or `package` | `unknown template '<name>': use app or package` | R-IN1 |
	## | 3 | `--ci` with a value other than `github` or `none` | `--ci must be github or none, not '<value>'` | R-CM1 |
	## | 4 | `--platform` with the template `package` | `--platform does not work with the package template: a package has no platform` | R-IN1 (answer Q4) |
	## | 5 | `--platform` that is not `owner/repo` (a name with no `/`, 2 or more `/`, an empty part, an `@`) | `'<name>' is not a platform name: use owner/repo` | R-IN1 (answer Q6) |
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
		named = flag_value(args, "--platform")
		match (named, template) {
			(Ok(_), Package) => Err(Fail.new(Usage, "--platform does not work with the package template: a package has no platform"))
			(Ok(name), App) if !is_full_name(name) => Err(Fail.new(Usage, "'${name}' is not a platform name: use owner/repo"))
			_ => Ok({ template, named, ci })
		}
	}

	## The release that the template starts at (R-IN1, R-IN2, R-C7): from the candidates of the repository, the releases that `min-release-age` does not hide (`published_at + min_age <= now`), in the URL form of the newest of them
	## (`Index.new_entry`, R-DI6), and of those the highest version (`Index.order`). The resolve of the slice then moves it as `tln upgrade` does, so this is only the start. `Err(NoRelease)` when none is left.
	start : { name : Str, list : List(Index.Candidate), now : U64, min_age : U64 } -> Try(Index.Candidate, [NoRelease])
	start = |facts| {
		visible = facts.list.keep_if(|c| c.published_at + facts.min_age <= facts.now)
		match Index.new_entry({ name: facts.name, list: visible }) {
			Err(NoCandidate) => Err(NoRelease)
			Ok(entry) => match Index.order(entry.list, Highest) {
				[first, ..] => Ok(first)
				[] => Err(NoRelease)
			}
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
	text = match plan.template {
		Package => InitText.package_file
		App => {
			name = plan.named ?? InitText.default_platform
			url = start_url!(fx, { net, roots, now, offline: args.offline, name })?
			InitText.app_file({ name, url })
		}
	}
	match fx.write_atomic!([{ path: main_path, content: text }]) {
		Ok(_) => {}
		Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
	}
	match after_first!(fx, args, plan, { cwd, main_path }) {
		Ok({}) => Ok({})
		Err(fail) => {
			_ = fx.delete!([main_path])
			Err(fail)
		}
	}
}

# Steps 4 (app): the release that the template starts at, as a URL.
start_url! : Fx, { net : Net.Settings, roots : Roots, now : U64, offline : Bool, name : Str } => Try(Str, Fail)
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
	match Init.start({ name: facts.name, list: listed.list, now: facts.now, min_age: config.min_release_age ?? 172800 }) {
		Ok(candidate) => Ok(candidate.url)
		Err(NoRelease) => Err(Fail.new(Usage, "no release of ${facts.name} is old enough for min-release-age"))
	}
}

# Steps 6 to 8: the flow of `tln upgrade` on the new file, the CI file, the output.
after_first! : Fx, Args, Init.Plan, { cwd : Str, main_path : Str } => Try({}, Fail)
after_first! = |fx, args, plan, here| {
	shown = Common.shown_fx(fx, args)
	consent = args.options.keep_if(|(name, _)| name == "--allow-downloads" or name == "--probe-downloads")
	given = { ..args, operands: [], options: consent, file: Ok(here.main_path) }
	opts = Opts.read(given)?
	begun = Update.begin!(shown, given)?
	outcome = Update.resolve!(shown, given, opts, begun, { command: Upgrade, names: [] })?
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
	Update.print!(fx, shown, args, opts, { ..outcome, written })
	shown.out!("created main.roc\n")
	match ci {
		Written => shown.out!("created .github/workflows/ci.yml\n")
		Exists => shown.out!("note: .github/workflows/ci.yml exists, not written\n")
		Skipped => {}
	}
	Ok({})
}

# The value of a flag that has one.
flag_value : Args, Str -> Try(Str, [Unset])
flag_value = |args, flag| match args.options.find_first(|(name, _)| name == flag) {
	Ok((_, value)) => value
	Err(NotFound) => Err(Unset)
}

# R-IN1 (answer Q6): `owner/repo`, no selector.
is_full_name : Str -> Bool
is_full_name = |name| match name.split_on("/") {
	[owner, repo] => !owner.is_empty() and !repo.is_empty() and !name.contains("@")
	_ => Bool.False
}
