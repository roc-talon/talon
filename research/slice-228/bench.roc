# CPU check of slice 228 (docs/slices/228-own-sort.md): `Sorted.sort_with` against `List.sort_with`.
# Usage: bench <variant: none|builtin|own> <shape: pair|record> <rows> <reps>   (run.sh builds it and times it)
# `none` makes the lists and does not sort them: its time is the cost of the lists, and the other two times minus it is the cost of the sort.
# Sorted.roc is a copy of packages/records/Sorted.roc (run.sh copies it here, SORTED=<file> chooses another).
import Sorted

Pair : (U64, U64)
Rec : { id : U64, repo : Str, kind : U64, label : Str, path : Str, n : I64 }

compare_bytes : List(U8), List(U8) -> [Before, Same, After]
compare_bytes = |x, y| match (x, y) {
	([], []) => Same
	([], _) => Before
	(_, []) => After
	([p, .. as rx], [q, .. as ry]) => if (p < q) Before else if (p > q) After else compare_bytes(rx, ry)
}

by_pair : Pair, Pair -> [Before, Same, After]
by_pair = |a, b| a.0.order_relative_to(b.0)

by_repo : Rec, Rec -> [Before, Same, After]
by_repo = |a, b| compare_bytes(a.repo.to_utf8(), b.repo.to_utf8())

next : U64 -> U64
next = |x| (x * 1103515245 + 12345) % 2147483648

make_pairs : U64, U64 -> List(Pair)
make_pairs = |n, seed| {
	var $x = seed
	var $out = List.with_capacity(n)
	for i in 0.U64..<n {
		$x = next($x)
		$out = $out.append((($x // 65536) % 1000000, i))
	}
	$out
}

make_recs : U64, U64 -> List(Rec)
make_recs = |n, seed| {
	var $x = seed
	var $out = List.with_capacity(n)
	for i in 0.U64..<n {
		$x = next($x)
		k = ($x // 65536) % 100000
		$out = $out.append({ id: i, repo: "owner-${k.to_str()}/repo-${(k % 97).to_str()}", kind: k % 4, label: "label-${i.to_str()}", path: "releases/download/${k.to_str()}/", n: i.to_i64_wrap() })
	}
	$out
}

# One number out of each run, so the compiler cannot drop the sort.
pair_sum : Str, U64, U64 -> U64
pair_sum = |variant, n, reps| {
	var $acc = 0
	for r in 0.U64..<reps {
		rows = make_pairs(n, r + 1)
		sorted = match variant {
			"builtin" => rows.sort_with(by_pair)
			"own" => Sorted.sort_with(rows, by_pair)
			_ => rows
		}
		$acc = $acc + (sorted.first().map_ok(|p| p.0).ok_or(0)) + (sorted.last().map_ok(|p| p.1).ok_or(0))
	}
	$acc
}

rec_sum : Str, U64, U64 -> U64
rec_sum = |variant, n, reps| {
	var $acc = 0
	for r in 0.U64..<reps {
		rows = make_recs(n, r + 1)
		sorted = match variant {
			"builtin" => rows.sort_with(by_repo)
			"own" => Sorted.sort_with(rows, by_repo)
			_ => rows
		}
		$acc = $acc + (sorted.first().map_ok(|p| p.id).ok_or(0)) + (sorted.last().map_ok(|p| p.id).ok_or(0))
	}
	$acc
}

main! = |args| {
	match args {
		[variant, shape, n_text, reps_text] => {
			n = U64.from_str(n_text) ?? 0
			reps = U64.from_str(reps_text) ?? 0
			total = if (shape == "pair") pair_sum(variant, n, reps) else rec_sum(variant, n, reps)
			echo!("${variant} ${shape} rows=${n.to_str()} reps=${reps.to_str()} check=${total.to_str()}\n")
			Ok({})
		}
		_ => {
			echo!("usage: bench <none|builtin|own> <pair|record> <rows> <reps>\n")
			Err(Exit(2))
		}
	}
}
