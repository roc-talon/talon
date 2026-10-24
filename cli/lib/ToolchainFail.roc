import Download
import Fail

## The failure texts of `tln roc install` (slice 039s: split from `Toolchain`, R-HF5, R-HF12, R-SE9, R-DI12, TW24). `Toolchain` keeps the names that the unit tests call. Pure.
ToolchainFail :: [].{

	## R-DA7: the failure of a download child that ended with an error (the form of `Fetch.download_failed`, with no hint about `tln audit`). `outcome` is `Download.outcome`.
	##
	## | Outcome | Kind and text |
	## | --- | --- |
	## | `Http(Ok(status))` | `Network`: `download of <id> failed: <status> (<url>)` |
	## | `Http(Err(Unknown))` | `Network`: `download of <id> failed: HTTP error (<url>)` |
	## | `Failed`, `NotStarted(text)` | `Environment` (exit 18): `cannot run <program>: <text>` (R-HF12). `<program>` is `curl` or `wget`. |
	## | `Failed`, another end | `Network`: `download of <id> failed: <last line> (<url>)`. With an empty last line: `<program> exited with code <n>`, or `<program> was stopped by signal <n>`, in its place. |
	download_failed : { id : Str, url : Str, program : Download.Program, ended : Download.Ended, outcome : [Http(Try(U16, [Unknown])), Failed], last_line : Str } -> Fail
	download_failed = |facts| {
		name = program_name(facts.program)
		match (facts.outcome, facts.ended) {
			(Http(Ok(status)), _) => Fail.new(Network, "download of ${facts.id} failed: ${status.to_str()} (${facts.url})")
			(Http(Err(Unknown)), _) => Fail.new(Network, "download of ${facts.id} failed: HTTP error (${facts.url})")
			(Failed, NotStarted(text)) => Fail.new(Environment, "cannot run ${name}: ${text}")
			(Failed, ended) => {
				why = if facts.last_line.is_empty() ended_text(name, ended) else facts.last_line
				Fail.new(Network, "download of ${facts.id} failed: ${why} (${facts.url})")
			}
		}
	}

	## R-SE9, R-HF5: the failure of `tar`. `NotStarted(text)`: kind `Environment` (exit 18), `cannot run tar: <text>`. Any other end: kind `Integrity` (exit 16, question Q3),
	## `tar rejected <id> (<url>): <last line>`, with `exit code <n>` or `tar was stopped by signal <n>` in place of an empty last line.
	tar_failed : { id : Str, url : Str, ended : Download.Ended, last_line : Str } -> Fail
	tar_failed = |facts| match facts.ended {
		NotStarted(text) => Fail.new(Environment, "cannot run tar: ${text}")
		ended => {
			why = if facts.last_line.is_empty() ended_text("tar", ended) else facts.last_line
			Fail.new(Integrity, "tar rejected ${facts.id} (${facts.url}): ${why}")
		}
	}

	## R-DI12 (question Q5): `--offline` and the compiler is not installed. Kind `Network` (exit 15): `<id> is not installed and --offline is set`.
	offline_missing : Str -> Fail
	offline_missing = |id| Fail.new(Network, "${id} is not installed and --offline is set")

	## R-DI12 (question Q5): `--offline`, the compiler is not installed, and no page of the list is cached. Kind `Network` (exit 15): `no cached list of compilers and --offline is set`.
	offline_no_list : {} -> Fail
	offline_no_list = |{}| Fail.new(Network, "no cached list of compilers and --offline is set")
}

program_name : Download.Program -> Str
program_name = |program| match program {
	Curl => "curl"
	Wget => "wget"
}

ended_text : Str, Download.Ended -> Str
ended_text = |program, ended| match ended {
	Exited(code) => "${program} exited with code ${code.to_str()}"
	Signaled(code) => "${program} was stopped by signal ${code.to_str()}"
	NotStarted(text) => "cannot run ${program}: ${text}"
}
