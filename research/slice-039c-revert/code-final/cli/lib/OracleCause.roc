import Explain
import Fail
import Ident
import OracleBase
import OracleDomain
import resolve.Solver

## The causes and the text of a failure of the oracle step (slice 039s: split from `Oracle`, R-PH13, R-RP2, R-EP7, R-LD3). Pure.
OracleCause :: [].{

	# R-EP7: the releases that the proof blames, with their interval on D. A fault is a hang or a crash by the row of H. No repeat.
	causes_of : OracleBase.Input, OracleBase.Compat, Solver.Why -> List(Explain.Cause)
	causes_of = |input, compat, why| why.steps
		.keep_oks(
			|step| match step.cause {
				Probe(p) => Ok({
					label: label_of(input, p.id),
					alias: alias_of(input, p.id),
					kind: match p.kind {
						Fail => Fail
						Fault => match OracleDomain.row_of(compat.checks, compat.compiler ?? "", p.id) {
							Ok(f) => if f.outcome == Hang Hang else Crash
							Err(_) => Crash
						}
					},
					modules: p.modules,
					from: p.from,
					to: p.to,
					inferred: p.inferred,
				})
				_ => Err(NoProbe)
			},
		)
		.fold([], |found, c| if found.contains(c) found else found.append(c))

	# R-PH13: the text of a failure. A unit fail in the proof is the blame of `Units.judge` (the same text, so a run with one tuple gives the text of slice 031). Else the text of `Pick.step`.
	# R-RP2: with `assume` the lines of `Explain.lines` follow, and the details are `Explain.details`. `hint` is the oldest nightly that works (`OracleHint.hint`): the caller gives `Err(None)` when `assume` is off or the proof has no probe cause.
	failure : OracleBase.Input, OracleBase.Compat, Bool, Solver.Why, Try(Str, [None]) -> Fail
	failure = |input, compat, assume, why, hint| {
		nightly = compat.compiler ?? ""
		causes = causes_of(input, compat, why)
		blames = causes.map(blame_text).fold([], |found, text| if found.contains(text) found else found.append(text))
		first = "no tuple works: the unit check on ${nightly} fails for ${Str.join_with(blames, "; ")}"
		if causes.is_empty() {
			Fail.new(NoTuple, "no tuple works: the releases of ${Str.join_with(input.slots.map(|slot| slot.id), ", ")} do not fit together (R-C2, R-C3)")
		} else if assume {
			{ ..Fail.new(NoTuple, "${first}\n${Str.join_with(Explain.lines({ causes, hint }), "\n")}"), details: Ok(Explain.details({ held: nightly, causes, hint })) }
		} else {
			Fail.new(NoTuple, first)
		}
	}

	# R-LD3, R-EP7: `<name> <version> (<what>)`, or `the platform <name> <version> (<what>)`. A fault is `hangs` or `crashes`, a fail with no module is `no module is named`.
	blame_text : Explain.Cause -> Str
	blame_text = |c| {
		what = match c.kind {
			Hang => "hangs"
			Crash => "crashes"
			Fail => if c.modules.is_empty() "no module is named" else Str.join_with(c.modules, ", ")
		}
		"${c.label} (${what})"
	}

	# R-LD3: `<name> <version>`, or `the platform <name> <version>`.
	label_of : OracleBase.Input, Str -> Str
	label_of = |input, id| {
		name = match Ident.of_url(id) {
			Ok(ident) => "${ident.name ?? id} ${ident.version}"
			Err(_) => id
		}
		if OracleBase.platform_of(input, id) "the platform ${name}" else name
	}

	# The alias of the slot of a release (`""` for the platform: the app cannot stop using it).
	alias_of : OracleBase.Input, Str -> Str
	alias_of = |input, id| match input.slots.find_first(|slot| !slot.is_platform and (slot.candidates.any(|c| c.url == id) or OracleBase.is_current(slot, id))) {
		Ok(slot) => slot.id
		Err(_) => ""
	}
}
