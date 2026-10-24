import Args
import Clean
import Common
import Consent
import Fail
import Fx
import Gc
import Mode
import Out
import Prompt
import Roots

## `tln cache clean` (slice 029, CLI 6.3, R-CM17, R-GC12 to R-GC14, R-NI7, R-NR3). Direct style over `Fx` (TESTING.md 2.2 part C): `Clean` decides, this module orders the calls.
## `Run.tln!` calls `run!` for the command `["cache", "clean"]`. The calls, in order (the L2 case `clean/cn1-clean` and the L3 case `cache/cl1-real` fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Clean.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM17 |
## | 2 | `env_all!`, `Roots.from_env`. No `clock!` call: `clean` has no age rule. | R-GC12 |
## | 3 | With `--all`: one `list_dirs!` with the one dir `roots.build`, then `Gc.entries`. Without `--all`: no call. | R-GC13 |
## | 4 | `Clean.asks`, one `tree_info!` with the paths, `Gc.Measured`, `Clean.found`. The call is made also in a dry run. It is never skipped (the list has 2 paths at least). | R-GC12, R-GC13 |
## | 5 | No path exists: the outcome `Nothing`, no more call (no prompt, no `delete!`). A dry run: the outcome `DryRun`, no more call. | R-GC14 |
## | 6 | `Mode.from_env` and `Prompt.ask!` with `Consent.cache_clean` (count and total size of the items), the flag `Err(NoFlag)`, `yes` from `--yes`, `quiet` from `--quiet`. `Prompt.ask!` calls `tty!` when the mode is `NeedsTty` (not with `--yes`), and `ask!` for a person. With no person (CI, `--json`, no terminal) the answer is Yes, and the answer line goes to stderr (R-NM6). | R-NI7, R-NR3, R-NM6 |
## | 7 | The answer No: the outcome `Declined`, exit 0, no lock, no `delete!`. The answer Yes: `Fx.locked!` (`Wait`) on `Roots.item(roots, Gc)` (the item `talon/gc`, taken after the prompt: R-CC3 point 5), and in it one `delete!` with the paths in the order of `Clean.found`, then `Clean.check` on the results (a refused path is exit 18). A busy lock prints `waiting for another tln: gc` on stderr and waits, so `clean` never deletes while `cache gc` runs, and a GC that starts later finds the lock busy and exits 0 (R-CC10). A dry run, a declined run and a run with no item take no lock (question Q2, answer of the manager). | R-GC14, R-CC3, R-CC5, R-CC10 |
## | 8 | The output: `Clean.report` on stdout (`--quiet` hides it, with `--json` it goes to stderr), with `--json` the envelope with `Clean.data` on stdout. | R-OUT2, R-J3 |
CacheClean :: [].{

	## Steps 1 to 8.
	run! : Fx, Args => I32
	run! = |fx, args| match Clean.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match clean_flow!(fx, args, plan) {
			Ok(done) => {
				print!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# Steps 2 to 7.
clean_flow! : Fx, Args, Clean.Plan => Try(Clean.Done, Fail)
clean_flow! = |fx, args, plan| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	builds = if plan.all Gc.entries({ dirs: [roots.build], listed: fx.list_dirs!([roots.build]) }) else []
	asks = Clean.asks({ roots, all: plan.all, builds })
	infos = fx.tree_info!(asks.map(|ask| ask.path))
	found = Clean.found(asks.map2(infos, |ask, info| { item: ask.item, path: ask.path, info }))
	done = { all: plan.all, outcome: Removed, paths: found.paths, sizes: found.sizes }
	if found.paths.is_empty() {
		Ok({ ..done, outcome: Nothing })
	} else if plan.dry_run {
		Ok({ ..done, outcome: DryRun })
	} else {
		mode = Mode.from_env({ env: Dict.from_list(env), json: args.json })
		prompt = Consent.cache_clean({ count: found.paths.len(), size: Clean.freed(done) })
		asked = Prompt.ask!(fx, prompt, { mode, yes: args.yes, quiet: args.quiet, flag: Err(NoFlag) })?
		if asked.answer == Yes {
			remove!(fx, roots, found.paths)?
			Ok(done)
		} else {
			Ok({ ..done, outcome: Declined })
		}
	}
}

# Step 7, R-CC3, R-CC10: one `delete!` in the GC lock, taken after the prompt.
remove! : Fx, Roots, List(Str) => Try({}, Fail)
remove! = |fx, roots, paths| fx.locked!(
	Roots.item(roots, Gc),
	|| {
		results = fx.delete!(paths)
		Clean.check({ paths, results })
	},
)

# Step 8: the text (hidden by `--quiet`, on stderr with `--json`), and with `--json` the envelope.
print! : Fx, Args, Clean.Done => {}
print! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	for line in Clean.report(done) {
		shown.out!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Clean.data(done) }))
	}
}
