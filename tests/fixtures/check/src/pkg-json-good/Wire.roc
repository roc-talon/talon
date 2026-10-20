Wire :: [].{
	encode : Str -> Str
	encode = |s| "\"${s}\""
}
