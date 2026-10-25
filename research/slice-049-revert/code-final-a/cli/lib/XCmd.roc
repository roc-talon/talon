import Args
import Fail
import Prompt
import Ref
import Scope
import ToolInstall

## The line of `tln x` and the texts of build reuse (slice 049, CLI 6.4: R-CM12, R-FL1, R-X1, R-X4, R-B3, R-B7, R-B8, R-NI9, R-C6, R-NM11, R-E1). Part A (TESTING.md 2.2). The command code is `XFlow` (`tln x`) and `XTake` (the take-over of `tln tool install`).
## The texts are proposals (R-OUT2, TW24), except the three that the design gives: the note of R-C6, the form of the note of R-B3 (`installed cached 1.2.0 (1.4.0 is available: tln tool install foo@latest)`) and the prompt of R-B7.
XCmd :: [].{

	## The operand and the flags of one `tln x` line. `ref` is the app as typed (`Ref.parse` with the scope `X`). `roc` is `--roc` (R-X1). `unchecked` is `--allow-unchecked` (R-B7, R-NI9). `args` are the words after a bare `--`: the arguments of the app (R-CM12).
	Plan : { ref : Ref, roc : [Auto, Pinned, Installed], unchecked : Bool, args : List(Str) }

	## R-CM12, R-FL1, R-X1: the line of `tln x`. All failures have the kind `Usage` (exit 2, the texts are proposals). The first row that holds wins:
	##
	## | # | Case | Failure |
	## | --- | --- | --- |
	## | 1 | `--git`, `--path` or `--resolve` (slices 059 and later: the git source, R-T23, and a new resolution, R-T1) | `tln x <flag> is not built yet` |
	## | 2 | No operand (the `<key>` form of a project tool is R-PT11, slice 059) | `tln x needs one app: owner/app` |
	## | 3 | 2 operands or more | `tln x takes one app, got <n>` |
	## | 4 | `Ref.parse(operand, Scope.X, false)` fails (R-SL1 to R-SL13) | Its failure |
	## | 5 | The selector is a `GitSha` (`@dd03c09e`) | `'<sel>' in '<operand>' is a git ref: a git ref needs --git (not built yet)` |
	## | 6 | `--roc` with another value than `pinned` and `installed` | `ToolInstall.read_flags` gives the failure |
	##
	## `--json` is refused by `Args.parse` (R-FL1, exit 2, the text `flag '--json' is not for 'x'`). `--yes`, `--offline`, `--quiet` and `--slots` are accepted as for `tool install`. The words after `--` are not read as flags (`Args.passthrough`).
	read : Args -> Try(Plan, Fail)
	read = |args| {
		later = args.options.find_first(|(name, _)| ["--git", "--path", "--resolve"].contains(name))
		match later {
			Ok((name, _)) => return Err(usage("tln x ${name} is not built yet"))
			Err(_) => {}
		}
		operand = match args.operands {
			[] => return Err(usage("tln x needs one app: owner/app"))
			[one] => one
			many => return Err(usage("tln x takes one app, got ${many.len().to_str()}"))
		}
		ref = Ref.parse(operand, Scope.X, Bool.False)?
		match ref.selector {
			Ok(GitSha(sel)) => return Err(usage("'${sel}' in '${operand}' is a git ref: a git ref needs --git (not built yet)"))
			_ => {}
		}
		flags = ToolInstall.read_flags(args)?
		unchecked = args.options.any(|(name, _)| name == "--allow-unchecked")
		Ok({ ref, roc: flags.roc, unchecked, args: args.passthrough })
	}

	## R-C6, R-B3: the note when a build is reused and no registry gave yank and advisory data (`direct`): `no yank and advisory data without a registry`. The command prints it on stderr as `note: <text>`.
	no_data : Str
	no_data = "todo: slice 049"

	## R-B3: the line when the build that is used is older than the newest release. `have` is its version, `newest` the newest release, `key` the binary name, `name` the full name.
	##
	## | `via` | Text |
	## | --- | --- |
	## | `TakeOver` (`tool install`) | `installed cached <have> (<newest> is available: tln tool install <key>@latest)` (the form of the design) |
	## | `RunCached` (`x`, an `x` cache entry) | `using cached <key> <have> (<newest> is available: tln x <name>@latest)` |
	## | `RunInstalled` (`x`, an installed tool, R-B5) | `using installed <key> <have> (<newest> is available: tln x <name>@latest)` |
	available : { via : [TakeOver, RunCached, RunInstalled], key : Str, name : Str, have : Str, newest : Str } -> Str
	available = |_facts| crash "todo: slice 049"

	## R-B8: the note when `tln x` runs an installed tool with no network: `<key> <version> is installed. tln did not check it online for yanks and advisories.` No prompt.
	offline_installed : { key : Str, version : Str } -> Str
	offline_installed = |_facts| crash "todo: slice 049"

	## R-B7, R-NI9, R-NM5, R-NM8, R-NR6: the prompt for a cached build that was not checked online. Kind `Required(["--allow-unchecked"])`, yes/no, the interactive default is `No` (so `--yes` is not the answer of Enter). With no person and no flag
	## `Prompt.decide` gives exit 13, and the message names `--allow-unchecked` and `--yes`.
	##
	## | Field | Text |
	## | --- | --- |
	## | `id` | `use-unchecked` |
	## | `question` | `<key> <version> is in the cache. It was not checked online for yanks and advisories. Install it?` (the text of the design). For `Run`: `... Run it?` |
	## | `subject` | `using the cached <key> <version>, which was not checked online` |
	## | `answer_line` | `Yes`: `using cached <key> <version>, not checked online`. `No`: `not using cached <key> <version>`. |
	unchecked_prompt : { via : [TakeOver, Run], key : Str, version : Str } -> Prompt
	unchecked_prompt = |_facts| crash "todo: slice 049"

	## R-B7, R-NM8: the failure when the person answers No to the prompt. Kind `Consent` (exit 13): `<key> <version> is in the cache, but it was not checked online and you did not accept it. Nothing was installed.` (`Nothing was run.` for `Run`)
	declined : { via : [TakeOver, Run], key : Str, version : Str } -> Fail
	declined = |_facts| crash "todo: slice 049"

	## R-B7: the failure when no build matches and the request cannot be resolved. Kind `Network` (exit 15): `no installed or cached build of <name> matches, and --offline is set. Run the command without --offline.` For a missing network (no `--offline`) the command gives the failure of the request itself
	## (the same kind, `Github.network_failure`), not this one.
	offline_no_build : Str -> Fail
	offline_no_build = |name| Fail.new(Network, "no installed or cached build of ${name} matches, and --offline is set. Run the command without --offline.")

	## R-HF6, R-E1: the failure when the app does not start. Kind `Environment` (exit 18): `cannot run <program>: <text>` (as `Proxy.start_failed`).
	start_failed : { program : Str, text : Str } -> Fail
	start_failed = |facts| Fail.new(Environment, "cannot run ${facts.program}: ${facts.text}")
}

usage : Str -> Fail
usage = |text| Fail.new(Usage, text)
