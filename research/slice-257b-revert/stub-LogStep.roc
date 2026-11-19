## The decisions of the tile writer (Registry R-SG4, R-SG7, R-PU35, R-PU36, R-WH14 `LOG_KEY` and `LOG`; Design Q636; slice 257b, docs/slices/257-log-tiles.md section 3.4).
## Pure: no `Fx`, no clock, no key. W0: `worker/tests/unit/LogStepTest.roc`. The math of the tiles and of the checkpoint is `records.Tlog` (slice 257a).
## The effects (R2, D1, WebCrypto, the log lines) are in `worker/LogWriter.roc`. Every body that is not a constant of the design is a stub until the code agent writes it (TW18).
import records.Tlog

LogStep :: [].{

	## R-PU35, R-WH14 (Cron triggers), Design Q636: the cron expression of the job "Tile catch-up": every 5 min at minute 2. `main.roc` registers
	## `Worker.cron(LogStep.cron, LogWriter.run!)`, and `wrangler.toml` `[triggers] crons` has the same text (`roc-cfw sync --check`).
	cron : Str
	cron = "2-59/5 * * * *"

	## R-SG7, Design Q636: the most leaves of one step (256 entry bundles, about 260 R2 puts).
	cap : U64
	cap = 65536

	## R-SG7 row 4, R-WH14 `LOG`: the R2 key of the checkpoint. The R2 key of an object is its path after `/log/`; a tile key is `Tlog.path(tile)`.
	checkpoint_key : Str
	checkpoint_key = "checkpoint"

	## One row of the D1 read of R-SG7 row 1: the leaves with `idx` above the checkpoint size S, in `idx` order, at most `cap` rows (one D1 call).
	Row : { idx : I64, grp : Str, version : Str, hash : Str, time : I64 }

	## What one step did (R-SG7). `Same(S)`: no leaf above the checkpoint size S (S is 0 for a log with no checkpoint, Design Q636 (16)); the step wrote nothing.
	## `Wrote`: the tiles and the checkpoint of `size`, from the checkpoint size `from`; `tiles` is the count of tile objects that the step put.
	## `Lost`: the compare and swap of the checkpoint failed, and the checkpoint that another run wrote has size `theirs`, at least `size` (R-SG7 row 4): the step stopped.
	Outcome : [Same(U64), Wrote({ from : U64, size : U64, tiles : U64 }), Lost({ size : U64, theirs : U64 })]

	## R-SG7 row 1, R-SG2, R-SG5: the entry bytes (`Tlog.entry`) of the rows of the read above `size`, in order. The rows must be `idx` size + 1, size + 2, ... with no gap
	## (D1 `idx` is max + 1, so a gap or a row at or below `size` is a broken log): else `Err(Gap(idx))` with the `idx` of the first row that is not the next one.
	## More than `cap` rows: `Err(TooMany)`. No row: `Ok([])`.
	entries : U64, List(LogStep.Row) -> Try(List(List(U8)), [Gap(I64), TooMany])
	entries = |_size, _rows| crash "todo"

	## R-SG7 (Design Q636): the cron job goes on until the checkpoint size is the largest `idx`. After a step that wrote `cap` leaves, more can be due: `True` (one more step).
	## After a step that wrote fewer leaves, `Same` or `Lost`: `False`.
	again : LogStep.Outcome -> Bool
	again = |_outcome| crash "todo"

	## R-SG7 row 4: after a failed compare and swap the step reads the checkpoint again. `theirs` is its size, `wanted` the size that the step wanted to write.
	## `True`: stop (`theirs` is at least `wanted`). `theirs` below `wanted` is Q257-18 (open): no test fixes it.
	stop_after_race : U64, U64 -> Bool
	stop_after_race = |_theirs, _wanted| crash "todo"

	## R-WH14 `LOG_KEY`: the 32-byte Ed25519 public key from the JWK text that `WebCrypto.export_key!(imported, Jwk)` gives for the imported private key:
	## the member `x` in base64url (RFC 4648 5, no padding). A text that is not a JSON object, no `x`, or an `x` that is not 32 bytes of base64url: `Err(BadJwk)`.
	public_key : Str -> Try(List(U8), [BadJwk])
	public_key = |_jwk| crash "todo"

	## R-WH14 `LOG_KEY` (Design Q636, 257a P2): the key id of the key text must be the key id of its key: `Tlog.key_id(key.name, public)`. Else `Err(WrongKeyId)`.
	check_key : Tlog.SignerKey, List(U8) -> Try({}, [WrongKeyId])
	check_key = |_key, _public| crash "todo"

	## R-AP23 (proposal P-b1, slice file section 3.4): the content type that the step stores with an R2 object (HTTP metadata, so `R2.respond!` of slice 257d sends it):
	## `text/plain; charset=utf-8` for `checkpoint_key`, `application/octet-stream` for a tile.
	content_type : Str -> Str
	content_type = |_key| crash "todo"
}
