# The 1.25 MB function in worker/app.wasm

Question: which Roc code makes the function of 1,246,912 bytes in `worker/app.wasm` (wasm function 186, imports counted), and can a change in our Roc code split it?

## Result

| Item | Finding |
| --- | --- |
| What the function is | `roc_event` (`event_for_host!`, cloudflare-workers/platform/main.roc:69): `Entry.event`, `Worker.event!`, the `own!` closure of `Worker.new`, and all of our `fetch!` path (main.roc `fetch!`, `Route.decide`, `run!`, the inlined routes `ReadRoutes`, `ShortRoutes`, `Auth`, ...) in one body. Its only caller is the 73-byte function 1860 (`handle`). |
| Main cause (6x) | `Worker.event!` (cloudflare-workers/platform/Worker.roc:223-227) has the arm `Fetch(_) \| Scheduled(_) \| Queue(_) \| Email(_) \| Tail(_) \| Other(_) => own!(ev)`. The compiler makes one copy of the arm body, with all of `own!` and so all of `fetch!`, for each of the 6 alternatives. |
| Second cause (38 copies) | `problem_response` (worker/main.roc:108-109, with `Problem.to_json`, worker/lib/Problem.roc:121-127) is inlined once for each `read_answer(...)` arm of `run!` (worker/main.roc:125-149) and for each `Err(Refuse(..))` site in the inlined routes: 38 copies of about 1.8 KB in each of the 6 copies, 228 in all. |
| Compiler or our code | The 6x is compiler behavior (an or-pattern arm is copied per alternative), set off by platform code. The same source with a wildcard arm in place of the or-pattern has no copies (table 3). Our code can avoid it (proposal A). |
| Measured effect (proposal A + B) | The entry function goes from 1,246,912 to 178,393 bytes; V8 Liftoff compile of it from 26.8 ms to 2.7 ms on this machine; the code section from 6.27 MB to 5.19 MB. W2: 182 of 189 pass, the same as before (the 7 `archive/` cases need `archive-test.wasm`, which this run did not have). |

## 1. Method

1. Static scan (`wasmscan.mjs`): decode each instruction of the function body (MVP, bulk memory and SIMD opcodes), collect the `i32.const` values that point into a data segment, and print the text there. Modes: `strings` (count per address), `calls`, `callers`, `pos` (offsets of one constant), `map` (texts per window of N bytes), `dump` (calls and texts in a byte range).
2. Build variants (`count.sh <variant dir>`): build with the nightly of the repo, print the 3 largest functions, and count the copies of the `Problem.title` table in the largest function (`titles.mjs`: the `i32.const` values that point at the text `Unauthenticated`).
3. Small apps on the same platform (`variants/mini*`, 8 to 20 s for each build) to isolate each cause. Then 2 builds of the full Worker (`variants/bp`, `variants/bpone`, about 3 minutes each).
4. `fntime.sh`: the V8 compile time of the largest functions (`--trace-wasm-compilation-times`, eager, one thread, Liftoff and TurboFan).
5. W2 (`worker/tests/run.mjs` with `W2_DIR` set to a copy dir with the variant `app.wasm` and a copy of `worker/.roc-cfw/`).

`variants/base` is a copy of `worker/` (not kept in git). Its build is byte-identical to `worker/app.wasm`, so the builds are reproducible.

## 2. Evidence: the strings in function 186

`node wasmscan.mjs ../../worker/app.wasm big strings` (count = number of `i32.const` in the body that point at the text):

| Text (start) | Count | Source |
| --- | --- | --- |
| `Entry: a socket error is`, `object event`, `Entry.event: unknown kind` | 1 | platform `Entry.event` (Entry.roc:35-50, 80-120) |
| `Unauthenticated`, `Id collision`, `Rate limited` (the 18 titles), `unauthenticated` (the 18 kebab names) | 228 each | `Problem.title`, `Problem.kebab` in `Problem.to_json` (worker/lib/Problem.roc:40-127) |
| `Internal error` | 244 | the same, plus 16 sites with a fixed `Internal` kind |
| `application/problem+json` | 282 | `problem_response` (worker/main.roc:109) and the routes |
| ` is not allowed on `, `no route for `, `the request body must be application/json` | 108, 18, 60 | `Route.decide` (worker/lib/Route.roc:39-115) |
| `bad program: MIN_TLN_WRITE` | 13 | `client_refusal!` (worker/main.roc:69-79) |
| `the Worker has no consumer for the queue` | 6 | platform `Queue` path in `own!` |
| `WITH page AS (SELECT * FROM releases ...`, `no artifact` | 12, 24 | `ReadRoutes` (inlined) |
| `the query parameter q must not be empty` | 12 | `Shorts` via `ShortRoutes.list!` (inlined) |
| `authorization`, `talon-contributor`, `the Authorization header must be "Bearer <token>"` | 12 to 24 | `Auth` (inlined) |

