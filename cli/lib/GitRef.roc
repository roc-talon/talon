import Args
import Fail
import Github
import Net
import Nightlies
import Ref
import Scope
import Selector

## The pure decisions of `tln roc install --git`, `tln roc install @<sha>` and `tln roc default --git` (slice 045, CLI 6.6, R-R1 to R-R3, R-R5, R-R7, R-R9 to R-R11, R-SE12, R-DA3): the ref that the user typed, the requests to GitHub,
## the nightly note and the header line. The command code is `GitInstall` and `GitDefault`. The contract is in the doc comments (tables). Texts that the design does not give are a
## proposal (R-OUT2, TW24): `docs/slices/045-git-install.md`, section "Output". The tests are `tests/unit/GitTest.roc`.
##
## What the user types (R-SL1, R-SL2, R-SL8, R-SL10, R-SL13, R-FL14). `--git` is a flag, the ref is the operand:
##
## | Words | Source |
## | --- | --- |
## | `roc install --git @main` (R-R9) | `roc-lang/roc`, ref `main` (the short form of `tln roc` is `roc-lang/roc`, R-SL2) |
## | `roc install --git Karakatiza666/roc@my-branch` (R-R10) | `Karakatiza666/roc`, ref `my-branch` |
## | `roc install @dd03c09e` (R-R11) | `roc-lang/roc`, ref `dd03c09e` (a sha needs no `--git`: hex only, 7 or more digits, R-SL10) |
## | `roc install Karakatiza666/roc@dd03c09e` | the same with another repo |
## | `roc default --git Karakatiza666/roc@my-branch` (R-R5) | `Karakatiza666/roc`, ref `my-branch` |
GitRef :: [].{

	## The repo on GitHub and the ref as the user typed it: a branch, a tag, or a sha (7 to 40 hex digits). The ref text is what `.talon.json` records (R-R1).
	Source : { owner : Str, repo : Str, ref : Str }

	## The operand of `tln roc install` and `tln roc default` as a git source. `bare_sha` is `True` for `roc install` (R-R11: a sha selector needs no `--git`), `False` for `roc default` (R-R5 names `--git`).
	## `Ref.parse(operand, Scope.Roc, git)` reads the operand (R-SL1, R-SL2, R-SL13: with `--git` each selector is a git ref, also `latest`). The result:
	##
	## | Case | Result |
	## | --- | --- |
	## | `--git` and one operand with a git ref (`GitRef` or `GitSha` selector) of the form `owner/repo@ref` or `@ref` | `Ok(Ok(source))` |
	## | no `--git`, `bare_sha`, one operand with a `GitSha` selector (`@dd03c09e`, `owner/repo@dd03c09e`) | `Ok(Ok(source))` |
	## | no `--git`, any other operand (a nightly tag with or without `@`, `@latest`, `@-1`, a prefix, a release version, a bad selector) or no operand or 2 or more | `Ok(Err(NotGit))`: the old command reads it |
	## | `--git`, no operand | `Err(Usage)`: `tln <typed> --git needs one ref: owner/repo@ref or @ref` (`typed` is `Args.typed`: `roc install`, `roc i`, `roc default`) |
	## | `--git`, 2 operands or more | `Err(Usage)`: `tln <typed> --git takes one ref, got <n>` |
	## | `--git`, a failure of `Ref.parse` | that failure |
	## | `--git`, an operand with no selector, a name that is not `owner/repo` | Question Q2, not decided by the design and not tested. The reference gives `Err(Usage)`. |
	read : { args : Args, bare_sha : Bool } -> Try(Try(GitRef.Source, [NotGit]), Fail)
	read = |facts| {
		args = facts.args
		git = args.options.any(|(flag, _)| flag == "--git")
		if git {
			match args.operands {
				[] => Err(Fail.new(Usage, "tln ${args.typed} --git needs one ref: owner/repo@ref or @ref"))
				[one] => git_source(one).map_ok(|source| Ok(source))
				many => Err(Fail.new(Usage, "tln ${args.typed} --git takes one ref, got ${many.len().to_str()}"))
			}
		} else if facts.bare_sha {
			match args.operands {
				[one] => Ok(sha_source(one))
				_ => Ok(Err(NotGit))
			}
		} else {
			Ok(Err(NotGit))
		}
	}

	## R-R1, R-R7: the repo URL that `.talon.json` records, whatever the API base is: `https://github.com/<owner>/<repo>`.
	repo_url : GitRef.Source -> Str
	repo_url = |source| "https://github.com/${source.owner}/${source.repo}"

	## `<owner>/<repo>@<ref>`.
	name_text : GitRef.Source -> Str
	name_text = |source| "${source.owner}/${source.repo}@${source.ref}"

	## The request that fixes a ref to a commit (question Q1: the design says "a branch or tag is fixed to a commit at install time" and does not name the request): `<api>/repos/<owner>/<repo>/commits/<ref>`.
	## `api` is `Net.Settings.api` (`https://api.github.com`, or `TALON_GITHUB_API`: R-EV19).
	commit_url : { api : Str, source : GitRef.Source } -> Str
	commit_url = |facts| "${facts.api}/repos/${facts.source.owner}/${facts.source.repo}/commits/${facts.source.ref}"

	## The headers of the commit request: `Net.headers({ token, etag: Err(None) })` (the request goes to the GitHub API, so it has the token as the release list has it: R-RG3, review Q1; R-DI9 excludes only an archive and `.roc-version`), then
	## `Accept: application/vnd.github.sha` (the answer is the 40 hex digits as text, not the JSON of the commit, which has all the changed files). `token` is `Net.token` of the plan of `Net.Settings.token` and the answer of `gh`.
	commit_headers : { token : Try(Str, [None]) } -> List((Str, Str))
	commit_headers = |facts| Net.headers({ token: facts.token, etag: Err(None) }).append(("Accept", "application/vnd.github.sha"))

	## The answer of the commit request. `now` is the real clock (for the reset time of a rate limit).
	##
	## | Answer | Result |
	## | --- | --- |
	## | 200, the body is 40 lower case hex digits (a line end at the end is cut) | `Ok(sha)` |
	## | 200, any other body (short, upper case, 41 digits, JSON, empty) | `Err(Network)`: `GitHub gave no commit sha for <owner>/<repo>@<ref> at <url>` |
	## | a rate limit (`Github.rate_limit` gives `Ok`) | `Github.rate_limit_failure` (R-DI13, exit 15) |
	## | 404 or 422, no rate limit | `Err(Usage)`: `no commit <ref> in <owner>/<repo>`. The real API answers 404 for a missing repo and 422 for a ref that does not exist. |
	## | any other status | `Github.status_failure({ url, status })` |
	commit_of : { source : GitRef.Source, url : Str, now : U64, status : U16, headers : List((Str, Str)), body : Str } -> Try(Str, Fail)
	commit_of = |facts| match Github.rate_limit({ status: facts.status, headers: facts.headers, now: facts.now }) {
		Ok({ reset }) => Err(Github.rate_limit_failure({ reset: reset }))
		Err(NotLimited) => match facts.status {
			200 => {
				sha = facts.body.trim_end()
				if is_full_sha(sha) {
					Ok(sha)
				} else {
					Err(Fail.new(Network, "GitHub gave no commit sha for ${GitRef.name_text(facts.source)} at ${facts.url}"))
				}
			}
			404 | 422 => Err(Fail.new(Usage, "no commit ${facts.source.ref} in ${facts.source.owner}/${facts.source.repo}"))
			status => Err(Github.status_failure({ url: facts.url, status }))
		}
	}

	## R-R1: the id of a build: `git-` and the first 8 characters of the full sha.
	sha_id : Str -> Str
	sha_id = |sha| "git-${sha8(sha)}"

	## R-R3: the source archive: `<api>/repos/<owner>/<repo>/tarball/<sha>` with the full sha. `<api>` redirects to `codeload.github.com`.
	archive_url : { api : Str, source : GitRef.Source, sha : Str } -> Str
	archive_url = |facts| "${facts.api}/repos/${facts.source.owner}/${facts.source.repo}/tarball/${facts.sha}"

	## R-R2: the note when the commit is the commit of a nightly. The tag of a nightly ends with the first 7 or more digits of its commit, so a nightly is the commit when `sha` starts with the sha of its tag
	## (`Nightlies.parts`). Only a nightly that the host can download counts (`Nightlies.candidates`). The first one in the list wins. The text is the design text:
	## `<first 8 of sha> is <tag>. tln roc install <tag> downloads it.` No such nightly: `Err(None)`.
	nightly_note : { sha : Str, releases : List(Nightlies.Release) } -> Try(Str, [None])
	nightly_note = |facts| match Nightlies.candidates(facts.releases).find_first(|release| is_commit_of(release.id, facts.sha)) {
		Ok(release) => Ok("${sha8(facts.sha)} is ${release.id}. tln roc install ${release.id} downloads it.")
		Err(NotFound) => Err(None)
	}

	## The first line of the design example of R-D4: `Build roc from <owner>/<repo>@<ref> (<first 8 of sha>)`.
	header_line : { source : GitRef.Source, sha : Str } -> Str
	header_line = |facts| "Build roc from ${GitRef.name_text(facts.source)} (${sha8(facts.sha)})"

	## R-D3 (slice 044, question Q4): the target of the LLVM bundle line of the dependency list. The design gives `x86_64-linux-musl`. The others are a proposal (TW24):
	##
	## | Host | Text |
	## | --- | --- |
	## | `LinuxX64`, `LinuxArm64` | `x86_64-linux-musl`, `aarch64-linux-musl` |
	## | `MacosApple`, `MacosX64` | `aarch64-macos`, `x86_64-macos` |
	## | `WindowsX64`, `WindowsArm64` | `x86_64-windows`, `aarch64-windows` |
	llvm_target : Nightlies.Host -> Str
	llvm_target = |host| match host {
		LinuxX64 => "x86_64-linux-musl"
		LinuxArm64 => "aarch64-linux-musl"
		MacosApple => "aarch64-macos"
		MacosX64 => "x86_64-macos"
		WindowsX64 => "x86_64-windows"
		WindowsArm64 => "aarch64-windows"
	}

	## R-DA3: the failure when the download program is `wget` (only `wget` is on `PATH`, or `TALON_DOWNLOADER=wget`): kind `Environment` (exit 18), the message names curl:
	## `tln roc install --git needs curl, but the download program is wget: a source archive has no published hash, and only curl refuses a redirect to http:// (R-DA3)`.
	needs_curl : {} -> Fail
	needs_curl = |_none| Fail.new(Environment, "tln roc install --git needs curl, but the download program is wget: a source archive has no published hash, and only curl refuses a redirect to http:// (R-DA3)")

	## R-DI12: `--offline` and a ref: the commit cannot be found with no request. Kind `Network` (exit 15): `<owner>/<repo>@<ref> needs a request to find its commit, and --offline is set`.
	offline_failure : GitRef.Source -> Fail
	offline_failure = |source| Fail.new(Network, "${GitRef.name_text(source)} needs a request to find its commit, and --offline is set")
}

