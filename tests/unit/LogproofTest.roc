import lib.LogKey
import lib.LogProof
import records.Release
import records.Toolchain
import records.Tlog

LogproofTest :: [].{}

# Slice 261b (docs/slices/261-log-inclusion-proofs.md section 13). Pure: the signed checkpoint checked with a key (DESIGN-CLI 7.6 R-LV4, with roc-ed25519),
# and the leaf of a row (R-LV2). The notes are signed by test keys with fixed test seeds (research/slice-261-vectors/vectors.mjs, node:crypto);
# the live checkpoint of 2026-11-23 is public data (research/slice-261-vectors/checkpoint-386.txt, verified by live.mjs with the built-in key).

nibble : U8 -> U8
nibble = |c| if (c >= 97) c - 87 else c - 48

from_hex : Str -> List(U8)
from_hex = |text| text.to_utf8().chunks_of(2).map(
	|p| match p {
		[a, b] => nibble(a) * 16 + nibble(b)
		_ => 0
	},
)

# A verifier key from the hex of the vectors (not from parse_verifier_key, which LogkeyTest checks).
key_of : Str, { verifier : Str, public : Str, key_id : Str } -> LogKey.VerifierKey
key_of = |name, k| { name: name, key_id: from_hex(k.key_id), public_key: from_hex(k.public) }

origin : Str
origin = "registry.roc-talon.org/log"

# The built-in key of tln (R-LV5).
builtin_key : LogKey.VerifierKey
builtin_key = { name: origin, key_id: from_hex("e5942107"), public_key: from_hex("c0a1ac5f5e1a98b6f580c24e70684bc25ddf11154754e8fba451837928ac2432") }

# The live checkpoint of size 386 (checkpoint-386.txt).
live_note : Str
live_note = "registry.roc-talon.org/log\n386\nD9mYoLv7k7hlsHqlLRp2zwA4l9i9kzWGhTfj1rP7In0=\n\n— registry.roc-talon.org/log 5ZQhBzhOnugdzVdM+OUvha15AUBSq7GR8XqqMCVGJylmiMX7nw5m8FP7T4Z18NVPmVzjnNUHT3aFHV30fsWr3RkopA8=\n"

# --- R-LV4: the signed checkpoint ---

# R-LV4: the live checkpoint verifies with the built-in key: size 386 and its root.
expect LogProof.open_checkpoint(builtin_key, live_note) == Ok({ size: 386, root: from_hex("0fd998a0bbfb93b865b07aa52d1a76cf003897d8bd9335868537e3d6b3fb227d") })

# R-LV4: the 257a note verifies with the 257a test key: size 257.
expect {
	key = { name: origin, key_id: from_hex("ef85463f"), public_key: from_hex("33a2ee5ac65b3cc99933a47122e241b759f62ffbbf9d7fa51c95f52e831c83e2") }
	note = "registry.roc-talon.org/log\n257\nvXhvEMNOL1+XH1IO//veu+lZi0M5pziQ97JiZTrD48E=\n\n— registry.roc-talon.org/log 74VGPxE3XQJfkEjIYH7SuhfQ8V8YiJ7KVXw5ZS9ls0fcNSoNJrel46tcEVBgTTH1zEJHhke7TSYUkE8WVJQDfILhpQQ=\n"
	LogProof.open_checkpoint(key, note) == Ok({ size: 257, root: from_hex("bd786f10c34e2f5f971f520efffbdebbe9598b4339a73890f7b262653ac3e3c1") })
}

# R-LV4: signed by A; an extra signature line of another key before or after the line of A is ignored.
expect {
	a = key_of(origin, vec_keys.a)
	got = [vec_notes.good, vec_notes.extra_before, vec_notes.extra_after].map(|n| LogProof.open_checkpoint(a, n))
	got == List.repeat(Ok({ size: 7, root: from_hex(vec_root7) }), 3)
}

# R-LV4: no signature line with the name and the key id of the key: only another key; the name of A with the key id of A2 (another key);
# no signature line; the live note with the test key A; the note of A with the key A2.
expect {
	a = key_of(origin, vec_keys.a)
	a2 = key_of(origin, vec_keys.a2)
	got = [
		LogProof.open_checkpoint(a, vec_notes.only_other),
		LogProof.open_checkpoint(a, vec_notes.other_id),
		LogProof.open_checkpoint(a, vec_notes.no_sig),
		LogProof.open_checkpoint(a, live_note),
		LogProof.open_checkpoint(a2, vec_notes.good),
	]
	got == List.repeat(Err(NoSignature), 5)
}

