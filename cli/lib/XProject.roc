import Args
import Clock
import Exit
import Fail
import Fx
import Ident
import Known
import Net
import Project
import Ref
import Roots
import RunFind
import RunSteps
import RunTools
import Text
import ToolsToml
import XCmd

## `tln x` of a project tool (slice 059, CLI 6.4: R-PT11, R-X4, R-PT8, R-PT9, R-PT12, CLI 1: R-PD9, R-PD16, R-RUN12). `tln x <key>` and `tln x owner/app` (no selector) run the project tool of `[tools]` when the `talon.toml` that the walk finds has it. Part A (`choose`, `note`)
## is pure (TESTING.md 2.2). Part C (`run!`) is direct style over `Fx`: it uses the walk of `tln run` (`RunFind` through `RunSteps.locate!`), the record of R-PD9 (`RunSteps.record_files!`) and the binary of a key (`RunTools.load!`, `bin!`).
## `XFlow.run!` calls `run!` first, and goes on with the global flow of slice 049 when it gives `Miss`.
##
## The calls of `run!`, in order (the L2 case `x/x3-project` fixes them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | A selector in the ref (`owner/app@sel`): `Miss`, no `Fx` call. The user asked for a version (R-PT11). | R-PT11 |
## | 2 | `env_all!`, `Roots.from_env`, `Clock.now!`, `cwd!`, `Project.scan!` (as step 2 and 3 of `RunFlow`). | R-PD2, R-PD3 |
## | 3 | The nearest `talon.toml` of the walk (`RunFind.find` with a file that always holds the name; a `Need` is one `read_files!`). No `talon.toml`: `Miss`. | R-PT11, R-RUN12, NC2, NC5 |
## | 4 | `RunTools.table` of the file of `[tools]` (`Found.tools_dir`). A failure is exit 19. `choose`: no hit is `Miss`. | R-PT11, R-PT1, OP4 |
## | 5 | A hit: `flags_stop` (slice 073: `--roc` or `--allow-unchecked` is exit 2, before the record, R-PT11), R-PD9 (`RunSteps.record_files!`, `Known.record!`), the warnings of the table on stderr, the `url` of the entry (none: exit 14, no more call), the note for the form `owner/app`, `RunTools.load!`, `RunTools.bin!`, then `exec!` of `[<binary>] ++ <the words after -->`. | R-PD9, R-PT9, R-X4, R-E1 |
XProject :: [].{

	## The entry that `tln x` runs, and how it was named: `Key` (the operand is the key) or `App` (the operand is the app of the entry).
	Hit : { entry : ToolsToml.Entry, via : [Key, App] }

	## R-PT11: which entry of `[tools]` the operand names. The operand has no selector (`owner/app@sel` and `<key>@sel` ask for a version: `Err(None)`):
	##
	## | Operand (`ref.form`) | Hit |
	## | --- | --- |
	## | A short name that is a key of `[tools]` (`Bare`) | `Key`: that entry. A key is the whole name: `fmt` is no hit for the key `fmt2`, and the short name of an app (`fmt` for the key `format` of `acme/fmt`) is no key. |
	## | `owner/app` (`Full`) with the same app as the `ref` of an entry (`ToolsToml.app_of`) | `App`: that entry. 2 entries or more with that app: `Err(Many(keys))`, the keys in the order of their lines (review Q1) |
	## | `host/path` (`HostPath`), or any operand with a selector, or no entry | `Err(None)` |
	choose : { ref : Ref, tools : List(ToolsToml.Entry) } -> Try(XProject.Hit, [None, Many(List(Str))])
	choose = |facts| match facts.ref.selector {
		Ok(_) => Err(None)
		Err(None) => match facts.ref.form {
			Bare => match facts.tools.find_first(|e| e.key == facts.ref.name) {
				Ok(entry) => Ok({ entry, via: Key })
				Err(_) => Err(None)
			}
			Full => {
				same = facts.tools.keep_if(|e| ToolsToml.app_of(e.ref) == facts.ref.name)
				match same {
					[] => Err(None)
					[entry] => Ok({ entry, via: App })
					_ => Err(Many(same.map(|e| e.key)))
				}
			}
			HostPath => Err(None)
		}
	}

	## R-PT11, review Q1: the failure for `Many`: kind `Usage` (exit 2), nothing is recorded, no child. The text is a proposal (TW24): `<name> is the app of <n> entries of [tools]: <key>, <key>. Use tln x <key>.`
	many : { name : Str, keys : List(Str) } -> Fail
	many = |facts| Fail.new(Usage, "${facts.name} is the app of ${facts.keys.len().to_str()} entries of [tools]: ${Str.join_with(facts.keys, ", ")}. Use tln x <key>.")

	## Slice 073, R-PT11, 059 Q2: `--roc` and `--allow-unchecked` have no effect on a project tool (its pin and its `url` are the lock, R-PT8), so a run that has a hit and one of them stops. `roc` and `unchecked` are the fields of `XCmd.Plan` (`--roc` is `Pinned` or `Installed`
	## when it was given, `Auto` when not). No flag: `Ok({})`. Else a failure of kind `Usage` (exit 2, the text is a proposal, TW24): `--roc has no effect on the project tool <key>: its pin and its url are the lock. Remove the flag.`, the same with `--allow-unchecked`, and with both
	## `--roc and --allow-unchecked have no effect on the project tool <key>: its pin and its url are the lock. Remove the flags.` The run that stops records no project file and starts no child (as `many`).
	flags_stop : { key : Str, roc : [Auto, Pinned, Installed], unchecked : Bool } -> Try({}, Fail)
	flags_stop = |facts| {
		roc = facts.roc != Auto
		flags = match (roc, facts.unchecked) {
			(Bool.False, Bool.False) => return Ok({})
			(Bool.True, Bool.False) => "--roc has"
			(Bool.False, Bool.True) => "--allow-unchecked has"
			(Bool.True, Bool.True) => "--roc and --allow-unchecked have"
		}
		plural = if roc and facts.unchecked "flags" else "flag"
		Err(Fail.new(Usage, "${flags} no effect on the project tool ${facts.key}: its pin and its url are the lock. Remove the ${plural}."))
	}

	## R-PT11: the note for the form `owner/app` (the text of the design, on stderr): `project tool <key> <version> (talon.toml)`.
	note : { key : Str, version : Str } -> Str
	note = |facts| "project tool ${facts.key} ${facts.version} (talon.toml)"

	## Steps 1 to 5 (the table above). `Ok(Ok(code))`: the exit code of the app. `Ok(Err(Miss))`: no project tool, the global flow goes on. `Err(fail)`: exit 19 for a `[tools]` that is not valid, exit 14 for an entry with no `url`,
	## the failures of `RunTools.bin!`, and exit 18 when the binary does not start.
	run! : Fx, Args, XCmd.Plan => Try(Try(I32, [Miss]), Fail)
	run! = |fx, args, plan| match plan.ref.selector {
		Ok(_) => Ok(Err(Miss))
		Err(None) => walk!(fx, args, plan)
	}
}

