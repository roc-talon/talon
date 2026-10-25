import Args
import Fail

## The line of `tln run` (slice 057, CLI 1: R-CM24, R-RUN10, R-RUN11, R-RUN17, R-FL1, R-FL6, R-FL7). Part A (pure). `Run.tln!` has parsed the words with `Args.parse` (which refuses `--file`, the resolve flags and `--allow-downloads` for `run`, R-FL6, R-FL7, R-FL12),
## `read` checks what is left. No `Fx` call.
RunCmd :: [].{

	## What the user asked for: `name` is the script (`Err(None)`: the list of R-RUN11), `args` are the words after a bare `--` (R-RUN10), as they are.
	Cmd : { name : Try(Str, [None]), args : List(Str), each : Bool, keep_going : Bool }

	## R-RUN10, R-RUN11, R-FL1: the checks, in this order. A failure has the kind `Usage` (exit 2). The texts are proposals (TW24):
	##
	## | Case | Failure |
	## | --- | --- |
	## | 2 operands or more (R-RUN10: a word after the name with no `--`) | `tln run takes one script name, got <n> words. Pass arguments for the script after --.` |
	## | A name and `--json` (R-FL1, R-RUN11: the steps write to stdout) | `tln run <name> does not take --json: the steps write to stdout. Only tln run with no name does.` |
	##
	## Slice 058 (R-RUN13, R-FL12, R-EA7): `each` is true with the flag `--each` (`Args.parse` allows it, and `--keep-going`, for `run` only), `keep_going` with `--keep-going`. `--keep-going` with no `--each` is a failure of kind `Usage` (exit 2), checked first:
	## `flag '--keep-going' needs --each` (a proposal, TW24). With `--each`, the other checks stay as the table above says: one name (the script of each node) or none (R-EA8: the order and the edges), `--json` only with no name, the words after `--` need a name (OP9: they are
	## the args of each node, `RunEachFlow`).
	##
	## One operand is the name as typed (no check of its form: a name that no `[scripts]` table has is the failure of R-RUN12). No operand is the list. Words after `--` and no name (Q1 of the review): exit 2, `tln run -- <words> needs a script name: the words after -- are the arguments of a script. Use tln run <name> -- <words>.`
	read : Args -> Try(RunCmd.Cmd, Fail)
	read = |args| {
		with_each = args.options.any(|(flag, _)| flag == "--each")
		keep = args.options.any(|(flag, _)| flag == "--keep-going")
		if keep and !with_each {
			Err(Fail.new(Usage, "flag '--keep-going' needs --each"))
		} else {
			read_words(args, with_each, keep)
		}
	}
}

# The operands and the words after `--` (R-RUN10, R-RUN11, R-FL1).
read_words : Args, Bool, Bool -> Try(RunCmd.Cmd, Fail)
read_words = |args, each, keep_going| match args.operands {
	[] => if args.passthrough.is_empty() {
		Ok({ name: Err(None), args: [], each, keep_going })
	} else {
		Err(Fail.new(Usage, "tln run -- <words> needs a script name: the words after -- are the arguments of a script. Use tln run <name> -- <words>."))
	}
	[name] => if args.json {
		Err(Fail.new(Usage, "tln run ${name} does not take --json: the steps write to stdout. Only tln run with no name does."))
	} else {
		Ok({ name: Ok(name), args: args.passthrough, each, keep_going })
	}
	more => Err(Fail.new(Usage, "tln run takes one script name, got ${more.len().to_str()} words. Pass arguments for the script after --."))
}
