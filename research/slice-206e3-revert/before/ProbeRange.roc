import Db
import Epochs

## The range search of `tln probe --range` (slice 037, Resolution 4 "tln probe", R-PB3, R-PB4, R-EP6, R-PP2, R-AL4). Part A (pure, TESTING.md 2.2 part B): a solver-like step. The command calls `step`, runs the probes that it asks for, adds the facts, and calls `step` again until it gives `Done`.
##
## The target is one hash. `domain` is the compiler list D (R-EP11) in R-NS1 order, the oldest first. `askable` are the releases of D that the command may start a probe on: the candidates that the `nightly` switch and `min-release-age` allow (R-NS3, R-C7)
## that are installed (slice 037: no download, R-NI4). `facts` are the rows that the command has (a row of another hash than `hash` is not read). A row with a target other than `any` is not read (a unit check, R-LD2). A row with a release that is not in D is not read.
## The cell of a release of D:
##
## | Cell | Where it comes from |
## | --- | --- |
## | real pass, real fail | a row of `facts` with the outcome `Pass` or `Fail` |
## | fault | a row with `Hang` or `Crash` (R-EP5: it is a fact, so the release is not asked again. It is no pass, no fail, and gives no inferred fact) |
## | inferred pass, inferred fail | `Epochs.epochs` of D and `facts` (R-EP6, R-EP14) |
## | unknown | none of the above |
##
## `step` (the tested reading, questions S1 and S2 of the slice file). Let p be the newest release of D with a real pass.
##
## | # | Case | Result |
## | --- | --- | --- |
## | 1 | The askable releases that are newer than p (all askable releases when there is no p) and have no real fact (a row of any outcome) are not empty | `Need` with the newest 3 of them, the newest first (R-PB3 "starts at the newest installed candidate", R-PP2) |
## | 2 | There is no p | `Done(NoPass)` |
## | 3 | Else q is the oldest release such that each release from q to p has a pass (real or inferred). F is the nearest release older than q with a real fail (none: before the start of D). K are the askable releases between F and q (both not in K) with no real fact, oldest first. K is not empty | `Need(picks of K)`. With 3 releases or fewer in K: all of K. With more: the releases at the places `m / 4`, `m / 2` and `3 * m / 4` of K (`m` is the length of K, places count from 0, integer division), oldest first. One round cuts the open range in 4 parts (R-PP2) |
## | 4 | K is empty | `Done(Range)`, see `found` |
##
## No `Need` has more than 3 releases, has a release that is not askable, has a release with a real fact, or has a release twice (R-AL4, R-PP4).
ProbeRange :: [].{

	## One end of a range. `real` is true when the end is a real fact (R-PB4): the release next to it, outside the range, has a real fail, or the end is the end of D. Else the end is `unknown` (the release next to it has no real fact, or a fault).
	End : { id : Str, real : Bool }

	## The result. `Range` has the lower end `from` (the older) and the upper end `to`. R-PB3: the maximal interval of D that contains p, in which each release has a pass, real or inferred. `NoPass`: no release of D has a real pass.
	Found : [NoPass, Range({ from : ProbeRange.End, to : ProbeRange.End })]

	## What `step` gives: the releases to probe in one round (the order of the list is the order of the results, R-PP3), or the result.
	Round : [Need(List(Str)), Done(ProbeRange.Found)]

	## `hash` is the target. A row of `facts` of another hash is not read.
	Input : { hash : Str, domain : List(Str), askable : List(Str), facts : List(Db.Fact) }

	## The table above.
	step : ProbeRange.Input -> ProbeRange.Round
	step = |input| {
		w = world_of(input)
		newest = newest_pass(w)
		above = w.places.keep_if(|i| above_pass(newest, i) and askable_at(w, i) and !has_real(cell_at(w, i)))
		if !above.is_empty() {
			Need(ids_at(w, above.rev().take_first(3)))
		} else {
			match newest {
				Err(NoPass) => Done(NoPass)
				Ok(p) => {
					q = low_of(w, p)
					start = match w.places.keep_if(|i| i < q).rev().find_first(|i| cell_at(w, i) == Fail) {
						Ok(f) => f + 1
						Err(_) => 0
					}
					open = w.places.keep_if(|i| i >= start and i < q and askable_at(w, i) and !has_real(cell_at(w, i)))
					if open.is_empty() Done(found_of(w)) else Need(ids_at(w, picks_of(open)))
				}
			}
		}
	}

	## The range for the facts that are known now, with no `Need` (rows 2 and 4 of the table above, also when K is not empty). A command that stops for the budget (R-PB4) prints this. With no real pass it is `NoPass`.
	## The ends: the lower end is the id of q, `real` when q is the first release of D or the release before q has a real fail. The upper end is the id of the newest release t such that each release from p to t has a pass (inferred passes above p come
	## from an epoch of more than one release, so in P1 t is p), `real` when t is the last release of D or the release after t has a real fail.
	found : ProbeRange.Input -> ProbeRange.Found
	found = |input| found_of(world_of(input))
}

