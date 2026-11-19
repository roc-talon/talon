## The tile writer (Registry R-SG4, R-SG7, R-PU35, R-PU36, R-WH14 `LOG_KEY` and `LOG`, R-AP41; Design Q636; slice 257b, docs/slices/257-log-tiles.md sections 3.2 and 3.4).
## The decisions are in `lib/LogStep.roc` (pure, W0) and `records.Tlog` (the tlog math, slice 257a). The tests are W2: `worker/tests/cases/log/`.
## The test entry is the cron job "Tile catch-up": `main.roc` registers `Worker.cron(LogStep.cron, LogWriter.run!)` (section 3.4). Slice 257c calls `step!` after each write that adds a leaf.
##
## One step (`step!`), in this order (R-SG7 rows 1 to 4):
## 1. The key: `Env.secret!("LOG_KEY")`, `Tlog.parse_signer_key`, `WebCrypto.import_key!(Ed25519, Pkcs8(Tlog.pkcs8(seed)))` (extractable), `WebCrypto.export_key!(key, Jwk)`,
##    `LogStep.public_key`, `LogStep.check_key`. A missing secret, a bad text or a wrong key id: `Err(Fault(..))` and NO R2 write (R-WH14: "500 internal and no write"; Q257-17).
##    The origin of the checkpoint is the key name (R-SG4, R-WH14).
## 2. `R2.get!(log, LogStep.checkpoint_key)`: `NotFound` is the size S = 0 and the condition `R2.absent`; else `Tlog.parse_checkpoint(origin, text)` gives S and the old root, and the
##    condition is `{ etag_matches: meta.etag }`. A checkpoint that does not parse: `Err(Fault(..))`, no write.
## 3. `R2.get!` of each tile of `Tlog.edge(S)` (key `Tlog.path(tile)`, `Io.all!` for one crossing). A missing tile: `Err(Fault(..))`, no write.
## 4. ONE D1 call: the leaves `WHERE idx > S ORDER BY idx LIMIT LogStep.cap` (R-SG7 row 1, Design Q636). `LogStep.entries`. No row: `Ok(Same(S))`, no write.
## 5. `Tlog.grow(S, edge tiles, entries)`. `Err(BadEdge)`, or an `old_root` that is not the root of the checkpoint of S: `Err(Fault(..))`, no write.
## 6. `R2.put_with!` of each tile of `grown.tiles` (`Io.all!`), with `http: { content_type: LogStep.content_type(key) }`. Any failed put: `Err(Fault(..))`, and NO checkpoint (row 2).
## 7. `Tlog.checkpoint_body(origin, N, root)`, `WebCrypto.sign!({ alg: Ed25519, key, data })`, `Tlog.signed_note`. `R2.put_with!(log, checkpoint_key, note, { only_if: <the condition of 2>,
##    http: { content_type } })` (row 4). `Ok`: `Ok(Wrote({ from: S, size: N, tiles: grown.tiles.len() }))`.
##    `Err(PreconditionFailed)`: read the checkpoint again (`R2.get!`, `Tlog.parse_checkpoint`); `LogStep.stop_after_race(theirs, N)`: `Ok(Lost({ size: N, theirs }))`.
##    A smaller size (Q257-18, open) or a read that fails: as the answer of Q257-18.
##
## The cron run (`run!`): the clock is not needed. `step!` while `LogStep.again(outcome)`. The log lines (a proposal, TW24, slice file section 5):
##   `Wrote`: `Log.info!("log wrote", { from, size, tiles })`. `Lost`: `Log.warn!("log checkpoint changed", { size, theirs })`. `Same`: no line.
##   `Err(Fault(text))`: `Log.error!("log step failed", { error: text })`, and the run gives the `Err` (Q257-17 recommendation (a): the run outcome is a failure).
import pf.Worker
import pf.R2
import lib.LogStep

LogWriter :: [].{

	## R-WH14 `LOG`: the bucket of the tiles and the checkpoint (`talon-log`, bench `talon-log-bench`). `main.roc` declares it.
	log : R2
	log = R2.binding("LOG")

	## R-SG7: one idempotent step: "build the tiles and sign up to the largest leaf index in D1", at most `LogStep.cap` leaves. The flow is in the header.
	step! : () => Try(LogStep.Outcome, [Fault(Str)])
	step! = || crash "todo"

	## R-PU35, R-SG7: the cron job "Tile catch-up". `step!` while `LogStep.again`; the log lines of the header.
	run! : Worker.Scheduled => Try({}, [Fault(Str)])
	run! = |_s| crash "todo"
}
