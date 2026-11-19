## The log read routes (Registry R-AP11, R-AP23, R-AP24, R-AP43; Design Q636, Q257-12, Q257-13; slice 257d, docs/slices/257-log-tiles.md section 3.5).
## The path grammar and the cache headers are in `lib/LogPath.roc` (pure, W0). The route table is `lib/Route.roc` (`decide_log`). This module only orders the effects.
## The tests are W2: `worker/tests/cases/logread/`. Every body is a stub until the code agent writes it (TW18).
##
## The flow of `get!` (`key` is the R2 key, the path after `/log/`. `Route.decide` has checked it with `LogPath.parse`; `get!` splits it at `/` and parses it again for the target):
## 1. A tile (`LogPath.in_cache_api`): the Cache API of the colo first (`Cache.default.get!`, key `req.url()`), a hit is the answer (also for a `HEAD` and for a request with `If-None-Match`:
##    the stored answer has the `etag`). The checkpoint never goes to the Cache API: each read is one R2 read.
## 2. R2: `LogWriter.log`, key `key`, with the conditional headers of the request (`R2.from_headers`): 200 with the body and the `content-type` and `etag` of the object, 304 with the `etag`.
##    No object: `Err(Refuse(Problem.new(NotFound, ..)))` (404 `not-found`, also the checkpoint before the first leaf). A 404 is not put in the Cache API (R-AP43).
## 3. The headers of 200 and 304: `cache-control: LogPath.cache_control(target)`, the `etag`, the `content-type` of the object (R-AP23, slice file P-b1). No `Expires`, no `Set-Cookie`.
## 4. `HEAD`: the same status and headers, no body. `GET` of a tile: the 200 goes in the Cache API.
## 5. R2 fails (`R2Err`): `Err(Fault(text))` (500 `internal`, R-AP48).
import pf.Request
import pf.Response
import pf.R2
import pf.Cache
import LogWriter
import ReadRoutes
import lib.LogPath
import lib.Problem
import lib.Reads

LogRoutes :: [].{

	## `GET` and `HEAD` of `/log/<key>` (R-AP11). `Route.decide` has checked the path and the method, so `key` is the key of a good target; the answers are in the header of this file.
	get! : Request, Str => Try(Response, ReadRoutes.Error)
	get! = |req, key| {
		target = LogPath.parse(key.split_on("/")).map_err(|_| Fault("the log key ${key} is not a log path"))?
		cache_control = LogPath.cache_control(target)
		if_none_match = req.header("if-none-match")
		# The Cache API key has no query (Q257-20): one entry for each tile path.
		cache_key = req.url().split_on("?").first() ?? req.url()
		cached = if (LogPath.in_cache_api(target)) Cache.default.get!(cache_key).map_err(|_| Miss) else Err(Miss)
		match cached {
			Ok(hit) => Ok(answer(hit, if_none_match, cache_control))
			Err(_) => {
				obj = R2.get!(LogWriter.log, key).map_err(
					|e| match e {
						NotFound => Refuse(Problem.new(NotFound, "the log has no object ${key}"))
						_ => Fault("the read of the log object ${key} failed: ${Str.inspect(e)}")
					},
				)?
				res = R2.to_response(obj).with_header("cache-control", cache_control)
				sent = if (LogPath.in_cache_api(target)) (Cache.default.put!(cache_key, res) ?? res) else res
				Ok(answer(sent, if_none_match, cache_control))
			}
		}
	}

	## Step 3: a 304 when `If-None-Match` matches the `etag` of the answer, else the answer (200).
	answer : Response, Try(Str, [NotFound]), Str -> Response
	answer = |res, if_none_match, cache_control| match (res.header("etag"), if_none_match) {
		(Ok(etag), Ok(text)) => if Reads.etag_matches(text, etag) {
			Response.from_status(304).with_header("etag", etag).with_header("cache-control", cache_control)
		} else {
			res
		}
		_ => res
	}
}
