import Fail
import JsonDoc
import ToolBin
import ToolsJson

## The check of prebuilt project tool binaries at lock time (slice 092, CLI 6.4: R-PT20, R-PT23, R-PT24; Design R-SE20, Q133, Q169). Part A (pure, TESTING.md 2.2). The flow (the release call, the downloads, the `gh` runs, the temp files) is command code and not in this module.
## The texts are proposals (TW24).
##
## ```mermaid
## flowchart TD
##     S["source: github.com url"] --> A["release_assets: the assets with a digest"]
##     A --> B["found: the targets that have the asset (none: end, no note)"]
##     B --> D["gate: gh found, new enough, logged in"]
##     D -->|"NoGh, GhOld"| N["skip_note, nothing is downloaded"]
##     D -->|"Ready"| E["verify the bundle: signers, bundle_signer"]
##     E -->|"Err"| X["bundle_note, nothing is downloaded"]
##     E -->|"Ok"| C["download, sha256, digest_check (exit 16 on a mismatch)"]
##     C --> F["verify each binary: signers, judge"]
##     F -->|"Ok"| G["a value in bin, summary"]
##     F -->|"Err"| H["no value, target_note"]
## ```
ToolBinCheck :: [].{

	## How a child ended (`Fx.spawn_all!`).
	Ended : [Exited(I32), Signaled(I32), NotStarted(Str)]

	## One verified attestation: the commit (`sourceRepositoryDigest`) and the workflow with its ref (`buildSignerURI`).
	Signer : { commit : Str, workflow : Str }

	## The result of `gate`.
	Gate : [Ready, NoGh, GhOld]

	## Why the check did not run (the two failures of `gate`).
	Skip : [NoGh, GhOld]

	## R-PT20 step 1: the assets of the body of `GET /repos/<owner>/<repo>/releases/tags/<tag>` (the field `assets`, each with `name` and `digest`). An asset whose `digest` is not `sha256:<64 lower case hex digits>` (missing, null, another algorithm) is not in the list: it counts as no binary. The `digest` has no prefix in the result. A body with no `assets` gives `Ok([])`. A body that is not JSON, or not an object, gives `Err(BadJson)`.
	release_assets : Str -> Try(List({ name : Str, digest : Str }), [BadJson])
	release_assets = |body| match JsonDoc.parse(body) {
		Ok(Obj(fields)) => match fields.find_first(|(k, _)| k == "assets") {
			Ok((_, Arr(items))) => Ok(items.keep_oks(asset_of))
			_ => Ok([])
		}
		_ => Err(BadJson)
	}

	## R-PT20 step 1 in direct mode (Q9, Q239): the assets of the release with `tag` in the pages of the release list of R-DI2 that the command already read. Each page is a JSON array of releases (`tag_name`, `assets`). The first release with the tag wins. A page that is not an array, no release with the tag, or a release with no `assets`: no asset. The rules of `release_assets` apply to each asset.
	list_assets : { pages : List(Str), tag : Str } -> List({ name : Str, digest : Str })
	list_assets = |facts| {
		releases = facts.pages.join_map(
			|page| match JsonDoc.parse(page) {
				Ok(Arr(items)) => items
				_ => []
			},
		)
		with_tag = releases.find_first(
			|r| match r {
				Obj(fields) => ToolsJson.text_of(fields, "tag_name") == Ok(facts.tag)
				_ => Bool.False
			},
		)
		match with_tag {
			Ok(Obj(fields)) => match fields.find_first(|(k, _)| k == "assets") {
				Ok((_, Arr(items))) => items.keep_oks(asset_of)
				_ => []
			}
			_ => []
		}
	}

	## R-PT20 step 1, R-PT17: the targets of `want` (text order) that have the asset `ToolBin.asset_name({ hash, target })` in `assets`, each with the digest of the asset. No other target: no value, no note.
	found : { hash : Str, want : List(Str), assets : List({ name : Str, digest : Str }) } -> List({ target : Str, digest : Str })
	found = |facts| facts.want.keep_oks(
		|target| {
			name = ToolBin.asset_name({ hash: facts.hash, target })
			match facts.assets.find_first(|a| a.name == name) {
				Ok(a) => Ok({ target, digest: a.digest })
				Err(_) => Err(NoAsset)
			}
		},
	)

	## R-PT20 step 2, R-PT24: the sha256 of the download against the `digest` of the release. Equal: `Ok`. Not equal: a failure of kind `Integrity` (exit 16, as R-CV4), the only failure that stops the command: `the <target> binary of <key> <version> has the sha256 <sha256>, but the release digest is <digest>. Talon deleted the file.`
	digest_check : { key : Str, version : Str, target : Str, digest : Str, sha256 : Str } -> Try({}, Fail)
	digest_check = |facts| if facts.sha256 == facts.digest {
		Ok({})
	} else {
		Err(Fail.new(Integrity, "the ${facts.target} binary of ${facts.key} ${facts.version} has the sha256 ${facts.sha256}, but the release digest is ${facts.digest}. Talon deleted the file."))
	}

	## R-PT20 step 3: the argument list of the version probe: `gh attestation verify --repo <repo> --source-ref refs/tags/<tag> --deny-self-hosted-runners --format json --help` (`repo` is `owner/repo`, `tag` has no `refs/tags/`). Exit code 0 is a `gh` that is new enough (2.68.0 or later, Q169). Talon reads no version text.
	help_argv : { repo : Str, tag : Str } -> List(Str)
	help_argv = |facts| ["gh", "attestation", "verify", "--repo", facts.repo, "--source-ref", "refs/tags/${facts.tag}", "--deny-self-hosted-runners", "--format", "json", "--help"]

	## R-PT20 step 4: the argument list of one check: `gh attestation verify <file> --repo <repo> --source-ref refs/tags/<tag> --deny-self-hosted-runners --format json`.
	verify_argv : { file : Str, repo : Str, tag : Str } -> List(Str)
	verify_argv = |facts| ["gh", "attestation", "verify", facts.file, "--repo", facts.repo, "--source-ref", "refs/tags/${facts.tag}", "--deny-self-hosted-runners", "--format", "json"]

	## R-PT20 step 3: the state of `gh`. `found` is the answer of `programs!`. `help` is the end of `help_argv` (`NotAsked` when `gh` is not there), `auth` is the end of `gh auth status` (`NotAsked` when the help run did not pass).
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `gh` is not on `PATH` | `NoGh` |
	## | 2 | The help run did not end with `Exited(0)` (an unknown command or flag, a signal, no start) | `GhOld` |
	## | 3 | `gh auth status` did not end with `Exited(0)` | `NoGh` |
	## | 4 | Else | `Ready` |
	gate : { found : Bool, help : Try(ToolBinCheck.Ended, [NotAsked]), auth : Try(ToolBinCheck.Ended, [NotAsked]) } -> ToolBinCheck.Gate
	gate = |facts| if !facts.found {
		NoGh
	} else if facts.help != Ok(Exited(0)) {
		GhOld
	} else if facts.auth != Ok(Exited(0)) {
		NoGh
	} else {
		Ready
	}

	## R-PT20 step 4 and 5: the attestations of one run of `gh attestation verify`. `last_line` is the last stderr line.
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `Exited(0)` and a JSON array: one `Signer` for each element that has `verificationResult.signature.certificate.sourceRepositoryDigest` and `buildSignerURI` | `Ok(list)` |
	## | 2 | `Exited(0)`, the array has no such element (also the empty array) | `Err("no attestation")` |
	## | 3 | `Exited(0)` and the output is not a JSON array | `Err("gh gave no readable JSON")` |
	## | 4 | `Exited(n)` | `Err("gh exit <n>: <last_line>")`, with no `: ` part when `last_line` is empty |
	## | 5 | `Signaled(n)` | `Err("gh signal <n>: <last_line>")`, the same rule |
	## | 6 | `NotStarted(text)` | `Err("gh not started: <text>")` |
	signers : { ended : ToolBinCheck.Ended, stdout : Str, last_line : Str } -> Try(List(ToolBinCheck.Signer), Str)
	signers = |facts| match facts.ended {
		Exited(0) => match JsonDoc.parse(facts.stdout) {
			Ok(Arr(items)) => match items.keep_oks(signer_of) {
				[] => Err("no attestation")
				some => Ok(some)
			}
			_ => Err("gh gave no readable JSON")
		}
		Exited(n) => Err("gh exit ${n.to_str()}${with_line(facts.last_line)}")
		Signaled(n) => Err("gh signal ${n.to_str()}${with_line(facts.last_line)}")
		NotStarted(text) => Err("gh not started: ${text}")
	}

	## R-PT20 step 3 (Design Q232, Q235): the one signer of the bundle. The verified attestations of the bundle must name one commit and one workflow file (`buildSignerURI`, so the file and its ref). The same signer twice is a re-run (allowed): `Ok(signer)`. Two or more commits or workflow files, or no attestation: `Err(reason)`:
	## `the bundle has attestations at more than one commit (<8 hex>, <8 hex>)` (the first two distinct commits, in the order of the list), `the bundle has attestations of more than one workflow file (<file>, <file>)` (commits equal), `no attestation` for the empty list.
	bundle_signer : List(ToolBinCheck.Signer) -> Try(ToolBinCheck.Signer, Str)
	bundle_signer = |list| match list {
		[] => Err("no attestation")
		[first, ..] => match list.find_first(|s| s.commit != first.commit) {
			Ok(other) => Err("the bundle has attestations at more than one commit (${short(first.commit)}, ${short(other.commit)})")
			Err(_) => match list.find_first(|s| s.workflow != first.workflow) {
				Ok(other) => Err("the bundle has attestations of more than one workflow file (${ToolBinCheck.workflow_file(first.workflow)}, ${ToolBinCheck.workflow_file(other.workflow)})")
				Err(_) => Ok(first)
			}
		}
	}

	## R-PT20 step 5 (Q235): a binary passes when one of its verified attestations equals the signer of the bundle. Else `Err(reason)`, from the first attestation of the binary (the note of that target): `the bundle was attested at commit <8 hex> and the binary at commit <8 hex>` when the commits differ,
	## `the bundle was attested by <file> and the binary by <file>` when the commits are the same (a proposal, TW24). An empty list: `no attestation`.
	judge : { bundle : ToolBinCheck.Signer, binary : List(ToolBinCheck.Signer) } -> Try({}, Str)
	judge = |facts| if facts.binary.any(|s| s == facts.bundle) {
		Ok({})
	} else {
		match facts.binary {
			[] => Err("no attestation")
			[first, ..] => if first.commit != facts.bundle.commit {
				Err("the bundle was attested at commit ${short(facts.bundle.commit)} and the binary at commit ${short(first.commit)}")
			} else {
				Err("the bundle was attested by ${ToolBinCheck.workflow_file(facts.bundle.workflow)} and the binary by ${ToolBinCheck.workflow_file(first.workflow)}")
			}
		}
	}

	## R-PT20 step 1, Q234: the repository and the tag of a release `url` on `github.com` (`https://github.com/<owner>/<repo>/releases/download/<tag>/<hash>.tar.zst`): `repo` is `owner/repo`, `tag` has no `refs/tags/`. Any other host (a loopback URL, another forge): `Err(NotGithub)`. The check does not run for it, with no note, and a new `url` gets no `bin` key.
	source : Str -> Try({ repo : Str, tag : Str }, [NotGithub])
	source = |url| match url.drop_prefix("https://github.com/").split_on("/") {
		[owner, repo, "releases", "download", tag, _file] if url.starts_with("https://github.com/") and !owner.is_empty() and !repo.is_empty() and !tag.is_empty() => Ok({ repo: "${owner}/${repo}", tag })
		_ => Err(NotGithub)
	}

	## R-PT23: the workflow file of a `buildSignerURI`: `https://github.com/<owner>/<repo>/.github/workflows/release.yml@refs/tags/1.0.3` gives `.github/workflows/release.yml`.
	workflow_file : Str -> Str
	workflow_file = |uri| {
		path = match uri.split_first("@") {
			Ok({ before, .. }) => before
			Err(_) => uri
		}
		match path.split_first("/.github/") {
			Ok({ after, .. }) => ".github/${after}"
			Err(_) => path
		}
	}

	## R-PT23: the line of a command that locked binaries, on stderr: `roc-cfw 1.0.3: attested binaries for arm64mac, x64musl (commit 1a2b3c4d, .github/workflows/release.yml)`. `names` are the targets with a value after the check, in text order. The commit is shortened to 8 characters.
	summary : { key : Str, version : Str, names : List(Str), commit : Str, workflow : Str } -> Str
	summary = |facts| "${facts.key} ${facts.version}: attested binaries for ${Str.join_with(facts.names, ", ")} (commit ${short(facts.commit)}, ${ToolBinCheck.workflow_file(facts.workflow)})"

	## R-PT23: the note of a target that has an asset and no value: `note: roc-cfw 1.0.3 x64win: no valid attestation (<reason>). It builds from source.`
	target_note : { key : Str, version : Str, target : Str, reason : Str } -> Str
	target_note = |facts| "note: ${facts.key} ${facts.version} ${facts.target}: no valid attestation (${facts.reason}). It builds from source."

	## R-PT23 (Q232): the note for a bundle that has no valid attestation (R-PT20 step 3), one line for the tool: `note: roc-cfw 1.0.3: the bundle has no valid attestation (<reason>). Each target builds from source.`
	bundle_note : { key : Str, version : Str, reason : Str } -> Str
	bundle_note = |facts| "note: ${facts.key} ${facts.version}: the bundle has no valid attestation (${facts.reason}). Each target builds from source."

	## R-PT23: the note when the check did not run, once for the command, only when step 1 found at least one binary asset: `NoGh` (no `gh`, or not logged in) and `GhOld`. The texts are those of R-PT23.
	skip_note : { key : Str, version : Str, skip : ToolBinCheck.Skip } -> Str
	skip_note = |facts| match facts.skip {
		NoGh => "note: binaries of ${facts.key} ${facts.version} not checked (needs gh, logged in). Each target builds from source. To lock them, run tln update ${facts.key} with gh."
		GhOld => "note: binaries of ${facts.key} ${facts.version} not checked (gh is too old, needs 2.68.0 or later). Each target builds from source. To lock them, update gh and run tln update ${facts.key}."
	}

	## R-PT23, R-OUT4: the value of `bin_skip` in the row of `data.tools`: `no-gh` or `gh-old` (the row has `null` when the check ran).
	skip_name : ToolBinCheck.Skip -> Str
	skip_name = |skip| match skip {
		NoGh => "no-gh"
		GhOld => "gh-old"
	}
}