# What the walk gave, and the run that it was made for.
Seen : { env : List((Str, Str)), roots : Roots, now : U64, scan : RunSteps.Scan, found : RunFind.Found }

# The name that each `talon.toml` of the walk has, so that `RunFind` takes the nearest file (D1). Its `[scripts]` is not read (R-RUN15).
holder : Str
holder = "x"

# Steps 2 and 3: the facts of the run, the walk and the nearest `talon.toml`. No file is `Miss`.
walk! : Fx, Args, XCmd.Plan => Try(Try(I32, [Miss]), Fail)
walk! = |fx, args, plan| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	now = Clock.now!(fx, env)?
	home = match env.find_first(|(name, _)| name == "HOME") {
		Ok((_, dir)) => dir
		Err(_) => ""
	}
	scan = Project.scan!(fx, { start: fx.cwd!(), home })?
	dirs = scan.walk.map(
		|d| match d.toml {
			Err(None) => { dir: d.dir, toml: Err(None) }
			Ok(_) => { dir: d.dir, toml: Ok({ names: [holder], bad: Err(None) }) }
		},
	)
	match RunSteps.locate!(fx, { name: Ok(holder), dirs }, scan, []) {
		Err(_) => Ok(Err(Miss))
		Ok(found) => table!(fx, args, plan, { env, roots, now, scan, found })
	}
}

# Step 4: the table of `[tools]` and the choice. No hit is `Miss`. 2 entries for the app are exit 2.
table! : Fx, Args, XCmd.Plan, Seen => Try(Try(I32, [Miss]), Fail)
table! = |fx, args, plan, seen| {
	path = Text.join(seen.found.tools_dir, "talon.toml")
	text = match seen.scan.walk.find_first(|d| d.dir == seen.found.tools_dir) {
		Ok(d) => d.toml ?? ""
		Err(_) => ""
	}
	table = RunTools.table({ path, text })?
	match XProject.choose({ ref: plan.ref, tools: table.tools }) {
		Err(None) => Ok(Err(Miss))
		Err(Many(keys)) => Err(XProject.many({ name: plan.ref.name, keys }))
		Ok(hit) => {
			XProject.flags_stop({ key: hit.entry.key, roc: plan.roc, unchecked: plan.unchecked })?
			Known.record!(fx, { roots: seen.roots, files: RunSteps.record_files!(fx, seen.scan, seen.found), now: seen.now })?
			for w in table.warnings {
				fx.err!("warning: ${w}\n")
			}
			run = { env: seen.env, roots: seen.roots, net: Net.from_env(seen.env), now: seen.now, path, text, tools: table.tools }
			Ok(Ok(exec_hit!(fx, args, plan, { run, hit })?))
		}
	}
}

# Step 5: the note for the form `owner/app`, the binary of the entry, and the run in place of `tln` (R-X4). The binary of a project tool is never the global one (R-PT12).
exec_hit! : Fx, Args, XCmd.Plan, { run : RunTools.Run, hit : XProject.Hit } => Try(I32, Fail)
exec_hit! = |fx, args, plan, what| {
	entry = what.hit.entry
	url = match entry.url {
		Ok(found) => found
		Err(Unset) => return Err(RunTools.no_url({ path: what.run.path, key: entry.key }))
	}
	match (what.hit.via, Ident.of_url(url)) {
		(App, Ok(ident)) => fx.err!("${XProject.note({ key: entry.key, version: ident.version })}\n")
		_ => {}
	}
	know = RunTools.load!(fx, what.run.roots)?
	got = RunTools.bin!(fx, args, what.run, know, entry)?
	match fx.exec!({ argv: [got.bin].concat(plan.args), env: [] }) {
		Ok(ended) => Ok(Exit.of_child(ended))
		Err(NotStarted(text)) => Err(XCmd.start_failed({ program: got.bin, text }))
	}
}
