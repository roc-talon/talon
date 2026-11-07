import lib.Fail
import lib.Fx
import lib.Help
import lib.JsonDoc
import lib.Net
import lib.Nightlies
import lib.Publish
import lib.Registry
import records.Audit
import records.Compat
import records.Work
import Bot

## The compat bot, part C (slice 223; Registry R-MX1, R-MX15, R-MX17): the command code. Direct style over `Fx`. The steps are in `docs/slices/223-compat-bot.md` (section "The flow").
## The exit codes (R-MX18 item 8): 0 done, 1 a hash has no fact or a sweep stays open (reported at the end), 2 usage, 15 no answer, 20 refusal. 2, 15 and 20 stop at once.
BotFlow :: [].{

	## One run of the bot. The operands are the nightly tags to sweep (R-MX18 item 2). Then the hint audit (R-MX13).
	run! : Fx => I32
	run! = |fx| match flow!(fx) {
		Err(fail) => {
			fx.err!("${fail.line()}\n")
			fail.kind.code()
		}
		Ok(problems) => {
			for problem in problems {
				fx.err!("tln: error[internal]: ${problem}\n")
			}
			if problems.is_empty() 0 else 1
		}
	}
}

# `stats` is `Ok` when COMPAT_STATS_DIR is set (slice 229): the dir of the files, the run id and the start time of the run.
Run : { origin : Str, oidc : Publish.Oidc, dir : Str, stats : Try({ dir : Str, id : Str, time : U64 }, [Off]) }

Stat : { wall_ms : U64, cpu_ms : U64, rss_kb : U64 }

# The stats lines of the run so far: the probe lines, the stats of each probe, the nightlies started.
Acc : { lines : List(Str), probes : List(Try(Stat, Str)), tags : U64 }

# The result of a step that can stop: the problems of the run, or the failure. Both keep the stats so far (they are written on every end).
Out : { acc : Acc, problems : List(Str) }

Halt : { fail : Fail, acc : Acc }

halt : Acc -> (Fail -> Halt)
halt = |acc| |fail| { fail, acc }

Sent : { status : U16, body : Str }

Unit : { rows : List(Compat.Row), nofact : U64, lines : List(Str), probes : List(Try(Stat, Str)) }

# One write request: the step names it in a failure, `soft` lets a 422 come back as an answer.
Write : { step : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)], method : [Get, Post, Put, Delete], url : Str, body : Str, soft : Bool }

State : { token : Str, retries : U64, tries : U64, renewed : Bool }

flow! : Fx => Try(List(Str), Fail)
flow! = |fx| {
	operands = fx.args!()
	env = fx.env_all!()
	origin = registry_of(env)?
	oidc = oidc_of(env)?
	dir = match Publish.env_var(env, "RUNNER_TEMP") {
		Ok(text) => text
		Err(Unset) => return Err(Fail.new(Usage, "the compat bot needs a directory for the archives, and RUNNER_TEMP is not set. Run it in a GitHub Actions job."))
	}
	stats = match Publish.env_var(env, "COMPAT_STATS_DIR") {
		Ok(stats_dir) => Ok({ dir: stats_dir, id: Publish.env_var(env, "GITHUB_RUN_ID") ?? "", time: fx.clock!() })
		Err(Unset) => Err(Off)
	}
	run = { origin, oidc, dir, stats }
	tags = if operands.is_empty() listed!(fx)? else named(operands)?
	finished = sweeps!(fx, run, tags)
	acc = match finished {
		Ok(out) => out.acc
		Err(stop) => stop.acc
	}
	write_stats!(fx, run, acc)
	match finished {
		Ok(out) => Ok(out.problems)
		Err(stop) => Err(stop.fail)
	}
}

# Steps 2 to 7: the sweep of each tag, then the audit.
sweeps! : Fx, Run, List(Str) => Try(Out, Halt)
sweeps! = |fx, run, tags| {
	var $acc = { lines: [], probes: [], tags: 0 }
	var $problems = []
	for tag in tags {
		found = sweep_tag!(fx, run, tag, $acc)?
		$acc = found.acc
		$problems = $problems.concat(found.problems)
	}
	audited = audit!(fx, run, $acc)?
	Ok({ acc: audited.acc, problems: $problems.concat(audited.problems) })
}

