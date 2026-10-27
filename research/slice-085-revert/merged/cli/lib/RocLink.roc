import Args
import Clock
import Common
import Fail
import Fx
import Launch
import Link
import Manage
import Out
import Roots
import Temp
import Text

## The commands `tln roc link <name> <path>` and `tln roc link --copy [--force] <name> <path>` (slice 024b, CLI 6.6: R-R12, R-R13, R-LK1 to R-LK4; R-CM15). Direct style over `Fx` (TESTING.md 2.2 part C): `Link` decides,
## this module orders the calls. `Run.tln!` calls `RocLink.link!` for the command `["roc", "link"]`. The calls, in order (the L2 case `link/lk1-link` and the L3 case `compilers/lk1-link-real` fix them).
## The one new `Fx` call is `copy_file!`.
##
## | Step | Does | Rule |
## | --- | --- | --- |
## | 1 | `Link.read(args)`. A failure is printed with `Common.failed!` (no `Fx` call). | R-CM15, R-FL12 |
## | 2 | `env_all!`, `Roots.from_env`, `cwd!`. The path of the operand is made absolute with `Text.resolve(cwd, typed)`. | R-LK4 |
## | 3 | One `canonical!` call with `full` (step 2 made it with `Text.resolve`), only to check that the file exists. `Link.source` gives `full` (no symbolic link is resolved), or the failure (no such file: exit 2). It is the same check for `link` and `link --copy`. | R-R12, R-R13 |
## | 4 | `Fx.with_lock!` on the item `Roots.item(Toolchain(id))` with `Wait` (the lock of `roc install` and of `roc remove`: `waiting for another tln: <item>` once when it is busy, R-CC5). | R-CC3, R-CC4 |
## | 5 | In the lock: `Launch.toolchains!` (one `list_dirs!`), then `Link.decide`. A failure ends the command (no write). | R-LK2 |
## | 6 | `random!`, then the temp dir `Temp.name({ target: item, hex })`. A link: one `write_atomic!` of `<temp>/.talon.json` (`Link.meta`). A copy: `copy_file!` from `full` to `<temp>/roc`, then `write_atomic!` of `<temp>/.talon.json` last. A failure of a step: `delete!` of the temp dir, then the failure (kind `Environment`: `cannot copy <path>: <error>` or `cannot write <path>`). | R-CC1, R-CC4 step 6, R-LK2 |
## | 7 | `Replace` only: `rename!` of the item to `Manage.trash_name({ item, hex })`. Then `rename!` of the temp dir to the item. Then (`Replace`) `delete!` of the trash dir; a failed delete is ignored (GC removes it, R-CC2). A failed `rename!` of the temp dir deletes the temp dir. | R-CC10, R-LK2 |
## | 8 | The output: `Link.report` on stdout (with `--json` on stderr, and stdout is only the envelope with `Link.data`). `--quiet` hides the stdout line (`Common.shown_fx`). | R-OUT2, R-J3 |
##
## `link` and `link --copy` never write `config.toml` (R-SO15 is for an install), never write `.last-use` (no compiler ran), and never run the target.
RocLink :: [].{

	## Steps 1 to 8.
	link! : Fx, Args => I32
	link! = |fx, args| match Link.read(args) {
		Err(fail) => Common.failed!(fx, args, fail)
		Ok(plan) => match flow!(fx, plan) {
			Ok(done) => {
				print!(fx, args, done)
				0
			}
			Err(fail) => Common.failed!(fx, args, fail)
		}
	}
}

# What `print!` shows: the plan, the absolute path (step 2), and whether `--force` replaced a copy.
Done : { plan : Link.Plan, full : Str, replaced : Bool }

# What the steps in the lock need.
Work : { plan : Link.Plan, full : Str, item : Str, now : U64 }

# Steps 2 to 7.
flow! : Fx, Link.Plan => Try(Done, Fail)
flow! = |fx, plan| {
	env = fx.env_all!()
	roots = Roots.from_env(env)?
	now = Clock.now!(fx, env)?
	lexical = Text.resolve(fx.cwd!(), plan.path)
	canonical = match fx.canonical!([lexical]) {
		[one] => one
		_ => Err(Other("no result"))
	}
	full = Link.source({ typed: plan.path, full: lexical, result: canonical })?
	item = Roots.item(roots, Toolchain(plan.id))
	work = { plan, full, item, now }
	replaced = fx.locked!(item, || make!(fx, roots, work))?
	Ok({ plan, full, replaced })
}

# Steps 5 to 7, in the lock: the decision, the temp dir, and the rename. The result is true for `Replace`.
make! : Fx, Roots, Work => Try(Bool, Fail)
make! = |fx, roots, work| {
	mode = Link.decide({ id: work.plan.id, copy: work.plan.copy, force: work.plan.force, installed: Launch.toolchains!(fx, roots) })?
	hex = Temp.hex(fx.random!())
	temp = Temp.name({ target: work.item, hex })
	trash = Manage.trash_name({ item: work.item, hex })
	build!(fx, work, temp)?
	if mode == Replace {
		match fx.rename!({ from: work.item, to: trash }) {
			Ok(_) => {}
			Err(err) => return Err(dropped!(fx, temp, Fail.new(Environment, "cannot replace ${work.item}: ${Str.inspect(err)}")))
		}
	}
	match fx.rename!({ from: temp, to: work.item }) {
		Ok(_) => {}
		Err(err) => return Err(dropped!(fx, temp, Fail.new(Environment, "cannot make ${work.item}: ${Str.inspect(err)}")))
	}
	if mode == Replace {
		# A failed delete is ignored: the trash dir is stale and GC removes it (R-CC2).
		_ = fx.delete!([trash])
	}
	Ok(mode == Replace)
}

# Step 6: the copy of the binary, then `.talon.json` last. A failure deletes the temp dir.
build! : Fx, Work, Str => Try({}, Fail)
build! = |fx, work, temp| {
	if work.plan.copy {
		match fx.copy_file!({ from: work.full, to: Text.join(temp, "roc") }) {
			Ok(_) => {}
			Err(err) => return Err(dropped!(fx, temp, Fail.new(Environment, "cannot copy ${work.full}: ${Str.inspect(err)}")))
		}
	}
	meta = Link.meta({ id: work.plan.id, kind: kind_of(work.plan), path: work.full, now: work.now })
	match fx.write_atomic!([{ path: Text.join(temp, ".talon.json"), content: meta }]) {
		Ok(_) => Ok({})
		Err({ path, err }) => Err(dropped!(fx, temp, Fail.new(Environment, "cannot write ${path}: ${Str.inspect(err)}")))
	}
}

# The failure, after the delete of the temp dir.
dropped! : Fx, Str, Fail => Fail
dropped! = |fx, temp, fail| {
	_ = fx.delete!([temp])
	fail
}

kind_of : Link.Plan -> [Link, Copy]
kind_of = |plan| if plan.copy Copy else Link

# Step 8: the text, or the envelope. `--quiet` and `--json` hide the stdout line (`Common.shown_fx`).
print! : Fx, Args, Done => {}
print! = |fx, args, done| {
	shown = Common.shown_fx(fx, args)
	kind = kind_of(done.plan)
	for line in Link.report({ id: done.plan.id, kind, path: done.full }) {
		shown.out!(line)
	}
	if args.json {
		fx.out!(Out.json_ok({ command: args.typed, data: Link.data({ id: done.plan.id, kind, path: done.full, replaced: done.replaced }) }))
	}
}
