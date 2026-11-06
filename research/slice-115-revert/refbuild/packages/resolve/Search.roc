## The PubGrub core of the solver (R-AL3, R-AL5): unit propagation, decisions and conflict resolution over variables with a finite list of values. Pure: the same rows give the same answer (R-DT2). It knows no release, no fact and no probe: `Solver` makes the rows.
##
## | Part | Meaning |
## | --- | --- |
## | Variable | A number. Its values are the places `0` to `size - 1`, best first. |
## | Lit | A term on places: variable `v` has one of the places in `set`. |
## | Row | An incompatibility: its lits cannot all be true. `Base`: a row of the caller. `Derived(a, b)`: the resolution of the rows `a` and `b` (places in the table, both before this row). |
## | Trail | The entries of the partial solution, in order. An entry takes places out of one variable. It is a decision (the best place) or it comes from a row (unit propagation). Each has a decision level. |
## | Conflict | A row with all lits true. Resolution takes the lit with the latest satisfier. A decision, or a satisfier that is the only one at its level, ends it: the row is learned, and the search goes back to the level of the other satisfiers. Else the row and the cause of the satisfier give a new row. A row with no lit is the end. |
##
## The table (`rows`) of a `NoTuple` has every row, also each resolvent: `last` is the row with no lit. The caller builds the explanation from it.
Search :: [].{

	## A term on places: the variable `v` has one of the places in `set` (ascending).
	Lit : { v : U64, set : List(U64) }

	## An incompatibility. The lits are in the order of `v`, one for each variable, none with all places of its variable.
	Row : { lits : List(Search.Lit), from : [Base, Derived(U64, U64)] }

	## The best place of each variable, or the table with the empty row.
	Outcome : [Found(List(U64)), NoTuple({ rows : List(Search.Row), last : U64 })]

	## `sizes` are the numbers of places of the variables. The decision takes the first variable with more than one place, and its first place: the result is the best tuple.
	run : List(Search.Row), List(U64) -> Search.Outcome
	run = |rows, sizes| {
		init = sizes.map(|n| below(n))
		go({ rows, trail: [], state: init, level: 0 }, init)
	}
}

Entry : { v : U64, left : List(U64), by : [Decision, From(U64)], level : U64 }

# The possible places of each variable are in `state`.
Run : { rows : List(Search.Row), trail : List(Entry), state : List(List(U64)), level : U64 }

Move : [Conflict(U64), Move({ at : U64, lit : Search.Lit }), Quiet]

Resolved : [Lost({ rows : List(Search.Row), last : U64 }), Learned({ rows : List(Search.Row), back : U64 })]

below : U64 -> List(U64)
below = |n| List.repeat(0, n).map_with_index(|_, i| i)

set_at : List(List(U64)), U64, List(U64) -> List(List(U64))
set_at = |state, v, left| state.map_with_index(|s, k| if k == v left else s)

# The state after the entries of the trail.
state_of : List(List(U64)), List(Entry) -> List(List(U64))
state_of = |init, trail| trail.fold(init, |st, e| set_at(st, e.v, e.left))

go : Run, List(List(U64)) -> Search.Outcome
go = |r, init| match next_move(r.rows, r.state) {
	Conflict(i) => match resolve(r.rows, r.trail, init, i) {
		Lost(x) => NoTuple(x)
		Learned(x) => {
			trail = r.trail.keep_if(|e| e.level <= x.back)
			go({ rows: x.rows, trail, state: state_of(init, trail), level: x.back }, init)
		}
	}
	Move(m) => {
		left = (r.state.get(m.lit.v) ?? []).keep_if(|x| !m.lit.set.contains(x))
		go({ ..r, trail: r.trail.append({ v: m.lit.v, left, by: From(m.at), level: r.level }), state: set_at(r.state, m.lit.v, left) }, init)
	}
	Quiet => match r.state.find_first_index(|s| s.len() > 1) {
		Ok(v) => {
			best = [(r.state.get(v) ?? []).first() ?? 0]
			go({ rows: r.rows, trail: r.trail.append({ v, left: best, by: Decision, level: r.level + 1 }), state: set_at(r.state, v, best), level: r.level + 1 }, init)
		}
		Err(_) => Found(r.state.map(|s| s.first() ?? 0))
	}
}

# The first row that is a conflict or a unit.
next_move : List(Search.Row), List(List(U64)) -> Move
next_move = |rows, state| rows.map_with_index(|row, i| (i, row)).fold_until(
	Quiet,
	|_, (i, row)| match fire(i, row.lits, state) {
		Quiet => Continue(Quiet)
		found => Break(found)
	},
)

