app [event!] {
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.2/f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd.tar.zst",
	semver: "https://github.com/Karakatiza666/roc-semver/releases/download/0.1.0/KFKmXaroJeaPkQmAaqm83fTP9yhnEkTQwE97a5BtFSX.tar.zst",
	base58: "https://github.com/Karakatiza666/roc-base58/releases/download/0.1.0/BgUuQGqWY94NikfEx4rBkWkgxYhngMim3ZEnD8wpM4NS.tar.zst",
	hdr: "https://github.com/Karakatiza666/roc-app-header/releases/download/0.1.0/HDQnwrX2Bcm8Jsf8RMC9ZdbVGwPiqD2nCLP7Zf1osfgU.tar.zst",
	records: "../records/main.roc",
}

## Probe of the registry plan: the 0.0.2 release URL, the generic packages,
## a local Talon package, D1 with a STRICT table and a 64-bit id, BLAKE3.
import pf.Worker
import pf.Request
import pf.Response
import pf.D1
import pf.Sql
import pf.Http
import semver.Semver
import base58.Base58
import hdr.PackageUrl
import records.Problem
import Route

db = D1.binding("DB")

Row : { id : I64, value : Str }

fetch! : Request => Try(Response, _)
fetch! = |req| {
	res = match req.segments() {
		[] => Response.from_text(200, "hello registry")
		["semver", v] => match Semver.parse(v) {
			Ok(s) => Response.from_text(200, s.to_str())
			Err(_) => Response.from_text(400, "bad")
		}
		["b58"] => Response.from_text(200, Base58.encode(Crypto.BLAKE3.hash([1, 2, 3]).to_bytes()))
		["url"] => match PackageUrl.parse(req.query("u") ?? "") {
			Ok(u) => Response.from_text(200, u.url_form())
			Err(_) => Response.from_text(400, "bad url")
		}
		["d1"] => d1!()
		["gh"] => match Http.get!("https://api.github.com/repos/roc-lang/unicode") {
			Ok(r) => Response.from_text(200, "github status ${r.status().to_str()}")
			Err(e) => Response.from_text(502, Str.inspect(e))
		}
		_ => Response.from_text(404, Problem.new("/errors/not-found", "Not Found", 404, "no route").to_json())
	}
	Ok(res)
}

d1! : () => Response
d1! = || {
	rows : Try(List(Row), _)
	rows = db.all!("SELECT CAST(id AS TEXT) AS id, value FROM names ORDER BY id", Sql.none)
	match rows {
		Ok(r) => Response.from_text(200, Str.inspect(r))
		Err(e) => Response.from_text(500, Str.inspect(e))
	}
}

worker = Worker.new({ fetch!: fetch!, bindings: [db.declare()] })

event! = |e| worker.event!(e)