# The first 8 characters of a sha (R-R1).
sha8 : Str -> Str
sha8 = |sha| Str.from_utf8_lossy(sha.to_utf8().take_first(8))

is_hex : U8 -> Bool
is_hex = |byte| (byte >= '0' and byte <= '9') or (byte >= 'a' and byte <= 'f')

# 40 lower case hex digits.
is_full_sha : Str -> Bool
is_full_sha = |text| text.count_utf8_bytes() == 40 and text.to_utf8().all(is_hex)

# R-R2: the tag of a nightly names the start of its commit.
is_commit_of : Str, Str -> Bool
is_commit_of = |tag, sha| match Nightlies.parts(tag) {
	Ok(parts) => sha.starts_with(parts.sha)
	Err(NotNightly) => Bool.False
}

# The owner, the repo and the ref of a parsed operand. A failure is a usage failure (question Q2: no guess).
git_source : Str -> Try(GitRef.Source, Fail)
git_source = |text| {
	parsed = Ref.parse(text, Scope.Roc, Bool.True)?
	if parsed.form != Full {
		return Err(Fail.new(Usage, "--git takes a GitHub repository as owner/repo, not '${parsed.name}'"))
	}
	match (parsed.name.split_first("/"), ref_of(parsed.selector)) {
		(Ok({ before, after }), Ok(ref)) => Ok({ owner: before, repo: after, ref })
		_ => Err(Fail.new(Usage, "'${text}' has no ref: use owner/repo@ref or @ref"))
	}
}

# R-R11: a sha selector needs no `--git`. Any other operand is for the old command.
sha_source : Str -> Try(GitRef.Source, [NotGit])
sha_source = |text| match Ref.parse(text, Scope.Roc, Bool.False) {
	Ok(parsed) => match (parsed.form, parsed.selector, parsed.name.split_first("/")) {
		(Full, Ok(GitSha(ref)), Ok({ before, after })) => Ok({ owner: before, repo: after, ref })
		_ => Err(NotGit)
	}
	Err(_) => Err(NotGit)
}

ref_of : Try(Selector, [None]) -> Try(Str, [NoRef])
ref_of = |selector| match selector {
	Ok(GitRef(text)) => Ok(text)
	Ok(GitSha(text)) => Ok(text)
	_ => Err(NoRef)
}
