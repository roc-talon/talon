import Closure
import Db
import Epochs
import Fail
import Pick
import Release

## The types of the oracle step and the two helpers that all its parts use (slice 039s: split from `Oracle`). `Oracle` has the three steps, `OracleRequest` builds the solver request, `OracleSearch` has the search and the probe rounds, `OracleCause` has the text of a failure, `OracleHint` has the hint. Pure.
OracleBase :: [].{

	## The input of `step` (the one of `Pick.step`).
	Input : {
		slots : List(Pick.Slot),
		strategy : [Highest, Lowest],
		now : U64,
		min_age : U64,
		snapshot : Try(U64, [None]),
		facts : List({ url : Str, release : Release }),
		unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
		paths : List(Closure.Node),
		second : Bool,
	}

	## Slice 036b (R-AL4, R-EP8, R-EP9, R-LF2): what the step knows about probes. `compiler` is the one compiler of D (the held compiler), `Err(None)` for no probe and no lookup (`--no-check`, `verify`). `checks` are the rows of the db that the command has, `looked` are the keys that it looked up,
	## `probes` is `Off` for `--no-probe`, and `conflicts` are the tuples that the ladder dropped (a list of (place of a slot, release URL) for each).
	## Slice 036b2: `used` are the scan results: for a release URL (`id`), the modules of that release that the app uses (`path` relative to the package dir, `Yaml.roc`). A row with `modules: []` is a scan that found no module.
	## Slice 036c: `domain` is D (the table above), `inferred` are the inferred facts of `Epochs.epochs` over D and the rows (`[]` when D is not read). `checks` can have the rows of any compiler of D (the command loaded them with D).
	Compat : { compiler : Try(Str, [None]), checks : List(Db.Fact), looked : List(Db.Key), probes : [Allowed, Off], conflicts : List(List({ at : U64, id : Str })), used : List({ id : Str, modules : List(Str) }), domain : Try(List(Str), [NotRead]), inferred : List(Epochs.Inferred) }

	## A pair that the step wants facts for: a release URL on a compiler. `is_platform` marks the platform (R-LD3: it has a text of its own).
	Pair : { id : Str, nightly : Str, is_platform : Bool }

	## What `step_probed` gives.
	## Slice 036c: `Wide` asks for D (the table above).
	Verdict : [Need(List(Str)), Pairs(List(OracleBase.Pair)), Scan({ ids : List(Str), chosen : List(Pick.Chosen) }), Wide, Done(List(Pick.Chosen)), Fail(Fail)]

	## Slice 039 (R-SP8, R-SP9, R-SP12, R-SP13, R-UP6): what `step_free` gives. As `Verdict`, and `Done` has the compiler that the tuple uses (`nightly`, `Err(None)` for a run with no compiler).
	Free : [Need(List(Str)), Pairs(List(OracleBase.Pair)), Scan({ ids : List(Str), chosen : List(Pick.Chosen) }), Wide, Done({ chosen : List(Pick.Chosen), nightly : Try(Str, [None]) }), Fail(Fail)]

	is_current : Pick.Slot, Str -> Bool
	is_current = |slot, url| match slot.current {
		Ok(cur) => cur == url
		Err(None) => Bool.False
	}

	platform_of : OracleBase.Input, Str -> Bool
	platform_of = |input, id| input.slots.any(|slot| slot.is_platform and (slot.candidates.any(|c| c.url == id) or is_current(slot, id)))
}
