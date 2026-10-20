import Fail
import Text
import header.Header

## What Talon needs from the header of a package release that it fetched (R-DI7, R-PH11): the kind (R-C4), the platform that the
## package names (R-C3) and the URL entries of its dependency record (R-C2, one level). The code uses `roc-app-header` (`Header.parse`).
##
## | Field | Holds | Rule |
## | --- | --- | --- |
## | `kind` | The first keyword of the header: `app`, `package`, `platform` | R-C4 |
## | `pf` | The value of the entry `pf: platform "<url>"` of a package or app header, as in the source. `Err(None)` when there is none. | R-C3 |
## | `deps` | The value of each entry that is not a platform entry and not the `roc` entry, in source order, as in the source. A path entry is in the list as it is. | R-C2, R-H7 |
Release := {
	kind : [App, Package, Platform],
	pf : Try(Str, [None]),
	deps : List(Str),
}.{
	is_eq : _

	## Reads the text of `main.roc` of a package. `path` is for the message. A text with no header: failure of kind `Input`,
	## `<path>: the package has no app, package or platform header`. A header that does not parse: kind `Input`,
	## `<path>:<line>: the header is not valid` (the line of the byte offset, 1-based). Texts are a proposal (TW24).
	## A platform header has no `pf` entry of its own: its `packages` record is its dependency record.
	read : { path : Str, text : Str } -> Try(Release, Fail)
	read = |facts| match Header.parse(facts.text) {
		Err(NoHeader) => Err(Fail.new(Input, "${facts.path}: the package has no app, package or platform header"))
		Err(BadHeader({ offset })) => Err(Fail.new(Input, "${facts.path}:${Text.line_of(facts.text, offset).to_str()}: the header is not valid"))
		Ok(header) => {
			entries = header.entries()
			kind = match header.kind() {
				App => App
				Package => Package
				Platform(_) => Platform
			}
			pf = match entries.find_first(|e| e.is_platform) {
				Ok(e) if kind != Platform => Ok(e.value)
				_ => Err(None)
			}
			Ok({ kind, pf, deps: entries.keep_if(|e| !e.is_platform and e.name != "roc").map(|e| e.value) })
		}
	}
}
