import Fail
import Pin
import semver.Semver

## The compiler of P0 (Design 7, R-PH6 to R-PH8; Resolution 13, R-SO7, R-SO9 to R-SO11). The only installed compiler is the `roc` on `PATH`.
## `Resolve.Request.compiler` is its id. This module reads the id from `roc version` and decides when a compiler is not usable.
Compiler :: [].{

	## R-SO9: the id from the stdout of `roc version`. The text is `Roc compiler version <id>`, with a line end. A text of another form is
	## `Err(BadVersion)`. Command code runs `roc version` with `Fx.spawn_all!` (P0 keeps no `path-roc.json`: that file is for the launcher check of P1).
	version_id : Str -> Try(Str, [BadVersion])
	version_id = |text| {
		prefix = "Roc compiler version "
		id = text.trim().drop_prefix(prefix)
		if text.trim().starts_with(prefix) and !id.is_empty() and !id.contains(" ") Ok(id) else Err(BadVersion)
	}

	## R-SO10, R-SO11: `Nightly` for a nightly tag (`Pin.is_nightly`), `Release` for a release version (`X.Y.Z`, no pre-release part), else `Local`
	## (`debug-<sha>`: a local build, Talon never writes it as a `roc:` pin).
	kind : Str -> [Nightly, Release, Local]
	kind = |id| {
		if Pin.is_nightly(id) {
			Nightly
		} else {
			match Semver.parse(id) {
				Ok(v) if v.pre_release().is_empty() => Release
				_ => Local
			}
		}
	}

	## R-SO7, R-PH6: the compiler on `PATH`. `version_text` is the stdout of `roc version`, or `Err(NoRoc)` when no `roc` is on `PATH` (`Fx.programs!`).
	## A nightly or a release is `Ok(id)` (R-SO10). No `roc`, a text that is not a version, and a local build are `Err(NoCompiler)`: the same value as
	## `Resolve.Request.compiler` and `Pin.decide` take (R-SO11, slice 005).
	on_path : Try(Str, [NoRoc]) -> Try(Str, [NoCompiler])
	on_path = |version_text| match version_text {
		Err(NoRoc) => Err(NoCompiler)
		Ok(text) => match Compiler.version_id(text) {
			Ok(id) if Compiler.kind(id) != Local => Ok(id)
			_ => Err(NoCompiler)
		}
	}

	## R-SO2, R-EV5, R-SC12: `ROC_TOOLCHAIN` (rank 2) from the environment. An empty value is the same as no value. A text that is not a full compiler id
	## (`Compiler.kind` is `Local`: a prefix such as `nightly-2026-10`) is a failure of kind `Usage` (exit 2, as a bad `TALON_NOW`): `ROC_TOOLCHAIN is not a full compiler id: <text>`.
	toolchain_of : List((Str, Str)) -> Try(Try(Str, [Unset]), Fail)
	toolchain_of = |env| match env.find_first(|(name, _)| name == "ROC_TOOLCHAIN") {
		Ok((_, text)) if !text.is_empty() => if Compiler.kind(text) == Local {
			Err(Fail.new(Usage, "ROC_TOOLCHAIN is not a full compiler id: ${text}"))
		} else {
			Ok(Ok(text))
		}
		_ => Ok(Err(Unset))
	}

	## R-PH7, R-PH6, R-BL3: a probe needs the compiler `id` (the held `roc:` pin, or the selected compiler). The only installed compiler is the one on `PATH`
	## (`path_roc`). When `id` is that compiler: `Ok({})`. Else the compiler is a required download (R-DL2), and P0 refuses it as `TALON_AUTO_INSTALL=no` does
	## (R-DL5): a failure of kind `Consent` (exit 13, R-EC13). The message (a proposal, TW24) names the id and says that this version of `tln` runs only
	## the `roc` on `PATH`. It does not name `--allow-downloads` or `TALON_AUTO_INSTALL` (P0 does not read them).
	##
	## | `path_roc` | Message |
	## | --- | --- |
	## | `Ok(path id)` | `the compiler <id> is not installed. This version of tln runs only the roc on PATH (<path id>).` |
	## | `Err(NoCompiler)` | `the compiler <id> is not installed. This version of tln runs only the roc on PATH, and there is none.` |
	require : { id : Str, path_roc : Try(Str, [NoCompiler]) } -> Try({}, Fail)
	require = |facts| match facts.path_roc {
		Ok(found) if found == facts.id => Ok({})
		Ok(found) => Err(not_installed(facts.id, " (${found})"))
		Err(NoCompiler) => Err(not_installed(facts.id, ", and there is none"))
	}
}

not_installed : Str, Str -> Fail
not_installed = |id, found| Fail.new(Consent, "the compiler ${id} is not installed. This version of tln runs only the roc on PATH${found}.")