# The cell of a release of D (the table in the doc of `ProbeRange`).
Cell : [Gap, Pass, Fail, Fault, IPass, IFail]

World : { ids : List(Str), askable : List(Str), cells : List(Cell), places : List(U64) }

world_of : ProbeRange.Input -> World
world_of = |input| {
	rows = input.facts.keep_if(|f| f.hash == input.hash and f.target == "any" and input.domain.contains(f.nightly))
	releases = input.domain.map(|id| { id, published_at: 0, asset: Err(NoAsset) })
	inferred = Epochs.epochs(releases, rows).inferred
	cell_of = |id| match rows.find_first(|f| f.nightly == id) {
		Ok(f) => match f.outcome {
			Pass => Pass
			Fail => Fail
			Hang | Crash => Fault
		}
		Err(_) => match inferred.find_first(|i| i.nightly == id) {
			Ok(i) => match i.outcome {
				Pass => IPass
				Fail => IFail
			}
			Err(_) => Gap
		}
	}
	{ ids: input.domain, askable: input.askable, cells: input.domain.map(cell_of), places: input.domain.map_with_index(|_, i| i) }
}

cell_at : World, U64 -> Cell
cell_at = |w, i| w.cells.get(i) ?? Gap

# R-EP5: a real pass, a real fail and a fault are real facts. An inferred cell and a gap are not.
has_real : Cell -> Bool
has_real = |cell| match cell {
	Pass | Fail | Fault => Bool.True
	_ => Bool.False
}

passes : Cell -> Bool
passes = |cell| match cell {
	Pass | IPass => Bool.True
	_ => Bool.False
}

askable_at : World, U64 -> Bool
askable_at = |w, i| w.askable.contains(w.ids.get(i) ?? "")

ids_at : World, List(U64) -> List(Str)
ids_at = |w, at| at.keep_oks(|i| w.ids.get(i))

# p: the place of the newest release with a real pass.
newest_pass : World -> Try(U64, [NoPass])
newest_pass = |w| w.places.keep_if(|i| cell_at(w, i) == Pass).last().map_err(|_| NoPass)

above_pass : Try(U64, [NoPass]), U64 -> Bool
above_pass = |newest, i| match newest {
	Ok(p) => i > p
	Err(NoPass) => Bool.True
}

# q: the oldest place such that each release from q to p has a pass.
low_of : World, U64 -> U64
low_of = |w, p| w.places.keep_if(|i| i <= p).rev().fold_until(p, |at, i| if passes(cell_at(w, i)) Continue(i) else Break(at))

# t: the newest place such that each release from p to t has a pass.
high_of : World, U64 -> U64
high_of = |w, p| w.places.keep_if(|i| i >= p).fold_until(p, |at, i| if passes(cell_at(w, i)) Continue(i) else Break(at))

# R-PP2: all open places when there are 3 or fewer, else the places m/4, m/2 and 3m/4.
picks_of : List(U64) -> List(U64)
picks_of = |open| {
	m = open.len()
	if m <= 3 open else [m / 4, m / 2, 3 * m / 4].keep_oks(|at| open.get(at))
}

# An end is real when the release next to it, outside the range, is a real fail, or the end is an end of D (R-PB3).
found_of : World -> ProbeRange.Found
found_of = |w| match newest_pass(w) {
	Err(NoPass) => NoPass
	Ok(p) => {
		q = low_of(w, p)
		t = high_of(w, p)
		id_at = |i| w.ids.get(i) ?? ""
		Range({
			from: { id: id_at(q), real: q == 0 or cell_at(w, q - 1) == Fail },
			to: { id: id_at(t), real: t + 1 >= w.ids.len() or cell_at(w, t + 1) == Fail },
		})
	}
}