# A lit is true when all possible places are in its set, false when none is. One false lit: the row holds already. All true: a conflict. One open lit and the rest true: that lit must be false.
fire : U64, List(Search.Lit), List(List(U64)) -> Move
fire = |i, lits, state| {
	classes = lits.map(|l| (l, class_of(l, state)))
	if classes.any(|(_, c)| c == Contra) {
		Quiet
	} else {
		match classes.keep_if(|(_, c)| c == Open) {
			[] => Conflict(i)
			[(l, _)] => Move({ at: i, lit: l })
			_ => Quiet
		}
	}
}

class_of : Search.Lit, List(List(U64)) -> [Pro, Open, Contra]
class_of = |l, state| {
	s = state.get(l.v) ?? []
	if s.all(|x| l.set.contains(x)) {
		Pro
	} else if s.any(|x| l.set.contains(x)) {
		Open
	} else {
		Contra
	}
}

entry_at : List(Entry), U64 -> Entry
entry_at = |trail, i| trail.get(i) ?? { v: 0, left: [], by: Decision, level: 0 }

# The place in the trail of the first entry that makes the lit true.
satisfier : List(Entry), Search.Lit -> U64
satisfier = |trail, l| trail.find_first_index(|e| e.v == l.v and e.left.all(|x| l.set.contains(x))) ?? 0

# Conflict resolution of the row `cur`, which is a conflict for this trail.
resolve : List(Search.Row), List(Entry), List(List(U64)), U64 -> Resolved
resolve = |rows, trail, init, cur| match rows.get(cur) {
	Ok(row) => if row.lits.is_empty() Lost({ rows, last: cur }) else resolve_row(rows, trail, init, cur, row.lits)
	Err(_) => Lost({ rows, last: cur })
}

resolve_row : List(Search.Row), List(Entry), List(List(U64)), U64, List(Search.Lit) -> Resolved
resolve_row = |rows, trail, init, cur, lits| {
	sats = lits.map(|l| (l, satisfier(trail, l)))
	top_at = sats.fold(0, |m, (_, i)| U64.max(m, i))
	others = sats.keep_if(|(_, i)| i != top_at)
	others_level = others.fold(0, |m, (_, i)| U64.max(m, entry_at(trail, i).level))
	top = (sats.find_first(|(_, i)| i == top_at) ?? ({ v: 0, set: [] }, 0)).0
	e = entry_at(trail, top_at)
	match e.by {
		Decision => Learned({ rows, back: others_level })
		From(c) => {
			cause = (rows.get(c) ?? { lits: [], from: Base }).lits
			s = cause.find_first(|l| l.v == e.v) ?? { v: e.v, set: [] }
			prev = U64.max(others_level, prior_level(trail, init, top_at, top, s))
			if prev < e.level {
				Learned({ rows, back: prev })
			} else {
				resolvent = merge(init, others.map(|(l, _)| l).concat(cause.keep_if(|l| l.v != e.v)), top, s)
				resolve(rows.append({ lits: resolvent, from: Derived(cur, c) }), trail, init, rows.len())
			}
		}
	}
}

# The level of the earliest state of the variable of `t` that, without the places of `s`, makes `t` true (the part of `t` that the satisfier does not give alone).
prior_level : List(Entry), List(List(U64)), U64, Search.Lit, Search.Lit -> U64
prior_level = |trail, init, at, t, s| {
	states = [((init.get(t.v) ?? []), 0)].concat(trail.map_with_index(|e, i| (e, i)).keep_if(|(e, i)| i < at and e.v == t.v).map(|(e, _)| (e.left, e.level)))
	match states.find_first(|(left, _)| left.keep_if(|x| !s.set.contains(x)).all(|x| t.set.contains(x))) {
		Ok((_, level)) => level
		Err(_) => 0
	}
}

# The lits of a resolvent: the other lits, joined by variable, and the union of `t` and `s` (left out when it has all places).
merge : List(List(U64)), List(Search.Lit), Search.Lit, Search.Lit -> List(Search.Lit)
merge = |init, rest, t, s| {
	all = below((init.get(t.v) ?? []).len())
	union = all.keep_if(|x| t.set.contains(x) or s.set.contains(x))
	extra = if union.len() == all.len() [] else [{ v: t.v, set: union }]
	rest.concat(extra).fold(
		[],
		|acc, l| match acc.find_first_index(|a| a.v == l.v) {
			Ok(j) => acc.map_with_index(|a, k| if k == j { v: a.v, set: a.set.keep_if(|x| l.set.contains(x)) } else a)
			Err(_) => acc.append(l)
		},
	).sort_with(|a, b| a.v.order_relative_to(b.v))
}
