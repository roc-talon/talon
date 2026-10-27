import Fail
import Fx
import Item
import Manage
import Roots
import Temp

## R-CC10, R-GC3 (shared by `roc remove`, slice 024, and `cache gc`, slice 028): the removal of one compiler under its lock.
## The caller holds the lock of `item`. The dir is renamed to `Manage.trash_name`, then the trash dir and the compat dir are deleted.
Trash :: [].{

	## Calls: `random!`, `rename!` of `item` to the trash name, then one `delete!` with the trash dir and the compat dir (`compat` is `Manage.compat_of`: `Err(None)` has no compat dir).
	## A failed `rename!` is a failure of kind `Environment` (exit 18). A failed `delete!` is ignored: the trash dir is stale and GC removes it later (R-CC2).
	move! : Fx, Roots, { item : Str, compat : Try(Str, [None]) } => Try({}, Fail)
	move! = |fx, roots, facts| {
		trash = Manage.trash_name({ item: facts.item, hex: Temp.hex(fx.random!()) })
		match fx.rename!({ from: facts.item, to: trash }) {
			Ok(_) => {}
			Err(err) => return Err(Fail.new(Environment, "cannot remove ${facts.item}: ${Str.inspect(err)}"))
		}
		compat_dir = match facts.compat {
			Ok(compat) => [Roots.item(roots, Item.Compat(compat))]
			Err(None) => []
		}
		_ = fx.delete!([trash].concat(compat_dir))
		Ok({})
	}
}
