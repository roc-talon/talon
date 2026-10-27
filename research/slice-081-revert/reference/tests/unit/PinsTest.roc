import lib.Db
import lib.Facts
import lib.Fail
import lib.Nightlies
import lib.Toolchain

PinsTest :: [].{}

# Slice 030b (R-CV6 wiring): the pure decisions that the compiler list uses to record the first sha256 of each asset and to drop a tag that changed.
# The tags are real ones from `roc-lang/nightlies` (the list of 2026-10-22). The sha256 values and the other data of a row are made up.
# A wrong row prints with `dbg`.

sha_a = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

sha_b = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"

sha_c = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"

host = "linux_x86_64"

t14 = "nightly-2026-10-14-38a3029"

t13 = "nightly-2026-10-13-91fa0c2"

t12 = "nightly-2026-10-12-2664a27"

t10 = "nightly-2026-10-10-abcdef0"

t10b = "nightly-2026-10-10-1234567"

# A made-up asset with the given sha256.
asset_of : Str, Try(Str, [None]) -> Nightlies.Asset
asset_of = |id, sha256| { name: "roc_nightly-linux_x86_64-${id}.tar.gz", url: "http://127.0.0.1:1/dl/${id}", size: 454, sha256 }

# A release with the given asset state.
rel : Str, Try(Nightlies.Asset, [NoAsset, Several(U64)]) -> Nightlies.Release
rel = |id, asset| { id, published_at: 1, asset }

row : Str, Str, Str -> Db.Pinned
row = |tag, target, sha256| { tag, target, sha256, source: GithubDigest }

