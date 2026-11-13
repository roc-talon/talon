import Fail
import Fx
import Github
import Ident
import JsonDoc
import Net
import Roots
import Text

## The privacy guard (slice 203, CLI 1, R-RG3 to R-RG6, R-EC2). Before the first registry request that names a `github.com` repository, Talon asks GitHub if it is public. `repos_to_check` is the pure decision,
## `check!` is the command code over `Fx`. A kept public answer is the file `repo_file` (R-RG5).
PrivacyGuard :: [].{

	## What a command sends to the registry, one value for each name that it carries (R-RG4): `Repo("owner/repo")` is a full name that the user typed (`tln add owner/repo`), `Group(text)` is a group in the URL form of R-AP13 (`github.com/acme/lib/releases/download/{v}/`),
	## `Url(text)` is a release asset URL (`https://github.com/acme/lib/releases/download/1.0.0/<hash>.tar.zst`) of a header entry or of an ingest, `Short(name)` is a `?short=` value (R-AD34).
	Source : [Repo(Str), Group(Str), Url(Str), Short(Str)]

	## R-RG4, R-RG5 (Design Q219): the repositories to check, in the order of first appearance, each once. A name is in lower case (GitHub names are ASCII case-insensitive), so `Acme/Lib` and `acme/lib` are one repository.
	##
	## | Case | Result |
	## | --- | --- |
	## | `offline` (R-RG4: Talon sends no request) | `Ok([])`, also for a bad name |
	## | `frozen` (`tln install --frozen` makes no index call: R-DI1) | `Ok([])`, also for a bad name |
	## | `Short(_)` (R-RG4: no check) | none for it |
	## | `Repo("owner/repo")` (a typed name) | `{ owner, repo }`. A part that is not a safe path part: `Err(BadName(text))` with the typed text (exit 2, R-EC2) |
	## | `Group` or `Url` whose text is `github.com/<owner>/<repo>` or `https://github.com/<owner>/<repo>`, with any path after the 2 parts or no path | `{ owner, repo }`: the first 2 path parts |
	## | A `Group` or a `Url` with an unsafe part (from a header or a dependency) | none for it, no error (R-AP28 case 3) |
	## | A group or a URL of another host (`example.com`, `gitlab.com`, `raw.githubusercontent.com`) | none (R-RG4 is for `github.com`, Design N4) |
	repos_to_check : { sources : List(Source), offline : Bool, frozen : Bool } -> Try(List({ owner : Str, repo : Str }), [BadName(Str)])
	repos_to_check = |facts| if facts.offline or facts.frozen {
		Ok([])
	} else {
		facts.sources.fold(
			Ok([]),
			|acc, source| match acc {
				Err(e) => Err(e)
				Ok(found) => match repo_of(source) {
					Ok(name) => Ok(if found.contains(name) found else found.append(name))
					Err(NoRepo) => Ok(found)
					Err(BadName(text)) => Err(BadName(text))
				}
			},
		)
	}

	## R-RG5, Design Q200, Q219: the file of a kept public answer: `<index>/github/<owner>/<repo>/repo.json` (the dir of `Github.index_dir`), the key in lower case. `Err(BadPart)` for a part that is not a safe path part.
	repo_file : { roots : Roots, owner : Str, repo : Str } -> Try(Str, [BadPart])
	repo_file = |facts| match Github.index_dir({ roots: facts.roots, owner: facts.owner.with_ascii_lowercased(), repo: facts.repo.with_ascii_lowercased() }) {
		Ok(dir) => Ok(Text.join(dir, "repo.json"))
		Err(BadPart) => Err(BadPart)
	}

	## R-RG4: `<api>/repos/<owner>/<repo>`. `api` is `Settings.api` of `Net`.
	repo_url : { api : Str, owner : Str, repo : Str } -> Str
	repo_url = |facts| "${facts.api}/repos/${facts.owner}/${facts.repo}"

	## R-RG5, R-RG6 (Design Q219): what the answer of GitHub says. Status 200 with the member `private` equal to `false`: `Public`. Status 200 with `private` equal to `true`, and status 404: `Refused`. Status 200 with no `private` member, with a `private` that is not a boolean, or with a body that is not a JSON object: `BadBody` (exit 15, nothing kept).
	## Any other status (403 rate limit, 5xx, 3xx): `Other` (the caller handles it: R-DI13).
	verdict : { status : U16, body : Str } -> [Public, Refused, Other, BadBody]
	verdict = |facts| match facts.status {
		404 => Refused
		200 => match JsonDoc.parse(facts.body) {
			Ok(Obj(pairs)) => match pairs.find_first(|(k, _)| k == "private") {
				Ok((_, Flag(Bool.False))) => Public
				Ok((_, Flag(Bool.True))) => Refused
				_ => BadBody
			}
			_ => BadBody
		}
		_ => Other
	}

	## R-RG4 row 4, R-E6 (an answer that does not decode), G-C39: the failure for a `BadBody` verdict. Kind `Network` (15). The text is a proposal (TW24).
	bad_body : { url : Str } -> Fail
	bad_body = |facts| Fail.new(Network, "the answer of GitHub for ${facts.url} is not a repository answer: it has no member private that is true or false. Try again later.")

	## R-RG6, R-EC2: the failure for a `Refused` answer. Kind `Usage` (exit 2). The texts are proposals (TW24). `token` is `Bool.True` when the request had a token.
	##
	## | `token` | Message |
	## | --- | --- |
	## | `Bool.True` | `GitHub repository <owner>/<repo> is private or does not exist. Private packages are not supported.` |
	## | `Bool.False` | `GitHub repository <owner>/<repo>: not found, or private. Private packages are not supported. With no token GitHub answers 404 for a private repository: set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login), and run the command again.` |
	refusal : { owner : Str, repo : Str, token : Bool } -> Fail
	refusal = |facts| if facts.token {
		Fail.new(Usage, "GitHub repository ${facts.owner}/${facts.repo} is private or does not exist. Private packages are not supported.")
	} else {
		Fail.new(Usage, "GitHub repository ${facts.owner}/${facts.repo}: not found, or private. Private packages are not supported. With no token GitHub answers 404 for a private repository: set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login), and run the command again.")
	}

	## The guard before the first registry request (R-RG3 to R-RG6). `sources` are the names of the request. The calls, in order (the L2 case `registry/rg4-guard` fixes them):
	##
	## | Step | Call |
	## | --- | --- |
	## | 0 | `repos_to_check` is `Err(BadName(text))`: no call at all, `Err(Github.bad_repo)` (exit 2, R-EC2). It is empty: no call at all, `Ok({})` |
	## | 1 | One `read_files!` of the `repo_file` of each repository (lower-case names), in order. A file that is there (any text) is a kept public answer: no request for that repository (R-RG5). |
	## | 2 | The token (R-RG3), only when a repository has no file, before the first request, once: `Github.ask_gh!` for `AskGh` (`programs!`, then `gh auth token`), `Test` and `Env` make no call. Never sent to a registry. |
	## | 3 | For each repository with no file, in order: one `http_get!` of `repo_url` with `Net.headers` (the token, no ETag). A transport error: `Github.network_failure`. A rate limit: `Github.rate_limit_failure` (R-DI13, exit 15). `Other`: `Github.status_failure`. `BadBody`: `Err(bad_body)` (exit 15), nothing is written for it. `Refused`: `Err(refusal)`, nothing is written for it, and no later repository is asked. |
	## | 4 | `Public`: one `write_atomic!` of `[{ path: repo_file, content: body }]` (the body as it came, R-RG5), at once, so a later `Refused` keeps this answer (Design Q220). |
	check! : Fx, { net : Net.Settings, roots : Roots, sources : List(Source), offline : Bool, frozen : Bool } => Try({}, Fail)
	check! = |fx, facts| guard!(fx, facts, Bool.False).map_ok(|_| {})

	## Slice 244b (Design Q620 item 9): `check!` for `tln audit`. A `Refused` repository does not stop the run: the result is the refused names (`owner/repo`, lower case), in order, and the later repositories are checked. Other failures stop as in `check!`.
	collect! : Fx, { net : Net.Settings, roots : Roots, sources : List(Source), offline : Bool, frozen : Bool } => Try(List(Str), Fail)
	collect! = |fx, facts| guard!(fx, facts, Bool.True)
}

