import Fail
import Fx

## R-RG9 (Design Q601): the one place of the first-request fall back of the built-in default registry to `direct`.
## Each first registry request of a run (the short-name read, the full-name read, the closure query, the compiler list) calls `decide!` on its failure.
Fallback :: [].{

	## What a run that fell back is: the registry URL and the cause, for the note `registry-direct`.
	Fell : { registry : Str, cause : Str }

	## The failure of a first registry request. `Fail.fallback` is `Ok` only for the built-in default and a failure that is a no answer or a 5xx (`Registry.no_answer`, `Registry.refuse`).
	## Then: the warning on stderr (also with `--quiet`, R-FL4) and `Ok(Fell)`: the run goes on in `direct`. Else `Err(fail)`: the failure stops the command (exit 15).
	## The text of the warning is a proposal (CLI 3, R-OUT2).
	decide! : Fx, Fail, Str => Try(Fallback.Fell, Fail)
	decide! = |fx, fail, origin| match fail.fallback {
		Ok(cause) => {
			fx.err!("warning: the default registry ${origin} does not answer (${cause}): this run uses GitHub (direct)\n")
			Ok({ registry: origin, cause })
		}
		Err(None) => Err(fail)
	}
}
