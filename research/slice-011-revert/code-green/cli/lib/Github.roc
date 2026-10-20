import Clock
import Fail
import Fx
import Item
import Net
import Roots
import Text

## The GitHub API as the index (CLI 7.3, R-DI2, R-DI8, R-DI9, R-DI12, R-DI13): the list request, the cache pages in `talon/index/`
## (R-CC11: no lock), the answers that stop a command, and the `.roc-version` hint. `releases!` and `hint!` are command code over `Fx`.
Github :: [].{

	## What the cache knows about one page: the ETag of its last answer and the time of that answer (the modification time of its
	## `meta` file, seconds).
	Cached : { etag : Try(Str, [None]), mtime : U64 }

	## The first request of a repository (R-DI2): `<api>/repos/<owner>/<repo>/releases?per_page=100`. `api` is `Settings.api` of `Net`.
	list_url : { api : Str, owner : Str, repo : Str } -> Str
	list_url = |facts| "${facts.api}/repos/${facts.owner}/${facts.repo}/releases?per_page=100"

	## The URL of the `.roc-version` hint (R-DI8): `<raw>/<owner>/<repo>/<tag>/.roc-version`. `raw` is `Settings.raw` of `Net`.
	hint_url : { raw : Str, owner : Str, repo : Str, tag : Str } -> Str
	hint_url = |facts| "${facts.raw}/${facts.owner}/${facts.repo}/${facts.tag}/.roc-version"

	## The hint in the answer (R-DI8): status 200 gives the first line that is not empty, with the white space cut off (a nightly id, for example
	## `nightly-2026-10-09-258ab27`). A 200 with no such line, and a 404, give `Err(NoHint)`. Any other status is `Err(Failed(status))`.
	hint : { status : U16, body : Str } -> Try(Str, [NoHint, Failed(U16)])
	hint = |facts| match facts.status {
		200 => match facts.body.split_on("\n").map(|line| line.trim()).find_first(|line| !line.is_empty()) {
			Ok(line) => Ok(line)
			Err(NotFound) => Err(NoHint)
		}
		404 => Err(NoHint)
		other => Err(Failed(other))
	}

	## The directory of the cache pages of a repository: `<index>/github/<owner>/<repo>` (R-DI2, CLI 6.1), with `<index>` the path of `Item.Index`.
	repo_dir : { roots : Roots, owner : Str, repo : Str } -> Str
	repo_dir = |facts| Text.join(Roots.item(facts.roots, Item.Index), "github/${facts.owner}/${facts.repo}")

	## The two files of page `n` (1-based) in `dir` (a proposal for the form of the cache, R-OUT2): `<dir>/<n>.json` holds the body of the answer as it came,
	## `<dir>/<n>.meta` holds `meta_text`. Talon writes the body first, then the meta, so a page has an ETag only with its body.
	page_files : { dir : Str, n : U64 } -> { body : Str, meta : Str }
	page_files = |facts| { body: Text.join(facts.dir, "${facts.n.to_str()}.json"), meta: Text.join(facts.dir, "${facts.n.to_str()}.meta") }

	## The text of a `meta` file: the line `etag <ETag>` when there is an ETag, then the line `next <URL>` when the page has a next page (the
	## `rel="next"` link, below). Each line ends with a newline. No ETag and no next page: the empty text.
	meta_text : { etag : Try(Str, [None]), next : Try(Str, [None]) } -> Str
	meta_text = |facts| {
		etag = match facts.etag {
			Ok(e) => "etag ${e}\n"
			Err(None) => ""
		}
		next = match facts.next {
			Ok(url) => "next ${url}\n"
			Err(None) => ""
		}
		"${etag}${next}"
	}

	## The reverse of `meta_text`. A line that is not `etag ...` or `next ...` is ignored.
	parse_meta : Str -> { etag : Try(Str, [None]), next : Try(Str, [None]) }
	parse_meta = |text| text.split_on("\n").fold(
		{ etag: Err(None), next: Err(None) },
		|found, line|
			if line.starts_with("etag ") {
				{ ..found, etag: Ok(line.drop_prefix("etag ")) }
			} else if line.starts_with("next ") {
				{ ..found, next: Ok(line.drop_prefix("next ")) }
			} else {
				found
			},
	)

	## The URL of the next page (R-DI2) from the response headers: the `Link` header (the name in any case) holds links `<url>; rel="next"`, split by commas.
	## The `rel="next"` link gives `Ok(url)`. No `Link` header, or no `rel="next"` link: `Err(None)`.
	next_link : List((Str, Str)) -> Try(Str, [None])
	next_link = |headers| match header_value(headers, "link") {
		Err(NotFound) => Err(None)
		Ok(value) => match value.split_on(",").keep_oks(next_target).first() {
			Ok(url) => Ok(url)
			Err(ListWasEmpty) => Err(None)
		}
	}

	## What to do for a page (R-DI2, R-DI12). `now` is the real clock and `mtime` is the time of the last answer (seconds). A time in the future counts as age 0.
	##
	## | Cache | `offline` | Result |
	## | --- | --- | --- |
	## | A page | yes | `Use`: no request |
	## | No page | yes | `Missing` |
	## | A page that is younger than 60 s (`now - mtime < 60`) | no | `Use`: no request |
	## | An older page with an ETag | no | `Revalidate(etag)`: the request has `If-None-Match` |
	## | An older page with no ETag | no | `Fetch` |
	## | No page | no | `Fetch` |
	plan : { cached : Try(Cached, [Missing]), now : U64, offline : Bool } -> [Use, Revalidate(Str), Fetch, Missing]
	plan = |facts| match facts.cached {
		Err(Missing) => if facts.offline Missing else Fetch
		Ok(page) => {
			age = if page.mtime >= facts.now 0 else facts.now - page.mtime
			if facts.offline or age < 60 {
				Use
			} else {
				match page.etag {
					Ok(etag) => Revalidate(etag)
					Err(None) => Fetch
				}
			}
		}
	}

	## A rate limit answer (R-DI13). It is one when the status is 403 or 429 and the headers (names in any case) have `x-ratelimit-remaining` with the value `0`, or `retry-after`.
	## The reset time is `x-ratelimit-reset` (seconds since the epoch) when it is a number, else `now + retry-after` when that is a number, else `Err(Unknown)`.
	## Any other answer is `Err(NotLimited)`.
	rate_limit : { status : U16, headers : List((Str, Str)), now : U64 } -> Try({ reset : Try(U64, [Unknown]) }, [NotLimited])
	rate_limit = |facts| {
		remaining = header_value(facts.headers, "x-ratelimit-remaining")
		retry = header_value(facts.headers, "retry-after")
		limited = (facts.status == 403 or facts.status == 429) and (remaining == Ok("0") or retry != Err(NotFound))
		if limited {
			reset = match header_value(facts.headers, "x-ratelimit-reset").map_err(|_| Unknown).map_ok(|t| U64.from_str(t.trim())) {
				Ok(Ok(at)) => Ok(at)
				_ => match retry.map_err(|_| Unknown).map_ok(|t| U64.from_str(t.trim())) {
					Ok(Ok(seconds)) => Ok(facts.now + seconds)
					_ => Err(Unknown)
				}
			}
			Ok({ reset: reset })
		} else {
			Err(NotLimited)
		}
	}

	## The failure for a rate limit (R-DI13): kind `Network` (exit 15), with the reset time and the three token sources (R-RG3):
	## `GitHub API rate limit reached. It resets at <time>. Set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login).`
	## `<time>` is `Clock.format_utc`. With `Err(Unknown)`: `GitHub API rate limit reached. Set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login).`
	rate_limit_failure : { reset : Try(U64, [Unknown]) } -> Fail
	rate_limit_failure = |facts| {
		when = match facts.reset {
			Ok(at) => " It resets at ${Clock.format_utc(at)}."
			Err(Unknown) => ""
		}
		Fail.new(Network, "GitHub API rate limit reached.${when} Set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login).")
	}

	## The failure for a request that got no answer (R-DI12): kind `Network` (exit 15), and the message names `--offline`:
	## `cannot reach <url>: <why>. Use --offline to work with the cached index.` `why` is `no answer in 20 s` for `Timeout` and the text for `Failed(text)`.
	network_failure : { url : Str, why : [Timeout, Failed(Str)] } -> Fail
	network_failure = |facts| {
		why = match facts.why {
			Timeout => "no answer in 20 s"
			Failed(text) => text
		}
		Fail.new(Network, "cannot reach ${facts.url}: ${why}. Use --offline to work with the cached index.")
	}

	## The failure for an answer that is not 200, 304 or a rate limit (question Q2): kind `Network` (exit 15), `GitHub answered <status> for <url>`.
	status_failure : { url : Str, status : U16 } -> Fail
	status_failure = |facts| Fail.new(Network, "GitHub answered ${facts.status.to_str()} for ${facts.url}")

	## The line that a command prints once when it works offline (R-DI12): `index: cached at <time>`, with `<time>` from `Clock.format_utc`.
	offline_line : U64 -> Str
	offline_line = |time| "index: cached at ${Clock.format_utc(time)}"

	## The pages of the release list of one repository (R-DI2, R-DI12, R-DI13). `now` is the real clock (`Fx.clock!`). The result:
	##
	## | Field | Value |
	## | --- | --- |
	## | `pages` | The page texts, in order. Empty when the source is `Missing`. |
	## | `source` | `Live`: not offline. `Cached(t)`: offline, with the oldest `mtime` of the pages (the command prints `offline_line(t)` once). `Missing`: offline and no page 1 (the command decides: R-DI11 or R-DI12, exit 15). |
	##
	## The calls, in order (the L2 case `index/di-list-flow` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 1 | One `list_dirs!` of `repo_dir`. `NotFound` is an empty list. The `mtime` of page `n` is that of the entry `<n>.meta`. |
	## | 2 | Page 1 has the URL `list_url`. A later page has the `next` of the meta of the page before it. For each page: when the listing has its `meta` entry, one `read_files!` of `[meta, body]` (a `body` that is missing is a page that is not cached). Then `plan`. |
	## | 3 | `Use`: the cached body. `Fetch` and `Revalidate`: one `http_get!` with `Net.headers` (the token is resolved before the first request, below) and the `ETag` of the cache for `Revalidate`. 200: the new body, `meta_text` with the new ETag (the header `ETag`, any case) and the `Link` next. 304 (only after `Revalidate`): the cached body and its `next`. A rate limit (`rate_limit`): `rate_limit_failure`. An error of the call: `network_failure`. Any other status: `status_failure`. |
	## | 4 | After the last page (no `next`), with no failure: one `write_atomic!` for all pages that changed: for each page the body (200 only) and then the meta (200, and 304: the same text, to renew the time of the page). No call when no page changed. A failure at any step writes nothing (R-DI13). |
	##
	## The token (R-RG3): before the first `http_get!`, and only then, `Net.token`. For `AskGh`: one `programs!(["gh"])`, and when `gh` is there one `spawn_all!({ jobs: [{ argv: ["gh", "auth", "token"], cwd: Err(Inherit) }], limit: 1 })`, read by `Net.token_from_gh`. `Test` and `Env` make no call. The token is for the list requests only (R-DI9: not for `.roc-version`, not for an archive).
	releases! : Fx, { net : Net.Settings, roots : Roots, owner : Str, repo : Str, now : U64, offline : Bool } => Try({ pages : List(Str), source : [Live, Cached(U64), Missing] }, Fail)
	releases! = |fx, facts| {
		dir = Github.repo_dir({ roots: facts.roots, owner: facts.owner, repo: facts.repo })
		listing = match fx.list_dirs!([dir]) {
			[Ok(entries)] => entries
			_ => []
		}
		run = { net: facts.net, owner: facts.owner, repo: facts.repo, now: facts.now, offline: facts.offline, dir, listing }
		first = Github.list_url({ api: facts.net.api, owner: facts.owner, repo: facts.repo })
		state = pages_from!(fx, run, { pages: [], writes: [], oldest: Err(None), token: Unresolved }, 1, first)?
		if !state.writes.is_empty() {
			match fx.write_atomic!(state.writes) {
				Ok(_) => {}
				Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
			}
		}
		source = match (facts.offline, state.oldest) {
			(False, _) => Live
			(True, Ok(oldest)) => Cached(oldest)
			(True, Err(None)) => Missing
		}
		Ok({ pages: state.pages, source })
	}

	## The `.roc-version` hint of a tag (R-DI8). One `http_get!` of `hint_url` with `Net.headers` and no token and no ETag. `Err(NoHint)` for a 404. A transport error
	## is `network_failure`, any other status is `status_failure`.
	hint! : Fx, { net : Net.Settings, owner : Str, repo : Str, tag : Str } => Try(Try(Str, [NoHint]), Fail)
	hint! = |fx, facts| {
		url = Github.hint_url({ raw: facts.net.raw, owner: facts.owner, repo: facts.repo, tag: facts.tag })
		match fx.http_get!({ url, headers: Net.headers({ token: Err(None), etag: Err(None) }) }) {
			Err(why) => Err(Github.network_failure({ url, why }))
			Ok(answer) => match Github.hint({ status: answer.status, body: answer.body }) {
				Ok(text) => Ok(Ok(text))
				Err(NoHint) => Ok(Err(NoHint))
				Err(Failed(status)) => Err(Github.status_failure({ url, status }))
			}
		}
	}

	## The failure for a 404 of the release list (question Q2): kind `Usage` (exit 2), `no GitHub repository <owner>/<repo> (a private repository needs a token)`.
	missing_repo : { owner : Str, repo : Str } -> Fail
	missing_repo = |facts| Fail.new(Usage, "no GitHub repository ${facts.owner}/${facts.repo} (a private repository needs a token)")
}

