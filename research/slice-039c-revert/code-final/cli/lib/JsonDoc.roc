## A JSON value that the CLI prints. `render` gives one line with no spaces.
## Object keys keep the order of the list.
##
## `Real(text)` is a number that is not an `I64` (a fraction, an exponent, or out of range). It keeps the text of the number.
JsonDoc := [Null, Flag(Bool), Num(I64), Real(Str), Text(Str), Arr(List(JsonDoc)), Obj(List((Str, JsonDoc)))].{
	is_eq : _

	## One line. Text is escaped (quote, backslash, control characters). Other characters stay as they are.
	render : JsonDoc -> Str
	render = |doc| match doc {
		Null => "null"
		Flag(b) => if b "true" else "false"
		Num(n) => n.to_str()
		Real(text) => text
		Text(t) => quote(t)
		Arr(items) => "[${Str.join_with(items.map(|d| d.render()), ",")}]"
		Obj(pairs) => "{${Str.join_with(pairs.map(|(k, v)| "${quote(k)}:${v.render()}"), ",")}}"
	}

	## Reads JSON text (slice 002: the Talon files, R-TF1, R-TF2; slice 003: the GitHub pages, G2). A Talon file is read, changed and
	## written again, so the object keys keep the order of the text and no key is dropped (R-TF2: unknown fields stay).
	##
	## | JSON | `JsonDoc` |
	## | --- | --- |
	## | `null`, `true`, `false` | `Null`, `Flag` |
	## | A number with no fraction and no exponent that fits `I64` | `Num` |
	## | Any other valid JSON number (a fraction, an exponent, out of range) | `Real` with the text of the number (G2: a field that Talon does not read never fails a parse) |
	## | A text that is not a valid JSON number (`01`, `1.`, `.5`, `1e`, `-`, `+1`) | `Err(BadJson)` |
	## | A string | `Text`. The escapes of `render`, `\/`, `\b`, `\f` and `\uXXXX` (a surrogate pair too) are decoded. |
	## | An array, an object | `Arr`, `Obj`. A repeated key is not tested. |
	##
	## White space between tokens is allowed. Text after the value (other than white space) is `Err(BadJson)`.
	## The empty text is `Err(BadJson)`.
	parse : Str -> Try(JsonDoc, [BadJson])
	parse = |text| {
		bytes = text.to_utf8()
		match parse_value(bytes, skip_ws(bytes, 0)) {
			Ok(found) => if skip_ws(bytes, found.next) == bytes.len() Ok(found.val) else Err(BadJson)
			Err(BadJson) => Err(BadJson)
		}
	}
}

quote : Str -> Str
quote = |text| {
	named = text
		.replace_each("\\", "\\\\")
		.replace_each("\"", "\\\"")
		.replace_each("\n", "\\n")
		.replace_each("\r", "\\r")
		.replace_each("\t", "\\t")
	"\"${U8.to(0, 31).fold(named, escape_control)}\""
}

# The other control characters (0 to 31) become `\u00XX`. The named ones are already gone.
escape_control : Str, U8 -> Str
escape_control = |text, code| match Str.from_utf8([code]) {
	Ok(char) => text.replace_each(char, "\\u00${hex(code // 16)}${hex(code % 16)}")
	Err(_) => text
}

hex : U8 -> Str
hex = |digit| match Str.from_utf8([if digit < 10 48 + digit else 87 + digit]) {
	Ok(char) => char
	Err(_) => "0"
}

# The parser reads bytes. A step gives the value and the index of the first byte after it.
Step(a) : Try({ val : a, next : U64 }, [BadJson])

skip_ws : List(U8), U64 -> U64
skip_ws = |bytes, i| match bytes.get(i) {
	Ok(b) => if b == 32 or b == 9 or b == 10 or b == 13 skip_ws(bytes, i + 1) else i
	Err(_) => i
}

parse_value : List(U8), U64 -> Step(JsonDoc)
parse_value = |bytes, i| match bytes.get(i) {
	Ok(123) => parse_object(bytes, skip_ws(bytes, i + 1))
	Ok(91) => parse_array(bytes, skip_ws(bytes, i + 1))
	Ok(34) => parse_string(bytes, i + 1).map_ok(|s| { val: Text(s.val), next: s.next })
	Ok(116) => literal(bytes, i, "true", Flag(Bool.True))
	Ok(102) => literal(bytes, i, "false", Flag(Bool.False))
	Ok(110) => literal(bytes, i, "null", Null)
	Ok(b) => if b == 45 or (b >= 48 and b <= 57) parse_number(bytes, i) else Err(BadJson)
	Err(_) => Err(BadJson)
}

