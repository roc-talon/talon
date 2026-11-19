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
##    A smaller size, or a read that fails: one more step, then stop (Q257-18, Design Q636).
##
## The cron run (`run!`): the clock is not needed. `step!` while `LogStep.again(outcome)`. The log lines (a proposal, TW24, slice file section 5):
##   `Wrote`: `Log.info!("log wrote", { from, size, tiles })`. `Lost`: `Log.warn!("log checkpoint changed", { size, theirs })`. `Same`: no line.
##   `Err(Fault(text))`: `Log.error!("log step failed", { error: text })`, and the run gives the `Err` (Q257-17 recommendation (a): the run outcome is a failure).
import pf.Worker
import pf.Response
import pf.R2
import pf.D1
import pf.Env
import pf.Io
import pf.Log
import pf.WebCrypto
import records.Tlog
import lib.LogStep
import lib.LogTrigger

LogWriter :: [].{

	## R-WH14 `LOG`: the bucket of the tiles and the checkpoint (`talon-log`, bench `talon-log-bench`). `main.roc` declares it.
	log : R2
	log = R2.binding("LOG")

	## R-SG7: one idempotent step: "build the tiles and sign up to the largest leaf index in D1", at most `LogStep.cap` leaves. The flow is in the header.
	step! : () => Try(LogStep.Outcome, [Fault(Str)])
	step! = || {
		key = signer!()?
		step_once!(key, Bool.False)
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

	## Slice 257c (R-SG7, R-PU1, R-AP41; Design Q636; slice file section 3.6): ONE step after an answer or at the end of a queue batch. No loop: a step after an answer
	## takes at most `LogStep.cap` leaves, and the cron "Tile catch-up" does the rest (R-SG7). The log line of the outcome is the line of `run!` (`log wrote`, `log checkpoint changed`,
	## no line for `Same`). A failed step: ONE line `Log.error!("log step failed", { error })`, and nothing else: it never fails, so the answer, the acks and the retries of a queue batch
	## do not change, and the platform writes no line `after respond: failed` (R-SG7: "a step after an answer gives only the log line").
	once! : () => {}
	once! = || {
		match step!() {
			Ok(Wrote(w)) => Log.info!("log wrote", { from: w.from, size: w.size, tiles: w.tiles })
			Ok(Lost(l)) => Log.warn!("log checkpoint changed", { size: l.size, theirs: l.theirs })
			Ok(Same(_)) => {}
			Err(Fault(text)) => Log.error!("log step failed", { error: text })
		}
	}

	## Slice 257c (R-SG7, R-PU1, Design Q636 (8)): the result of a write route (publish, ingest, `PUT /v1/toolchains/{tag}`) with the step as work after the answer
	## (`Response.after(|| { once!(); Ok({}) })`, `cloudflare-workers/API.md` 10.2) when `LogTrigger.wrote_leaf(res.status())`. Else the result as it is (an `Err` too). The step is
	## after the answer, so its D1 call is not a D1 call of the request (R-AP41) and the answer never waits for R2. A work after the answer that the route has already (the cache drop of
	## R-AP69) stays: two `after` calls run both works, in order.
	with_step : Try(Response, e) -> Try(Response, e)
	with_step = |result| match result {
		Ok(res) if LogTrigger.wrote_leaf(res.status()) => {
			work! = || {
				once!()
				Ok({})
			}
			Ok(res.after(work!))
		}
		other => other
	}

	db = D1.binding("DB")

	## The key of `LOG_KEY` (header row 1): its name (the origin), its key id, and the imported key that signs.
	Signer : { name : Str, key_id : List(U8), key : WebCrypto.Key }

	## The checkpoint in R2 (header row 2): its size, its root, and the condition of the write of the next checkpoint.
	Current : { size : U64, root : List(U8), cond : R2.Cond }

	## Header row 1: the key check. No R2 or D1 call before it.
	signer! : () => Try(LogWriter.Signer, [Fault(Str)])
	signer! = || {
		secret = Env.secret!("LOG_KEY").map_err(|_| Fault("the setting LOG_KEY is missing"))?
		parsed = Tlog.parse_signer_key(secret.reveal()).map_err(|_| Fault("LOG_KEY is not a signer key text"))?
		key = WebCrypto.import_key!(Ed25519, Pkcs8(Tlog.pkcs8(parsed.seed))).map_err(|e| Fault("LOG_KEY import failed: ${Str.inspect(e)}"))?
		exported = WebCrypto.export_key!(key, Jwk).map_err(|e| Fault("LOG_KEY export failed: ${Str.inspect(e)}"))?
		jwk = match exported {
			Jwk(text) => text
			_ => return Err(Fault("LOG_KEY export gave no JWK"))
		}
		public = LogStep.public_key(jwk).map_err(|_| Fault("LOG_KEY export gave no public key"))?
		LogStep.check_key(parsed, public).map_err(|_| Fault("the key id of LOG_KEY is not the key id of its key"))?
		Ok({ name: parsed.name, key_id: parsed.key_id, key })
	}

	## Header row 2: the checkpoint. None: the size 0 and the condition `R2.absent`.
	current! : Str => Try(LogWriter.Current, [Fault(Str)])
	current! = |origin| match R2.get!(log, LogStep.checkpoint_key) {
		Err(NotFound) => Ok({ size: 0, root: [], cond: R2.absent })
		Err(e) => Err(Fault("the checkpoint read failed: ${Str.inspect(e)}"))
		Ok(obj) => {
			text = obj.body.text!().map_err(|e| Fault("the checkpoint read failed: ${Str.inspect(e)}"))?
			cp = Tlog.parse_checkpoint(origin, text).map_err(|_| Fault("the checkpoint in R2 does not parse"))?
			Ok({ size: cp.size, root: cp.root, cond: { etag_matches: obj.meta.etag } })
		}
	}

	## Header row 3: the partial tiles of the size S, in one crossing. A missing tile is a fault.
	edge! : U64 => Try(List(Tlog.TileBytes), [Fault(Str)])
	edge! = |size| {
		tiles = Tlog.edge(size)
		results = Io.all!(tiles.map(|t| R2.get(log, Tlog.path(t))))
		var $out = []
		for pair in tiles.map2(results, |t, r| (t, r)) {
			(tile, result) = pair
			obj = match result {
				Ok(o) => o
				Err(NotFound) => return Err(Fault("the tile ${Tlog.path(tile)} of size ${size.to_str()} is missing"))
				Err(e) => return Err(Fault("the tile read failed: ${Str.inspect(e)}"))
			}
			bytes = obj.body.bytes!().map_err(|e| Fault("the tile read failed: ${Str.inspect(e)}"))?
			$out = $out.append({ tile, bytes })
		}
		Ok($out)
	}

	## Header rows 2 to 7. `retried`: this is the one more step after a lost compare and swap with a smaller checkpoint (Q257-18).
	step_once! : LogWriter.Signer, Bool => Try(LogStep.Outcome, [Fault(Str)])
	step_once! = |signer, retried| {
		cur = current!(signer.name)?
		old = cur.size
		edges = edge!(old)?
		read : Try(List(LogStep.Row), _)
		read = db.all!("SELECT idx, grp, version, hash, time FROM log WHERE idx > ?1 ORDER BY idx LIMIT ?2", (old, LogStep.cap))
		rows = read.map_err(|e| Fault("the leaf read failed: ${Str.inspect(e)}"))?
		entries = match LogStep.entries(old, rows) {
			Ok(list) => list
			Err(Gap(idx)) => return Err(Fault("the leaf idx ${idx.to_str()} is not the next leaf after ${old.to_str()}"))
			Err(TooMany) => return Err(Fault("the leaf read gave more than the cap"))
		}
		if entries.is_empty() {
			return Ok(Same(old))
		}
		size = old + entries.len()
		grown = Tlog.grow(old, edges, entries).map_err(|e| Fault("the tiles of size ${old.to_str()} are bad: ${Str.inspect(e)}"))?
		if old > 0 and grown.old_root != cur.root {
			return Err(Fault("the root of the tiles of size ${old.to_str()} is not the root of the checkpoint"))
		}
		puts = Io.all!(grown.tiles.map(|t| R2.put_with(log, Tlog.path(t.tile), Bytes(t.bytes), { http: { content_type: LogStep.content_type(Tlog.path(t.tile)) } })))
		for put in puts {
			match put {
				Ok(_) => {}
				Err(e) => return Err(Fault("a tile put failed: ${Str.inspect(e)}"))
			}
		}
		body = Tlog.checkpoint_body(signer.name, size, grown.root)
		signature = WebCrypto.sign!({ alg: Ed25519, key: signer.key, data: body.to_utf8() }).map_err(|e| Fault("the checkpoint sign failed: ${Str.inspect(e)}"))?
		note = Tlog.signed_note(body, signer.name, signer.key_id, signature)
		written = R2.put_with!(log, LogStep.checkpoint_key, Text(note), { only_if: cur.cond, http: { content_type: LogStep.content_type(LogStep.checkpoint_key) } })
		match written {
			Ok(_) => Ok(Wrote({ from: old, size, tiles: grown.tiles.len() }))
			Err(PreconditionFailed) => {
				again = current!(signer.name)?
				if LogStep.stop_after_race(again.size, size) or retried {
					Ok(Lost({ size, theirs: again.size }))
				} else {
					step_once!(signer, Bool.True)
				}
			}
			Err(e) => Err(Fault("the checkpoint put failed: ${Str.inspect(e)}"))
		}
	}
}