# R-CV6 R-CV3: the rows that a list gives. One row for each release that has one asset for the host with a sha256: the tag, the target of the host, the sha256, and the source `github-digest` (direct mode).
# A release with no asset, with 2 assets, or with an asset that has no sha256 gives no row (R-CV4 stops the install of such an asset). The order of the list stays. The target is the target of the host.
expect {
	list = [
		rel(t10, Ok(asset_of(t10, Ok(sha_a)))),
		rel(t12, Err(NoAsset)),
		rel(t13, Err(Several(2))),
		rel(t14, Ok(asset_of(t14, Ok(sha_b)))),
		rel("nightly-2026-10-15-38e6c42", Ok(asset_of("nightly-2026-10-15-38e6c42", Err(None)))),
	]
	rows = [
		(Nightlies.pins({ host: LinuxX64, releases: list }) == [row(t10, host, sha_a), row(t14, host, sha_b)], "linux x86_64"),
		(Nightlies.pins({ host: WindowsArm64, releases: list }) == [row(t10, "windows_arm64", sha_a), row(t14, "windows_arm64", sha_b)], "the target is the one of the host"),
		(Nightlies.pins({ host: LinuxX64, releases: [] }) == [], "no release"),
		(Nightlies.pins({ host: LinuxX64, releases: [rel(t12, Err(NoAsset))] }) == [], "no row for a release with no asset"),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}

# R-CV6: the list with no changed tag. A release with the tag of a change is dropped (any number of them). The order of the others stays. A change of a tag that is not in the list does nothing.
expect {
	list = [
		rel(t10, Ok(asset_of(t10, Ok(sha_a)))),
		rel(t12, Err(NoAsset)),
		rel(t13, Ok(asset_of(t13, Ok(sha_a)))),
		rel(t14, Ok(asset_of(t14, Ok(sha_b)))),
	]
	change = |tag| { first: row(tag, host, sha_a), now: row(tag, host, sha_c) }
	ids = |changed| Nightlies.without_changed({ releases: list, changed }).map(|r| r.id)
	rows = [
		(ids([]) == [t10, t12, t13, t14], "no change: the same list"),
		(ids([change(t13)]) == [t10, t12, t14], "one change"),
		(ids([change(t14), change(t10)]) == [t12, t13], "2 changes, the order of the list stays"),
		(ids([change(t12)]) == [t10, t13, t14], "a release with no asset can be dropped too"),
		(ids([change("nightly-2026-10-11-1a2b3c4")]) == [t10, t12, t13, t14], "a tag that is not in the list"),
		(Nightlies.without_changed({ releases: [], changed: [change(t13)] }) == [], "no release"),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}

# R-CV6: the first-seen decision for a whole list. `new`: listed rows with no recorded row of the tag and the target, one row for a repeated tag and target, in the order of the list.
# `changed`: listed rows with another recorded sha256, with the recorded row as `first`. The same sha256 is in neither (also with another source). A recorded row of another target is no row of the asset.
expect {
	listed = [row(t10, host, sha_a), row(t13, host, sha_a), row(t14, host, sha_b)]
	same_a = row(t10, host, sha_a)
	other_source = { ..row(t13, host, sha_a), source: Registry }
	first_b = row(t14, host, sha_c)
	other_target = row(t14, "linux_arm64", sha_c)
	rows = [
		(Facts.first_seen_all({ recorded: [], listed }) == { new: listed, changed: [] }, "nothing recorded"),
		(Facts.first_seen_all({ recorded: listed, listed }) == { new: [], changed: [] }, "all the same"),
		(Facts.first_seen_all({ recorded: [same_a, other_source], listed }) == { new: [row(t14, host, sha_b)], changed: [] }, "2 the same (one with another source), one new"),
		(Facts.first_seen_all({ recorded: [first_b], listed }) == { new: [row(t10, host, sha_a), row(t13, host, sha_a)], changed: [{ first: first_b, now: row(t14, host, sha_b) }] }, "one changed, 2 new"),
		(Facts.first_seen_all({ recorded: [other_target], listed }) == { new: listed, changed: [] }, "a row of another target is no row"),
		(Facts.first_seen_all({ recorded: [], listed: [row(t10, host, sha_a), row(t10, host, sha_a)] }) == { new: [row(t10, host, sha_a)], changed: [] }, "a repeated row is one new row"),
		(Facts.first_seen_all({ recorded: [same_a], listed: [] }) == { new: [], changed: [] }, "no listed row"),
		(
			Facts.first_seen_all({ recorded: [row(t10, host, sha_b), first_b], listed })
				== { new: [row(t13, host, sha_a)], changed: [{ first: row(t10, host, sha_b), now: row(t10, host, sha_a) }, { first: first_b, now: row(t14, host, sha_b) }] },
			"2 changed in the order of the list, one new",
		),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}

# R-CV6 R-SC10 R-CV1: a command names a tag that changed. The tag, the same nightly in the other tag form, and a prefix of exactly one changed tag give the failure of R-CV6 (kind Integrity, exit 16).
# A prefix of 2 changed tags, an empty text, `@latest`, a step, a tag that did not change and a text that is no tag are not named. One leading `@` is dropped, as `Nightlies.pick` does.
expect {
	c14 = { first: row(t14, host, sha_a), now: row(t14, host, sha_b) }
	c10 = { first: { ..row(t10, host, sha_a), source: Registry }, now: row(t10, host, sha_b) }
	c10b = { first: row(t10b, host, sha_a), now: row(t10b, host, sha_c) }
	both = [c14, c10, c10b]
	want = |c| Ok(Facts.changed_fail(c))
	rows = [
		(Toolchain.changed_failed({ text: t14, changed: both }) == want(c14), "the tag"),
		(Toolchain.changed_failed({ text: "@${t14}", changed: both }) == want(c14), "the tag after @"),
		(Toolchain.changed_failed({ text: "nightly-2026-October-14-38a3029", changed: both }) == want(c14), "the other tag form (R-CV1)"),
		(Toolchain.changed_failed({ text: t10, changed: both }) == want(c10), "the first source is in the text"),
		(Toolchain.changed_failed({ text: "nightly-2026-10-14", changed: both }) == want(c14), "a prefix of one changed tag"),
		(Toolchain.changed_failed({ text: "nightly-2026-10-10", changed: both }) == Err(NotNamed), "a prefix of 2 changed tags"),
		(Toolchain.changed_failed({ text: t10b, changed: both }) == want(c10b), "the full tag wins over the prefix of 2"),
		(Toolchain.changed_failed({ text: "", changed: both }) == Err(NotNamed), "empty"),
		(Toolchain.changed_failed({ text: "@", changed: both }) == Err(NotNamed), "only @"),
		(Toolchain.changed_failed({ text: "", changed: [c14] }) == Err(NotNamed), "empty, one change"),
		(Toolchain.changed_failed({ text: "@", changed: [c14] }) == Err(NotNamed), "only @, one change"),
		(Toolchain.changed_failed({ text: "@latest", changed: both }) == Err(NotNamed), "@latest"),
		(Toolchain.changed_failed({ text: "@-1", changed: both }) == Err(NotNamed), "a step"),
		(Toolchain.changed_failed({ text: t13, changed: both }) == Err(NotNamed), "a tag that did not change"),
		(Toolchain.changed_failed({ text: "nightly-2026-10-14-ffffff0", changed: both }) == Err(NotNamed), "the date of a change with another sha"),
		(Toolchain.changed_failed({ text: t14, changed: [] }) == Err(NotNamed), "no change"),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}

# R-CV6 (TW24, proposal): the failure of a named tag has kind Integrity and the text of `Facts.changed_fail`, with no override. The warning for a tag that is dropped (not named) has the same facts: the tag, the target,
# both values and both sources. It ends with "Talon does not offer this compiler.".
expect {
	c = { first: { ..row(t14, host, sha_a), source: Registry }, now: row(t14, host, sha_b) }
	named = match Toolchain.changed_failed({ text: t14, changed: [c] }) {
		Ok(fail) => fail
		Err(NotNamed) => Fail.new(Internal, "not named")
	}
	want = Fail.new(Integrity, "the sha256 of ${t14} for ${host} changed: first seen ${sha_a} (registry), now ${sha_b} (github-digest). Talon does not use this compiler. Select another compiler.")
	text = Toolchain.changed_warning(c)
	want_text = "the sha256 of ${t14} for ${host} changed: first seen ${sha_a} (registry), now ${sha_b} (github-digest). Talon does not offer this compiler."
	dbg named
	dbg text
	named == want and text == want_text
}

# R-CV6 R-C9 (review of slice 030b, Q1): an installed compiler whose tag changed stays in use, so it stays the base of a relative step. `auto_with_base` puts the base back into `auto` at its place in the order of R-NS1
# (also when the base is given in the other tag form). No other changed tag comes back, so a step never lands on a changed tag. It does nothing for no base, for a base that is not a dropped release, and for an unknown id.
expect {
	r10 = rel(t10, Ok(asset_of(t10, Ok(sha_a))))
	r12 = rel(t12, Ok(asset_of(t12, Ok(sha_a))))
	r13 = rel(t13, Ok(asset_of(t13, Ok(sha_a))))
	r14 = rel(t14, Ok(asset_of(t14, Ok(sha_b))))
	kept = [r10, r14]
	auto = [t10, t14]
	back = |dropped, base| Nightlies.auto_with_base({ releases: kept, dropped, auto, base })
	step = |text, base| Nightlies.pick({ text, named: auto, auto: back([r12, r13], base), base })
	rows = [
		(back([r13], Ok(t13)) == [t10, t13, t14], "the base is put back at its place"),
		(back([r13, r12], Ok(t13)) == [t10, t13, t14], "no other changed tag comes back"),
		(back([r12, r13], Ok("nightly-2026-October-13-91fa0c2")) == [t10, t13, t14], "the base in the other tag form"),
		(back([r13], Err(None)) == auto, "no base"),
		(back([r13], Ok(t10)) == auto, "a base that is a candidate"),
		(back([r13], Ok(t12)) == auto, "a base that is not dropped"),
		(back([], Ok(t13)) == auto, "nothing dropped"),
		(step("@-1", Ok(t13)) == Ok(t10), "a step back from the base does not land on the changed tag 2026-10-12"),
		(step("@+1", Ok(t13)) == Ok(t14), "a step forward from the base"),
	]
	bad = rows.keep_if(|(holds, _)| !holds).map(|(_, label)| label)
	dbg bad
	bad == []
}