Entry : { name : Str, is_dir : Bool, mtime : U64 }

Run : { net : Net.Settings, owner : Str, repo : Str, now : U64, offline : Bool, dir : Str, listing : List(Entry) }

Token : [Unresolved, Resolved(Try(Str, [None]))]

State : { pages : List(Str), writes : List({ path : Str, content : Str }), oldest : Try(U64, [None]), token : Token }

CachedPage : { etag : Try(Str, [None]), next : Try(Str, [None]), mtime : U64, body : Str }

# The value of a header, with the name in any case.
header_value : List((Str, Str)), Str -> Try(Str, [NotFound])
header_value = |headers, name| match headers.find_first(|(n, _)| n.with_ascii_lowercased() == name) {
	Ok((_, value)) => Ok(value)
	Err(NotFound) => Err(NotFound)
}

# The URL of one link of a `Link` header, when it is `<url>; rel="next"`.
next_target : Str -> Try(Str, [NotFound])
next_target = |part| {
	link = part.trim()
	match link.split_first(">") {
		Ok(found) => if link.starts_with("<") and found.after.contains("rel=\"next\"") Ok(found.before.drop_prefix("<")) else Err(NotFound)
		Err(NotFound) => Err(NotFound)
	}
}

# Page `n` from the cache: its meta and its body. A page with no meta entry, or with no body, is not cached.
cached_page! : Fx, Run, U64 => Try(CachedPage, [Missing])
cached_page! = |fx, run, n| {
	files = Github.page_files({ dir: run.dir, n })
	match run.listing.find_first(|e| e.name == Text.last_segment(files.meta)) {
		Err(NotFound) => Err(Missing)
		Ok(entry) => match fx.read_files!([files.meta, files.body]) {
			[Ok(meta_text), Ok(body)] => {
				meta = Github.parse_meta(meta_text)
				Ok({ etag: meta.etag, next: meta.next, mtime: entry.mtime, body })
			}
			_ => Err(Missing)
		}
	}
}

