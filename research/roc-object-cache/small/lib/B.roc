B :: [].{
	sorted_text : List(Str) -> Str
	sorted_text = |xs| {
		rows = xs.map(|s| { key: s.to_utf8().len(), name: s })
		Str.join_with(rows.sort_with(|l, r| if l.key < r.key Before else if l.key > r.key After else Same).map(|r| "${r.name}:${r.key.to_str()}"), ",")
	}
}
