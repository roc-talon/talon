import Args
import BuildSkip
import BuildTarget
import Clock
import Common
import Consent
import Fail
import Fetch
import Fx
import Github
import Ident
import Index
import Item
import Launch
import Locked
import Lookup
import Net
import Out
import Probe
import Release
import RocInstall
import Roots
import Scope
import Setup
import SetupIo
import Temp
import Text
import ToolInstall
import ToolsJson

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
## | 9 | `Launch.toolchains!` (one `list_dirs!`), `ToolInstall.compiler`. `Missing`: `ToolInstall.want`, then `RocInstall.offer!`, the line `Consent.optional_line` on stderr and `RocInstall.install_offer!` (R-T6). | R-T11, R-T12, R-T6, R-DL1 |
## | 10 | `random!`, `ToolInstall.layout`, `ToolInstall.header_lines` on stderr. `Launch.program!`, `Launch.touch!`, `Launch.child_env!`, `make_dirs!` of the temp dir, one `probes!` with `ToolInstall.build_spec`. A result that is not a pass: `ToolInstall.build_failed`. | R-SE8, R-T11, R-T8, R-T5, R-CC9, R-PX6 |
## | 11 | The lock of `tools.json` (`Fx.locked!` on `Roots.item(ToolsJson)`, `Wait`, R-CC3), for the last step only (R-CC6): `read_files!` and `ToolsJson.read` again, `ToolsJson.clash` again (`Taken`, `Elsewhere`), `list_dirs!` of the bin dir, `SetupIo.have_of!`, `sha256_file!` of the old binary, `ToolInstall.verdict` (`Foreign`: exit 2, nothing is written). | R-CC6, R-T28, R-ST6, R-ST11 |
## | 12 | Under the lock: the check of step 7b again (`entry_verdict!`: the file can appear during the build), then `make_dirs!` of the data bin dir and the bin dir, `copy_file!` of the output to the temp name, `rename!` (R-CC1), `sha256_file!` of the binary, `hard_link!` to the temp name of the entry (else `copy_file!`), `rename!`, then `write_atomic!` of `tools.json` (`ToolsJson.add`). | R-T3, R-T4, R-ST7, R-ST15, R-CC1 |
## | 13 | `delete!` of the temp dir (also after a failure, R-CC2). The output: `ToolInstall.report` (`--quiet` hides it, R-FL4). With `--json` the text goes to stderr and stdout is `Out.json_ok` with `ToolInstall.data`. | R-J1 to R-J4, R-OUT2 |
ToolFlow :: [].{

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
}

# What the command did, as `ToolInstall.report` and `ToolInstall.data` need it.
Done : { how : ToolInstall.How, key : Str, name : Str, version : Str, bin : Str, built : Try({ url : Str, nightly : Str, target : Str, sha256 : Str, entry : [HardLink, Copy] }, [None]) }

# What steps 2 to 5 found. `file` is the name of the binary file and of the bin dir entry (R-ST15).
Facts : { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, os : Setup.Os, bin : Str, target : Str, entries : List(ToolsJson.Entry), min_age : U64, name : Str, key : Str, file : Str }

# The app bundle that step 8 chose: the release, the `roc:` pin, the platform entry and the hashes of the release URL entries of the header (D13).
Bundle : { cand : Index.Candidate, pin : Try(Str, [NoPin]), pf : Try(Str, [None]), hashes : List(Str) }

# What the steps under the lock need.
Ctx : { facts : Facts, bundle : Bundle, id : Str, layout : ToolInstall.Layout }

# Steps 2 to 13.
flow! : Fx, Args, ToolInstall.Plan => Try(Done, Fail)
flow! = |fx, args, plan| {
	facts = gather!(fx, plan)?
	list = release_list!(fx, args, facts)?
	picked = ToolInstall.pick({ name: facts.name, list, selector: plan.ref.selector, now: facts.now, min_age: facts.min_age })?
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
	notes!(fx, facts, picked, newest)
	entry_verdict!(fx, facts)?
	bundle = first_app!(fx, args, facts, picked.order)?
	check_platform!(fx, args, facts, bundle)?
	id = compiler_id!(fx, args, plan, facts, bundle)?
	build!(fx, args, facts, { bundle, id })
}

