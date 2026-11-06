import Search
import SolverBase

Var : SolverBase.Var

Val : SolverBase.Val

Inc : SolverBase.Inc

Env : SolverBase.Env

Span : SolverBase.Span

## The explanation of a failure (slice 036b3: split from `Solver`): the cone of the empty row and its steps.
SolverWhy :: [].{

	## The explanation: the cone of the empty row, in the order of the table (D9).
	why_of : List(Var), List(Inc), List(Search.Row), U64 -> SolverBase.Why
	why_of = |vars, incs, rows, last| {
		marked = cone(rows, last)
		{ steps: marked.map(|i| step_of(vars, incs, marked, rows, i)) }
	}
}

cone : List(Search.Row), U64 -> List(U64)
cone = |rows, last| List.repeat(0, last + 1).map_with_index(|_, k| last - k).fold([], |acc, i| if i == last or acc.any(|j| refers(rows, j, i)) acc.append(i) else acc).rev()

refers : List(Search.Row), U64, U64 -> Bool
refers = |rows, j, i| match rows.get(j) {
	Ok(row) => match row.from {
		Derived(a, b) => a == i or b == i
		Base => Bool.False
	}
	Err(_) => Bool.False
}

step_of : List(Var), List(Inc), List(U64), List(Search.Row), U64 -> SolverBase.Step
step_of = |vars, incs, marked, rows, i| {
	row = rows.get(i) ?? { lits: [], from: Base }
	at = |n| marked.find_first_index(|x| x == n) ?? 0
	{
		terms: row.lits.map(|l| term_of(vars, l)),
		cause: match row.from {
			Base => incs.get(i).map_ok(|x| x.cause) ?? Given
			Derived(a, b) => Derived(at(a), at(b))
		},
	}
}

term_of : List(Var), Search.Lit -> SolverBase.Term
term_of = |vars, l| match vars.get(l.v) {
	Ok(vr) => { name: vr.name, ids: l.set.keep_oks(|p| vr.vals.get(p).map_ok(|x| x.c.id)), sign: In }
	Err(_) => { name: "", ids: [], sign: In }
}
