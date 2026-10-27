import Fail
import PinOrder
import Ranges
import Text

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
	is_nightly = PinOrder.is_nightly

	## R-NS5, R-NS7, R-RP2, R-NS1: does the range admit the compiler id? `Any` admits all. `Exactly(a)` admits the nightly `a` in either tag form (R-CV1: the date and the sha are equal) and no other
	## id (slice 022, G1 of slice 020: `nightly-2026-July-23-abc1234` and `nightly-2026-07-23-abc1234` are one nightly). `AtLeast(a)` admits a nightly that `Pin.order` puts at or after `a`
	## (`times`: the `published_at` that the caller knows, see `Pin.order`; with no time the same date is ordered by the tag text, `a` itself included). `Semver(range)` admits a
	## release that the range admits, and no nightly.
	##
	## `times` has the `published_at` of each id that the caller knows (the `.talon.json` of an installed compiler, or the list of compilers). `[]` is allowed.
	admits : { req : Req, id : Str, times : List({ id : Str, published_at : U64 }) } -> Bool
	admits = |facts| match facts.req {
		Any => Bool.True
		Exactly(a) => Pin.same_id(a, facts.id)
		AtLeast(a) => PinOrder.at_least(a, facts.id, facts.times)
		Semver(range) => !Pin.is_nightly(facts.id) and Ranges.admits({ ranges: [range], version: facts.id })
	}

	## R-NS1 (slice 022): the order of 2 compiler ids, for the newest installed compiler of rank 4 (R-SO4) and for `AtLeast`. The key of an id is its day, then its kind, then its time, then its text:
	##
	## | Part | Value |
	## | --- | --- |
	## | day | A nightly: the date of its tag (both tag forms). A release: the UTC day of its `published_at` in `times`. A release with no time has no day. |
	## | kind | On the same day a release is newer than a nightly (R-NS1) |
	## | time | Two nightlies of one day: the `published_at` in `times` when both are known (R-NS1: it is Talon's own order, roc gives them one rank) |
	## | text | Else (and for equal times): nightlies by the tag text in byte order, releases by version (`Semver`) |
	##
	## An id with no day (a release with no time) is older than every id that has a day. Two ids with no day: by version. `order` is total on ids that are a nightly or a release. For any other id the result is `Same`.
	order : { a : Str, b : Str, times : List({ id : Str, published_at : U64 }) } -> [Before, Same, After]
	order = |facts| PinOrder.order_of(facts.a, facts.b, facts.times)

	## R-CV1 (slice 022): are the 2 ids one compiler? Equal texts, or two nightlies with the same date and the same sha (the two tag forms: `nightly-2026-July-23-abc1234` and `nightly-2026-07-23-abc1234`).
	same_id : Str, Str -> Bool
	same_id = PinOrder.same_id

	## R-NS8 to R-NS11 (slice 022): the value of the `nightly` switch and where it comes from. The first source that is set wins: the environment (`TALON_NIGHTLY`), `talon.toml`, `config.toml`, else on (`Default`).
	## `ResolveBase.settings_of` and `tln roc install` both use it.
	switch : { env : Try(Bool, [Unset]), toml : Try(Bool, [Unset]), config : Try(Bool, [Unset]) } -> { nightly : Bool, source : Source }
	switch = |facts| match (facts.env, facts.toml, facts.config) {
		(Ok(on), _, _) => { nightly: on, source: Env }
		(_, Ok(on), _) => { nightly: on, source: Toml }
		(_, _, Ok(on)) => { nightly: on, source: Config }
		_ => { nightly: Bool.True, source: Default }
	}

	## The decision for the `roc:` entries of the members (Design 4.4 R-WS4, Resolution 9 R-RP1 to R-RP3, Design 4.2 R-H6, Design 7 R-PH8).
	##
	## Input:
	##
	## | Field | Holds |
	## | --- | --- |
	## | `members` | One row for each member file, in order: its `roc:` entry text (`Err(NoPin)` when it has none), and `changes`: the command writes the header of this member for another change |
	## | `compiler` | The id of the selected compiler: in P0 the `roc` on `PATH` (R-PH8), when its id is a nightly or a release. `Err(NoCompiler)` for no compiler, or a local build id (`debug-<sha>`: R-SO11, never written). |
	## | `compiler_from` | Slice 022: the rank that selected `compiler` (`Compiler.select`): `Range` (4), `VersionFile` (5), `Default` (6) or `Path` (7). It is the `held_from` of the last table row. |
	## | `toolchain` | `ROC_TOOLCHAIN` (rank 2, R-SO2), a full compiler id that `Compiler.toolchain_of` checked. `Err(Unset)` when it is not set (slice 013) |
	## | `role` | `Lock`: the command holds and writes the nightly (`install`, `add`, `update`, `remove`). `Verify`: `tln verify`, it writes nothing (R-SO21). (slice 013) |
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
	## | A member that has no pin, and `held` is a local build (`git-<name>`, `link-<name>`, `copy-<name>`: not a nightly, not a release) | No write, never (R-R4, R-LK3, R-SO11, R-H6: Talon never writes a local build as a pin). `held` stays the local build. |
	## | A member that has no pin, with `no_check` true (R-H6) | No write: Talon writes none if there was none |
	## | A member that has no pin, `changes` false | No write: a missing pin alone is not a change (R-RP3) |
	## | A member that has a pin | No write, never (R-RP1, R-RP2: P0 holds the nightly) |
	##
	## Slice 013 (R-SO19 to R-SO21, G-pin-gate section 3): `held` and `held_from` for each case, and the `note`:
	##
	## | Pin of the members | `toolchain` | `role` | `held` | `held_from` | `note` |
	## | --- | --- | --- | --- | --- | --- |
	## | `P` | not set, or `P` | `Lock` or `Verify` | `P` | `Pin` | `Err(None)` |
	## | `P` | `T`, not `P` | `Lock` | `P` (R-SO20: the pin stays, the probes run on it) | `Pin` | `Ok(<text>)`, see `toolchain_note` |
	## | `P` | `T`, not `P` | `Verify` | `T` (R-SO21: `verify` writes nothing, so it probes on rank 2) | `Env` | `Err(None)` |
	## | none | `T` | `Lock` or `Verify` | `T` (R-SO19: rank 2 selects the held nightly. R-SO22: no `roc` on `PATH` is needed) | `Env` | `Err(None)` |
	## | none | not set | `Lock` or `Verify` | `compiler` | `compiler_from` (slice 022: `Range`, `VersionFile`, `Default` or `Path`) | `Err(None)` |
	##
	## `outside` is the same in all rows: R-SO21 says that the pin of the header is checked also in `Verify` (R-RP2). `writes` is made from `held` (R-RP3).
	##
	## `writes` has the order of `members`.
	## `held_from` says which rank gave `held`: `Pin` needs no `gate` (G5), the other tags do (`ResolveBase.check_pin`).
	Decision : {
		held : Try(Str, [NoCompiler]),
		held_from : [Pin, Env, Range, VersionFile, Default, Path],
		note : Try(Str, [None]),
		writes : List({ file : Str, id : Str }),
		outside : Try(Str, [None]),
	}

	## Where the value of the `nightly` switch comes from (R-NS8 to R-NS10): the environment, `[toolchain] nightly` of `talon.toml`, `nightly` of `config.toml`, or the default (on).
	Source : [Env, Toml, Config, Default]

	decide : {
		members : List({ file : Str, pin : Try(Str, [NoPin]), changes : Bool }),
		compiler : Try(Str, [NoCompiler]),
		compiler_from : [Range, VersionFile, Default, Path],
		toolchain : Try(Str, [Unset]),
		role : [Lock, Verify],
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
			pin = match texts {
				[one] => Ok(one)
				_ => Err(NoPin)
			}
			choice = held_choice(pin, { compiler: facts.compiler, compiler_from: facts.compiler_from, toolchain: facts.toolchain, role: facts.role })
			can_write = !facts.no_check
			writes = match choice.held {
				Ok(id) if can_write and is_compiler_id(id) => facts.members.keep_if(|m| m.pin == Err(NoPin) and m.changes).map(|m| { file: m.file, id })
				_ => []
			}
			Ok({ held: choice.held, held_from: choice.held_from, note: choice.note, writes, outside: outside_pin(texts, { req: facts.req, nightly: facts.nightly }) })
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

	## R-SO20: the one note of a `Lock` command that holds the header pin `pin` while `ROC_TOOLCHAIN` names `toolchain`. It names both ids and the way to change the pin. The text is a proposal (TW24).
	## Slice 026 (gap G2 of slice 024b, R-U1, R-R4, R-LK3): `tln roc use` refuses a `git-*`, `link-*` or `copy-*` id, so the note has 2 forms. The form depends on `toolchain` (`Pin.is_id`):
	##
	## | `toolchain` | Text |
	## | --- | --- |
	## | A nightly or a release | `ROC_TOOLCHAIN is <toolchain>, but the header pin is <pin>. This command keeps the pin. To change the pin, run tln roc use <toolchain>.` |
	## | `git-*`, `link-*`, `copy-*` | `ROC_TOOLCHAIN is <toolchain>, but the header pin is <pin>. This command keeps the pin. A git, link or copy build cannot be a pin, so tln roc use does not take it. Use ROC_TOOLCHAIN or tln roc default for it.` |
	toolchain_note : { pin : Str, toolchain : Str } -> Str
	toolchain_note = |facts| {
		start = "ROC_TOOLCHAIN is ${facts.toolchain}, but the header pin is ${facts.pin}. This command keeps the pin."
		if local_build(facts.toolchain) {
			"${start} A git, link or copy build cannot be a pin, so tln roc use does not take it. Use ROC_TOOLCHAIN or tln roc default for it."
		} else {
			"${start} To change the pin, run tln roc use ${facts.toolchain}."
		}
	}

	## R-U5, R-NS5, R-NS7 (slice 026b): the stop of `tln roc use` for the new compiler `id` (the full id that the operand named). `req` is `[toolchain] roc` of the root `talon.toml`, `req_text` is its text, `nightly` is the switch and `source` is where it comes from. `times` is as for `Pin.admits`. The checks, in this order.
	## `tln roc use` never edits `talon.toml`. Kind `NoTuple` (exit 10, as R-NS2, R-SO19 and `Pin.outside_failure`: review of slice 026b). The texts name the switch or the range, as `outside_failure` does (a proposal, TW24):
	##
	## | Case | Text |
	## | --- | --- |
	## | `id` is a nightly, and `nightly` is false | `tln roc use <id>: it is a nightly, and nightly is false (set by <source text>). Use a release, or change the nightly switch. tln roc use does not change talon.toml.` |
	## | `req` is set and does not admit `id` | `tln roc use <id>: it is outside [toolchain] roc (<req text>). Use a compiler in the range, or change [toolchain] roc. tln roc use does not change talon.toml.` |
	## | Else | `Ok({})` |
	use_gate : { id : Str, req : Try(Req, [Unset]), req_text : Try(Str, [Unset]), nightly : Bool, source : Source, times : List({ id : Str, published_at : U64 }) } -> Try({}, Fail)
	use_gate = |facts| {
		keep = "tln roc use does not change talon.toml."
		if Pin.is_nightly(facts.id) and !facts.nightly {
			Err(Fail.new(NoTuple, "tln roc use ${facts.id}: it is a nightly, and nightly is false (set by ${Pin.source_text(facts.source)}). Use a release, or change the nightly switch. ${keep}"))
		} else {
			match (facts.req, facts.req_text) {
				(Ok(req), Ok(text)) if !Pin.admits({ req, id: facts.id, times: facts.times }) => Err(Fail.new(NoTuple, "tln roc use ${facts.id}: it is outside [toolchain] roc (${text}). Use a compiler in the range, or change [toolchain] roc. ${keep}"))
				_ => Ok({})
			}
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

	## R-SO13, R-NS2, R-NS3, R-PH7: the check of the selected compiler (the `roc` on `PATH`) when no member has a pin (`Decision.held_from` is `Path`).
	## P0 cannot select another compiler. The switch is checked first (R-NS2: with the switch off the domain of nightlies is empty).
	##
	## | Case | Result |
	## | --- | --- |
	## | `compiler` is a nightly, and `nightly` is false | Failure, kind `NoTuple` (exit 10): `the roc on PATH, <id>, is a nightly, and nightly is false (set by <source text>). No roc release is known, so no compiler can be selected.` |
	## | `req` does not admit `compiler` | Failure, kind `Consent` (exit 13, R-PH7): `the roc on PATH, <id>, is outside [toolchain] roc (<req text>). This version of tln runs only the roc on PATH, so it cannot select another compiler.` |
	## | Else | `Ok({})` |
	##
	## Slice 013 (R-SO19, R-SO13, G-pin-gate W4): `held_from` is the rank that selected `compiler`. `Path` gives the rows above. `Env` (no pin, `ROC_TOOLCHAIN` selected it) is exit 10 (kind `NoTuple`) for both a range that does not
	## admit it and a nightly with the switch off. The switch is checked first, as for `Path`. The texts name the rank (a proposal, TW24):
	##
	## | Case with `Env` | Text |
	## | --- | --- |
	## | The switch is off and `compiler` is a nightly | `the compiler <id> from ROC_TOOLCHAIN is a nightly, and nightly is false (set by <source text>). Change ROC_TOOLCHAIN or the nightly switch.` |
	## | `req` does not admit `compiler` | `the compiler <id> from ROC_TOOLCHAIN is outside [toolchain] roc (<req text>). Change ROC_TOOLCHAIN or [toolchain] roc.` |
	##
	## Slice 022 (R-SO19, R-NS2, R-NS6): the same 2 rows, exit 10 and the same text form for `VersionFile` and `Default`. The rank names and the fix are:
	##
	## | `held_from` | `from <rank>` | Fix, with the switch | Fix, with the range |
	## | --- | --- | --- | --- |
	## | `VersionFile` | `from .roc-version` | `Change .roc-version or the nightly switch.` | `Change .roc-version or [toolchain] roc.` |
	## | `Default` | `from the global default` | `Change the default (tln roc default) or the nightly switch.` | `Change the default (tln roc default) or [toolchain] roc.` |
	##
	## `Range` is always `Ok({})`: rank 4 chooses inside the range and the switch (`Compiler.select`), so it cannot fail them.
	##
	## A compiler that is not a nightly and not a release (`Pin.is_id` is false: `git-<sha8>`, `link-<name>`, `copy-<name>`, a local build) is never checked, for each `held_from` (R-NS6, R-SO19: Talon never writes it as a pin): `Ok({})`.
	##
	## The caller does not call `gate` when a header has a pin (G5: R-RP2 checks the pin, and `Compiler.require` checks the pin compiler at the first probe), and not for `Verify` with `Env` (R-NS4).
	gate : { compiler : Str, held_from : [Env, Range, VersionFile, Default, Path], req : Try(Req, [Unset]), req_text : Try(Str, [Unset]), nightly : Bool, source : Source } -> Try({}, Fail)
	gate = |facts| {
		switch_off = Pin.is_nightly(facts.compiler) and !facts.nightly
		source = Pin.source_text(facts.source)
		outside = match (facts.req, facts.req_text) {
			(Ok(req), Ok(text)) if !Pin.admits({ req, id: facts.compiler, times: [] }) => Ok(text)
			_ => Err(None)
		}
		if !Pin.is_id(facts.compiler) or facts.held_from == Range {
			Ok({})
		} else if facts.held_from == Path {
			match (switch_off, outside) {
				(Bool.True, _) => Err(Fail.new(NoTuple, "the roc on PATH, ${facts.compiler}, is a nightly, and nightly is false (set by ${source}). No roc release is known, so no compiler can be selected."))
				(_, Ok(text)) => Err(Fail.new(Consent, "the roc on PATH, ${facts.compiler}, is outside [toolchain] roc (${text}). This version of tln runs only the roc on PATH, so it cannot select another compiler."))
				_ => Ok({})
			}
		} else {
			words = rank_words(facts.held_from)
			head = "the compiler ${facts.compiler} from ${words.from}"
			match (switch_off, outside) {
				(Bool.True, _) => Err(Fail.new(NoTuple, "${head} is a nightly, and nightly is false (set by ${source}). Change ${words.fix} or the nightly switch."))
				(_, Ok(text)) => Err(Fail.new(NoTuple, "${head} is outside [toolchain] roc (${text}). Change ${words.fix} or [toolchain] roc."))
				_ => Ok({})
			}
		}
	}
}

# R-SO19: how the gate texts name a rank, and what the user changes.
rank_words : [Env, Range, VersionFile, Default, Path] -> { from : Str, fix : Str }
rank_words = |rank| match rank {
	VersionFile => { from: ".roc-version", fix: ".roc-version" }
	Default => { from: "the global default", fix: "the default (tln roc default)" }
	_ => { from: "ROC_TOOLCHAIN", fix: "ROC_TOOLCHAIN" }
}

# R-SO19 to R-SO21: the held value, the rank that gave it, and the note (the table of `Pin.decide`).
held_choice : Try(Str, [NoPin]), { compiler : Try(Str, [NoCompiler]), compiler_from : [Range, VersionFile, Default, Path], toolchain : Try(Str, [Unset]), role : [Lock, Verify] } -> { held : Try(Str, [NoCompiler]), held_from : [Pin, Env, Range, VersionFile, Default, Path], note : Try(Str, [None]) }
held_choice = |pin, facts| match (pin, facts.toolchain) {
	(Ok(p), Ok(t)) if t != p => match facts.role {
		Lock => { held: Ok(p), held_from: Pin, note: Ok(Pin.toolchain_note({ pin: p, toolchain: t })) }
		Verify => { held: Ok(t), held_from: Env, note: Err(None) }
	}
	(Ok(p), _) => { held: Ok(p), held_from: Pin, note: Err(None) }
	(Err(NoPin), Ok(t)) => { held: Ok(t), held_from: Env, note: Err(None) }
	(Err(NoPin), Err(Unset)) => {
		from = match facts.compiler_from {
			Range => Range
			VersionFile => VersionFile
			Default => Default
			Path => Path
		}
		{ held: facts.compiler, held_from: from, note: Err(None) }
	}
}

# A git, link or copy build: its id has one of these prefixes (`Manage.kind_of`).
local_build : Str -> Bool
local_build = |id| id.starts_with("git-") or id.starts_with("link-") or id.starts_with("copy-")

# A nightly tag, or a release version `X.Y.Z`.
is_compiler_id : Str -> Bool
is_compiler_id = |text| Pin.is_nightly(text) or PinOrder.is_release(text)

# R-NS5, R-NS7: the pin of the workspace (the one text, when the members agree) against the range and the switch.
outside_pin : List(Str), { req : Try(Pin.Req, [Unset]), nightly : Bool } -> Try(Str, [None])
outside_pin = |texts, facts| match texts {
	[pin] => {
		out_of_range = match facts.req {
			Ok(req) => !Pin.admits({ req, id: pin, times: [] })
			Err(Unset) => Bool.False
		}
		if out_of_range or (Pin.is_nightly(pin) and !facts.nightly) Ok(pin) else Err(None)
	}
	_ => Err(None)
}