# The token of the list requests (R-RG3), asked for once, at the first request.
token_of! : Fx, Net.Settings, Token => (Try(Str, [None]), Token)
token_of! = |fx, net, state| match state {
	Resolved(token) => (token, state)
	Unresolved => {
		gh = match net.token {
			AskGh => ask_gh!(fx)
			_ => Err(None)
		}
		token = Net.token({ plan: net.token, gh })
		(token, Resolved(token))
	}
}

ask_gh! : Fx => Try(Str, [None])
ask_gh! = |fx| match fx.programs!(["gh"]) {
	[Bool.True] => match fx.spawn_all!({ jobs: [{ argv: ["gh", "auth", "token"], cwd: Err(Inherit) }], limit: 1 }) {
		[result] => Net.token_from_gh({ code: result.ended, stdout: result.stdout })
		_ => Err(None)
	}
	_ => Err(None)
}

# The pages from page `n` (at `url`) to the last one.
pages_from! : Fx, Run, State, U64, Str => Try(State, Fail)
pages_from! = |fx, run, state, n, url| {
	cached = cached_page!(fx, run, n)
	step = Github.plan({ cached: cached.map_ok(|c| { etag: c.etag, mtime: c.mtime }), now: run.now, offline: run.offline })
	match (step, cached) {
		(Missing, _) => Ok(state)
		(Use, Ok(c)) => {
			oldest = match state.oldest {
				Ok(t) => if t < c.mtime t else c.mtime
				Err(None) => c.mtime
			}
			next_page!(fx, run, { ..state, pages: state.pages.append(c.body), oldest: Ok(oldest) }, n, c.next)
		}
		(Use, Err(Missing)) => Ok(state)
		_ => {
			etag = match step {
				Revalidate(e) => Ok(e)
				_ => Err(None)
			}
			(token, token_state) = token_of!(fx, run.net, state.token)
			asked = { ..state, token: token_state }
			files = Github.page_files({ dir: run.dir, n })
			answer = match fx.http_get!({ url, headers: Net.headers({ token, etag }) }) {
				Ok(a) => a
				Err(why) => return Err(Github.network_failure({ url, why }))
			}
			match Github.rate_limit({ status: answer.status, headers: answer.headers, now: run.now }) {
				Ok({ reset }) => Err(Github.rate_limit_failure({ reset: reset }))
				Err(NotLimited) => match (answer.status, cached) {
					(200, _) => {
						new_etag = header_value(answer.headers, "etag").map_err(|_| None)
						next = Github.next_link(answer.headers)
						writes = [{ path: files.body, content: answer.body }, { path: files.meta, content: Github.meta_text({ etag: new_etag, next }) }]
						next_page!(fx, run, { ..asked, pages: asked.pages.append(answer.body), writes: asked.writes.concat(writes) }, n, next)
					}
					(304, Ok(c)) if etag != Err(None) => {
						writes = [{ path: files.meta, content: Github.meta_text({ etag: c.etag, next: c.next }) }]
						next_page!(fx, run, { ..asked, pages: asked.pages.append(c.body), writes: asked.writes.concat(writes) }, n, c.next)
					}
					(404, _) => Err(Github.missing_repo({ owner: run.owner, repo: run.repo }))
					(status, _) => Err(Github.status_failure({ url, status }))
				}
			}
		}
	}
}

next_page! : Fx, Run, State, U64, Try(Str, [None]) => Try(State, Fail)
next_page! = |fx, run, state, n, next| match next {
	Ok(url) => pages_from!(fx, run, state, n + 1, url)
	Err(None) => Ok(state)
}
