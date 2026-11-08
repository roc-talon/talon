import records.Toolchain as Wire
import Fail
import Fx
import JsonDoc
import Registry
import RegistryCache
import Roots
import Text

## The compiler list of a registry (slice 204; Registry 4 R-AP5, R-AP19, R-AP47; CLI 6.1 R-IX4, R-IX5, R-IX6, R-TF3, R-TF6; CLI 6.2 R-CV1).
## `GET /v1/toolchains?after=<n>` gives pages of rows with `more`. `tln` keeps the rows in one file for each registry and asks only for the rows after the largest log index that it has.
## The wire types and the codecs are the package `records` (`records.Toolchain`, R-PK7). `origin` in each function is the base URL form of R-RG7 (`Registry.base`).
## No command calls this module yet: slice 206 and later slices choose the registry source of a compiler list. `Nightlies.list_registry!` is the seam.
RegistryToolchains :: [].{

	## The `format` of the registry compiler list file that this Talon writes (R-IX4, R-TF1).
	format : U64
	format = 1

	## A row of R-RE4 on the wire (`records.Toolchain.Row`): `sha256` is bare lower-case hex, `published_at` is milliseconds (R-AP50), `log_index` is the position in the log (R-AP19).
	Row : Wire.Row

	## Where the rows of a `list!` came from (as `Nightlies.list!`): `Live` (the registry was asked), `Cached(t)` (`--offline`: the file, with its modification time), `Missing` (`--offline` and no usable file: the list is empty, the command decides, R-DI12).
	Source : [Live, Cached(U64), Missing]

	## R-IX4, R-IX1: the file of the rows: `<index>/registry/<origin dir>/toolchains.json` (`RegistryCache.origin_dir` of the registry, then `toolchains.json`).
	path : { roots : Roots, origin : Str } -> Str
	path = |facts| Text.join(RegistryCache.origin_dir({ roots: facts.roots, origin: facts.origin }), "toolchains.json")

	## R-IX4, R-TF1: the text of the file: `{"format":1,"rows":[<row>,...]}`, no white space, a line end at the end. Each row is the text of `records.Toolchain.encode_row` (members `tag`, `target`, `asset_name`, `sha256`, `published_at`, `log_index` in this order). No row gives `{"format":1,"rows":[]}`.
	file_text : List(Row) -> Str
	file_text = |rows| "{\"format\":${format.to_str()},\"rows\":[${Str.join_with(rows.map(Wire.encode_row), ",")}]}\n"

	## R-TF2, R-IX4 (slice 204b): the unknown members of a file text, as the text of their pairs (`"k":v,...`, no braces). `top` is those of the top object (not `format`, not `rows`). `rows` has one text for each row of `rows`, in order,
	## with the members of that row that `records.Toolchain` does not know (`""` for none). A text that does not parse as `parse_file` reads it gives no member (`{ top: "", rows: [] }`).
	file_extras : Str -> { top : Str, rows : List(Str) }
	file_extras = |text| match JsonDoc.parse(text) {
		Ok(Obj(pairs)) => {
			rows = match member(pairs, "rows") {
				Ok(Arr(items)) => items.map(row_extra)
				_ => []
			}
			{ top: pair_text(pairs.keep_if(|(key, _)| key != "format" and key != "rows")), rows }
		}
		_ => { top: "", rows: [] }
	}

	## R-TF2 (slice 204b): as `file_text`, and the unknown members stay. `extras` is the result of `file_extras` of the kept file. The text of a pair list `extras.rows[i]` goes at the end of the row `i` (after `log_index`),
	## and `extras.top` goes at the end of the top object (after `rows`). A row with no text in `extras.rows` (a new row) has none.
	file_text_keep : List(Row), { top : Str, rows : List(Str) } -> Str
	file_text_keep = |rows, extras| {
		texts = rows.map_with_index(|row, i| with_extra(Wire.encode_row(row), extras.rows.get(i) ?? ""))
		tail = if extras.top.is_empty() "" else ",${extras.top}"
		"{\"format\":${format.to_str()},\"rows\":[${Str.join_with(texts, ",")}]${tail}}\n"
	}

	## The reverse of `file_text`. `Err(Bad)`: not JSON, no `format` or `rows` member, a row with a missing member or a member of the wrong type (R-IX4, R-TF6: the file is deleted and the read starts at `after=0`).
	## `Err(Newer)`: a `format` number that is larger than 1 (R-TF3: a file of a newer Talon is ignored, and never written). An unknown member of the top object or of a row is ignored (R-TF2, R-AP51). The order of the rows is kept.
	parse_file : Str -> Try(List(Row), [Bad, Newer])
	parse_file = |text| match JsonDoc.parse(text) {
		Ok(Obj(pairs)) => match member(pairs, "format") {
			Ok(Num(n)) => if n > format.to_i64_wrap() {
				Err(Newer)
			} else if n == format.to_i64_wrap() {
				file_rows(pairs)
			} else {
				Err(Bad)
			}
			_ => Err(Bad)
		}
		_ => Err(Bad)
	}

	## R-IX4, R-AP47: the `after` of the next read: the `log_index` of the last row, `0` for no row (the first page, R-AP5: no `after` is `after=0`).
	after_of : List(Row) -> U64
	after_of = |rows| match rows.last() {
		Ok(last) => last.log_index
		Err(_) => 0
	}

	## R-AP5, R-AP69, R-IX4: the URL of one page: `<origin>/v1/toolchains?after=<n>`. Talon sends no `target` (R-IX4: one store for all targets).
	page_url : { origin : Str, after : U64 } -> Str
	page_url = |facts| "${facts.origin}/v1/toolchains?after=${facts.after.to_str()}"

	## R-AP5, R-AP51 (`Wire.decode_page`): the reader of a 200 body. A body that does not decode (a missing `toolchains` or `more`, `null`, a wrong type, not JSON) is a failure of kind `Network` (exit 15, R-E6 last row): `the answer of the registry <origin> is not a toolchain list: <decoder text>`.
	## An unknown member is ignored (R-AP44).
	page : { origin : Str, body : Str } -> Try(Wire.Page, Fail)
	page = |facts| match Wire.decode_page(facts.body) {
		Ok(got) => Ok(got)
		Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${facts.origin} is not a toolchain list: ${why}"))
	}

	## R-AP47: what to read after a page. `after` is the `after` of the request. `more` false: `Ok(Done)`. `more` true: `Ok(More(n))` with `n` the `log_index` of the last row of the page.
	## A page with `more` true that has no row, or whose last `log_index` is not larger than `after`, would never end: `Err` of kind `Network` (exit 15), the text `the registry <origin> gave a toolchain page that does not move on after <after>. Try again later.` (a proposal, TW24).
	next : { origin : Str, after : U64, page : Wire.Page } -> Try([More(U64), Done], Fail)
	next = |facts| if !facts.page.more {
		Ok(Done)
	} else {
		match facts.page.toolchains.last() {
			Ok(last) if last.log_index > facts.after => Ok(More(last.log_index))
			_ => Err(Fail.new(Network, "the registry ${facts.origin} gave a toolchain page that does not move on after ${facts.after.to_str()}. Try again later."))
		}
	}

	## R-IX4: the file after a read: the kept rows and then the rows of the new pages, in this order. A new row whose `log_index` is not larger than the largest kept one is dropped (a row never changes, R-PU10, so the kept row stays).
	merge : { kept : List(Row), fresh : List(Row) } -> List(Row)
	merge = |facts| {
		start = { top: RegistryToolchains.after_of(facts.kept), rows: facts.kept }
		facts.fresh.fold(start, |acc, row| if row.log_index > acc.top { top: row.log_index, rows: acc.rows.append(row) } else acc).rows
	}

	## R-AP19, R-AP47: `--snapshot log:N` hides each row with a `log_index` greater than N (`log: Ok(N)`: a row with `log_index == N` stays). `Err(None)`: all rows. The order stays. The file keeps all rows: the hide is for the use only.
	visible : { rows : List(Row), log : Try(U64, [None]) } -> List(Row)
	visible = |facts| match facts.log {
		Ok(n) => facts.rows.keep_if(|row| row.log_index <= n)
		Err(None) => facts.rows
	}

	## R-IX4 line 1: the warning for a file that does not parse, printed on stderr (a proposal, TW24): `warning: <path> is not a toolchain list file and is removed: Talon reads the list again from <origin>`.
	bad_file_warning : { path : Str, origin : Str } -> Str
	bad_file_warning = |facts| "warning: ${facts.path} is not a toolchain list file and is removed: Talon reads the list again from ${facts.origin}"

	## The compiler list of one registry (R-CV1, R-AP5, R-AP47, R-IX4, R-IX6). `version` is the `tln` version (the `User-Agent`, R-AP45). `roots` has the dir of the index. No token (R-RG3), no guard (the request has no name).
	## The result has all rows of the file after the read, in log index order (the caller hides with `visible`). The calls, in order (the L2 cases `registry/ap5-toolchain-rows` and `registry/cv1-registry-nightlies` fix them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | One `read_files!` of `[path]`. `Ok(text)` and `parse_file` is `Ok(rows)`: the kept rows. A missing or unreadable file: no kept row. `Err(Bad)`: one `delete!` of `[path]`, then `err!(bad_file_warning)`, and no kept row (R-TF6). `Err(Newer)`: question Q3 of slice 204, no test: the reference reads no row and writes no file |
	## | 2 | `offline` and kept rows: one `list_dirs!` of the dir of the file, the result is `Cached(<mtime of toolchains.json>)` and the kept rows. `offline` and no kept row: `Missing` and no row. No request (R-IX6) |
	## | 3 | Not `offline`: one `http_get!` of `page_url` with `after_of(kept)`, headers `[User-Agent]` only (`RegistryCache.read_headers` with no etag, `newest` false, no bookmark). No copy in `get/` is read or written (question Q2). A page with `more` true: the next request with `next`'s `after`, until `more` is false. Requests are one after the other |
	## | 3b | An answer: 200 gives `page`. A 3xx, and a 304 (no `If-None-Match` was sent): `RegistryCache.unusable` (exit 15). Another status: `Registry.refuse` with method `Get`. No answer: `Registry.no_answer` (`no answer in 20 s` for a timeout). Any failure ends the read: no write, so the file never has a gap (R-IX4) |
	## | 4 | New rows and no failure: one `write_atomic!` of `[{ path, content: file_text_keep(merge, extras) }]` (the unknown members of the kept file stay, R-TF2), after the last page. No new row: no write (also when the file is missing: no empty file). A failed write: kind `Environment`, `cannot write <path>` |
	## | 5 | The result: `Live` and the merged rows |
	list! : Fx, { roots : Roots, origin : Str, version : Str, offline : Bool, source ?: Str } => Try({ rows : List(Row), source : Source }, Fail)
	list! = |fx, facts| {
		file = RegistryToolchains.path({ roots: facts.roots, origin: facts.origin })
		kept = kept_rows!(fx, file, facts.origin)
		if facts.offline {
			offline_list!(fx, facts, file, kept.rows)
		} else {
			fresh = fetch_pages!(fx, facts, RegistryToolchains.after_of(kept.rows))?
			rows = RegistryToolchains.merge({ kept: kept.rows, fresh })
			if kept.write and !fresh.is_empty() {
				match fx.write_atomic!([{ path: file, content: RegistryToolchains.file_text_keep(rows, kept.extras) }]) {
					Ok(_) => {}
					Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
				}
			}
			Ok({ rows, source: Live })
		}
	}
}

