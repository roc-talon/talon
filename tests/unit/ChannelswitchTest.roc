import lib.ClosureRequest
import lib.Compiler
import lib.Nightlies
import lib.Pin
import lib.Toolchain

ChannelswitchTest :: [].{}

# Slice 239 (docs/slices/239-github-release-shape.md), R-CH9 R-CH16, Design Q614 item 5: where a user-channel build counts as a nightly.
# It counts only where the rule is about the `nightly` switch (R-NS3): `Toolchain.range_allowed`, `Pin.use_gate`. It does not count where the rule is about the `roc:` header pin
# (R-SO10, R-SO11), the consent (R-NS2), or the registry (ClosureRequest): there a user build is local only (R-CH16).
# New name used here: none (the callers keep their names; `Pin.counts_as_nightly` is in ChannelidTest).

asset = Ok({ name: "x.tar.gz", url: "http://127.0.0.1:1/x", size: 1, sha256: Ok("aa") })

built : Str, U64 -> Nightlies.Release
built = |id, t| { id, published_at: t, asset }

# R-CH9 R-NS3: with the switch off, the range pick (`Toolchain.range_allowed`) drops a user-channel build as it drops a nightly. A release stays. With the switch on, the nightly stays.
expect {
	releases = [built("nightly-2026-11-05-ccccccc", 1000), built("reify-2026-11-03-1708298", 2000), built("0.1.0", 3000)]
	pick = |nightly| Toolchain.range_allowed({ releases, req: Any, now: 99999999, min_age: 0, snapshot: Err(None), nightly, exclude: [] }).map(|r| r.id)
	off = pick(Bool.False)
	dbg off
	off == ["0.1.0"] and pick(Bool.True).contains("nightly-2026-11-05-ccccccc")
}

# R-CH9 R-NS3 R-U5 (`tln roc use <id>`, the switch part of `Pin.use_gate`): a user-channel id with the switch off is a stop of kind `NoTuple`, as a nightly. With the switch on, no stop.
expect {
	gate = |id, nightly| Pin.use_gate({ id, req: Err(Unset), req_text: Err(Unset), nightly, source: Default, times: [] })
	n_off = gate("nightly-2026-11-05-ccccccc", Bool.False).is_err()
	r_off = gate("reify-2026-11-03-1708298", Bool.False).is_err()
	r_on = gate("reify-2026-11-03-1708298", Bool.True).is_ok()
	n_off and r_off and r_on
}

# R-SO10 R-SO11 (guard): the kind of a compiler version that roc reports. A user-channel id is not a nightly there: it is `Local`, as `debug-<sha>`. A nightly and a release keep their kind.
expect {
	rows = [
		(Compiler.kind("nightly-2026-10-09-258ab27"), Nightly),
		(Compiler.kind("0.1.0"), Release),
		(Compiler.kind("debug-abc1234"), Local),
		(Compiler.kind("reify-2026-11-03-1708298"), Local),
	]
	bad = rows.keep_if(|(got, want)| got != want)
	dbg bad
	bad == []
}

# R-CH16 (Registry R-AP57, R-AP74): the window of a registry request never holds a user-channel build; the registry has no such row (ClosureRequest keeps `Pin.is_nightly`).
# A domain with a user-channel row: it does not stay, so it is not an end of the window. With only user rows, no compiler stays.
expect {
	domain = |rows| { rows, nightly: Bool.True, req: Err(Unset), now: 99999999, min_age: 0, exclude: [], snapshot: None }
	nrow = { id: "nightly-2026-11-05-ccccccc", published_at: 1000, log_index: 1 }
	urow = { id: "reify-2026-11-08-eeeeeee", published_at: 5000, log_index: 2 }
	mixed = ClosureRequest.window_of(Free(domain([nrow, urow])))
	only = ClosureRequest.window_of(Free(domain([urow])))
	dbg mixed
	mixed == Ok(Ok({ from: Ok(nrow.id), to: Ok(nrow.id) })) and only == Err(NoCompiler)
}
