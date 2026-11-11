import lib.Clock
import lib.Compiler
import lib.Nightlies
import lib.Pin

ChannelrangeTest :: [].{}

# Slice 241 (docs/slices/241-channel-selection.md), R-CH7 R-CH6 R-CH9 R-CH5 R-R4 R-CH16 (Design Q612 items 1 and 3). The ranges of `[toolchain] roc` over the ids of a user channel.
# No new names: these tests call existing functions (`Pin.parse_req`, `Pin.admits`, `Pin.order`, `Compiler.select`, `Compiler.toolchain_of`, `Pin.decide`). The file compiles; the rows that need new behavior fail (red).
# Rows marked "guard" are green before the slice and must stay green.

r1 = "reify-2026-10-30-abc1234"

r2 = "reify-2026-11-03-1708298"

# Same date as r2. Its tag text is before r2.
r3 = "reify-2026-11-03-0000001"

# A later date than r2, same channel.
r4 = "reify-2026-12-01-fedcba9"

# A year later: the year decides before the month.
r5 = "reify-2027-01-02-abcdef0"

other = "other-2026-12-01-abc1234"

f1 = "my-fork-2026-10-30-abc1234"

f2 = "my-fork-2026-11-03-1708298"

short = "my-2026-12-01-abc1234"

n1 = "nightly-2026-10-14-38a3029"

# A nightly that is newer than every reify build above except r4 and r5.
n2 = "nightly-2026-11-05-bbbbbbb"

n3 = "nightly-2027-02-01-ccccccc"

rel = "0.1.3"

t = |text| Clock.parse_utc(text) ?? 0