# A member of a JSON object.
member : List((Str, JsonDoc)), Str -> Try(JsonDoc, [NotFound])
member = |pairs, name| match pairs.find_first(|(key, _)| key == name) {
	Ok((_, value)) => Ok(value)
	Err(_) => Err(NotFound)
}

# The rows of a file with `format` 1. A row is read by `records.Toolchain.decode_row`: a missing member or a wrong type is `Bad`, an unknown member is ignored.
file_rows : List((Str, JsonDoc)) -> Try(List(RegistryToolchains.Row), [Bad, Newer])
file_rows = |pairs| match member(pairs, "rows") {
	Ok(Arr(items)) => items.map_try(|item| Wire.decode_row(item.render()).map_err(|_| Bad))
	_ => Err(Bad)
}

# Step 1 of `list!`: the kept rows. `write` is false for a file of a newer format: it is never written (R-TF3).
kept_rows! : Fx, Str, Str => { rows : List(RegistryToolchains.Row), write : Bool, extras : { top : Str, rows : List(Str) } }
kept_rows! = |fx, file, origin| match fx.read_files!([file]) {
	[Ok(text)] => match RegistryToolchains.parse_file(text) {
		Ok(rows) => { rows, write: Bool.True, extras: RegistryToolchains.file_extras(text) }
		Err(Newer) => { rows: [], write: Bool.False, extras: none_extras }
		Err(Bad) => {
			_removed = fx.delete!([file])
			fx.err!("${RegistryToolchains.bad_file_warning({ path: file, origin })}\n")
			{ rows: [], write: Bool.True, extras: none_extras }
		}
	}
	_ => { rows: [], write: Bool.True, extras: none_extras }
}

