import lib.Fail
import lib.ToolBin
import lib.ToolBinCheck

ToolbincheckTest :: [].{}

# Slice 092 (docs/slices/092-prebuilt-bin-check.md): the lock-time check of prebuilt project tool binaries, the pure parts (CLI 6.4: R-PT20, R-PT23, R-PT24; Design R-SE20, Q133, Q169). The expected value of each row is the design text or the slice file text, not the code.
# Texts that the design does not give are the proposals of the slice file (TW24). The shape of the JSON is that of `gh` 2.6x and of the release Karakatiza666/roc-cloudflare-workers-cli 0.0.2-pre1 (the slice file, section 4).

hash = "GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW"

h1 = Str.repeat("a", 64)

h2 = Str.repeat("b", 64)

c1 = "1a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d"

c2 = "ffffffffffffffffffffffffffffffffffffffff"

wf = "https://github.com/acme/foo/.github/workflows/release.yml@refs/tags/1.0.3"

other_wf = "https://github.com/acme/foo/.github/workflows/other.yml@refs/tags/1.0.3"

# R-PT20 step 1: the body of `releases/tags/<tag>` has `assets` with `name` and `digest`. Only `sha256:<64 hex>` counts: a missing digest, `null`, a bare hex digest and another algorithm are no binary. Not JSON, or not an object: `BadJson`.
expect {
	asset = |name, digest| "{\"name\":\"${name}\",\"size\":10,\"digest\":${digest},\"browser_download_url\":\"https://x/${name}\"}"
	body = "{\"tag_name\":\"1.0.3\",\"assets\":[${asset("a", "\"sha256:${h1}\"")},${asset("b", "null")},${asset("c", "\"sha512:${h1}\"")},{\"name\":\"d\"},${asset("g", "\"${h1}\"")},${asset("e", "\"sha256:${Str.repeat("A", 64)}\"")},${asset("f", "\"sha256:${h2}\"")}]}"
	ToolBinCheck.release_assets(body) == Ok([{ name: "a", digest: h1 }, { name: "f", digest: h2 }]) and ToolBinCheck.release_assets("{\"tag_name\":\"x\"}") == Ok([]) and ToolBinCheck.release_assets("[1]") == Err(BadJson) and ToolBinCheck.release_assets("nope") == Err(BadJson)
}

# R-PT20 step 1, R-PT17: a target is in the result when `want` has it and the release has the asset of its name (with a digest). The result is in text order. No other target: no value, no note.
expect {
	assets = [
		{ name: ToolBin.asset_name({ hash, target: "x64win" }), digest: h2 },
		{ name: ToolBin.asset_name({ hash, target: "x64musl" }), digest: h1 },
		{ name: ToolBin.asset_name({ hash, target: "arm64mac" }), digest: h1 },
		{ name: "other-hash-x64mac", digest: h1 },
	]
	all = ToolBinCheck.found({ hash, want: ToolBin.all_targets, assets })
	some = ToolBinCheck.found({ hash, want: ["x64musl", "x64mac"], assets })
	none = ToolBinCheck.found({ hash, want: ToolBin.all_targets, assets: [] })
	# R-PT19, Q233: `want` is the targets with no value in `bin`, and a dry run shows the found ones as `would_check`.
	missing = ToolBinCheck.found({ hash, want: ToolBin.to_check(Ok(Hashes([{ target: "x64musl", sha256: h1 }]))), assets })
	all == [{ target: "arm64mac", digest: h1 }, { target: "x64musl", digest: h1 }, { target: "x64win", digest: h2 }] and some == [{ target: "x64musl", digest: h1 }] and none == [] and missing == [{ target: "arm64mac", digest: h1 }, { target: "x64win", digest: h2 }]
}

# R-PT20 step 2, R-PT24, R-SE20: a sha256 that is not the digest is exit code 16 and the only failure that stops the command.
expect {
	ok = ToolBinCheck.digest_check({ key: "roc-cfw", version: "1.0.3", target: "x64musl", digest: h1, sha256: h1 })
	bad = match ToolBinCheck.digest_check({ key: "roc-cfw", version: "1.0.3", target: "x64musl", digest: h1, sha256: h2 }) {
		Ok(_) => "ok"
		Err(e) => "${e.kind.code().to_str()} ${e.message}"
	}
	ok == Ok({}) and bad == "16 the x64musl binary of roc-cfw 1.0.3 has the sha256 ${h2}, but the release digest is ${h1}. Talon deleted the file."
}