# Step 6 of the stats (slice 229): when the stats are on and a probe ran, the monthly file and runs.csv, in one write. A failed write is a warning: it never changes the exit code.
write_stats! : Fx, Run, Acc => {}
write_stats! = |fx, run, acc| match run.stats {
	Err(Off) => {}
	Ok(stats) => if acc.lines.is_empty() {
		{}
	} else {
		lines = |head, rows| "${Str.join_with([head].concat(rows), "\n")}\n"
		run_row = Bot.run_line({ run: stats.id, time: stats.time, tags: acc.tags, probes: acc.probes })
		files = [
			{ path: "${stats.dir}/${Bot.month_file(stats.time)}", content: lines(Bot.header(Probes), acc.lines) },
			{ path: "${stats.dir}/runs.csv", content: lines(Bot.header(Runs), [run_row]) },
		]
		match fx.write_atomic!(files) {
			Ok(_) => {}
			Err(bad) => fx.err!("warning: no stats written: ${bad.path}\n")
		}
	}
}

# Step 1: `TALON_REGISTRY` only (R-MX18 item 10), the base URL form of CLI R-RG7.
registry_of : List((Str, Str)) -> Try(Str, Fail)
registry_of = |env| match Publish.env_var(env, "TALON_REGISTRY") {
	Err(Unset) => Err(no_registry("is not set or is empty"))
	Ok("direct") => Err(no_registry("is direct"))
	Ok(text) => match Registry.base(text) {
		Ok(origin) => Ok(origin)
		Err(BadRegistry) => Err(no_registry("is ${text}, and that is not a base URL (https, or http to a loopback host, with no path)"))
	}
}

no_registry : Str -> Fail
no_registry = |what| Fail.new(Usage, "the compat bot needs a registry, and TALON_REGISTRY ${what}. Set TALON_REGISTRY to the base URL of the registry.")

# Step 1: the OIDC variables (R-TP2, R-AP27). The URL is checked first.
oidc_of : List((Str, Str)) -> Try(Publish.Oidc, Fail)
oidc_of = |env| {
	url = Publish.env_var(env, "ACTIONS_ID_TOKEN_REQUEST_URL").map_err(|Unset| no_oidc("ACTIONS_ID_TOKEN_REQUEST_URL"))?
	token = Publish.env_var(env, "ACTIONS_ID_TOKEN_REQUEST_TOKEN").map_err(|Unset| no_oidc("ACTIONS_ID_TOKEN_REQUEST_TOKEN"))?
	Ok({ url, token })
}

no_oidc : Str -> Fail
no_oidc = |name| Fail.new(Usage, "the compat bot needs an OIDC token, and ${name} is not set. In a GitHub Actions job, set permissions: id-token: write.")

# Step 2 (R-MX18 item 2): the operands must be nightly tags.
named : List(Str) -> Try(List(Str), Fail)
named = |operands| {
	for operand in operands {
		if Nightlies.parts(operand).is_err() {
			return Err(Fail.new(Usage, "'${operand}' is not a nightly tag. Use nightly-<date>-<sha>."))
		}
	}
	Ok(operands)
}

# Step 2 (R-MX18 item 2): no operand, so the newest 7 nightly tags of GitHub, oldest first. One request, no retry.
listed! : Fx => Try(List(Str), Fail)
listed! = |fx| {
	reply = fx.http_get!({ url: "https://api.github.com/repos/roc-lang/nightlies/releases?per_page=7", headers: Net.headers({ token: Err(None), etag: Err(None) }) })
	failed = |answer| Bot.failure({ origin: "", step: List, reply: answer })
	match reply {
		Err(Timeout) => Err(failed(Err(NoAnswer("no answer in 20 s"))))
		Err(Failed(why)) => Err(failed(Err(NoAnswer(why))))
		Ok(answer) => {
			if answer.status != 200 return Err(failed(Ok({ status: answer.status, body: answer.body })))
			match Bot.tags(answer.body) {
				Err(BadJson(_)) => Err(failed(Ok({ status: answer.status, body: answer.body })))
				Ok([]) => Err(Fail.new(Network, "the list of nightlies at api.github.com has no nightly tag (${count_text(releases_in(answer.body), "release")} read). The bot stops, and the next run starts again."))
				Ok(list) => Ok(list)
			}
		}
	}
}