none_extras : { top : Str, rows : List(Str) }
none_extras = { top: "", rows: [] }

# The text of some pairs of an object, with no braces.
pair_text : List((Str, JsonDoc)) -> Str
pair_text = |pairs| JsonDoc.render(Obj(pairs)).drop_prefix("{").drop_suffix("}")

# The members of a row object that the wire type does not know.
row_extra : JsonDoc -> Str
row_extra = |item| match item {
	Obj(pairs) => pair_text(pairs.keep_if(|(key, _)| !known_row_keys.contains(key)))
	_ => ""
}

known_row_keys : List(Str)
known_row_keys = ["tag", "target", "asset_name", "sha256", "size", "published_at", "log_index"]

# The text of a row with the text of its unknown members before the closing brace.
with_extra : Str, Str -> Str
with_extra = |row, extra| if extra.is_empty() row else "${row.drop_suffix("}")},${extra}}"

# Step 2 of `list!`: `--offline` reads only the file. Its age is its modification time.
offline_list! : Fx, { roots : Roots, origin : Str, version : Str, offline : Bool, source ?: Str }, Str, List(RegistryToolchains.Row) => Try({ rows : List(RegistryToolchains.Row), source : RegistryToolchains.Source }, Fail)
offline_list! = |fx, facts, file, rows| if rows.is_empty() {
	Ok({ rows, source: Missing })
} else {
	dir = RegistryCache.origin_dir({ roots: facts.roots, origin: facts.origin })
	listing = match fx.list_dirs!([dir]) {
		[Ok(entries)] => entries
		_ => []
	}
	mtime = match listing.find_first(|e| file.ends_with("/${e.name}")) {
		Ok(entry) => entry.mtime
		Err(_) => 0
	}
	Ok({ rows, source: Cached(mtime) })
}