# R-LV4: a line of the key whose signature does not verify: one bit of the signature changed; the size or the root changed after the signature.
expect {
	a = key_of(origin, vec_keys.a)
	got = [vec_notes.bad_sig, vec_notes.size_changed, vec_notes.root_changed].map(|n| LogProof.open_checkpoint(a, n))
	got == List.repeat(Err(BadSignature), 3)
}

# R-LV4 (gap test of the mutant note-any-line, research/slice-261b-revert): each line with the name and the key id of the key must verify, as Go `note.Open`:
# a good line and a bad line of the same key, in either order, is BadSignature.
expect {
	a = key_of(origin, vec_keys.a)
	good_line = vec_notes.good.split_on("\n\n").get(1) ?? ""
	bad_line = vec_notes.bad_sig.split_on("\n\n").get(1) ?? ""
	body7 = vec_notes.good.split_on("\n\n").first() ?? ""
	got = ["${body7}\n\n${good_line}${bad_line}", "${body7}\n\n${bad_line}${good_line}"].map(|n| LogProof.open_checkpoint(a, n))
	got == [Err(BadSignature), Err(BadSignature)]
}

# R-LV4: a valid signature, but the origin is not the name of the key (key C signs a note of registry.roc-talon.org/log); an extension line (R-SG4: none).
expect {
	c = key_of("example.org/log", vec_keys.c)
	a = key_of(origin, vec_keys.a)
	[LogProof.open_checkpoint(c, vec_notes.wrong_origin), LogProof.open_checkpoint(a, vec_notes.extension)] == [Err(BadCheckpoint), Err(BadCheckpoint)]
}

# R-LV4: not a signed note (no empty line; a `\r`).
expect {
	a = key_of(origin, vec_keys.a)
	body7 = vec_notes.good.split_on("\n\n").first() ?? ""
	[LogProof.open_checkpoint(a, "${body7}\n"), LogProof.open_checkpoint(a, vec_notes.good.replace_first("\n7\n", "\r\n7\n"))] == [Err(BadNote), Err(BadNote)]
}

# --- R-LV2: the leaf of a row ---

semver_grp : Str
semver_grp = "github.com/Karakatiza666/roc-semver/releases/download/{v}/"

semver_hash : Str
semver_hash = "BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i"

# Entry 1 of the live log.
semver_leaf : { grp : Str, version : Str, hash : Str, time : I64 }
semver_leaf = { grp: semver_grp, version: "0.2.0", hash: semver_hash, time: 1794044326262 }

semver_row : { group : Str, version : Str, hash : Str, url : Str }
semver_row = { group: semver_grp, version: "0.2.0", hash: semver_hash, url: "https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst" }

# R-LV2: the row of entry 1 of the live log; a group `v{v}` keeps the `v` in the URL.
expect {
	vgrp = "github.com/acme/roc-json/releases/download/v{v}/"
	vrow = { group: vgrp, version: "1.2.3", hash: semver_hash, url: "https://github.com/acme/roc-json/releases/download/v1.2.3/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst" }
	vleaf = { grp: vgrp, version: "1.2.3", hash: semver_hash, time: 5 }
	[LogProof.check_release(semver_row, semver_leaf), LogProof.check_release(vrow, vleaf)] == [Ok({}), Ok({})]
}

# R-LV2 (T1): the entry has another group, version or hash than the row.
expect {
	got = [
		LogProof.check_release(semver_row, { ..semver_leaf, grp: "github.com/Karakatiza666/roc-semver2/releases/download/{v}/" }),
		LogProof.check_release(semver_row, { ..semver_leaf, version: "0.2.1" }),
		LogProof.check_release(semver_row, { ..semver_leaf, hash: "BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9j" }),
	]
	got == List.repeat(Err(EntryDiffers), 3)
}

# R-LV2 (T2b): the entry is the row, but the row URL is not made from it: http, another host, another version, another hash, no `.tar.zst`, `{v}` not changed.
expect {
	urls = [
		"http://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst",
		"https://evil.example.org/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst",
		"https://github.com/Karakatiza666/roc-semver/releases/download/0.2.1/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst",
		"https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9j.tar.zst",
		"https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i",
		"https://github.com/Karakatiza666/roc-semver/releases/download/{v}/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst",
	]
	urls.map(|u| LogProof.check_release({ ..semver_row, url: u }, semver_leaf)) == List.repeat(Err(UrlDiffers), urls.len())
}

