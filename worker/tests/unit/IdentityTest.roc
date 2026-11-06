import lib.Identity
import lib.Problem

IdentityTest :: [].{}

# W0 tests of worker/lib/Identity.roc (slice 113, docs/slices/113-repo-identity.md section 4).
# The rows are plain numbers: the repo ids (R-IK2) are not needed here. W2 (worker/tests/cases/identity/) has the ids from node.

# A row of the name 7: repository 100, owner 10, written at the time 1000.
row = |state, successor, state_at| { repo: 7, repository_id: 100, owner_id: 10, state, successor, state_at, time: 1000 }

active = row(Active, Err(None), 1000)

event = |action, id_before, id_after, owner_before, owner_after, successor| {
	repo: 7,
	action,
	repository_id_before: id_before,
	repository_id_after: id_after,
	owner_id_before: owner_before,
	owner_id_after: owner_after,
	successor,
}

now = 5000

decide = |r, repository_id, owner_id| Identity.decide({ repo: 7, row: r, seen: { repository_id, owner_id }, now })

# R-TP5, R-TP9, R-TP13, Design Q163: no row is a new binding. The row is Active with no successor, state_at and time are the clock, one event Bind with the ids after.
expect {
	decide(Err(None), 100, 10)
		== Ok({
			row: { repo: 7, repository_id: 100, owner_id: 10, state: Active, successor: Err(None), state_at: now, time: now },
			events: [event(Bind, Err(None), Ok(100), Err(None), Ok(10), Err(None))],
		})
}

# R-TP9 row 1: the same repository id and the same owner id is the same repository. Accept, the row is the same, no event (R-TP13: an event for a change only).
expect decide(Ok(active), 100, 10) == Ok({ row: active, events: [] })

# R-TP9 row 2: the same repository id and another owner id is a transfer. The row gets the new owner id; state_at and time stay; the event has the owner before and after.
expect {
	decide(Ok(active), 100, 11)
		== Ok({
			row: { ..active, owner_id: 11 },
			events: [event(Transfer, Ok(100), Ok(100), Ok(10), Ok(11), Err(None))],
		})
}

# R-TP9 row 3: the same owner id and another repository id is a new repository of the owner. The row gets the new repository id (state Active, state_at stays: nothing else changed).
expect {
	decide(Ok(active), 101, 10)
		== Ok({
			row: { ..active, repository_id: 101 },
			events: [event(Recreate, Ok(100), Ok(101), Ok(10), Ok(10), Err(None))],
		})
}

# R-TP9 row 3, R-TP11: a recreate also sets the state Active and clears the successor. A Moved row with a successor (the row 99) and a Missing row change their state: state_at is the clock.
expect {
	moved = row(Moved, Ok(99), 2000)
	missing = row(Missing, Err(None), 2000)
	decide(Ok(moved), 101, 10)
		== Ok({ row: { ..moved, repository_id: 101, state: Active, successor: Err(None), state_at: now }, events: [event(Recreate, Ok(100), Ok(101), Ok(10), Ok(10), Err(None))] })
		and decide(Ok(missing), 101, 10)
			== Ok({ row: { ..missing, repository_id: 101, state: Active, state_at: now }, events: [event(Recreate, Ok(100), Ok(101), Ok(10), Ok(10), Err(None))] })
}

# R-TP11: a Missing row is Active again (event Found) when a read of the same repository id succeeds. A transfer of a Missing row has both events, the transfer first.
expect {
	missing = row(Missing, Err(None), 2000)
	decide(Ok(missing), 100, 10)
		== Ok({ row: { ..missing, state: Active, state_at: now }, events: [event(Found, Ok(100), Ok(100), Ok(10), Ok(10), Err(None))] })
		and decide(Ok(missing), 100, 11)
			== Ok({
				row: { ..missing, owner_id: 11, state: Active, state_at: now },
				events: [event(Transfer, Ok(100), Ok(100), Ok(10), Ok(11), Err(None)), event(Found, Ok(100), Ok(100), Ok(11), Ok(11), Err(None))],
			})
}