literal : List(U8), U64, Str, JsonDoc -> Step(JsonDoc)
literal = |bytes, i, word, doc| {
	want = word.to_utf8()
	if bytes.sublist({ start: i, len: want.len() }) == want Ok({ val: doc, next: i + want.len() }) else Err(BadJson)
}

# A JSON number: `-`, an integer part with no leading zero, an optional fraction, an optional exponent.
parse_number : List(U8), U64 -> Step(JsonDoc)
parse_number = |bytes, i| {
	first = if bytes.get(i) == Ok(45) i + 1 else i
	int_end = digits_end(bytes, first)
	if int_end == first or (int_end - first > 1 and bytes.get(first) == Ok(48)) return Err(BadJson)
	frac_end = fraction_end(bytes, int_end)?
	end = exponent_end(bytes, frac_end)?
	text = Str.from_utf8_lossy(bytes.sublist({ start: i, len: end - i }))
	if end == int_end {
		match I64.from_str(text) {
			Ok(n) => Ok({ val: Num(n), next: end })
			Err(_) => Ok({ val: Real(text), next: end })
		}
	} else {
		Ok({ val: Real(text), next: end })
	}
}

# `i` is the end of the integer part. A `.` needs one digit or more after it.
fraction_end : List(U8), U64 -> Try(U64, [BadJson])
fraction_end = |bytes, i| if bytes.get(i) == Ok(46) {
	end = digits_end(bytes, i + 1)
	if end == i + 1 Err(BadJson) else Ok(end)
} else {
	Ok(i)
}

# `i` is the end of the fraction. An `e` or `E` needs an optional sign and one digit or more.
exponent_end : List(U8), U64 -> Try(U64, [BadJson])
exponent_end = |bytes, i| if bytes.get(i) == Ok(101) or bytes.get(i) == Ok(69) {
	start = if bytes.get(i + 1) == Ok(43) or bytes.get(i + 1) == Ok(45) i + 2 else i + 1
	end = digits_end(bytes, start)
	if end == start Err(BadJson) else Ok(end)
} else {
	Ok(i)
}

digits_end : List(U8), U64 -> U64
digits_end = |bytes, i| match bytes.get(i) {
	Ok(b) => if b >= 48 and b <= 57 digits_end(bytes, i + 1) else i
	Err(_) => i
}

# `i` is the index after the opening quote.
parse_string : List(U8), U64 -> Step(Str)
parse_string = |bytes, i| string_loop(bytes, i, [])

string_loop : List(U8), U64, List(U8) -> Step(Str)
string_loop = |bytes, i, out| match bytes.get(i) {
	Err(_) => Err(BadJson)
	Ok(34) => match Str.from_utf8(out) {
		Ok(text) => Ok({ val: text, next: i + 1 })
		Err(_) => Err(BadJson)
	}
	Ok(92) => match bytes.get(i + 1) {
		Ok(34) => string_loop(bytes, i + 2, out.append(34))
		Ok(92) => string_loop(bytes, i + 2, out.append(92))
		Ok(47) => string_loop(bytes, i + 2, out.append(47))
		Ok(98) => string_loop(bytes, i + 2, out.append(8))
		Ok(102) => string_loop(bytes, i + 2, out.append(12))
		Ok(110) => string_loop(bytes, i + 2, out.append(10))
		Ok(114) => string_loop(bytes, i + 2, out.append(13))
		Ok(116) => string_loop(bytes, i + 2, out.append(9))
		Ok(117) => match unicode_escape(bytes, i + 2) {
			Ok(found) => string_loop(bytes, found.next, out.concat(utf8_of(found.val)))
			Err(BadJson) => Err(BadJson)
		}
		_ => Err(BadJson)
	}
	Ok(b) => if b < 32 Err(BadJson) else string_loop(bytes, i + 1, out.append(b))
}

