import Args
import BuildSkip
import BuildTarget
import Clock
import Common
import Compiler
import Consent
import Fail
import Fetch
import Fx
import Github
import Ident
import Index
import Item
import Launch
import Lookup
import Mode
import Net
import OnPath
import Out
import RocInstall
import Roots
import Scope
import Setup
import SetupIo
import Start
import Temp
import Text
import ToolBuild
import ToolCompiler
import ToolCompilerFlow
import ToolInstall
import ToolsJson
import XTake

## The command `tln tool install owner/app` for a release (slice 046, CLI 6.4, R-CM16, R-T1 to R-T6, R-T8 to R-T12, R-T26 to R-T28, R-SE8, R-ST15, R-LY2, R-LY3, R-CC6). Direct style over `Fx` (TESTING.md 2.2 part C): `ToolInstall` and `ToolsJson` decide, this module
## orders the calls. `Run.run!` calls it for the command `["tool", "install"]`. The calls, in order (the L2 cases `tool/ti1-install` and `ti2-refusals` and the L3 case `tools/ti1-tool-install` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolInstall.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM16, R-T28 |
## | 2 | `env_all!`, `Roots.from_env`, `Net.from_env`, `Clock.now!` (one `clock!` call), `platform!`, `Setup.bin_dir`, `BuildSkip.target` (no target for the machine: kind `Environment`). | R-LY2, R-LY8, R-T8 |
## | 3 | One `read_files!` of `tools.json` (a missing file is no tool), `ToolsJson.read`. Then `RocInstall.read_config!` (one `read_files!` of `config.toml`: `min-release-age`, R-C7). | R-T4, R-T9 |
## | 4 | `Lookup.find` with the scope `Tool` and `ToolsJson.entities`: the full name (an installed tool with that name or short name, else the name as typed). A failure prints its block, then the failure. | R-SC3, R-AD7 |
## | 5 | `ToolInstall.key`, `ToolsJson.clash`: `Taken` and `Elsewhere` stop before any request (exit 2). | R-T28, R-NM11 |
## | 6 | The release list: `Github.releases!`, `Index.candidates`. `--offline` with no cached page: `Github.no_page_failure`. No candidate: `ToolInstall.no_candidate`, with one `http_get!` of `GET <api>/repos/<owner>/<repo>` (no request with `--offline`) for the default branch. | R-DI2, R-DI12, R-T10 |
## | 7 | `ToolInstall.pick`, `ToolInstall.reuse`: `Keep` ends the command (no build, R-T26). `young`: `ToolInstall.age_note` on stderr. | R-T9, R-T26 |
## | 7b | `entry_verdict!` (review of Q8, fail fast): `list_dirs!` of the bin dir, `SetupIo.have_of!`, `sha256_file!` of the data bin file, `ToolInstall.verdict`. `Foreign`: `ToolInstall.foreign_failure` (exit 2) before the download and the build. The same check runs again under the lock (step 12). | R-ST6, R-ST11 |
## | 8 | For each candidate in order: `Fetch.packages!` of its URL, one `read_files!` of `<pkgs>/<hash>/main.roc`, `Release.read`. A bundle that is not an app is dropped (R-T10). None left: `ToolInstall.no_candidate` with the newest tag. `Locked.read` gives the pin. | R-T10, R-T1, R-FE2 |
## | 8b | `check_platform!` (review of Q9): the platform of the app header, when it is a release URL (`Ident.of_url`): `Fetch.packages!` of it, one `read_files!` of `<pkgs>/<hash>/main.roc`, `BuildTarget.targets_of`, `ToolInstall.native`. `WasmOnly`: `ToolInstall.not_native` (exit 2). A path entry or a header with no `targets` is admitted (no call). | R-T2 |
## | 9 | `compile!` (slice 047): `ToolCompilerFlow.choose!` with the run facts (`Facts.probe_timeout` is `probe.timeout`). The pin is installed (R-T12): no more call. Else the evidence, `--roc`, the prompt, option 2. The calls: the doc table of `ToolCompilerFlow` and `ToolTry`. | R-T11 to R-T21, R-NI8 |
## | 10 | `attempt!` (the build of `choose!`, `ToolTry` and `finish!`): `random!`, `ToolInstall.layout`, `ToolInstall.header_lines` on stderr (the platform line for the first attempt only), `Launch.toolchains!`, `Launch.program!`, `Launch.touch!`, `Launch.child_env!`, `make_dirs!` of the temp dir, one `probes!` with `ToolInstall.build_spec`. An attempt that does not pass deletes the temp dir. `finish!` uses the passed attempt of option 2, else one `attempt!`; a result that is not a pass: `ToolInstall.build_failed`. | R-SE8, R-T11, R-T8, R-T5, R-CC9, R-PX6 |
## | 11 | The lock of `tools.json` (`Fx.locked!` on `Roots.item(ToolsJson)`, `Wait`, R-CC3), for the last step only (R-CC6): `read_files!` and `ToolsJson.read` again, `ToolsJson.clash` again (`Taken`, `Elsewhere`), `list_dirs!` of the bin dir, `SetupIo.have_of!`, `sha256_file!` of the old binary, `ToolInstall.verdict` (`Foreign`: exit 2, nothing is written). | R-CC6, R-T28, R-ST6, R-ST11 |
## | 12 | Under the lock: the check of step 7b again (`entry_verdict!`: the file can appear during the build), then `make_dirs!` of the data bin dir and the bin dir, `copy_file!` of the output to the temp name, `rename!` (R-CC1), `sha256_file!` of the binary, `hard_link!` to the temp name of the entry (else `copy_file!`), `rename!`, then `write_atomic!` of `tools.json` (`ToolsJson.add`). | R-T3, R-T4, R-ST7, R-ST15, R-CC1 |
## | 13 | `delete!` of the temp dir (also after a failure, R-CC2). The output: `ToolInstall.report` (`--quiet` hides it, R-FL4). With `--json` the text goes to stderr and stdout is `Out.json_ok` with `ToolInstall.data`. | R-J1 to R-J4, R-OUT2 |
ToolFlow :: [].{

	## What steps 2 and 3 found (slice 049, `tln x`): the machine, `tools.json` with all fields of each tool, `config.toml`. `ToolBuild.Facts` is this and the name of the app.
	Machine : { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, os : Setup.Os, bin : Str, target : Str, tools : List(ToolsJson.Tool), min_age : U64, exclude : List(Str), probe_timeout : U64, default_roc : Str }

	## Steps 1 to 13.
	run! : Fx, Args => I32
	run! = |fx, args| match ToolInstall.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match flow!(fx, args, plan) {
			Ok(done) => {
				print!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}

	## The steps of `flow!` for the other tool commands (slice 048: `ToolGitFlow`, `ToolUpdateFlow`). Each one is the private step with the same name.
	machine_for! : Fx => Try(ToolFlow.Machine, Fail)
	machine_for! = |fx| machine!(fx)

	choose_for! : Fx, Args, { roc : [Auto, Pinned, Installed] }, ToolBuild.Facts, ToolBuild.Bundle => Try(ToolCompilerFlow.Chosen, Fail)
	choose_for! = |fx, args, plan, facts, bundle| choose!(fx, args, plan, facts, bundle)

	## R-T30, R-SO2, R-SO6, R-SO7, R-SO10 (slices 079, 079b): the compiler that a tool command selects: `ROC_TOOLCHAIN`, else `default-roc` (`facts.selected`), else (slice 080, R-SO24 case 3) the newest installed nightly or release (one `list_dirs!`, a note on stderr), else the `roc` on `PATH` (rank 7). The lookup of `PATH` is lazy: a rank above 7 decides with no call (R-SO7), so only the commands with nothing installed make the calls of `OnPath.file!`.
	selected_for! : Fx, ToolBuild.Facts => Str
	selected_for! = |fx, facts| {
		env = toolchain_env(facts.env)
		newest = if env.is_empty() and facts.selected.is_empty() newest_of!(fx, facts) else ""
		path = if env.is_empty() and facts.selected.is_empty() and newest.is_empty() OnPath.file!(fx, facts.roots).map_ok(|found| found.id) else Err(NoCompiler)
		ToolCompiler.selected_of({ env, default: if newest.is_empty() facts.selected else newest, path })
	}

	gather_for! : Fx, ToolInstall.Plan => Try(ToolBuild.Facts, Fail)
	gather_for! = |fx, plan| gather!(fx, plan)

	release_list_for! : Fx, Args, ToolBuild.Facts => Try(List(Index.Candidate), Fail)
	release_list_for! = |fx, args, facts| release_list!(fx, args, facts)

	notes_for! : Fx, Args, ToolBuild.Facts, ToolInstall.Picked, Index.Candidate => {}
	notes_for! = |fx, args, facts, picked, newest| notes!(fx, args, facts, picked, newest)

	first_app_for! : Fx, Args, ToolBuild.Facts, List(Index.Candidate) => Try(ToolBuild.Bundle, Fail)
	first_app_for! = |fx, args, facts, order| first_app!(fx, args, facts, order)

	platform_for! : Fx, Args, ToolBuild.Facts, ToolBuild.Bundle => Try({}, Fail)
	platform_for! = |fx, args, facts, bundle| check_platform!(fx, args, facts, bundle)

	compile_for! : Fx, Args, ToolInstall.Plan, ToolBuild.Facts, ToolBuild.Bundle => Try(ToolBuild.Done, Fail)
	compile_for! = |fx, args, plan, facts, bundle| compile!(fx, args, plan, facts, bundle)

	bundle_for! : Fx, Args, ToolBuild.Facts, { version : Str, url : Str, hash : Str } => Try(Try(ToolBuild.Bundle, [NotApp]), Fail)
	bundle_for! = |fx, args, facts, rel| read_bundle!(fx, args, facts, rel)

	package_text_for! : Fx, Args, ToolBuild.Facts, { url : Str, hash : Str } => Try(Str, Fail)
	package_text_for! = |fx, args, facts, pkg| package_text!(fx, args, facts, pkg)
}

# Steps 2 to 13.
flow! : Fx, Args, ToolInstall.Plan => Try(ToolBuild.Done, Fail)
flow! = |fx, args, plan| {
	facts = gather!(fx, plan)?
	# Slice 049 (R-B7): with `--offline` a matching `x` entry is taken first, and no list is read.
	if args.offline {
		match XTake.offline!(fx, args, { facts, selector: plan.ref.selector })? {
			Ok(done) => return Ok(done)
			Err(NoMatch) => {}
		}
	}
	list = match release_list!(fx, args, facts) {
		Ok(got) => got
		Err(fail) => return no_list!(fx, args, { plan, facts, fail })
	}
	picked = ToolInstall.pick({ name: facts.name, list, selector: plan.ref.selector, now: facts.now, min_age: facts.min_age, exclude: facts.exclude })?
	newest = match picked.order.first() {
		Ok(first) => first
		Err(_) => return Err(Fail.new(Internal, "no release was picked"))
	}
	installed = match facts.entries.find_first(|e| e.key == facts.key) {
		Ok(entry) => Ok(entry)
		Err(_) => Err(None)
	}
	match ToolInstall.reuse({ installed, selector: plan.ref.selector, first: newest.ident.version }) {
		Keep(version) => return Ok({ how: Present, key: facts.key, name: facts.name, version, bin: Text.join(facts.bin, facts.file), built: Err(None) })
		Build => {}
	}
	match XTake.online!(fx, args, { facts, selector: plan.ref.selector, list, newest })? {
		Ok(done) => return Ok(done)
		Err(NoMatch) => {}
	}
	notes!(fx, args, facts, picked, newest)
	ToolBuild.entry_verdict!(fx, facts, Fresh)?
	bundle = first_app!(fx, args, facts, picked.order)?
	check_platform!(fx, args, facts, bundle)?
	compile!(fx, args, plan, facts, bundle)
}

# Steps 2 to 5: the machine, `tools.json`, `config.toml`, the full name, the binary name.
gather! : Fx, ToolInstall.Plan => Try(ToolBuild.Facts, Fail)
gather! = |fx, plan| {
	m = machine!(fx)?
	entries = m.tools.map(|t| { key: t.key, name: t.name, source: t.source })
	name = full_name!(fx, plan, entries)?
	key = match plan.as_name {
		Ok(_) => ToolInstall.key({ plan, name })
		Err(Unset) => match ToolInstall.installed_key({ entries, name }) {
			Ok(installed) => installed
			Err(None) => ToolInstall.key({ plan, name })
		}
	}
	match ToolsJson.clash({ entries, key, name }) {
		Taken(other) => return Err(ToolInstall.clash_failure({ key, taken: other.name, name }))
		Elsewhere(other) => return Err(ToolInstall.elsewhere_failure({ key: other.key, name }))
		_ => {}
	}
	Ok({ env: m.env, roots: m.roots, net: m.net, now: m.now, os: m.os, bin: m.bin, target: m.target, entries, min_age: m.min_age, exclude: m.exclude, probe_timeout: m.probe_timeout, name, key, file: ToolInstall.file_name({ os: m.os, key }), selected: Fetch.selected({ held: "", default: m.default_roc }) })
}

# Slice 049 (R-B7): a release list that fails with the kind `Network` (no network, and no `--offline`) is the offline case: a matching `x` entry is offered. No match, or another kind: the failure of the list.
no_list! : Fx, Args, { plan : ToolInstall.Plan, facts : ToolBuild.Facts, fail : Fail } => Try(ToolBuild.Done, Fail)
no_list! = |fx, args, run| match run.fail.kind {
	Network if !args.offline => match XTake.offline!(fx, args, { facts: run.facts, selector: run.plan.ref.selector })? {
		Ok(done) => Ok(done)
		Err(NoMatch) => Err(run.fail)
	}
	_ => Err(run.fail)
}

# Steps 2 and 3: the machine, `tools.json`, `config.toml`.
machine! : Fx => Try(ToolFlow.Machine, Fail)
machine! = |fx| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	net = Net.from_env(env)
	now = Clock.now!(fx, env)?
	host = fx.platform!()
	bin = Setup.bin_dir({ os: host.os, env })?
	target = match BuildSkip.target(host) {
		Ok(known) => known
		Err(Unknown) => return Err(Fail.new(Environment, "tln has no build target for this machine"))
	}
	tools_file = Roots.item(roots, Item.ToolsJson)
	tools = ToolsJson.manifest({ path: tools_file, text: SetupIo.read_text!(fx, tools_file)? })?
	config = RocInstall.read_config!(fx, roots)?
	Ok({ env, roots, net, now, os: host.os, bin, target, tools, min_age: config.min_release_age ?? 172800, exclude: config.min_release_age_exclude, probe_timeout: ToolBuild.probe_timeout(config), default_roc: config.default_roc ?? "" })
}

