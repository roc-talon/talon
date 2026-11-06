import Nullable

## The request of `POST /v1/compat` on the bot path (Registry R-AP10, R-AP66; Design Q154; slice 104d). Pure.
## The values (`result`, the id forms, the row limit) are checked by the Worker, not here (R-AP66 checks 5 and 6).
Compat :: [].{

	## One matrix row. All values are text as sent. `error_digest` is text or null (R-AP58).
	Row : { hash : Str, nightly : Str, target : Str, result : Str, error_digest : Try(Str, [None]) }

	## The sweep of a bot request (R-MX4): `upto_log_index` is the log index bound.
	Sweep : { nightly : Str, target : Str, upto_log_index : U64 }

	## The body: `rows` and the optional `sweep`.
	Post : { rows : List(Compat.Row), sweep : Try(Compat.Sweep, [None]) }

	## The wire forms. The `source` members exist only to find a `source` member (R-AP66: it is refused in the body and in a row).
	RowWire : { hash : Str, nightly : Str, target : Str, result : Str, error_digest : Nullable(Str), source : Try(Nullable(Str), [Missing]) }
	SweepWire : { nightly : Str, target : Str, upto_log_index : U64 }
	PostWire : { rows : List(Compat.RowWire), sweep : Try(Nullable(Compat.SweepWire), [Missing]), source : Try(Nullable(Str), [Missing]) }

	## Members in alphabetical order. `error_digest` is always written (`null` for none). `sweep` is left out for none. `source` is never written.
	encode_post : Compat.Post -> Str
	encode_post = |post| Json.to_str({
		rows: post.rows.map(|r| { hash: r.hash, nightly: r.nightly, target: r.target, result: r.result, error_digest: Nullable.write(r.error_digest) }),
		sweep: Nullable.write_opt(post.sweep),
	})

	## R-AP66, R-AP51, R-AP44. A missing `rows`, a missing or null `hash`, `nightly`, `target`, `result`, a missing `error_digest`, a `source` member (any value, also with an escaped key) in the body or in a row, and an `upto_log_index` that is not a U64 are `BadJson`. A `null` `error_digest` is `Err(None)`. An unknown member is ignored.
	decode_post : Str -> Try(Compat.Post, [BadJson(Str)])
	decode_post = |text| {
		parsed : Try(Compat.PostWire, _)
		parsed = Json.parse(text)
		match parsed {
			Err(e) => Err(BadJson(Str.inspect(e)))
			Ok(w) =>
				if Nullable.read_opt(w.source) != Err(None) or w.source.is_ok() {
					Err(BadJson("member source"))
				} else if w.rows.any(|r| r.source.is_ok()) {
					Err(BadJson("member source in a row"))
				} else {
					Ok({
						rows: w.rows.map(|r| { hash: r.hash, nightly: r.nightly, target: r.target, result: r.result, error_digest: Nullable.read(r.error_digest) }),
						sweep: Nullable.read_opt(w.sweep),
					})
				}
		}
	}
}
