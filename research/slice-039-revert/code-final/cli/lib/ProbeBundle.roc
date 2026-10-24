import Fail
import Fetch
import Fx
import Item
import Roots
import Temp

## A bundle file as a package (slice 037, R-PB1, R-FE2, R-FE3). `ensure!` puts `<hash>.tar.zst` in `<pkgs>/<hash>/` with the program of `ProbeCmd.unbundler`. The calls, in order (the L2 cases `probe/pc1-targets` and `probe/pc2-range` fix them):
##
## | Step | Call |
## | --- | --- |
## | 1 | One `list_dirs!` of `<pkgs>`. The dir `<hash>` is there: no more call |
## | 2 | `random!`, `make_dirs!` of the temp dir `<pkgs>/<hash>.<hex>.tmp` (R-FE3) |
## | 3 | `copy_file!` of the bundle file into the temp dir |
## | 4 | One `spawn_all!` with `<program> unbundle <hash>.tar.zst` in the temp dir. `Exited(0)` is a success, else exit 16 (`Fetch.unbundle_failed`) |
## | 5 | `rename!` of `<temp>/<hash>` to `<pkgs>/<hash>`. `Exists`: another process won, its copy is as good |
## | 6 | `delete!` of the temp dir, also after a failure (R-CC2) |
ProbeBundle :: [].{

	ensure! : Fx, { roots : Roots, path : Str, hash : Str, program : Str } => Try({}, Fail)
	ensure! = |fx, run| {
		listing = match fx.list_dirs!([run.roots.pkgs]) {
			[Ok(entries)] => entries
			_ => []
		}
		if listing.any(|e| e.is_dir and e.name == run.hash) {
			Ok({})
		} else {
			item = Roots.item(run.roots, Item.Package(run.hash))
			temp = Temp.name({ target: item, hex: Temp.hex(fx.random!()) })
			result = unpack!(fx, run, { item, temp })
			_ = fx.delete!([temp])
			result
		}
	}
}

# Steps 2 to 5 for one temp dir.
unpack! : Fx, { roots : Roots, path : Str, hash : Str, program : Str }, { item : Str, temp : Str } => Try({}, Fail)
unpack! = |fx, run, dirs| {
	archive = "${dirs.temp}/${run.hash}.tar.zst"
	extracted = "${dirs.temp}/${run.hash}"
	match fx.make_dirs!([dirs.temp]) {
		Ok(_) => {}
		Err(_) => return Err(Fail.new(Environment, "cannot make the temp dir ${dirs.temp}"))
	}
	match fx.copy_file!({ from: run.path, to: archive }) {
		Ok(_) => {}
		Err(_) => return Err(Fail.new(Usage, "cannot read the bundle file ${run.path}"))
	}
	done = fx.spawn_all!({ jobs: [{ argv: [run.program, "unbundle", "${run.hash}.tar.zst"], cwd: Ok(dirs.temp) }], limit: 1 })
	match done {
		[{ ended: Exited(0), .. }] => {}
		[r] => {
			plan = { url: run.path, hash: run.hash, what: run.hash, item: dirs.item, temp: dirs.temp, archive, extracted }
			return Err(Fetch.unbundle_failed({ plan, ended: r.ended, last_line: r.stderr_last }))
		}
		_ => return Err(Fail.new(Internal, "the unbundle gave no result"))
	}
	match fx.rename!({ from: extracted, to: dirs.item }) {
		Ok(_) => Ok({})
		Err(Exists) => Ok({})
		Err(err) => Err(Fail.new(Environment, "cannot move ${extracted} to ${dirs.item}: ${Str.inspect(err)}"))
	}
}
