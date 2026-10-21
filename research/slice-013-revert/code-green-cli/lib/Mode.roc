## Interactive or non-interactive mode (CLI 4, R-NM1, R-NM2). The TTY test is a process
## call (R-HF1), so the mode comes in two steps: `from_env`, then `with_tty` only when
## `from_env` gives `NeedsTty`. A run that never needs the answer never starts the test.
Mode := [Interactive, NonInteractive, NeedsTty].{
	is_eq : _

	## From the variables and the flag. `NonInteractive` when `--json` is set, or when `CI`
	## (`true` or `1`, any case), `DEBIAN_FRONTEND` (`noninteractive`) or `NONINTERACTIVE`
	## (`1` or `true`) says so, unless `TALON_INTERACTIVE` is `1` (R-NM2). `TALON_INTERACTIVE`
	## `0` gives `NonInteractive`. Else `NeedsTty`.
	from_env : { env : Dict(Str, Str), json : Bool } -> Mode
	from_env = |facts| {
		var_is = |name, values| match facts.env.get(name) {
			Ok(value) => values.contains(value)
			Err(_) => Bool.False
		}
		# Only `CI` ignores the case (R-NM1).
		ci = match facts.env.get("CI") {
			Ok(value) => ["true", "1"].contains(value.with_ascii_lowercased())
			Err(_) => Bool.False
		}
		if facts.json {
			NonInteractive
		} else if var_is("TALON_INTERACTIVE", ["1"]) {
			NeedsTty
		} else if var_is("TALON_INTERACTIVE", ["0"]) {
			NonInteractive
		} else if ci or var_is("DEBIAN_FRONTEND", ["noninteractive"]) or var_is("NONINTERACTIVE", ["true", "1"]) {
			NonInteractive
		} else {
			NeedsTty
		}
	}

	## Gives `Interactive` or `NonInteractive` for `NeedsTty`: `Interactive` only when stdin
	## and stderr are both a terminal (R-NR1). Any other mode stays as it is.
	with_tty : Mode, { stdin : Bool, stderr : Bool } -> Mode
	with_tty = |mode, tty| match mode {
		NeedsTty => if tty.stdin and tty.stderr Interactive else NonInteractive
		other => other
	}

	## Color: off when `NO_COLOR` is set, else on when stderr is a terminal (R-EV9).
	## It does not depend on the mode (R-NM3).
	color : { env : Dict(Str, Str), stderr_tty : Bool } -> Bool
	color = |facts| !facts.env.contains("NO_COLOR") and facts.stderr_tty
}
