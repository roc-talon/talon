import records.Closure as Wire
import Age
import Fail
import Ident
import Pin

## The body of `POST /v1/closure` from the resolve request (slice 205, Registry 4.1, R-AP16, R-AP60, R-AP61; CLI 7.3, R-DI1; Design 4.1, R-ID7). Pure.
## The type of the body is `records.Closure.Request` (R-PK7). The client limits (R-AP46, R-AP78) are `check` and `check_shorts`: the flow counts and calls them before the send.
ClosureRequest :: [].{

	## One group of the request, as `Wire.GroupQuery`: `group` is the URL form (R-AP15), `series` and `range` are optional. `range` is one text in the form of `talon.toml` (how a variable with 2 or more ranges gives one text is question Q2).
	Group : { group : Str, series : Try(Str, [None]), range : Try(Str, [None]) }

	## One row of the compiler list of the registry (R-AP5, R-RE4): the tag, the GitHub `published_at` in seconds (R-DI10) and the log index (R-AP19).
	Row : { id : Str, published_at : U64, log_index : U64 }

	## The `snapshot` of the run for compilers (R-C7, R-DT3, R-DT4): the time form hides a compiler that is published after it, the log form hides a row with a log index above N.
	Snapshot : [None, Time(U64), Log(U64)]

	## What decides the domain of a free compiler (R-NS3): `rows` are the compiler list (nightlies only, R-AP57 step 1). `nightly` is the switch (R-NS1, R-NS8: the result of `Pin.switch`). `req` is the text of the `[toolchain] roc` range (R-NS7, checked at load: `Pin.parse_req` reads it). `now`, `min_age` (seconds) and `exclude` (R-C15 patterns) are for `min-release-age` (R-C7).
	Domain : { rows : List(ClosureRequest.Row), nightly : Bool, req : Try(Str, [Unset]), now : U64, min_age : U64, exclude : List(Str), snapshot : ClosureRequest.Snapshot }

	## The window W (R-AP16 `compilers`). `Held(id)`: the `roc:` pin is held (Resolution 9, R-RP2): `from` = `to` = `id`, as it is in the header (a release or a nightly that the registry does not list too, R-AP60). `Free(domain)`: the oldest and the newest compiler of the domain.
	## `None`: no window (`tln probe --range`).
	Window : [None, Held(Str), Free(ClosureRequest.Domain)]

	## The facts of the first query. `groups` are in the order that the caller gives (the order of the variables). `entries` are the values of the header entries (Design 4.2): a release URL, a path, or another text.
	Facts : { groups : List(ClosureRequest.Group), entries : List(Str), window : ClosureRequest.Window }

	## R-AP16, R-ID7, R-DI1: the request. `groups`: as given, with the members of `Group`. `hashes`: the hash of each entry that is a release URL (`Ident.of_url`), in the order of `entries`, with no other change (a repeated hash is repeated: the Worker reads it once, R-AP59). An entry that is a path or a URL that has no hash (`Foreign`) gives no hash.
	## `compilers` (R-AP16, R-AP60, R-AP61):
	##
	## | `window` | `compilers` |
	## | --- | --- |
	## | `None` | `Err(None)` (no member) |
	## | `Held(id)` | `Ok({ from: Ok(id), to: Ok(id) })` |
	## | `Free(domain)` | `Ok({ from: Ok(oldest), to: Ok(newest) })` of the compilers that stay (below). No compiler stays: `Err(NoCompiler)` (R-AP61: the client has no compiler to ask for; what it sends then is question Q3). |
	##
	## The compilers that stay, in the order of R-NS1 (`Pin.order` with the `published_at` of the rows): a row stays when
	## all hold: (1) a nightly tag (`Pin.is_nightly`) only when `nightly` is true (the list has nightlies only, R-AP57 step 1: with the switch off nothing stays, R-NS2); (2) `req` is `Err(Unset)` or `Pin.admits` it (R-NS7);
	## (3) it is not hidden by `min_age` and `exclude` (`Age.hides`, R-C7, R-C15); (4) the `snapshot` allows it: `Time(t)`: `published_at <= t`; `Log(n)`: `log_index <= n`; `None`: always.
	request : ClosureRequest.Facts -> Try(Wire.Request, [NoCompiler])
	request = |facts| {
		compilers = ClosureRequest.window_of(facts.window)?
		hashes = facts.entries.keep_oks(|entry| Ident.of_url(entry).map_ok(|ident| ident.hash))
		Ok({ groups: facts.groups, hashes, compilers })
	}

	window_of : ClosureRequest.Window -> Try(Try(Wire.Window, [None]), [NoCompiler])
	window_of = |window| match window {
		None => Ok(Err(None))
		Held(id) => Ok(Ok({ from: Ok(id), to: Ok(id) }))
		Free(domain) => {
			ends = ClosureRequest.ends(ClosureRequest.staying(domain), domain.rows)?
			Ok(Ok({ from: Ok(ends.oldest), to: Ok(ends.newest) }))
		}
	}

	## The rows that stay in the domain.
	staying : ClosureRequest.Domain -> List(ClosureRequest.Row)
	staying = |domain| {
		times = domain.rows.map(|r| { id: r.id, published_at: r.published_at })
		req = match domain.req {
			Err(Unset) => Ok(Any)
			Ok(text) => Pin.parse_req(text)
		}
		match req {
			Err(BadReq) => []
			Ok(parsed) => domain.rows.keep_if(
				|r| (!Pin.is_nightly(r.id) or domain.nightly)
					and Pin.admits({ req: parsed, id: r.id, times })
						and !Age.hides({ now: domain.now, min_age: domain.min_age, published_at: r.published_at, exclude: domain.exclude, name: Ok(Age.compiler_name(r.id)) })
							and ClosureRequest.allowed(domain.snapshot, r),
			)
		}
	}

	allowed : ClosureRequest.Snapshot, ClosureRequest.Row -> Bool
	allowed = |snapshot, row| match snapshot {
		None => Bool.True
		Time(t) => row.published_at <= t
		Log(n) => row.log_index <= n
	}

	## The oldest and the newest of the rows, by `Pin.order` (R-NS1).
	ends : List(ClosureRequest.Row), List(ClosureRequest.Row) -> Try({ oldest : Str, newest : Str }, [NoCompiler])
	ends = |kept, all| match kept {
		[] => Err(NoCompiler)
		[first, .. as rest] => {
			times = all.map(|r| { id: r.id, published_at: r.published_at })
			ordered = |a, b| Pin.order({ a, b, times })
			Ok(
				rest.fold(
					{ oldest: first.id, newest: first.id },
					|acc, r| {
						oldest = if ordered(r.id, acc.oldest) == Before r.id else acc.oldest
						newest = if ordered(r.id, acc.newest) == After r.id else acc.newest
						{ oldest, newest }
					},
				),
			)
		}
	}

	## The JSON text of `request` (`records.Closure.encode_request`).
	body : ClosureRequest.Facts -> Try(Str, [NoCompiler])
	body = |facts| ClosureRequest.request(facts).map_ok(Wire.encode_request)

	## R-AP78, R-AP46: the limits of a closure query, checked before the send. A request is never split. The counts are those of the request (`groups`, `hashes`) and the byte length of its body text. The checks run in this order: the body (262144 bytes), `groups` (300), `hashes` (1000). A count at the limit is valid.
	## Over a limit: `Err` with kind `Internal` (exit 1) and the message `the closure query has <count> <item>, over the limit of <limit>: the project is past what Talon supports now`, with `<item>` = `bytes`, `groups` or `hashes` (a proposal, R-OUT2).
	check : { groups : U64, hashes : U64, bytes : U64 } -> Try({}, Fail)
	check = |counts| {
		over = |item, count, limit| Err(Fail.new(Internal, "the closure query has ${count.to_str()} ${item}, over the limit of ${limit.to_str()}: the project is past what Talon supports now"))
		if counts.bytes > 262144.U64 {
			over("bytes", counts.bytes, 262144.U64)
		} else if counts.groups > 300 {
			over("groups", counts.groups, 300.U64)
		} else if counts.hashes > 1000 {
			over("hashes", counts.hashes, 1000.U64)
		} else {
			Ok({})
		}
	}

	## R-AP78, R-AP46, R-SN1: more than 50 short names in one command (a count of 50 is valid): `Err` with kind `Usage` (exit 2) and the message `<count> short names are over the limit of 50: use full names (owner/repo) or run 2 commands` (a proposal). Slice 211 calls it.
	check_shorts : U64 -> Try({}, Fail)
	check_shorts = |count| if count > 50 {
		Err(Fail.new(Usage, "${count.to_str()} short names are over the limit of 50: use full names (owner/repo) or run 2 commands"))
	} else {
		Ok({})
	}
}