# Steps 2 to 6 for one tag. The result is the problems of the tag, which the run reports at its end.
sweep_tag! : Fx, Run, Str, Acc => Try(Out, Halt)
sweep_tag! = |fx, run, tag, before| {
	acc = { ..before, tags: before.tags + 1 }
	put = write!(fx, run, { step: Put(tag), method: Put, url: Bot.url({ origin: run.origin, route: Put(tag) }), body: "", soft: Bool.True }).map_err(halt(acc))?
	if put.status == 422 {
		fx.err!("warning: skipping ${tag}: the registry refused the nightly (422). ${put.body}\n")
		return Ok({ acc, problems: [] })
	}
	fx.out!("put ${tag}: ${if put.status == 201 "new" else "known"}\n")
	work = read_work!(fx, run, tag).map_err(halt(acc))?
	if Bot.done(work) {
		fx.out!("sweep ${tag}: done\n")
		Ok({ acc, problems: [] })
	} else {
		round!(fx, run, tag, { work, held: [], nofact: 0, n: 1, acc })
	}
}

# Steps 3 to 6: one round of a tag. After a 422 `sweep-incomplete`: one more round (at most 2 sweep requests, R-MX18 item 7).
round! : Fx, Run, Str, { work : Work.Answer, held : List(Compat.Row), nofact : U64, n : U64, acc : Acc } => Try(Out, Halt)
round! = |fx, run, tag, state| {
	todo = state.work.missing.keep_if(|hash| !state.held.any(|row| row.hash == hash))
	fx.out!("sweep ${tag}: ${todo.len().to_str()} of ${state.work.members.to_str()} members to probe\n")
	probed = probe!(fx, run, tag, todo).map_err(halt(state.acc))?
	acc = add_stats(state.acc, probed)
	rows = state.held.concat(probed.rows)
	nofact = state.nofact + probed.nofact
	sweep = Bot.sweep({ tag, work: state.work, rowed: rows.map(|row| row.hash) })
	posted = post_all!(fx, run, { tag, audit: Bool.False, posts: Bot.chunks({ rows, sweep }) }).map_err(halt(acc))?
	missing_text = if nofact == 0 [] else ["${count_text(nofact, "probe")} gave no fact, so there is no sweep for ${tag}"]
	match posted {
		Done => Ok({ acc, problems: missing_text })
		Stale => if state.n >= 2 {
			fx.err!("warning: no sweep for ${tag}: the registry answered 422 sweep-incomplete after 2 sweep requests\n")
			Ok({ acc, problems: missing_text.append("no sweep for ${tag}") })
		} else {
			fx.out!("sweep ${tag}: not complete (422), reading the work list again\n")
			work = read_work!(fx, run, tag).map_err(halt(acc))?
			round!(fx, run, tag, { work, held: rows, nofact, n: state.n + 1, acc })
		}
	}
}

# Step 7: the hint audit (R-MX13). The unit pairs are grouped by nightly: steps 4 and 5 for each group, then one post with no sweep.
audit! : Fx, Run, Acc => Try(Out, Halt)
audit! = |fx, run, before| {
	answer = read!(fx, run, { url: Bot.url({ origin: run.origin, route: Audit(200) }), step: GetAudit }).map_err(halt(before))?
	pairs = match Audit.decode(answer.body) {
		Ok(decoded) => decoded.pairs
		Err(BadJson(why)) => return Err({ fail: Fail.new(Network, "the answer of the registry ${run.origin} is not an audit list: ${why}"), acc: before })
	}
	fx.out!("audit: ${count_text(pairs.len(), "pair")}\n")
	var $acc = before
	var $problems = []
	for group in Bot.audit_groups(pairs) {
		probed = probe!(fx, run, group.nightly, group.hashes).map_err(halt($acc))?
		$acc = add_stats($acc, probed)
		posts = Bot.chunks({ rows: probed.rows, sweep: Err(None) })
		_ = post_all!(fx, run, { tag: group.nightly, audit: Bool.True, posts }).map_err(halt($acc))?
		if probed.nofact > 0 {
			$problems = $problems.append("${count_text(probed.nofact, "probe")} gave no fact on ${group.nightly}")
		}
	}
	Ok({ acc: $acc, problems: $problems })
}

