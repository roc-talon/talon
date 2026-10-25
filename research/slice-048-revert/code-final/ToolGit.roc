import Args
import Fail
import GitRef
import JsonDoc
import Ref
import Roots
import Scope
import Text
import ToolInstall
import ToolsJson

## The pure decisions of `tln tool install --git` (slice 048, CLI 6.4: R-T23, R-T26, R-T27, R-T28, R-T2, R-SL8, R-SL10, R-SL11, R-SL13, R-FL12, R-FL14, R-SE12, R-DA3). Part A (TESTING.md 2.2). The command code is `ToolGitFlow`. The ref and the commit come from `GitRef` (slice 045). The texts and the
## `data` fields are proposals (R-OUT2, TW24): the human accepts or changes them at the review.
##
## What the user types for a tool (the scope `Tool`: no short form of `tln roc`, R-SL2):
##
## | Words | Source |
## | --- | --- |
## | `tool install --git owner/app@main` (R-T23) | `owner/app`, ref `main` (a branch, a tag or a sha) |
## | `tool install --git owner/app@main --path apps/cli` | the same, the app is `apps/cli/main.roc` of the source |
## | `tool install owner/app@dd03c09e` (R-SL10: hex only, 7 or more digits, no release matches) | `owner/app`, ref `dd03c09e`, no `--git` |
##
## ```mermaid
## flowchart TD
##     A["read: --git, --path, --as, --roc"] --> B["the commit of the ref now (GitRef.commit_of)"]
##     B --> C{"reuse (R-T26): the same commit is installed?"}
##     C -->|"Keep"| Z["no build"]
##     C -->|"Build"| D["the source archive of the commit, extracted in the temp dir (layout)"]
##     D --> E["main.roc in the app dir: an app (R-T10 form)"]
##     E --> F["the platform check (R-T2), the compiler (R-T11 to R-T21), the build, the lock of tools.json (R-CC6)"]
## ```
ToolGit :: [].{

	## The operand and the flags of one `tool install` line with a git source. `ref` is the app as typed (`Ref.parse` with the scope `Tool`, so `Lookup.find` can read it). `source` is the repo and the typed ref (`GitRef.Source`). `path` is `--path` (`Err(None)` for no `--path`). `as_name` and `roc` as in `ToolInstall.Plan`.
	Plan : { ref : Ref, source : GitRef.Source, path : Try(Str, [None]), as_name : Try(Str, [Unset]), roc : [Auto, Pinned, Installed] }

	## R-T23, R-SL8, R-SL10, R-SL11, R-SL13, R-FL12, R-FL14: the line of `tool install` as a git source. All failures have the kind `Usage` (exit 2). The first row that holds wins:
	##
	## | # | Case | Result |
	## | --- | --- | --- |
	## | 1 | `--git` and `--resolve` | `tln tool install --resolve is not built yet` |
	## | 2 | `--git`, no operand | `tln tool install --git needs one app: owner/app@ref` |
	## | 3 | `--git`, 2 operands or more | `tln tool install --git takes one app, got <n>` |
	## | 4 | `--git`, the operand is not a ref (`Ref.parse(operand, Scope.Tool, true)`) | Its failure |
	## | 5 | `--git`, the name is not `owner/repo` (a short name, `host/path`) | `--git takes a GitHub repository as owner/repo, not '<name>'` |
	## | 6 | `--git`, no selector | `'<operand>' has no ref: use owner/repo@ref` |
	## | 7 | `--roc` with another value than `pinned` and `installed`, `--as` with a text that is no binary name | The failures of `ToolInstall.read` (the same text) |
	## | 8 | `--path` with no `--git` and no sha selector | `tln tool install --path needs a git ref: --git owner/app@ref` |
	## | 9 | `--path` that is empty, starts with `/`, or has a `..` part (R-SE12: the path is a directory of the source archive) | `--path '<dir>' must be a directory inside the repository: a relative path with no '..'` |
	## | 10 | A plan | `Ok(Ok(plan))`. A `--path` ends with no `/` in the plan (`apps/cli/` is `apps/cli`). |
	##
	## No `--git`: one operand with a form `owner/repo` and the selector `GitSha` (`Ref.parse(operand, Scope.Tool, false)`, R-SL10) is a git source, the typed ref is the sha. Every other line, also one that does not parse, is `Ok(Err(NotGit))`: `ToolInstall.read` reads it.
	read : Args -> Try(Try(Plan, [NotGit]), Fail)
	read = |args| {
		if has_flag(args, "--git") {
			resolve_check(args)?
			operand = match args.operands {
				[] => return Err(usage("tln tool install --git needs one app: owner/app@ref"))
				[one] => one
				many => return Err(usage("tln tool install --git takes one app, got ${many.len().to_str()}"))
			}
			parsed = Ref.parse(operand, Scope.Tool, Bool.True)?
			plan_of(args, parsed, git_source(operand, parsed)?)
		} else {
			bare_sha(args)
		}
	}

	## R-T28, R-T26, R-T27 (as `ToolInstall.key` and `installed_key`): the binary name of a git install: `--as`, else the key under which the app is installed already (`ToolInstall.installed_key`: `Ok`), else the repo name.
	key : { plan : Plan, installed : Try(Str, [None]) } -> Str
	key = |facts| match facts.plan.as_name {
		Ok(name) => name
		Err(Unset) => match facts.installed {
			Ok(installed) => installed
			Err(None) => facts.plan.source.repo
		}
	}

	## R-T26 (D-G3): is the installed tool enough for a git request? `installed` is the tool with the key (`Err(None)`: none), `sha` is the commit of the ref now. A git tool with that commit: `Keep(<its source text>)` (no build). Any other tool (another commit, or a release: R-B10, the source kind must be equal): `Build`.
	reuse : { installed : Try(ToolsJson.Entry, [None]), sha : Str } -> [Keep(Str), Build]
	reuse = |facts| match facts.installed {
		Ok(entry) => match entry.source {
			Git(git) if git.commit == facts.sha => Keep(ToolGit.source_text({ ref: git.ref, sha: git.commit }))
			_ => Build
		}
		Err(None) => Build
	}

	## R-T4, R-T23: how a git tool says where it came from: `git <ref>@<first 8 of the commit>` (`git main@dd03c09e`). The `version` of the report and of the line `building ...`.
	source_text : { ref : Str, sha : Str } -> Str
	source_text = |facts| "git ${facts.ref}@${Str.from_utf8_lossy(facts.sha.to_utf8().take_first(8))}"

	## The paths of one source: R-CC1, R-CC2, R-R3, R-R7 (as `GitBuild.plan`). `hex` is `Temp.hex(Fx.random!())`. `path` is `--path`.
	##
	## | Field | Path |
	## | --- | --- |
	## | `temp` | `<cache>/talon/tmp/<hex>`: the dir of this run. The archive, the source and (the build of `ToolBuild`) the output are in it. |
	## | `archive` | `<temp>/source.tar.gz` |
	## | `src` | `<temp>/src`: the source, extracted with no top dir (`Toolchain.tar_command`) |
	## | `dir` | `<src>/<path>`, or `<src>` for no `--path`: the dir that the build runs in |
	## | `file` | `<dir>/main.roc` |
	layout : { roots : Roots, hex : Str, path : Try(Str, [None]) } -> { temp : Str, archive : Str, src : Str, dir : Str, file : Str }
	layout = |facts| {
		temp = Roots.item(facts.roots, TalonTmp(facts.hex))
		src = Text.join(temp, "src")
		dir = match facts.path {
			Ok(path) => Text.join(src, path)
			Err(None) => src
		}
		{ temp, archive: Text.join(temp, "source.tar.gz"), src, dir, file: Text.join(dir, "main.roc") }
	}

	## R-DA3, R-SE12: the failure when the download program is `wget`. Kind `Environment` (exit 18). As `GitRef.needs_curl`, for this command (proposal): `tln tool install --git needs curl, but the download program is wget: a source archive has no published hash, and only curl refuses a redirect to http:// (R-DA3)`.
	needs_curl : {} -> Fail
	needs_curl = |_none| Fail.new(Environment, "tln tool install --git needs curl, but the download program is wget: a source archive has no published hash, and only curl refuses a redirect to http:// (R-DA3)")

	## R-T23, R-T10 (proposal): the failure when the source has no `main.roc` in the app dir. Kind `Usage` (exit 2). With `--path`: `<owner>/<repo>@<ref> has no main.roc in <path>`. Without: `<owner>/<repo>@<ref> has no main.roc at its top. Use --path <dir> for an app in a subdirectory.`
	no_main : { source : GitRef.Source, path : Try(Str, [None]) } -> Fail
	no_main = |facts| match facts.path {
		Ok(path) => usage("${GitRef.name_text(facts.source)} has no main.roc in ${path}")
		Err(None) => usage("${GitRef.name_text(facts.source)} has no main.roc at its top. Use --path <dir> for an app in a subdirectory.")
	}

	## R-T23, R-T10 (proposal): the failure when `main.roc` is not an app (a package or a platform). Kind `Usage` (exit 2): `main.roc of <owner>/<repo>@<ref> is not an app, so tln tool install cannot build it`.
	not_app : GitRef.Source -> Fail
	not_app = |source| usage("main.roc of ${GitRef.name_text(source)} is not an app, so tln tool install cannot build it")

	## R-J3, R-J4, R-OUT4 (proposal): the `data` of `tool install --git --json`, the keys in this order: `tool` (the key), `name`, `source` (`git`), `commit`, `ref`, `path` (only with `--path`), `how` (`installed`, `replaced`, `present`), `previous` (the old source text for `Replaced`, else null), `bin` (the bin dir entry),
	## then for a build only: `nightly` (the compiler id), `target`, `sha256`, `entry` (`hard_link` or `copy`).
	data : { how : ToolInstall.How, key : Str, name : Str, ref : Str, commit : Str, path : Try(Str, [None]), bin : Str, built : Try({ nightly : Str, target : Str, sha256 : Str, entry : [HardLink, Copy] }, [None]) } -> JsonDoc
	data = |facts| {
		(how, previous) = match facts.how {
			Installed => ("installed", JsonDoc.Null)
			Replaced(old) => ("replaced", JsonDoc.Text(old))
			Present => ("present", JsonDoc.Null)
		}
		head = [
			("tool", JsonDoc.Text(facts.key)),
			("name", JsonDoc.Text(facts.name)),
			("source", JsonDoc.Text("git")),
			("commit", JsonDoc.Text(facts.commit)),
			("ref", JsonDoc.Text(facts.ref)),
		]
		with_path = match facts.path {
			Ok(path) => head.append(("path", JsonDoc.Text(path)))
			Err(None) => head
		}
		common = with_path.concat([("how", JsonDoc.Text(how)), ("previous", previous), ("bin", JsonDoc.Text(facts.bin))])
		match facts.built {
			Err(None) => JsonDoc.Obj(common)
			Ok(built) => {
				entry = match built.entry {
					HardLink => "hard_link"
					Copy => "copy"
				}
				JsonDoc.Obj(
					common.concat([
						("nightly", JsonDoc.Text(built.nightly)),
						("target", JsonDoc.Text(built.target)),
						("sha256", JsonDoc.Text(built.sha256)),
						("entry", JsonDoc.Text(entry)),
					]),
				)
			}
		}
	}
}

