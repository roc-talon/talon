import records.Sorted

SortedTest :: [].{}

# W0 tests of packages/records/Sorted.roc (slice 228, docs/slices/228-own-sort.md). The design has no rule id for this module: it is a build-size change.
# Each test says what it checks. The contract is the one of `List.sort_with`: a stable sort, `Same` keeps the input order. A comparator that is not a total order is out of scope.
# A row is (key, input position). The generator is a fixed linear generator, so a run gives the same lists on every machine.

Row : (U64, U64)

by_key : Row, Row -> [Before, Same, After]
by_key = |a, b| a.0.order_relative_to(b.0)

by_key_desc : Row, Row -> [Before, Same, After]
by_key_desc = |a, b| b.0.order_relative_to(a.0)

# A total order (key, then position). Each correct sort gives one list under it, so it is an oracle that does not use the sort of the compiler.
by_key_pos : Row, Row -> [Before, Same, After]
by_key_pos = |a, b| match a.0.order_relative_to(b.0) {
	Same => a.1.order_relative_to(b.1)
	other => other
}

by_key_desc_pos : Row, Row -> [Before, Same, After]
by_key_desc_pos = |a, b| match b.0.order_relative_to(a.0) {
	Same => a.1.order_relative_to(b.1)
	other => other
}

# n rows, keys in 0..<range (range 1: all keys equal). The high bits of the generator are used: its low bits repeat.
make : U64, U64, U64 -> List(Row)
make = |n, range, seed| {
	var $x = seed
	var $out = List.with_capacity(n)
	for i in 0.U64..<n {
		$x = ($x * 1103515245 + 12345) % 2147483648
		$out = $out.append((($x // 65536) % range, i))
	}
	$out
}

sizes : List(U64)
sizes = [0, 1, 2, 3, 4, 5, 7, 8, 9, 16, 17, 100, 101, 500, 2000]

# Range 1: all equal. Range 3: many ties. Range 1000000: nearly all keys differ.
ranges : List(U64)
ranges = [1, 3, 50, 1000000]

# (size, range, seed) for each size and each range, with 2 seeds.
cases : List((U64, U64, U64))
cases = sizes.join_map(|n| ranges.join_map(|r| [(n, r, 1), (n, r, 987654321)]))

# The keys never go down, and a key that repeats has its positions in rising order.
is_stable_sorted : List(Row) -> Bool
is_stable_sorted = |rows| rows.drop_last(1).map2(rows.drop_first(1), |a, b| (a.0 < b.0) or ((a.0 == b.0) and (a.1 < b.1))).all(|ok| ok)

# Same result as `List.sort_with`, on random lists of 0 to 2000 rows.
expect cases.all(
	|(n, r, s)| {
		rows = make(n, r, s)
		Sorted.sort_with(rows, by_key) == rows.sort_with(by_key)
	},
)

# Same result as the oracle (the total order key, position): the answer does not depend on a stable `List.sort_with`.
expect cases.all(
	|(n, r, s)| {
		rows = make(n, r, s)
		Sorted.sort_with(rows, by_key) == rows.sort_with(by_key_pos)
	},
)

# Stability: equal keys keep their input order, and the keys never go down.
expect cases.all(|(n, r, s)| is_stable_sorted(Sorted.sort_with(make(n, r, s), by_key)))

# A hand-made list: the ties (key 1 and key 2) keep their order.
expect Sorted.sort_with([(2, 0), (1, 1), (2, 2), (1, 3), (0, 4), (2, 5)], by_key) == [(0, 4), (1, 1), (1, 3), (2, 0), (2, 2), (2, 5)]

# Size 0, 1 and 2 with hand-made rows.
expect Sorted.sort_with([], by_key) == []
expect Sorted.sort_with([(5, 0)], by_key) == [(5, 0)]
expect Sorted.sort_with([(5, 0), (4, 1)], by_key) == [(4, 1), (5, 0)]
expect Sorted.sort_with([(4, 0), (5, 1)], by_key) == [(4, 0), (5, 1)]
expect Sorted.sort_with([(4, 0), (4, 1)], by_key) == [(4, 0), (4, 1)]

# Input that is sorted already (many ties): the list does not change.
ascending : U64 -> List(Row)
ascending = |n| (0.U64).until(n).map(|i| (i // 3, i)).collect()

expect sizes.all(|n| Sorted.sort_with(ascending(n), by_key) == ascending(n))

# Input in reverse order, all keys different: the result is the input reversed.
descending : U64 -> List(Row)
descending = |n| (0.U64).until(n).map(|i| (n - 1 - i, i)).collect()

expect sizes.all(|n| Sorted.sort_with(descending(n), by_key) == descending(n).rev())

# Input in reverse order, with ties: the ties keep the order of the input (positions go down in the input, so the result has them in the input order).
expect sizes.all(
	|n| {
		rows = ascending(n).rev()
		Sorted.sort_with(rows, by_key) == ascending(n).sort_with(
			|a, b| match a.0.order_relative_to(b.0) {
				Same => b.1.order_relative_to(a.1)
				other => other
			},
		)
	},
)

# All keys equal: the list does not change, with a comparator on the key and with a comparator that says `Same` for every pair.
expect sizes.all(
	|n| {
		rows = make(n, 1, 1)
		Sorted.sort_with(rows, by_key) == rows
	},
)

expect sizes.all(
	|n| {
		rows = make(n, 1000000, 1)
		Sorted.sort_with(rows, |_a, _b| Same) == rows
	},
)

# A comparator that goes down: the order is reversed, ties still keep the input order.
expect cases.all(|(n, r, s)| Sorted.sort_with(make(n, r, s), by_key_desc) == make(n, r, s).sort_with(by_key_desc_pos))

# Other element types: Str (by length), and a record with a Str field.
expect Sorted.sort_with(["bb", "a", "cc", "d", "eee", "ff"], |a, b| a.count_utf8_bytes().order_relative_to(b.count_utf8_bytes())) == ["a", "d", "bb", "cc", "ff", "eee"]

expect Sorted.sort_with(
	[{ k: 3, label: "x" }, { k: -1, label: "y" }, { k: 3, label: "z" }, { k: -1, label: "w" }, { k: 0, label: "v" }],
	|a, b| a.k.order_relative_to(b.k),
) == [{ k: -1, label: "y" }, { k: -1, label: "w" }, { k: 0, label: "v" }, { k: 3, label: "x" }, { k: 3, label: "z" }]

# The input list is not changed: it is shared (the sort is pure).
expect {
	rows = make(100, 3, 1)
	sorted = Sorted.sort_with(rows, by_key)
	(rows == make(100, 3, 1)) and (sorted.len() == 100)
}
