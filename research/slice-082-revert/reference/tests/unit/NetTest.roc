import lib.Help
import lib.Net

NetTest :: [].{}

# R-EV14 R-EV15 R-EV19 R-EV20 R-EV3 R-RG3 R-EV12 R-EV2: the settings from the environment. The default API and raw base URLs.
# `TALON_GITHUB_API` replaces the API base and turns the token off (no token source is read, R-EV19). `GITHUB_TOKEN` comes before
# `GH_TOKEN`, and the output of `gh` is the third source (`AskGh`). An empty value is no value (Q5).
expect {
	api = "https://api.github.com"
	raw = "https://raw.githubusercontent.com"
	fake = "http://127.0.0.1:41234"
	rows = [
		("nothing set", [], { api, raw, token: AskGh, downloader: Auto, registry: Err(Unset) }),
		("GITHUB_TOKEN", [("GITHUB_TOKEN", "t1")], { api, raw, token: Env("t1"), downloader: Auto, registry: Err(Unset) }),
		("GH_TOKEN", [("GH_TOKEN", "t2")], { api, raw, token: Env("t2"), downloader: Auto, registry: Err(Unset) }),
		("GITHUB_TOKEN first", [("GH_TOKEN", "t2"), ("GITHUB_TOKEN", "t1")], { api, raw, token: Env("t1"), downloader: Auto, registry: Err(Unset) }),
		("empty GITHUB_TOKEN", [("GITHUB_TOKEN", ""), ("GH_TOKEN", "t2")], { api, raw, token: Env("t2"), downloader: Auto, registry: Err(Unset) }),
		("both tokens empty", [("GITHUB_TOKEN", ""), ("GH_TOKEN", "")], { api, raw, token: AskGh, downloader: Auto, registry: Err(Unset) }),
		(
			"test API: no token source, even with a token in the environment",
			[("TALON_GITHUB_API", "${fake}/api"), ("GITHUB_TOKEN", "t1"), ("GH_TOKEN", "t2")],
			{ api: "${fake}/api", raw, token: Test, downloader: Auto, registry: Err(Unset) },
		),
		("test raw base", [("TALON_GITHUB_RAW", "${fake}/raw")], { api, raw: "${fake}/raw", token: AskGh, downloader: Auto, registry: Err(Unset) }),
		("empty API is not set", [("TALON_GITHUB_API", "")], { api, raw, token: AskGh, downloader: Auto, registry: Err(Unset) }),
		("curl", [("TALON_DOWNLOADER", "curl")], { api, raw, token: AskGh, downloader: Curl, registry: Err(Unset) }),
		("wget", [("TALON_DOWNLOADER", "wget")], { api, raw, token: AskGh, downloader: Wget, registry: Err(Unset) }),
		("another program", [("TALON_DOWNLOADER", "fetch")], { api, raw, token: AskGh, downloader: Bad("fetch"), registry: Err(Unset) }),
		("empty downloader", [("TALON_DOWNLOADER", "")], { api, raw, token: AskGh, downloader: Auto, registry: Err(Unset) }),
		("registry direct", [("TALON_REGISTRY", "direct")], { api, raw, token: AskGh, downloader: Auto, registry: Ok("direct") }),
		("registry URL", [("TALON_REGISTRY", "https://r.example.com")], { api, raw, token: AskGh, downloader: Auto, registry: Ok("https://r.example.com") }),
	]
	bad = rows.keep_if(|(_, env, want)| Net.from_env(env) != want).map(|(label, env, want)| (label, want, Net.from_env(env)))
	dbg bad
	bad == []
}

# R-RG1 R-RG2: the registry. The flag, then `TALON_REGISTRY`, then `config.toml`, then the built-in default `direct`. The text `direct` is
# `Direct`, any other text is a URL. R-RG3: the token of `gh` is the output of `gh auth token` when `gh` exits with 0 and prints a
# text. `Net.token` follows the plan: `Test` sends none, `Env` the variable, `AskGh` the answer of `gh`. R-EV19 R-DI9: the
# headers of a request: the user agent first, then the token, then `If-None-Match`.
expect {
	set = |v| Ok(v)
	none = Err(Unset)
	registries = [
		("nothing: the default", { flag: none, env: none, config: none }, Direct),
		("config only", { flag: none, env: none, config: set("https://c.example.com") }, Url("https://c.example.com")),
		("env over config", { flag: none, env: set("direct"), config: set("https://c.example.com") }, Direct),
		("flag over env", { flag: set("https://f.example.com"), env: set("direct"), config: set("https://c.example.com") }, Url("https://f.example.com")),
		("flag direct over all", { flag: set("direct"), env: set("https://e.example.com"), config: set("https://c.example.com") }, Direct),
		("env over nothing", { flag: none, env: set("https://e.example.com"), config: none }, Url("https://e.example.com")),
	]
	bad_registry = registries.keep_if(|(_, layers, want)| Net.registry(layers) != want).map(|(label, layers, want)| (label, want, Net.registry(layers)))
	dbg bad_registry

	gh_rows = [
		("a token", { code: Exited(0), stdout: "ghp_abc\n" }, Ok("ghp_abc")),
		("white space around", { code: Exited(0), stdout: "  tok  \n" }, Ok("tok")),
		("empty output", { code: Exited(0), stdout: "" }, Err(None)),
		("only a newline", { code: Exited(0), stdout: "\n" }, Err(None)),
		("not logged in", { code: Exited(1), stdout: "ghp_abc" }, Err(None)),
		("gh is not installed", { code: NotStarted("not found"), stdout: "" }, Err(None)),
		("a signal", { code: Signaled(9), stdout: "ghp_abc" }, Err(None)),
	]
	bad_gh = gh_rows.keep_if(|(_, facts, want)| Net.token_from_gh(facts) != want).map(|(label, facts, want)| (label, want, Net.token_from_gh(facts)))
	dbg bad_gh

	token_rows = [
		("test API: no token, also when gh gave one", { plan: Test, gh: Ok("g") }, Err(None)),
		("env token", { plan: Env("e"), gh: Err(None) }, Ok("e")),
		("env token over gh", { plan: Env("e"), gh: Ok("g") }, Ok("e")),
		("gh token", { plan: AskGh, gh: Ok("g") }, Ok("g")),
		("no token at all", { plan: AskGh, gh: Err(None) }, Err(None)),
	]
	bad_token = token_rows.keep_if(|(_, facts, want)| Net.token(facts) != want).map(|(label, facts, want)| (label, want, Net.token(facts)))
	dbg bad_token

	agent = ("User-Agent", "tln/${Help.version}")
	header_rows = [
		("no token, no etag", { token: Err(None), etag: Err(None) }, [agent]),
		("token", { token: Ok("abc"), etag: Err(None) }, [agent, ("Authorization", "Bearer abc")]),
		("etag", { token: Err(None), etag: Ok("\"v1\"") }, [agent, ("If-None-Match", "\"v1\"")]),
		("token and etag", { token: Ok("abc"), etag: Ok("W/\"v2\"") }, [agent, ("Authorization", "Bearer abc"), ("If-None-Match", "W/\"v2\"")]),
	]
	bad_headers = header_rows.keep_if(|(_, facts, want)| Net.headers(facts) != want).map(|(label, facts, want)| (label, want, Net.headers(facts)))
	dbg bad_headers
	bad_registry == [] and bad_gh == [] and bad_token == [] and bad_headers == []
}
