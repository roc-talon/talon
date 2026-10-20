import Fail
import Ranges
import Selector
import Text
import semver.Semver

## The `roc:` pin of a header and the compiler range of `talon.toml` (Resolution 1 "The `nightly` switch", Resolution 9 "The `roc:` pin",
## Design 4.4 R-WS4, Design 7 R-PH8). In P0 the nightly is always held (R-RP2): no command moves an existing pin (R-RP1), and
## `upgrade` is P1. This module only decides what the pin is, if it is allowed, and where Talon writes it.
##
## A compiler id is a nightly tag `nightly-<year>-<month>-<day>-<sha>` (for example `nightly-2026-10-09-258ab27`), or a release version
## (`0.1.0`). The order of two nightlies is the date, then the text of the tag (R-NS1: P0 has no `published_at` of compilers).
## A release has no date in P0 (no compiler release exists), so a `AtLeast(<nightly>)` bound admits no release (question Q9).
Pin :: [].{

	## The `[toolchain] roc` of `talon.toml` (R-NS7):
	##
	## | Text | Tag | Admits |
	## | --- | --- | --- |
	## | `*` | `Any` | each nightly and each release |
	## | `>=<id>` | `AtLeast(id)` | each nightly at or after the nightly `id` |
	## | `=<id>` | `Exactly(id)` | that id only |
	## | A semver range (`0.1.*`, `^1`) | `Semver(text)` | releases only (never a nightly) |
	Req : [Any, AtLeast(Str), Exactly(Str), Semver(Str)]

	## R-NS7, R-TF4. A `>=` or `=` text that is not a compiler id, and a text that is not a range, is `Err(BadReq)`.
	## `>=nightly-2026-10-09-258ab27` is `AtLeast("nightly-2026-10-09-258ab27")`. `0.1.*` is `Semver("0.1.*")`.
	parse_req : Str -> Try(Req, [BadReq])
	parse_req = |text| {
		bound = |op| text.drop_prefix(op)
		if text == "*" {
			Ok(Any)
		} else if text.starts_with(">=") and is_compiler_id(bound(">=")) {
			Ok(AtLeast(bound(">=")))
		} else if text.starts_with("=") and !text.starts_with("=<") and is_compiler_id(bound("=")) {
			Ok(Exactly(bound("=")))
		} else {
			match Ranges.check(text) {
				Ok({}) => Ok(Semver(text))
				Err(BadRange) => Err(BadReq)
			}
		}
	}

	## R-SC12: is the text a full compiler id, a nightly tag or a release version? A prefix (`nightly-2026-10`) is not.
	is_id : Str -> Bool
	is_id = |text| is_compiler_id(text)

	## Is the id a nightly tag (`nightly-` and 3 parts, the form of Design 2)? A release is not.
	is_nightly : Str -> Bool
	is_nightly = |id| Selector.parse(id, Bool.False) == Ok(Nightly(id))

	## R-NS5, R-NS7, R-RP2: does the range admit the compiler id? `Any` admits all. `Exactly(a)` admits `a` only. `AtLeast(a)` admits a nightly
	## with a date that is at or after the date of `a` (same date: the tag text in byte order, `a` itself included). `Semver(range)` admits a
	## release that the range admits, and no nightly.
	admits : { req : Req, id : Str } -> Bool
	admits = |facts| match facts.req {
		Any => Bool.True
		Exactly(a) => facts.id == a
		AtLeast(a) => at_least(a, facts.id)
		Semver(range) => !Pin.is_nightly(facts.id) and Ranges.admits({ ranges: [range], version: facts.id })
	}

	## The decision for the `roc:` entries of the members (Design 4.4 R-WS4, Resolution 9 R-RP1 to R-RP3, Design 4.2 R-H6, Design 7 R-PH8).
	##
	## Input:
	##
	## | Field | Holds |
	## | --- | --- |
	## | `members` | One row for each member file, in order: its `roc:` entry text (`Err(NoPin)` when it has none), and `changes`: the command writes the header of this member for another change |
	## | `compiler` | The id of the selected compiler: in P0 the `roc` on `PATH` (R-PH8), when its id is a nightly or a release. `Err(NoCompiler)` for no compiler, or a local build id (`debug-<sha>`: R-SO11, never written). |
	## | `req` | `[toolchain] roc` of the workspace root or the project `talon.toml` |
	## | `nightly` | The `nightly` switch (R-NS8 to R-NS11), after the priority of its sources |
	## | `no_check` | `--no-check` (R-LF3, R-H6) |
	##
	## Result:
	##
	## | Case | Result |
	## | --- | --- |
	## | The members that have a pin have 2 or more different texts | Failure, kind `Usage` (exit 2, R-WS4, R-EC2): `members have different roc pins: <file> <pin>, <file> <pin>. Run tln roc use <id> or tln upgrade roc.` The members that have a pin, in the order of `members`, each with its pin. |
	## | One pin text in the workspace | `held` is that text (R-SP1: the nightly is held at the pin). The members that have no pin get it (R-WS4, last sentence) |
	## | No pin in any member | `held` is `compiler` (R-SP1: the selected compiler) |
	## | A pin that `req` does not admit, or a nightly pin with `nightly` false (R-NS5) | `outside` is `Ok(pin)`. The command decides what that means: `install` and `update` stop with exit 10 (R-RP2, `Pin.outside_failure`), `--frozen` reports it (R-LF1, R-SO17). Else `Err(None)`. |
	## | A member that has no pin, `changes` is true, `no_check` is false, and `held` is `Ok(id)` | `writes` has `{ file, id }` (R-RP3: the held value is written after the check passes. `Pin.decide` runs before the check, so the command writes only when the check passes.) |
	## | A member that has no pin, with `no_check` true (R-H6) | No write: Talon writes none if there was none |
	## | A member that has no pin, `changes` false | No write: a missing pin alone is not a change (R-RP3) |
	## | A member that has a pin | No write, never (R-RP1, R-RP2: P0 holds the nightly) |
	##
	## `writes` has the order of `members`.
	## `pinned` is true when a member has a pin (`held` is the pin), false when `held` is the selected compiler (`gate` checks that one).
	Decision : {
		held : Try(Str, [NoCompiler]),
		writes : List({ file : Str, id : Str }),
		outside : Try(Str, [None]),
		pinned : Bool,
	}

	## Where the value of the `nightly` switch comes from (R-NS8 to R-NS10): the environment, `[toolchain] nightly` of `talon.toml`, `nightly` of `config.toml`, or the default (on).
	Source : [Env, Toml, Config, Default]

	decide : {
		members : List({ file : Str, pin : Try(Str, [NoPin]), changes : Bool }),
		compiler : Try(Str, [NoCompiler]),
		req : Try(Req, [Unset]),
		nightly : Bool,
		no_check : Bool,
	} -> Try(Decision, Fail)
	decide = |facts| {
		pins = facts.members.keep_oks(|m| m.pin.map_ok(|text| { file: m.file, text }))
		texts = Text.sorted_unique(pins.map(|p| p.text))
		if texts.len() >= 2 {
			Err(Fail.new(Usage, "members have different roc pins: ${Str.join_with(pins.map(|p| "${p.file} ${p.text}"), ", ")}. Run tln roc use <id> or tln upgrade roc."))
		} else {
			held = match texts {
				[one] => Ok(one)
				_ => facts.compiler
			}
			can_write = !facts.no_check
			writes = match held {
				Ok(id) if can_write => facts.members.keep_if(|m| m.pin == Err(NoPin) and m.changes).map(|m| { file: m.file, id })
				_ => []
			}
			Ok({ held, writes, outside: outside_pin(texts, { req: facts.req, nightly: facts.nightly }), pinned: !texts.is_empty() })
		}
	}

	## R-RP2 (a nightly that the header holds is outside `[toolchain] roc`): the failure of `install`, `add`, `update` and `remove`. Kind `NoTuple`
	## (exit 10): `the roc pin <pin> is outside [toolchain] roc (<req text>). Run tln upgrade roc or tln roc use <id>.` With the switch off, the
	## text names the switch and its source (R-NS2): `the roc pin <pin> is a nightly, and nightly is false (set by <source text>). Run tln upgrade roc or tln roc use <id>.`
	## `req_text` is the text of `[toolchain] roc` (`Err(Unset)`: none). Texts are a proposal (TW24).
	outside_failure : { pin : Str, req_text : Try(Str, [Unset]), nightly : Bool, source : Source } -> Fail
	outside_failure = |facts| {
		follow = "Run tln upgrade roc or tln roc use <id>."
		if !facts.nightly and Pin.is_nightly(facts.pin) {
			Fail.new(NoTuple, "the roc pin ${facts.pin} is a nightly, and nightly is false (set by ${Pin.source_text(facts.source)}). ${follow}")
		} else {
			range = match facts.req_text {
				Ok(text) => " (${text})"
				Err(Unset) => ""
			}
			Fail.new(NoTuple, "the roc pin ${facts.pin} is outside [toolchain] roc${range}. ${follow}")
		}
	}

	## The name of a source of the switch, for the messages.
	source_text : Source -> Str
	source_text = |source| match source {
		Env => "TALON_NIGHTLY"
		Toml => "[toolchain] nightly in talon.toml"
		Config => "nightly in config.toml"
		Default => "the default"
	}

	## R-SO13, R-NS2, R-NS3, R-PH7: the check of the selected compiler (the `roc` on `PATH`) when no member has a pin (`Decision.pinned` is false).
	## P0 cannot select another compiler. The switch is checked first (R-NS2: with the switch off the domain of nightlies is empty).
	##
	## | Case | Result |
	## | --- | --- |
	## | `compiler` is a nightly, and `nightly` is false | Failure, kind `NoTuple` (exit 10): `the roc on PATH, <id>, is a nightly, and nightly is false (set by <source text>). No roc release is known, so no compiler can be selected.` |
	## | `req` does not admit `compiler` | Failure, kind `Consent` (exit 13, R-PH7): `the roc on PATH, <id>, is outside [toolchain] roc (<req text>). This version of tln runs only the roc on PATH, so it cannot select another compiler.` |
	## | Else | `Ok({})` |
	gate : { compiler : Str, req : Try(Req, [Unset]), req_text : Try(Str, [Unset]), nightly : Bool, source : Source } -> Try({}, Fail)
	gate = |facts| {
		if Pin.is_nightly(facts.compiler) and !facts.nightly {
			Err(Fail.new(NoTuple, "the roc on PATH, ${facts.compiler}, is a nightly, and nightly is false (set by ${Pin.source_text(facts.source)}). No roc release is known, so no compiler can be selected."))
		} else {
			match (facts.req, facts.req_text) {
				(Ok(req), Ok(text)) if !Pin.admits({ req, id: facts.compiler }) => Err(
					Fail.new(Consent, "the roc on PATH, ${facts.compiler}, is outside [toolchain] roc (${text}). This version of tln runs only the roc on PATH, so it cannot select another compiler."),
				)
				_ => Ok({})
			}
		}
	}
}

