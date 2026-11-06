## A pure decision in worker/: map a path to a route (no effect).
Route := [Root, Semver(Str), NotFound].{
	is_eq : _

	of : List(Str) -> Route
	of = |segments| match segments {
		[] => Root
		["semver", v] => Semver(v)
		_ => NotFound
	}
}

expect Route.of([]) == Root
expect Route.of(["semver", "1.2.3"]) == Semver("1.2.3")
expect Route.of(["x"]) == NotFound