usage : Str -> Fail
usage = |message| Fail.new(Usage, message)

has_flag : Args, Str -> Bool
has_flag = |args, flag| args.options.any(|(name, _)| name == flag)

option : Args, Str -> Try(Str, [Unset])
option = |args, flag| match args.options.find_first(|(name, _)| name == flag) {
	Ok((_, Ok(value))) => Ok(value)
	_ => Err(Unset)
}

# Row 1: `--resolve` is for a later slice.
resolve_check : Args -> Try({}, Fail)
resolve_check = |args| if has_flag(args, "--resolve") Err(usage("tln tool install --resolve is not built yet")) else Ok({})

# Rows 5 and 6: the repo of the operand (`owner/repo` only) and the typed ref.
git_source : Str, Ref -> Try(GitRef.Source, Fail)
git_source = |operand, parsed| {
	if parsed.form != Full {
		return Err(usage("--git takes a GitHub repository as owner/repo, not '${parsed.name}'"))
	}
	ref = match parsed.selector {
		Ok(GitRef(text)) => text
		Ok(GitSha(text)) => text
		_ => return Err(usage("'${operand}' has no ref: use owner/repo@ref"))
	}
	match parsed.name.split_first("/") {
		Ok({ before, after }) => Ok({ owner: before, repo: after, ref })
		Err(_) => Err(usage("--git takes a GitHub repository as owner/repo, not '${parsed.name}'"))
	}
}

