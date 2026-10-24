import Fail
import Pin
import Ranges
import Vars

## `tln install --frozen` (Resolution 12, R-LF1, R-SP22, R-DT6, R-I5, R-WS3): it resolves nothing. It fails when plain `tln install` would resolve something. This is the pure
## check. The command code also fetches the closure and checks each hash (slice 003, `Fetch.packages!`).
Frozen :: [].{

	## `scoped` is `Vars.scope` with the command `Install` and no names, `wants` is from `Vars.build`. `outside` is `Pin.Decision.outside`, and `req_text` is the text of
	## `[toolchain] roc`.
	##
	## The findings, in this order (each one is a plain `install` that resolves something: R-SP20, R-I5, R-RP2, R-SO17):
	##
	## | Finding | Text |
	## | --- | --- |
	## | A free variable (R-SP20, R-WS3): for each use that no range admits, in the order of the uses | `<file>: <alias> <version> is outside <range> and <range>` (the ranges of the variable, joined by ` and `) |
	## | A want that is not stale (R-I5) | `talon.toml: key "<key>" is not in the header` (`<key>` as in the file) |
	## | A want that is stale (R-I8) | `talon.toml: key "<key>" is "<name>", which the header names "<alias>"` (the text of the design) |
	## | `outside` is `Ok(pin)` (R-NS5, R-SO17) | `the roc pin <pin> is outside [toolchain] roc (<req text>)`. With no `req_text`: `the roc pin <pin> is a nightly, and nightly is false` |
	##
	## No finding: `Ok({})`. Else a failure of kind `Frozen` (exit 14, R-EC14): `the header does not satisfy talon.toml: <finding>; <finding>` (the findings joined by `; `).
	## A workspace rule failure (R-WS4: pins that differ, exit 2) comes from `Pin.decide` before this check, as in `install`. Texts: a proposal (TW24).
	check : { scoped : List(Vars.Scoped), wants : List(Vars.Want), outside : Try(Str, [None]), req_text : Try(Str, [Unset]), nightly : Bool } -> Try({}, Fail)
	check = |facts| {
		findings = outside_uses(facts.scoped).concat(facts.wants.map(want_finding)).concat(pin_finding({ outside: facts.outside, req_text: facts.req_text, nightly: facts.nightly }))
		if findings.is_empty() {
			Ok({})
		} else {
			Err(Fail.new(Frozen, "the header does not satisfy talon.toml: ${Str.join_with(findings, "; ")}"))
		}
	}
}

# R-SP20, R-WS3: each use of a free variable that no range admits.
outside_uses : List(Vars.Scoped) -> List(Str)
outside_uses = |scoped| scoped.keep_if(|s| s.free).join_map(
	|s| {
		ranges = s.variable.ranges.map(|r| r.range)
		s.variable.uses
			.keep_if(|u| !Ranges.admits({ ranges, version: u.version }))
			.map(|u| "${u.file}: ${u.alias} ${u.version} is outside ${Str.join_with(ranges, " and ")}")
	},
)

# R-I5, R-I8: a key of `talon.toml` that the header does not have, or has under another alias.
want_finding : Vars.Want -> Str
want_finding = |w| match w.stale {
	Ok(alias) => "talon.toml: key \"${w.key}\" is \"${w.name ?? w.key}\", which the header names \"${alias}\""
	Err(None) => "talon.toml: key \"${w.key}\" is not in the header"
}

# R-NS5, R-SO17: a `roc:` pin that the range or the switch does not allow.
pin_finding : { outside : Try(Str, [None]), req_text : Try(Str, [Unset]), nightly : Bool } -> List(Str)
pin_finding = |facts| match facts.outside {
	Err(None) => []
	Ok(pin) => if !facts.nightly and Pin.is_nightly(pin) {
		["the roc pin ${pin} is a nightly, and nightly is false"]
	} else {
		match facts.req_text {
			Ok(text) => ["the roc pin ${pin} is outside [toolchain] roc (${text})"]
			Err(Unset) => ["the roc pin ${pin} is outside [toolchain] roc"]
		}
	}
}
