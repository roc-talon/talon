# Hidden helper: main.roc does not list Nibble.
Nibble :: [].{
	to_ascii : U8 -> U8
	to_ascii = |n| if n < 10 n + '0' else n - 10 + 'a'

	from_ascii : U8 -> Try(U8, [BadHex])
	from_ascii = |c| {
		if c >= '0' and c <= '9' {
			Ok(c - '0')
		} else if c >= 'a' and c <= 'f' {
			Ok(c - 'a' + 10)
		} else if c >= 'A' and c <= 'F' {
			Ok(c - 'A' + 10)
		} else {
			Err(BadHex)
		}
	}
}