# R-SL10: no `--git`, one `owner/repo@<sha>` operand is a git source. A `--path` with any other line has no git source (row 8).
bare_sha : Args -> Try(Try(Plan, [NotGit]), Fail)
bare_sha = |args| {
	found = match args.operands {
		[one] => match Ref.parse(one, Scope.Tool, Bool.False) {
			Ok(parsed) => match (parsed.form, parsed.selector, parsed.name.split_first("/")) {
				(Full, Ok(GitSha(ref)), Ok({ before, after })) => Ok((parsed, { owner: before, repo: after, ref }))
				_ => Err(NotGit)
			}
			Err(_) => Err(NotGit)
		}
		_ => Err(NotGit)
	}
	match found {
		Ok((parsed, source)) => {
			resolve_check(args)?
			plan_of(args, parsed, source)
		}
		Err(NotGit) => if has_flag(args, "--path") {
			Err(usage("tln tool install --path needs a git ref: --git owner/app@ref"))
		} else {
			Ok(Err(NotGit))
		}
	}
}

# Rows 7, 9 and 10: the flags of a git source.
plan_of : Args, Ref, GitRef.Source -> Try(Try(Plan, [NotGit]), Fail)
plan_of = |args, parsed, source| {
	flags = ToolInstall.read_flags(args)?
	path = match option(args, "--path") {
		Ok(text) => Ok(source_path(text)?)
		Err(Unset) => Err(None)
	}
	Ok(Ok({ ref: parsed, source, path, as_name: flags.as_name, roc: flags.roc }))
}

# Row 9, R-SE12: a relative directory of the source, with no `..` part. A `/` at the end goes.
source_path : Str -> Try(Str, Fail)
source_path = |text| {
	bad = text.is_empty() or text.starts_with("/") or text.split_on("/").any(|part| part == "..")
	if bad {
		Err(usage("--path '${text}' must be a directory inside the repository: a relative path with no '..'"))
	} else {
		Ok(no_end_slash(text))
	}
}

no_end_slash : Str -> Str
no_end_slash = |text| if text.ends_with("/") no_end_slash(text.drop_suffix("/")) else text
