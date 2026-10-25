import Args
import Clock
import ConfigToml
import Fail
import Fx
import Ident
import Item
import Launch
import Locked
import Net
import Probe
import Release
import Roots
import Setup
import SetupIo
import Temp
import Text
import ToolCompiler
import ToolCompilerFlow
import ToolInstall
import ToolsJson

## Steps 7b and 10 to 13 of `tln tool install` (slice 047, cut from `ToolFlow` as the slice file plans): one build attempt, the install under the lock of `tools.json`, the check of the bin dir entry. Command code over `Fx`. `ToolFlow` gathers the facts and calls `ToolCompilerFlow.choose!` with `attempt!`, then `finish!`.
## The calls, in order: the rows 7b and 10 to 13 of the table of `ToolFlow`.
ToolBuild :: [].{

	# What the command did, as `ToolInstall.report` and `ToolInstall.data` need it.
	Done : { how : ToolInstall.How, key : Str, name : Str, version : Str, bin : Str, built : Try({ url : Str, nightly : Str, target : Str, sha256 : Str, entry : [HardLink, Copy] }, [None]) }

	# What steps 2 to 5 found. `file` is the name of the binary file and of the bin dir entry (R-ST15).
	Facts : { env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, os : Setup.Os, bin : Str, target : Str, entries : List(ToolsJson.Entry), min_age : U64, probe_timeout : U64, name : Str, key : Str, file : Str }

	# The app that step 8 chose (slice 048: a release bundle or a git source). `version` is the text of the reports (`1.1.0`, `git main@dd03c09e`), `url` the bundle (for a git source the archive), `hash` the closure of the evidence (the hash of the bundle, or the commit),
	# `dir` the dir that the build runs in, `source` and `path` what `tools.json` records, then the `roc:` pin, the platform entry and the hashes of the release URL entries of the header (D13).
	Bundle : { version : Str, url : Str, hash : Str, dir : Str, source : ToolsJson.Source, path : Try(Str, [None]), pin : Try(Str, [NoPin]), pf : Try(Str, [None]), hashes : List(Str) }

	# Step 10: one build attempt in its own temp dir. A build that does not pass, or a failed call, deletes the temp dir (R-CC2). The passed attempt keeps it for the install.
	attempt! : Fx, Args, Facts, Bundle, { id : Str, first : Bool } => Try(ToolCompiler.Attempt, Fail)
	attempt! = |fx, args, facts, bundle, req| {
		hex = Temp.hex(fx.random!())
		base = ToolInstall.layout({ roots: facts.roots, bin: facts.bin, os: facts.os, key: facts.key, hash: bundle.hash, hex })
		layout = { ..base, dir: bundle.dir }
		result = build_in!(fx, args, facts, { bundle, req, layout })
		passed = match result {
			Ok(done) => match done.class {
				Pass => Bool.True
				_ => Bool.False
			}
			Err(_) => Bool.False
		}
		if !passed {
			_ = fx.delete!([layout.temp])
		}
		result
	}

	# Steps 11 to 13: the attempt that option 2 passed, else one build with the chosen compiler. Then the install under the lock for the last step only (R-CC6). The temp dir goes also after a failure (R-CC2).
	finish! : Fx, Args, Facts, Bundle, ToolCompilerFlow.Chosen => Try(Done, Fail)
	finish! = |fx, args, facts, bundle, chosen| {
		got = match chosen.passed {
			Ok(layout) => Ok({ class: Pass, errors: [], layout })
			Err(None) => attempt!(fx, args, facts, bundle, { id: chosen.id, first: chosen.first })
		}
		attempt = got?
		ctx = { facts, bundle, id: chosen.id, layout: attempt.layout }
		match attempt.class {
			Pass => {
				result = fx.locked!(Roots.item(facts.roots, Item.ToolsJson), || install!(fx, ctx))
				_ = fx.delete!([attempt.layout.temp])
				result
			}
			class => Err(build_failure(ctx, class, attempt.errors))
		}
	}

	# Steps 7b and 12 (R-ST6, R-ST11): may the bin dir entry be written? The same check runs before the download and again under the lock.
	entry_verdict! : Fx, Facts => Try({}, Fail)
	entry_verdict! = |fx, facts| match ToolBuild.entry_state!(fx, facts)? {
		Make => Ok({})
		Foreign => Err(ToolInstall.foreign_failure(Text.join(facts.bin, facts.file)))
	}

	# The calls of `entry_verdict!` without the failure text. Slice 048: `tool rebuild` and `tool update` have a text of their own for `Foreign` (no `--as`).
	entry_state! : Fx, Facts => Try([Make, Foreign], Fail)
	entry_state! = |fx, facts| {
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
		Ok(ToolInstall.verdict({ old, have }))
	}

	# R-T1, R-T10: the header of a `main.roc` that was read. An app gives its `roc:` pin, its platform entry and the hashes of its release URL entries (D13). A package or a platform is `NotApp`. A bad header is the failure of `Release.read` or `Locked.read`.
	app_header : { path : Str, text : Str } -> Try(Try({ pin : Try(Str, [NoPin]), pf : Try(Str, [None]), hashes : List(Str) }, [NotApp]), Fail)
	app_header = |facts| {
		release = Release.read(facts)?
		match release.kind {
			App => {
				locked = Locked.read(facts)?
				hashes = locked.rows.keep_oks(
					|row| match row.what {
						Release(ident) => Ok(ident.hash)
						_ => Err(NoHash)
					},
				)
				Ok(Ok({ pin: locked.roc, pf: release.pf, hashes }))
			}
			_ => Ok(Err(NotApp))
		}
	}

	# R-T18: `probe.timeout` of `config.toml`, the timeout of the checks of option 2.
	probe_timeout : ConfigToml.Config -> U64
	probe_timeout = |config| Probe.settings({ flag_slots: Err(Unset), project: { max: Err(Unset), timeout: Err(Unset), slots: Err(Unset), max_toolchains: Err(Unset) }, user: config.probe }).timeout

	# The hash of the platform of the app (`Err(None)` for a path entry or a foreign URL).
	pf_hash : Bundle -> Try(Str, [None])
	pf_hash = |bundle| match bundle.pf {
		Ok(value) => Ident.of_url(value).map_ok(|ident| ident.hash).map_err(|Foreign| None)
		Err(None) => Err(None)
	}
}