# R-LV2, Registry R-SG3: a compiler row and its leaf (the 257a compiler entry).
compiler_leaf : { grp : Str, version : Str, hash : Str, time : I64 }
compiler_leaf = { grp: "roc-lang/nightlies:x86_64-linux", version: "nightly-2026-10-14-38a3029", hash: "sha256:95199d6f9614f0ee7847afae7fccff094b4d5ac48d86dc32f10f60a7308452e1", time: 1760400000000 }

compiler_row : { target : Str, tag : Str, sha256 : Str }
compiler_row = { target: "x86_64-linux", tag: "nightly-2026-10-14-38a3029", sha256: "95199d6f9614f0ee7847afae7fccff094b4d5ac48d86dc32f10f60a7308452e1" }

expect LogProof.check_compiler(compiler_row, compiler_leaf) == Ok({})

# R-LV2 (T1): another target, tag or sha256; a leaf hash with no `sha256:` prefix.
expect {
	got = [
		LogProof.check_compiler({ ..compiler_row, target: "aarch64-linux" }, compiler_leaf),
		LogProof.check_compiler({ ..compiler_row, tag: "nightly-2026-10-15-38e6c42" }, compiler_leaf),
		LogProof.check_compiler({ ..compiler_row, sha256: "95199d6f9614f0ee7847afae7fccff094b4d5ac48d86dc32f10f60a7308452e2" }, compiler_leaf),
		LogProof.check_compiler(compiler_row, { ..compiler_leaf, hash: compiler_row.sha256 }),
	]
	got == List.repeat(Err(EntryDiffers), 4)
}

# --- vectors: generated by research/slice-261-vectors/vectors.mjs cli, do not edit ---

# Test keys (fixed test seeds): the verifier text, the 32-byte public key and the key id in hex. A and A2 have the name of the built-in key; B and C do not.
vec_keys : { a : { verifier : Str, public : Str, key_id : Str }, a2 : { verifier : Str, public : Str, key_id : Str }, b : { verifier : Str, public : Str, key_id : Str }, c : { verifier : Str, public : Str, key_id : Str } }
vec_keys = { a: { verifier: "registry.roc-talon.org/log+1a078f80+AR/IiLuExwX1injOo1olZopZngPqAXCx+TnIG79R+W5C", public: "1fc888bb84c705f58a78cea35a25668a599e03ea0170b1f939c81bbf51f96e42", key_id: "1a078f80" }, a2: { verifier: "registry.roc-talon.org/log+d08e1294+ARj1Rlo7svX3ka2gaSxV4e1cYIkNstRxH0j+Hpyw6WDU", public: "18f5465a3bb2f5f791ada0692c55e1ed5c60890db2d4711f48fe1e9cb0e960d4", key_id: "d08e1294" }, b: { verifier: "witness.example.org/w1+be8be942+AYgAz2SJHtNNY1oqn4Jt2n9P/Edn0L3y3+sbEbzlDNnj", public: "8800cf64891ed34d635a2a9f826dda7f4ffc4767d0bdf2dfeb1b11bce50cd9e3", key_id: "be8be942" }, c: { verifier: "example.org/log+e9506e69+AWD5DYMxg+npNDlJ+4JyVmWhE9cqFkLSpBt2hQ1nqj8B", public: "60f90d833183e9e9343949fb82725665a113d72a1642d2a41b76850d67aa3f01", key_id: "e9506e69" } }

