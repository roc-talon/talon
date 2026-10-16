import Internal/Nibble as Nibble

## Lowercase hex text for bytes.
Hex :: [].{

	## Two lowercase hex digits for each byte.
	encode : List(U8) -> Str
	encode = |bytes| {
		digits = bytes.fold([], |acc, b| acc.append(Nibble.to_ascii(b // 16)).append(Nibble.to_ascii(b % 16)))
		Str.from_utf8(digits) ?? ""
	}

	## The bytes of hex text. Upper and lower case digits are accepted.
	decode : Str -> Try(List(U8), [BadHex])
	decode = |text| decode_impl(text) # BODY
}

decode_impl : Str -> Try(List(U8), [BadHex])
decode_impl = |text| {
	chars = text.to_utf8()
	if chars.len() % 2 != 0 {
		return Err(BadHex)
	}
	chars.chunks_of(2).map_try(
		|pair| {
			hi = Nibble.from_ascii(pair.get(0) ?? 0)?
			lo = Nibble.from_ascii(pair.get(1) ?? 0)?
			Ok(hi * 16 + lo)
		},
	)
}