# A nightly tag, or a release version `X.Y.Z`.
is_compiler_id : Str -> Bool
is_compiler_id = |text| Pin.is_nightly(text) or is_release(text)

is_release : Str -> Bool
is_release = |text| match Semver.parse(text) {
	Ok(v) => v.pre_release().is_empty()
	Err(_) => Bool.False
}

# R-NS5, R-NS7: the pin of the workspace (the one text, when the members agree) against the range and the switch.
outside_pin : List(Str), { req : Try(Pin.Req, [Unset]), nightly : Bool } -> Try(Str, [None])
outside_pin = |texts, facts| match texts {
	[pin] => {
		out_of_range = match facts.req {
			Ok(req) => !Pin.admits({ req, id: pin })
			Err(Unset) => Bool.False
		}
		if out_of_range or (Pin.is_nightly(pin) and !facts.nightly) Ok(pin) else Err(None)
	}
	_ => Err(None)
}

# The order of 2 compiler ids of one kind (Q9): nightlies by date then tag text, releases by version. Other pairs have none.
at_least : Str, Str -> Bool
at_least = |bound, id| match (nightly_key(bound), nightly_key(id)) {
	(Ok(a), Ok(b)) => !is_before(b, a)
	(Err(_), Err(_)) => match (Semver.parse(bound), Semver.parse(id)) {
		(Ok(a), Ok(b)) => is_release(bound) and is_release(id) and b.order_relative_to(a) != Before
		_ => Bool.False
	}
	_ => Bool.False
}

