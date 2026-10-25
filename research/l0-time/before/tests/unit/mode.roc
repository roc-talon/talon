app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Mode

main! = |_args| Ok({})

from = |pairs, json| Mode.from_env({ env: Dict.from_list(pairs), json })

# R-NM1 R-NM2 R-EV1 R-EV8: the variables and --json give NonInteractive, else the terminal decides (NeedsTty).
# CI is `true` or `1` in any case. TALON_INTERACTIVE overrides the three variables, not --json.
expect {
	modes = [
		from([], Bool.False),
		from([("CI", "true")], Bool.False),
		from([("CI", "TRUE")], Bool.False),
		from([("CI", "1")], Bool.False),
		from([("CI", "false")], Bool.False),
		from([("CI", "0")], Bool.False),
		from([("CI", "")], Bool.False),
		from([("DEBIAN_FRONTEND", "noninteractive")], Bool.False),
		from([("DEBIAN_FRONTEND", "dialog")], Bool.False),
		from([("NONINTERACTIVE", "1")], Bool.False),
		from([("NONINTERACTIVE", "true")], Bool.False),
		from([("NONINTERACTIVE", "0")], Bool.False),
		from([], Bool.True),
		from([("TALON_INTERACTIVE", "1"), ("CI", "true")], Bool.False),
		from([("TALON_INTERACTIVE", "1"), ("CI", "1"), ("DEBIAN_FRONTEND", "noninteractive"), ("NONINTERACTIVE", "1")], Bool.False),
		from([("TALON_INTERACTIVE", "1")], Bool.False),
		from([("TALON_INTERACTIVE", "0")], Bool.False),
		from([("TALON_INTERACTIVE", "1"), ("CI", "true")], Bool.True),
		from([("TALON_INTERACTIVE", "1")], Bool.True),
	]
	dbg modes
	modes == [
		NeedsTty,
		NonInteractive,
		NonInteractive,
		NonInteractive,
		NeedsTty,
		NeedsTty,
		NeedsTty,
		NonInteractive,
		NeedsTty,
		NonInteractive,
		NonInteractive,
		NeedsTty,
		NonInteractive,
		NeedsTty,
		NeedsTty,
		NeedsTty,
		NonInteractive,
		NonInteractive,
		NonInteractive,
	]
}

# R-NR1 R-HF1: only a terminal on both stdin and stderr gives Interactive, and only for NeedsTty.
# NonInteractive stays NonInteractive.
expect {
	both = { stdin: Bool.True, stderr: Bool.True }
	modes = [
		Mode.with_tty(NeedsTty, both),
		Mode.with_tty(NeedsTty, { stdin: Bool.True, stderr: Bool.False }),
		Mode.with_tty(NeedsTty, { stdin: Bool.False, stderr: Bool.True }),
		Mode.with_tty(NeedsTty, { stdin: Bool.False, stderr: Bool.False }),
		Mode.with_tty(NonInteractive, both),
	]
	dbg modes
	modes == [Interactive, NonInteractive, NonInteractive, NonInteractive, NonInteractive]
}

# R-EV9 R-NM3: NO_COLOR with any value turns color off. Else color follows the terminal of stderr.
# The mode (CI) does not change it.
expect {
	color = |pairs, tty| Mode.color({ env: Dict.from_list(pairs), stderr_tty: tty })
	shown = [
		color([], Bool.True),
		color([], Bool.False),
		color([("NO_COLOR", "1")], Bool.True),
		color([("NO_COLOR", "yes")], Bool.False),
		color([("CI", "true")], Bool.True),
	]
	dbg shown
	shown == [Bool.True, Bool.False, Bool.False, Bool.False, Bool.True]
}
