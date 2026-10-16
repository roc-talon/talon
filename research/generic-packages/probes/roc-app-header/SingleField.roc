# Repro: a record with one shorthand field `{ offset }` is read as a block, not a record.
# On nightly-2026-10-14-38a3029, `roc check` gives "type mismatch": the branch is
# `[Err([BadHeader(U64)])]`. With two fields (`{ offset, len }`) it is a record.
# `{ offset: offset }` works, and `roc fmt` keeps it.
SingleField :: [].{
	to_err : Try(U64, [Bad(U64)]) -> Try(U64, [BadHeader({ offset : U64 })])
	to_err = |result| match result {
		Ok(n) => Ok(n)
		Err(Bad(offset)) => Err(BadHeader({ offset }))
	}
}
