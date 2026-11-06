import lib.Db
import lib.Facts
import lib.Fx
import lib.QueueSend
import lib.Roots
import lib.ShareQueue
import L2Util

## The entry `db` of the L2 test app (slice 066, split from `main.roc`).
##
## Slice 215 adds 2 words: `queue-add <cap> <hash,nightly,target,result,talon_version,queued_at>...` (`ShareQueue.enqueue!` with this cap; it prints `  Queued` or `  Lost`, or `exit <code>` and the line of the failure on stderr)
## and `queue-count` (`db_query!` with `QueueCount`; it prints `  <n>`).
## Slice 216 adds `queue-send <talon_version> [off] [direct] [offline] [env:<NAME>=<value>]...`: `QueueSend.send!` (R-SH4) with the roots of the case and the facts of R-SH2: `share` is `true` (`off`: `false`), the registry is
## `http://127.0.0.1:9` (`direct`: `Direct`), `--offline` is the word `offline`, the environment is `env_all!` (one call) and the words `env:`. It prints `  done` (`send!` prints nothing itself: R-SH4).
L2Db :: [].{

	## Slice 030. See the table in `main.roc` for the entry.
	entry! : Fx, Str => I32
	entry! = |fx, w| {
		cache = "${w}/home/.cache/roc"
		roots = Roots.{ cache, pkgs: "${cache}/packages", build: cache, config: "${w}/home/.config/talon", data: "${w}/home/.local/share/talon" }
		for line in L2Util.file_lines!("${w}/fx/runs").keep_if(|l| !l.starts_with("#")) {
			fx.out!("== ${line}\n")
			given = L2Util.words(line)
			match given {
				["load", .. as specs] => {
					keys = specs.keep_oks(
						|spec| match spec.split_on(":") {
							[hash, nightly, target] => Ok({ hash, nightly, target })
							_ => Err(BadSpec)
						},
					)
					match Facts.load!(fx, { roots, keys }) {
						Ok(rows) => if rows.is_empty() fx.out!("  none\n") else for row in rows {
							fx.out!("  ${Db.fact_line(row)}\n")
						}
						Err(fail) => L2Util.report!(fx, fail)
					}
				}
				["save", mode, .. as specs] => {
					rows = specs.keep_oks(
						|spec| match spec.split_on(":") {
							[hash, nightly, target, outcome, modules, closure] => match Db.outcome_of(outcome) {
								Ok(o) => Ok({ hash, nightly, target, outcome: o, modules: Db.modules_of(modules), closure })
								Err(_) => Err(BadSpec)
							}
							_ => Err(BadSpec)
						},
					)
					match Facts.save!(fx, { roots, rows, existing: if mode == "keep" Keep else Replace }) {
						Ok(Saved) => fx.out!("  Saved\n")
						Ok(Kept) => fx.out!("  Kept\n")
						Err(fail) => L2Util.report!(fx, fail)
					}
				}
				["pin", spec] => match spec.split_on(":") {
					[tag, target, sha256, source] => match Db.source_of(source) {
						Ok(src) => match Facts.pin!(fx, { roots, listed: { tag, target, sha256, source: src } }) {
							Ok(New) => fx.out!("  New\n")
							Ok(Same) => fx.out!("  Same\n")
							Err(fail) => L2Util.report!(fx, fail)
						}
						Err(_) => fx.out!("  bad line\n")
					}
					_ => fx.out!("  bad line\n")
				}
				["queue-add", cap, .. as specs] => {
					rows = specs.keep_oks(
						|spec| match spec.split_on(",") {
							[hash, nightly, target, result, talon_version, queued_at] => match Db.outcome_of(result) {
								Ok(outcome) => Ok({ hash, nightly, target, result: outcome, talon_version, queued_at })
								Err(_) => Err(BadSpec)
							}
							_ => Err(BadSpec)
						},
					)
					match ShareQueue.enqueue!(fx, { roots, rows, cap: U64.from_str(cap) ?? 0 }) {
						Ok(Queued) => fx.out!("  Queued\n")
						Ok(Lost) => fx.out!("  Lost\n")
						Err(fail) => L2Util.report!(fx, fail)
					}
				}
				["queue-send", talon_version, .. as flags] => {
					extra = flags.keep_oks(
						|word| if word.starts_with("env:") {
							match word.drop_prefix("env:").split_first("=") {
								Ok({ before, after }) => Ok((before, after))
								Err(_) => Err(NotEnv)
							}
						} else {
							Err(NotEnv)
						},
					)
					sharing = {
						share: Ok(!flags.contains("off")),
						registry: if flags.contains("direct") Direct else Url("http://127.0.0.1:9"),
						offline: flags.contains("offline"),
						env: fx.env_all!().concat(extra),
					}
					QueueSend.send!(fx, { roots, sharing, talon_version })
					fx.out!("  done\n")
				}
				# Slice 218: `smoke-add <hash,nightly,target,outcome>...` is `db_write!` with `Smoke` (prints `  ok` or `  err`), `smoke-get <hash:nightly:target>...` is `db_query!` with `Smoke` (prints the `Db.smoke_line` of each row, or `  none`).
				["smoke-add", .. as specs] => {
					rows = specs.keep_oks(
						|spec| match spec.split_on(",") {
							[hash, nightly, target, outcome] => match Db.outcome_of(outcome) {
								Ok(found) => Ok({ hash, nightly, target, outcome: found })
								Err(_) => Err(BadSpec)
							}
							_ => Err(BadSpec)
						},
					)
					match fx.db_write!({ path: Roots.item(roots, CompatDb), busy_ms: Db.busy_ms, format: Db.format }, Smoke(rows)) {
						Ok(_) => fx.out!("  ok\n")
						Err(_) => fx.out!("  err\n")
					}
				}
				["smoke-get", .. as specs] => {
					keys = specs.keep_oks(
						|spec| match spec.split_on(":") {
							[hash, nightly, target] => Ok({ hash, nightly, target })
							_ => Err(BadSpec)
						},
					)
					match fx.db_query!({ path: Roots.item(roots, CompatDb), busy_ms: Db.busy_ms, format: Db.format }, Smoke(keys)) {
						Ok(Smoke(rows)) => if rows.is_empty() fx.out!("  none\n") else for row in rows {
							fx.out!("  ${Db.smoke_line(row)}\n")
						}
						Ok(_) => fx.out!("  wrong answer\n")
						Err(_) => fx.out!("  err\n")
					}
				}
				["queue-count"] => match fx.db_query!({ path: Roots.item(roots, CompatDb), busy_ms: Db.busy_ms, format: Db.format }, QueueCount) {
					Ok(QueueCount(n)) => fx.out!("  ${n.to_str()}\n")
					Ok(_) => fx.out!("  wrong answer\n")
					Err(_) => fx.out!("  err\n")
				}
				_ => fx.out!("  bad line\n")
			}
		}
		0
	}
}