guard! : Fx, { net : Net.Settings, roots : Roots, sources : List(Source), offline : Bool, frozen : Bool }, Bool => Try(List(Str), Fail)
guard! = |fx, facts, collect| {
	repos = match PrivacyGuard.repos_to_check({ sources: facts.sources, offline: facts.offline, frozen: facts.frozen }) {
		Ok(r) => r
		Err(BadName(text)) => return Err(bad_name(text))
	}
	files = repos.keep_oks(
		|r| PrivacyGuard.repo_file({ roots: facts.roots, owner: r.owner, repo: r.repo }).map_ok(|path| { owner: r.owner, repo: r.repo, path }),
	)
	if files.is_empty() {
		return Ok([])
	}
	known = fx.read_files!(files.map(|f| f.path))
	todo = files.map2(known, |f, got| (f, got)).keep_if(|(_, got)| got.is_err()).map(|(f, _)| f)
	if todo.is_empty() {
		return Ok([])
	}
	gh = match facts.net.token {
		AskGh => Github.ask_gh!(fx)
		_ => Err(None)
	}
	token = Net.token({ plan: facts.net.token, gh })
	var $refused = []
	for repo in todo {
		url = PrivacyGuard.repo_url({ api: facts.net.api, owner: repo.owner, repo: repo.repo })
		reply = match fx.http_get!({ url, headers: Net.headers({ token, etag: Err(None) }) }) {
			Ok(r) => r
			Err(why) => return Err(Github.network_failure({ url, why }))
		}
		# The clock is read only when the reset time can come from `retry-after` alone.
		has_reset = reply.headers.any(|(name, _)| name.with_ascii_lowercased() == "x-ratelimit-reset")
		now = if (reply.status == 403 or reply.status == 429) and !has_reset fx.clock!() else 0
		match Github.rate_limit({ status: reply.status, headers: reply.headers, now }) {
			Ok(limited) => return Err(Github.rate_limit_failure(limited))
			Err(NotLimited) => {}
		}
		match PrivacyGuard.verdict({ status: reply.status, body: reply.body }) {
			Public => match fx.write_atomic!([{ path: repo.path, content: reply.body }]) {
				Ok(_) => {}
				Err(failed) => return Err(Fail.new(Environment, "cannot write ${failed.path}"))
			}
			Refused => if collect {
				$refused = $refused.append("${repo.owner}/${repo.repo}")
			} else {
				return Err(PrivacyGuard.refusal({ owner: repo.owner, repo: repo.repo, token: token != Err(None) }))
			}
			BadBody => return Err(PrivacyGuard.bad_body({ url: url }))
			Other => return Err(Github.status_failure({ url, status: reply.status }))
		}
	}
	Ok($refused)
}

