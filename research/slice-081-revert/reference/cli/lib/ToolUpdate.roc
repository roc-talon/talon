import Consent
import Fail
import Ident
import JsonDoc
import Mode
import Prompt
import Toolchain
import ToolManage
import ToolsJson

## The pure decisions of `tln tool update` and `tln tool rebuild` (slice 048, CLI 6.4: R-T7, R-T24, R-T25, R-T5, R-T6, R-T9, R-DL1 to R-DL5, R-NM6). Part A (TESTING.md 2.2). The command code is `ToolUpdateFlow`. The texts, the prompt and the `data` fields are proposals (R-OUT2, TW24): the human accepts or changes them at the review.
##
## ```mermaid
## flowchart TD
##     A["each tool of the command (one name, or all tools: R-T25)"] --> B{"way: the source of the tool (R-T24)"}
##     B -->|"Release"| C["the newest release in min-release-age (R-T9), as tool install app@latest: UpToDate or build"]
##     B -->|"Branch"| D["the commit of the ref now: Same (UpToDate) or Moved (build the new head)"]
##     B -->|"Commit"| E["Pinned: no change, no request"]
##     F["tool rebuild (R-T7): origin: the same source, the recorded compiler (R-T5)"]
##     C --> G["downloads: the compilers that no tool can use (not installed). One prompt for the command (R-DL1, R-T25)"]
##     D --> G
##     F --> G
##     G --> H["build, install under the lock of tools.json (ToolBuild)"]
## ```
ToolUpdate :: [].{

	## What one tool of `tool update` is (R-T24): `Release` (the newest release, as `tool install app@latest`), `Branch` (the head of a branch or a tag now), `Commit` (a sha: no change).
	##
	## | Source | `way` |
	## | --- | --- |
	## | `Release(_)` | `Release` |
	## | `Git(_)` with a ref of 7 or more hex digits (R-SL10) | `Commit` |
	## | `Git(_)` with any other ref | `Branch` |
	way : ToolsJson.Tool -> [Release, Branch, Commit]
	way = |tool| match tool.source {
		Release(_) => Release
		Git(git) => if is_commit(git.ref) Commit else Branch
	}

	## R-T24: the commit of a branch now (`sha`, 40 hex digits, from `GitRef.commit_of`) against the commit of the tool. `Same` when they are equal (nothing to build), else `Moved`. A release tool is `Moved` (the flow does not ask).
	moved : { tool : ToolsJson.Tool, sha : Str } -> [Same, Moved]
	moved = |facts| match facts.tool.source {
		Git(git) if git.commit == facts.sha => Same
		_ => Moved
	}

	## R-T24 (text from the design): `<key>: pinned to commit <first 8 of the commit>`. `commit` is the full commit of the tool.
	pinned_text : { key : Str, commit : Str } -> Str
	pinned_text = |facts| "${facts.key}: pinned to commit ${short(facts.commit)}"

	## R-T24, R-B2 (proposal): `<key> <source text> is up to date`, for example `foo 1.2.0 is up to date` and `baz git main@dd03c09e is up to date`.
	up_to_date_text : ToolsJson.Tool -> Str
	up_to_date_text = |tool| "${tool.key} ${ToolManage.source_text(tool)} is up to date"

	## R-T24 (proposal): `updated <key> <old> to <new> (<name>)`. `old` is `ToolManage.source_text` of the tool, `new` is the source text after the build (`1.2.0`, `git main@1a2b3c4d`).
	updated_text : { tool : ToolsJson.Tool, new : Str } -> Str
	updated_text = |facts| "updated ${facts.tool.key} ${ToolManage.source_text(facts.tool)} to ${facts.new} (${facts.tool.name})"

	## R-T7, R-T5 (proposal): `rebuilt <key> <source text> (<name>) with <compiler id>`. The compiler is the one of the manifest.
	rebuilt_text : { tool : ToolsJson.Tool } -> Str
	rebuilt_text = |facts| "rebuilt ${facts.tool.key} ${ToolManage.source_text(facts.tool)} (${facts.tool.name}) with ${facts.tool.nightly}"

	## What one tool of the command did: `how` is `Updated`, `UpToDate`, `Pinned` or `Rebuilt`. `from` is the source text before (`Updated` only), `to` is the source text after (the current text for the others).
	Outcome : { tool : Str, name : Str, how : [Updated, UpToDate, Pinned, Rebuilt], from : Try(Str, [None]), to : Str }

	## R-J3, R-J4, R-OUT4 (proposal): the `data` of `tool update --json` and `tool rebuild --json`: `tools`, an array with one object for each tool of the command in the order of the processing. The keys: `tool`, `name`, `how` (`updated`, `up_to_date`, `pinned`, `rebuilt`), `from` (the old source text or null), `to`.
	data : List(Outcome) -> JsonDoc
	data = |outcomes| JsonDoc.Obj([("tools", JsonDoc.Arr(outcomes.map(outcome_doc)))])

	## R-T7, R-T5: where `tool rebuild` gets the source of a tool, as the manifest has it. A release: the bundle at `source.url` (its hash is the last part of the URL, `Ident.of_url`). A git tool: the archive of the commit of the repo `name` (`owner/repo`), with the `path` of the tool.
	## A `url` that is no release URL, and a git `name` that is not `owner/repo`: kind `Input` (exit 19), `<key>: the source url <url> is not a release url` and `<key>: the name <name> is not owner/repo, so the source archive is not known`.
	origin : ToolsJson.Tool -> Try([Bundle({ url : Str, hash : Str }), Archive({ owner : Str, repo : Str, commit : Str, path : Try(Str, [None]) })], Fail)
	origin = |tool| match tool.source {
		Release(rel) => match Ident.of_url(rel.url) {
			Ok(ident) => Ok(Bundle({ url: rel.url, hash: ident.hash }))
			Err(Foreign) => Err(Fail.new(Input, "${tool.key}: the source url ${rel.url} is not a release url"))
		}
		Git(git) => match tool.name.split_on("/") {
			[owner, repo] => Ok(Archive({ owner, repo, commit: git.commit, path: tool.path }))
			_ => Err(Fail.new(Input, "${tool.key}: the name ${tool.name} is not owner/repo, so the source archive is not known"))
		}
	}

	## R-T25, R-DL1, R-DL2, R-T5: the compiler releases that the command may have to download: the distinct ids of `pins` (one for each tool that is built: the pin of a new release, the recorded compiler of a rebuild) that are not in `installed`, in the order of `pins`.
	downloads : { pins : List(Str), installed : List(Str) } -> List(Str)
	downloads = |facts| facts.pins.fold(
		[],
		|found, id| if facts.installed.contains(id) or found.contains(id) found else found.append(id),
	)

	## R-T25, R-DL1 to R-DL5, R-NM5, R-NM9, R-HF1: what the command does for `ids` (not empty: `downloads`). One decision for the whole command: the first row that holds wins. `auto` is `TALON_AUTO_INSTALL`, `yes` is `--yes`, `mode` is the mode of the run (`Mode.from_env`, then `Mode.with_tty` for `NeedTty`).
	## Each id is judged by `Consent.required_want` (no answer flag: `tool update` and `tool rebuild` have none).
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | An id is not a nightly tag (`Consent.required_want` is `Refuse`: a `git-` or `link-` compiler cannot be downloaded) | `Stop`: `the compiler <id> is not installed. Run: tln roc install <id>.` (kind `Consent`, exit 13) |
	## | 2 | `auto` is `No` and `yes` is false (`AutoNo`) | `Stop(ToolUpdate.refused(<first id>))` |
	## | 3 | `yes` or `auto` is `Yes` (`Install`) | `Download`: the downloads start, no prompt |
	## | 4 | The mode is interactive (`Ask`) | `Ask`: one prompt for all ids (`prompt`) |
	## | 5 | The mode is `NeedsTty` | `NeedTty` |
	## | 6 | No person and no answer (`NeedsConsent`) | `Stop(consent_stop(ids))` (exit 13) |
	want : { ids : List(Str), auto : [Ask, Yes, No], yes : Bool, mode : Mode } -> [Download, Ask, NeedTty, Stop(Fail)]
	want = |run| {
		judge = |id| Consent.required_want({ id, auto: run.auto, mode: run.mode, yes: run.yes, flag: Err(NoFlag) })
		match run.ids.find_first(|id| judge(id) == Refuse) {
			Ok(id) => Stop(Fail.new(Consent, "the compiler ${id} is not installed. Run: tln roc install ${id}."))
			Err(_) => match run.ids {
				[] => Download
				[first, ..] => match judge(first) {
					AutoNo => Stop(ToolUpdate.refused(first))
					Install => Download
					Ask => Ask
					NeedTty => NeedTty
					NeedsConsent => Stop(ToolUpdate.consent_stop(run.ids))
					Refuse => Stop(Fail.new(Internal, "the download rules gave no answer for ${first}"))
				}
			}
		}
	}

	## R-T25, R-DL5, R-NM5: the failure of a command with `TALON_AUTO_INSTALL=no` and no `--yes`. Kind `Consent` (exit 13). As `Consent.download_refused`, but the ways do not name `--allow-downloads` (`tool update` and `tool rebuild` refuse that flag, R-FL12) (proposal):
	## `the compiler <id> is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install <id>, pass --yes, or set TALON_AUTO_INSTALL=yes.`
	refused : Str -> Fail
	refused = |id| Fail.new(Consent, "the compiler ${id} is not installed. TALON_AUTO_INSTALL=no refuses the download. Run: tln roc install ${id}, pass --yes, or set TALON_AUTO_INSTALL=yes.")

	## R-T25, R-DL4, R-NM5: the failure of a command with no person and no answer. Kind `Consent` (exit 13). It names the flags (proposal): `<n> compiler download(s) needed (<ids>). Pass --yes or set TALON_AUTO_INSTALL=yes.` With 1 id: `1 compiler download is needed (<id>).`, else `<n> compiler downloads are needed (<id>, <id>).`
	consent_stop : List(Str) -> Fail
	consent_stop = |ids| {
		count = ids.len()
		what = if count == 1 "1 compiler download is needed" else "${count.to_str()} compiler downloads are needed"
		Fail.new(Consent, "${what} (${Str.join_with(ids, ", ")}). Pass --yes or set TALON_AUTO_INSTALL=yes.")
	}

	## R-T25, R-DL1, R-NR2, R-NR6, R-NM6 (proposal): the one prompt of the command for the downloads of all tools. `size` is the sum of the sizes of the archives in bytes (`Toolchain.size_text`). Kind `Required(["TALON_AUTO_INSTALL=yes"])` (`Prompt.decide` adds `--yes`), yes/no, the interactive default is `Yes`.
	##
	## | Field | Text |
	## | --- | --- |
	## | `id` | `tool-download` |
	## | `question` | `Download <n> compiler(s), <size>: <id>, <id>?` (`compiler` for 1, `compilers` for more) |
	## | `subject` | `the download of <n> compiler(s)` |
	## | `answer_line` | `Yes`: `downloading <n> compiler(s) (<size>)`. Else: `no download of <n> compiler(s)` |
	prompt : { ids : List(Str), size : U64 } -> Prompt
	prompt = |facts| {
		size = Toolchain.size_text(facts.size)
		count = facts.ids.len()
		what = "${count.to_str()} ${if count == 1 "compiler" else "compilers"}"
		Prompt.{
			id: "tool-download",
			kind: Required(["TALON_AUTO_INSTALL=yes"]),
			shape: YesNo,
			default: Yes,
			question: "Download ${what}, ${size}: ${Str.join_with(facts.ids, ", ")}?",
			subject: "the download of ${what}",
			answer_line: |answer| if answer == Yes "downloading ${what} (${size})" else "no download of ${what}",
		}
	}

	## R-ST6, R-ST11 (Q-U3, review of slice 048): the failure of `tool update` and `tool rebuild` when the bin dir entry of a tool is a file that tln did not write. Kind `Usage` (exit 2). The text does not name `--as` (these commands have no such flag): it names the file and says what to do (proposal):
	## `<path> is not a file that tln wrote, so tln does not replace it. Move or remove that file, then run the command again.`
	foreign_failure : Str -> Fail
	foreign_failure = |path| Fail.new(Usage, "${path} is not a file that tln wrote, so tln does not replace it. Move or remove that file, then run the command again.")

	## R-T25, R-NM5: the failure when a person answers No to the prompt. Kind `Consent` (exit 13). No tool is changed (proposal): `the download of <ids> was declined. No tool was changed.`
	declined : List(Str) -> Fail
	declined = |ids| Fail.new(Consent, "the download of ${Str.join_with(ids, ", ")} was declined. No tool was changed.")
}

# The first 8 digits of a commit.
short : Str -> Str
short = |commit| Str.from_utf8_lossy(commit.to_utf8().take_first(8))

# One outcome of `data`.
outcome_doc : ToolUpdate.Outcome -> JsonDoc
outcome_doc = |o| {
	how = match o.how {
		Updated => "updated"
		UpToDate => "up_to_date"
		Pinned => "pinned"
		Rebuilt => "rebuilt"
	}
	from = match o.from {
		Ok(text) => JsonDoc.Text(text)
		Err(None) => JsonDoc.Null
	}
	JsonDoc.Obj([("tool", JsonDoc.Text(o.tool)), ("name", JsonDoc.Text(o.name)), ("how", JsonDoc.Text(how)), ("from", from), ("to", JsonDoc.Text(o.to))])
}

# R-SL10: a ref of 7 or more hex digits is a commit.
is_commit : Str -> Bool
is_commit = |ref| {
	bytes = ref.to_utf8()
	bytes.len() >= 7 and bytes.all(|b| (b >= 48 and b <= 57) or (b >= 97 and b <= 102) or (b >= 65 and b <= 70))
}
