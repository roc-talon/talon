Wire :: [].{
	encode : Str -> Str
	encode = |s| s.count_utf8_bytes()
}
