app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Compiler
import lib.Fail

main! = |_args| Ok({})

n1 = "nightly-2026-10-14-38a3029"

n2 = "nightly-2026-10-09-258ab27"

# R-SO7 R-SO9 R-SO10 R-SO11 R-PH6: the compiler on `PATH` is the one installed compiler. Its id is in the stdout of `roc version`. A nightly or a release is an
# installed compiler (R-SO10). Another id is a local build (R-SO11), and with no `roc` there is no compiler: both are `NoCompiler` for the resolve (slice 005).
expect {
	versions = [
		("Roc compiler version ${n1}\n", Ok(n1)),
		("Roc compiler version ${n1}", Ok(n1)),
		("Roc compiler version ${n1}\r\n", Ok(n1)),
		("Roc compiler version 0.1.0\n", Ok("0.1.0")),
		("Roc compiler version debug-3f9a1c2\n", Ok("debug-3f9a1c2")),
		("Roc compiler version \n", Err(BadVersion)),
		("Roc compiler version a b\n", Err(BadVersion)),
		("roc 0.1.0\n", Err(BadVersion)),
		("", Err(BadVersion)),
	]
	bad_versions = versions.keep_if(|(text, want)| Compiler.version_id(text) != want).map(|(text, want)| (text, want, Compiler.version_id(text)))
	dbg bad_versions

	kinds = [(n1, Nightly), ("0.1.0", Release), ("12.30.4", Release), ("debug-3f9a1c2", Local), ("nightly-2026-10-09", Local), ("", Local)]
	bad_kinds = kinds.keep_if(|(id, want)| Compiler.kind(id) != want).map(|(id, want)| (id, want))
	dbg bad_kinds

	paths = [
		(Ok("Roc compiler version ${n1}\n"), Ok(n1)),
		(Ok("Roc compiler version 0.1.0\n"), Ok("0.1.0")),
		(Ok("Roc compiler version debug-3f9a1c2\n"), Err(NoCompiler)),
		(Ok("not a version"), Err(NoCompiler)),
		(Err(NoRoc), Err(NoCompiler)),
	]
	bad_paths = paths.keep_if(|(text, want)| Compiler.on_path(text) != want).map(|(text, want)| (text, want))
	dbg bad_paths
	bad_versions == [] and bad_kinds == [] and bad_paths == []
}

# R-PH7 R-PH6 R-BL3 R-DL5 R-EC13: a probe needs a compiler. The only installed compiler is the `roc` on `PATH`. Any other id is a required download, and P0 refuses
# it with exit code 13 (kind consent). The message names the id and says that tln runs only the `roc` on `PATH`. It does not name `--allow-downloads` or
# `TALON_AUTO_INSTALL` (P0 does not read them).
expect {
	refuse = |id, path_roc| Compiler.require({ id, path_roc })
	rows = [
		(refuse(n1, Ok(n1)), Ok({})),
		(refuse("0.1.0", Ok("0.1.0")), Ok({})),
		(
			refuse(n2, Ok(n1)),
			Err(Fail.new(Consent, "the compiler ${n2} is not installed. This version of tln runs only the roc on PATH (${n1}).")),
		),
		(
			refuse("0.1.0", Ok(n1)),
			Err(Fail.new(Consent, "the compiler 0.1.0 is not installed. This version of tln runs only the roc on PATH (${n1}).")),
		),
		(
			refuse(n1, Err(NoCompiler)),
			Err(Fail.new(Consent, "the compiler ${n1} is not installed. This version of tln runs only the roc on PATH, and there is none.")),
		),
	]
	bad = rows.keep_if(|(got, want)| got != want).map(|(got, want)| (got, want))
	dbg bad
	refused = refuse(n2, Ok(n1))
	text = match refused {
		Err(f) => f.message
		Ok(_) => ""
	}
	code = match refused {
		Err(f) => f.kind.code()
		Ok(_) => 0
	}
	bad == [] and code == 13 and !text.contains("--allow-downloads") and !text.contains("TALON_AUTO_INSTALL") and !text.contains("P0")
}
