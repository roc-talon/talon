import lib.Db
import lib.Epochs
import lib.Nightlies

EpochsTest :: [].{}

# The expected value of each row is the design text (Resolution 4, R-EP1 to R-EP14), not the code. A wrong row prints its label with `dbg`.
# The ids of the releases are made up: only the order matters (the function reads `id` and never sorts). The hashes are made up too.
# The order of the hashes is the byte order of the text: h1 < h2 < h3.

h1 = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

h2 = "Bz7g9mTqU2oV4tG3a1kKfWm5cD8xNqL6RrPjYsHe2vZu"

h3 = "Gm4Wc7nPq2YkR8vTb5Jd3XaF6sHeZu9LtNw1VoCxEzKy"

host = "linux_x86_64"

# A release with an asset for the host (a candidate) and one with no asset. Both are in the domain D (R-EP11: the `nightly` switch and the range choose candidates in D, they do not remove releases from D).
has_asset : Str -> Nightlies.Release
has_asset = |id| { id, published_at: 0, asset: Ok({ name: "roc_nightly-${host}-${id}.tar.gz", url: "http://127.0.0.1:1/${id}", size: 1, sha256: Err(None) }) }

no_asset : Str -> Nightlies.Release
no_asset = |id| { id, published_at: 0, asset: Err(NoAsset) }

# The releases at the even places (the first, the third, ...) have an asset for the host, the others have none.
domain_of : List(Str) -> List(Nightlies.Release)
domain_of = |ids| ids.map_with_index(|id, i| if i % 2 == 0 has_asset(id) else no_asset(id))

d6 = domain_of(["n1", "n2", "n3", "n4", "n5", "n6"])

iv : Str, Str -> Epochs.Interval
iv = |from, to| { from, to }

# A unit check fact (target `any`, no closure).
fact : Str, Str, Db.Outcome, List(Str) -> Db.Fact
fact = |hash, nightly, outcome, modules| { hash, nightly, target: "any", outcome, modules, closure: "" }

pass_at : Str, Str -> Db.Fact
pass_at = |hash, nightly| fact(hash, nightly, Pass, [])

fail_at : Str, Str, List(Str) -> Db.Fact
fail_at = |hash, nightly, modules| fact(hash, nightly, Fail, modules)

hang_at : Str, Str -> Db.Fact
hang_at = |hash, nightly| fact(hash, nightly, Hang, [])

crash_at : Str, Str -> Db.Fact
crash_at = |hash, nightly| fact(hash, nightly, Crash, [])

# A build fact (target is the host, with a closure digest): not a unit check, so epochs do not read it.
build_at : Str, Str, Db.Outcome -> Db.Fact
build_at = |hash, nightly, outcome| { hash, nightly, target: host, outcome, modules: [], closure: "c0ffee" }

inf_pass : Str, Str, List(Str) -> Epochs.Inferred
inf_pass = |hash, nightly, from| { hash, nightly, outcome: Pass, modules: [], from }

inf_fail : Str, Str, List(Str), List(Str) -> Epochs.Inferred
inf_fail = |hash, nightly, modules, from| { hash, nightly, outcome: Fail, modules, from }

# R-EP4 R-EP11 R-EP13 R-EP5: with no matrix (`direct`), each release of D is an epoch of its own: the epochs are a partition of D into intervals of one release, in the order of D.
# The facts do not change them: all hashes agree on all releases, or they differ, or there are faults (a fault never ends an epoch, and a flat result never joins two releases). A release with no asset is in D.
# The order is the order that the caller gives (R-NS1 order is the caller's job): the function does not sort.
expect {
	singles = |ids| ids.map(|id| iv(id, id))
	agree = [h1, h2, h3].join_map(|h| ["n1", "n2", "n3", "n4", "n5", "n6"].map(|n| pass_at(h, n)))
	mixed = [pass_at(h1, "n1"), fail_at(h1, "n2", ["A.roc"]), hang_at(h1, "n3"), crash_at(h2, "n4"), pass_at(h2, "n5"), fail_at(h3, "n6", [])]
	all6 = singles(["n1", "n2", "n3", "n4", "n5", "n6"])
	rows = [
		(Epochs.partition([]), [], "empty D"),
		(Epochs.partition([has_asset("n1")]), singles(["n1"]), "one release"),
		(Epochs.partition(d6), all6, "6 releases, some with no asset"),
		(Epochs.partition([no_asset("n1"), no_asset("n2")]), singles(["n1", "n2"]), "no asset at all"),
		(Epochs.partition(domain_of(["b", "a", "c"])), singles(["b", "a", "c"]), "the order of the caller, no sort"),
		(Epochs.epochs(d6, []).epochs, all6, "epochs with no fact"),
		(Epochs.epochs(d6, agree).epochs, all6, "a flat result on all releases does not join them"),
		(Epochs.epochs(d6, mixed).epochs, all6, "faults and different results do not change the epochs"),
		(Epochs.epochs([], agree).epochs, [], "empty D with facts"),
	]
	bad = rows.keep_if(|(got, want, _)| got != want).map(|(_, _, label)| label)
	dbg bad
	bad == []
}

