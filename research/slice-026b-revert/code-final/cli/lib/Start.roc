import Answer
import Compiler
import Consent
import Fail
import Fx
import Launch
import Mode
import Prompt
import RocInstall
import Roots

## The start of a ladder run (slice 025, `Ladder.run!` and `Ladder.verify!`): the compiler that runs the first probe, with its program and its variables (R-SO22, R-PH7, R-PX2, R-PX6).
## The compiler is found in `<cache>/toolchains` or on `PATH` (`Compiler.find`). A compiler that is not installed is a required download (R-DL2, R-BL3: the baseline and the candidate run on the same compiler).
## The consent rules decide it (`Consent.required_want`, the table in its doc). The calls, in order (the L2 cases `consent/` fix them):
##
## | Step | Call | Rule |
## | --- | --- | --- |
## | 0a | `Launch.toolchains!`: one `list_dirs!` of `<cache>/toolchains` | R-SO22 |
## | 0b | `Compiler.find`. `Ok(id)`: go to 0f. `Err(Missing)`: `Consent.required_want` | R-DL2 |
## | 0c | `Refuse`: the failure of `Compiler.require`. `AutoNo`: `Consent.download_refused`. `NeedTty`: one `tty!` call, then decide again | R-NS2, R-DL5, R-HF1 |
## | 0d | `RocInstall.offer!`. `Present`: go to 0f. `NeedsConsent`: `Consent.download_stop` with the size | R-CC4, R-DL4 |
## | 0e | `Prompt.ask!` with `Consent.command_download`. `No`: `Consent.command_declined`. Then `RocInstall.install_offer!` | R-DL1, R-NI5, R-CC4 |
## | 0f | `Launch.program!`, `Launch.child_env!` | R-LK4, R-PX6 |
Start :: [].{

	## The facts of the consent rules (R-DL5). `auto` is `TALON_AUTO_INSTALL`. `allow` is `--allow-downloads`. `yes`, `mode` and `quiet` are the facts of the prompt. `offline` is `--offline`. `env` is the environment of the process.
	Downloads : { auto : [Ask, Yes, No], allow : Try(Answer, [NoFlag]), yes : Bool, mode : Mode, quiet : Bool, offline : Bool, env : List((Str, Str)) }

	## `id` is the compiler that runs. `installed` has the ids of `<cache>/toolchains` (also the id of a download), so `Ladder` writes `.last-use` for it (R-CC9). `downloads` is 1 after a download, else 0.
	Started : { id : Str, installed : List(Str), program : Str, env : List((Str, Str)), downloads : U64 }

	run! : Fx, { roots : Roots, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, downloads : Start.Downloads } => Try(Start.Started, Fail)
	run! = |fx, run| {
		listed = Launch.toolchains!(fx, run.roots)
		have = match Compiler.find({ id: run.held, installed: listed, path: run.path_roc }) {
			Ok(id) => { id, installed: listed, downloads: 0 }
			Err(Missing) => download!(fx, run, listed)?
		}
		program = Launch.program!(fx, { roots: run.roots, id: have.id, installed: have.installed, path: run.path_roc })?
		env = Launch.child_env!(fx, run.roots, { opted_out: Bool.False })
		Ok({ id: have.id, installed: have.installed, program, env, downloads: have.downloads })
	}
}

Have : { id : Str, installed : List(Str), downloads : U64 }

# Steps 0b to 0e: the compiler of the first probe is not installed.
download! : Fx, { roots : Roots, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, downloads : Start.Downloads }, List(Str) => Try(Have, Fail)
download! = |fx, run, listed| {
	facts = run.downloads
	want = |mode| Consent.required_want({ id: run.held, auto: facts.auto, mode, yes: facts.yes, flag: facts.allow })
	first = want(facts.mode)
	mode = if first == NeedTty Mode.with_tty(facts.mode, fx.tty!()) else facts.mode
	decided = want(mode)
	match decided {
		Refuse => {
			id = Compiler.require({ id: run.held, installed: listed, path: run.path_roc })?
			Ok({ id, installed: listed, downloads: 0 })
		}
		AutoNo => Err(Consent.download_refused(run.held))
		_ => offered!(fx, run, listed, { decided, mode })
	}
}

# Steps 0d and 0e. The list is read before the question and before the lock (R-CC3 point 5).
offered! : Fx, { roots : Roots, path_roc : Try({ id : Str, path : Str }, [NoCompiler]), held : Str, downloads : Start.Downloads }, List(Str), { decided : [Refuse, AutoNo, NeedsConsent, Install, Ask, NeedTty], mode : Mode } => Try(Have, Fail)
offered! = |fx, run, listed, how| {
	facts = run.downloads
	match RocInstall.offer!(fx, { id: run.held, env: facts.env, offline: facts.offline })? {
		Present(found) => Ok({ id: found.id, installed: listed.append(found.id), downloads: 0 })
		Download(offer) => {
			if how.decided == NeedsConsent return Err(Consent.download_stop({ count: 1, size: offer.size }))
			prompt = Consent.command_download({ id: offer.id, count: 1, size: offer.size })
			flag = if how.decided == Install Ok(Yes) else Err(NoFlag)
			asked = Prompt.ask!(fx, prompt, { mode: how.mode, yes: facts.yes, quiet: facts.quiet, flag })?
			if asked.answer != Yes return Err(Consent.command_declined(offer.id))
			done = RocInstall.install_offer!(fx, offer)?
			Ok({ id: done.id, installed: listed.append(done.id), downloads: 1 })
		}
	}
}
