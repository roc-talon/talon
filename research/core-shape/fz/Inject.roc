Inject := [].{
	## Effectful logic that gets its effects as a record
	count_lines! : { read! : Str => Try(Str, [NotFound]) }, Str => U64
	count_lines! = |fx, path|
		match (fx.read!)(path) {
			Ok(text) => text.split_on("\n").len()
			Err(_) => 0
		}
}

