app [event!] {
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.2/f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd.tar.zst",
	tar: "https://github.com/Karakatiza666/roc-tar/releases/download/0.0.1/FGAUE1Pds7Fvd48GkrAYd9rRUpztew8bgUZjUrKPGyo7.tar.zst",
	header: "https://github.com/Karakatiza666/roc-app-header/releases/download/0.1.0/HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU.tar.zst",
}

## Probe of slice 111: Http.open! of a URL, Body.chunk!, BLAKE3, zstd, roc-tar, roc-app-header on the worker nightly.
import pf.Worker
import pf.Request
import pf.Response
import pf.Http
import pf.Native
import tar.Tar
import header.Header

fetch! : Request => Try(Response, _)
fetch! = |req| match run!(req) {
	Ok(text) => Ok(Response.from_text(200, text))
	Err(e) => Ok(Response.from_text(500, Str.inspect(e)))
}

run! : Request => Try(Str, _)
run! = |req| {
	url = req.query("url") ?? "https://github.com/x"
	res = Http.open!(Request.get(url))?
	cl = res.header("content-length") ?? "none"
	b3 = Native.Blake3.new!()?
	z = Native.ZstdStream.open!()?
	var $t = Tar.new(Tar.Limits.{ max_path_bytes: 255 })
	var $n = 0.U64
	var $chunks = 0.U64
	var $header = []
	var $paths = []
	var $err = ""
	var $more = Bool.True
	while $more {
		match res.body().chunk!() {
			Ok(Chunk(c)) => {
				$n = $n + c.len()
				$chunks = $chunks + 1
				Native.Blake3.update!(b3, c)?
				if $err == "" {
					match Native.ZstdStream.push!(z, c) {
						Ok(out) => match $t.push(out, choose) {
							Ok((t2, events)) => {
								$t = t2
								for e in events {
									match e {
										Entry(entry) => {
											$paths = $paths.append(entry.path)
										}

										Content(_, data) => {
											$header = data
										}
									}
								}
							}

							Err(e) => {
								$err = Tar.err_to_str(e)
							}
						}

						Err(e) => {
							$err = Str.inspect(e)
						}
					}
				}
			}

			Ok(End) => {
				$more = Bool.False
			}

			Err(e) => {
				$err = Str.inspect(e)
				$more = Bool.False
			}
		}
	}
	digest = Native.Blake3.final!(b3)?
	closed = Str.inspect(Native.ZstdStream.close!(z))
	kind = match Str.from_utf8($header) {
		Ok(text) => match Header.parse(text) {
			Ok(h) => Str.inspect(h.kind())
			Err(e) => Str.inspect(e)
		}

		Err(_) => "not utf8"
	}
	Ok(("status=${res.status().to_str()} cl=${cl} n=${$n.to_str()} chunks=${$chunks.to_str()} paths=${$paths.len().to_str()} header=${$header.len().to_str()} err=${$err} close=${closed} kind=${kind} b3=${Str.inspect(digest.take_first(4))}"))
}

choose : Tar.Entry -> Tar.Action
choose = |e| if (e.path == "main.roc") Collect(1048576) else Skip

worker = Worker.new({ fetch!: fetch! })

event! = |e| worker.event!(e)