# Signed notes of the body of size 7 (root 19f84e...): signed by A; with an extra line of B before or after; only B; signed by A2 (the name of A, another key id);
# a signature of A with a changed bit; the size or the root changed after the signature; signed by C (origin is not the name of C); an extension line signed by A; no signature line.
vec_notes : { good : Str, extra_before : Str, extra_after : Str, only_other : Str, other_id : Str, bad_sig : Str, size_changed : Str, root_changed : Str, wrong_origin : Str, extension : Str, no_sig : Str }
vec_notes = { good: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— registry.roc-talon.org/log GgePgJ8opkkTUToa0PIqztu7PIhslvWiGViXiydYIZ/lHKnDuN9SsmS5mEAYz5aYNKyCKAw91K5Femo0g8PaTbNCVQY=\n", extra_before: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— witness.example.org/w1 vovpQoLDldSzR8c2XjFjSwFJm80c63NTa9+QsIUdQxrJKaJb+vuVfEcsuPcR6j9GjpaSKill4A1iTbNb+sh2je0bBQI=\n— registry.roc-talon.org/log GgePgJ8opkkTUToa0PIqztu7PIhslvWiGViXiydYIZ/lHKnDuN9SsmS5mEAYz5aYNKyCKAw91K5Femo0g8PaTbNCVQY=\n", extra_after: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— registry.roc-talon.org/log GgePgJ8opkkTUToa0PIqztu7PIhslvWiGViXiydYIZ/lHKnDuN9SsmS5mEAYz5aYNKyCKAw91K5Femo0g8PaTbNCVQY=\n— witness.example.org/w1 vovpQoLDldSzR8c2XjFjSwFJm80c63NTa9+QsIUdQxrJKaJb+vuVfEcsuPcR6j9GjpaSKill4A1iTbNb+sh2je0bBQI=\n", only_other: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— witness.example.org/w1 vovpQoLDldSzR8c2XjFjSwFJm80c63NTa9+QsIUdQxrJKaJb+vuVfEcsuPcR6j9GjpaSKill4A1iTbNb+sh2je0bBQI=\n", other_id: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— registry.roc-talon.org/log 0I4SlLA8RSxVZb6AivgZmeB+D5TD8lfMlnJXA8mu/tVlRTepgtvCREJ10eaIpjqm/ljKSGszr+07Jqvg9jMG/kqrQgk=\n", bad_sig: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— registry.roc-talon.org/log GgePgJ8opkkTUToa0PIqztu7PIhslvWiGViXiydYIZ/lHKnDuN9SsmS5mEAYz5aYNKyCKAw91K5Femo0g8PaTbNCVQc=\n", size_changed: "registry.roc-talon.org/log\n8\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— registry.roc-talon.org/log GgePgJ8opkkTUToa0PIqztu7PIhslvWiGViXiydYIZ/lHKnDuN9SsmS5mEAYz5aYNKyCKAw91K5Femo0g8PaTbNCVQY=\n", root_changed: "registry.roc-talon.org/log\n7\nGPhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— registry.roc-talon.org/log GgePgJ8opkkTUToa0PIqztu7PIhslvWiGViXiydYIZ/lHKnDuN9SsmS5mEAYz5aYNKyCKAw91K5Femo0g8PaTbNCVQY=\n", wrong_origin: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n— example.org/log 6VBuaaF5fwy4H0XMbE+CR9mlZPP1t73E5uvvDytCYtSUp9rC2mmjtVH7p4Xo5XDq+qjXxGjgydDev+oE67Kb6zGE2Ac=\n", extension: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\nextension line\n\n— registry.roc-talon.org/log GgePgClxMUwz6rNXEUDsNQwAD7bwUoHW2aPsjWsBeS/GmI7fso0cUUwbSbkXQCWOVFf6EggaB2LMc4NZfQiQvWlYRwg=\n", no_sig: "registry.roc-talon.org/log\n7\nGfhO6TwnV4WNdy1/6KlVFYBuu9zIk+82SYGKbft7Sco=\n\n" }

vec_root7 : Str
vec_root7 = "19f84ee93c2757858d772d7fe8a95515806ebbdcc893ef3649818a6dfb7b49ca"

# --- end of vectors ---

# --- Slice 261c (docs/slices/261-log-inclusion-proofs.md section 14): the pure parts of the header check (R-LV1, R-LV3, R-LV7, R-LV9, R-LV10, R-LV11, R-IX8). ---

# A release row of a registry answer (Registry R-AP1, R-AP13) with the fields that the check reads.
row : U64, Str, Str, Str -> Release.Row
row = |log_index, repo, version, hash| {
	log_index,
	hash,
	group: "github.com/${repo}/releases/download/{v}/",
	series: "1",
	version,
	url: "https://github.com/${repo}/releases/download/${version}/${hash}.tar.zst",
	tag: Ok(version),
	roc_version: Err(None),
	repo: Ok(repo),
	published_at: 1790848800000,
	yanked: Bool.False,
	yank_reason: Err(None),
	withdrawn: Err(None),
	provenance: ["ingest"],
}

json_old : Release.Row
json_old = row(44, "acme/json", "2.0.0", "7vqcxRy8v7AeYcCSstUq6Pjx8PuvoVvxdmhXvUYjTa21")

json_new : Release.Row
json_new = row(25, "acme/json", "2.1.0", "4gAvkRHDdEndqaanHcjMKebZJxta5pqHAohzhnFJiNUq")

parser_new : Release.Row
parser_new = row(35, "acme/parser", "1.2.0", "EiSZVhEG7h44iRLspsGTX5NRmJbz4fHktH4XcpRqFyjt")

check_of : Str, Release.Row -> LogProof.Check
check_of = |text, r| { text, log_index: r.log_index, group: r.group, version: r.version, hash: r.hash, url: r.url }

