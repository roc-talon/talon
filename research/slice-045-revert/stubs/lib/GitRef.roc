import Args
import Fail
import Github
import Net
import Nightlies
import Ref
import Scope

## The pure decisions of `tln roc install --git`, `tln roc install @<sha>` and `tln roc default --git` (slice 045, CLI 6.6, R-R1 to R-R3, R-R5, R-R7, R-R9 to R-R11, R-SE12, R-DA3): the ref that the user typed, the requests to GitHub,
## the nightly note and the header line. The command code is `GitInstall` and `GitDefault`. The bodies are the work of the code agent. The contract is in the doc comments (tables). Texts that the design does not give are a
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
	read = |_facts| crash "todo: slice 045"

	## R-R1, R-R7: the repo URL that `.talon.json` records, whatever the API base is: `https://github.com/<owner>/<repo>`.
	repo_url : GitRef.Source -> Str
	repo_url = |_source| crash "todo: slice 045"

	## `<owner>/<repo>@<ref>`.
	name_text : GitRef.Source -> Str
	name_text = |_source| crash "todo: slice 045"

	## The request that fixes a ref to a commit (question Q1: the design says "a branch or tag is fixed to a commit at install time" and does not name the request): `<api>/repos/<owner>/<repo>/commits/<ref>`.
	## `api` is `Net.Settings.api` (`https://api.github.com`, or `TALON_GITHUB_API`: R-EV19).
	commit_url : { api : Str, source : GitRef.Source } -> Str
	commit_url = |_facts| crash "todo: slice 045"

	## The headers of the commit request: `Net.headers({ token, etag: Err(None) })` (the request goes to the GitHub API, so it has the token as the release list has it: R-RG3, review Q1; R-DI9 excludes only an archive and `.roc-version`), then
	## `Accept: application/vnd.github.sha` (the answer is the 40 hex digits as text, not the JSON of the commit, which has all the changed files). `token` is `Net.token` of the plan of `Net.Settings.token` and the answer of `gh`.
	commit_headers : { token : Try(Str, [None]) } -> List((Str, Str))
	commit_headers = |_facts| crash "todo: slice 045"

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
	commit_of = |_facts| crash "todo: slice 045"

	## R-R1: the id of a build: `git-` and the first 8 characters of the full sha.
	sha_id : Str -> Str
	sha_id = |_sha| crash "todo: slice 045"

	## R-R3: the source archive: `<api>/repos/<owner>/<repo>/tarball/<sha>` with the full sha. `<api>` redirects to `codeload.github.com`.
	archive_url : { api : Str, source : GitRef.Source, sha : Str } -> Str
	archive_url = |_facts| crash "todo: slice 045"

	## R-R2: the note when the commit is the commit of a nightly. The tag of a nightly ends with the first 7 or more digits of its commit, so a nightly is the commit when `sha` starts with the sha of its tag
	## (`Nightlies.parts`). Only a nightly that the host can download counts (`Nightlies.candidates`). The first one in the list wins. The text is the design text:
	## `<first 8 of sha> is <tag>. tln roc install <tag> downloads it.` No such nightly: `Err(None)`.
	nightly_note : { sha : Str, releases : List(Nightlies.Release) } -> Try(Str, [None])
	nightly_note = |_facts| crash "todo: slice 045"

	## The first line of the design example of R-D4: `Build roc from <owner>/<repo>@<ref> (<first 8 of sha>)`.
	header_line : { source : GitRef.Source, sha : Str } -> Str
	header_line = |_facts| crash "todo: slice 045"

	## R-D3 (slice 044, question Q4): the target of the LLVM bundle line of the dependency list. The design gives `x86_64-linux-musl`. The others are a proposal (TW24):
	##
	## | Host | Text |
	## | --- | --- |
	## | `LinuxX64`, `LinuxArm64` | `x86_64-linux-musl`, `aarch64-linux-musl` |
	## | `MacosApple`, `MacosX64` | `aarch64-macos`, `x86_64-macos` |
	## | `WindowsX64`, `WindowsArm64` | `x86_64-windows`, `aarch64-windows` |
	llvm_target : Nightlies.Host -> Str
	llvm_target = |_host| crash "todo: slice 045"

	## R-DA3: the failure when the download program is `wget` (only `wget` is on `PATH`, or `TALON_DOWNLOADER=wget`): kind `Environment` (exit 18), the message names curl:
	## `tln roc install --git needs curl, but the download program is wget: a source archive has no published hash, and only curl refuses a redirect to http:// (R-DA3)`.
	needs_curl : {} -> Fail
	needs_curl = |_none| crash "todo: slice 045"

	## R-DI12: `--offline` and a ref: the commit cannot be found with no request. Kind `Network` (exit 15): `<owner>/<repo>@<ref> needs a request to find its commit, and --offline is set`.
	offline_failure : GitRef.Source -> Fail
	offline_failure = |_source| crash "todo: slice 045"
}