# Step 4 (R-SC3, R-AD7): an installed tool by its name or short name, else the name as typed. A failure prints its block first.
full_name! : Fx, ToolInstall.Plan, List(ToolsJson.Entry) => Try(Str, Fail)
full_name! = |fx, plan, entries| match Lookup.find(Scope.Tool, plan.ref, ToolsJson.entities(entries)) {
	Ok(Lookup.Existing(found)) => Ok(found.name)
	Ok(Lookup.New(name)) => Ok(name)
	Err({ fail, block }) => {
		if !block.is_empty() fx.err!(block)
		Err(fail)
	}
}

# Step 6 (R-DI2, R-DI12, R-T10): the candidates of the repo. No candidate is the failure of R-T10.
release_list! : Fx, Args, ToolBuild.Facts => Try(List(Index.Candidate), Fail)
release_list! = |fx, args, facts| {
	(owner, repo) = match facts.name.split_on("/") {
		[o, r] => (o, r)
		_ => return Err(Fail.new(Usage, "'${facts.name}' is not an owner/repo name. tln tool install reads the releases of GitHub repos only."))
	}
	fetched = Github.releases!(fx, { net: facts.net, roots: facts.roots, owner, repo, now: facts.now, offline: args.offline })?
	match fetched.source {
		Missing => return Err(Github.no_page_failure(facts.name))
		Cached(time) => fx.err!("${Github.offline_line(time)}\n")
		Live => {}
	}
	listed = match Index.candidates({ owner, repo, pages: fetched.pages, known: [] }) {
		Ok(got) => got
		Err(BadPage(n)) => return Err(Fail.new(Network, "the release list of ${facts.name} (page ${n.to_str()}) is not a list of releases"))
	}
	for w in listed.warnings {
		fx.err!("warning: ${w}\n")
	}
	if listed.list.is_empty() {
		return Err(ToolInstall.no_candidate({ name: facts.name, newest: Err(None), branch: default_branch!(fx, args, facts) }))
	}
	Ok(listed.list)
}

