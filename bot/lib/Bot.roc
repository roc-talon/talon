import lib.Clock
import lib.Fail
import lib.JsonDoc
import lib.Nightlies
import lib.Registry
import records.Audit
import records.Compat
import records.Work

## The compat bot, part A (slice 223; Registry R-MX1, R-MX4, R-MX10, R-MX13, R-MX15, R-MX17, R-AP2, R-AP6, R-AP10, R-AP39, R-AP40). Pure decisions. Stubs: the code agent writes the bodies.
## The doc of each function says the rule. The slice file `docs/slices/223-compat-bot.md` has the questions: a function that a question touches says so.
Bot :: [].{

	## Slice 104k (Design Q575): the answers of R-AP39 and R-AP40 are `records.Work.Answer` (`sweep : Try(Work.Sweep, [None])` with `time`, `log_size`, `members`, `missing`: the hashes without a `bot` row, each once) and `records.Audit.Pair`
	## (`hash`, `nightly`, `target`, `pass_count`, `fail_count`, `crash_count`). The flow decodes with `Work.decode` and `Audit.decode`. Slice 223 depends on 104k.

	## The URL of each route that the bot calls. `origin` is the base URL form of the registry (CLI 1, R-RG7), with no `/` at the end.
	##
	## | Route | URL | Rule |
	## | --- | --- | --- |
	## | `Put(tag)` | `<origin>/v1/toolchains/<tag>` | R-AP6 |
	## | `Sweeps(tag)` | `<origin>/v1/sweeps/<tag>` (no `target`: the default `any`, R-AP67) | R-AP39 |
	## | `Audit(n)` | `<origin>/v1/compat_hints?audit=<n>` | R-AP40 |
	## | `Artifact(hash)` | `<origin>/v1/artifacts/<hash>` | R-AP2 (question Q1) |
	## | `Compat` | `<origin>/v1/compat` | R-AP10 |
	url : { origin : Str, route : [Put(Str), Sweeps(Str), Audit(U64), Artifact(Str), Compat] } -> Str
	url = |x| {
		path = match x.route {
			Put(tag) => "/v1/toolchains/${tag}"
			Sweeps(tag) => "/v1/sweeps/${tag}"
			Audit(n) => "/v1/compat_hints?audit=${n.to_str()}"
			Artifact(hash) => "/v1/artifacts/${hash}"
			Compat => "/v1/compat"
		}
		"${x.origin}${path}"
	}

	## R-AP2, R-MX18 item 1 (Q566): the `url` of the first row of `releases` whose `withdrawn` is `null` (any `yanked`), in `GET /v1/artifacts/{hash}` (`{artifact, releases, repos}`). No such row: `Err(NoRelease)`.
	release_url : Str -> Try(Str, [BadJson(Str), NoRelease])
	release_url = |text| match JsonDoc.parse(text) {
		Err(BadJson) => Err(BadJson("the artifact answer is not JSON"))
		Ok(doc) => {
			releases = match field(doc, "releases") {
				Ok(Arr(items)) => items
				_ => return Err(BadJson("the artifact answer has no releases"))
			}
			live = releases.keep_if(
				|r| match field(r, "withdrawn") {
					Ok(Null) | Err(None) => Bool.True
					Ok(_) => Bool.False
				},
			)
			match live.first() {
				Ok(first) => match field(first, "url") {
					Ok(Text(link)) => Ok(link)
					_ => Err(BadJson("a release has no url"))
				}
				Err(_) => Err(NoRelease)
			}
		}
	}

	## The job that downloads the archive of a hash to `<dir>/<hash>.tar.zst`: `curl -fsSL --output <dir>/<hash>.tar.zst <url>`.
	fetch_job : { dir : Str, hash : Str, url : Str } -> List(Str)
	fetch_job = |x| ["curl", "-fsSL", "--output", "${x.dir}/${x.hash}.tar.zst", x.url]

	## The job that is one unit probe (R-MX15, R-PB1, R-PB7): `env ROC_TOOLCHAIN=<tag> tln probe --json --yes <dir>/<hash>.tar.zst` (R-MX18 item 1).
	probe_job : { dir : Str, tag : Str, hash : Str } -> List(Str)
	probe_job = |x| ["env", "ROC_TOOLCHAIN=${x.tag}", "tln", "probe", "--json", "--yes", "${x.dir}/${x.hash}.tar.zst"]

	## Slice 229 (Design Q606): the stats of one probe from the text of GNU `time -f "%e %U %S %M"`: the last line has the 4 numbers. `%e` is the wall time in seconds with 2 decimals, `%U` and `%S` the user and system CPU seconds,
	## `%M` the peak RSS in KB. `wall_ms` is `%e` in ms, `cpu_ms` is `%U` plus `%S` in ms. GNU time can put a first line `Command exited with non-zero status <n>` or `Command terminated by signal <n>`: it is not the last line, so it is ignored.
	## Empty text, a last line that is not 4 numbers: `Err(why)`.
	time_stats : Str -> Try({ wall_ms : U64, cpu_ms : U64, rss_kb : U64 }, Str)
	time_stats = |text| {
		lines = text.split_on("\n").keep_if(|l| !l.trim().is_empty())
		last = match lines.last() {
			Ok(l) => l.trim()
			Err(_) => return Err("the time text is empty")
		}
		match last.split_on(" ") {
			[wall, user, sys, rss] => {
				wall_ms = dec_ms(wall)?
				cpu_ms = dec_ms(user)? + dec_ms(sys)?
				rss_kb = U64.from_str(rss).map_err(|_| "the peak RSS is not a number")?
				Ok({ wall_ms, cpu_ms, rss_kb })
			}
			_ => Err("the last line of the time text is not 4 numbers")
		}
	}

	## Slice 229 (Q606): the job of `argv` under GNU time: `/usr/bin/time -f "%e %U %S %M" -o <time_file> <argv...>`. `-o` keeps the time text out of the stdout that the bot parses.
	timed_job : { time_file : Str, argv : List(Str) } -> List(Str)
	timed_job = |x| ["/usr/bin/time", "-f", "%e %U %S %M", "-o", x.time_file].concat(x.argv)

	## Slice 229 (Q606): the file that GNU time writes for the probe of `hash`: `<dir>/<hash>.time`.
	time_file : { dir : Str, hash : Str } -> Str
	time_file = |x| "${x.dir}/${x.hash}.time"

	## Slice 229b (Design Q608): the job that installs the compiler of a nightly before its first probe batch: `tln roc install <tag>`. No GNU time, no `--yes`, no `TALON_AUTO_INSTALL` (R-NI6, R-DL4: the command names the download, so it is the consent).
	install_job : { tag : Str } -> List(Str)
	install_job = |x| ["tln", "roc", "install", x.tag]

	## Slice 229 (Q606): the `repo` of the first release of an artifact answer that is not withdrawn (the same release as `release_url`), for example `acme/json`. The empty text when there is none or the member is `null`.
	release_repo : Str -> Str
	release_repo = |text| match JsonDoc.parse(text) {
		Err(BadJson) => ""
		Ok(doc) => {
			releases = match field(doc, "releases") {
				Ok(Arr(items)) => items
				_ => return ""
			}
			live = releases.keep_if(
				|r| match field(r, "withdrawn") {
					Ok(Null) | Err(None) => Bool.True
					Ok(_) => Bool.False
				},
			)
			match live.first() {
				Ok(first) => match field(first, "repo") {
					Ok(Text(repo)) => repo
					_ => ""
				}
				Err(_) => ""
			}
		}
	}

	## Slice 229 (Q606): the header line of a stats file, with no new line at the end. `Probes` is `stats/compat/<YYYY-MM>.csv`, `Runs` is `stats/compat/runs.csv`.
	header : [Probes, Runs] -> Str
	header = |which| match which {
		Probes => "run,time,nightly,hash,repo,target,result,wall_ms,cpu_ms,rss_kb"
		Runs => "run,time,tags,probes,no_stats,wall_ms,cpu_ms,rss_kb"
	}

	## Slice 229 (Q606): the name of the monthly probe file for a time (seconds since the epoch, UTC): `<YYYY-MM>.csv`.
	month_file : U64 -> Str
	month_file = |time| match Clock.format_utc(time).split_on("T") {
		[date, _] => match date.split_on("-") {
			[year, month, _] => "${year}-${month}.csv"
			_ => ""
		}
		_ => ""
	}

	## Slice 229 (Q606): one CSV line (no new line at the end) of a probe, in the order of `header(Probes)`. `time` is `Clock.format_utc`. A `stats` of `Err` gives empty `wall_ms`, `cpu_ms` and `rss_kb`.
	## A field with a comma, a double quote or a new line is in double quotes, and a double quote in it is doubled (RFC 4180).
	probe_line : { run : Str, time : U64, nightly : Str, hash : Str, repo : Str, target : Str, result : Str, stats : Try({ wall_ms : U64, cpu_ms : U64, rss_kb : U64 }, Str) } -> Str
	probe_line = |x| {
		nums = match x.stats {
			Ok(s) => "${s.wall_ms.to_str()},${s.cpu_ms.to_str()},${s.rss_kb.to_str()}"
			Err(_) => ",,"
		}
		fields = [x.run, Clock.format_utc(x.time), x.nightly, x.hash, x.repo, x.target, x.result].map(csv_field)
		"${Str.join_with(fields, ",")},${nums}"
	}

	## Slice 229 (Q606): one CSV line (no new line at the end) of a run, in the order of `header(Runs)`: `run`, `time`, `tags` (nightlies swept, not the audit), `probes` (the number of items of `probes`),
	## `no_stats` (the items that are `Err`), `wall_ms` (the sum over the `Ok` items), `cpu_ms` (the sum), `rss_kb` (the largest, 0 when there is none).
	run_line : { run : Str, time : U64, tags : U64, probes : List(Try({ wall_ms : U64, cpu_ms : U64, rss_kb : U64 }, Str)) } -> Str
	run_line = |x| {
		oks = x.probes.keep_oks(|p| p)
		wall = oks.fold(0.U64, |sum, s| sum + s.wall_ms)
		cpu = oks.fold(0.U64, |sum, s| sum + s.cpu_ms)
		rss = oks.fold(0.U64, |top, s| if s.rss_kb > top s.rss_kb else top)
		no_stats = x.probes.len() - oks.len()
		"${csv_field(x.run)},${Clock.format_utc(x.time)},${x.tags.to_str()},${x.probes.len().to_str()},${no_stats.to_str()},${wall.to_str()},${cpu.to_str()},${rss.to_str()}"
	}

	## R-MX17, R-AP10: the matrix row of one probe from the `stdout` of `tln probe --json` (`data` of CLI 3 R-J3, R-J4; ProbeCmd `Unit`). `target` is `any`, `result` is `data.outcome`
	## (`pass`, `fail`, `hang`, `crash`), `error_digest` is null (Q569). `Err(why)` when the document is not JSON, has `ok` false, is not `kind` `unit`, has another `hash`, or a `compiler` with another nightly id than `tag`
	## (R-IK4: `nightly-2026-July-31-123c5d7` and `nightly-2026-07-31-123c5d7` are equal, Q570): such a probe gives no row.
	row : { tag : Str, hash : Str, stdout : Str } -> Try(Compat.Row, Str)
	row = |x| match JsonDoc.parse(x.stdout) {
		Err(BadJson) => Err("the output of tln probe is not JSON")
		Ok(doc) => {
			if field(doc, "ok") != Ok(Flag(Bool.True)) return Err("tln probe did not succeed")
			data = match field(doc, "data") {
				Ok(d) => d
				Err(None) => return Err("the output has no data")
			}
			if field(data, "kind") != Ok(Text("unit")) return Err("the output is not a unit check")
			if field(data, "hash") != Ok(Text(x.hash)) return Err("the output is for another hash")
			compiler = match field(data, "compiler") {
				Ok(Text(c)) => c
				_ => return Err("the output has no compiler")
			}
			if !Nightlies.same_nightly(compiler, x.tag) return Err("the output is for the compiler ${compiler}")
			match field(data, "outcome") {
				Ok(Text(outcome)) if outcome == "pass" or outcome == "fail" or outcome == "hang" or outcome == "crash" => Ok({ hash: x.hash, nightly: x.tag, target: "any", result: outcome, error_digest: Err(None) })
				_ => Err("the output has no outcome")
			}
		}
	}

	## R-MX4: the sweep of the run. `Ok({ nightly: tag, target: "any", upto_log_index: work.log_size })` when each hash of `work.missing` is in `rowed` (the hashes that have a row of this run), else `Err(None)`.
	## The bound is the log size that the bot read before its probes. An empty `missing` is complete.
	sweep : { tag : Str, work : Work.Answer, rowed : List(Str) } -> Try(Compat.Sweep, [None])
	sweep = |x| if x.work.missing.all(|h| x.rowed.contains(h)) {
		Ok({ nightly: x.tag, target: "any", upto_log_index: x.work.log_size })
	} else {
		Err(None)
	}

	## R-MX13, R-MX10 (the cost table: the audit is grouped by nightly, so each older nightly downloads once): the unit pairs (`target` `any`) of the audit, as one group for each nightly,
	## in the order of the first pair of the nightly, and the hashes of a group in the order of the pairs. A pair of another target is a smoke build (Q568): it is not in a group.
	audit_groups : List(Audit.Pair) -> List({ nightly : Str, hashes : List(Str) })
	audit_groups = |pairs| pairs.keep_if(|p| p.target == "any").fold(
		[],
		|groups, p| match groups.find_first(|g| g.nightly == p.nightly) {
			Ok(_) => groups.map(
				|g| if g.nightly == p.nightly {
					{ ..g, hashes: g.hashes.append(p.hash) }
				} else g,
			)
			Err(_) => groups.append({ nightly: p.nightly, hashes: [p.hash] })
		},
	)

	## R-MX18 item 2 (Q567): the tags of a GitHub release list (`GET https://api.github.com/repos/roc-lang/nightlies/releases?per_page=7`, an array of objects with `tag_name`): the tags that read as a nightly (R-IK4), the others dropped,
	## in the order of R-NS1, oldest first (the list is newest first). Not JSON, or not an array: `BadJson`. An empty result is `Ok([])` (the flow makes the exit 15 `no nightly in the list`).
	tags : Str -> Try(List(Str), [BadJson(Str)])
	tags = |text| match JsonDoc.parse(text) {
		Ok(Arr(items)) => {
			names = items.keep_oks(
				|item| match field(item, "tag_name") {
					Ok(Text(name)) if Nightlies.parts(name).is_ok() => Ok(name)
					_ => Err(None)
				},
			)
			Ok(names.fold([], |acc, name| [name].concat(acc)))
		}
		_ => Err(BadJson("the list is not a JSON array"))
	}

	## R-MX18 item 7 (Q572): a work list with nothing to do: no `missing` and a `sweep` row whose `upto_log_index` is at least `log_size`.
	done : Work.Answer -> Bool
	done = |work| match work.sweep {
		Ok(s) => work.missing.is_empty() and s.upto_log_index >= work.log_size
		Err(None) => Bool.False
	}

	## R-MX18 item 7 (Q572, R-AP46): the bodies of one nightly: the rows in chunks of 500, in order, and the sweep only in the last chunk (its check needs each member row in the matrix). No rows: one body with the sweep only
	## (b2). With `sweep` `Err(None)` (the audit) no body has a sweep. No rows and no sweep: no body.
	chunks : { rows : List(Compat.Row), sweep : Try(Compat.Sweep, [None]) } -> List(Compat.Post)
	chunks = |x| if x.rows.is_empty() {
		match x.sweep {
			Ok(_) => [{ rows: [], sweep: x.sweep }]
			Err(None) => []
		}
	} else {
		parts = x.rows.chunks_of(500)
		last = parts.len() - 1
		parts.map_with_index(|rows, i| { rows, sweep: if i == last x.sweep else Err(None) })
	}

	## R-MX18 item 13, Design Q585 (proposals, R-OUT2): the failure of a registry or GitHub answer. Its own texts, not `Registry.refuse`. `reply` is `Ok` with the status and the body of the answer (the problem details of R-AP21 for a registry answer), or `Err(NoAnswer(why))`.
	## The failure never holds a token: it gets none. `step` is `Put(tag)`, `Post(tag)`, `PostAudit(tag)` (the texts `put <tag>`, `post <tag>`, `post audit <tag>`) or `List` (the GitHub list of Q567).
	##
	## | Case | Kind (exit) | Text |
	## | --- | --- | --- |
	## | 401 or 403 of a write | `rejected` (20) | `the registry <origin> refused the OIDC token of this run (<type>): <detail>. Check that the run is the workflow of BOT_WORKFLOW_REF on the default branch of BOT_REPOSITORY_ID (R-TP7) and that the job has permissions: id-token: write.` |
	## | 400, 404, 409 or 422 of a write | `rejected` (20) | `the registry <origin> refused the <step> (<type>): <detail>. The bot stops. This is a fault of the bot or of the registry data, not of the run.` |
	## | No answer, 429, 5xx or 503 `busy`, after the retries | `network` (15) | `the registry <origin> did not take the <step> after 4 requests (<status or no answer>). The bot stops, and the next run starts again.` |
	## | The GitHub list: no answer, 429, 5xx, a body that does not decode | `network` (15) | `the list of nightlies at api.github.com did not answer (<status or no answer>). The bot stops, and the next run starts again.` |
	failure : { origin : Str, step : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)], reply : Try({ status : U16, body : Str }, [NoAnswer(Str)]) } -> Fail
	failure = |x| match x.reply {
		Err(NoAnswer(_)) => gave_up(x, "no answer")
		Ok(answer) if is_list(x.step) => gave_up(x, answer.status.to_str())
		Ok(answer) => {
			status = answer.status
			if status == 401 or status == 403 {
				found = problem_of(answer)
				Fail.new(Rejected, "the registry ${x.origin} refused the OIDC token of this run (${found.type}): ${found.what}. Check that the run is the workflow of BOT_WORKFLOW_REF on the default branch of BOT_REPOSITORY_ID (R-TP7) and that the job has permissions: id-token: write.")
			} else if status == 429 or status >= 500 {
				gave_up(x, status.to_str())
			} else {
				found = problem_of(answer)
				Fail.new(Rejected, "the registry ${x.origin} refused the ${step_text(x.step)} (${found.type}): ${found.what}. The bot stops. This is a fault of the bot or of the registry data, not of the run.")
			}
		}
	}
}