# R-LV1, Design R-SE2: only the new values with a registry row are checked: a value that the header has now is not; a URL with no row (another host) is not;
# a candidate row that is not chosen is not; one URL of two aliases is checked once (the first alias); the order is the order of log_index.
expect {
	other = "https://example.org/acme/other/releases/download/1.0.0/4fuYsvs8fLQptnhMHwz9pYv7M1j3knJFyQSmR4o1aaUu.tar.zst"
	got = LogProof.to_check({
		before: [json_old.url, other],
		after: [
			{ alias: "parser", name: "acme/parser", url: parser_new.url },
			{ alias: "json", name: "acme/json", url: json_new.url },
			{ alias: "json2", name: "acme/json", url: json_new.url },
			{ alias: "old", name: "acme/json", url: json_old.url },
			{ alias: "other", name: "acme/other", url: "https://example.org/acme/other/releases/download/2.0.0/4fuYsvs8fLQptnhMHwz9pYv7M1j3knJFyQSmR4o1aaUu.tar.zst" },
		],
		rows: [json_old, json_new, parser_new, row(36, "acme/parser", "1.1.0", "u2J5ZhgwXSYn55Ac7xti1xFYVGz78yhBDqfZY2ZtFR6")],
	})
	got == [check_of("json: acme/json 2.1.0", json_new), check_of("parser: acme/parser 1.2.0", parser_new)]
}

# R-LV1: no new value gives no check (install with no change, R-SE2 sentence 2).
expect LogProof.to_check({ before: [json_new.url], after: [{ alias: "json", name: "acme/json", url: json_new.url }], rows: [json_new] }) == []

# R-LV9: read again up to 3 more times, after waits of 2, 4 and 8 s; then Behind (T5). A read that covers ends the reads.
expect
	[
		LogProof.after_read({ read: 1, size: 1, need: 2 }),
		LogProof.after_read({ read: 2, size: 1, need: 2 }),
		LogProof.after_read({ read: 3, size: 1, need: 2 }),
		LogProof.after_read({ read: 4, size: 1, need: 2 }),
		LogProof.after_read({ read: 1, size: 2, need: 2 }),
		LogProof.after_read({ read: 3, size: 50, need: 2 }),
		LogProof.after_read({ read: 4, size: 2, need: 2 }),
	]
		== [Again(2000), Again(4000), Again(8000), Behind, Covers, Covers, Covers]

# R-LV3, R-LV7, R-LV10: the tiles of a command, in order, no duplicate (the paths come from research/slice-261-vectors/vectors.mjs: entryTile, proofTiles, consistencyTiles).
expect {
	paths = |need| LogProof.tiles_of(need).map(Tlog.path)
	[
		paths({ kept: Err(None), size: 3, indexes: [2] }),
		paths({ kept: Ok(1), size: 3, indexes: [2] }),
		paths({ kept: Err(None), size: 300, indexes: [2, 290] }),
		paths({ kept: Err(None), size: 36, indexes: [25, 33, 35, 25] }),
		paths({ kept: Ok(5), size: 9, indexes: [7] }),
		paths({ kept: Ok(300), size: 600, indexes: [550] }),
		paths({ kept: Ok(3), size: 3, indexes: [2] }),
	]
		== [
			["tile/entries/000.p/3", "tile/0/000.p/3"],
			["tile/0/000.p/3", "tile/entries/000.p/3"],
			["tile/entries/000", "tile/0/000", "tile/1/000.p/1", "tile/0/001.p/44", "tile/entries/001.p/44"],
			["tile/entries/000.p/36", "tile/0/000.p/36"],
			["tile/0/000.p/9", "tile/entries/000.p/9"],
			["tile/0/001", "tile/1/000.p/2", "tile/0/002.p/88", "tile/entries/002.p/88"],
			["tile/entries/000.p/3", "tile/0/000.p/3"],
		]
}

hash_tile : Tlog.Tile
hash_tile = { level: Hashes(0), index: 0, width: 2 }

bundle_tile : Tlog.Tile
bundle_tile = { level: Entries, index: 0, width: 2 }

hash_bytes : List(U8)
hash_bytes = (0.U8).until(64).collect()

hash_text : Str
hash_text = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f\n202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f\n"

bundle_bytes : List(U8)
bundle_bytes = [0, 8].concat("a b c 1\n".to_utf8()).concat([0, 8]).concat("d e f 2\n".to_utf8())