# Step 3 of `list!`: the pages one after the other. Any failure ends the read (no write, so the file never has a gap).
fetch_pages! : Fx, { roots : Roots, origin : Str, version : Str, offline : Bool, source ?: Str }, U64 => Try(List(RegistryToolchains.Row), Fail)
fetch_pages! = |fx, facts, start| {
	var $after = start
	var $fresh = []
	var $going = Bool.True
	while $going {
		got = fetch_page!(fx, facts, $after)?
		$fresh = $fresh.concat(got.toolchains)
		match RegistryToolchains.next({ origin: facts.origin, after: $after, page: got })? {
			More(n) => {
				$after = n
			}
			Done => {
				$going = Bool.False
			}
		}
	}
	Ok($fresh)
}

# One request of a page: 200 is a page, 3xx (and 304) is no use, any other status is a refusal.
fetch_page! : Fx, { roots : Roots, origin : Str, version : Str, offline : Bool, source ?: Str }, U64 => Try(Wire.Page, Fail)
fetch_page! = |fx, facts, after| {
	url = RegistryToolchains.page_url({ origin: facts.origin, after })
	headers = RegistryCache.read_headers({ version: facts.version, etag: Err(None), newest: Bool.False, bookmark: Err(None) })
	reply = match fx.http_get!({ url, headers }) {
		Ok(got) => got
		Err(why) => {
			text = match why {
				Timeout => "no answer in 20 s"
				Failed(t) => t
			}
			return Err(Registry.no_answer({ origin: facts.origin, why: text, source: facts.?source ?? "" }))
		}
	}
	if reply.status == 200 {
		RegistryToolchains.page({ origin: facts.origin, body: reply.body })
	} else if reply.status >= 300 and reply.status < 400 {
		Err(RegistryCache.unusable({ origin: facts.origin, path: url.drop_prefix(facts.origin), status: reply.status }))
	} else {
		Err(Registry.refuse({ origin: facts.origin, version: facts.version, method: Get, reply: { status: reply.status, body: reply.body }, retry_after: Registry.retry_after_of(reply.headers), source: facts.?source ?? "" }))
	}
}
