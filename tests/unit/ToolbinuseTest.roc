import lib.ToolBin
import lib.ToolBinUse

ToolbinuseTest :: [].{}

# Slice 093 (docs/slices/093-prebuilt-bin-use.md), the pure parts: the use of prebuilt project tool binaries (CLI 6.4: R-PT9 steps 1 and 2, R-PT15, R-PT21, R-PT22, R-PT23, R-B10, R-T22; Design Q237, Q238, R-DA4). The expected value of each row is the design text or the slice file text, not the code.
# Texts that the design does not give are the proposals of the slice file (TW24). The flow cases (L2, L3) are not written yet.

bundle = "GTD8yh6ExWViorE8u3JMyK9mC5b6FRuCgpd5xNhd7xtW"

h1 = Str.repeat("a", 64)

h2 = Str.repeat("b", 64)

lock = Ok(Hashes([{ target: "x64musl", sha256: h1 }]))

# R-PT22 (Q237 text): the dir of a prebuilt entry is the sha256 of `prebuilt\n<bundle>\n<target>\n<sha256>\n`. The value is made outside the code (python3 hashlib). Each input changes it.
expect {
	d = ToolBinUse.digest({ bundle, target: "x64musl", sha256: h1 })
	d == "df5758e458064aec0de274f3fb4b531e3197eb74bfb9482ef4cb6ab38d59f741" and d != ToolBinUse.digest({ bundle, target: "x64mac", sha256: h1 }) and d != ToolBinUse.digest({ bundle, target: "x64musl", sha256: h2 }) and d != ToolBinUse.digest({ bundle: "other", target: "x64musl", sha256: h1 })
}

# R-PT9 step 1, R-PT22, R-PT25, Design Q237: the entry that a run takes. A prebuilt entry only when the lock (`bin`) names its sha256 and the two levels allow binaries, and then it wins over a source build entry. Else a source build entry. Else none. Entries of another bundle or target never count.
expect {
	pre = |dir, sha| { dir, bundle, target: "x64musl", kind: Prebuilt({ sha256: sha }) }
	built = |dir| { dir, bundle, target: "x64musl", kind: Built }
	pick = |scope, machine, bin, entries| ToolBinUse.pick({ scope, bundle, target: "x64musl", bin, machine, entries })
	rows = [
		(pick(Project, Err(Unset), lock, [pre("/p", h1)]), Prebuilt("/p")),
		(pick(Project, Err(Unset), lock, [built("/b"), pre("/p", h1)]), Prebuilt("/p")),
		(pick(Project, Err(Unset), lock, [pre("/p2", h2), built("/b")]), Source("/b")),
		(pick(Project, Err(Unset), lock, [pre("/p2", h2)]), NoEntry),
		(pick(Project, Err(Unset), Err(Unset), [pre("/p", h1), built("/b")]), Source("/b")),
		(pick(Project, Err(Unset), Ok(Hashes([])), [pre("/p", h1)]), NoEntry),
		(pick(Project, Err(Unset), Ok(Off), [pre("/p", h1), built("/b")]), Source("/b")),
		(pick(Project, Ok(Bool.False), lock, [pre("/p", h1), built("/b")]), Source("/b")),
		(pick(Project, Ok(Bool.False), lock, [pre("/p", h1)]), NoEntry),
		(pick(Project, Ok(Bool.True), lock, [pre("/p", h1)]), Prebuilt("/p")),
		(pick(Project, Err(Unset), lock, []), NoEntry),
		(pick(Global, Err(Unset), lock, [pre("/p", h1), built("/b")]), Source("/b")),
		(pick(Global, Err(Unset), lock, [pre("/p", h1)]), NoEntry),
		(ToolBinUse.pick({ scope: Project, bundle, target: "x64mac", bin: lock, machine: Err(Unset), entries: [pre("/p", h1), built("/b")] }), NoEntry),
		(ToolBinUse.pick({ scope: Project, bundle: "other", target: "x64musl", bin: lock, machine: Err(Unset), entries: [pre("/p", h1), built("/b")] }), NoEntry),
	]
	rows.all(|(got, want)| got == want)
}