# R-IX8: the text form of the copies, and back.
expect
	[
		LogProof.copy_text({ tile: hash_tile, bytes: hash_bytes }),
		LogProof.copy_text({ tile: bundle_tile, bytes: bundle_bytes }),
	]
		== [Ok(hash_text), Ok("a b c 1\nd e f 2\n")]

expect
	[LogProof.copy_bytes(hash_tile, hash_text), LogProof.copy_bytes(bundle_tile, "a b c 1\nd e f 2\n")]
		== [Ok(hash_bytes), Ok(bundle_bytes)]

# R-IX8: bytes that are not `width` hashes or entries are not kept; a copy text that is not `width` lines of the form is not used.
expect
	[
		LogProof.copy_text({ tile: hash_tile, bytes: hash_bytes.drop_last(1) }),
		LogProof.copy_text({ tile: bundle_tile, bytes: [0, 8].concat("a b c 1\n".to_utf8()) }),
	]
		== [Err(BadTile), Err(BadTile)]

expect
	[
		LogProof.copy_bytes(hash_tile, hash_text.drop_suffix("\n").concat("0\n")),
		LogProof.copy_bytes(hash_tile, "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f\n"),
		LogProof.copy_bytes(hash_tile, hash_text.replace_each("0a0b", "0A0B")),
		LogProof.copy_bytes(bundle_tile, "a b c 1\n"),
	]
		== [Err(BadCopy), Err(BadCopy), Err(BadCopy), Err(BadCopy)]

# The failure of a check, as `<kind> <code> | <message> | <details>`.
failure : Try(LogProof.Check, [None]), Try(U64, [None]), LogProof.Why -> Str
failure = |release, size, why| {
	f = LogProof.fail({ base: "http://127.0.0.1:9", release, size }, why)
	"${f.kind.name()} | ${f.message} | ${f.details.map_ok(|d| d.render()) ?? "no details"}"
}

known : LogProof.Check
known = check_of("known: acme/known 1.1.0", row(2, "acme/known", "1.1.0", "24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL"))

details : Str, Str, Str, Str -> Str
details = |reason, size, index, release| "{\"log\":\"http://127.0.0.1:9/log\",\"reason\":\"${reason}\",\"size\":${size},\"index\":${index},\"release\":${release}}"

known_url : Str
known_url = "\"https://github.com/acme/known/releases/download/1.1.0/24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL.tar.zst\""

# R-LV2, R-LV11 T1, T2b, R-EC16: an entry that is not the row, a URL that is not the URL of the leaf.
expect
	[
		failure(Ok(known), Ok(3), EntryDiffers("github.com/acme/known/releases/download/{v}/ 1.1.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK")),
		failure(Ok({ ..known, url: "https://github.com/evil/known/releases/download/1.1.0/24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL.tar.zst" }), Ok(3), UrlDiffers),
	]
		== [
			"integrity | known: acme/known 1.1.0: the log of http://127.0.0.1:9 has another entry at log index 2: github.com/acme/known/releases/download/{v}/ 1.1.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK. Talon wrote nothing. | ${details("entry-differs", "3", "2", known_url)}",
			"integrity | known: acme/known 1.1.0: the registry http://127.0.0.1:9 gave the URL https://github.com/evil/known/releases/download/1.1.0/24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL.tar.zst, which is not the URL of its log entry. Talon wrote nothing. | ${details("url-differs", "3", "2", "\"https://github.com/evil/known/releases/download/1.1.0/24rkETgKNBjGJpcTGb8WEQVf7ULptHeJM7c85KqCdLxL.tar.zst\"")}",
		]

