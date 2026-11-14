# Private reference of slice 247b (test agent, TW18, not for the code agent): patches the copy root ($1) so the stubs of owner_changed work.
# Use: NOREF=1 MUTATE=mutations/ref247b.py ./ref.sh ...   (NOREF=1: the real code of slice 247 and the stubs of 247b; this script is the reference of 247b.)
import sys, re
root = sys.argv[1]
def edit(path, pairs):
    p = f"{root}/{path}"; s = open(p).read()
    for a, b in pairs:
        if a not in s: sys.exit(f"ref247b: not found in {path}: {a[:70]}")
        s = s.replace(a, b)
    open(p, 'w').write(s)
SUBA = "(SELECT e.action FROM repo_events e WHERE e.repo = %s.repo AND e.action IN (1, 3) ORDER BY e.seq DESC LIMIT 1) AS owner_action, (SELECT e.time FROM repo_events e WHERE e.repo = %s.repo AND e.action IN (1, 3) ORDER BY e.seq DESC LIMIT 1) AS owner_at"
# records
edit("packages/records/Closure.roc", [
 ('owner_changed_to_wire = |_o| crash "todo"', 'owner_changed_to_wire = |o| { action: match o.action { Transfer => "transfer", Recreate => "recreate" }, at: o.at }'),
 ('owner_changed_from_wire = |_w| crash "todo"', 'owner_changed_from_wire = |w| match w.action {\n\t\t"transfer" => Ok({ action: Transfer, at: w.at })\n\t\t"recreate" => Ok({ action: Recreate, at: w.at })\n\t\tother => Err(bad("owner_changed.action", other))\n\t}'),
])
# worker lib
edit("worker/lib/Reads.roc", [
 ('owner_changed_of = |_action, _at| crash "todo"', 'owner_changed_of = |action, at| match (action, at) {\n\t\t(Err(Missing), Err(Missing)) => Ok(Err(None))\n\t\t(Ok(1), Ok(t)) => Ok(Ok({ action: Transfer, at: t }))\n\t\t(Ok(3), Ok(t)) => Ok(Ok({ action: Recreate, at: t }))\n\t\t_ => Err(BadRow("the owner_changed columns are not a transfer or a recreate with a time"))\n\t}'),
 ('state_at: row.state_at, owner_changed: Err(None) })', 'state_at: row.state_at, owner_changed })'),
 ('\t\tOk({ name: row.name, state, successor', '\t\towner_changed = Reads.owner_changed_of(row.owner_action, row.owner_at)?\n\t\tOk({ name: row.name, state, successor'),
])
# the reads
edit("worker/ReadRoutes.roc", [
 ("COALESCE(c.app_installed, 0) AS app_installed FROM repos p", "COALESCE(c.app_installed, 0) AS app_installed, " + SUBA % ("p", "p") + " FROM repos p"),
])
edit("worker/sql/closure/repos.sql", [
 ("p.state_at AS state_at\n", "p.state_at AS state_at, " + SUBA % ("p", "p") + "\n"),
])
# the move routes
edit("worker/MoveRoutes.roc", [
 ("import lib.Publish\n", "import lib.Publish\nimport lib.Reads\n"),
 ("r.state_at AS state_at FROM repos r LEFT JOIN names sn ON sn.id = r.successor LEFT JOIN names o", "r.state_at AS state_at, " + SUBA % ("r", "r") + " FROM repos r LEFT JOIN names sn ON sn.id = r.successor LEFT JOIN names o"),
 ("offer : Try(Str, [Missing]), state_at : U64 }", "offer : Try(Str, [Missing]), state_at : U64, owner_action : Try(I64, [Missing]), owner_at : Try(U64, [Missing]) }"),
 ("r.state_at AS state_at FROM repos r JOIN names n ON n.id = r.repo LEFT JOIN names sn", "r.state_at AS state_at, " + SUBA % ("r", "r") + " FROM repos r JOIN names n ON n.id = r.repo LEFT JOIN names sn"),
 ("ItemSql : { name : Str, state : U64, successor : Try(Str, [Missing]), state_at : U64 }", "ItemSql : { name : Str, state : U64, successor : Try(Str, [Missing]), state_at : U64, owner_action : Try(I64, [Missing]), owner_at : Try(U64, [Missing]) }"),
 ("read_old : List(D1.Result), Str -> Try(Try({ old : Move.Old, state_at : U64 }, [None]), IngestRoutes.Error)", "read_old : List(D1.Result), Str -> Try(Try({ old : Move.Old, state_at : U64, owner_changed : Try(Closure.OwnerChanged, [None]) }, [None]), IngestRoutes.Error)"),
 ("offer: opt(r.offer) }, state_at: r.state_at }))", "offer: opt(r.offer) }, state_at: r.state_at, owner_changed: Reads.owner_changed_of(r.owner_action, r.owner_at).map_err(|_| Fault(\"bad owner_changed\"))? }))"),
 ("item_of(old, known.state_at)", "item_of(old, known.state_at, known.owner_changed)"),
 ("item_of : Move.Old, U64 -> Closure.Repo\n\titem_of = |old, state_at| { name: old.name, state: old.state, successor: old.successor, state_at, owner_changed: Err(None) }", "item_of : Move.Old, U64, Try(Closure.OwnerChanged, [None]) -> Closure.Repo\n\titem_of = |old, state_at, owner_changed| { name: old.name, state: old.state, successor: old.successor, state_at, owner_changed }"),
 ("state_at: r.state_at, owner_changed: Err(None) }\n\t\t\t\t[] =>", "state_at: r.state_at, owner_changed: Reads.owner_changed_of(r.owner_action, r.owner_at).map_err(|_| Fault(\"bad owner_changed\"))? }\n\t\t\t\t[] =>"),
])
