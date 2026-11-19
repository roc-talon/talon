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
import pf.D1
import pf.Body
import pf.Env
import pf.Io
import pf.Log
import pf.WebCrypto
import records.Tlog
import lib.LogStep

LogWriter :: [].{

	## R-WH14 `LOG`: the bucket of the tiles and the checkpoint (`talon-log`, bench `talon-log-bench`). `main.roc` declares it.
	log : R2
	log = R2.binding("LOG")

	## R-SG7: one idempotent step: "build the tiles and sign up to the largest leaf index in D1", at most `LogStep.cap` leaves. The flow is in the header.
	step! : () => Try(LogStep.Outcome, [Fault(Str)])
	step! = || {
		text = Env.secret!("LOG_KEY").map_ok(|x| x.reveal()).map_err(|_| Fault("LOG_KEY is not set"))?
		signer = Tlog.parse_signer_key(text).map_err(|_| Fault("LOG_KEY is not a signer key text"))?
		key = WebCrypto.import_key!(Ed25519, Pkcs8(Tlog.pkcs8(signer.seed))).map_err(|e| Fault(Str.inspect(e)))?
		jwk = match WebCrypto.export_key!(key, Jwk) {
			Ok(Jwk(j)) => j
			_ => return Err(Fault("LOG_KEY: no JWK export"))
		}
		public = LogStep.public_key(jwk).map_err(|_| Fault("LOG_KEY: no public key"))?
		LogStep.check_key(signer, public).map_err(|_| Fault("LOG_KEY: the key id is not the key id of the key"))?
		origin = signer.name
		old = read_checkpoint!(origin)?
		size = old.size
		edges = Tlog.edge(size)
		reads = Io.all!(edges.map(|t| R2.get(log, Tlog.path(t))))
		var $edge = []
		for (t, r) in edges.map2(reads, |a, b| (a, b)) {
			match r {
				Ok(obj) => {
					bytes = Body.bytes!(obj.body).map_err(|e| Fault(Str.inspect(e)))?
					$edge = $edge.append({ tile: t, bytes })
				}
				Err(_) => return Err(Fault("a tile of the checkpoint size is missing: ${Tlog.path(t)}"))
			}
		}
		rows : Try(List(LogStep.Row), _)
		rows = db.all!("SELECT idx, grp, version, hash, time FROM log WHERE idx > ? ORDER BY idx LIMIT ?", (size.to_i64_wrap(), LogStep.cap.to_i64_wrap()))
		got = rows.map_err(|e| Fault(Str.inspect(e)))?
		entries = LogStep.entries(size, got).map_err(|e| Fault(Str.inspect(e)))?
		if entries.is_empty() {
			return Ok(Same(size))
		}
		grown = Tlog.grow(size, $edge, entries).map_err(|e| Fault(Str.inspect(e)))?
		if size > 0 and grown.old_root != old.root {
			return Err(Fault("the root of the tiles is not the root of the checkpoint"))
		}
		puts = Io.all!(
			grown.tiles.map(
				|tb| {
					k = Tlog.path(tb.tile)
					R2.put_with(log, k, Body.Bytes(tb.bytes), { http: { content_type: LogStep.content_type(k) } })
				},
			),
		)
		if puts.any(|p| p.is_err()) {
			return Err(Fault("a tile put failed"))
		}
		new_size = size + entries.len()
		body = Tlog.checkpoint_body(origin, new_size, grown.root)
		sig = WebCrypto.sign!({ alg: Ed25519, key, data: body.to_utf8() }).map_err(|e| Fault(Str.inspect(e)))?
		note = Tlog.signed_note(body, origin, signer.key_id, sig)
		match R2.put_with!(log, LogStep.checkpoint_key, Body.Text(note), { only_if: old.cond, http: { content_type: LogStep.content_type(LogStep.checkpoint_key) } }) {
			Ok(_) => Ok(Wrote({ from: size, size: new_size, tiles: grown.tiles.len() }))
			Err(PreconditionFailed) => {
				again = read_checkpoint!(origin)?
				if LogStep.stop_after_race(again.size, new_size) {
					Ok(Lost({ size: new_size, theirs: again.size }))
				} else {
					Err(Fault("the checkpoint changed to a smaller size"))
				}
			}
			Err(e) => Err(Fault(Str.inspect(e)))
		}
	}

	db = D1.binding("DB")

	read_checkpoint! : Str => Try({ size : U64, root : List(U8), cond : R2.Cond }, [Fault(Str)])
	read_checkpoint! = |origin| match R2.get!(log, LogStep.checkpoint_key) {
		Err(NotFound) => Ok({ size: 0, root: [], cond: R2.absent })
		Err(e) => Err(Fault(Str.inspect(e)))
		Ok(obj) => {
			text = Body.text!(obj.body).map_err(|e| Fault(Str.inspect(e)))?
			ck = Tlog.parse_checkpoint(origin, text).map_err(|_| Fault("the checkpoint does not parse"))?
			Ok({ size: ck.size, root: ck.root, cond: { etag_matches: obj.meta.etag } })
		}
	}

	## R-PU35, R-SG7: the cron job "Tile catch-up". `step!` while `LogStep.again`; the log lines of the header.
	run! : Worker.Scheduled => Try({}, [Fault(Str)])
	run! = |_s| {
		var $go = Bool.True
		while $go {
			match step!() {
				Ok(outcome) => {
					match outcome {
						Wrote(w) => Log.info!("log wrote", { from: w.from, size: w.size, tiles: w.tiles })
						Lost(l) => Log.warn!("log checkpoint changed", { size: l.size, theirs: l.theirs })
						Same(_) => {}
					}
					$go = LogStep.again(outcome)
				}
				Err(Fault(text)) => {
					Log.error!("log step failed", { error: text })
					return Err(Fault(text))
				}
			}
		}
		Ok({})
	}
}
