## Private reference of slice 104e (not for the code agent).
Toolchain :: [].{

	Row : { tag : Str, target : Str, asset_name : Str, sha256 : Str, published_at : U64, log_index : U64 }
	Page : { toolchains : List(Toolchain.Row), more : Bool }
	Put : { toolchains : List(Toolchain.Row) }

	encode_row : Toolchain.Row -> Str
	encode_row = |r| "{\"tag\":${Json.to_str(r.tag)},\"target\":${Json.to_str(r.target)},\"asset_name\":${Json.to_str(r.asset_name)},\"sha256\":${Json.to_str(r.sha256)},\"published_at\":${r.published_at.to_str()},\"log_index\":${r.log_index.to_str()}}"

	rows_text : List(Toolchain.Row) -> Str
	rows_text = |rows| {
		items : List(Str)
		items = rows.map(encode_row)
		"[${Str.join_with(items, ",")}]"
	}

	decode_row : Str -> Try(Toolchain.Row, [BadJson(Str)])
	decode_row = |text| {
		parsed : Try(Toolchain.Row, _)
		parsed = Json.parse(text)
		parsed.map_err(|e| BadJson(Str.inspect(e)))
	}

	encode_page : Toolchain.Page -> Str
	encode_page = |p| "{\"toolchains\":${rows_text(p.toolchains)},\"more\":${if (p.more) "true" else "false"}}"

	decode_page : Str -> Try(Toolchain.Page, [BadJson(Str)])
	decode_page = |text| {
		parsed : Try(Toolchain.Page, _)
		parsed = Json.parse(text)
		parsed.map_err(|e| BadJson(Str.inspect(e)))
	}

	encode_put : Toolchain.Put -> Str
	encode_put = |p| "{\"toolchains\":${rows_text(p.toolchains)}}"

	decode_put : Str -> Try(Toolchain.Put, [BadJson(Str)])
	decode_put = |text| {
		parsed : Try(Toolchain.Put, _)
		parsed = Json.parse(text)
		parsed.map_err(|e| BadJson(Str.inspect(e)))
	}
}
