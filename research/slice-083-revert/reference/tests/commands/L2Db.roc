import lib.Db
import lib.Facts
import lib.Fx
import lib.Roots
import L2Util

## The entry `db` of the L2 test app (slice 066, split from `main.roc`).
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
				_ => fx.out!("  bad line\n")
			}
		}
		0
	}
}
