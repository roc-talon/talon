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
		== Ok([nm("acme", "lib"), nm("acme", "json"), nm("acme", "web"), nm("zed", "app")])
		and check([Short("jsn"), Group("example.com/pkg/{v}/"), Url("https://example.org/a/b/c/d/e.tar.zst")])
			== Ok([])
			and check([])
				== Ok([])
				and PrivacyGuard.repos_to_check({ sources: all, offline: Bool.True, frozen: Bool.False })
					== Ok([])
					and PrivacyGuard.repos_to_check({ sources: all, offline: Bool.False, frozen: Bool.True })
						== Ok([])
}

# R-RG4, G-C39 (Design Q219) rows 1 to 3: each `github.com` text of a request names a repository, the first 2 path parts: a URL with the host github.com and no path after the 2 parts, or any path (not only releases/download), a group or a URL with no scheme.
# One check for each name in lower case (`Acme/Wiki`, `ACME/Wiki` and a URL with the same name in another case are one), and the name in the result is in lower case. A group or a URL (a header, a dependency) with an unsafe part names nothing and gives no error (R-AP28 case 3).
# A host that only contains github.com, and another host with the repo in its path, name nothing.
expect {
	forms = [
		Url("https://github.com/Acme/Wiki"),
		Group("github.com/acme/tools/x/y"),
		Url("https://github.com/acme/issues/issues/3"),
		Url("github.com/acme/plain/releases/download/1/h.tar.zst"),
		Repo("ACME/Wiki"),
		Group("github.com/ACME/TOOLS/"),
		Group("github.com/../lib/releases/download/{v}/"),
		Url("https://github.com/acme/../x"),
		Group("example.com/github.com/acme/hidden/"),
		Url("https://raw.githubusercontent.com/acme/raw/main/x"),
		Url("https://notgithub.com/acme/other/releases/download/1/h.tar.zst"),
	]
	check(forms)
		== Ok([nm("acme", "wiki"), nm("acme", "tools"), nm("acme", "issues"), nm("acme", "plain")])
		and check([Repo("Acme/Lib"), Group("github.com/acme/lib/releases/download/{v}/"), Url("https://github.com/ACME/LIB/releases/download/1/h.tar.zst")])
			== Ok([nm("acme", "lib")])
}

# R-RG4, R-EC2, G-C39 (Design Q219) row 3: a typed name (`Repo`) with an unsafe part is `BadName` with the typed text (exit 2), also when an earlier name is good. `offline` and `frozen` give `Ok([])` before the check of the names (R-RG4: no request).
expect {
	check([Repo("acme/lib"), Repo("../lib")])
		== Err(BadName("../lib"))
		and check([Repo("acme/.."), Repo("acme/lib")])
			== Err(BadName("acme/.."))
			and PrivacyGuard.repos_to_check({ sources: [Repo("../lib")], offline: Bool.True, frozen: Bool.False })
				== Ok([])
				and PrivacyGuard.repos_to_check({ sources: [Repo("../lib")], offline: Bool.False, frozen: Bool.True })
					== Ok([])
}

# R-RG5, Design Q200, G-C39: the file of a kept answer is `<index>/github/<owner>/<repo>/repo.json`, the key in lower case. An unsafe part has no file. R-RG4: the URL of the request is `<api>/repos/<owner>/<repo>`, with the base of the test hook too.
expect {
	PrivacyGuard.repo_file({ roots, owner: "acme", repo: "lib" })
		== Ok("/c/roc/talon/index/github/acme/lib/repo.json")
		and PrivacyGuard.repo_file({ roots, owner: "Acme", repo: "LIB" })
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

# R-RG5, R-RG6, G-C39 row 4: the verdict. `private` false is public. `private` true and a 404 are refused (with no token a private repository is a 404). Any other status is not the guard's: a rate limit and a server fault.
# The body of a real GitHub answer has many members, `private` is read by name, in any place of the top object. A 200 with no boolean `private` (no member, a string, null, only a nested one), or a body that is not a JSON object, is `BadBody` (exit 15, nothing kept).
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
								and verdict(200, "{\"id\":1,\"name\":\"lib\"}")
									== BadBody
									and verdict(200, "{\"private\":\"false\"}")
										== BadBody
										and verdict(200, "{\"private\":null}")
											== BadBody
											and verdict(200, "{\"owner\":{\"private\":false}}")
												== BadBody
												and verdict(200, "<html>rate limited</html>")
													== BadBody
													and verdict(200, "")
														== BadBody
														and verdict(200, "[false]")
															== BadBody
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

# R-RG4 row 4, R-E6, G-C39: the failure for an answer with no boolean private (or not JSON): kind network (exit 15), the text names the URL. The text is a proposal (TW24).
expect {
	fail = PrivacyGuard.bad_body({ url: "https://api.github.com/repos/acme/lib" })
	fail.kind.code()
		== 15
		and fail.message
			== "the answer of GitHub for https://api.github.com/repos/acme/lib is not a repository answer: it has no member private that is true or false. Try again later."
}
