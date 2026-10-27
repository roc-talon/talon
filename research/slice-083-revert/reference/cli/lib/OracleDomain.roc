import Db
import Epochs
import Ident
import resolve.Solver

## The checks of the domain D for the oracle step (slice 036c, R-EP7, R-EP8, R-EP9, R-EP11, R-EP14, D2). Split from `Oracle` (module size). Pure.
OracleDomain :: [].{

	hash_of : Str -> Str
	hash_of = |url| match Ident.of_url(url) {
		Ok(ident) => ident.hash
		Err(_) => ""
	}

	## The row of a release on a compiler for the target `any` (a check: R-P4).
	row_of : List(Db.Fact), Str, Str -> Try(Db.Fact, [None])
	row_of = |rows, nightly, url| {
		hash = hash_of(url)
		rows.find_first(|f| f.hash == hash and f.nightly == nightly and f.target == "any").map_err(|_| None)
	}

	## R-EP11: D is used when it has the held compiler H. Else (not read, a compiler that the list does not have, an empty list) it is `[H]`.
	space : Try(List(Str), [NotRead]), Str -> List(Str)
	space = |domain, held| match domain {
		Ok(d) if d.contains(held) => d
		_ => [held]
	}

	## R-EP7, R-EP8, D2: for each release of `urls` and each compiler of `domain`, one check. The real row first. Else the assumed pass: the value that a header has now (`current`) on the held compiler `assumed` only.
	## Else the inferred fact of `inferred` (source `Inferred`, R-EP14: it never decides with `Allowed`, R-EP8).
	checks : { urls : List(Str), current : List(Str), rows : List(Db.Fact), inferred : List(Epochs.Inferred), domain : List(Str), assumed : Try(Str, [None]) } -> List(Solver.Check)
	checks = |x| x.urls
		.fold([], |found, url| if found.contains(url) found else found.append(url))
		.join_map(|url| x.domain.keep_oks(|nightly| check_at(x, url, nightly)))
}

check_at : { urls : List(Str), current : List(Str), rows : List(Db.Fact), inferred : List(Epochs.Inferred), domain : List(Str), assumed : Try(Str, [None]) }, Str, Str -> Try(Solver.Check, [Unknown])
check_at = |x, url, nightly| match OracleDomain.row_of(x.rows, nightly, url) {
	Ok(f) => Ok({ id: url, nightly, outcome: f.outcome, modules: f.modules, source: Real })
	Err(None) => if x.current.contains(url) and (x.assumed.map_ok(|held| held == nightly) ?? Bool.False) {
		Ok({ id: url, nightly, outcome: Pass, modules: [], source: Real })
	} else {
		hash = OracleDomain.hash_of(url)
		match x.inferred.find_first(|i| i.hash == hash and i.nightly == nightly) {
			Ok(i) => Ok({ id: url, nightly, outcome: if i.outcome == Pass Pass else Fail, modules: i.modules, source: Inferred })
			Err(_) => Err(Unknown)
		}
	}
}
