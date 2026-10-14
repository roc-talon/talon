import Program

Deep := [].{
	loop : U64, U64 -> Program.Program(U64)
	loop = |i, n|
		if i == n Write("out", n.to_str(), Done(n))
		else Read("f", |_| Deep.loop(i + 1, n))

	loop_then : U64, U64 -> Program.Program(U64)
	loop_then = |i, n|
		if i == n Done(n)
		else Program.then(Read("f", |_| Done(i)), |_| Deep.loop_then(i + 1, n))
}


expect Program.run_fake(Deep.loop(0, 100000), Dict.empty(), |_| Pass, Bool.True).result == 100000
expect Program.run_fake(Deep.loop_then(0, 100000), Dict.empty(), |_| Pass, Bool.True).result == 100000
