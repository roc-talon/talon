import Args
import Common
import Db
import Fail
import Fx
import Github
import Help
import Ident
import Item
import JsonDoc
import Net
import Out
import Publish
import RocInstall
import Roots
import Share

## `tln publish` (slice 221; CLI 1 R-CM13; Registry R-AP8, R-AP27, R-AP34, R-TP2). Direct style over `Fx`. The decisions are in `Publish`. The L2 cases are `tests/commands/cases/publish/pu1` to `pu8`.
## Calls in order (the `calls.log` of the cases fix them):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `env_all!`, `Roots.of_run!`, `read_files!` of `config.toml`, `Share.setting`, `Net.registry` (the flag `--registry`, `TALON_REGISTRY`, the key `registry`): as `ShareAccountFlow.start!`. `Direct`: `Publish.direct` (exit 2). Then `--offline`: `Publish.offline` (exit 15). Then `Publish.operand(args.operands)` (exit 2). `--file` is accepted, no effect. | Q32, Q507, Q508, R-PUB4 items 1, 2 |
## | 2 | `Publish.job(env)` (repository, ref, form of both, safe tag), then `Publish.oidc(env)`: no call, exit 2 on a failure. Both come before any request, and before the release read (R-AP27, Q507). | R-PUB1, R-AP27, R-TP2 |
## | 3 | `http_get!` of `Publish.release_url` with `Net.headers` (the GitHub token: R-RG3, `GITHUB_TOKEN` in the cases), `Publish.asset`. A failure ends the command: no token request. | R-PUB2 |
## | 4 | `db_query!` `FactsOf(hash)` (the hash of `Ident.of_url(asset URL)`). `Err(TooNew)`: exit 19 (`Db.on_err`), no token request. `Busy`, `Failed`: one `warning: ` with `Publish.unread(cause)` and no `compat` member (Q517). | R-PB5, R-TF3 |
## | 5 | `Publish.facts`; its `warning` on stderr (more than 500: Q510). No fact (and no read failure): `warning: ` and `Publish.no_facts(hash)` on stderr. | R-PUB3 |
## | 6 | The token: `http_send!` of `Publish.token_request`, `Publish.token` (401, 403: exit 2). | R-TP2, Q515 |
## | 7 | The request: `http_send!` of `Publish.request`, `Publish.next`: `Wait(ms)` is `sleep!(ms)` and the same request; `Renew` is steps 6 and 7 again (a new token); `Stop` is `Publish.failure` (with `tries` and `renewed`); `Done` is `Publish.answer`. | R-AP8, R-AP34 |
## | 8 | Output: `Publish.lines` on stdout, or with `--json` the envelope with `Publish.data` (`Out.json_ok`). A failure: `Common.failed!`. `tln publish` does not send the share queue (Q518). | R-OUT2, R-J1, R-SH4 |
PublishFlow :: [].{

	## Returns the exit code.
	run! : Fx, Args => I32
	run! = |fx, args| match flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(done) => {
			if args.json {
				fx.out!(Out.json_ok({ command: args.typed, data: Publish.data(done.report) }))
			} else {
				for line in Publish.lines(done.report) {
					fx.out!(line)
				}
			}
			0
		}
	}
}

Report : { owner : Str, repo : Str, tag : Str, hash : Str, created : Bool, facts : U64 }

Run : { origin : Str, net : Net.Settings, oidc : Publish.Oidc }

flow! : Fx, Args => Try({ report : Report }, Fail)
flow! = |fx, args| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	config_path = Roots.item(roots, Item.Config)
	config = Share.setting({ path: config_path, text: RocInstall.read_text!(fx, config_path)? })?
	net = Net.from_env(env)
	origin = match Net.registry({ flag: args.registry, env: net.registry, config: config.registry }) {
		Direct => return Err(Publish.direct({}))
		Url(url) => url
	}
	if args.offline {
		return Err(Publish.offline({}))
	}
	Publish.operand(args.operands)?
	job = Publish.job(env)?
	oidc = Publish.oidc(env)?
	url = release!(fx, net, job)?
	hash = match Ident.of_url(url) {
		Ok(ident) => ident.hash
		Err(Foreign) => return Err(Fail.new(Internal, "the asset URL ${url} is not a package URL"))
	}
	found = facts!(fx, roots, hash)?
	run = { origin, net, oidc }
	token = token!(fx, run)?
	sent = post!(fx, run, { url, facts: found.list }, { token, retries: 0, tries: 0, renewed: Bool.False })?
	Ok({ report: { owner: job.owner, repo: job.repo, tag: job.tag, hash, created: sent.created, facts: found.list.len() } })
}