# R-T10: the default branch of a repo with no release. One request, never with `--offline`, with the token of the other GitHub requests (R-RG3). Any problem is `Err(None)`.
default_branch! : Fx, Args, ToolBuild.Facts => Try(Str, [None])
default_branch! = |fx, args, facts| if args.offline {
	Err(None)
} else {
	url = "${facts.net.api}/repos/${facts.name}"
	gh = match facts.net.token {
		AskGh => Github.ask_gh!(fx)
		_ => Err(None)
	}
	token = Net.token({ plan: facts.net.token, gh })
	match fx.http_get!({ url, headers: Net.headers({ token, etag: Err(None) }) }) {
		Ok(answer) => ToolInstall.branch_of({ status: answer.status, body: answer.body })
		Err(_) => Err(None)
	}
}

# Step 7 (R-T9, R-C16): the notes on stderr for a build. The note of a release that only a pattern kept is hidden by `--quiet` (R-FL4).
notes! : Fx, Args, ToolBuild.Facts, ToolInstall.Picked, Index.Candidate => {}
notes! = |fx, args, facts, picked, newest| {
	match picked.note {
		Ok(note) => fx.err!("note: ${note}\n")
		Err(None) => {}
	}
	if picked.young {
		fx.err!("${ToolInstall.age_note({ name: facts.name, version: newest.ident.version, published_at: newest.published_at })}\n")
	}
	match picked.kept {
		Ok(text) if !args.quiet => fx.err!("note: ${text}\n")
		_ => {}
	}
}