# The text of a member of a JSON object.
field : JsonDoc, Str -> Try(JsonDoc, [None])
field = |doc, name| match doc {
	Obj(pairs) => match pairs.find_first(|(key, _)| key == name) {
		Ok((_, value)) => Ok(value)
		Err(_) => Err(None)
	}
	_ => Err(None)
}

# The steps are `Put`, `Post`, `PostAudit` and `List`, and the 3 read steps `GetSweeps(Str)`, `GetAudit` and `GetArtifact(Str)`. The type lists the first 4 (a closed union of those 4 is the argument of `BotTest`)
# and is open for the others, which the match names.
step_text : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)] -> Str
step_text = |step| match step {
	Put(tag) => "put ${tag}"
	Post(tag) => "post ${tag}"
	PostAudit(tag) => "post audit ${tag}"
	List => "list"
	GetSweeps(tag) => "get sweeps ${tag}"
	GetAudit => "get audit"
	GetArtifact(hash) => "get artifact ${hash}"
}

# The text of a problem body.
# The type and the detail of the problem details of an answer. An answer with none gives the status.
problem_of : { status : U16, body : Str } -> { type : Str, what : Str }
problem_of = |answer| match Registry.problem(answer) {
	Ok(body) => { type: body.type_text, what: if body.detail.is_empty() body.title else body.detail }
	Err(NotProblem) => { type: "no problem details", what: "HTTP ${answer.status.to_str()}" }
}

