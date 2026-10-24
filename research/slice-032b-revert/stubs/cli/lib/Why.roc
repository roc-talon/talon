import Args
import Closure
import Common
import Evidence
import Fail
import Fx
import Install
import JsonDoc
import Listing
import Lookup
import Ls
import Opts
import Out
import Ref
import Scope

## The command `tln why <name>` (R-CM7, R-PH12, R-SC1, R-SC6 to R-SC8, R-SC14, R-SC15, R-H4, R-H7, R-C8; slice 011).
## It shows the paths from the app to one package of the closure. P0 has no evidence (R-PH12), so it does not say why a version was chosen, except the mark `raised from <version>` (R-C2).
## Part A is pure (`read`, `row_facts`, `find`, `paths`, `text`, `data`). `run!` is the command code (TESTING.md 2.2 part C): the same steps as `Ls.run!`, then these.
## The texts and the `data` fields are a proposal (R-OUT2, TW24): the human accepts or changes them at the review.
##
## The paths are made of the followed edges only (question Q13 of slice 009): `Closure.Walked.links`. A version that a package names and Roc does not build is not in the closure, so it has no path.
##
## `run!`, in order (the L2 case `closure/cl2-chain` and the L3 case `why/wy1-why` fix the calls and the output):
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Why.read(args)`. A failure is printed with `Out.fail` (no `Fx` call). | R-CM7, R-FL7, R-EC2 |
## | 2 to 8 | The steps 2 to 8 of `Ls.run!`: `Install.begin!`, `Known.record!`, the load of the members, the walk of the current member (else all members). No compiler call, no write except `projects.json`. A failure of the walk is the failure of the run (nothing on stdout). The code is `Ls.walk!` (with `notes` false). It is in `Ls`, not in `ResolveBase`: `ResolveBase` cannot import `Install` (`Install` imports `Resolve`, which imports `ResolveBase`). | R-PD1 to R-PD9, R-H7, R-FE7, R-EC10 |
## | 9 | For each member: `Why.find` over the rows of its walk. A member with no match is left out (question Q23). A failure of `find` is printed with `Out.fail`: its `block` goes to stderr first, then the failure line (R-E4: the failure line is the last line). With no match in any member the failure is `Why.find` of the first member. | R-SC1, R-SC8, R-SC14 |
## | 10 | The output: `Why.text` of each member in the order of the members, or with `--json` only the envelope `Out.json_ok({ command: args.typed, data: Why.data(found) })` (`command` is `why`). The answer is not hidden by `--quiet` (R-FL4). `why` prints no R-C8 line (question Q24). | R-J1 to R-J6, R-OUT4 |
##
## The forms of a name (R-SC6 to R-SC8, `Lookup.find` with the scope `Project`): a header alias, a full name (`owner/repo`, `host/path`), a short name (the repo name, or the repo name without a leading `roc-`).
## An alias of a package that is not a header entry (the alias in the header of a package) is no alias here (R-SC6: an alias is unique in one header). The series is part of the name when 2 packages of one repo are in the closure (R-SC15):
## `roc-lang/http@2`, a typed `owner/repo@sel` picks the entry by its series (question Q12 of slice 004).
Why :: [].{

	## One step of a path: the `alias` of the edge (the key in the header of the package before it, or in the project header for the first step), the `id` of the row that it reaches (`Closure.Row.id`), and its `kind`.
	Step : { alias : Str, id : Str, kind : [Release, Path, Foreign] }

	## The answer of one member: its project file, its walk, and the row of the package (`Why.find`).
	Found : { file : Str, walked : Closure.Walked, target : Closure.Row }

	## One member of `tln why` with its evidence (slice 032b, R-CM7, R-PH12, R-EF3). `evidence` is the block of the package of `found` (`EvidenceFlow.blocks!`).
	Shown : { found : Why.Found, evidence : Evidence.Block }

	## The text of one member with its evidence (a proposal, TW24): `Why.text` of `found`, then `Evidence.text` of the block. With no compiler and with no line the text is the one of `Why.text`, so a `why` with no evidence prints what it printed before.
	show : Why.Shown -> Str
	show = |_shown| crash "todo"

	## The `data` of `--json` with the evidence: the same as `Why.data` (the same keys in the same order), and each member also has the 3 keys of `Evidence.fields` (`compiler`, `evidence`, `notes`) after `paths` (R-OUT4, R-OUT5).
	shown_data : List(Why.Shown) -> JsonDoc
	shown_data = |_members| crash "todo"

	## The operand of `tln why`: exactly one name. `Opts.read` of the line is checked first (its failures: the texts of `Opts.read`, R-FL5). Each failure has the kind `Usage` (exit 2, R-EC2).
	## `Args.parse` has rejected the flags that `why` does not take (R-FL7, R-FL12: `--strategy`, `--frozen`, `--tree`, ...).
	##
	## | Case | Failure |
	## | --- | --- |
	## | No name, or 2 names or more | `tln why takes one name` |
	read : Args -> Try({ name : Str }, Fail)
	read = |args| {
		_ = Opts.read(args)?
		match args.operands {
			[name] => Ok({ name: name })
			_ => Err(Fail.new(Usage, "tln why takes one name"))
		}
	}

	## The facts of the rows for `Lookup.build` (slice 014, R-SC1, R-SC6, R-SC15): one fact for each row, in the order of the rows.
	##
	## | Row | Fact |
	## | --- | --- |
	## | `Release` | `what: Release({ name: Row.name, series: Row.series, version: Row.version })` |
	## | `Path` or `Foreign` | `what: Unmanaged` |
	## | `alias` | `Row.alias` when `Row.direct`, else `""` (R-SC6: an alias of a package header is no alias) |
	## | `role` | `Platform` when `Row.is_platform`, else `Direct` when `Row.direct`, else `Via(Row.via)` |
	row_facts : List(Closure.Row) -> List(Lookup.Fact)
	row_facts = |rows| rows.map(
		|r| {
			what = match r.kind {
				Release => Release({ name: r.name, series: r.series, version: r.version })
				_ => Unmanaged
			}
			role = if r.is_platform {
				Platform
			} else if r.direct {
				Direct
			} else {
				Via(r.via ?? "")
			}
			{ alias: if r.direct r.alias else "", what, role }
		},
	)

	## `Ref.parse` (scope `Project`) and `Lookup.find` of the text over `Lookup.build(row_facts(rows))`. The row is the one with the same alias, name and series as the entity (D10). The result is the row. An entity that is not in the rows is the failure of kind `Usage`: `'<name>' is not in the project` (question Q7 of slice 004).
	## A failure of `Ref.parse` or `Lookup.find` is returned as it is, with its `block` (the tie list of R-SC14, or `""`).
	find : { text : Str, rows : List(Closure.Row) } -> Try(Closure.Row, { fail : Fail, block : Str })
	find = |facts| {
		ref = Ref.parse(facts.text, Scope.Project, Bool.False).map_err(|fail| { fail, block: "" })?
		ents = Lookup.build(row_facts(facts.rows))
		# `Lookup.find` with the scope `Project` never gives `New` (W8), so `New` only needs a key that no row has.
		(alias, name, series) = match Lookup.find(Scope.Project, ref, ents)? {
			Existing(e) => (e.alias, e.name, e.series)
			New(n) => ("", n, "")
		}
		key = |r| (if r.direct r.alias else "", if r.kind == Release r.name else "", if r.kind == Release r.series else "")
		facts.rows.find_first(|r| key(r) == (alias, name, series)).map_err(|_| not_in(facts.text))
	}

	## The paths from the header to the row `target` (`Row.id`), as lists of steps. Each path starts with a link of `from = Err(Header)` and ends with a step that has `id == target`. A path is a chain of links, each link leaves the row that
	## the link before it reached. The order is depth first in the order of `Walked.links` (the order of `Listing.tree`): the links of the header in order, below each link the links of its row in order. All paths are listed, a row that is reached
	## by 2 routes has 2 paths, 2 links with 2 aliases from one package to one row are 2 paths. A row has no loop (`Closure.step` rejects a cycle). A target that no link reaches has no path.
	paths : { walked : Closure.Walked, target : Str } -> List(List(Step))
	paths = |facts| routes(facts.walked, facts.target, Err(Header), [])

	## The text of one member. The first line is the project file. The second line is 2 spaces, the label of the package (`<name> <version>` for a `Release`, else the `name` as written) and, when there are marks, ` (<marks>)` with the
	## marks `direct`, `raised from <version>`, `foreign` joined by `; ` (the marks of `list` without `via`). Then one line for each path of `paths`: 4 spaces, the aliases of the steps joined by ` -> `. A step of kind `Path` has ` (path)`
	## after its alias (question Q15 of slice 009). Each line ends with a line end.
	##
	## ```text
	## /p/main.roc
	##   acme/core 1.1.0 (direct; raised from 1.0.0)
	##     web -> core
	##     web -> text -> core
	##     core
	##     util (path) -> core
	## ```
	text : Found -> Str
	text = |found| {
		target = found.target
		marks = marks_of(target)
		suffix = if marks.is_empty() "" else " (${Str.join_with(marks, "; ")})"
		lines = paths({ walked: found.walked, target: target.id }).map(|p| "    ${Str.join_with(p.map(step_text), " -> ")}\n")
		"${found.file}\n  ${label_of(target)}${suffix}\n${Str.join_with(lines, "")}"
	}

	## The `data` of `--json` (R-J3, R-J4, R-OUT4, R-OUT5). Keys in this order. `members` is a list, one object for each member in the order of the members:
	##
	## | Key | Value |
	## | --- | --- |
	## | `file` | The project file |
	## | `package` | The object of the package as in `data.members[].packages[]` of `tln list --json`: `alias`, `name`, `version` (null for a path or foreign row), `kind`, `id`, `direct`, `via`, `raised`, `foreign`, `platform` |
	## | `paths` | A list of paths. A path is a list of objects `alias`, `kind` (`"release"`, `"path"`, `"foreign"`), `id` |
	data : List(Found) -> JsonDoc
	data = |members| JsonDoc.Obj([("members", Arr(members.map(member_doc)))])

	## The command (the table above).
	run! : Fx, Args => I32
	run! = |fx, args| match Why.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(opts) => match Ls.walk!(fx, args, Bool.False) {
			Err(fail) => Common.failed!(fx, args, fail)
			Ok(closures) => match answers(opts.name, closures) {
				Err({ fail, block }) => {
					if !block.is_empty() fx.err!(block)
					Common.failed!(fx, args, fail)
				}
				Ok(found) => {
					if args.json {
						fx.out!(Out.json_ok({ command: args.typed, data: Why.data(found) }))
					} else {
						for f in found {
							fx.out!(Why.text(f))
						}
					}
					0
				}
			}
		}
	}
}