add_stats : Acc, Unit -> Acc
add_stats = |acc, probed| { ..acc, lines: acc.lines.concat(probed.lines), probes: acc.probes.concat(probed.probes) }

# Steps 4 and 5: the archive and the probe of each hash on the tag, in two batches of 4 (R-MX18 item 1). A hash with no row is a warning and a count.
probe! : Fx, Run, Str, List(Str) => Try(Unit, Fail)
probe! = |fx, run, tag, hashes| {
	var $nofact = 0
	var $found = []
	for hash in hashes {
		match release!(fx, run, hash) {
			Ok(release) => {
				$found = $found.append({ hash, url: release.url, repo: release.repo })
			}
			Err(Warn(why)) => {
				$nofact = $nofact + 1
				fx.err!("warning: no fact for ${hash} on ${tag}: ${why}\n")
			}
			Err(Stop(fail)) => return Err(fail)
		}
	}
	downloaded = batch!(fx, $found.map(|item| Bot.fetch_job({ dir: run.dir, hash: item.hash, url: item.url })))
	var $ready = []
	for (item, result) in $found.map2(downloaded, |item, result| (item, result)) {
		match result.ended {
			Exited(0) => {
				$ready = $ready.append(item)
			}
			other => {
				$nofact = $nofact + 1
				fx.err!("warning: no fact for ${item.hash} on ${tag}: curl ${ended_text(other)}\n")
			}
		}
	}
	jobs = $ready.map(
		|item| {
			argv = Bot.probe_job({ dir: run.dir, tag, hash: item.hash })
			match run.stats {
				Ok(_) => Bot.timed_job({ time_file: Bot.time_file({ dir: run.dir, hash: item.hash }), argv })
				Err(Off) => argv
			}
		},
	)
	probes = batch!(fx, jobs)
	times = match run.stats {
		Ok(_) => if $ready.is_empty() [] else fx.read_files!($ready.map(|item| Bot.time_file({ dir: run.dir, hash: item.hash })))
		Err(Off) => []
	}
	var $rows = []
	var $lines = []
	var $stats = []
	for (i, (item, result)) in $ready.map2(probes, |item, result| (item, result)).map_with_index(|pair, i| (i, pair)) {
		hash = item.hash
		verdict = Bot.row({ tag, hash, stdout: result.stdout })
		match run.stats {
			Err(Off) => {}
			Ok(stats) => {
				timed = match times.get(i) {
					Ok(Ok(text)) => Bot.time_stats(text)
					_ => Err("no time file")
				}
				if timed.is_err() fx.err!("warning: no time stats for ${hash} on ${tag}\n")
				$stats = $stats.append(timed)
				result_text = match verdict {
					Ok(row) => row.result
					Err(_) => "no-fact"
				}
				$lines = $lines.append(Bot.probe_line({ run: stats.id, time: stats.time, nightly: tag, hash, repo: item.repo, target: "any", result: result_text, stats: timed }))
			}
		}
		match verdict {
			Ok(row) => {
				$rows = $rows.append(row)
				fx.out!("probe ${hash} on ${tag}: ${row.result}\n")
			}
			Err(why) => {
				$nofact = $nofact + 1
				reason = match result.ended {
					Exited(0) => why
					other => "tln probe ${ended_text(other)}"
				}
				fx.err!("warning: no fact for ${hash} on ${tag}: ${reason}\n")
			}
		}
	}
	Ok({ rows: $rows, nofact: $nofact, lines: $lines, probes: $stats })
}