# `i` is the index after `\u`. A high surrogate needs a `\uXXXX` low surrogate after it.
unicode_escape : List(U8), U64 -> Step(U32)
unicode_escape = |bytes, i| {
	unit = hex4(bytes, i)?
	if unit >= 0xD800 and unit <= 0xDBFF {
		if bytes.get(i + 4) == Ok(92) and bytes.get(i + 5) == Ok(117) {
			low = hex4(bytes, i + 6)?
			if low >= 0xDC00 and low <= 0xDFFF {
				Ok({ val: 0x10000 + (unit - 0xD800) * 1024 + (low - 0xDC00), next: i + 10 })
			} else {
				Err(BadJson)
			}
		} else {
			Err(BadJson)
		}
	} else if unit >= 0xDC00 and unit <= 0xDFFF {
		Err(BadJson)
	} else {
		Ok({ val: unit, next: i + 4 })
	}
}

hex4 : List(U8), U64 -> Try(U32, [BadJson])
hex4 = |bytes, i| {
	digits = bytes.sublist({ start: i, len: 4 })
	if digits.len() == 4 {
		digits.fold(
			Ok(0),
			|acc, b| match (acc, hex_value(b)) {
				(Ok(n), Ok(d)) => Ok(n * 16 + d)
				_ => Err(BadJson)
			},
		)
	} else {
		Err(BadJson)
	}
}

hex_value : U8 -> Try(U32, [BadJson])
hex_value = |b|
	if b >= 48 and b <= 57 Ok((b - 48).to_u32())
	else if b >= 97 and b <= 102 Ok((b - 87).to_u32())
	else if b >= 65 and b <= 70 Ok((b - 55).to_u32())
	else Err(BadJson)

utf8_of : U32 -> List(U8)
utf8_of = |cp|
	if cp < 0x80 [cp.to_u8_wrap()]
	else if cp < 0x800 [(0xC0 + cp // 64).to_u8_wrap(), (0x80 + cp % 64).to_u8_wrap()]
	else if cp < 0x10000 [(0xE0 + cp // 4096).to_u8_wrap(), (0x80 + cp // 64 % 64).to_u8_wrap(), (0x80 + cp % 64).to_u8_wrap()]
	else [(0xF0 + cp // 262144).to_u8_wrap(), (0x80 + cp // 4096 % 64).to_u8_wrap(), (0x80 + cp // 64 % 64).to_u8_wrap(), (0x80 + cp % 64).to_u8_wrap()]

# `i` is the index of the first byte after `[` and the white space.
parse_array : List(U8), U64 -> Step(JsonDoc)
parse_array = |bytes, i| match bytes.get(i) {
	Ok(93) => Ok({ val: Arr([]), next: i + 1 })
	_ => array_items(bytes, i, [])
}

array_items : List(U8), U64, List(JsonDoc) -> Step(JsonDoc)
array_items = |bytes, i, items| {
	item = parse_value(bytes, i)?
	after = skip_ws(bytes, item.next)
	more = items.append(item.val)
	match bytes.get(after) {
		Ok(44) => array_items(bytes, skip_ws(bytes, after + 1), more)
		Ok(93) => Ok({ val: Arr(more), next: after + 1 })
		_ => Err(BadJson)
	}
}

# `i` is the index of the first byte after `{` and the white space.
parse_object : List(U8), U64 -> Step(JsonDoc)
parse_object = |bytes, i| match bytes.get(i) {
	Ok(125) => Ok({ val: Obj([]), next: i + 1 })
	_ => object_pairs(bytes, i, [])
}

object_pairs : List(U8), U64, List((Str, JsonDoc)) -> Step(JsonDoc)
object_pairs = |bytes, i, pairs| {
	if bytes.get(i) != Ok(34) return Err(BadJson)
	key = parse_string(bytes, i + 1)?
	colon = skip_ws(bytes, key.next)
	if bytes.get(colon) != Ok(58) return Err(BadJson)
	item = parse_value(bytes, skip_ws(bytes, colon + 1))?
	after = skip_ws(bytes, item.next)
	more = pairs.append((key.val, item.val))
	match bytes.get(after) {
		Ok(44) => object_pairs(bytes, skip_ws(bytes, after + 1), more)
		Ok(125) => Ok({ val: Obj(more), next: after + 1 })
		_ => Err(BadJson)
	}
}
