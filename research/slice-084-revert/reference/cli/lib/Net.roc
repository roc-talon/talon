import Help
import Setting

## The network settings of a run, from the environment (CLI 1: R-EV2, R-EV3, R-EV12, R-EV14, R-EV15, R-EV19, R-EV20), the
## registry precedence (R-RG1, R-RG2) and the token rules for the GitHub API (R-RG3, R-DI9). Pure: the call of `gh` and the
## requests are in `Github` and `Fx`.
Net :: [].{

	## `api` and `raw` are the base URLs (no `/` at the end). `token` is the plan for the GitHub token. `downloader` is
	## the wish of `TALON_DOWNLOADER`. `registry` is the value of `TALON_REGISTRY`.
	Settings : {
		api : Str,
		raw : Str,
		token : [Test, Env(Str), AskGh],
		downloader : [Auto, Curl, Wget, Bad(Str)],
		registry : Try(Str, [Unset]),
	}

	## The registry of a run (R-RG1).
	Registry : [Direct, Url(Str)]

	## The settings from the environment (`Fx.env_all!`). An empty value is the same as no value.
	##
	## | Field | Value | Rule |
	## | --- | --- | --- |
	## | `api` | `TALON_GITHUB_API`, else `https://api.github.com` | R-EV14, R-EV19 |
	## | `raw` | `TALON_GITHUB_RAW`, else `https://raw.githubusercontent.com` | R-EV15, R-EV20 |
	## | `token` | `Test` when `TALON_GITHUB_API` is set: Talon reads no token source and sends no token (R-EV19). Else `Env(t)` for the first of `GITHUB_TOKEN`, `GH_TOKEN` that is set. Else `AskGh`: the output of `gh auth token` is the third source (R-RG3). | R-EV3, R-RG3, R-EV19 |
	## | `downloader` | `TALON_DOWNLOADER`: `curl` is `Curl`, `wget` is `Wget`, not set is `Auto`, any other text is `Bad(text)` (question Q4) | R-EV12 |
	## | `registry` | `TALON_REGISTRY` | R-EV2 |
	from_env : List((Str, Str)) -> Settings
	from_env = |env| {
		var_of = |name| match env.find_first(|(n, _)| n == name) {
			Ok((_, value)) => if value.is_empty() Err(Unset) else Ok(value)
			Err(_) => Err(Unset)
		}
		api = var_of("TALON_GITHUB_API")
		first_token = match var_of("GITHUB_TOKEN") {
			Ok(t) => Ok(t)
			Err(Unset) => var_of("GH_TOKEN")
		}
		{
			api: api ?? "https://api.github.com",
			raw: var_of("TALON_GITHUB_RAW") ?? "https://raw.githubusercontent.com",
			token: match api {
				Ok(_) => Test
				Err(Unset) => match first_token {
					Ok(t) => Env(t)
					Err(Unset) => AskGh
				}
			},
			downloader: match var_of("TALON_DOWNLOADER") {
				Err(Unset) => Auto
				Ok("curl") => Curl
				Ok("wget") => Wget
				Ok(other) => Bad(other)
			},
			registry: var_of("TALON_REGISTRY"),
		}
	}

	## The registry of a run: the first of the flag (`--registry`), `TALON_REGISTRY` (`Settings.registry`) and `registry` in
	## `config.toml`. The text `direct` is `Direct`, any other text is `Url(text)`. With no value: `Direct`, the built-in
	## default (R-RG2). A URL is not checked here.
	registry : { flag : Try(Str, [Unset]), env : Try(Str, [Unset]), config : Try(Str, [Unset]) } -> Registry
	registry = |layers| match Setting.pick({ flag: layers.flag, env: layers.env, project: Err(Unset), user: layers.config }) {
		Ok("direct") => Direct
		Ok(url) => Url(url)
		Err(Unset) => Direct
	}

	## The token from the output of `gh auth token` (R-RG3, the third source): the output with the white space cut off,
	## when the exit code is 0 and the text is not empty. Else `Err(None)` (`gh` is not logged in).
	token_from_gh : { code : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str } -> Try(Str, [None])
	token_from_gh = |facts| match facts.code {
		Exited(0) => {
			text = facts.stdout.trim()
			if text.is_empty() Err(None) else Ok(text)
		}
		_ => Err(None)
	}

	## The token that Talon sends: the plan of `Settings.token` and the answer of `gh` (`Err(None)` when it was not asked or it
	## gave nothing). `Test` gives no token. `Env(t)` gives `t`. `AskGh` gives the answer of `gh`.
	token : { plan : [Test, Env(Str), AskGh], gh : Try(Str, [None]) } -> Try(Str, [None])
	token = |facts| match facts.plan {
		Test => Err(None)
		Env(t) => Ok(t)
		AskGh => facts.gh
	}

	## The headers of one request to the GitHub API (R-DI2, R-RG3), in this order: `User-Agent: tln/<Help.version>` (GitHub
	## refuses a request with no user agent: question Q5), `Authorization: Bearer <token>` when there is a token, and
	## `If-None-Match: <etag>` when there is an ETag. A request that does not go to the API (`.roc-version`, an archive) has
	## no token (R-DI9, R-EV20): the caller gives `Err(None)`.
	headers : { token : Try(Str, [None]), etag : Try(Str, [None]) } -> List((Str, Str))
	headers = |facts| {
		agent = [("User-Agent", "tln/${Help.version}")]
		with_token = match facts.token {
			Ok(t) => agent.append(("Authorization", "Bearer ${t}"))
			Err(None) => agent
		}
		match facts.etag {
			Ok(e) => with_token.append(("If-None-Match", e))
			Err(None) => with_token
		}
	}
}