# R-PT20 step 3, Q169: the two argument lists. The help run has the flags of step 4 and `--help`, so a `gh` that does not know a flag fails before the help text. The check has the file first.
expect {
	help = ToolBinCheck.help_argv({ repo: "acme/foo", tag: "1.0.3" })
	verify = ToolBinCheck.verify_argv({ file: "/t/x.tmp", repo: "acme/foo", tag: "1.0.3" })
	help == ["gh", "attestation", "verify", "--repo", "acme/foo", "--source-ref", "refs/tags/1.0.3", "--deny-self-hosted-runners", "--format", "json", "--help"] and verify == ["gh", "attestation", "verify", "/t/x.tmp", "--repo", "acme/foo", "--source-ref", "refs/tags/1.0.3", "--deny-self-hosted-runners", "--format", "json"]
}

# R-PT20 step 3, Q169, Q133: the state of `gh`. No `gh`, or not logged in: `NoGh`. A help run that fails (an unknown command or flag: `gh` older than 2.68.0): `GhOld`, also for a signal and a start failure.
expect {
	ok = Ok(Exited(0))
	rows = [
		(ToolBinCheck.gate({ found: Bool.False, help: Err(NotAsked), auth: Err(NotAsked) }), NoGh),
		(ToolBinCheck.gate({ found: Bool.True, help: Ok(Exited(1)), auth: Err(NotAsked) }), GhOld),
		(ToolBinCheck.gate({ found: Bool.True, help: Ok(Exited(127)), auth: Err(NotAsked) }), GhOld),
		(ToolBinCheck.gate({ found: Bool.True, help: Ok(Signaled(9)), auth: Err(NotAsked) }), GhOld),
		(ToolBinCheck.gate({ found: Bool.True, help: Ok(NotStarted("x")), auth: Err(NotAsked) }), GhOld),
		(ToolBinCheck.gate({ found: Bool.True, help: ok, auth: Ok(Exited(1)) }), NoGh),
		(ToolBinCheck.gate({ found: Bool.True, help: ok, auth: Ok(NotStarted("x")) }), NoGh),
		(ToolBinCheck.gate({ found: Bool.True, help: ok, auth: ok }), Ready),
	]
	rows.all(|(got, want)| got == want)
}

# R-PT20 step 4 and 5: the attestations of one `gh attestation verify` run, from the JSON of `--format json` (an array; each element has `verificationResult.signature.certificate`). An element with no commit or no signer is not counted. A run that does not end with 0 gives the reason with the last stderr line.
expect {
	elem = |commit, uri| "{\"attestation\":{\"bundle\":{}},\"verificationResult\":{\"signature\":{\"certificate\":{\"issuer\":\"https://token.actions.githubusercontent.com\",\"runnerEnvironment\":\"github-hosted\",\"sourceRepositoryDigest\":\"${commit}\",\"buildSignerURI\":\"${uri}\"}}}}"
	sig = |ended, stdout, last_line| ToolBinCheck.signers({ ended, stdout, last_line })
	two = "[${elem(c1, wf)},{\"verificationResult\":{}},${elem(c2, other_wf)}]"
	sig(Exited(0), two, "") == Ok([{ commit: c1, workflow: wf }, { commit: c2, workflow: other_wf }]) and sig(Exited(0), "[]", "") == Err("no attestation") and sig(Exited(0), "[{\"verificationResult\":{}}]", "") == Err("no attestation") and sig(Exited(0), "{}", "") == Err("gh gave no readable JSON") and sig(Exited(0), "nope", "") == Err("gh gave no readable JSON") and sig(Exited(1), "", "Error: no attestations found") == Err("gh exit 1: Error: no attestations found") and sig(Exited(1), "", "") == Err("gh exit 1") and sig(Signaled(9), "", "") == Err("gh signal 9") and sig(NotStarted("no gh"), "", "") == Err("gh not started: no gh")
}

