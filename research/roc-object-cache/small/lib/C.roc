import B

C :: [].{
	run : List(Str) -> Str
	run = |xs| B.sorted_text(xs.map(|s| "${s}${s}"))
}