ended_text : [Exited(I32), Signaled(I32), NotStarted(Str)] -> Str
ended_text = |ended| match ended {
	Exited(code) => "exited with ${code.to_str()}"
	Signaled(signal) => "ended with signal ${signal.to_str()}"
	NotStarted(why) => "did not start (${why})"
}

# One `spawn_all!` call, up to 4 at the same time. An empty batch makes no call (R-MX18 item 1).
batch! : Fx, List(List(Str)) => List({ ended : [Exited(I32), Signaled(I32), NotStarted(Str)], stdout : Str, stderr_last : Str })
batch! = |fx, argvs| if argvs.is_empty() [] else fx.spawn_all!({ jobs: argvs.map(|argv| { argv, cwd: Err(Inherit) }), limit: 4 })

# The URL of the first release that is not withdrawn (R-AP2). `Warn` has the reason of the warning for that hash (a 4xx other than 429, R-MX18 item 14); `Stop` ends the run.
release! : Fx, Run, Str => Try({ url : Str, repo : Str }, [Warn(Str), Stop(Fail)])
release! = |fx, run, hash| match get!(fx, run, { url: Bot.url({ origin: run.origin, route: Artifact(hash) }), step: GetArtifact(hash) }) {
	Err(Refused(answer)) => if answer.status < 500 and answer.status != 429 {
		Err(Warn("the registry did not give the artifact (${answer.status.to_str()})"))
	} else {
		Err(Stop(Bot.failure({ origin: run.origin, step: GetArtifact(hash), reply: Ok(answer) })))
	}
	Err(Silent(why)) => Err(Stop(Bot.failure({ origin: run.origin, step: GetArtifact(hash), reply: Err(NoAnswer(why)) })))
	Ok(answer) => match Bot.release_url(answer.body) {
		Ok(url) => Ok({ url, repo: Bot.release_repo(answer.body) })
		Err(NoRelease) => Err(Warn("the artifact has no release that is not withdrawn"))
		Err(BadJson(why)) => Err(Warn(why))
	}
}

# Step 3: the work list of a tag (R-AP39).
read_work! : Fx, Run, Str => Try(Work.Answer, Fail)
read_work! = |fx, run, tag| {
	answer = read!(fx, run, { url: Bot.url({ origin: run.origin, route: Sweeps(tag) }), step: GetSweeps(tag) })?
	match Work.decode(answer.body) {
		Ok(work) => Ok(work)
		Err(BadJson(why)) => Err(Fail.new(Network, "the answer of the registry ${run.origin} is not a work list: ${why}"))
	}
}

# The headers of a read: no `Authorization` (public routes), no local copy (R-AP43).
read_headers : List((Str, Str))
read_headers = Registry.headers({ version: Help.version, body: None }).append(("Cache-Control", "no-cache"))

# One read of a route: the waits of R-AP34 (`Publish.next`, with `renewed` true: a read has no token, so a 401 stops). `Refused` is the answer that stopped it, `Silent` the reason of no answer.
get! : Fx, Run, { url : Str, step : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)] } => Try(Sent, [Refused(Sent), Silent(Str)])
get! = |fx, run, request| get_again!(fx, run, request, 0)

get_again! : Fx, Run, { url : Str, step : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)] }, U64 => Try(Sent, [Refused(Sent), Silent(Str)])
get_again! = |fx, run, request, retries| {
	reply = fx.http_get!({ url: request.url, headers: read_headers })
	match Publish.next({ retries, renewed: Bool.True, reply }) {
		Done => match reply {
			Ok(answer) => Ok({ status: answer.status, body: answer.body })
			Err(_) => Err(Silent("no answer after a good answer"))
		}
		Wait(ms) => {
			fx.sleep!(ms)
			get_again!(fx, run, request, retries + 1)
		}
		Renew => Err(Silent("a read asked for a new token"))
		Stop => match reply {
			Ok(answer) => Err(Refused({ status: answer.status, body: answer.body }))
			Err(Timeout) => Err(Silent("no answer in 20 s"))
			Err(Failed(why)) => Err(Silent(why))
		}
	}
}