# R-CH7 R-NS7: the text of `[toolchain] roc`. `=<id>` and `>=<id>` accept the full id of a user build (R-CH5: `<name>-<date>-<sha>`, read from the right). A prefix, a short sha, the month name form
# (Design Q614 item 7), a bare name and a `git-` id are not ids of a build (BadReq).
expect {
	rows = [
		("= user id (R-CH7)", Pin.parse_req("=${r2}"), Ok(Exactly(r2))),
		(">= user id (R-CH7)", Pin.parse_req(">=${r1}"), Ok(AtLeast(r1))),
		("= id of a channel with - in the name", Pin.parse_req("=${f2}"), Ok(Exactly(f2))),
		(">= id of a channel with - in the name", Pin.parse_req(">=${f1}"), Ok(AtLeast(f1))),
		("= a prefix of a user id", Pin.parse_req("=reify-2026-11"), Err(BadReq)),
		("= a bare channel name", Pin.parse_req("=reify"), Err(BadReq)),
		(">= a user id with a short sha", Pin.parse_req(">=reify-2026-11-03-170829"), Err(BadReq)),
		("= a user id in the month name form (Q614 item 7)", Pin.parse_req("=reify-2026-July-31-123c5d7"), Err(BadReq)),
		("= a git id (R-R4)", Pin.parse_req("=git-dd03c09e"), Err(BadReq)),
		("guard: = nightly", Pin.parse_req("=${n1}"), Ok(Exactly(n1))),
		("guard: >= nightly", Pin.parse_req(">=${n1}"), Ok(AtLeast(n1))),
		("guard: = release", Pin.parse_req("=${rel}"), Ok(Exactly(rel))),
		("guard: *", Pin.parse_req("*"), Ok(Any)),
		("guard: semver range", Pin.parse_req("0.1.*"), Ok(Semver("0.1.*"))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH7: `Pin.admits` over user ids.
# - `*`, a semver range and `>=<nightly>` never admit a user build (Design Q612 item 3). `=<nightly>` does not either.
# - `=<user id>` admits that id only. `>=<user id>` admits the builds of that channel at or after the bound (R-NS1 order: date, then published_at, then the tag text), and no nightly, release or other channel.
expect {
	times = [{ id: r2, published_at: t("2026-11-03T10:00:00Z") }, { id: r3, published_at: t("2026-11-03T13:00:00Z") }]
	times_early = [{ id: r2, published_at: t("2026-11-03T10:00:00Z") }, { id: r3, published_at: t("2026-11-03T08:00:00Z") }]
	rows = [
		("* does not admit a user build", Pin.admits({ req: Any, id: r2, times: [] }), Bool.False),
		("* does not admit a user build of a channel with -", Pin.admits({ req: Any, id: f2, times: [] }), Bool.False),
		("a semver range does not admit a user build", Pin.admits({ req: Semver("*"), id: r2, times: [] }), Bool.False),
		(">= nightly does not admit a newer user build", Pin.admits({ req: AtLeast(n1), id: r2, times: [] }), Bool.False),
		(">= nightly does not admit a user build of a later year", Pin.admits({ req: AtLeast(n1), id: r5, times: [] }), Bool.False),
		("= nightly does not admit a user build", Pin.admits({ req: Exactly(n1), id: r2, times: [] }), Bool.False),
		("= user id admits that id", Pin.admits({ req: Exactly(r2), id: r2, times: [] }), Bool.True),
		("= user id does not admit an older build of the channel", Pin.admits({ req: Exactly(r2), id: r1, times: [] }), Bool.False),
		("= user id does not admit a newer build of the channel", Pin.admits({ req: Exactly(r2), id: r4, times: [] }), Bool.False),
		("= user id does not admit another channel", Pin.admits({ req: Exactly(r2), id: other, times: [] }), Bool.False),
		("= user id does not admit a nightly", Pin.admits({ req: Exactly(r2), id: n1, times: [] }), Bool.False),
		("= user id does not admit a release", Pin.admits({ req: Exactly(r2), id: rel, times: [] }), Bool.False),
		("= id of a channel with -", Pin.admits({ req: Exactly(f2), id: f2, times: [] }), Bool.True),
		("= id of channel my-fork does not admit channel my", Pin.admits({ req: Exactly(f2), id: short, times: [] }), Bool.False),
		(">= user id admits the id itself", Pin.admits({ req: AtLeast(r1), id: r1, times: [] }), Bool.True),
		(">= user id admits a later build", Pin.admits({ req: AtLeast(r1), id: r2, times: [] }), Bool.True),
		(">= user id admits a build of a later month", Pin.admits({ req: AtLeast(r2), id: r4, times: [] }), Bool.True),
		(">= user id admits a build of a later year", Pin.admits({ req: AtLeast(r4), id: r5, times: [] }), Bool.True),
		(">= user id does not admit an earlier build", Pin.admits({ req: AtLeast(r2), id: r1, times: [] }), Bool.False),
		(">= user id does not admit an earlier year", Pin.admits({ req: AtLeast(r5), id: r4, times: [] }), Bool.False),
		(">= user id does not admit a newer nightly", Pin.admits({ req: AtLeast(r1), id: n2, times: [] }), Bool.False),
		(">= user id does not admit a nightly of a later year", Pin.admits({ req: AtLeast(r1), id: n3, times: [] }), Bool.False),
		(">= user id does not admit a release", Pin.admits({ req: AtLeast(r1), id: rel, times: [] }), Bool.False),
		(">= user id does not admit a newer build of another channel", Pin.admits({ req: AtLeast(r1), id: other, times: [] }), Bool.False),
		(">= id of channel my-fork does not admit channel my", Pin.admits({ req: AtLeast(f1), id: short, times: [] }), Bool.False),
		(">= id of channel my-fork admits a later build", Pin.admits({ req: AtLeast(f1), id: f2, times: [] }), Bool.True),
		(">= user id, same day, the later published_at is admitted (R-NS1)", Pin.admits({ req: AtLeast(r2), id: r3, times }), Bool.True),
		(">= user id, same day, the earlier published_at is not admitted (R-NS1)", Pin.admits({ req: AtLeast(r2), id: r3, times: times_early }), Bool.False),
		("a range never mixes channels: = id of reify does not admit my-fork (answer 5)", Pin.admits({ req: Exactly(r2), id: f2, times: [] }), Bool.False),
		(">= id of my-fork does not admit a later build of reify (answer 5)", Pin.admits({ req: AtLeast(f1), id: r4, times: [] }), Bool.False),
		(">= id of reify does not admit a later build of my-fork (answer 5)", Pin.admits({ req: AtLeast(r1), id: f2, times: [] }), Bool.False),
		("guard: * admits a nightly", Pin.admits({ req: Any, id: n1, times: [] }), Bool.True),
		("guard: * admits a release", Pin.admits({ req: Any, id: rel, times: [] }), Bool.True),
		("guard: >= nightly admits a newer nightly", Pin.admits({ req: AtLeast(n1), id: n2, times: [] }), Bool.True),
		("guard: >= nightly does not admit a release", Pin.admits({ req: AtLeast(n1), id: rel, times: [] }), Bool.False),
		("guard: = nightly admits itself", Pin.admits({ req: Exactly(n1), id: n1, times: [] }), Bool.True),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH9 R-NS1: each user channel is ordered alone, by the order of the nightlies (date, then published_at, then the tag text). Two builds of one channel only: how a build of channel A compares with
# a build of channel B has no order (answer 5 of the slice file: there is no order across channels; a range never mixes channels, see the rows of the admits test).
expect {
	times = [{ id: r2, published_at: t("2026-11-03T10:00:00Z") }, { id: r3, published_at: t("2026-11-03T13:00:00Z") }]
	rows = [
		("a later date", Pin.order({ a: r2, b: r1, times: [] }), After),
		("an earlier date", Pin.order({ a: r1, b: r2, times: [] }), Before),
		("the same build", Pin.order({ a: r2, b: r2, times: [] }), Same),
		("a later month", Pin.order({ a: r4, b: r2, times: [] }), After),
		("a later year over an earlier month", Pin.order({ a: r5, b: r4, times: [] }), After),
		("same day, no times: the tag text decides", Pin.order({ a: r2, b: r3, times: [] }), After),
		("same day, the later published_at is later", Pin.order({ a: r3, b: r2, times }), After),
		("same day, the earlier published_at is earlier", Pin.order({ a: r2, b: r3, times }), Before),
		("a channel with - in the name", Pin.order({ a: f2, b: f1, times: [] }), After),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH7 R-CH9 R-SO4 R-NS3 R-CH5 (slice 241): rank 4 of `Compiler.select` over the installed ids. A user build is a candidate for `=<user id>` and `>=<user id>` only. The newest in the range wins.
# R-CH9: a user build counts as a nightly for the switch, so with `nightly` false it is no candidate.
expect {
	base = { argument: Err(Unset), env: Err(Unset), req: Err(Unset), nightly: Bool.True, has_toml: Bool.True, version_file: Err(None), default: Err(Unset), path: Err(NoCompiler), installed: [], times: [] }
	shown = |r| match r {
		Ok(sel) => Ok((sel.id, sel.rank, sel.state))
		Err(e) => Err(e)
	}
	all = [n1, n2, r1, r2]
	times = [{ id: r2, published_at: t("2026-11-03T10:00:00Z") }, { id: r3, published_at: t("2026-11-03T13:00:00Z") }]
	rows = [
		("= user id: that build", shown(Compiler.select({ ..base, req: Ok(Exactly(r2)), installed: all })), Ok((r2, Range, Installed))),
		("= user id, not installed: none in range (R-SO13)", shown(Compiler.select({ ..base, req: Ok(Exactly(r2)), installed: [n1, n2, r1] })), Err(NoneInRange)),
		("= user id, only nightlies installed", shown(Compiler.select({ ..base, req: Ok(Exactly(r2)), installed: [n1, n2] })), Err(NoneInRange)),
		(">= user id: the newest build of the channel, not the newer nightly", shown(Compiler.select({ ..base, req: Ok(AtLeast(r1)), installed: all })), Ok((r2, Range, Installed))),
		(">= user id: the newest by published_at on one day", shown(Compiler.select({ ..base, req: Ok(AtLeast(r1)), installed: [r1, r2, r3], times })), Ok((r3, Range, Installed))),
		(">= user id: no build of the channel at or after the bound", shown(Compiler.select({ ..base, req: Ok(AtLeast(r2)), installed: [n1, n2, r1] })), Err(NoneInRange)),
		("= user id wins over the default of rank 6", shown(Compiler.select({ ..base, req: Ok(Exactly(r2)), installed: all, default: Ok(n1) })), Ok((r2, Range, Installed))),
		("the switch is off: a user build is a nightly (R-CH9)", shown(Compiler.select({ ..base, req: Ok(Exactly(r2)), installed: all, nightly: Bool.False })), Err(NoneInRange)),
		("the switch is off, >= user id", shown(Compiler.select({ ..base, req: Ok(AtLeast(r1)), installed: all, nightly: Bool.False })), Err(NoneInRange)),
		("guard: * never takes a user build, though it is newer than the nightlies", shown(Compiler.select({ ..base, req: Ok(Any), installed: [n1, r2] })), Ok((n1, Range, Installed))),
		("guard: * takes the newest nightly", shown(Compiler.select({ ..base, req: Ok(Any), installed: all })), Ok((n2, Range, Installed))),
		("guard: >= nightly never takes a user build", shown(Compiler.select({ ..base, req: Ok(AtLeast(n1)), installed: [n1, r2, r4] })), Ok((n1, Range, Installed))),
		("guard: a semver range never takes a user build", shown(Compiler.select({ ..base, req: Ok(Semver("*")), installed: [rel, r2] })), Ok((rel, Range, Installed))),
		("guard: rank 6, the default is a user build (R-CH5)", shown(Compiler.select({ ..base, default: Ok(r2), installed: all })), Ok((r2, Default, Installed))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH5: the id of a user build is a value of `ROC_TOOLCHAIN` (rank 2). A prefix, a bare name and a month name id are not.
expect {
	env = |text| Compiler.toolchain_of([("ROC_TOOLCHAIN", text)])
	rows = [
		("user id", env(r2), Ok(Ok(r2))),
		("user id, channel with -", env(f2), Ok(Ok(f2))),
		("guard: nightly", env(n1), Ok(Ok(n1))),
		("guard: git build", env("git-0123abcd"), Ok(Ok("git-0123abcd"))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	refused = ["reify-2026-11", "reify", "reify-2026-July-31-123c5d7", "reify-2026-11-03-170829"].keep_if(|text| env(text).is_ok())
	dbg bad
	dbg refused
	bad == [] and refused == []
}

# R-CH6 R-R4: Talon never writes a user id into a header `roc:` pin. A member with no pin gets no write when the held compiler is a user build (the project pins it in `talon.toml` as `=<id>`, R-CH6).
# The header pin of a nightly that is outside `=<user id>` is `outside` (R-RP2: the command stops with exit 10). All rows pass the `Pin.decide` rules of R-NS5, R-RP2 (a guard for the first 3).
expect {
	member = |pin| { file: "main.roc", pin, changes: Bool.True }
	decide = |members, compiler, req| Pin.decide({ members, compiler, compiler_from: Range, toolchain: Err(Unset), role: Lock, req, nightly: Bool.True, no_check: Bool.False })
	shown = |r| match r {
		Ok(d) => Ok((d.held, d.writes, d.outside))
		Err(_) => Err(Refused)
	}
	rows = [
		("no pin, held user build, range =<id>: no write", shown(decide([member(Err(NoPin))], Ok(r2), Ok(Exactly(r2)))), Ok((Ok(r2), [], Err(None)))),
		("no pin, held user build, no range: no write", shown(decide([member(Err(NoPin))], Ok(r2), Err(Unset))), Ok((Ok(r2), [], Err(None)))),
		("no pin, held nightly, no range: the write of a nightly is as before", shown(decide([member(Err(NoPin))], Ok(n1), Err(Unset))), Ok((Ok(n1), [{ file: "main.roc", id: n1 }], Err(None)))),
		("a header pin outside =<user id>: outside", shown(decide([member(Ok(n1))], Ok(r2), Ok(Exactly(r2)))), Ok((Ok(n1), [], Ok(n1)))),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-CH16 R-R4 R-CH9: a user build is a local build for the header pin, the version of roc, the consent and the registry (`Compiler.kind` is `Local`, as for `debug-<sha>`), and a nightly for the switch only.
# The share of probe results needs `Compiler.kind` `Nightly` (ProbeShare), so a probe result of a user build stays local, in `compat.db` under its id. Guards: green before the slice.
expect {
	rows = [
		("kind of a user build", Compiler.kind(r2), Local),
		("kind of a user build, channel with -", Compiler.kind(f2), Local),
		("kind of a nightly", Compiler.kind(n1), Nightly),
		("kind of a release", Compiler.kind(rel), Release),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	switch = [Pin.counts_as_nightly(r2), Pin.counts_as_nightly(f2), Pin.counts_as_nightly(n1), !Pin.counts_as_nightly(rel), !Pin.is_nightly(r2), !Pin.is_nightly(f2)]
	dbg bad
	bad == [] and switch.all(|ok| ok)
}

# R-SL6 R-CH8 R-CH5: a tag of a user channel is not a ref. `@<user id>` is refused (use `<name>@<selector>`), also when the build is installed. The id with no `@` names the build (R-CH5, R-SC10): a guard.
# `@latest` and `@-1` with no name keep their meaning (a guard); the channel of the base is the work of the command (L2, ch08-step).
expect {
	pick = |text, ids| Nightlies.pick({ text, named: ids, auto: ids, base: Err(None) })
	ids = [r1, r2]
	rows = [
		("@<user id> is not a ref", pick("@${r2}", ids).is_err(), Bool.True),
		("@<user id> of a channel with -", pick("@${f2}", [f1, f2]).is_err(), Bool.True),
		("the user id with no @ names the build (guard)", pick(r2, ids) == Ok(r2), Bool.True),
		("a prefix with one match names the build (guard)", pick("reify-2026-11", ids) == Ok(r2), Bool.True),
		("@latest, the last of auto (guard)", pick("@latest", ids) == Ok(r2), Bool.True),
		("@-1 from the base (guard)", Nightlies.pick({ text: "@-1", named: ids, auto: ids, base: Ok(r2) }) == Ok(r1), Bool.True),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
