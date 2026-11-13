import records.Closure as Wire
import AuditCheck
import AuditTypes
import Closure
import Fail
import Fx
import Ident
import Project
import JsonDoc
import ResolveBase
import Text
import toml.Toml
import toml.Value

## The audit warnings of a resolve and the download 404 message (slice 244c, R-AU6, R-AU7, R-AU14, R-FE10). Command code over `Fx`; the decisions are in `AuditCheck`.
## `warn!` runs after `ResolveBase.closure_notes!` in `InstallFlow.finish!` and `VerifyFlow`: one `warning: <line>` on stderr for each finding, from the closure answers that the run has. It sends no request. Not `--frozen`, not `--offline`, not `direct` (no closure answer).
## The release lists of a `direct` run are not kept by the pick, so `direct` prints no R-AU7 line yet (open question for the review).
AuditResolve :: [].{

	## The text of the root `talon.toml` (the workspace root, else the file of the project), when the load read it.
	root_toml : { project : Project, loaded : ResolveBase.Loaded } -> Try({ path : Str, text : Str }, [None])
	root_toml = |read| {
		path = match read.project.workspace {
			Ok(w) => Text.join(w.root, "talon.toml")
			Err(Standalone) => Text.join(Text.dir_of(read.loaded.members.first().map_ok(|m| m.file) ?? ""), "talon.toml")
		}
		read.loaded.tomls.find_first(|t| t.path == path).map_ok(|t| { path, text: t.text }).map_err(|_| None)
	}

	## R-AU7: print the warnings and give their `--json` docs (`data.audit_warnings`). `second` is the second answer of a held move; it is searched first (Q-244c-2).
	warn! : Fx, ResolveBase.Request, ResolveBase.Loaded, List({ file : Str, walked : Closure.Walked }), { second : Try(Wire.Answer, [NotRead]), found : List(ResolveBase.Candidates) } => List(JsonDoc)
	warn! = |fx, request, loaded, closures, how| match request.index {
		Answer(a) => {
			answers = match how.second {
				Ok(other) => [other, a.answer]
				Err(NotRead) => [a.answer]
			}
			entries = AuditCheck.entries({ members: closures, tools: [] })
			items = match root_toml({ project: request.project, loaded }) {
				Ok(t) => lenient_items(t.text)
				Err(None) => []
			}
			show!(fx, AuditCheck.resolve_findings({ answers, entries, items }))
		}
		Direct => if request.offline {
			[]
		} else {
			# Q-244d-3: the pages that the pick read (no request). A name that is not `owner/repo` has no list.
			lists = how.found.keep_if(|c| !c.pages.is_empty()).keep_oks(
				|c| match c.name.split_on("/") {
					[owner, repo] => Ok({ owner: owner.with_ascii_lowercased(), repo: repo.with_ascii_lowercased(), list: Pages({ pages: c.pages, redirected: Bool.False }) })
					_ => Err(NoRepo)
				},
			)
			entries = AuditCheck.entries({ members: closures, tools: [] })
			items = match root_toml({ project: request.project, loaded }) {
				Ok(t) => lenient_items(t.text)
				Err(None) => []
			}
			show!(fx, AuditCheck.resolve_direct({ lists, entries, items }))
		}
		_ => []
	}

	show! : Fx, List(AuditTypes.Finding) => List(JsonDoc)
	show! = |fx, found| {
		for f in found {
			fx.err!("warning: ${AuditCheck.resolve_line(f)}\n")
		}
		found.map(AuditCheck.resolve_doc)
	}

	## The data of `--json` with the member `audit_warnings` after the other members, when there is a warning (R-J6: no output of today changes).
	with_warnings : JsonDoc, Try(Fail.Ran, [None]) -> JsonDoc
	with_warnings = |data, ran| match (data, ran) {
		(Obj(members), Ok(found)) if !found.audit.is_empty() => Obj(members.append(("audit_warnings", Arr(found.audit))))
		_ => data
	}

	## R-FE10, R-AU6: a download failure `download of <what> failed: 404 (<url>). Run tln audit to see why.` of a run that has closure answers (`fail.ran`) gets the reason and the fix when the answer has the release state of the URL. Any other failure: as it is.
	explain : Fail, { project : Project, loaded : ResolveBase.Loaded } -> Fail
	explain = |fail, ctx| {
		parts = fail.message.drop_prefix("download of ").split_first(" failed: 404 (")
		match (fail.kind, fail.ran, parts) {
			(Network, Ok(ran), Ok({ before: what, after })) if fail.message.starts_with("download of ") => match after.split_first(")") {
				Ok({ before: url, .. }) => match Ident.of_url(url) {
					Ok(ident) => {
						header = ctx.loaded.members.join_map(|m| m.locked.rows).find_first(|r| r.value == url).map_ok(|r| r.alias)
						name = ident.name ?? what
						entry = { url, name, group: ident.group.form, version: ident.version, hash: ident.hash, alias: header.map_err(|_| None), edge: header ?? "", via: [], tool: Err(None), members: [], why: name }
						found = AuditCheck.resolve_findings({ answers: ran.answers.rev(), entries: [entry], items: [] })
						AuditCheck.download_failed({ what, status: 404, url, index: Registry, finding: found.first().map_err(|_| None) })
					}
					Err(Foreign) => fail
				}
				Err(_) => fail
			}
			_ => fail
		}
	}
}

# The items of `[audit] ignore` that are texts; the rest is skipped (Q620 item 6: only `tln audit` stops for a bad item).
lenient_items : Str -> List(Str)
lenient_items = |text| match Toml.parse(text) {
	Ok(doc) => match Toml.get(doc, ["audit", "ignore"]) {
		Ok(Value.Array(values)) => values.keep_oks(
			|v| match v {
				Value.String(s) => Ok(s)
				_ => Err(NotText)
			},
		)
		_ => []
	}
	Err(_) => []
}
