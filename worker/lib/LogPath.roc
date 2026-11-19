## The paths of the log read routes (Registry R-AP11, R-AP23, R-AP48 row 1; Design Q636; slice 257d, docs/slices/257-log-tiles.md section 3.5).
## Pure: no request, no R2. W0: `worker/tests/unit/LogPathTest.roc`. The inverse of `parse` is `Tlog.path` (slice 257a) and `key`.
## Every body is a stub until the code agent writes it (TW18).
import records.Tlog

LogPath :: [].{

	## What a path of `/log/` names. `Checkpoint`: `GET /log/checkpoint`. `Tile(tile)`: a hash tile, an entry bundle, or a partial one (C2SP tlog-tiles).
	Target : [Checkpoint, Tile(Tlog.Tile)]

	## The path after `/log/`, as the segments of the request (`Request.segments`, no empty item; the caller drops `"log"`), to its `Target`. The grammar:
	##
	## | Segments | Target |
	## | --- | --- |
	## | `["checkpoint"]` | `Checkpoint` |
	## | `["tile", L, G1, ..., Gk]`, `["tile", "entries", G1, ..., Gk]` | `Tile({ level: Hashes(L) or Entries, index: N, width: 256 })` |
	## | the same, and the last group is `"<digits>.p"`, then one more segment `W` | the same with `width: W`, W from 1 to 255 |
	##
	## L: decimal 0 to 63 with no leading zero (`0`, `7`, `63`). N: 1 to 7 groups of exactly 3 ASCII digits, each group but the last has an `x` before it (`x001`, `x234`, `067`),
	## a first group `x000` is a leading zero, so it is bad (N has the least groups: 67 is `067`, not `x000/067`). N fits in a `U64`
	## (`x018/x446/x744/x073/x709/x551/615` is the largest). W: decimal 1 to 255, no leading zero, no sign. A width of 256 is a full tile and has no `.p` path.
	## Bad, all `Err(BadPath)` (R-AP48 row 1: the path names no resource, so the answer is 404 with no R2 read): the empty list; any other first segment (upper case `Checkpoint`, `tiles`);
	## a segment that is empty or has a `/` (an extra slash that reached the segments); `.` and `..`; a level that is 64 or more, has a leading zero (`00`, `01`), a sign or is not an ASCII digit string;
	## `Entries` or `ENTRIES`; a group of 2 or 4 digits; an `x` on the last group, none on a group before it, an upper-case `X`; no group; more than 7 groups; N above `U64`;
	## `.p` on a hash tile with no width, a width of 0 or 256 or more, a width with a leading zero, `.P`, `.p` twice, or more segments after the width; extra segments after `checkpoint`.
	## The text of a segment is compared byte for byte (no case folding, no Unicode digits).
	parse : List(Str) -> Try(LogPath.Target, [BadPath])
	parse = |segments| match segments {
		["checkpoint"] => Ok(Checkpoint)
		["tile", "entries", .. as rest] => parse_tail(Entries, rest)
		["tile", level, .. as rest] => {
			l = parse_level(level)?
			parse_tail(Hashes(l), rest)
		}
		_ => Err(BadPath)
	}

	## The R2 key of a target (Design Q257-7: the path after `/log/`): `Checkpoint` is `checkpoint`, `Tile(tile)` is `Tlog.path(tile)`.
	key : LogPath.Target -> Str
	key = |target| match target {
		Checkpoint => "checkpoint"
		Tile(tile) => Tlog.path(tile)
	}

	## The `Cache-Control` of a 200 and of a 304 answer (R-AP11): `Checkpoint` is `max-age=5`, a tile (also a partial tile and an entry bundle) is `max-age=31536000, immutable`.
	cache_control : LogPath.Target -> Str
	cache_control = |target| match target {
		Checkpoint => "max-age=5"
		Tile(_) => "max-age=31536000, immutable"
	}

	## Does the Worker keep the answer in the Cache API of its colo (R-AP11, Design Q257-12)? A tile: yes. The checkpoint: no.
	in_cache_api : LogPath.Target -> Bool
	in_cache_api = |target| match target {
		Checkpoint => Bool.False
		Tile(_) => Bool.True
	}

	## The value of a text of ASCII digits only (at least one). A byte that is not `0` to `9` is bad. A text of more than 30 digits is bad (no overflow of `U128`).
	digits_value : Str -> Try(U128, [BadPath])
	digits_value = |text| {
		bytes = text.to_utf8()
		if bytes.is_empty() or bytes.len() > 30 {
			return Err(BadPath)
		}
		var $n = 0.U128
		for b in bytes {
			if b < 48 or b > 57 {
				return Err(BadPath)
			}
			$n = $n * 10 + (b - 48).to_u128()
		}
		Ok($n)
	}

	## L: decimal 0 to 63, no leading zero.
	parse_level : Str -> Try(U8, [BadPath])
	parse_level = |text| {
		if text.count_utf8_bytes() > 1 and text.starts_with("0") {
			return Err(BadPath)
		}
		n = digits_value(text)?
		if n > 63 {
			Err(BadPath)
		} else {
			Ok(n.to_u8_wrap())
		}
	}

	## W: decimal 1 to 255, no leading zero.
	parse_width : Str -> Try(U64, [BadPath])
	parse_width = |text| {
		if text.starts_with("0") {
			return Err(BadPath)
		}
		n = digits_value(text)?
		if n < 1 or n > 255 {
			Err(BadPath)
		} else {
			Ok(n.to_u64_wrap())
		}
	}

	## The segments after the level: the index groups, then the optional `.p` and the width.
	parse_tail : [Hashes(U8), Entries], List(Str) -> Try(LogPath.Target, [BadPath])
	parse_tail = |level, rest| {
		n = rest.len()
		partial = n >= 2 and rest.get(n - 2).map_ok(|g| g.ends_with(".p")) == Ok(Bool.True)
		if partial {
			width = parse_width(rest.get(n - 1) ?? "")?
			raw = rest.take_first(n - 1)
			last = raw.last() ?? ""
			groups = raw.drop_last(1).append(last.drop_suffix(".p"))
			index = parse_index(groups)?
			Ok(Tile({ level, index, width }))
		} else {
			index = parse_index(rest)?
			Ok(Tile({ level, index, width: 256 }))
		}
	}

	## N: 1 to 7 groups of 3 digits, an `x` before each group but the last, no first group `x000`, fits in `U64`.
	parse_index : List(Str) -> Try(U64, [BadPath])
	parse_index = |groups| {
		count = groups.len()
		if count == 0 or count > 7 {
			return Err(BadPath)
		}
		var $n = 0.U128
		var $i = 0.U64
		for g in groups {
			is_last = $i + 1 == count
			digits = if is_last {
				g
			} else if g.starts_with("x") {
				g.drop_prefix("x")
			} else {
				return Err(BadPath)
			}
			if digits.count_utf8_bytes() != 3 {
				return Err(BadPath)
			}
			v = digits_value(digits)?
			if $i == 0 and count > 1 and v == 0 {
				return Err(BadPath)
			}
			$n = $n * 1000 + v
			$i = $i + 1
		}
		$n.to_u64_try().map_err(|_| BadPath)
	}
}
