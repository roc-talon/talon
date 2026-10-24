## Leaf module. The edit goes here.
A :: [].{
	label : U64 -> Str
	label = |n| {
		xs = [n, n + 5, 1, n * 2]
		ys = xs.sort_with(|l, r| if l < r Before else if l > r After else Same)
		zs = ys.map(|v| [v.to_str(), "-"]).sort_with(|l, r| if l.len() < r.len() Before else After)
		"n${Str.join_with(ys.map(|v| v.to_str()), "+")}${zs.len().to_str()}"
	}
}