# One asset of the release body: a name and a `sha256:<64 hex>` digest. Else it counts as no binary.
asset_of : JsonDoc -> Try({ name : Str, digest : Str }, [NoAsset])
asset_of = |item| match item {
	Obj(fields) => match (ToolsJson.text_of(fields, "name"), ToolsJson.text_of(fields, "digest")) {
		(Ok(name), Ok(digest)) => match digest.split_first("sha256:") {
			Ok({ before: "", after }) if ToolBin.is_sha256(after) => Ok({ name, digest: after })
			_ => Err(NoAsset)
		}
		_ => Err(NoAsset)
	}
	_ => Err(NoAsset)
}

# One element of the `gh` output: the commit and the signer of its certificate.
signer_of : JsonDoc -> Try(ToolBinCheck.Signer, [NoSigner])
signer_of = |item| match item {
	Obj(fields) => {
		cert = ToolsJson.object_of(ToolsJson.object_of(ToolsJson.object_of(fields, "verificationResult"), "signature"), "certificate")
		match (ToolsJson.text_of(cert, "sourceRepositoryDigest"), ToolsJson.text_of(cert, "buildSignerURI")) {
			(Ok(commit), Ok(workflow)) => Ok({ commit, workflow })
			_ => Err(NoSigner)
		}
	}
	_ => Err(NoSigner)
}

with_line : Str -> Str
with_line = |line| if line.is_empty() "" else ": ${line}"

# The first 8 characters of a commit.
short : Str -> Str
short = |commit| Str.from_utf8_lossy(commit.to_utf8().take_first(8))