# R-TP9 row 4, R-TP11 (the binding stays): both ids different is Changed in each state, also for a Missing row (the repository may be deleted: the name stays bound).
expect {
	states = [active, row(Missing, Err(None), 2000), row(Moved, Ok(99), 2000)]
	states.all(|r| decide(Ok(r), 101, 11) == Err(Changed))
}

# R-TP11, R-PU24 (state part): an Active row that is not found or not public becomes Missing. The ids stay (R-TP9 row 4). A Missing row is the same, with no event.
expect {
	missing = row(Missing, Err(None), 2000)
	Identity.went_missing({ row: active, now })
		== { row: { ..active, state: Missing, state_at: now }, events: [event(Missing, Ok(100), Ok(100), Ok(10), Ok(10), Err(None))] }
		and Identity.went_missing({ row: missing, now }) == { row: missing, events: [] }
}

# R-TP19, Design Q265: a Moved row keeps its state, its successor and its state_at, and adds no event. The state `missing` is for the row of the current name (R-TP14: a moved row keeps its successor).
expect {
	moved = row(Moved, Ok(99), 2000)
	Identity.went_missing({ row: moved, now }) == { row: moved, events: [] }
}

# R-TP10: the name of a rename. The same name in another case is not a rename; another name is, and the result is lower case.
expect {
	Identity.renamed("acme/lib", "acme/lib") == Err(Same)
		and Identity.renamed("acme/lib", "Acme/LIB") == Err(Same)
		and Identity.renamed("acme/lib", "acme/lib2") == Ok("acme/lib2")
		and Identity.renamed("acme/lib", "NewOrg/Lib") == Ok("neworg/lib")
}

# R-TP10: the full_name of the GitHub answer. Other members are ignored (the answer of GitHub has many); a missing member, a member that is not text, and a text that is not JSON are BadRepo.
expect {
	Identity.full_name_of("{\"id\":100,\"full_name\":\"Acme/Lib2\",\"owner\":{\"id\":10},\"visibility\":\"public\"}") == Ok("Acme/Lib2")
		and Identity.full_name_of("{\"id\":100}") == Err(BadRepo)
		and Identity.full_name_of("{\"full_name\":5}") == Err(BadRepo)
		and Identity.full_name_of("{\"full_name\":null}") == Err(BadRepo)
		and Identity.full_name_of("not json") == Err(BadRepo)
		and Identity.full_name_of("") == Err(BadRepo)
}

# R-TP10: the read by id (the reconcile and the webhook have only the id).
expect Identity.repo_by_id_url(812345) == "https://api.github.com/repositories/812345"

# R-RE11, R-RE15: the codes of the columns `repos.state` and `repo_events.action` (sql/0001_init.sql comments; the Worker writes them as integers).
expect {
	states = [Active, Missing, Moved].map(Identity.state_code)
	actions = [Bind, Transfer, Rename, Recreate, Missing, Found, SuccessorSet, SuccessorRemoved, Offer, Operator].map(Identity.action_code)
	states == [0, 1, 2] and actions == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
}

Wire : { type : Str, title : Str, status : U16, detail : Str, issues_url : Str }

# R-TP12, R-AP21: 403 `repository-changed` with the member issues_url (the setting ISSUES_URL) and the 4 members of every problem. The URL is escaped as JSON text.
expect {
	problem = Identity.changed("acme/lib", 812345)
	issues = "https://github.com/roc-talon/talon/issues"
	parsed : Try(Wire, _)
	parsed = Json.parse(Identity.changed_json(problem, issues))
	other : Try(Wire, _)
	other = Json.parse(Identity.changed_json(problem, "https://x.test/a\"b?c=d"))
	problem == Problem.new(RepositoryChanged, "the name acme/lib is bound to another GitHub account (repository id 812345)")
		and Problem.http_status(problem) == 403
		and parsed
			== Ok({ type: "/errors/repository-changed", title: "Repository changed", status: 403, detail: "the name acme/lib is bound to another GitHub account (repository id 812345)", issues_url: issues })
		and other.map_ok(|w| w.issues_url) == Ok("https://x.test/a\"b?c=d")
}