not_in : Str -> { fail : Fail, block : Str }
not_in = |name| { fail: Fail.new(Usage, "'${name}' is not in the project"), block: "" }

# `<name> <version>` for a release, else the value as written.
label_of : Closure.Row -> Str
label_of = |row| if row.kind == Release "${row.name} ${row.version}" else row.name

# The marks of `list` without `via` (R-CM9).
marks_of : Closure.Row -> List(Str)
marks_of = |row| {
	direct = if row.direct ["direct"] else []
	raised = match row.raised {
		Ok(version) => ["raised from ${version}"]
		Err(None) => []
	}
	direct.concat(raised).concat(if row.kind == Release [] else ["foreign"])
}

step_text : Why.Step -> Str
step_text = |step| match step.kind {
	Path => "${step.alias} (path)"
	_ => step.alias
}

# The routes below the links that leave `from`, depth first. A route ends at the first step that reaches the target. `seen` keeps a route from a loop.
routes : Closure.Walked, Str, Try(Str, [Header]), List(Str) -> List(List(Why.Step))
routes = |walked, target, from, seen| walked.links.keep_if(|l| l.from == from).join_map(
	|l| {
		here = { alias: l.alias, id: l.to, kind: kind_of(walked, l.to) }
		if l.to == target {
			[[here]]
		} else if seen.contains(l.to) {
			[]
		} else {
			routes(walked, target, Ok(l.to), seen.append(l.to)).map(|rest| [here].concat(rest))
		}
	},
)

