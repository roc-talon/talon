import Fail
import Scope
import Selector

## A reference as the user types it: `name[@selector]`, `@selector`, or a nightly tag (CLI 2, R-SL1).
##
## | Field | Holds |
## | --- | --- |
## | `form` | `Bare`: an alias or a short name (no `/`). `Full`: `owner/repo` (R-SC7). `HostPath`: `host/path` with 2 or more `/` and a `.` in the first part (Design 4.1, R-ID3). |
## | `name` | The name text. For the short forms of `tln roc` (R-SL2): `roc-lang/roc`, with form `Full`. |
## | `selector` | `Err(None)` when the text has no `@`. Else the parsed selector (`Selector.parse`). |
##
## The short forms (R-SL2) are valid only in the scope `Roc`:
## `@sel` is `roc-lang/roc@sel`, and a full nightly tag with no `@` is `roc-lang/roc@<tag>`.
## In the other scopes, a text that starts with `@` is a failure. A nightly tag is then a short name (form `Bare`).
##
## The selectors `Nightly` and `Step` select a compiler (R-SL6, R-SL7). In a scope other than `Roc` they are a failure.
## `GitSha` and `GitRef` in the scopes `Install` and `Project` are question Q3 of the slice file.
##
## The failures have the kind `Usage` (R-EC2: bad ref). The texts are a proposal (slice 004, "Output"):
##
## | Case | Message |
## | --- | --- |
## | Name is empty, scope is not `Roc` | `'<text>' has no name: a reference with only @selector is for 'tln roc'` |
## | Selector is empty (`owner/app@`) | `'<text>' has an empty selector after '@'` |
## | `Selector.parse` gives `Unknown` | `bad selector '<sel>' in '<text>': use --git for a branch or tag` |
## | Compiler selector, scope is not `Roc` | `selector '<sel>' in '<text>' is for a compiler: use it with 'tln roc'` |
## | `GitSha` or `GitRef`, scope is `Install` or `Project` (Q3) | `git ref '<sel>' in '<text>' is not for this command: use it with 'tln tool install', 'tln x' or 'tln roc'` |
## | Name is not one of the 3 forms (`a/b/c`, `/x`, `a/`) | `'<text>' is not a package name: use a short name, owner/repo or host/path` |
##
## `<sel>` is the text after `@`, as typed.
Ref := {
	form : [Bare, Full, HostPath],
	name : Str,
	selector : Try(Selector, [None]),
}.{
	is_eq : _

	## `parse(text, scope, git)`: `git` is `--git` (R-FL14: only for `tool install`, `x`, `roc install` and `roc default`).
	parse : Str, Scope, Bool -> Try(Ref, Fail)
	parse = |text, scope, git| match scope {
		Roc => parse_roc(text, git)
		_ => parse_in(text, scope, git)
	}
}

# The scope `Roc` (R-SL2): `@sel` and a full nightly tag are refs to `roc-lang/roc`.
parse_roc : Str, Bool -> Try(Ref, Fail)
parse_roc = |text, git| {
	if text.starts_with("@") {
		with_selector(text, "roc-lang/roc", text.drop_prefix("@"), Scope.Roc, git)
	} else {
		match Selector.parse(text, Bool.False) {
			Ok(Nightly(tag)) => Ok({ form: Full, name: "roc-lang/roc", selector: Ok(Nightly(tag)) })
			_ => parse_in(text, Scope.Roc, git)
		}
	}
}

# The ref has a name, and maybe a selector, after the first `@`.
parse_in : Str, Scope, Bool -> Try(Ref, Fail)
parse_in = |text, scope, git| {
	if text.starts_with("@") {
		return Err(usage("'${text}' has no name: a reference with only @selector is for 'tln roc'"))
	}
	(name, sel) = match text.split_first("@") {
		Ok({ before, after }) => (before, Ok(after))
		Err(NotFound) => (text, Err(None))
	}
	form = form_of(name)?
	match sel {
		Err(None) => Ok({ form, name, selector: Err(None) })
		Ok(sel_text) => with_selector(text, name, sel_text, scope, git)
	}
}

# A full ref: the selector text is read and checked for the scope.
with_selector : Str, Str, Str, Scope, Bool -> Try(Ref, Fail)
with_selector = |text, name, sel_text, scope, git| {
	form = form_of(name)?
	selector = match Selector.parse(sel_text, git) {
		Ok(sel) => sel
		Err(Empty) => return Err(usage("'${text}' has an empty selector after '@'"))
		Err(Unknown) => return Err(usage("bad selector '${sel_text}' in '${text}': use --git for a branch or tag"))
	}
	check_scope(selector, scope, text, sel_text)?
	Ok({ form, name, selector: Ok(selector) })
}

# R-SL6, R-SL7: a compiler selector is for `tln roc`. Q3: a git ref is for `tool`, `x` and `roc`.
check_scope : Selector, Scope, Str, Str -> Try({}, Fail)
check_scope = |selector, scope, text, sel_text| {
	compiler = match selector {
		Nightly(_) | Step(_) => Bool.True
		_ => Bool.False
	}
	git_ref = match selector {
		GitSha(_) | GitRef(_) => Bool.True
		_ => Bool.False
	}
	package_scope = scope == Scope.Install or scope == Scope.Project
	if compiler and scope != Scope.Roc {
		Err(usage("selector '${sel_text}' in '${text}' is for a compiler: use it with 'tln roc'"))
	} else if git_ref and package_scope {
		Err(usage("git ref '${sel_text}' in '${text}' is not for this command: use it with 'tln tool install', 'tln x' or 'tln roc'"))
	} else {
		Ok({})
	}
}

# D6: `Bare` has no `/`. `Full` has one, with 2 parts. `HostPath` has 2 or more, and a `.` in the first part.
form_of : Str -> Try([Bare, Full, HostPath], Fail)
form_of = |name| {
	parts = name.split_on("/")
	bad = Err(usage("'${name}' is not a package name: use a short name, owner/repo or host/path"))
	if parts.any(|part| part.is_empty()) {
		bad
	} else {
		match parts {
			[_] => Ok(Bare)
			[_, _] => Ok(Full)
			[first, ..] => if first.contains(".") Ok(HostPath) else bad
			[] => bad
		}
	}
}

usage : Str -> Fail
usage = |message| Fail.new(Usage, message)
