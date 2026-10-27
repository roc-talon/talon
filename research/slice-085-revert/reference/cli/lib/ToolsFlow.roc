import Args
import Clock
import Common
import Fail
import Fetch
import Fx
import Install
import Intent
import Known
import Out
import RocInstall
import Setting
import Text
import ToolBuild
import Selector
import ToolsCmd
import ToolsPlan
import ToolsStep
import ToolsToml
import XCacheIo

## The commands with `--tool` (slice 056, CLI 6.4: R-PT3, R-PT5, R-PT12, R-FL7, R-FL12): `tln add --tool owner/app[@sel] [--as <key>]`, `tln remove --tool <key>...`, `tln update --tool [<key>...]`, `tln upgrade --tool [<key>...]`.
## Direct style over `Fx` (TESTING.md 2.2 part C). `ToolsCmd` reads the line, `ToolsPlan` and `ToolsToml` decide, `ToolsStep` selects, builds and writes. `Run.tln!` calls `run!` when the line has `--tool` (`ToolsCmd.op_of`), before `check_refs`.
## The commands never read or write `tools.json`, never lock it, and make no bin dir entry (R-PT12). They run no resolve of the header: no probe, no ladder, no `on_path!`, no compiler gate.
##
## The calls, in order (the L2 cases `ptool/pt1-add` and `ptool/pt3-move` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `ToolsCmd.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-FL7, R-FL12 |
## | 2 | `Install.begin!` (`env_all!`, `clock!`, `Project.find!`), `Known.record!` of the member files (as `install`: also a run that fails later). A workspace root with no current member is allowed (the file is the root file). | R-PD9, R-PT2 |
## | 3 | `ToolsPlan.home`, one `read_files!` of that `talon.toml` (a missing file is the empty text, R-PT3), `Intent.read` with the role `Root` (the warnings on stderr), `RocInstall.read_config!` (one `read_files!`: `min-release-age`, `probe.timeout`). | R-PT2, R-TF4, R-C7 |
## | 4 | `remove`: the keys must be in `[tools]` (`ToolsCmd.no_key`), then step 8. No build, no network. | R-PT3 |
## | 5 | `add`: `ToolsCmd.key_of`. A key that is in `[tools]` with the same app acts as `update <key>`, with another app it is `ToolsCmd.key_taken`. | R-PT3 |
## | 6 | `update` and `upgrade`: the keys must be in `[tools]`. `ToolsStep.run!` with the phase `Update` or `Upgrade` and the keys (`[]` is each entry). | R-PT5 |
## | 7 | `add` (a new key): `ToolsStep.machine!`, `XCacheIo.entries!`, `ToolsStep.pick!` (the release list, the pick), `ToolsStep.chosen!` (the bundle), `ToolsStep.ensure!` (the build), then the entry `ToolsPlan.add_ref`. | R-PT3, R-PT4, R-PT6 |
## | 8 | `ToolsStep.write!` (one write for all changes, none for `--dry-run`), the lines (`ToolsStep.print!`, `nothing to change` when no row changed), `dry run: nothing was written` for `--dry-run`, with `--json` the envelope `ToolsStep.data`. | R-CC7, R-LF4, R-J3 |
ToolsFlow :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match ToolsCmd.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(cmd) => match flow!(fx, args, cmd) {
			Ok(done) => {
				print!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# What the command did: the context (the file, the flags), and the rows and changes.
Done : { ctx : ToolsStep.Ctx, done : ToolsStep.Done }

# Steps 2 to 8.
flow! : Fx, Args, ToolsCmd.Cmd => Try(Done, Fail)
flow! = |fx, args, cmd| {
	ctx = context!(fx, args, cmd)?
	done = match cmd.op {
		Add => add!(fx, ctx, cmd)?
		Remove => remove!(ctx, cmd)?
		Update => moved!(fx, ctx, cmd, Update)?
		Upgrade => moved!(fx, ctx, cmd, Upgrade)?
	}
	ToolsStep.write!(fx, ctx, done.changes)?
	Ok({ ctx, done })
}

# Steps 2 and 3: the project, the record, the file of `[tools]`, its text and the `config.toml`.
context! : Fx, Args, ToolsCmd.Cmd => Try(ToolsStep.Ctx, Fail)
context! = |fx, args, cmd| {
	start = Install.begin_loose!(fx, args)?
	place = match start.project {
		Ok(project) => {
			files = Install.canonical_files!(fx, project)
			{ files, home: Err(project) }
		}
		Err(fail) => if ToolsPlan.no_project(fail) {
			file = Text.join(start.cwd, "talon.toml")
			{ files: [file], home: Ok(file) }
		} else {
			return Err(fail)
		}
	}
	Known.record!(fx, { roots: start.roots, files: place.files, now: start.now })?
	home = match place.home {
		Ok(file) => file
		Err(project) => ToolsPlan.home({ workspace: project.workspace, file: project.file })?
	}
	text = RocInstall.read_text!(fx, home)?
	read = Intent.read({ path: home, text, role: Root })?
	for w in read.warnings {
		fx.err!("warning: ${w}\n")
	}
	config = RocInstall.read_config!(fx, start.roots)?
	Ok({
		args,
		env: start.env,
		roots: start.roots,
		net: start.net,
		now: start.now,
		min_age: Setting.pick({ flag: Err(Unset), env: Err(Unset), project: read.intent.resolution.min_release_age, user: config.min_release_age }) ?? 172800,
		probe_timeout: ToolBuild.probe_timeout(config),
		snapshot: snapshot_of(cmd, read.intent)?,
		dry_run: cmd.dry_run,
		allow: cmd.allow_downloads == Ok(Yes),
		home,
		home_text: text,
		tools: read.intent.tools,
		selected: Fetch.selected({ held: "", default: config.default_roc ?? "" }),
	})
}

# R-DT4, R-EV1: `--snapshot` wins over `[resolution] snapshot`. A `log:<n>` needs a registry: direct has none.
snapshot_of : ToolsCmd.Cmd, Intent -> Try(Try(U64, [None]), Fail)
snapshot_of = |cmd, intent| match cmd.snapshot {
	Err(Unset) => Intent.direct_snapshot(intent.resolution.snapshot)
	Ok(text) => {
		bad = Fail.new(Usage, "--snapshot '${text}' is not a UTC time or log:<n>. Use a UTC time, for example 2026-10-12T00:00:00Z.")
		if text.starts_with("log:") {
			match U64.from_str(text.drop_prefix("log:")) {
				Ok(n) => Intent.direct_snapshot(Ok(Log(n)))
				Err(_) => Err(bad)
			}
		} else {
			match Clock.parse_utc(text) {
				Ok(seconds) => Ok(Ok(seconds))
				Err(BadTime) => Err(bad)
			}
		}
	}
}

# Steps 5 and 7: a new key builds the release and gets the entry. The key of the same app acts as `update <key>`, the key of another app is a failure.
add! : Fx, ToolsStep.Ctx, ToolsCmd.Cmd => Try(ToolsStep.Done, Fail)
add! = |fx, ctx, cmd| {
	parsed = match cmd.ref {
		Ok(found) => found
		Err(None) => return Err(Fail.new(Internal, "add --tool has no app"))
	}
	name = parsed.name
	key = ToolsCmd.key_of({ as_key: cmd.as_key, name })?
	match ctx.tools.find_first(|e| e.key == key) {
		Ok(entry) => if ToolsToml.app_of(entry.ref) == name {
			ToolsStep.run!(fx, ctx, { phase: Update, keys: [key] })
		} else {
			Err(ToolsCmd.key_taken({ path: ctx.home, key, other: ToolsToml.app_of(entry.ref) }))
		}
		Err(_) => fresh!(fx, ctx, { key, name, selector: parsed.selector })
	}
}

# Step 7: the release list, the pick, the bundle, the build, then the entry.
fresh! : Fx, ToolsStep.Ctx, { key : Str, name : Str, selector : Try(Selector, [None]) } => Try(ToolsStep.Done, Fail)
fresh! = |fx, ctx, run| {
	machine = ToolsStep.machine!(fx)?
	found = XCacheIo.entries!(fx, ctx.roots, machine.os)?
	picked = ToolsStep.pick!(fx, ctx, { machine, name: run.name, selector: run.selector })?
	chosen = ToolsStep.chosen!(fx, ctx, { pick: picked, found })?
	ensured = ToolsStep.ensure!(fx, ctx, { facts: picked.facts, rel: chosen.rel, bundle: chosen.bundle, found })?
	ref = ToolsPlan.add_ref({ name: run.name, selector: run.selector, version: chosen.rel.version })
	row = { key: run.key, name: run.name, action: Added, ref: Ok(ref), url: Ok(chosen.rel.url), version: Ok(chosen.rel.version), previous: Err(None), built: ensured.built, would_build: ensured.would }
	Ok({ rows: [row], changes: [Put({ key: run.key, ref, url: chosen.rel.url })] })
}

# Step 4: the keys must be in `[tools]`. No build, no network.
remove! : ToolsStep.Ctx, ToolsCmd.Cmd => Try(ToolsStep.Done, Fail)
remove! = |ctx, cmd| {
	check_keys(ctx, cmd.keys)?
	rows = cmd.keys.map(
		|key| {
			ref = match ctx.tools.find_first(|e| e.key == key) {
				Ok(entry) => entry.ref
				Err(_) => ""
			}
			{ key, name: ToolsToml.app_of(ref), action: Removed, ref: Err(None), url: Err(None), version: Err(None), previous: Err(None), built: Bool.False, would_build: Bool.False }
		},
	)
	Ok({ rows, changes: cmd.keys.map(|key| Drop(key)) })
}

# Step 6: `update` and `upgrade` with the keys (`[]` is each entry).
moved! : Fx, ToolsStep.Ctx, ToolsCmd.Cmd, ToolsPlan.Phase => Try(ToolsStep.Done, Fail)
moved! = |fx, ctx, cmd, phase| {
	check_keys(ctx, cmd.keys)?
	ToolsStep.run!(fx, ctx, { phase, keys: cmd.keys })
}

# R-PT3, R-PT5: the first key that is not in `[tools]` is the failure.
check_keys : ToolsStep.Ctx, List(Str) -> Try({}, Fail)
check_keys = |ctx, keys| {
	have = ctx.tools.map(|e| e.key)
	for key in keys {
		if !have.contains(key) {
			return Err(ToolsCmd.no_key({ path: ctx.home, key, keys: have }))
		}
	}
	Ok({})
}

# Step 8: the lines, `nothing to change`, the line of `--dry-run`, and with `--json` the envelope.
print! : Fx, Args, Done => {}
print! = |fx, args, run| {
	shown = Common.shown_fx(fx, args)
	ToolsStep.print!(shown, run.ctx, run.done)
	changed = !run.done.changes.is_empty() or run.done.rows.any(|row| ToolsStep.line(row).is_ok())
	if !changed {
		shown.out!("nothing to change\n")
	}
	if run.ctx.dry_run {
		shown.out!("dry run: nothing was written\n")
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: ToolsStep.data(run.ctx.home, run.done.rows) }))
	}
}
