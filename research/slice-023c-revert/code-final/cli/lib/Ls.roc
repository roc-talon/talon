import Args
import Closure
import Exit
import Fail
import Fx
import Install
import Known
import Listing
import Mode
import Out
import ResolveBase

## The command `tln list` (also `ls`: R-CM9, R-CM19, R-H4, R-C8; slice 010). The wiring of a run, in direct style over `Fx` (TESTING.md 2.2 part C): `Listing` decides the text, `Walk` reads the closure.
## `Run.run!` calls it for the command `list`. The calls, in order (the L2 case `closure/cl1-flow` and the L3 case `list/ls1-list` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Listing.read(args)`. A failure is printed with `Out.fail` (no `Fx` call). | R-FL5, R-FL7, R-CM9 |
## | 2 to 4 | `Install.begin!` (environment, time, project) | R-EV1, R-EV13, R-EV22, R-PD1 to R-PD8 |
## | 5 | No R-WS12 check: `list` works on the workspace (R-PD5). The members are the current member when there is one, else all members. No test: no workspace case in P0 (gap G3). | R-PD5, R-PD14 |
## | 6 | `canonical!` and `Known.record!` (R-PD14: `list` uses a project, R-PD9 records it). No compiler call: `list` needs no `roc version`. | R-PD9 |
## | 7 | The load of the members (the one `read_files!` call of the member files and the `talon.toml` candidates: today the private `load!` of `Resolve`. After the split of `Resolve` it is a public function of the base module: the name is free, no test calls it) | R-PD6 |
## | 8 | For each member: `Walk.run!` with its header rows (`Locked.rows` without `roc`), `known` from the earlier members. A failure of one member is the failure of the run: nothing is printed on stdout (no partial list, question Q10). | R-H7, R-CM9, R-FE7 |
## | 9 | The output (below) | R-J1 to R-J6, R-FL4 |
##
## Output. The notes of R-C8 (`Closure.notes`, each member) go to stderr, one line each, before the list (R-J2: warnings are human text on stderr, also with `--json`). The list is the answer, so `--quiet` does not hide it (R-FL4).
## stdout is `Listing.text` of each member (`Listing.tree` with `--tree`), in the order of the members. With `--json` stdout is only the envelope `Out.json_ok({ command: args.typed, data: Listing.data(members) })`
## (`command` is the word as typed: `list` or `ls`). A failure is printed with `Out.fail`, and the code is `Exit.choose`. The run writes no project file.
Ls :: [].{

	run! : Fx, Args => I32
	run! = |fx, args| match Listing.read(args) {
		Err(fail) => Install.failed!(fx, args, fail)
		Ok(opts) => match walk!(fx, args, Bool.True) {
			Ok(closures) => {
				if args.json {
					fx.out!(Out.json_ok({ command: args.typed, data: Listing.data(closures) }))
				} else {
					for c in closures {
						fx.out!(if opts.tree Listing.tree(c) else Listing.text(c))
					}
				}
				0
			}
			Err(fail) => Install.failed!(fx, args, fail)
		}
	}

	## Steps 2 to 8 of the table above: the environment, the project, the record, the load, and the walk of each member. With `notes` the warnings of R-C8 go to stderr (`tln list`). `tln why` calls it with `notes` false (slice 011, Q24).
	walk! : Fx, Args, Bool => Try(List({ file : Str, walked : Closure.Walked }), Fail)
	walk! = |fx, args, notes| {
		start = Install.begin!(fx, args)?
		Known.record!(fx, { roots: start.roots, files: Install.canonical_files!(fx, start.project), now: start.now })?
		request = {
			command: Install,
			names: [],
			frozen: Bool.False,
			no_check: Bool.False,
			project: start.project,
			roots: start.roots,
			net: start.net,
			now: start.now,
			offline: args.offline,
			strategy: Err(Unset),
			nightly: Install.nightly_of(start.env),
			compiler: Err(NoCompiler),
			toolchain: Err(Unset),
			snapshot: Err(Unset),
			dry_run: Bool.False,
			add: { as_platform: Bool.False, as_alias: Err(Unset), no_pin: Bool.False },
			prompt: { mode: Mode.from_env({ env: Dict.from_list(start.env), json: args.json }), yes: args.yes, quiet: args.quiet, rename_keys: Err(NoFlag), allow_moves: Err(NoFlag) },
		}
		loaded = ResolveBase.load!(fx, request)?
		# R-SO18: `ls` warns when `.roc-version` and the header pin differ (`why` does not: `notes` is false).
		if notes {
			for line in ResolveBase.roc_version_warnings(loaded) {
				fx.err!("warning: ${line}\n")
			}
		}
		current = start.project.file ?? ""
		named = loaded.members.keep_if(|m| m.file == current)
		members = if named.is_empty() loaded.members else named
		closures = ResolveBase.closure!(fx, request, { members: members.map(|m| { file: m.file, entries: ResolveBase.entries_after(m, []) }), known: [] })?
		if notes {
			ResolveBase.closure_notes!(fx, request, closures)
		}
		Ok(closures)
	}
}
