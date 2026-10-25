import Args
import Clock
import Common
import Compiler
import Consent
import Exit
import Fail
import Fx
import Known
import Mode
import Net
import OnPath
import Opts
import Out
import Project
import Report
import Resolve
import Roots

## The command `tln install` (also `add` and `i`, R-CM2, R-CM19, R-CM20): the wiring of a run, in direct style over `Fx` (TESTING.md 2.2, part C). It owns no decision:
## `Opts` reads the flags, `Resolve.install!` is the flow of slice 005 and 006 with the add of names, `Report` makes the line of R-DT5 and the `data` of `--json`.
## `Run.run!` calls it for the command `install`, after `Run.check_refs` (W1, W3).
##
## `run!` prints, and gives the exit code (`Exit.choose`). The calls, in order (the L2 case `install/in1-flow` fixes them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Opts.read(args)`. A failure is printed with `Out.fail` (no `Fx` call). | R-FL5, R-FL8 to R-FL14 |
## | 2 | `env_all!` (one call). `Roots.from_env`, `Mode.from_env({ env, json: args.json })`, `Net.from_env`, `TALON_NIGHTLY`, `TALON_NOW`. A failure of `Roots.from_env` is exit 18, a bad `TALON_NOW` is exit 2 (slice 001 Q5). | R-EV1, R-EV4, R-EV13, R-EV22 |
## | 3 | `clock!`, then `Clock.now({ talon_now, real })` | R-EV22 |
## | 4 | `Project.find!` with the start `cwd!`, `--file`, and the home dir (`HOME`) | R-PD1 to R-PD8 |
## | 5 | With names (`add`): the project must have a current member. A workspace root with no current member is a usage failure that lists the members (R-WS12, below). No `Fx` call is made after step 4 for this failure. | R-WS12 |
## | 6 | `canonical!` of the member files that the run reads (the standalone file, or each member of a workspace), then `Known.record!` with `now`. A run that found a project records it, also a run that fails later, a `--dry-run` and a `--frozen`. | R-PD9, R-CC2, R-CC6 |
## | 7 | Not `--frozen`: the compiler. `Install.on_path!`: `path_roc!`, then (when a `roc` file is on `PATH`) the cache `path-roc.json`, the launcher test with `sha256_file!`, and `spawn_all!` of `<file> version` (one job, limit 1) only for a binary with no run in its row (`PathRoc.step`). The step runs for each such run, also when a later step fails (the L3 `roc.log` shows it). `--frozen` needs no compiler (slice 005 Q3). | R-SO7, R-PH6, R-PH8 |
## | 8 | `Resolve.install!` with a `Resolve.Request`: the flags in `Opts`, `Mode.from_env`, `--yes`, `--quiet`, `TALON_NIGHTLY` (`0` or `false`, `1` or `true`: `Resolve.Request.nightly`), `Net.from_env` | R-SP18, R-AD1 to R-AD33 |
## | 9 | The output (below) | R-DT5, R-J1 to R-J6, R-FL4, R-LF4 |
##
## The output. All human text of the flow goes through `fx.out!`. The command gives each step a `Fx` with a changed `out!` (the record update `{ ..fx, out!: ... }` works on `Fx`):
##
## | Flags | `out!` of the `Fx` that the steps get | Why |
## | --- | --- | --- |
## | none | `fx.out!` | |
## | `--json` | `fx.err!` | stdout has the one envelope, stderr has the human text (R-J1, R-J2, R-OUT4) |
## | `--quiet` | no output | each stdout line is `Info` (R-FL4). Errors and answer lines go through `err!` and stay. `--quiet` wins over `--json`: the human text is not shown. |
##
## After `Resolve.install!` gave the `Report.Outcome`, the command prints with the same `Fx`: the line of `Report.resolved_line` when something was resolved and planned (an entry added, moved or pinned, a `talon.toml` key written or renamed: not `--frozen`, not "nothing to change", not a kept entry),
## then, with `--dry-run`, the line `dry run: nothing was written`. These are the last lines of stdout (the lines of the flow come first, question Q4 and the decision D3 of the slice file). With `--json` the envelope is
## `Out.json_ok({ command: args.typed, data: Report.data(outcome) })` on stdout. `command` is the word as typed (`add`, `i`, `install`). A failure is printed with `Out.fail` (the human line on stderr and, with `--json`, the envelope on stdout) and the code is `Exit.choose`.
##
## R-WS12 text (proposal, TW24): `no current member in the workspace at <root>. Members: <file>, <file>. Pass --file <member file>.` Kind `Usage`.
Install :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match Opts.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(opts) => {
			shown = Common.shown_fx(fx, args)
			match flow!(shown, args, opts) {
				Ok(outcome) => {
					print!(fx, shown, args, opts, outcome)
					0
				}
				Err(fail) => Common.failed!(fx, args, fail)
			}
		}
	}

	# Steps 2 to 4: the environment, the time, and the project (`remove` makes the same calls in the same order).
	begin! : Fx, Args => Try({ env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, project : Project }, Fail)
	begin! = |fx, args| {
		got = Install.begin_loose!(fx, args)?
		project = got.project?
		Ok({ env: got.env, roots: got.roots, net: got.net, now: got.now, project })
	}

	## Slice 056 (Q3 of the review): the calls of `begin!`, but a failure of the search for the project file is the field `project`, not the failure of the run (`add --tool` makes `talon.toml` in `cwd` when `ToolsPlan.no_project` is true for it). `cwd` is the answer of the one `cwd!` call.
	begin_loose! : Fx, Args => Try({ env : List((Str, Str)), roots : Roots, net : Net.Settings, now : U64, cwd : Str, project : Try(Project, Fail) }, Fail)
	begin_loose! = |fx, args| {
		env = fx.env_all!()
		roots = Roots.from_env(env)?
		net = Net.from_env(env)
		now = Clock.now!(fx, env)?
		home = match env.find_first(|(name, _)| name == "HOME") {
			Ok((_, dir)) => dir
			Err(_) => ""
		}
		cwd = fx.cwd!()
		project = Project.find!(fx, { start: cwd, file: args.file, home })
		Ok({ env, roots, net, now, cwd, project })
	}

	# Step 5, R-WS12: a run that needs a member (`add` with names, `remove`) needs a current member. No `Fx` call is made after the project is found.
	check_member : Bool, Project -> Try({}, Fail)
	check_member = |needs_member, project| match (project.workspace, project.file) {
		(Ok(ws), Err(NoCurrent)) if needs_member => Err(
			Fail.new(Usage, "no current member in the workspace at ${ws.root}. Members: ${Str.join_with(ws.members, ", ")}. Pass --file <member file>."),
		)
		_ => Ok({})
	}

	# Step 6, R-PD9: the canonical paths of the member files that the run reads.
	canonical_files! : Fx, Project => List(Str)
	canonical_files! = |fx, project| {
		files = match project.workspace {
			Ok(ws) => ws.members
			Err(Standalone) => match project.file {
				Ok(file) => [file]
				Err(NoCurrent) => []
			}
		}
		if files.is_empty() {
			[]
		} else {
			files.map2(fx.canonical!(files), |file, result| result ?? file)
		}
	}

	# Step 7, R-SO9: the `roc` on `PATH` (rank 7). The loop is `OnPath.file!`.
	on_path! : Fx, Roots => Try(Str, [NoCompiler])
	on_path! = |fx, roots| Install.on_path_file!(fx, roots).map_ok(|found| found.id)

	## Slice 023: `on_path!` with the path of the compiler file (rank 7, R-SO9), as `PATH` wrote it. The proxy runs this file (R-PX2). The calls are those of `on_path!`. Not for `--frozen`.
	on_path_file! : Fx, Roots => Try({ id : Str, path : Str }, [NoCompiler])
	on_path_file! = |fx, roots| OnPath.file!(fx, roots)

	# Step 7, R-SO22: the `roc` on `PATH` (not for `--frozen`). `ROC_TOOLCHAIN` is read apart (`Compiler.toolchain_of`, no `Fx` call) and needs no installed compiler here:
	# the first probe checks it (`Compiler.require`).
	compiler! : Fx, Roots, Bool => Try({ id : Str, path : Str }, [NoCompiler])
	compiler! = |fx, roots, frozen| if frozen Err(NoCompiler) else Install.on_path_file!(fx, roots)
}