# R-LV3, R-LV4, R-LV10, R-LV11 T2, T3, T4: the proof, the signature (the key `<name>+<key id>` and its source), the kept checkpoint.
expect {
	l9 = { name: "127.0.0.1:9/log", key_id: from_hex("56ce7b6e"), public_key: [] }
	kept = "/h/.local/share/talon/log/http_127.0.0.1_9/checkpoint"
	[
		failure(Ok(known), Ok(3), NotIncluded),
		failure(Ok(known), Err(None), BadSignature({ key: l9, source: Env })),
		failure(Ok(known), Err(None), BadSignature({ key: l9, source: Config("/h/.config/talon/config.toml") })),
		failure(Ok(known), Err(None), BadSignature({ key: builtin_key, source: BuiltIn })),
		failure(Ok(known), Ok(3), NotConsistent({ kept: 1, date: "2026-10-14", path: kept })),
	]
		== [
			"integrity | known: acme/known 1.1.0: the inclusion proof of log index 2 does not match the signed checkpoint of http://127.0.0.1:9 (size 3). Talon wrote nothing. | ${details("not-included", "3", "2", known_url)}",
			"integrity | the checkpoint of the log of http://127.0.0.1:9 has no valid signature of 127.0.0.1:9/log+56ce7b6e (TALON_LOG_KEY). Talon wrote nothing. | ${details("bad-signature", "null", "null", "null")}",
			"integrity | the checkpoint of the log of http://127.0.0.1:9 has no valid signature of 127.0.0.1:9/log+56ce7b6e (log-key in /h/.config/talon/config.toml). Talon wrote nothing. | ${details("bad-signature", "null", "null", "null")}",
			"integrity | the checkpoint of the log of http://127.0.0.1:9 has no valid signature of registry.roc-talon.org/log+e5942107 (the built-in key). Talon wrote nothing. | ${details("bad-signature", "null", "null", "null")}",
			"integrity | the log of http://127.0.0.1:9 changed its history: the checkpoint of size 3 does not contain the checkpoint of size 1 that Talon kept on 2026-10-14 (${kept}). Talon wrote nothing. Report this to the registry operator. | ${details("not-consistent", "3", "null", "null")}",
		]
}

# R-LV9, R-LV11 T5, T6, T6b, T7, R-EC15, R-RG9 row 5: behind after 4 reads, no answer, a tile that is missing, --offline with no kept proof.
expect
	[
		failure(Ok(known), Ok(1), Behind),
		failure(Ok(known), Err(None), NoAnswer("status 404")),
		failure(Ok(known), Err(None), NoAnswer("timeout")),
		failure(Ok(known), Ok(3), TileMissing({ tile: "tile/0/000.p/3", cause: "status 404" })),
		failure(Ok(known), Err(None), Offline),
	]
		== [
			"network | known: acme/known 1.1.0 (log index 2) is not in the log of http://127.0.0.1:9 yet: the checkpoint has size 1 after 4 reads. Try again in a few minutes. | ${details("behind", "1", "2", known_url)}",
			"network | the log of http://127.0.0.1:9 does not answer (status 404): Talon cannot check known: acme/known 1.1.0. Try again later, or use --registry direct. | ${details("no-answer", "null", "2", known_url)}",
			"network | the log of http://127.0.0.1:9 does not answer (timeout): Talon cannot check known: acme/known 1.1.0. Try again later, or use --registry direct. | ${details("no-answer", "null", "2", known_url)}",
			"network | the log of http://127.0.0.1:9 has no tile tile/0/000.p/3 for size 3 (status 404). Try again later. | ${details("tile-missing", "3", "null", "null")}",
			"network | known: acme/known 1.1.0 has no kept log proof and --offline is set. Run the command without --offline. | ${details("offline", "null", "2", known_url)}",
		]

# --- Slice 261d (docs/slices/261-log-inclusion-proofs.md section 16): the checks of tools and compilers (R-LV1, R-LV2, R-LV11, R-SE11). ---

# The R-AP1 row of acme/foo 1.1.0 (registry/sc3-tool-install, log index 3).
foo_row : Release.Row
foo_row = row(3, "acme/foo", "1.1.0", "AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY")

foo_url : Str
foo_url = "\"https://github.com/acme/foo/releases/download/1.1.0/AL3LZTP3UWR21xDHSrJudR7Cb5ofsXBNqdwip4kv6fVY.tar.zst\""

# The toolchain row of nightly-2026-10-13-91fa0c2 (registry/cv1-roc-default, log index 20).
nightly_row : Toolchain.Row
nightly_row = {
	tag: "nightly-2026-10-13-91fa0c2",
	target: "linux_x86_64",
	asset_name: "roc_nightly-linux_x86_64-2026-10-13-91fa0c2.tar.gz",
	sha256: "b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78",
	size: 73500000,
	published_at: 1791903600000,
	log_index: 20,
}

nightly_leaf : Tlog.Leaf
nightly_leaf = { grp: "roc-lang/nightlies:linux_x86_64", version: "nightly-2026-10-13-91fa0c2", hash: "sha256:b5d54c39e66671c9731b9f471e585d8262cd4f54963f0c93082d8dcf334d4c78", time: 1791903600000 }

# R-LV11, section 7: `<release>` of a tool is `tool <name> <version>` (the full name), of a compiler `<tag> (<target>)`; the log index is the row value.
expect {
	tool = LogProof.tool_check({ name: "acme/foo", row: foo_row })
	nightly = LogProof.compiler_check(nightly_row)
	[(tool.text, tool.log_index), (nightly.text, nightly.log_index)] == [("tool acme/foo 1.1.0", 3), ("nightly-2026-10-13-91fa0c2 (linux_x86_64)", 20)]
}

