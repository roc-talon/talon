# Probe (slice 101): a copy of worker/ with fetch! = Time.now_ms!. With worker/tests/run.mjs (W2_DIR=this dir) and a request {"now": 1790000000000}, the answer is 1790000000000: Time.now_ms! reads the Date.now() that worker/tests/clock.js sets. The shim option `now` is not needed.
app [event!] {
	lib: "lib/main.roc",
	pf: platform "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.2/f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd.tar.zst",
	roc: "nightly-2026-10-31-f7bef6b",
}

## The registry Worker (Registry 4 to 8). Slice 101 is the skeleton: the entry, the router, the problem form.
## Slice 101 stub. The code agent writes the bodies (docs/slices/101-worker-skeleton.md section 3).
import pf.Worker
import pf.Request
import pf.Response
import pf.D1
import pf.Queue
import pf.Time
import lib.Problem
import lib.Route

db = D1.binding("DB")

fetch! : Request => Try(Response, _)
fetch! = |_req| Ok(Response.from_text(200, Time.now_ms!().to_str()))

scheduled! : Worker.Scheduled => Try({}, _)
scheduled! = |_s| crash "todo"

queue! : Queue.Batch => Try({}, _)
queue! = |_b| crash "todo"

worker = Worker.new({ fetch!: fetch!, scheduled!: scheduled!, queue!: queue!, bindings: [db.declare()] })

event! = |e| worker.event!(e)
