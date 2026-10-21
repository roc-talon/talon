## The scope of a command: where its names are looked up (CLI 2, R-SC1 to R-SC5).
## One name never means two kinds of things, because each command works in one scope.
##
## | Scope | Commands | Looks in |
## | --- | --- | --- |
## | `Project` | `update`, `upgrade`, `remove`, `why`, `patch`, `probe` | Header entries and the closure (R-SC1) |
## | `Install` | `install` with names (and `add`, `i`) | The project first (a header alias), then the registry index, or GitHub with `direct` (R-SC2) |
## | `Tool` | `tool ...` | `tools.json`. `tool install` with a full name: the index (R-SC3) |
## | `X` | `x` | Installed tools and `x` cache entries. A full name: the index (R-SC4) |
## | `Roc` | `roc ...` | Installed compiler releases (R-SC5) |
Scope := [Install, Project, Tool, X, Roc].{
	is_eq : _

	## The scope of a command. The words are `Args.command` (the long form, R-CM19):
	## `["tool", "install"]`, `["update"]`. A command with no scope (`list`, `verify`, `outdated`,
	## `cache gc`, `setup`) gives `NoScope`.
	of_command : List(Str) -> Try(Scope, [NoScope])
	of_command = |words| match words {
		["install"] => Ok(Install)
		["update"] | ["upgrade"] | ["remove"] | ["why"] | ["patch"] | ["probe"] => Ok(Project)
		["tool", ..] => Ok(Tool)
		["x"] => Ok(X)
		["roc", ..] => Ok(Roc)
		_ => Err(NoScope)
	}
}