# R-EP6 (b) R-EP1 R-EP5 R-EP12 R-EP14 R-EP4: with one epoch for each release, a pair with no real fact gets X when the nearest real code result of the hash before it and the nearest after it are both X.
# `from` names the 2 real facts. A fault is not a code result: it is skipped when the nearest is searched, and its own pair has a real fact, so it gets no inferred fact. A build row is not a unit check.
# A pass next to a fail stays unknown: no row. No result before or after: no row. The rows are by hash (byte order), then by the order of D, whatever the order of the input.
expect {
	got = |facts| Epochs.epochs(d6, facts).inferred
	rows = [
		(got([pass_at(h1, "n1"), pass_at(h1, "n4")]), [inf_pass(h1, "n2", ["n1", "n4"]), inf_pass(h1, "n3", ["n1", "n4"])], "pass, 2 gaps, pass"),
		(got([fail_at(h1, "n1", ["A.roc", "B.roc"]), fail_at(h1, "n3", ["A.roc", "B.roc"])]), [inf_fail(h1, "n2", ["A.roc", "B.roc"], ["n1", "n3"])], "fail copies the failing modules"),
		(got([fail_at(h1, "n1", ["B.roc"]), fail_at(h1, "n3", ["A.roc", "C.roc"])]), [inf_fail(h1, "n2", ["A.roc", "B.roc", "C.roc"], ["n1", "n3"])], "2 sources with different modules: the sorted union (Q1)"),
		(got([fail_at(h1, "n1", []), fail_at(h1, "n3", [])]), [inf_fail(h1, "n2", [], ["n1", "n3"])], "fail with no module"),
		(got([pass_at(h1, "n1"), fail_at(h1, "n3", ["A.roc"])]), [], "pass then fail stays unknown"),
		(got([fail_at(h1, "n1", ["A.roc"]), pass_at(h1, "n3")]), [], "fail then pass stays unknown"),
		(got([pass_at(h1, "n3")]), [], "one result only"),
		(got([pass_at(h1, "n1"), pass_at(h1, "n2")]), [], "no result after"),
		(got([fail_at(h1, "n5", [])]), [], "a fail only"),
		(got([pass_at(h1, "n1"), pass_at(h1, "n6")]), ["n2", "n3", "n4", "n5"].map(|n| inf_pass(h1, n, ["n1", "n6"])), "4 gaps, in the order of D"),
		(got([pass_at(h1, "n1"), fail_at(h1, "n3", []), fail_at(h1, "n5", [])]), [inf_fail(h1, "n4", [], ["n3", "n5"])], "the nearest results, not the first and the last"),
		(got([]), [], "no fact"),
		(got([pass_at(h1, "n1"), hang_at(h1, "n2"), pass_at(h1, "n3")]), [], "a fault has a real fact: no inferred fact"),
		(got([pass_at(h1, "n1"), crash_at(h1, "n2"), pass_at(h1, "n3")]), [], "a crash has a real fact: no inferred fact"),
		(got([pass_at(h1, "n1"), hang_at(h1, "n2"), pass_at(h1, "n4")]), [inf_pass(h1, "n3", ["n1", "n4"])], "a fault is skipped when the nearest result is searched"),
		(got([pass_at(h1, "n1"), crash_at(h1, "n3"), fail_at(h1, "n5", [])]), [], "after a crash the nearest result is the fail: unknown"),
		(got([hang_at(h1, "n1"), crash_at(h1, "n4")]), [], "faults only"),
		(got([build_at(h1, "n1", Pass), build_at(h1, "n3", Pass)]), [], "build rows are no source"),
		(got([pass_at(h1, "n1"), build_at(h1, "n2", Fail), pass_at(h1, "n3")]), [inf_pass(h1, "n2", ["n1", "n3"])], "a build row is no real fact of the unit pair"),
		(got([pass_at(h1, "n1"), build_at(h1, "n3", Pass)]), [], "a build row is no source for a gap"),
		(got([pass_at(h1, "n1"), pass_at(h1, "n3"), pass_at(h1, "x9")]), [inf_pass(h1, "n2", ["n1", "n3"])], "a release that is not in D is ignored"),
		(got([pass_at(h1, "n1"), pass_at(h1, "x9")]), [], "a result on a release that is not in D is no source"),
		(
			got([pass_at(h2, "n1"), fail_at(h2, "n2", ["A.roc"]), fail_at(h2, "n4", ["A.roc"]), pass_at(h1, "n3"), pass_at(h1, "n6"), pass_at(h1, "n1")]),
			[inf_pass(h1, "n2", ["n1", "n3"]), inf_pass(h1, "n4", ["n3", "n6"]), inf_pass(h1, "n5", ["n3", "n6"]), inf_fail(h2, "n3", ["A.roc"], ["n2", "n4"])],
			"2 hashes, the input order is not the output order",
		),
	]
	bad = rows.keep_if(|(got_rows, want, _)| got_rows != want).map(|(_, _, label)| label)
	dbg bad
	bad == []
}

