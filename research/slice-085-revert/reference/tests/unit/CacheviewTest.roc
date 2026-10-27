import lib.Args
import lib.CacheView
import lib.Fail

CacheviewTest :: [].{}

# The expected value of each row is the design text or the slice file text (docs/slices/029b-cache-list-dir.md), not the code. A wrong row prints with `dbg`.
# Texts and `data` fields that the design does not give are the proposals of the slice file (TW24).

# R-CM17: `tln cache dir` and `tln cache list` take no operand (exit 2). The global flags change nothing here. The message has the words of the command.
expect {
	read = |words| match Args.parse(words) {
		Ok(args) => CacheView.read(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	rows = [
		(["cache", "dir"], Ok({})),
		(["cache", "list"], Ok({})),
		(["cache", "dir", "--json", "--quiet", "--yes"], Ok({})),
		(["cache", "list", "--json", "--quiet"], Ok({})),
		(["cache", "dir", "packages"], Err(Fail.new(Usage, "tln cache dir takes no operand, got 1"))),
		(["cache", "list", "a", "b"], Err(Fail.new(Usage, "tln cache list takes no operand, got 2"))),
	]
	bad = rows.keep_if(|(words, want)| read(words) != want).map(|(words, want)| (words, want, read(words)))
	dbg bad
	bad == []
}

# R-OUT2, R-J3, R-OUT4: `dir` prints the cache root and a line end, nothing else. The `data` is `{"path":...}`. A path is escaped as JSON text.
expect {
	text = CacheView.dir_report("/c/roc")
	data = CacheView.dir_data("/c/roc").render()
	odd = CacheView.dir_data("/c/a \"b\"/roc").render()
	dbg (text, data, odd)
	text == ["/c/roc\n"] and data == "{\"path\":\"/c/roc\"}" and odd == "{\"path\":\"/c/a \\\"b\\\"/roc\"}"
}

# R-OUT2: the text of `list`. No item: one line, no total. Items: the order of `paths` (not the order of the sizes), the suffix ` (<size>)` for an item with a size (also 0 B), no suffix for an item with no size, then the total of the sizes.
# The total line is there when one item has a size, and it is not there when no item has a size. The size words are those of `Toolchain.size_text`.
expect {
	sized = |item, bytes| { item, bytes }
	none = CacheView.list_report({ paths: [], sizes: [] })
	two = CacheView.list_report({ paths: ["/c/b", "/c/a"], sizes: [sized("/c/a", 999), sized("/c/b", 1500)] })
	mixed = CacheView.list_report({ paths: ["/c/x", "/c/i"], sizes: [sized("/c/i", 11)] })
	empty_dir = CacheView.list_report({ paths: ["/c/e"], sizes: [sized("/c/e", 0)] })
	unknown = CacheView.list_report({ paths: ["/c/x", "/c/y"], sizes: [] })
	dbg (none, two, mixed, empty_dir, unknown)
	none == ["nothing to clean\n"] and two == ["/c/b (1.5 KB)\n", "/c/a (999 B)\n", "total 2.5 KB\n"] and mixed == ["/c/x\n", "/c/i (11 B)\n", "total 11 B\n"] and empty_dir == ["/c/e (0 B)\n", "total 0 B\n"] and unknown == ["/c/x\n", "/c/y\n"]
}

# R-J3, R-OUT4: the `data` of `list`: the keys `items` and `total`, in this order. `bytes` is null for an item with no size. `total` is the sum of the sizes, 0 with no item. The order of `items` is the order of `paths`.
expect {
	sized = |item, bytes| { item, bytes }
	none = CacheView.list_data({ paths: [], sizes: [] }).render()
	two = CacheView.list_data({ paths: ["/c/b", "/c/a"], sizes: [sized("/c/a", 999), sized("/c/b", 1500)] }).render()
	mixed = CacheView.list_data({ paths: ["/c/x", "/c/i"], sizes: [sized("/c/i", 11)] }).render()
	dbg (none, two, mixed)
	none == "{\"items\":[],\"total\":0}" and two == "{\"items\":[{\"path\":\"/c/b\",\"bytes\":1500},{\"path\":\"/c/a\",\"bytes\":999}],\"total\":2499}" and mixed == "{\"items\":[{\"path\":\"/c/x\",\"bytes\":null},{\"path\":\"/c/i\",\"bytes\":11}],\"total\":11}"
}