# Steps 2 to 5: the machine, `tools.json`, `config.toml`, the full name, the binary name.
gather! : Fx, ToolInstall.Plan => Try(Facts, Fail)
gather! = |fx, plan| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	net = Net.from_env(env)
	now = Clock.now!(fx, env)?
	machine = fx.platform!()
	bin = Setup.bin_dir({ os: machine.os, env })?
	target = match BuildSkip.target(machine) {
		Ok(known) => known
		Err(Unknown) => return Err(Fail.new(Environment, "tln has no build target for this machine"))
	}
	tools_file = Roots.item(roots, Item.ToolsJson)
	entries = ToolsJson.read({ path: tools_file, text: SetupIo.read_text!(fx, tools_file)? })?
	config = RocInstall.read_config!(fx, roots)?
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
	Ok({ env, roots, net, now, os: machine.os, bin, target, entries, min_age: config.min_release_age ?? 172800, name, key, file: ToolInstall.file_name({ os: machine.os, key }) })
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
release_list! : Fx, Args, Facts => Try(List(Index.Candidate), Fail)
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
default_branch! : Fx, Args, Facts => Try(Str, [None])
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

# Step 7 (R-T9): the notes on stderr for a build.
notes! : Fx, Facts, ToolInstall.Picked, Index.Candidate => {}
notes! = |fx, facts, picked, newest| {
	match picked.note {
		Ok(note) => fx.err!("note: ${note}\n")
		Err(None) => {}
	}
	if picked.young {
		fx.err!("${ToolInstall.age_note({ name: facts.name, version: newest.ident.version, published_at: newest.published_at })}\n")
	}
}

# Steps 7b and 12 (R-ST6, R-ST11): may the bin dir entry be written? The same check runs before the download and again under the lock.
entry_verdict! : Fx, Facts => Try({}, Fail)
entry_verdict! = |fx, facts| {
	entry = Text.join(facts.bin, facts.file)
	data_file = Text.join(Roots.item(facts.roots, Item.Bin), facts.file)
	listed = match fx.list_dirs!([facts.bin]) {
		[one] => SetupIo.entries_of(one, facts.bin)?
		_ => return Err(Fail.new(Internal, "list_dirs! gave no result"))
	}
	have = SetupIo.have_of!(fx, facts.bin, listed, facts.file)
	old = match fx.sha256_file!(data_file) {
		Ok(sha) => Ok(sha)
		Err(NotFound) => Err(NotFound)
		Err(err) => return Err(Fail.new(Environment, "cannot read ${data_file}: ${Str.inspect(err)}"))
	}
	match ToolInstall.verdict({ old, have }) {
		Make => Ok({})
		Foreign => Err(ToolInstall.foreign_failure(entry))
	}
}

# Step 8 (R-T10, R-T1): the first candidate, newest first, whose bundle is an app. None left is the failure of R-T10 with the newest tag.
first_app! : Fx, Args, Facts, List(Index.Candidate) => Try(Bundle, Fail)
first_app! = |fx, args, facts, order| {
	match try_each!(fx, args, facts, order)? {
		Ok(bundle) => Ok(bundle)
		Err(None) => Err(ToolInstall.no_candidate({ name: facts.name, newest: ToolInstall.newest_tag(order), branch: Err(None) }))
	}
}

try_each! : Fx, Args, Facts, List(Index.Candidate) => Try(Try(Bundle, [None]), Fail)
try_each! = |fx, args, facts, rest| match rest {
	[] => Ok(Err(None))
	[cand, .. as more] => match read_app!(fx, args, facts, cand)? {
		Ok(bundle) => Ok(Ok(bundle))
		Err(NotApp) => try_each!(fx, args, facts, more)
	}
}

# One candidate: fetch the bundle, read its header (R-T1). A bundle that is no app is `NotApp`.
read_app! : Fx, Args, Facts, Index.Candidate => Try(Try(Bundle, [NotApp]), Fail)
read_app! = |fx, args, facts, cand| {
	text = package_text!(fx, args, facts, { url: cand.url, hash: cand.ident.hash })?
	path = Text.join(Roots.item(facts.roots, Item.Package(cand.ident.hash)), "main.roc")
	release = Release.read({ path, text })?
	match release.kind {
		App => {
			locked = Locked.read({ path, text })?
			hashes = locked.rows.keep_oks(
				|row| match row.what {
					Release(ident) => Ok(ident.hash)
					_ => Err(NoHash)
				},
			)
			Ok(Ok({ cand, pin: locked.roc, pf: release.pf, hashes }))
		}
		_ => Ok(Err(NotApp))
	}
}