# R-EP6 (a) R-EP5 R-EP14 R-EP4: with epochs of more than one release (the P2 matrix will give them), a pair with no real fact gets X when the hash has a real code result X in the epoch of the pair.
# The result is the set of the X of both cases: one X is an inferred fact, `Pass` and `Fail` together (also both inside the epoch) leave the pair unknown. `from` is the sources of the cases, in the order of D, with no repeat.
# A release that no interval holds is an epoch of its own, so `epochs: []` is the case of the other expect. A fault in an epoch is never a source and its pair gets no inferred fact. Facts of another epoch do not reach in.
expect {
	two = [iv("n1", "n3"), iv("n4", "n6")]
	infer = |epochs, facts| Epochs.infer({ domain: d6, epochs, facts })
	rows = [
		(infer(two, [pass_at(h1, "n2")]), [inf_pass(h1, "n1", ["n2"]), inf_pass(h1, "n3", ["n2"])], "pass in the epoch, the other epoch has none"),
		(infer(two, [fail_at(h1, "n2", ["A.roc"])]), [inf_fail(h1, "n1", ["A.roc"], ["n2"]), inf_fail(h1, "n3", ["A.roc"], ["n2"])], "fail copies the failing modules"),
		(infer(two, [pass_at(h1, "n1"), pass_at(h1, "n3")]), [inf_pass(h1, "n2", ["n1", "n3"])], "2 sources in the epoch"),
		(infer(two, [fail_at(h1, "n1", ["B.roc"]), fail_at(h1, "n3", ["A.roc", "C.roc"])]), [inf_fail(h1, "n2", ["A.roc", "B.roc", "C.roc"], ["n1", "n3"])], "2 fail sources with different modules: the sorted union (Q1)"),
		(infer(two, [fail_at(h1, "n1", ["A.roc"]), fail_at(h1, "n3", ["A.roc"])]), [inf_fail(h1, "n2", ["A.roc"], ["n1", "n3"])], "2 fail sources with one set of modules"),
		(
			infer([iv("n1", "n2"), iv("n3", "n4")], [pass_at(h1, "n1"), pass_at(h1, "n4")]),
			[inf_pass(h1, "n2", ["n1", "n4"]), inf_pass(h1, "n3", ["n1", "n4"])],
			"case (a) and case (b) with the same X: the sources of both, in the order of D, no repeat",
		),
		(infer([iv("n1", "n4")], [pass_at(h1, "n1"), fail_at(h1, "n2", []), fail_at(h1, "n4", [])]), [], "a pass and a fail in the epoch: unknown"),
		(infer([iv("n1", "n3")], [pass_at(h1, "n1"), fail_at(h1, "n3", [])]), [], "pass and fail at the ends of the epoch: unknown"),
		(infer([iv("n1", "n2")], [pass_at(h1, "n1"), fail_at(h1, "n2", [])]), [], "both pairs have a real fact"),
		(infer([iv("n1", "n3")], [pass_at(h1, "n1"), hang_at(h1, "n2")]), [inf_pass(h1, "n3", ["n1"])], "a fault has a real fact, it is no source"),
		(infer([iv("n1", "n3")], [hang_at(h1, "n2")]), [], "a fault only: no inferred fact in its epoch"),
		(infer([iv("n1", "n3")], [crash_at(h1, "n1"), crash_at(h1, "n3")]), [], "faults at the ends"),
		(
			infer(two, [pass_at(h1, "n1"), fail_at(h1, "n4", [])]),
			[inf_pass(h1, "n2", ["n1"]), inf_pass(h1, "n3", ["n1"]), inf_fail(h1, "n5", [], ["n4"]), inf_fail(h1, "n6", [], ["n4"])],
			"case (a) gives one result, the 2 nearest results of case (b) differ: case (b) gives none",
		),
		(infer([iv("x1", "n3")], [pass_at(h1, "n2")]), [], "an interval with a first id that is not in D holds nothing"),
		(infer([iv("n4", "x2")], [pass_at(h1, "n5")]), [], "an interval with a last id that is not in D holds nothing"),
		(infer([], [pass_at(h1, "n1"), pass_at(h1, "n3")]), [inf_pass(h1, "n2", ["n1", "n3"])], "no interval: each release is its own epoch"),
		(infer([iv("x1", "x2")], [pass_at(h1, "n1"), pass_at(h1, "n3")]), [inf_pass(h1, "n2", ["n1", "n3"])], "an interval with ids that are not in D holds nothing"),
		(infer(two, [pass_at(h1, "n1"), pass_at(h2, "n5")]), [inf_pass(h1, "n2", ["n1"]), inf_pass(h1, "n3", ["n1"]), inf_pass(h2, "n4", ["n5"]), inf_pass(h2, "n6", ["n5"])], "2 hashes, each in its own epoch"),
		(infer(two, [build_at(h1, "n2", Pass)]), [], "a build row is no source"),
	]
	bad = rows.keep_if(|(got, want, _)| got != want).map(|(_, _, label)| label)
	dbg bad
	bad == []
}

