import Args
import Common
import Fail
import Fx
import Help
import IndexQuery
import Item
import MoveCheck
import Net
import Out
import PrivacyGuard
import Publish
import Registry
import RegistryCache
import RocInstall
import Roots
import Share

## `tln move` (slice 251; CLI 1 R-CM22, R-MV1 to R-MV5; Registry R-AP31, R-TP15, R-AP1, R-AP34). Direct style over `Fx`, as `YankFlow`. The decisions are in `MoveCheck`; the token and the waits are those of `tln publish`. The L2 cases are `tests/commands/cases/move`.
## Calls in order: `env_all!`, `Roots.of_run!`, `read_files!` of `config.toml`, `Net.registry`; `MoveCheck.direct`, `offline`, `operand`, `name`, `flags`, `name`, `job`, `plan`, `event`, `server`, `oidc` (no call); the privacy guard of the successor (R-MV3); the read of R-AP1 for the old name (`Set` and `Remove`); `MoveCheck.before`, `holder`; the token request; the write with the waits and the new token; `MoveCheck.answer`; the output.
MoveFlow :: [].{

	## Returns the exit code.
	run! : Fx, Args => I32
	run! = |fx, args| match flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(done) => {
			if args.json {
				fx.out!(Out.json_ok({ command: args.typed, data: MoveCheck.data(done) }))
			} else {
				for line in MoveCheck.lines(done) {
					fx.out!(line)
				}
			}
			0
		}
	}
}

Run : { origin : Str, setting : Str, oidc : Publish.Oidc, old : MoveCheck.Name, plan : MoveCheck.Plan }

State : { token : Str, retries : U64, tries : U64, renewed : Bool }

flow! : Fx, Args => Try(MoveCheck.Done, Fail)
flow! = |fx, args| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	config_path = Roots.item(roots, Item.Config)
	config = Share.setting({ path: config_path, text: RocInstall.read_text!(fx, config_path)? })?
	net = Net.from_env(env)
	origin = match Net.registry({ flag: args.registry, env: net.registry, config: config.registry }) {
		Direct => return Err(MoveCheck.direct({}))
		Url(url) => url
	}
	if args.offline {
		return Err(MoveCheck.offline({}))
	}
	old_text = MoveCheck.operand(args.operands)?
	old = MoveCheck.name({ what: "the old name", text: old_text })?
	undo = args.options.any(|(name, _)| name == "--undo")
	to_text = match args.options.find_first(|(name, _)| name == "--to") {
		Ok((_, Ok(text))) => Ok(text)
		_ => Err(None)
	}
	MoveCheck.flags({ undo, to: to_text })?
	to = match to_text {
		Ok(text) => Ok(MoveCheck.name({ what: "the value of --to", text })?)
		Err(None) => Err(None)
	}
	job = MoveCheck.job(env)?
	plan = MoveCheck.plan({ job, old, to, undo })?
	MoveCheck.event(env)?
	MoveCheck.server(env)?
	oidc = MoveCheck.oidc(env)?
	names = MoveCheck.guarded(plan)
	if !names.is_empty() {
		PrivacyGuard.check!(fx, { net, roots, sources: names.map(|n| Repo(n)), offline: Bool.False, frozen: Bool.False })?
	}
	setting = IndexQuery.source({ flag: args.registry, env: net.registry, config: config.registry })
	before = match plan {
		Offer(_) => Unknown
		_ => {
			path = Registry.releases_of_repo_url({ origin: "", owner: old.owner, repo: old.repo })
			got = RegistryCache.get_needs!(fx, { roots, origin, version: Help.version, path, now: 0, offline: Bool.False, newest: Bool.True, bookmark: Err(None), source: setting, needs: Bool.True })?
			answer = match got {
				Answer(a) => a
				NoCopy => return Err(Fail.new(Internal, "no answer for the release list and no copy"))
			}
			MoveCheck.before({ origin, old, status: answer.status, body: answer.body, source: setting })?
		}
	}
	MoveCheck.holder({ plan, job, old, before })?
	run = { origin, setting, oidc, old, plan }
	token = token!(fx, run)?
	sent = send!(fx, run, { token, retries: 0, tries: 0, renewed: Bool.False })?
	MoveCheck.answer({ origin, old, plan, before, status: sent.status, body: sent.body })
}

# The OIDC token (R-TP2).
token! : Fx, Run => Try(Str, Fail)
token! = |fx, run| Publish.token(fx.http_send!(Publish.token_request({ oidc: run.oidc, origin: run.origin })))

# The write, with the waits and the new token (R-AP34).
send! : Fx, Run, State => Try({ status : U16, body : Str }, Fail)
send! = |fx, run, state| {
	reply = fx.http_send!(MoveCheck.request({ origin: run.origin, version: Help.version, token: state.token, old: run.old, plan: run.plan }))
	tries = state.tries + 1
	# 202 is the answer of an offer (R-TP15): `Publish.next` gives `Stop` for it.
	step = match reply {
		Ok(answer) if answer.status == 202 => Done
		_ => Publish.next({ retries: state.retries, renewed: state.renewed, reply })
	}
	match step {
		Done => match reply {
			Ok(answer) => Ok({ status: answer.status, body: answer.body })
			Err(_) => Err(Fail.new(Internal, "no answer after a good answer"))
		}
		Renew => {
			new_token = token!(fx, run)?
			send!(fx, run, { ..state, token: new_token, tries, renewed: Bool.True })
		}
		Wait(ms) => {
			fx.sleep!(ms)
			send!(fx, run, { ..state, retries: state.retries + 1, tries })
		}
		Stop => Err(MoveCheck.failure({ origin: run.origin, version: Help.version, tries, renewed: state.renewed, reply, plan: run.plan, source: run.setting }))
	}
}
