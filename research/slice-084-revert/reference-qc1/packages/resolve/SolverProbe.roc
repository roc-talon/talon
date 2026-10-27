import SolverBase

Var : SolverBase.Var

Val : SolverBase.Val

Inc : SolverBase.Inc

Env : SolverBase.Env

Span : SolverBase.Span

## The incompatibilities of the probe facts (R-EP7, R-UM1, R-EP9; slice 036b3: split from `Solver`): the intervals of D where a release fails, and the incompatibility of each interval.
SolverProbe :: [].{

	## R-EP7: the incompatibilities of the probe facts, for each release of each variable that is not the compiler, in the order of the slots, values and seeds.
	probe_incs : List(U64), List(Var), SolverBase.Compat, [All, Real] -> List(Inc)
	probe_incs = |sizes, vars, compat, mode| match vars.map_with_index(|v, i| (v, i)).find_first(|(v, _)| v.kind == Compiler) {
		Ok((roc, ri)) => {
			env = { sizes, cells: Dict.from_list(compat.checks.rev().map(|c| (key(c.id, c.nightly), c))), used: Dict.from_list(compat.used.rev().map(|u| (u.id, u.modules))), domain: compat.domain, mode, ri }
			vars.map_with_index(|vr, i| (vr, i)).keep_if(|(vr, _)| vr.kind != Compiler).join_map(
				|(vr, i)| vr.vals.map_with_index(|x, p| release_incs(env, roc, i, p, x.c.id)).join(),
			)
		}
		Err(_) => []
	}
}

key : Str, Str -> Str
key = |id, nightly| "${id}@${nightly}"

# What the check of a release on a compiler of D does to a run: a fail that touches (R-UM1: no module, or a used module) goes on, a fault stands alone, the rest ends the run. An inferred fail counts in `All` only, an inferred fault never.
kind_at : Env, Str, Str -> [Touch, Fault, Rest]
kind_at = |env, id, nightly| match env.cells.get(key(id, nightly)) {
	Ok(c) => {
		used = env.used.get(id) ?? []
		is_real = c.source == Real
		if c.outcome == Fail and (env.mode == All or is_real) and (c.modules.is_empty() or c.modules.any(|m| used.contains(m))) {
			Touch
		} else if is_real and (c.outcome == Hang or c.outcome == Crash) {
			Fault
		} else {
			Rest
		}
	}
	Err(_) => Rest
}

# The intervals of D (places in D): the maximal runs of `Touch` and each `Fault`.
spans : List([Touch, Fault, Rest]) -> List(Span)
spans = |kinds| {
	r = kinds.fold_with_index(
		{ done: [], open: Err(None) },
		|acc, k, j| match k {
			Touch => match acc.open {
				Ok(_) => acc
				Err(_) => { ..acc, open: Ok(j) }
			}
			_ => {
				closed = match acc.open {
					Ok(s) => acc.done.append({ from: s, to: j - 1, kind: Fail })
					Err(_) => acc.done
				}
				{ done: if k == Fault closed.append({ from: j, to: j, kind: Fault }) else closed, open: Err(None) }
			}
		},
	)
	match r.open {
		Ok(s) => r.done.append({ from: s, to: kinds.len() - 1, kind: Fail })
		Err(_) => r.done
	}
}

release_incs : Env, Var, U64, U64, Str -> List(Inc)
release_incs = |env, roc, i, p, id| spans(env.domain.map(|n| kind_at(env, id, n))).join_map(|span| span_inc(env, roc, i, p, id, span))

# `not (release and roc in interval)`. The modules are the failing modules that the app uses, the inferred compilers are named (R-EP9).
span_inc : Env, Var, U64, U64, Str, Span -> List(Inc)
span_inc = |env, roc, i, p, id, span| {
	members = env.domain.map_with_index(|n, j| (n, j)).keep_if(|(_, j)| span.from <= j and j <= span.to).map(|(n, _)| n)
	set = roc.vals.map_with_index(|x, q| (x, q)).keep_if(|(x, _)| members.contains(x.c.id)).map(|(_, q)| q)
	used = env.used.get(id) ?? []
	cell = |n| env.cells.get(key(id, n))
	fault = span.kind == Fault
	cause = Probe({
		id,
		kind: span.kind,
		from: members.first() ?? "",
		to: members.last() ?? "",
		modules: if fault [] else SolverBase.dedupe(members.join_map(|n| (cell(n).map_ok(|c| c.modules) ?? []).keep_if(|m| used.contains(m)))),
		inferred: if fault [] else members.keep_if(|n| cell(n).map_ok(|c| c.source == Inferred) ?? Bool.False),
	})
	SolverBase.mk(env.sizes, [{ v: i, set: [p] }, { v: env.ri, set }], cause)
}