Texts of `PublishRoutes`, `LoginRoutes`, `WebhookRoutes`, `IngestRoutes` are not in the body: those handlers are separate functions (the body calls 127 different functions).

The `map` mode (texts per 25 KB window) shows 2 regions:

| Offset | Size | Content |
| --- | --- | --- |
| 0 to 50 K | 50 KB | `Entry.event` (the JS event to `Worker.Event`) |
| 50 K to 775 K | 725 KB | the same sequence 6 times: `Route.decide`, `client_refusal!`, `Auth`, `ReadRoutes`, `ShortRoutes`, the queue path |
| 775 K to 1,247 K | 470 KB | about 200 copies, back to back, of the problem answer (the title table, `Json.to_str`, `Response.from_bytes`), about 1.8 KB each (`dump` mode) |

So each text of the fetch path is in the body 6 times (or 6 times the number of its sites in the source). 228 = 6 x 38.

## 3. Evidence: the build variants

Small apps on platform 0.0.7 with `worker/lib/Route.roc` and `worker/lib/Problem.roc`. `mini2` has the shape of worker/main.roc (`fetch!`, `handle!`, `run!` with 17 arms, `read_answer`) with 17 stub handlers; each stub gives `Err(Refuse(problem))` with a kind that is known only at run time.

| Variant | Change from `mini2` | Largest function (bytes) | Title-table copies |
| --- | --- | --- | --- |
| `mini` | only `Route.decide` and `problem_response`, no handlers | 144,938 | 0 (kinds are constants, folded) |
| `mini2` | (none) `event! = \|e\| worker.event!(e)` | 488,466 | 102 = 6 x 17 |
| `mini2k9` | `kind_of` with 9 kinds in place of 5 | 548,366 | 102 |
| `mini2bp` | `event!` sends `Fetch` to `fetch!` itself; `Worker.new` gets a stub `fetch!` | 139,683 | 17 |
| `mini2or` | as `mini2bp`, but `event!` calls `own!(e)` from an arm `Fetch(_) \| Scheduled(_) \| Queue(_) \| Email(_) \| Tail(_) \| Other(_)` | 501,878 | 102 |
| `mini2wild` | as `mini2or`, but the 4 other kinds come first and the `own!(e)` arm is `_` | 165,808 | 17 |
| `mini2one` | as `mini2wild`, and `run!` gives `Refuse` up; `handle!` calls `read_answer` once | 133,503 | 1 |

`mini2or` and `mini2wild` differ only in the form of one match arm. That is the smallest evidence for the 6x.

The full Worker (`--opt=speed`, nightly-2026-10-31-f7bef6b):

| Variant | Change (worker/main.roc only) | Entry function (bytes) | Title copies | Largest function | Code section | wasm file |
| --- | --- | --- | --- | --- | --- | --- |
| `base` (= worker/app.wasm) | none | 1,246,912 | 228 | the entry | 6,270,963 | 6,361,855 |
| `bp` | proposal A | 284,449 | 39 | the entry | 5,298,509 | 5,389,413 |
| `bpone` | proposal A + B | 178,393 | 3 | 242,991 (another function, unchanged) | 5,192,453 | 5,283,357 |

V8 compile time of the entry function (this machine, one thread, `fntime.sh`):

| Variant | Liftoff | TurboFan | Liftoff machine code |
| --- | --- | --- | --- |
| `base` | 26.8 ms | 702 ms | 2.40 MB |
| `bp` | 5.6 ms | 148 ms | 0.56 MB |
| `bpone` | 2.7 ms | 80 ms | 0.36 MB |

The Workers profile gave 39 ms for this function at the first call. If the time is in proportion to the Liftoff time here, the first call costs about 4 ms with A + B: about 35 ms less CPU on a cold first request. Measure it on a deploy to be sure.

The `--opt=size` build (research/deploy-121/startup/size/app.wasm) also has 228 title copies in a function of 1,170,718 bytes. So the copies are not from the inlining of the speed mode.

Not reproduced: a headerless native program with the same or-pattern shape (`orpat/rec-or.roc` against `orpat/rec-wild.roc`, also `or.roc`, `wild.roc`, `*-fx.roc`) has the same text size for both forms. So the trigger needs more than the or-pattern alone (possibly the platform types, the `=>` closure in a record, or the wasm32 target). The smallest evidence for an upstream report is `variants/mini2or` against `variants/mini2wild` (one app file each, the platform by URL).