# The text of the `main.roc` of a package that is fetched when its dir is missing (R-FE2, R-FE7).
package_text! : Fx, Args, Facts, { url : Str, hash : Str } => Try(Str, Fail)
package_text! = |fx, args, facts, pkg| {
	match Fetch.packages!(fx, { roots: facts.roots, urls: [pkg.url], offline: args.offline, roc: "roc", downloader: facts.net.downloader }) {
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

# Step 8b (R-T2): the platform of the app must make a native executable. A path entry and a header with no `targets` are admitted.
check_platform! : Fx, Args, Facts, Bundle => Try({}, Fail)
check_platform! = |fx, args, facts, bundle| match bundle.pf {
	Err(None) => Ok({})
	Ok(url) => match Ident.of_url(url) {
		Err(Foreign) => Ok({})
		Ok(ident) => {
			text = package_text!(fx, args, facts, { url, hash: ident.hash })?
			match ToolInstall.native(BuildTarget.targets_of(text)) {
				Native => Ok({})
				WasmOnly(names) => Err(ToolInstall.not_native({ name: facts.name, version: bundle.cand.ident.version, hash: ident.hash, names }))
			}
		}
	}
}

# Step 9 (R-T11, R-T12, R-T6): the compiler of the pin. A pin that is not installed needs the consent of `ToolInstall.want`.
compiler_id! : Fx, Args, ToolInstall.Plan, Facts, Bundle => Try(Str, Fail)
compiler_id! = |fx, args, plan, facts, bundle| match ToolInstall.compiler({ pin: bundle.pin, installed: Launch.toolchains!(fx, facts.roots) }) {
	NoPin => Err(ToolInstall.no_pin({ name: facts.name, version: bundle.cand.ident.version }))
	Use(id) => Ok(id)
	Missing(id) => match ToolInstall.want({ id, roc: plan.roc, auto: Consent.auto_install(facts.env), yes: args.yes }) {
		Stop(fail) => Err(fail)
		Install => {
			_ = RocInstall.fetch_optional!(fx, { id, env: facts.env, offline: args.offline })?
			Ok(id)
		}
	}
}

# Steps 10 to 13: the build, then the install under the lock. The temp dir goes also after a failure (R-CC2).
build! : Fx, Args, Facts, { bundle : Bundle, id : Str } => Try(Done, Fail)
build! = |fx, args, facts, chosen| {
	hex = Temp.hex(fx.random!())
	layout = ToolInstall.layout({ roots: facts.roots, bin: facts.bin, os: facts.os, key: facts.key, hash: chosen.bundle.cand.ident.hash, hex })
	version = chosen.bundle.cand.ident.version
	if !args.quiet {
		pf_hash = match chosen.bundle.pf {
			Ok(value) => Ident.of_url(value).map_ok(|ident| ident.hash).map_err(|Foreign| None)
			Err(None) => Err(None)
		}
		for line in ToolInstall.header_lines({ name: facts.name, version, id: chosen.id, pf: chosen.bundle.pf, hash: pf_hash }) {
			fx.err!("${line}\n")
		}
	}
	installed = Launch.toolchains!(fx, facts.roots)
	program = Launch.program!(fx, { roots: facts.roots, id: chosen.id, installed, path: Err(NoCompiler) })?
	Launch.touch!(fx, facts.roots, { id: chosen.id, now: facts.now })
	env = Launch.child_env!(fx, facts.roots, { opted_out: Bool.False })
	spec = ToolInstall.build_spec({ id: chosen.id, program, env, dir: layout.dir, output: layout.output })
	result = built!(fx, { facts, bundle: chosen.bundle, id: chosen.id, layout }, spec)
	_ = fx.delete!([layout.temp])
	result
}

# Step 10 (R-T11, R-T8) and steps 11, 12: the build in the temp dir, then the lock of `tools.json` for the install only (R-CC6).
built! : Fx, Ctx, Probe.Spec => Try(Done, Fail)
built! = |fx, ctx, spec| {
	match fx.make_dirs!([ctx.layout.temp]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${ctx.layout.temp}: ${Str.inspect(err)}"))
	}
	out = match fx.probes!({ pool: 12, specs: [spec] }) {
		[one] => one
		_ => return Err(Fail.new(Internal, "probes! gave no result"))
	}
	class = Probe.classify(out)
	match class {
		Pass => {}
		_ => return Err(build_failure(ctx, class, Probe.errors({ text: out.stderr, dir: ctx.layout.dir, pkgs: ctx.facts.roots.pkgs })))
	}
	fx.locked!(Roots.item(ctx.facts.roots, Item.ToolsJson), || install!(fx, ctx))
}

build_failure : Ctx, Probe.Class, List(Probe.Err) -> Fail
build_failure = |ctx, class, errors| ToolInstall.build_failed({ name: ctx.facts.name, version: ctx.bundle.cand.ident.version, id: ctx.id, class, errors, output: ctx.layout.output })

# Steps 11 and 12, under the lock: `tools.json` again, the clash again (R-CC6), the check of the entry again, the files, then `tools.json`.
install! : Fx, Ctx => Try(Done, Fail)
install! = |fx, ctx| {
	facts = ctx.facts
	tools_file = Roots.item(facts.roots, Item.ToolsJson)
	text = SetupIo.read_text!(fx, tools_file)?
	entries = ToolsJson.read({ path: tools_file, text })?
	how = match ToolsJson.clash({ entries, key: facts.key, name: facts.name }) {
		Taken(other) => return Err(ToolInstall.clash_failure({ key: facts.key, taken: other.name, name: facts.name }))
		Elsewhere(other) => return Err(ToolInstall.elsewhere_failure({ key: other.key, name: facts.name }))
		Same(old) => Replaced(source_text(old.source))
		Free => Installed
	}
	entry_verdict!(fx, facts)?
	sha = write_binary!(fx, ctx)?
	form = write_entry!(fx, ctx.layout)?
	built = {
		key: facts.key,
		name: facts.name,
		version: ctx.bundle.cand.ident.version,
		url: ctx.bundle.cand.url,
		hashes: ctx.bundle.hashes,
		nightly: ctx.id,
		target: facts.target,
		sha256: sha,
		libs: [],
		installed_at: Clock.format_utc(facts.now),
	}
	updated = ToolsJson.add({ path: tools_file, text, built })?
	SetupIo.write_file!(fx, tools_file, updated)?
	Ok({
		how,
		key: facts.key,
		name: facts.name,
		version: built.version,
		bin: ctx.layout.entry,
		built: Ok({ url: built.url, nightly: ctx.id, target: facts.target, sha256: sha, entry: form }),
	})
}

# The old source as the report shows it: the version of a release, `git <ref>` of a git build.
source_text : ToolsJson.Source -> Str
source_text = |source| match source {
	Release(rel) => rel.version
	Git(git) => "git ${git.ref}"
}

# Step 12 (R-T3, R-CC1): the output goes to a temp name in the data bin dir, then a rename. A build that made no file is `Pass` with no output.
write_binary! : Fx, Ctx => Try(Str, Fail)
write_binary! = |fx, ctx| {
	lay = ctx.layout
	match fx.make_dirs!([lay.data_bin, lay.bin]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${lay.data_bin}: ${Str.inspect(err)}"))
	}
	match fx.copy_file!({ from: lay.output, to: lay.data_tmp }) {
		Ok(_) => {}
		Err(NotFound) => return Err(build_failure(ctx, Pass, []))
		Err(err) => return Err(Fail.new(Environment, "cannot copy ${lay.output} to ${lay.data_tmp}: ${Str.inspect(err)}"))
	}
	match fx.rename!({ from: lay.data_tmp, to: lay.data_file }) {
		Ok(_) => {}
		Err(err) => return Err(SetupIo.dropped!(fx, lay.data_tmp, "cannot make ${lay.data_file}: ${Str.inspect(err)}"))
	}
	match fx.sha256_file!(lay.data_file) {
		Ok(sha) => Ok(sha)
		Err(err) => Err(Fail.new(Environment, "cannot read ${lay.data_file}: ${Str.inspect(err)}"))
	}
}

# Step 12 (R-ST7, R-CC1): the bin dir entry is a hard link to the binary, else a copy, at a temp name, then a rename.
write_entry! : Fx, ToolInstall.Layout => Try([HardLink, Copy], Fail)
write_entry! = |fx, lay| {
	form = match fx.hard_link!({ from: lay.data_file, to: lay.entry_tmp }) {
		Ok(_) => HardLink
		Err(_) => match fx.copy_file!({ from: lay.data_file, to: lay.entry_tmp }) {
			Ok(_) => Copy
			Err(err) => return Err(SetupIo.dropped!(fx, lay.entry_tmp, "cannot make ${lay.entry}: ${Str.inspect(err)}"))
		}
	}
	match fx.rename!({ from: lay.entry_tmp, to: lay.entry }) {
		Ok(_) => Ok(form)
		Err(err) => Err(SetupIo.dropped!(fx, lay.entry_tmp, "cannot make ${lay.entry}: ${Str.inspect(err)}"))
	}
}

# Step 13: the line on stdout (`--quiet` hides it), or with `--json` the line on stderr and the envelope on stdout.
print! : Fx, Args, Done => {}
print! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	shown.out!(ToolInstall.report({ how: done.how, key: done.key, name: done.name, version: done.version }))
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: ToolInstall.data(done) }))
	}
}
