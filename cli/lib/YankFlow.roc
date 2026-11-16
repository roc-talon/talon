import Args
import Common
import Fail
import Fx
import Help
import IndexQuery
import Item
import Net
import Out
import Publish
import Registry
import RegistryCache
import RocInstall
import Roots
import Share
import YankCheck

## `tln yank` (slice 249; CLI 1 R-CM21; Registry R-YK1, R-YK3, R-AP1, R-AP34). Direct style over `Fx`. The decisions are in `YankCheck`; the token and the waits are those of `tln publish`. The L2 cases are `tests/commands/cases/yank`.
## Calls in order: `env_all!`, `Roots.of_run!`, `read_files!` of `config.toml`, `Net.registry`; `YankCheck.direct`, `offline`, `operand`, `reason`, `job`, `oidc` (no call); the read of R-AP1 (`newest`, with the source); `YankCheck.release`; the token request; the write with the waits and the new token; `YankCheck.answer`; the output.
YankFlow :: [].{

	## Returns the exit code.
	run! : Fx, Args => I32
	run! = |fx, args| match flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(done) => {
			if args.json {
				fx.out!(Out.json_ok({ command: args.typed, data: YankCheck.data(done) }))
			} else {
				for line in YankCheck.lines(done) {
					fx.out!(line)
				}
			}
			0
		}
	}
}

Run : { origin : Str, setting : Str, oidc : Publish.Oidc }

State : { token : Str, retries : U64, tries : U64, renewed : Bool }

flow! : Fx, Args => Try(YankCheck.Done, Fail)
flow! = |fx, args| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	config_path = Roots.item(roots, Item.Config)
	config = Share.setting({ path: config_path, text: RocInstall.read_text!(fx, config_path)? })?
	net = Net.from_env(env)
	origin = match Net.registry({ flag: args.registry, env: net.registry, config: config.registry }) {
		Direct => return Err(YankCheck.direct({}))
		Url(url) => url
	}
	if args.offline {
		return Err(YankCheck.offline({}))
	}
	tag = YankCheck.operand(args.operands)?
	reason = match args.options.find_first(|(name, _)| name == "--reason") {
		Ok((_, Ok(text))) => Ok(text)
		_ => Err(None)
	}
	undo = args.options.any(|(name, _)| name == "--undo")
	YankCheck.undo_reason({ undo, reason })?
	YankCheck.reason(reason)?
	job = YankCheck.job(env)?
	oidc = YankCheck.oidc(env)?
	setting = IndexQuery.source({ flag: args.registry, env: net.registry, config: config.registry })
	path = Registry.releases_of_repo_url({ origin: "", owner: job.owner, repo: job.repo })
	got = RegistryCache.get_needs!(fx, { roots, origin, version: Help.version, path, now: 0, offline: Bool.False, newest: Bool.True, bookmark: Err(None), source: setting, needs: Bool.True })?
	answer = match got {
		Answer(a) => a
		NoCopy => return Err(Fail.new(Internal, "no answer for the release list and no copy"))
	}
	row = YankCheck.release({ origin, owner: job.owner, repo: job.repo, tag, status: answer.status, body: answer.body, source: setting })?
	run = { origin, setting, oidc }
	token = token!(fx, run)?
	body = { log_index: row.log_index, undo, reason }
	sent = send!(fx, run, body, { token, retries: 0, tries: 0, renewed: Bool.False })?
	YankCheck.answer({ origin, name: "${job.owner}/${job.repo}", tag, before: row.yanked, status: sent.status, body: sent.body })
}

# The OIDC token (R-TP2).
token! : Fx, Run => Try(Str, Fail)
token! = |fx, run| Publish.token(fx.http_send!(Publish.token_request({ oidc: run.oidc, origin: run.origin })))

# The write, with the waits and the new token (R-AP34).
send! : Fx, Run, { log_index : U64, undo : Bool, reason : Try(Str, [None]) }, State => Try({ status : U16, body : Str }, Fail)
send! = |fx, run, body, state| {
	reply = fx.http_send!(YankCheck.request({ origin: run.origin, version: Help.version, token: state.token, log_index: body.log_index, undo: body.undo, reason: body.reason }))
	tries = state.tries + 1
	match Publish.next({ retries: state.retries, renewed: state.renewed, reply }) {
		Done => match reply {
			Ok(answer) => Ok({ status: answer.status, body: answer.body })
			Err(_) => Err(Fail.new(Internal, "no answer after a good answer"))
		}
		Renew => {
			new_token = token!(fx, run)?
			send!(fx, run, body, { ..state, token: new_token, tries, renewed: Bool.True })
		}
		Wait(ms) => {
			fx.sleep!(ms)
			send!(fx, run, body, { ..state, retries: state.retries + 1, tries })
		}
		Stop => Err(YankCheck.failure({ origin: run.origin, version: Help.version, tries, renewed: state.renewed, reply, undo: body.undo, source: run.setting }))
	}
}