# Step 8 (R-T10, R-T1): the first candidate, newest first, whose bundle is an app. None left is the failure of R-T10 with the newest tag.
first_app! : Fx, Args, ToolBuild.Facts, List(Index.Candidate) => Try(ToolBuild.Bundle, Fail)
first_app! = |fx, args, facts, order| {
	match try_each!(fx, args, facts, order)? {
		Ok(bundle) => Ok(bundle)
		Err(None) => Err(ToolInstall.no_candidate({ name: facts.name, newest: ToolInstall.newest_tag(order), branch: Err(None) }))
	}
}

try_each! : Fx, Args, ToolBuild.Facts, List(Index.Candidate) => Try(Try(ToolBuild.Bundle, [None]), Fail)
try_each! = |fx, args, facts, rest| match rest {
	[] => Ok(Err(None))
	[cand, .. as more] => match read_app!(fx, args, facts, cand)? {
		Ok(bundle) => Ok(Ok(bundle))
		Err(NotApp) => try_each!(fx, args, facts, more)
	}
}

# One candidate: fetch the bundle, read its header (R-T1). A bundle that is no app is `NotApp`.
read_app! : Fx, Args, ToolBuild.Facts, Index.Candidate => Try(Try(ToolBuild.Bundle, [NotApp]), Fail)
read_app! = |fx, args, facts, cand| read_bundle!(fx, args, facts, { version: cand.ident.version, url: cand.url, hash: cand.ident.hash })