# R-PT21, R-PT15, R-PT25, R-PT6, R-PT7: step 2. A download only with a value for the host target, both levels on, and online. Else a build: no value for the target (`--frozen` too: no release list), `bin` missing or empty or `false`, `tool-binaries = false`, `--offline`.
expect {
	use = |machine, bin, target, offline| ToolBinUse.use({ machine, bin, target, offline })
	rows = [
		(use(Err(Unset), lock, "x64musl", Bool.False), Download(h1)),
		(use(Ok(Bool.True), lock, "x64musl", Bool.False), Download(h1)),
		(use(Err(Unset), lock, "arm64mac", Bool.False), Build),
		(use(Err(Unset), Ok(Hashes([])), "x64musl", Bool.False), Build),
		(use(Err(Unset), Err(Unset), "x64musl", Bool.False), Build),
		(use(Err(Unset), Ok(Off), "x64musl", Bool.False), Build),
		(use(Ok(Bool.False), lock, "x64musl", Bool.False), Build),
		(use(Err(Unset), lock, "x64musl", Bool.True), Build),
	]
	rows.all(|(got, want)| got == want)
}

# R-PT21, R-DA4, R-DL7: a sha256 that is not the `bin` value is exit code 16, with the target, both values and the way on. The use line and the download warning are the texts of R-PT23.
expect {
	ok = ToolBinUse.verify({ key: "roc-cfw", version: "1.0.3", target: "x64musl", got: h1, want: h1 })
	bad = match ToolBinUse.verify({ key: "roc-cfw", version: "1.0.3", target: "x64musl", got: h2, want: h1 }) {
		Ok(_) => "ok"
		Err(e) => "${e.kind.code().to_str()} ${e.message}"
	}
	line = ToolBinUse.use_line({ key: "roc-cfw", version: "1.0.3", target: "x64musl", sha256: h1 })
	warn = ToolBinUse.download_warning({ key: "roc-cfw", version: "1.0.3", target: "x64musl", reason: "HTTP 404" })
	ok == Ok({}) and bad == "16 the x64musl binary of roc-cfw 1.0.3 has the sha256 ${h2}, but talon.toml has ${h1}. Talon deleted the file. To build from source, remove x64musl from bin of roc-cfw in talon.toml." and line == "roc-cfw 1.0.3: prebuilt x64musl binary, sha256 aaaaaaaaaaaa (talon.toml)" and warn == "warning: the x64musl binary of roc-cfw 1.0.3 could not be downloaded (HTTP 404). Talon builds it from source."
}

# R-PT22, R-B9, R-TF1, R-B10: the manifest of a prebuilt entry is one line with `format` 1, the source kind `prebuilt`, and no build id. `read_manifest` gives the entry back. A manifest of a source build (the kind `release`) is `NotPrebuilt`, so a source reader (`XCache.read`) keeps it.
expect {
	e = { name: "acme/foo", version: "1.0.3", bundle, target: "x64musl", sha256: h1, url: "https://github.com/acme/foo/releases/download/1.0.3/${bundle}-x64musl", last_run: "2026-11-02T10:00:00Z" }
	text = ToolBinUse.manifest_text(e)
	release = "{\"format\":1,\"name\":\"acme/foo\",\"source\":{\"kind\":\"release\",\"version\":\"1.0.3\",\"url\":\"https://x/y.tar.zst\"},\"sha256\":\"${h1}\",\"bundle\":\"${bundle}\"}\n"
	text == "{\"format\":1,\"name\":\"acme/foo\",\"source\":{\"kind\":\"prebuilt\",\"version\":\"1.0.3\",\"url\":\"${e.url}\"},\"target\":\"x64musl\",\"sha256\":\"${h1}\",\"bundle\":\"${bundle}\",\"last_run\":\"2026-11-02T10:00:00Z\"}\n" and ToolBinUse.read_manifest(text) == Ok(e) and ToolBinUse.read_manifest(release) == Err(NotPrebuilt) and ToolBinUse.read_manifest("nope") == Err(NotPrebuilt)
}