kind_of : Closure.Walked, Str -> [Release, Path, Foreign]
kind_of = |walked, id| match walked.rows.find_first(|r| r.id == id) {
	Ok(r) => r.kind
	Err(_) => Release
}

member_doc : Why.Found -> JsonDoc
member_doc = |found| JsonDoc.Obj([
	("file", Text(found.file)),
	("package", Listing.object_of(found.target)),
	("paths", Arr(Why.paths({ walked: found.walked, target: found.target.id }).map(|p| Arr(p.map(step_doc))))),
])

step_doc : Why.Step -> JsonDoc
step_doc = |step| JsonDoc.Obj([
	("alias", Text(step.alias)),
	(
		"kind",
		Text(
			match step.kind {
				Release => "release"
				Path => "path"
				Foreign => "foreign"
			},
		),
	),
	("id", Text(step.id)),
])

# Step 9: the row of each member that has the package. A member with no match is left out (Q23). No match in any member: the failure of the first member.
answers : Str, List({ file : Str, walked : Closure.Walked }) -> Try(List(Why.Found), { fail : Fail, block : Str })
answers = |name, closures| {
	results = closures.map(|c| Why.find({ text: name, rows: c.walked.rows }).map_ok(|row| { file: c.file, walked: c.walked, target: row }))
	found = results.keep_oks(|r| r)
	if found.is_empty() {
		match results.first() {
			Ok(Err(e)) => Err(e)
			_ => Err(not_in(name))
		}
	} else {
		Ok(found)
	}
}