# R-LV2: a tool check is the compare of a release (the entry, then the URL of the leaf).
expect {
	tool = LogProof.tool_check({ name: "acme/foo", row: foo_row })
	leaf = { grp: foo_row.group, version: "1.1.0", hash: foo_row.hash, time: 1788264000000 }
	[
		LogProof.check_leaf(tool, leaf),
		LogProof.check_leaf(tool, { ..leaf, hash: "9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK" }),
		LogProof.check_leaf({ ..tool, url: "https://github.com/acme/foo/releases/download/1.1.0/9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK.tar.zst" }, leaf),
	]
		== [Ok({}), Err(EntryDiffers), Err(UrlDiffers)]
}

# R-LV2, Registry R-SG3: a compiler check is the compare of the compiler leaf (target, tag, sha256), with no URL check.
expect {
	nightly = LogProof.compiler_check(nightly_row)
	[
		LogProof.check_leaf(nightly, nightly_leaf),
		LogProof.check_leaf(nightly, { ..nightly_leaf, hash: "sha256:0000000000000000000000000000000000000000000000000000000000000000" }),
		LogProof.check_leaf(nightly, { ..nightly_leaf, grp: "roc-lang/nightlies:macos_apple_silicon" }),
		LogProof.check_leaf(nightly, { ..nightly_leaf, version: "nightly-2026-10-12-2664a27" }),
		LogProof.check_leaf(nightly, { ..nightly_leaf, hash: nightly_row.sha256 }),
	]
		== [Ok({}), Err(EntryDiffers), Err(EntryDiffers), Err(EntryDiffers), Err(EntryDiffers)]
}

# R-LV11, R-LV12, CLI 3 catalog: the texts and `error.details` of a tool (`release` is the URL) and of a compiler (`release` is the tag).
expect {
	tool = LogProof.tool_check({ name: "acme/foo", row: foo_row })
	nightly = LogProof.compiler_check(nightly_row)
	tag = "\"nightly-2026-10-13-91fa0c2\""
	[
		failure(Ok(tool), Ok(4), EntryDiffers("github.com/acme/foo/releases/download/{v}/ 1.1.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK")),
		failure(Ok(tool), Ok(4), NotIncluded),
		failure(Ok(nightly), Ok(30), EntryDiffers("roc-lang/nightlies:linux_x86_64 nightly-2026-10-13-91fa0c2 sha256:0000000000000000000000000000000000000000000000000000000000000000")),
		failure(Ok(nightly), Ok(30), NotIncluded),
		failure(Ok(nightly), Ok(12), Behind),
		failure(Ok(nightly), Err(None), Offline),
	]
		== [
			"integrity | tool acme/foo 1.1.0: the log of http://127.0.0.1:9 has another entry at log index 3: github.com/acme/foo/releases/download/{v}/ 1.1.0 9LFkxQ6m3iAu5J8inRcoFjJRHZVevMogAyiPEhPZERUK. Talon wrote nothing. | ${details("entry-differs", "4", "3", foo_url)}",
			"integrity | tool acme/foo 1.1.0: the inclusion proof of log index 3 does not match the signed checkpoint of http://127.0.0.1:9 (size 4). Talon wrote nothing. | ${details("not-included", "4", "3", foo_url)}",
			"integrity | nightly-2026-10-13-91fa0c2 (linux_x86_64): the log of http://127.0.0.1:9 has another entry at log index 20: roc-lang/nightlies:linux_x86_64 nightly-2026-10-13-91fa0c2 sha256:0000000000000000000000000000000000000000000000000000000000000000. Talon wrote nothing. | ${details("entry-differs", "30", "20", tag)}",
			"integrity | nightly-2026-10-13-91fa0c2 (linux_x86_64): the inclusion proof of log index 20 does not match the signed checkpoint of http://127.0.0.1:9 (size 30). Talon wrote nothing. | ${details("not-included", "30", "20", tag)}",
			"network | nightly-2026-10-13-91fa0c2 (linux_x86_64) (log index 20) is not in the log of http://127.0.0.1:9 yet: the checkpoint has size 12 after 4 reads. Try again in a few minutes. | ${details("behind", "12", "20", tag)}",
			"network | nightly-2026-10-13-91fa0c2 (linux_x86_64) has no kept log proof and --offline is set. Run the command without --offline. | ${details("offline", "null", "20", tag)}",
		]
}
