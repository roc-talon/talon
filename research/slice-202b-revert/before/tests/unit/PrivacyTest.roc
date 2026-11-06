import lib.PrivacyGuard
import lib.Roots

PrivacyTest :: [].{}

# Slice 203 (docs/slices/203-privacy-guard.md). Pure: which repositories the guard checks, the file and URL, the verdict and the 2 failures.
# The flow `PrivacyGuard.check!` is the L2 case `tests/commands/cases/registry/rg4-guard`.

roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }

nm = |owner, repo| { owner, repo }

check = |sources| PrivacyGuard.repos_to_check({ sources, offline: Bool.False, frozen: Bool.False })

# R-RG4, R-RG5, R-DI5: the repositories to check. A full name, a group and an asset URL of github.com name a repository. First appearance order, each once, also when 2 forms name one repository.
# A group or a URL of another host gives none (Design N4), and a `?short=` value gives none. R-RG4 is for a registry request: `offline` and `frozen` give none, whatever the names are.
expect {
	all = [
		Repo("acme/lib"),
		Group("github.com/acme/json/releases/download/{v}/"),
		Url("https://github.com/acme/lib/releases/download/1.0.0/h1.tar.zst"),
		Short("jsn"),
		Group("example.com/pkg/{v}/"),
		Url("https://gitlab.com/acme/other/releases/download/1.0.0/h2.tar.zst"),
		Url("https://github.com/acme/web/releases/download/v2.1.0/h3.tar.zst"),
		Group("github.com/zed/app/releases/download/v{v}/"),
	]
	check(all)
		== [nm("acme", "lib"), nm("acme", "json"), nm("acme", "web"), nm("zed", "app")]
		and check([Short("jsn"), Group("example.com/pkg/{v}/"), Url("https://example.org/a/b/c/d/e.tar.zst")])
			== []
			and check([])
				== []
				and PrivacyGuard.repos_to_check({ sources: all, offline: Bool.True, frozen: Bool.False })
					== []
					and PrivacyGuard.repos_to_check({ sources: all, offline: Bool.False, frozen: Bool.True })
						== []
}

# R-RG5, Design Q200: the file of a kept answer is `<index>/github/<owner>/<repo>/repo.json`. An unsafe part has no file. R-RG4: the URL of the request is `<api>/repos/<owner>/<repo>`, with the base of the test hook too.
expect {
	PrivacyGuard.repo_file({ roots, owner: "acme", repo: "lib" })
		== Ok("/c/roc/talon/index/github/acme/lib/repo.json")
		and PrivacyGuard.repo_file({ roots, owner: "..", repo: "lib" })
			== Err(BadPart)
			and PrivacyGuard.repo_file({ roots, owner: "acme", repo: "a/b" })
				== Err(BadPart)
				and PrivacyGuard.repo_url({ api: "https://api.github.com", owner: "acme", repo: "lib" })
					== "https://api.github.com/repos/acme/lib"
					and PrivacyGuard.repo_url({ api: "http://127.0.0.1:1/api", owner: "acme", repo: "lib" })
						== "http://127.0.0.1:1/api/repos/acme/lib"
}

# R-RG5, R-RG6: the verdict. `private` false is public. `private` true and a 404 are refused (with no token a private repository is a 404). Any other status is not the guard's: a rate limit and a server fault.
# The body of a real GitHub answer has many members, `private` is read by name, in any place.
expect {
	body = |private| "{\"id\":1,\"name\":\"lib\",\"full_name\":\"acme/lib\",\"private\":${private},\"owner\":{\"login\":\"acme\"},\"fork\":false}"
	verdict = |status, text| PrivacyGuard.verdict({ status, body: text })
	verdict(200, body("false"))
		== Public
		and verdict(200, body("true"))
			== Refused
			and verdict(404, "{\"message\":\"Not Found\"}")
				== Refused
				and verdict(403, "{\"message\":\"API rate limit exceeded\"}")
					== Other
					and verdict(429, "")
						== Other
						and verdict(500, "")
							== Other
							and verdict(301, "")
								== Other
}

# R-RG6, R-EC2: the 2 failures. Both are exit 2 (usage), say that private packages are not supported, and name the full name. With no token the text says "not found, or private" and names the 3 token sources of R-RG3.
expect {
	with_token = PrivacyGuard.refusal({ owner: "acme", repo: "lib", token: Bool.True })
	no_token = PrivacyGuard.refusal({ owner: "acme", repo: "lib", token: Bool.False })
	with_token.kind.code()
		== 2
		and no_token.kind.code()
			== 2
			and with_token.message
				== "GitHub repository acme/lib is private or does not exist. Private packages are not supported."
				and no_token.message
					== "GitHub repository acme/lib: not found, or private. Private packages are not supported. With no token GitHub answers 404 for a private repository: set GITHUB_TOKEN or GH_TOKEN, or log in with gh (gh auth login), and run the command again."
}
