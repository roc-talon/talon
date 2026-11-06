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

	## R-RG4, R-RG5: the repositories to check, in the order of first appearance, each one once (the same `owner` and `repo` text). `known` is not here: `check!` skips the repositories that have a kept answer.
	##
	## | Case | Result |
	## | --- | --- |
	## | `offline` (R-RG4: Talon sends no request) | none |
	## | `frozen` (`tln install --frozen` makes no index call: R-DI1) | none |
	## | `Short(_)` (R-RG4: no check) | none for it |
	## | `Repo("owner/repo")` | `{ owner, repo }` |
	## | `Group` of the form `github.com/<owner>/<repo>/releases/download/<rest>`, `Url` of the form `https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>` | `{ owner, repo }` |
	## | A group or a URL of another host (`example.com`, `gitlab.com`, `raw.githubusercontent.com`) | none (R-RG4 is for `github.com`, Design N4) |
	##
	## Not tested and open (slice file Q3): another form on `github.com`, a part that is not a safe path part.
	repos_to_check : { sources : List(Source), offline : Bool, frozen : Bool } -> List({ owner : Str, repo : Str })
	repos_to_check = |facts| if facts.offline or facts.frozen {
		[]
	} else {
		facts.sources.fold(
			[],
			|found, source| match repo_of(source) {
				Ok(name) => if found.contains(name) found else found.append(name)
				Err(_) => found
			},
		)
	}

	## R-RG5, Design Q200: the file of a kept public answer: `<index>/github/<owner>/<repo>/repo.json` (the dir of `Github.index_dir`). `Err(BadPart)` for a part that is not a safe path part.
	repo_file : { roots : Roots, owner : Str, repo : Str } -> Try(Str, [BadPart])
	repo_file = |facts| match Github.index_dir({ roots: facts.roots, owner: facts.owner, repo: facts.repo }) {
		Ok(dir) => Ok(Text.join(dir, "repo.json"))
		Err(BadPart) => Err(BadPart)
	}

	## R-RG4: `<api>/repos/<owner>/<repo>`. `api` is `Settings.api` of `Net`.
	repo_url : { api : Str, owner : Str, repo : Str } -> Str
	repo_url = |facts| "${facts.api}/repos/${facts.owner}/${facts.repo}"

	## R-RG5, R-RG6: what the answer of GitHub says. Status 200 with the member `private` equal to `false`: `Public`. Status 200 with `private` equal to `true`, and status 404: `Refused`. Any other status (403 rate limit, 5xx): `Other` (the caller handles it: R-DI13).
	## Not tested and open (slice file Q4): a 200 with no `private` member, or a body that is not JSON.
	verdict : { status : U16, body : Str } -> [Public, Refused, Other]
	verdict = |facts| match facts.status {
		404 => Refused
		200 => match JsonDoc.parse(facts.body) {
			Ok(Obj(pairs)) => match pairs.find_first(|(k, _)| k == "private") {
				Ok((_, Flag(Bool.False))) => Public
				_ => Refused
			}
			_ => Refused
		}
		_ => Other
	}

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
	## | 0 | `repos_to_check` is empty: no call at all, `Ok({})` |
	## | 1 | One `read_files!` of the `repo_file` of each repository, in order. A file that is there (any text) is a kept public answer: no request for that repository (R-RG5). |
	## | 2 | The token (R-RG3), only when a repository has no file, before the first request, once: `Github.ask_gh!` for `AskGh` (`programs!`, then `gh auth token`), `Test` and `Env` make no call. Never sent to a registry. |
	## | 3 | For each repository with no file, in order: one `http_get!` of `repo_url` with `Net.headers` (the token, no ETag). A transport error: `Github.network_failure`. A rate limit: `Github.rate_limit_failure` (R-DI13, exit 15). `Other`: `Github.status_failure`. `Refused`: `Err(refusal)`, nothing is written for it, and no later repository is asked. |
	## | 4 | `Public`: one `write_atomic!` of `[{ path: repo_file, content: body }]` (the body as it came, R-RG5). |
	check! : Fx, { net : Net.Settings, roots : Roots, sources : List(Source), offline : Bool, frozen : Bool } => Try({}, Fail)
	check! = |fx, facts| {
		repos = PrivacyGuard.repos_to_check({ sources: facts.sources, offline: facts.offline, frozen: facts.frozen })
		files = repos.keep_oks(
			|r| PrivacyGuard.repo_file({ roots: facts.roots, owner: r.owner, repo: r.repo }).map_ok(|path| { owner: r.owner, repo: r.repo, path }),
		)
		if files.is_empty() {
			return Ok({})
		}
		known = fx.read_files!(files.map(|f| f.path))
		todo = files.map2(known, |f, got| (f, got)).keep_if(|(_, got)| got.is_err()).map(|(f, _)| f)
		if todo.is_empty() {
			return Ok({})
		}
		gh = match facts.net.token {
			AskGh => Github.ask_gh!(fx)
			_ => Err(None)
		}
		token = Net.token({ plan: facts.net.token, gh })
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
				Refused => return Err(PrivacyGuard.refusal({ owner: repo.owner, repo: repo.repo, token: token != Err(None) }))
				Other => return Err(Github.status_failure({ url, status: reply.status }))
			}
		}
		Ok({})
	}
}

# The repository that a name carries, for `github.com` only (R-RG4). A part that is not a safe path part is skipped.
repo_of : PrivacyGuard.Source -> Try({ owner : Str, repo : Str }, [NoRepo])
repo_of = |source| match source {
	Repo(name) => match name.split_on("/") {
		[owner, repo] => checked(owner, repo)
		_ => Err(NoRepo)
	}
	Group(text) => if text.starts_with("github.com/") from_path(text.drop_prefix("github.com/")) else Err(NoRepo)
	Url(text) => if text.starts_with("https://github.com/") from_path(text.drop_prefix("https://github.com/")) else Err(NoRepo)
	Short(_) => Err(NoRepo)
}

# `<owner>/<repo>/releases/download/...`
from_path : Str -> Try({ owner : Str, repo : Str }, [NoRepo])
from_path = |path| match path.split_on("/") {
	[owner, repo, "releases", "download", ..] => checked(owner, repo)
	_ => Err(NoRepo)
}

checked : Str, Str -> Try({ owner : Str, repo : Str }, [NoRepo])
checked = |owner, repo| if Ident.safe_part(owner) and Ident.safe_part(repo) Ok({ owner, repo }) else Err(NoRepo)