# R-EP10 R-EP13 R-EP14 R-EP6 R-EP5 R-EP4: the whole function on a made-up sample in the shape of the design (Q11): 6 releases, 3 hashes, faults, a build row.
# The same inputs give the same output: the facts in another order (reversed, rotated) give the same epochs and the same inferred facts. `epochs` is `partition` and `infer` with it.
#
# | Hash | n1 | n2 | n3 | n4 | n5 | n6 | Inferred |
# | --- | --- | --- | --- | --- | --- | --- | --- |
# | h1 | pass | hang | gap | pass | fail | gap | n3 pass from n1 and n4 (the hang is skipped). n6 has no result after it. |
# | h2 | gap | fail A | gap | gap | fail A | crash | n3 and n4 fail A from n2 and n5. n1 has no result before it. |
# | h3 | pass | gap | gap (a build row) | gap | gap | fail | none: a pass and a fail |
expect {
	facts = [
		pass_at(h1, "n1"),
		hang_at(h1, "n2"),
		pass_at(h1, "n4"),
		fail_at(h1, "n5", ["B.roc"]),
		fail_at(h2, "n2", ["A.roc"]),
		fail_at(h2, "n5", ["A.roc"]),
		crash_at(h2, "n6"),
		pass_at(h3, "n1"),
		build_at(h3, "n3", Pass),
		fail_at(h3, "n6", ["C.roc"]),
	]
	want = [inf_pass(h1, "n3", ["n1", "n4"]), inf_fail(h2, "n3", ["A.roc"], ["n2", "n5"]), inf_fail(h2, "n4", ["A.roc"], ["n2", "n5"])]
	single = d6.map(|r| iv(r.id, r.id))
	rotated = facts.drop_first(3).concat(facts.take_first(3))
	rows = [
		(Epochs.epochs(d6, facts).inferred == want, "inferred"),
		(Epochs.epochs(d6, facts).epochs == single, "epochs"),
		(Epochs.epochs(d6, facts.rev()).inferred == want, "facts reversed"),
		(Epochs.epochs(d6, rotated).inferred == want, "facts rotated"),
		(Epochs.epochs(d6, facts.rev()).epochs == single, "epochs, facts reversed"),
		(Epochs.infer({ domain: d6, epochs: Epochs.partition(d6), facts }) == want, "infer with the partition"),
	]
	bad = rows.keep_if(|(ok, _)| !ok).map(|(_, label)| label)
	dbg bad
	bad == []
}