# Step 3: the release of the tag, and the asset URL.
release! : Fx, Net.Settings, Publish.Job => Try(Str, Fail)
release! = |fx, net, job| {
	url = Publish.release_url({ api: net.api, owner: job.owner, repo: job.repo, tag: job.tag })
	gh = match net.token {
		AskGh => Github.ask_gh!(fx)
		_ => Err(None)
	}
	reply = fx.http_get!({ url, headers: Net.headers({ token: Net.token({ plan: net.token, gh }), etag: Err(None) }) })
	# The clock is read only for a rate limit answer.
	now = match reply {
		Ok(answer) => if answer.status == 403 or answer.status == 429 fx.clock!() else 0
		Err(_) => 0
	}
	Publish.asset({ api: net.api, owner: job.owner, repo: job.repo, tag: job.tag, now, reply })
}

# Steps 4 and 5: the facts of the hash. A `compat.db` that is busy or cannot be read is one warning and no facts (Q517).
facts! : Fx, Roots, Str => Try({ list : List(Publish.Fact) }, Fail)
facts! = |fx, roots, hash| {
	open = { path: Roots.item(roots, Item.CompatDb), busy_ms: Db.busy_ms, format: Db.format }
	read = match fx.db_query!(open, FactsOf(hash)) {
		Ok(Facts(rows)) => Ok(rows)
		Ok(_) => Ok([])
		Err(TooNew(found)) => match Db.on_err({ err: TooNew(found), what: Read, path: open.path }) {
			Stop(fail) => return Err(fail)
			Warn(_) => Ok([])
		}
		Err(Busy) => Err("busy")
		Err(Failed(why)) => Err(why)
	}
	match read {
		Err(cause) => {
			fx.err!("warning: ${Publish.unread(cause)}\n")
			Ok({ list: [] })
		}
		Ok(stored) => {
			chosen = Publish.facts({ hash, stored })
			match chosen.warning {
				Ok(text) => fx.err!("warning: ${text}\n")
				Err(None) => {}
			}
			if chosen.list.is_empty() {
				fx.err!("warning: ${Publish.no_facts(hash)}\n")
			}
			Ok({ list: chosen.list })
		}
	}
}

# Step 6: the OIDC token.
token! : Fx, Run => Try(Str, Fail)
token! = |fx, run| Publish.token(fx.http_send!(Publish.token_request({ oidc: run.oidc, origin: run.origin })))

State : { token : Str, retries : U64, tries : U64, renewed : Bool }

# Step 7: the request, with the waits and the new token (R-AP34).
post! : Fx, Run, { url : Str, facts : List(Publish.Fact) }, State => Try({ created : Bool, hash : Str, version : Str }, Fail)
post! = |fx, run, body, state| {
	reply = fx.http_send!(Publish.request({ origin: run.origin, version: Help.version, token: state.token, url: body.url, facts: body.facts }))
	tries = state.tries + 1
	match Publish.next({ retries: state.retries, renewed: state.renewed, reply }) {
		Done => match reply {
			Ok(answer) => Publish.answer({ origin: run.origin, status: answer.status, body: answer.body })
			Err(_) => Err(Fail.new(Internal, "no answer after a good answer"))
		}
		Renew => {
			new_token = token!(fx, run)?
			post!(fx, run, body, { ..state, token: new_token, tries, renewed: Bool.True })
		}
		Wait(ms) => {
			fx.sleep!(ms)
			post!(fx, run, body, { ..state, retries: state.retries + 1, tries })
		}
		Stop => Err(Publish.failure({ origin: run.origin, version: Help.version, tries, renewed: state.renewed, reply }))
	}
}