# One read of the registry: a 200 is the answer, any other end is a failure of `Bot.failure`.
read! : Fx, Run, { url : Str, step : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)] } => Try(Sent, Fail)
read! = |fx, run, request| match get!(fx, run, request) {
	Ok(answer) => Ok(answer)
	Err(Refused(answer)) => Err(Bot.failure({ origin: run.origin, step: request.step, reply: Ok(answer) }))
	Err(Silent(why)) => Err(Bot.failure({ origin: run.origin, step: request.step, reply: Err(NoAnswer(why)) }))
}

# Step 6: the posts of one tag or audit group, in order. A 422 of a post that has the sweep is `Stale`.
post_all! : Fx, Run, { tag : Str, audit : Bool, posts : List(Compat.Post) } => Try([Done, Stale], Fail)
post_all! = |fx, run, job| {
	for post in job.posts {
		step = if job.audit PostAudit(job.tag) else Post(job.tag)
		sent = write!(fx, run, { step, method: Post, url: Bot.url({ origin: run.origin, route: Compat }), body: Compat.encode_post(post), soft: post.sweep.is_ok() })?
		if sent.status == 422 return Ok(Stale)
		rows = count_text(post.rows.len(), "row")
		text = match post.sweep {
			Ok(sweep) => "${rows}, sweep up to ${sweep.upto_log_index.to_str()}"
			Err(None) => if job.audit rows else "${rows}, no sweep"
		}
		fx.out!("posted ${if job.audit "audit " else ""}${job.tag}: ${text}\n")
	}
	Ok(Done)
}

releases_in : Str -> U64
releases_in = |text| match JsonDoc.parse(text) {
	Ok(Arr(items)) => items.len()
	_ => 0
}

count_text : U64, Str -> Str
count_text = |n, word| if n == 1 "1 ${word}" else "${n.to_str()} ${word}s"

# R-TP2: the OIDC token of one write.
token! : Fx, Run => Try(Str, Fail)
token! = |fx, run| Publish.token(fx.http_send!(Publish.token_request({ oidc: run.oidc, origin: run.origin })))

# One write: a new token, then the request with the waits and the new token of R-AP34 (`Publish.next`).
write! : Fx, Run, Write => Try(Sent, Fail)
write! = |fx, run, request| {
	token = token!(fx, run)?
	send!(fx, run, request, { token, retries: 0, tries: 0, renewed: Bool.False })
}

send! : Fx, Run, Write, State => Try(Sent, Fail)
send! = |fx, run, request, state| {
	has_body = request.method == Post
	headers = Registry.headers({ version: Help.version, body: if has_body Json else None }).append(("Authorization", "Bearer ${state.token}"))
	reply = fx.http_send!({ method: request.method, url: request.url, headers, body: request.body, timeout_s: 20 })
	tries = state.tries + 1
	failed = |answer| Bot.failure({ origin: run.origin, step: request.step, reply: answer })
	match Publish.next({ retries: state.retries, renewed: state.renewed, reply }) {
		Done => match reply {
			Ok(answer) => Ok({ status: answer.status, body: answer.body })
			Err(_) => Err(Fail.new(Internal, "no answer after a good answer"))
		}
		Renew => {
			token = token!(fx, run)?
			send!(fx, run, request, { ..state, token, tries, renewed: Bool.True })
		}
		Wait(ms) => {
			fx.sleep!(ms)
			send!(fx, run, request, { ..state, retries: state.retries + 1, tries })
		}
		Stop => match reply {
			Ok(answer) => if request.soft and answer.status == 422 {
				Ok({ status: 422, body: answer.body })
			} else {
				Err(failed(Ok({ status: answer.status, body: answer.body })))
			}
			Err(Timeout) => Err(failed(Err(NoAnswer("no answer in 20 s"))))
			Err(Failed(why)) => Err(failed(Err(NoAnswer(why))))
		}
	}
}
