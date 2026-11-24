import lib.LogKey
import lib.LogProof

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
