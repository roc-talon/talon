import Text

## Temp names and the choice of stale temps (CLI 7.4, R-CC1, R-CC2). The writes are in the real `Fx`
## (`Fx.write_atomic!`). The choice of what to delete is here, so L0 tests it.
##
## | Form | Name |
## | --- | --- |
## | Temp (R-CC1) | `<target>.<16hex>.tmp`, in the directory of the target. `16hex` is 16 lowercase hex digits. |
## | Trash dir (R-CC10) | `<item>.<16hex>.trash` |
## | Probe copy (R-LY1) | `<cache>/talon/tmp/<16hex>/` |
Temp :: [].{

	## 16 lowercase hex digits for a random number, with leading zeros (R-CC1). The real `Fx` takes the number from
	## `Random.seed_u64!` (TW2). `Temp.hex(255)` is `00000000000000ff`.
	hex : U64 -> Str
	hex = |n| U64.to(1, 16).fold(
		(n, ""),
		|(rest, text), _| (rest // 16, "${hex_digit(rest % 16)}${text}"),
	).1

	## The temp name of a target (R-CC1): `<target>.<hex>.tmp`. `Temp.name({ target: "/a/b/main.roc", hex: "0123456789abcdef" })`
	## is `/a/b/main.roc.0123456789abcdef.tmp`.
	name : { target : Str, hex : Str } -> Str
	name = |facts| "${facts.target}.${facts.hex}.tmp"

	## The temps of one item that the lock holder deletes (R-CC2: the lock holder of an item deletes the temps of that item;
	## R-CC4 step 5). `item` is the path of the item. `entries` is the list of its parent directory (`Fx.list_dirs!`).
	## An entry is a temp of the item when its name is `<last segment of item>.<16hex>.tmp`: a file or a directory.
	## The result is the full paths (`<parent>/<name>`), sorted, with no age rule: only the lock holder writes them.
	## `projects.json.0123456789abcdef.tmp` is a temp of `projects.json`. `projects.json.lock`, `projects.json.bak.tmp`,
	## `projects.json.<15 hex>.tmp` and `xprojects.json.0123456789abcdef.tmp` are not.
	of_item : { item : Str, entries : List({ name : Str, is_dir : Bool, mtime : U64 }) } -> List(Str)
	of_item = |facts| {
		base = Text.last_segment(facts.item)
		parent = Text.dir_of(facts.item)
		facts.entries
			.keep_if(|e| is_temp_of(base, e.name))
			.map(|e| Text.join(parent, e.name))
			|> Text.sorted
	}

	## The stale items that `tln cache gc` deletes (R-CC2, R-GC6): an entry is stale when it is
	## (1) a name that ends with `.<16hex>.tmp` or `.<16hex>.trash` (a file or a directory), or
	## (2) a directory `<16hex>` whose parent directory is named `tmp` and whose grandparent is named `talon`
	## (a probe copy of an app), or
	## (3) a file `<16hex>.locks` in such a `tmp` dir (slice 028: the registry of the locks of a process that ended, `RealLocks`),
	## and its age is more than 1 day (86400 s): `now - mtime`. `mtime` is the modification time and `now` is the real
	## clock, never `TALON_NOW` (R-EV22). An age of exactly 86400 s is not stale. `entries` has full paths. The result is
	## sorted. The age of a lock heartbeat is not here (`Lock.state`).
	old : { entries : List({ path : Str, is_dir : Bool, mtime : U64 }), now : U64 } -> List(Str)
	old = |facts| facts.entries
		.keep_if(|e| is_stale_kind(e) and is_older_than_day(e.mtime, facts.now))
		.map(|e| e.path)
		|> Text.sorted
}

hex_digit : U64 -> Str
hex_digit = |digit| match Str.from_utf8([if digit < 10 48 + digit.to_u8_wrap() else 87 + digit.to_u8_wrap()]) {
	Ok(char) => char
	Err(_) => "0"
}

is_hex16 : Str -> Bool
is_hex16 = |text| {
	bytes = text.to_utf8()
	bytes.len() == 16 and bytes.all(|b| (b >= 48 and b <= 57) or (b >= 97 and b <= 102))
}

# `<base>.<16hex>.tmp`
is_temp_of : Str, Str -> Bool
is_temp_of = |base, name| name.starts_with("${base}.") and {
	rest = name.drop_prefix("${base}.")
	rest.ends_with(".tmp") and is_hex16(rest.drop_suffix(".tmp"))
}

# A name that ends with `.<16hex>.<ext>`.
has_stamp : Str, Str -> Bool
has_stamp = |name, ext| name.ends_with(".${ext}") and {
	bytes = name.drop_suffix(".${ext}").to_utf8()
	size = bytes.len()
	size >= 17 and bytes.get(size - 17) == Ok(46) and is_hex16(Str.from_utf8_lossy(bytes.sublist({ start: size - 16, len: 16 })))
}

# The kinds of R-CC2 and R-GC6: a temp, a trash dir, a stale lock dir (Q6), a probe copy `talon/tmp/<16hex>`, a lock registry `talon/tmp/<16hex>.locks` (D10 of slice 028).
is_stale_kind : { path : Str, is_dir : Bool, mtime : U64 } -> Bool
is_stale_kind = |e| {
	name = Text.last_segment(e.path)
	parent = Text.dir_of(e.path)
	in_talon_tmp = Text.last_segment(parent) == "tmp" and Text.last_segment(Text.dir_of(parent)) == "talon"
	probe_copy = e.is_dir and is_hex16(name) and in_talon_tmp
	registry = !e.is_dir and name.ends_with(".locks") and is_hex16(name.drop_suffix(".locks")) and in_talon_tmp
	has_stamp(name, "tmp") or has_stamp(name, "trash") or has_stamp(name, "stale") or probe_copy or registry
}

# Exactly 1 day is not old. A time in the future is not old.
is_older_than_day : U64, U64 -> Bool
is_older_than_day = |mtime, now| now > mtime and now - mtime > 86400