# What the steps under the lock need.
Ctx : { facts : ToolBuild.Facts, bundle : ToolBuild.Bundle, id : Str, layout : ToolInstall.Layout }

# Step 10 (R-SE8, R-T11, R-T8): the header lines (the platform line for the first attempt only, D-E9), the compiler, one `probes!` with `ToolInstall.build_spec`.
build_in! : Fx, Args, ToolBuild.Facts, { bundle : ToolBuild.Bundle, req : { id : Str, first : Bool }, layout : ToolInstall.Layout } => Try(ToolCompiler.Attempt, Fail)
build_in! = |fx, args, facts, run| {
	id = run.req.id
	if !args.quiet {
		pf = if run.req.first run.bundle.pf else Err(None)
		for line in ToolInstall.header_lines({ name: facts.name, version: run.bundle.version, id, pf, hash: ToolBuild.pf_hash(run.bundle) }) {
			fx.err!("${line}\n")
		}
	}
	installed = Launch.toolchains!(fx, facts.roots)
	program = Launch.program!(fx, { roots: facts.roots, id, installed, path: Err(NoCompiler) })?
	Launch.touch!(fx, facts.roots, { id, now: facts.now })
	env = Launch.child_env!(fx, facts.roots, { opted_out: Bool.False })
	spec = ToolInstall.build_spec({ id, program, env, dir: run.layout.dir, output: run.layout.output })
	match fx.make_dirs!([run.layout.temp]) {
		Ok(_) => {}
		Err(err) => return Err(Fail.new(Environment, "cannot make ${run.layout.temp}: ${Str.inspect(err)}"))
	}
	out = match fx.probes!({ pool: 12, specs: [spec] }) {
		[one] => one
		_ => return Err(Fail.new(Internal, "probes! gave no result"))
	}
	Ok({ class: Probe.classify(out), errors: Probe.errors({ text: out.stderr, dir: run.layout.dir, pkgs: facts.roots.pkgs }), layout: run.layout })
}

build_failure : Ctx, Probe.Class, List(Probe.Err) -> Fail
build_failure = |ctx, class, errors| ToolInstall.build_failed({ name: ctx.facts.name, version: ctx.bundle.version, id: ctx.id, class, errors, output: ctx.layout.output })

# Steps 11 and 12, under the lock: `tools.json` again, the clash again (R-CC6), the check of the entry again, the files, then `tools.json`.
install! : Fx, Ctx => Try(ToolBuild.Done, Fail)
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
	ToolBuild.entry_verdict!(fx, facts)?
	sha = write_binary!(fx, ctx)?
	form = write_entry!(fx, ctx.layout)?
	tool = {
		key: facts.key,
		name: facts.name,
		source: ctx.bundle.source,
		path: ctx.bundle.path,
		hashes: ctx.bundle.hashes,
		nightly: ctx.id,
		target: facts.target,
		sha256: sha,
		libs: [],
		installed_at: Clock.format_utc(facts.now),
	}
	updated = ToolsJson.put({ path: tools_file, text, tool })?
	SetupIo.write_file!(fx, tools_file, updated)?
	Ok({
		how,
		key: facts.key,
		name: facts.name,
		version: ctx.bundle.version,
		bin: ctx.layout.entry,
		built: Ok({ url: ctx.bundle.url, nightly: ctx.id, target: facts.target, sha256: sha, entry: form }),
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
