# Repro: a var assignment as a match arm body is a parse error ("unexpected pattern syntax").
# On nightly-2026-10-14-38a3029. Braces around the assignment work: `Ok(v) => { $n = v }`.
count : List(Try(U64, [X])) -> U64
count = |items| {
	var $n = 0
	for item in items {
		match item {
			Ok(v) => $n = v
			Err(_) => {}
		}
	}
	$n
}

main! = |_args| Ok({})