# The failure for a typed name with an unsafe part (R-EC2). `text` is the typed text.
bad_name : Str -> Fail
bad_name = |text| match text.split_on("/") {
	[owner, repo] => Github.bad_repo({ owner, repo })
	_ => Github.bad_repo({ owner: text, repo: "" })
}

# The repository that a name carries, for `github.com` only (R-RG4), in lower case. `BadName` only for a typed name (`Repo`) with an unsafe part: a name from a header or a dependency is skipped (R-AP28 case 3).
repo_of : PrivacyGuard.Source -> Try({ owner : Str, repo : Str }, [NoRepo, BadName(Str)])
repo_of = |source| match source {
	Repo(name) => match name.split_on("/") {
		[owner, repo] => match checked(owner, repo) {
			Ok(r) => Ok(r)
			Err(_) => Err(BadName(name))
		}
		_ => Err(NoRepo)
	}
	Group(text) => from_text(text)
	Url(text) => from_text(text)
	Short(_) => Err(NoRepo)
}

# `[https://]github.com/<owner>/<repo>[/...]`
from_text : Str -> Try({ owner : Str, repo : Str }, [NoRepo, BadName(Str)])
from_text = |text| {
	rest = text.drop_prefix("https://")
	if rest.starts_with("github.com/") {
		match rest.drop_prefix("github.com/").split_on("/") {
			[owner, repo, ..] => checked(owner, repo).map_err(|_| NoRepo)
			_ => Err(NoRepo)
		}
	} else {
		Err(NoRepo)
	}
}

checked : Str, Str -> Try({ owner : Str, repo : Str }, [NoRepo])
checked = |owner, repo| {
	o = owner.with_ascii_lowercased()
	r = repo.with_ascii_lowercased()
	if Ident.safe_part(o) and Ident.safe_part(r) Ok({ owner: o, repo: r }) else Err(NoRepo)
}
