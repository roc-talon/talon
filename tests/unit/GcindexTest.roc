import lib.Gc
import lib.Roots

GcindexTest :: [].{}

# Slice 237 (docs/slices/237-gc-registry-copies.md, Design Q611 = G-C241): the pure decisions of R-GC15. The new names `Gc.index_pages` and `Gc.index_dirs` do not exist yet: this file does not compile until the code agent adds them (the red state, on purpose).
# The expected value of each row is the design text (R-GC15, R-IX1, R-IX2, R-IX5, R-GC9) or the slice file text, not the code. A wrong row prints with `dbg`.
# The flow (which listings, which `tree_info!`, the report) is in the L2 case tests/commands/cases/gc/gc15-registry-copies.

roots : Roots
roots = { cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }

now : U64
now = 100000000

age : U64
age = 2592000

get_dir : Str
get_dir = "/c/roc/talon/index/registry/https_current.example.org/get"

k1 : Str
k1 = "00000000000000000000000000000001"

k2 : Str
k2 = "00000000000000000000000000000002"

k3 : Str
k3 = "00000000000000000000000000000003"

k4 : Str
k4 = "00000000000000000000000000000004"

k5 : Str
k5 = "00000000000000000000000000000005"

k6 : Str
k6 = "00000000000000000000000000000006"

k7 : Str
k7 = "00000000000000000000000000000007"

file : Str, U64 -> { name : Str, is_dir : Bool, mtime : U64 }
file = |name, mtime| { name, is_dir: Bool.False, mtime }

# One page: its 2 files, the body and the meta, with the 2 times.
page : Str, U64, U64 -> List({ name : Str, is_dir : Bool, mtime : U64 })
page = |key, body, meta| [file("${key}.json", body), file("${key}.meta", meta)]

# R-GC15, R-IX2, R-GC9: a page of `get/` goes, both files, when its meta is older than the GC age. Exactly the age stays (the same edge as `Gc.expired`, `is_over`). A meta in the future stays.
# The age of a page is the time of its meta (R-IX2): a young body with an old meta goes, an old body with a young meta stays.
# A name that is not `<32 hex digits>.json` or `.meta` is no page and stays (Design Q611). The result is in the order of the paths.
expect {
	entries = page(k1, now - 10, now - age - 1)
		.concat(page(k2, now - age - 1, now - age))
		.concat(page(k3, now - 5, now - 5))
		.concat(page(k4, now + 100, now + 100))
		.concat(page(k5, now - 3 * age, 1000))
		.concat(page(k6, 1000, now - 10))
		.concat([file("notes.meta", 1000), file("README", 1000), file("${k7}.txt", 1000)])
	got = Gc.index_pages({ dir: get_dir, entries, now, age })
	dbg got
	got
		== [
			"${get_dir}/${k1}.json",
			"${get_dir}/${k1}.meta",
			"${get_dir}/${k5}.json",
			"${get_dir}/${k5}.meta",
		]
}

# R-GC15, R-GC9, R-IX2 (Design Q611, item 3): a half page is aged by the file that exists, by its own time. An orphan `.json` or an orphan `.meta` that is old goes (only that file is in the result), a young one stays. The edge is the same: exactly the age stays.
expect {
	entries = [
		file("${k1}.json", now - age - 1),
		file("${k2}.json", now - age),
		file("${k3}.meta", now - age - 1),
		file("${k4}.meta", now - 5),
		file("${k5}.json", now - 5),
		file("${k6}.meta", now - age),
	]
	got = Gc.index_pages({ dir: get_dir, entries, now, age })
	dbg got
	got == ["${get_dir}/${k1}.json", "${get_dir}/${k3}.meta"]
}

# R-GC15, R-GC9: the span is the argument. With a span of 60 s: 61 s goes, exactly 60 s stays, 59 s stays. No page and no entry: nothing goes.
expect {
	entries = page(k1, now - 61, now - 61).concat(page(k2, now - 60, now - 60)).concat(page(k3, now - 59, now - 59))
	got = Gc.index_pages({ dir: get_dir, entries, now, age: 60 })
	dbg got
	none = Gc.index_pages({ dir: get_dir, entries: [], now, age })
	got == ["${get_dir}/${k1}.json", "${get_dir}/${k1}.meta"] and none == []
}

index : Str
index = "/c/roc/talon/index/registry"

dir_entry : Str -> { path : Str, is_dir : Bool, mtime : U64 }
dir_entry = |name| { path: "${index}/${name}", is_dir: Bool.True, mtime: 1000 }

listing : List({ path : Str, is_dir : Bool, mtime : U64 })
listing = [
	dir_entry("https_current.example.org"),
	dir_entry("https_old.example.org"),
	dir_entry("http_127.0.0.1_8787"),
	{ path: "${index}/stray.txt", is_dir: Bool.False, mtime: 1000 },
]

# R-GC15, R-IX1, R-IX5: the dirs of other registries are the candidates. The dir of the registry of the run is not (R-IX1 name: `://` and each other `:` become `_`). A file in `registry/` is no dir of a registry. The result is sorted by path.
# No registry in the run (`direct`, R-IX5): each dir is the dir of another registry.
expect {
	https_run = Gc.index_dirs({ roots, current: Registry("https://current.example.org"), entries: listing })
	http_run = Gc.index_dirs({ roots, current: Registry("http://127.0.0.1:8787"), entries: listing })
	direct_run = Gc.index_dirs({ roots, current: Direct, entries: listing })
	empty = Gc.index_dirs({ roots, current: Direct, entries: [] })
	dbg (https_run, http_run, direct_run)
	https_run == ["${index}/http_127.0.0.1_8787", "${index}/https_old.example.org"]
		and http_run == ["${index}/https_current.example.org", "${index}/https_old.example.org"]
			and direct_run == ["${index}/http_127.0.0.1_8787", "${index}/https_current.example.org", "${index}/https_old.example.org"]
				and empty == []
}

# R-GC15, R-GC9, R-IX5: a dir of another registry goes when no file in it changed in the GC age (`newest` is the newest file time: `Gc.expired`, exactly the age stays). One new file keeps the whole dir.
# The dir of the registry of the run is never asked, so it stays when all its files are old (it holds `toolchains.json`, which GC keeps: its rows never change). `current` here is `https_current.example.org`, with all files old.
expect {
	dirs = Gc.index_dirs({ roots, current: Registry("https://current.example.org"), entries: listing.concat([dir_entry("https_new.example.org"), dir_entry("https_edge.example.org"), dir_entry("https_over.example.org")]) })
	tree = |name, newest| { item: "${index}/${name}", path: "${index}/${name}", info: Ok({ newest, size: 10 }) }
	measured = [
		tree("https_current.example.org", 1000),
		tree("https_old.example.org", now - 5 * age),
		tree("http_127.0.0.1_8787", now - 10),
		tree("https_new.example.org", now - 5),
		tree("https_edge.example.org", now - age),
		tree("https_over.example.org", now - age - 1),
	]
	gone = Gc.expired({ dirs, measured, now, span: age })
	dbg (dirs, gone)
	gone == ["${index}/https_old.example.org", "${index}/https_over.example.org"]
}
