import Args
import Common
import Fail
import Fx
import Help
import Item
import JsonDoc
import Net
import Out
import RocInstall
import Roots
import Share
import ShareAccount
import ShareFlow
import ShareJson

## `tln share logout` and `tln share forget` (slice 220; CLI 1 R-SH9, R-SH10; Registry R-AP36, R-AP38). Direct style over `Fx`. The pure decisions are in `ShareAccount`.
## The steps are in the slice file `docs/slices/220-share-logout-forget.md` (section The flow). The L2 cases are `share/sh33` to `share/sh48`.
ShareAccountFlow :: [].{

	## R-SH9, R-AP38, R-SH10. Returns the exit code.
	logout! : Fx, Args => I32
	logout! = |fx, args| match logout_flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(done) => {
			show!(fx, args, done.lines, done.data)
			0
		}
	}

	## R-SH9, R-AP36, R-SH10, R-SH5, R-SH13. Returns the exit code.
	forget! : Fx, Args => I32
	forget! = |fx, args| match forget_flow!(fx, args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(done) => {
			show!(fx, args, done.lines, done.data)
			0
		}
	}
}

Shown : { lines : List(Str), data : JsonDoc }

show! : Fx, Args, List(Str), JsonDoc => {}
show! = |fx, args, lines, data| if args.json {
	fx.out!(Out.json_ok({ command: args.typed, data }))
} else {
	for line in lines {
		fx.out!(line)
	}
}

# The steps that `logout` and `forget` share: the environment, the registry (R-SH10, Q485), the path of `share.json` and its doc (a missing file is `Err(Missing)`).
Start : { origin : Str, json_path : Str, doc : Try(ShareJson.Doc, [Missing]) }

start! : Fx, Args, Str => Try(Start, Fail)
start! = |fx, args, word| {
	env = fx.env_all!()
	roots = Roots.of_run!(fx, env)?
	config_path = Roots.item(roots, Item.Config)
	config = Share.setting({ path: config_path, text: RocInstall.read_text!(fx, config_path)? })?
	origin = match Net.registry({ flag: args.registry, env: Net.from_env(env).registry, config: config.registry }) {
		Direct => return Err(Fail.new(Usage, ShareAccount.direct_text({ command: word })))
		Url(url) => url
	}
	if args.offline {
		return Err(Fail.new(Network, ShareAccount.offline_text({ command: word })))
	}
	json_path = Roots.item(roots, Item.ShareJson)
	doc = match fx.read_files!([json_path]) {
		[Ok(text)] => Ok(ShareJson.read({ path: json_path, text })?)
		_ => Err(Missing)
	}
	Ok({ origin, json_path, doc })
}

logout_flow! : Fx, Args => Try(Shown, Fail)
logout_flow! = |fx, args| {
	begun = start!(fx, args, "logout")?
	none = Ok({ lines: ShareAccount.no_login_lines({}), data: ShareAccount.no_login_data({}) })
	doc = match begun.doc {
		Ok(found) => found
		Err(Missing) => return none
	}
	if doc.token == Err(Unset) {
		return none
	}
	match ShareAccount.jwt({ doc, now: fx.clock!() }) {
		None => return none
		Expired => {}
		Live(token) => {
			request = ShareAccount.logout_request({ origin: begun.origin, version: Help.version, token })
			# 401: the token already stopped, the goal is reached (Q481).
			_ = ShareAccount.delete_answer({ origin: begun.origin, version: Help.version, reply: fx.http_send!(request) })?
		}
	}
	ShareFlow.totals_write!(fx, begun.json_path, ShareAccount.logged_out)?
	Ok({ lines: ShareAccount.logout_lines({}), data: ShareAccount.logout_data({}) })
}

forget_flow! : Fx, Args => Try(Shown, Fail)
forget_flow! = |fx, args| {
	begun = start!(fx, args, "forget")?
	doc = match begun.doc {
		Ok(found) => found
		Err(Missing) => return Ok({ lines: ShareAccount.nothing_to_forget_lines({}), data: ShareAccount.nothing_to_forget_data({}) })
	}
	proof = if doc.token == Err(Unset) {
		Machine(doc.id)
	} else {
		match ShareAccount.jwt({ doc, now: fx.clock!() }) {
			None => Machine(doc.id)
			Expired => return Err(ShareAccount.forget_expired({}))
			Live(token) => Account(token)
		}
	}
	reply = fx.http_send!(ShareAccount.forget_request({ origin: begun.origin, version: Help.version, proof }))
	match ShareAccount.delete_answer({ origin: begun.origin, version: Help.version, reply })? {
		Stopped => {
			answer = reply.map_err(|_| {}) ?? { status: 401, headers: [], body: "" }
			return Err(ShareAccount.forget_stopped({ origin: begun.origin, reply: { status: answer.status, body: answer.body } }))
		}
		Done => {}
	}
	high = fx.random!()
	low = fx.random!()
	id = ShareJson.id_of({ high, low })
	ShareFlow.totals_write!(fx, begun.json_path, |current| ShareAccount.forgotten({ doc: current, id }))?
	which = match proof {
		Account(_) => Account
		Machine(_) => Machine
	}
	Ok({ lines: ShareAccount.forget_lines({ proof: which }), data: ShareAccount.forget_data({ proof: which }) })
}
