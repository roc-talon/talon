import lib.ConfigToml
import lib.IndexQuery
import lib.Intent

NewerhintTest :: [].{}

# Slice 231 (docs/slices/231-unknown-value-hint.md), R-TF8 R-TF4 R-EC19, Design Q607.
# `ConfigToml.read_lenient` is a new name (a proposal): until the code agent adds it, this file does not compile (red on purpose).

hint = "A newer tln may know this value. Update tln: tln tool update talon"

# The failure of a read as (exit code, message).
shown = |r| match r {
	Ok(_) => Err("no failure")
	Err(f) => Ok((f.kind.code(), f.message))
}

talon = |text| shown(Intent.read({ path: "/p/talon.toml", text, role: Standalone }))

config = |text| shown(ConfigToml.read({ path: "/c/config.toml", text }))

build = |text| match Intent.read({ path: "/p/talon.toml", text, role: Standalone }) {
	Ok(done) => shown(Intent.build_check({ path: "/p/talon.toml", bad: done.intent.build.bad, kind: App }))
	Err(_) => Err("read failed")
}

# R-TF8: an unknown word for a known key gets exit 19 and the hint as a second line of the message.
expect {
	talon("[resolution]\nstrategy = \"middle\"\n") == Ok((19, "/p/talon.toml:2: resolution.strategy: must be \"highest\" or \"lowest\"\n${hint}"))
}

# R-TF8: a `[build] target` word that is not a Roc target (a newer roc can have it) is the same, for an app (`build_check`).
expect {
	build("[build]\ntarget = \"wasm64\"\n") == Ok((19, "/p/talon.toml:2: build.target: 'wasm64' is not a Roc target\n${hint}"))
}

# R-TF8: a `default-roc` of an id kind that this tln does not know (`<kind>-<name>`).
expect {
	config("default-roc = \"svn-1a2b3c4\"\n") == Ok((19, "/c/config.toml:1: default-roc: must be a full compiler id\n${hint}"))
}

# R-TF8 (Design Q609, G-C239, decided 2026-11-08): the hint goes on each exit 19 for the value of a known key: a wrong type, a prefix of an id, a range or a duration that does not parse. Only text that is not TOML has no hint.
expect {
	rows = [
		("strategy is a number", talon("[resolution]\nstrategy = 5\n"), Ok((19, "/p/talon.toml:2: resolution.strategy: must be \"highest\" or \"lowest\"\n${hint}"))),
		("nightly is a string", talon("[toolchain]\nnightly = \"yes\"\n"), Ok((19, "/p/talon.toml:2: toolchain.nightly: must be true or false\n${hint}"))),
		("a range that does not parse", talon("[dependencies]\njson = \"latest\"\n"), Ok((19, "/p/talon.toml:2: dependencies.json: 'latest' is not a version range\n${hint}"))),
		("min-release-age in hours", talon("[resolution]\nmin-release-age = \"48h\"\n"), Ok((19, "/p/talon.toml:2: resolution.min-release-age: must be a number of days, for example \"2d\"\n${hint}"))),
		("target is a number", build("[build]\ntarget = 5\n"), Ok((19, "/p/talon.toml:2: build.target: must be a string\n${hint}"))),
		("config: default-roc is a number", config("default-roc = 5\n"), Ok((19, "/c/config.toml:1: default-roc: must be a full compiler id\n${hint}"))),
		("config: a prefix of a nightly id", config("default-roc = \"nightly-2026-10\"\n"), Ok((19, "/c/config.toml:1: default-roc: must be a full compiler id\n${hint}"))),
		("config: nightly is a string", config("nightly = \"yes\"\n"), Ok((19, "/c/config.toml:1: nightly: must be true or false\n${hint}"))),
		("config: gc-age in hours", config("gc-age = \"48h\"\n"), Ok((19, "/c/config.toml:1: gc-age: must be a number of days, for example \"30d\"\n${hint}"))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-TF8: the bad `registry` text of `config.toml` (`IndexQuery.setting`) has the hint too.
expect {
	got = IndexQuery.setting({ flag: Err(Unset), env: Err(Unset), config: Ok({ text: "https://user@r.example", at: "/c/config.toml:3" }) })
	match got {
		Err(f) => f.kind.code() == 19 and f.message.starts_with("/c/config.toml:3: registry: 'https://user@r.example' is not a registry URL.") and f.message.ends_with("\n${hint}")
		Ok(_) => Bool.False
	}
}

# R-TF8: text that is not TOML has no hint (it is wrong in each version).
expect {
	talon("[dependencies]\njson = = 1\n") == Ok((19, "/p/talon.toml:2: not valid TOML")) and config("nightly = = 1\n") == Ok((19, "/c/config.toml:1: not valid TOML"))
}

# R-TF8: the lenient read of `config.toml` (for `tln tool update talon`) never fails. A bad value is a warning and the key is unset. The good keys stay. The text of a warning is a proposal (TW24): `<path>:<line>: <key>: <why> (ignored)`.
expect {
	lenient = |text| ConfigToml.read_lenient({ path: "/c/config.toml", text })
	empty = match ConfigToml.read({ path: "/c/config.toml", text: "" }) {
		Ok(done) => done.config
		Err(_) => crash "empty config must read"
	}
	bad_value = lenient("nightly = true\ndefault-roc = \"svn-1a2b3c4\"\nmin-release-age = \"1d\"\n")
	two_bad = lenient("default-roc = 5\nnightly = \"yes\"\nfoo = 1\n")
	syntax = lenient("nightly = = 1\n")
	good_text = "nightly = false\nmin-release-age = \"3d\"\nunknown-key = 1\n"
	strict = ConfigToml.read({ path: "/c/config.toml", text: good_text })
	same = match strict {
		Ok(done) => lenient(good_text) == { config: done.config, warnings: done.warnings }
		Err(_) => Bool.False
	}
	bad_value.config.default_roc == Err(Unset)
		and bad_value.config.nightly == Ok(Bool.True)
			and bad_value.config.min_release_age == Ok(86400)
				and bad_value.warnings == ["/c/config.toml:2: default-roc: must be a full compiler id (ignored)"]
					and two_bad.config == empty
						and two_bad.warnings == ["/c/config.toml:1: default-roc: must be a full compiler id (ignored)", "/c/config.toml:2: nightly: must be true or false (ignored)", "/c/config.toml:3: unknown key foo"]
							and syntax == { config: empty, warnings: ["/c/config.toml:1: not valid TOML (ignored)"] }
								and same
}
