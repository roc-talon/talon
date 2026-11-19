## PRIVATE REFERENCE of slice 257d (the test agent's, to prove that each test can pass and to make the revert mutants). Not the code of the code agent.
import records.Tlog

LogPath :: [].{

	Target : [Checkpoint, Tile(Tlog.Tile)]

	parse : List(Str) -> Try(LogPath.Target, [BadPath])
	parse = |segments| match segments {
		["checkpoint"] => Ok(Checkpoint)
		["tile", level_text, .. as rest] => {
			level = parse_level(level_text)?
			tile_of(level, rest)
		}
		_ => Err(BadPath)
	}

	parse_level : Str -> Try([Hashes(U8), Entries], [BadPath])
	parse_level = |text| {
		if text == "entries" {
			Ok(Entries)
		} else {
			n = number(text, 2)?
			if n <= 63 { Ok(Hashes(n.to_u8_wrap())) } else { Err(BadPath) }
		}
	}

	## A decimal number with no leading zero, 1 to `max_digits` ASCII digits.
	number : Str, U64 -> Try(U64, [BadPath])
	number = |text, max_digits| {
		bytes = text.to_utf8()
		if bytes.is_empty() or bytes.len() > max_digits or !bytes.all(is_digit) {
			Err(BadPath)
		} else if bytes.len() > 1 and bytes.first() == Ok('0') {
			Err(BadPath)
		} else {
			Ok(bytes.fold(0, |acc, b| acc * 10 + (b - '0').to_u64()))
		}
	}

	is_digit : U8 -> Bool
	is_digit = |b| b >= '0' and b <= '9'

	tile_of : [Hashes(U8), Entries], List(Str) -> Try(LogPath.Target, [BadPath])
	tile_of = |level, rest| {
		partial = match rest {
			[.. as init, last, w] => if last.ends_with(".p") { Ok((init.append(last.drop_suffix(".p")), w)) } else { Err(Full) }
			_ => Err(Full)
		}
		parts = match partial {
			Ok((groups, w)) => {
				width = number(w, 3)?
				if width >= 1 and width <= 255 { Ok((groups, width)) } else { Err(BadPath) }
			}
			Err(Full) => Ok((rest, 256))
		}?
		index = index_of(parts.0)?
		Ok(Tile({ level, index, width: parts.1 }))
	}

	## 1 to 7 groups of 3 digits, an `x` before each group but the last, the first group (of 2 or more) not zero, at most `U64`.
	index_of : List(Str) -> Try(U64, [BadPath])
	index_of = |groups| {
		n = groups.len()
		if n < 1 or n > 7 {
			Err(BadPath)
		} else {
			vals = groups.map_with_index(|g, i| group(g, i + 1 < n)).map_try(|r| r)?
			if n > 1 and vals.first() == Ok(0) {
				Err(BadPath)
			} else {
				total = vals.fold(0.U128, |acc, v| acc * 1000 + v.to_u128())
				if total <= 18446744073709551615 { Ok(total.to_u64_wrap()) } else { Err(BadPath) }
			}
		}
	}

	group : Str, Bool -> Try(U64, [BadPath])
	group = |text, has_x| {
		digits = if has_x { if text.starts_with("x") text.drop_prefix("x") else return Err(BadPath) } else text
		bytes = digits.to_utf8()
		if bytes.len() == 3 and bytes.all(is_digit) {
			Ok(bytes.fold(0, |acc, b| acc * 10 + (b - '0').to_u64()))
		} else {
			Err(BadPath)
		}
	}

	key : LogPath.Target -> Str
	key = |target| match target {
		Checkpoint => "checkpoint"
		Tile(tile) => Tlog.path(tile)
	}

	cache_control : LogPath.Target -> Str
	cache_control = |target| match target {
		Checkpoint => "max-age=5"
		Tile(_) => "max-age=31536000, immutable"
	}

	in_cache_api : LogPath.Target -> Bool
	in_cache_api = |target| match target {
		Checkpoint => Bool.False
		Tile(_) => Bool.True
	}
}