# The bundle of one release: fetched when its dir is missing, its `main.roc` read as an app header. `dir` is the package dir, the source is the release, there is no `--path`.
read_bundle! : Fx, Args, ToolBuild.Facts, { version : Str, url : Str, hash : Str } => Try(Try(ToolBuild.Bundle, [NotApp]), Fail)
read_bundle! = |fx, args, facts, rel| {
	text = package_text!(fx, args, facts, { url: rel.url, hash: rel.hash })?
	dir = Roots.item(facts.roots, Item.Package(rel.hash))
	match ToolBuild.app_header({ path: Text.join(dir, "main.roc"), text })? {
		Ok(header) => Ok(Ok({ version: rel.version, url: rel.url, hash: rel.hash, dir, source: Release({ version: rel.version, url: rel.url }), path: Err(None), pin: header.pin, pf: header.pf, hashes: header.hashes }))
		Err(NotApp) => Ok(Err(NotApp))
	}
}

# The text of the `main.roc` of a package that is fetched when its dir is missing (R-FE2, R-FE7).
package_text! : Fx, Args, ToolBuild.Facts, { url : Str, hash : Str } => Try(Str, Fail)
package_text! = |fx, args, facts, pkg| {
	match Fetch.packages!(fx, { roots: facts.roots, urls: [pkg.url], offline: args.offline, unbundler: Choose({ selected: facts.selected, none: Download({ scope: Outside, exclude: [], downloads: downloads_of(args, facts) }) }), downloader: facts.net.downloader }) {
		[Ok(_)] => {}
		[Err(fail)] => return Err(fail)
		_ => return Err(Fail.new(Internal, "the fetch of ${pkg.url} gave no answer"))
	}
	path = Text.join(Roots.item(facts.roots, Item.Package(pkg.hash)), "main.roc")
	match fx.read_files!([path]) {
		[Ok(text)] => Ok(text)
		_ => Err(Fail.new(Environment, "cannot read ${path}"))
	}
}