# The failure after the retries: the GitHub list, or a registry step.
gave_up : { origin : Str, step : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)], reply : Try({ status : U16, body : Str }, [NoAnswer(Str)]) }, Str -> Fail
gave_up = |x, what| match x.step {
	List => Fail.new(Network, "the list of nightlies at api.github.com did not answer (${what}). The bot stops, and the next run starts again.")
	_ => Fail.new(Network, "the registry ${x.origin} did not take the ${step_text(x.step)} after 4 requests (${what}). The bot stops, and the next run starts again.")
}

is_list : [Put(Str), Post(Str), PostAudit(Str), List, GetSweeps(Str), GetAudit, GetArtifact(Str)] -> Bool
is_list = |step| match step {
	List => Bool.True
	_ => Bool.False
}

# Seconds with up to 3 decimals as ms. GNU time gives 2 decimals.
dec_ms : Str -> Try(U64, Str)
dec_ms = |text| {
	bad = |_| "'${text}' is not a time in seconds"
	match text.split_on(".") {
		[whole] => Ok(U64.from_str(whole).map_err(bad)? * 1000)
		[whole, frac] => {
			scale = match frac.count_utf8_bytes() {
				1 => 100
				2 => 10
				3 => 1
				_ => return Err(bad({}))
			}
			Ok(U64.from_str(whole).map_err(bad)? * 1000 + U64.from_str(frac).map_err(bad)? * scale)
		}
		_ => Err(bad({}))
	}
}

# RFC 4180: a field with a comma, quote or new line is in double quotes, a quote is doubled.
csv_field : Str -> Str
csv_field = |text| if text.contains(",") or text.contains("\"") or text.contains("\n") or text.contains("\r") {
	"\"${text.replace_each("\"", "\"\"")}\""
} else text