# Steps 2 to 8: the environment, the project, the record, the compiler, and `Resolve.install!`.
flow! : Fx, Args, Opts => Try(Report.Outcome, Fail)
flow! = |fx, args, opts| {
	start = Install.begin!(fx, args)?
	env = start.env
	roots = start.roots
	net = start.net
	now = start.now
	project = start.project
	Install.check_member(!opts.names.is_empty(), project)?
	Known.record!(fx, { roots, files: Install.canonical_files!(fx, project), now })?
	toolchain = Compiler.toolchain_of(env)?
	compiler = Install.compiler!(fx, roots, opts.frozen)
	Resolve.install!(
		fx,
		{
			command: Install,
			names: opts.names,
			frozen: opts.frozen,
			no_check: opts.no_check,
			project,
			roots,
			net,
			now,
			offline: args.offline,
			strategy: opts.strategy,
			nightly: Common.nightly_of(env),
			compiler,
			toolchain,
			snapshot: opts.snapshot,
			dry_run: opts.dry_run,
			add: { as_platform: opts.as_platform, as_alias: opts.as_alias, no_pin: opts.no_pin },
			prompt: { mode: Mode.from_env({ env: Dict.from_list(env), json: args.json }), yes: args.yes, quiet: args.quiet, rename_keys: opts.rename_keys, allow_moves: opts.allow_moves },
			downloads: { auto: Consent.auto_install(env), allow: opts.allow_downloads, probe: opts.probe_downloads, env },
			probe: { no_probe: opts.no_probe, slots: opts.slots },
		},
	)
}

# Step 9: the lines after the flow, or the envelope.
print! : Fx, Fx, Args, Opts, Report.Outcome => {}
print! = |fx, shown, args, opts, outcome| {
	planned = !outcome.added.is_empty() or !outcome.moved.is_empty() or outcome.pinned.is_ok() or !outcome.toml.is_empty() or !outcome.renamed.is_empty()
	if planned {
		shown.out!("${Report.resolved_line({ at: outcome.at, probes: outcome.probes })}\n")
	}
	if opts.dry_run {
		shown.out!("dry run: nothing was written\n")
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Report.data(outcome) }))
	}
}