`--specialize=no` (boxy lowering) crashes the compiler on this app (`Segmentation fault ... post-check boxy_plan`), so it could not be compared.

## 4. Proposal

A and B change only worker/main.roc. C is a change to the platform (a separate repo, for its owner).

### A. Send the fetch event to `fetch!` in `event!`, not through `Worker.event!` (6x to 1x)

```roc
worker = Worker.new({ fetch!: fetch_stub!, scheduled!: ..., ... })

event! = |e| match e {
	Fetch(req) => fetch_outcome!(req)
	_ => worker.event!(e)
}

## The same outcome as the `own!` of `Worker.new` gives for a fetch (Worker.roc:57-63).
fetch_outcome! : Request => Worker.Outcome
fetch_outcome! = |req| match fetch!(req) {
	Ok(res) => Respond(res)
	Err(x) => Failed(Str.inspect(x))
}

## Given to `Worker.new` so that the manifest lists `fetch`. A fetch event never gets to it.
fetch_stub! : Request => Try(Response, [NotUsed])
fetch_stub! = |_req| Ok(Response.from_bytes(500, "text/plain", "not used".to_utf8()))
```

The full text is `variants/bp/main.roc`. The manifest, `on_trap`, crons and the queue do not change. The compiler gives a warning: the `Err(x)` arm cannot match, because `fetch!` never gives `Err` (`handle!` changes each `Err` to a 500). The review can keep the arm (it is what `own!` does) or remove it.

Effect: entry function 1,246,912 to 284,449 bytes.

Risk: the stub is dead code that the reader must understand. When the platform gets fix C, remove A.

### B. One `read_answer` site (38 copies to 1)

`run!` gives `Try(Response, ReadRoutes.Error)` (the arms call the handler with no `read_answer`), the `PutToolchain` arm gives `Err(Refuse(problem))` for a failed bot check, and `handle!` does `match read_answer(run!(id, req))`. The answers do not change. Full text: `variants/bpone/main.roc` (A + B).

Effect: entry function 284,449 to 178,393 bytes. It is then not the largest function (function 377, 242,991 bytes, has no data texts and was already there; not examined).

### C. Platform: no or-pattern in `Worker.event!` (for the owner of cloudflare-workers)

Put the 4 specific arms first and make the `own!` arm a wildcard:

```roc
event! = |w, ev| match ev {
	Rpc({ entrypoint, method, arg }) => ...
	EntrypointFetch({ entrypoint, request }) => ...
	Object({ class, id, event }) => ...
	Manifest => Reply(manifest(w))
	_ => {
		own! = w.own!
		own!(ev)
	}
}
```

`variants/mini2wild` shows that this form has no copies. This removes the 6x for each app, and the scheduled and queue paths too (they are still copied 6 times inside `Worker.event!` with A). With C, A is not necessary.

### Upstream (Roc compiler)

A report can say: "a `match` arm with an or-pattern of N tag alternatives is lowered as N copies of the arm body, also when the pattern binds nothing; with a large inlined callee in the arm this makes the function N times larger (`--opt=speed` and `--opt=size`, wasm32)". Repro: `variants/mini2or/main.roc` against `variants/mini2wild/main.roc` (largest function 501,878 against 165,808 bytes). The native repro in `orpat/` did not show it, so the report must use the wasm32 app.

## 5. What is left

| Item | Note |
| --- | --- |
| The fetch path is 2 times in the entry function of `bp` (for example `WITH page AS ... repo` 2 times, `bad program: MIN_TLN_WRITE` 3 times) | Not examined. A possible cause is the same kind of copy for a match whose arms call the same function (for example `body_present!`, worker/main.roc:89-96). |
| Function 377 (242,991 bytes) | No data texts; 2 callers. Not examined. It is compiled only when it is called. |
| Cold-request CPU on Workers | Not measured (no deploy in this task). |

## 6. Files

| File | Purpose |
| --- | --- |
| `wasmscan.mjs` | the static scan of one function (modes in section 1) |
| `titles.mjs` | the title-table copies in the largest function |
| `count.sh` | build a variant and print the sizes and the copies (`NOBUILD=1` for a wasm that is already built) |
| `fntime.sh` | V8 compile time of the 3 largest functions |
| `compiletime.mjs` | V8 compile time of the whole module |
| `rocstr.mjs` | decode the 12-byte `RocStr` records in the data |
| `variants/mini*` | the small apps of table 3 |
| `variants/bp/main.roc`, `variants/bpone/main.roc` | proposal A, and A + B (the other files of these dirs are copies of `worker/`, not kept) |
| `orpat/` | the native repro that did not reproduce |