# R-FE4, R-SO14 (2), R-DL1 to R-DL6: the consent facts of the download of a compiler that the unpack of a bundle needs. `tool install` has no `--allow-downloads`.
downloads_of : Args, ToolBuild.Facts -> Start.Downloads
downloads_of = |args, facts| {
	auto: Consent.auto_install(facts.env),
	allow: Err(NoFlag),
	yes: args.yes,
	mode: Mode.from_env({ env: Dict.from_list(facts.env), json: args.json }),
	quiet: args.quiet,
	offline: args.offline,
	env: facts.env,
}

# Step 8b (R-T2): the platform of the app must make a native executable. A path entry and a header with no `targets` are admitted.
check_platform! : Fx, Args, ToolBuild.Facts, ToolBuild.Bundle => Try({}, Fail)
check_platform! = |fx, args, facts, bundle| match bundle.pf {
	Err(None) => Ok({})
	Ok(url) => match Ident.of_url(url) {
		Err(Foreign) => Ok({})
		Ok(ident) => {
			text = package_text!(fx, args, facts, { url, hash: ident.hash })?
			match ToolInstall.native(BuildTarget.targets_of(text)) {
				Native => Ok({})
				WasmOnly(names) => Err(ToolInstall.not_native({ name: facts.name, version: bundle.version, hash: ident.hash, names }))
			}
		}
	}
}

# Steps 9 to 12: the compiler (`ToolCompilerFlow.choose!`: the pin, the evidence, the prompt, option 2), the build, then the install.
compile! : Fx, Args, ToolInstall.Plan, ToolBuild.Facts, ToolBuild.Bundle => Try(ToolBuild.Done, Fail)
compile! = |fx, args, plan, facts, bundle| {
	chosen = choose!(fx, args, { roc: plan.roc }, facts, bundle)?
	ToolBuild.finish!(fx, args, facts, bundle, chosen)
}

# Step 9 (R-X1): the compiler choice (`ToolCompilerFlow.choose!`: the pin, the evidence, the prompt, option 2) with the run facts of the build.
choose! : Fx, Args, { roc : [Auto, Pinned, Installed] }, ToolBuild.Facts, ToolBuild.Bundle => Try(ToolCompilerFlow.Chosen, Fail)
choose! = |fx, args, plan, facts, bundle| {
	run = {
		env: facts.env,
		roots: facts.roots,
		now: facts.now,
		target: facts.target,
		name: facts.name,
		version: bundle.version,
		bundle: bundle.hash,
		pin: bundle.pin,
		pf: ToolBuild.pf_hash(bundle),
		hashes: bundle.hashes,
		roc: plan.roc,
		timeout: facts.probe_timeout,
		selected: ToolFlow.selected_for!(fx, facts),
	}
	ToolCompilerFlow.choose!(fx, args, run, { build: |req| ToolBuild.attempt!(fx, args, facts, bundle, req) })
}

# R-SO6, R-SO24 case 3: rank 6 with no `default-roc` is the newest installed nightly or release. One `list_dirs!`, and the note on stderr when a compiler is found. `""` when none is installed.
newest_of! : Fx, ToolBuild.Facts => Str
newest_of! = |fx, facts| match Compiler.newest_installed({ installed: Launch.toolchains!(fx, facts.roots), times: [] }) {
	Ok(id) => {
		fx.err!("note: ${Compiler.newest_note(id)}\n")
		id
	}
	Err(None) => ""
}

# R-SO2: `ROC_TOOLCHAIN` (rank 2), `""` when it is not set.
toolchain_env : List((Str, Str)) -> Str
toolchain_env = |env| match env.find_first(|(name, _)| name == "ROC_TOOLCHAIN") {
	Ok((_, text)) => text
	Err(_) => ""
}

# Step 13: the line on stdout (`--quiet` hides it), or with `--json` the line on stderr and the envelope on stdout.
print! : Fx, Args, ToolBuild.Done => {}
print! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	shown.out!(ToolInstall.report({ how: done.how, key: done.key, name: done.name, version: done.version }))
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: ToolInstall.data(done) }))
	}
}
