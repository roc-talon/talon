## The answers of the toolchain routes (Registry R-AP5, R-AP6, R-AP49 row of R-RE4, R-AP73; slice 104e). Pure.
## The encoders write the bytes of `worker/lib/Toolchains.roc` (`row_text`, `put_body`, `page_body`): no white space, a row with the members `tag`, `target`, `asset_name`, `sha256`, `published_at`, `log_index` in this order (not alphabetical), the rows in the order given.
## The decoders follow R-AP51: all members are required, an unknown member is ignored.
Toolchain :: [].{

	## A row of R-RE4. `published_at` is milliseconds (R-AP50).
	Row : { tag : Str, target : Str, asset_name : Str, sha256 : Str, published_at : U64, log_index : U64 }

	## R-AP5: `{"toolchains":[..],"more":<bool>}`.
	Page : { toolchains : List(Toolchain.Row), more : Bool }

	## R-AP6: `{"toolchains":[..]}`.
	Put : { toolchains : List(Toolchain.Row) }

	encode_row : Toolchain.Row -> Str
	encode_row = |_r| crash "todo"

	decode_row : Str -> Try(Toolchain.Row, [BadJson(Str)])
	decode_row = |_text| crash "todo"

	encode_page : Toolchain.Page -> Str
	encode_page = |_p| crash "todo"

	decode_page : Str -> Try(Toolchain.Page, [BadJson(Str)])
	decode_page = |_text| crash "todo"

	encode_put : Toolchain.Put -> Str
	encode_put = |_p| crash "todo"

	decode_put : Str -> Try(Toolchain.Put, [BadJson(Str)])
	decode_put = |_text| crash "todo"
}
