D :: [].{
	sorted_pairs : List(Str) -> Str
	sorted_pairs = |xs| {
		rows = xs.map(|s| { key: s.to_utf8().len(), name: s, tag: if s.to_utf8().len() > 2 Big(s) else Small })
		out = rows.sort_with(|l, r| if l.key > r.key Before else if l.key < r.key After else Same)
		Str.join_with(out.map(|r| match r.tag { Big(t) => t, Small => r.name }), "/")
	}
}
