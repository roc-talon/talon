## The archive read of a package asset (Registry R-PU38, slice 111): the effects. The decisions are in `lib/ArchiveRead.roc` (pure, W0).
## Slice 112 (ingest) calls `read!`. This slice has no route: the W2 cases (`worker/tests/cases/archive/`) run the test app `archive-test.roc`, which calls `read!`.
##
## `read!(url, hash)` flow. `hash` is the hash of the URL (Design 2; slice 112 has the URL rules). No D1 call, no write.
## 1. One `Http.open!` of `Request.get(url)` with the header `user-agent: talon-registry` (the body stays a stream; `fetch` follows the 302 of a GitHub
##    release download). No answer (`Err(Infra(_))`) is `Upstream(NoAnswer)`. A status other than 200 is `Upstream(Status(status))`: no body read.
## 2. `ArchiveRead.check_length(res.header("content-length"))` before any body read (row 2). A refusal is `Refused`, with no body read.
## 3. `Native.Blake3.new!()` and `Native.ZstdStream.open!()` (the default window limit, 8 MiB, row 3; `open_with!` is not used). An error is `Fault`.
## 4. Loop on `res.body().chunk!()`, with `state = ArchiveRead.empty()`:
##    a. `Chunk(c)`: `ArchiveRead.count(state, c.len())` first. `Err(refusal)` is `Refused(refusal)` at once: no more read, no hash (the stream can be endless).
##    b. `Native.Blake3.update!(b3, c)` for each chunk (row 4: the hash reads to the end, also after the tar end and after a refusal).
##    c. Only while `ArchiveRead.reading(state)`: `Native.ZstdStream.push!(z, c)`. `Ok(out)` goes to `ArchiveRead.push`. A zstd error of the tags of
##       `unzip_failed` goes to `ArchiveRead.unzip_failed`. `BadHandle` and `WrongTask` are `Fault`.
##    d. `End` ends the loop. `Err(BodyErr(_))` is `Upstream(BodyRead)`.
## 5. `Native.ZstdStream.close!(z)` always (it frees the stream). While `reading`, its zstd error goes to `unzip_failed` (an empty or cut stream is `Truncated`).
## 6. `Native.Blake3.final!(b3)`, then `ArchiveRead.finish(state, digest, hash)`. Its `Err` is `Refused`.
import pf.Http
import pf.Request
import pf.Response
import pf.Native
import lib.ArchiveRead
import records.Artifact

Archive :: [].{

	## The error of `read!`. `Refused`: the asset is not a candidate (the problem is `ArchiveRead.problem`). `Upstream`: the asset read failed
	## (`ArchiveRead.upstream_problem`). `Fault`: a fault of the Worker (500 `internal`).
	Error : [Refused(ArchiveRead.Refusal), Upstream([Status(U16), NoAnswer, BodyRead]), Fault(Str)]

	read! : Str, Str => Try(Artifact.Row, Archive.Error)
	read! = |url, hash| {
		res = match Http.open!(Request.get(url).with_header("user-agent", "talon-registry")) {
			Ok(r) => r
			Err(_) => return Err(Upstream(NoAnswer))
		}
		if res.status() != 200 {
			return Err(Upstream(Status(res.status())))
		}
		ArchiveRead.check_length(res.header("content-length")).map_err(|r| Refused(r))?
		b3 = Native.Blake3.new!().map_err(|e| Fault(Str.inspect(e)))?
		z = Native.ZstdStream.open!().map_err(|e| Fault(Str.inspect(e)))?
		body = res.body()
		var $s = ArchiveRead.empty()
		var $more = Bool.True
		while $more {
			match body.chunk!() {
				Ok(Chunk(c)) => {
					$s = $s.count(c.len()).map_err(|r| Refused(r))?
					Native.Blake3.update!(b3, c).map_err(|e| Fault(Str.inspect(e)))?
					if $s.reading() {
						match Native.ZstdStream.push!(z, c) {
							Ok(out) => {
								$s = $s.push(out)
							}

							Err(BadHandle) => return Err(Fault("zstd handle"))
							Err(WrongTask) => return Err(Fault("zstd task"))
							Err(OutputLimit) => { $s = $s.unzip_failed(OutputLimit) }
							Err(WindowTooLarge) => { $s = $s.unzip_failed(WindowTooLarge) }
							Err(BadFrame) => { $s = $s.unzip_failed(BadFrame) }
							Err(Truncated) => { $s = $s.unzip_failed(Truncated) }
							Err(Unsupported) => { $s = $s.unzip_failed(Unsupported) }
						}
					}
				}

				Ok(End) => {
					$more = Bool.False
				}

				Err(_) => return Err(Upstream(BodyRead))
			}
		}
		closed = Native.ZstdStream.close!(z)
		if $s.reading() {
			match closed {
				Ok(_) => {}
				Err(OutputLimit) => { $s = $s.unzip_failed(OutputLimit) }
				Err(WindowTooLarge) => { $s = $s.unzip_failed(WindowTooLarge) }
				Err(BadFrame) => { $s = $s.unzip_failed(BadFrame) }
				Err(Truncated) => { $s = $s.unzip_failed(Truncated) }
				Err(Unsupported) => { $s = $s.unzip_failed(Unsupported) }
				Err(_) => return Err(Fault("zstd close"))
			}
		}
		digest = Native.Blake3.final!(b3).map_err(|e| Fault(Str.inspect(e)))?
		$s.finish(digest, hash).map_err(|r| Refused(r))
	}
}
