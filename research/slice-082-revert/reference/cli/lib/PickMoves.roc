import Consent
import Fail
import Pick
import Release
import Vars

## Slice 017 (R-SP16, R-SP23, R-SP24): the decisions of a held move that `PickFlow` uses. Pure functions.
PickMoves :: [].{

	## D4: the second search runs after a first search that ended with "do not fit together" (each slot has a release), and only when a variable is movable.
	second_wanted : Fail, List(Vars.Scoped) -> Bool
	second_wanted = |fail, scoped| fail.kind == NoTuple and fail.message.contains("do not fit together") and scoped.any(|s| s.movable)

	## The moves of the second search, for the report and the prompt (R-SP16): `Pick.moves` with the name of the variable and the member files that the move writes (R-SP25).
	## `slots` are the slots of the search, `scoped` the variables in the order of the first slots.
	moves_of : { scoped : List(Vars.Scoped), slots : List(Pick.Slot), chosen : List(Pick.Chosen), facts : List({ url : Str, release : Release }) } -> List(Consent.Move)
	moves_of = |input| Pick.moves({ slots: input.slots, chosen: input.chosen, facts: input.facts }).keep_oks(
		|m| match input.scoped.find_first(|s| s.movable and s.variable.uses.first().map_ok(|u| u.alias) == Ok(m.id)) {
			Ok(s) => Ok({ alias: m.id, name: s.variable.name ?? s.variable.group.form, from: m.from, to: m.to, why: m.why, members: files_of(s.variable.uses) })
			Err(_) => Err(NoVariable)
		},
	)
}

files_of : List({ file : Str, alias : Str, url : Str, version : Str }) -> List(Str)
files_of = |uses| uses.fold([], |found, u| if found.contains(u.file) found else found.append(u.file))