NightlyKey : { date : List(U64), sha : Str }

is_before : NightlyKey, NightlyKey -> Bool
is_before = |a, b| match compare_dates(a.date, b.date) {
	Before => Bool.True
	After => Bool.False
	Same => Text.compare(a.sha, b.sha) == Before
}

compare_dates : List(U64), List(U64) -> [Before, Same, After]
compare_dates = |a, b| match (a, b) {
	([x, .. as xs], [y, .. as ys]) => if x < y Before else if x > y After else compare_dates(xs, ys)
	_ => Same
}

# `nightly-<year>-<month or name>-<day>-<sha>` as the date numbers and the sha text.
nightly_key : Str -> Try(NightlyKey, [NotNightly])
nightly_key = |id| match id.split_on("-") {
	["nightly", year, month, day, sha] if Pin.is_nightly(id) => {
		numbers = [U64.from_str(year), month_number(month), U64.from_str(day)]
		match numbers {
			[Ok(y), Ok(m), Ok(d)] => Ok({ date: [y, m, d], sha })
			_ => Err(NotNightly)
		}
	}
	_ => Err(NotNightly)
}

month_number : Str -> Try(U64, [NotMonth])
month_number = |text| match U64.from_str(text) {
	Ok(n) => Ok(n)
	Err(_) => match months.find_first(|(name, _)| name == text) {
		Ok((_, n)) => Ok(n)
		Err(_) => Err(NotMonth)
	}
}

months : List((Str, U64))
months = [("January", 1), ("February", 2), ("March", 3), ("April", 4), ("May", 5), ("June", 6), ("July", 7), ("August", 8), ("September", 9), ("October", 10), ("November", 11), ("December", 12)]
