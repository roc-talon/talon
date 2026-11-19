## PRIVATE REFERENCE of slice 257d (the test agent's). Not the code of the code agent.
import pf.Request
import pf.Response
import pf.R2
import pf.Cache
import lib.LogPath
import lib.Problem
import lib.Reads
import ReadRoutes
import LogWriter

LogRoutes :: [].{

	get! : Request, Str => Try(Response, ReadRoutes.Error)
	get! = |req, key| match LogPath.parse(key.split_on("/")) {
		Err(BadPath) => Err(Refuse(Problem.new(NotFound, "no log object ${key}")))
		Ok(target) => serve!(req, key, target)
	}

	serve! : Request, Str, LogPath.Target => Try(Response, ReadRoutes.Error)
	serve! = |req, key, target| {
		cc = LogPath.cache_control(target)
		cache_key = req.url().split_on("?").first() ?? ""
		if_none_match = req.header("if-none-match")
		cached = if LogPath.in_cache_api(target) Cache.default.get!(cache_key) else Err(NotFound)
		match cached {
			Ok(hit) => Ok(answer_hit(hit, if_none_match, cc))
			Err(_) => {
				obj = match LogWriter.log.get!(key) {
					Ok(o) => o
					Err(NotFound) => return Err(Refuse(Problem.new(NotFound, "no log object ${key}")))
					Err(Infra(e)) => return Err(Fault(Str.inspect(e)))
				}
				etag = obj.meta.http_etag
				if matches(if_none_match, etag) {
					Ok(not_modified(etag, cc))
				} else {
					res = R2.to_response(obj).with_header("cache-control", cc)
					if LogPath.in_cache_api(target) {
						Ok(Cache.default.put!(cache_key, res) ?? res)
					} else {
						Ok(res)
					}
				}
			}
		}
	}

	answer_hit : Response, Try(Str, [NotFound]), Str -> Response
	answer_hit = |hit, if_none_match, cc| match hit.header("etag") {
		Ok(etag) => if (matches(if_none_match, etag)) not_modified(etag, cc) else hit
		Err(NotFound) => hit
	}

	matches : Try(Str, [NotFound]), Str -> Bool
	matches = |if_none_match, etag| match if_none_match {
		Ok(text) => Reads.etag_matches(text, etag)
		Err(NotFound) => Bool.False
	}

	not_modified : Str, Str -> Response
	not_modified = |etag, cc| Response.from_status(304).with_header("etag", etag).with_header("cache-control", cc)
}