# R-PT20 step 3, Q232, Q235, R-SE20: the verified attestations of the bundle must name one commit and one workflow file. The same signer twice (a re-run) is allowed. Two commits, or two workflow files, or none: no target passes, with a reason.
expect {
	a = { commit: c1, workflow: wf }
	b = { commit: c2, workflow: wf }
	c = { commit: c1, workflow: other_wf }
	one = |list| ToolBinCheck.bundle_signer(list)
	one([a]) == Ok(a) and one([a, a]) == Ok(a) and one([a, b]) == Err("the bundle has attestations at more than one commit (1a2b3c4d, ffffffff)") and one([a, c]) == Err("the bundle has attestations of more than one workflow file (.github/workflows/release.yml, .github/workflows/other.yml)") and one([a, a, b]) == Err("the bundle has attestations at more than one commit (1a2b3c4d, ffffffff)") and one([]) == Err("no attestation")
}

# R-PT20 step 5, Q235, R-SE20: a binary passes when one of its verified attestations is the signer of the bundle (the commit and the workflow file). Else a reason for the note of that target.
expect {
	a = { commit: c1, workflow: wf }
	b = { commit: c2, workflow: wf }
	c = { commit: c1, workflow: other_wf }
	judge = |binary| ToolBinCheck.judge({ bundle: a, binary })
	judge([a]) == Ok({}) and judge([b, a]) == Ok({}) and judge([b]) == Err("the bundle was attested at commit 1a2b3c4d and the binary at commit ffffffff") and judge([c]) == Err("the bundle was attested by .github/workflows/release.yml and the binary by .github/workflows/other.yml") and judge([]) == Err("no attestation")
}

# R-PT20 step 1, Q234: the repository and the tag of a release `url` on github.com. Another host (a loopback URL) or a URL that is not a release download: `NotGithub`, so no check, no note, no `bin` key.
expect {
	ok = ToolBinCheck.source("https://github.com/acme/foo/releases/download/1.0.3/${hash}.tar.zst")
	prefix = ToolBinCheck.source("https://github.com/acme/foo/releases/download/v2.0.0-rc1/${hash}.tar.zst")
	loop = ToolBinCheck.source("http://127.0.0.1:8080/acme/foo/releases/download/1.0.3/${hash}.tar.zst")
	forge = ToolBinCheck.source("https://gitlab.com/acme/foo/releases/download/1.0.3/${hash}.tar.zst")
	archive = ToolBinCheck.source("https://github.com/acme/foo/archive/main.tar.zst")
	ok == Ok({ repo: "acme/foo", tag: "1.0.3" }) and prefix == Ok({ repo: "acme/foo", tag: "v2.0.0-rc1" }) and loop == Err(NotGithub) and forge == Err(NotGithub) and archive == Err(NotGithub)
}

# R-PT23: the workflow file of a signer URI, the summary line, the three kinds of note and the `bin_skip` names. The texts are the examples of R-PT23.
expect {
	five = ["arm64mac", "arm64musl", "x64mac", "x64musl", "x64win"]
	ToolBinCheck.workflow_file(wf) == ".github/workflows/release.yml" and ToolBinCheck.summary({ key: "roc-cfw", version: "1.0.3", names: five, commit: c1, workflow: wf }) == "roc-cfw 1.0.3: attested binaries for arm64mac, arm64musl, x64mac, x64musl, x64win (commit 1a2b3c4d, .github/workflows/release.yml)" and ToolBinCheck.target_note({ key: "roc-cfw", version: "1.0.3", target: "x64win", reason: "gh exit 1: Error: no attestations found" }) == "note: roc-cfw 1.0.3 x64win: no valid attestation (gh exit 1: Error: no attestations found). It builds from source." and ToolBinCheck.skip_note({ key: "roc-cfw", version: "1.0.3", skip: NoGh }) == "note: binaries of roc-cfw 1.0.3 not checked (needs gh, logged in). Each target builds from source. To lock them, run tln update roc-cfw with gh." and ToolBinCheck.skip_note({ key: "roc-cfw", version: "1.0.3", skip: GhOld }) == "note: binaries of roc-cfw 1.0.3 not checked (gh is too old, needs 2.68.0 or later). Each target builds from source. To lock them, update gh and run tln update roc-cfw." and ToolBinCheck.bundle_note({ key: "roc-cfw", version: "1.0.3", reason: "more than one commit" }) == "note: roc-cfw 1.0.3: the bundle has no valid attestation (more than one commit). Each target builds from source." and ToolBinCheck.skip_name(NoGh) == "no-gh" and ToolBinCheck.skip_name(GhOld) == "gh-old"
}
