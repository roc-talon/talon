import Add
import Closure
import Fail
import Fx
import Gather
import Ident
import Pick
import Release
import ResolveBase

## Step G of the flow: `Pick.step` until `Done` or `Fail` (slice 016, R-AL8, R-AL9). Split from `PickFlow` (module size).
## A `Need` goes to `Gather.get!`, the same call as the closure walk makes: one fetch and one read for all ids of the list. A release URL gives a fact
## (`Release.read`), a path file gives a node of the closure (`Release.entries_of`). The facts and the nodes stay for the walk after the pick (R-AL8, source 1).
PickLoop :: [].{

	## `unmanaged` are the header entries that no slot owns, for each member (`Pick.step`). `want_slots` name the keys of `talon.toml` for the check of R-AD33.
	Input : {
		slots : List(Pick.Slot),
		strategy : [Highest, Lowest],
		min_age : U64,
		snapshot : Try(U64, [None]),
		unmanaged : List({ file : Str, entries : List(Closure.Entry) }),
		want_slots : List({ key : Str, name : Str, urls : List(Str) }),
	}

	Looped : { chosen : List(Pick.Chosen), facts : List(ResolveBase.Fact), paths : List(Closure.Node) }

	run! : Fx, ResolveBase.Request, Input, List(ResolveBase.Fact), List(Closure.Node) => Try(Looped, Fail)
	run! = |fx, request, input, facts, paths| match Pick.step({ slots: input.slots, strategy: input.strategy, now: request.now, min_age: input.min_age, snapshot: input.snapshot, facts, unmanaged: input.unmanaged, paths }) {
		Done(chosen) => Ok({ chosen, facts, paths })
		Fail(fail) => Err(fail)
		Need(ids) => {
			got = Gather.get!(fx, { roots: request.roots, net: request.net, offline: request.offline }, ids)?
			var $facts = facts
			var $paths = paths
			for g in got {
				match Ident.of_url(g.id) {
					Ok(_) => {
						$facts = $facts.append({ url: g.id, release: Release.read({ path: g.path, text: g.text })? })
					}
					Err(Foreign) => {
						$paths = $paths.append({ id: g.id, entries: Release.entries_of({ path: g.path, text: g.text })? })
					}
				}
			}
			platform_wants(input.want_slots, $facts)?
			run!(fx, request, input, $facts, $paths)
		}
	}
}

# Q2, R-AD33: a key of `talon.toml` whose release is a platform is not added as a package.
platform_wants : List({ key : Str, name : Str, urls : List(Str) }), List(ResolveBase.Fact) -> Try({}, Fail)
platform_wants = |wants, facts| {
	found = wants.join_map(|w| facts.keep_if(|f| f.release.kind == Platform and w.urls.contains(f.url)).map(|f| (w, f.url)))
	match found {
		[] => Ok({})
		[(w, url), ..] => match Add.decide({ selector: Err(None), chosen: { name: w.name, url, kind: Platform }, platform_flag: Bool.False, no_pin: Bool.False, as_alias: Ok(w.key), header: [] }) {
			Err(fail) => Err(fail)
			Ok(_) => Ok({})
		}
	}
}
