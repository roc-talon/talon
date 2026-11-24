import records.Tlog

TlogTest :: [].{}

# W0 tests of packages/records/Tlog.roc (slice 257a, Design Q636). The expected values come from research/slice-257a-vectors/vectors.mjs (node:crypto, the tiles
# from their definition in C2SP tlog-tiles), not from the code under test. The Ed25519 signature is an input: the vectors sign with a throwaway test key.
# The note vectors are also checked against the published example of golang.org/x/mod/sumdb/note (key PeterNeumann).

# --- Test helpers (not under test) ---

hex_digit : U8 -> U8
hex_digit = |n| if (n < 10) 48 + n else 87 + n

to_hex : List(U8) -> Str
to_hex = |bytes| Str.from_utf8(bytes.fold([], |acc, b| acc.append(hex_digit(b // 16)).append(hex_digit(b % 16)))) ?? ""

nibble : U8 -> U8
nibble = |c| if (c >= 97) c - 87 else c - 48

from_hex : Str -> List(U8)
from_hex = |text| text.to_utf8().chunks_of(2).map(
	|p| match p {
		[a, b] => nibble(a) * 16 + nibble(b)
		_ => 0
	},
)

sha_hex : List(U8) -> Str
sha_hex = |bytes| to_hex(Crypto.SHA256.hash(bytes).to_bytes())

# The entry bytes of the test leaves 0 to n - 1.
entries_to : U64 -> List(List(U8))
entries_to = |n| {
	var $out = []
	for i in 0..<n {
		$out = $out.append(Tlog.entry(vec_leaf(i)))
	}
	$out
}

# The new tiles of a grow as (path, SHA-256 hex of the bytes).
tile_digests : List(Tlog.TileBytes) -> List((Str, Str))
tile_digests = |tiles| tiles.map(|t| (Tlog.path(t.tile), sha_hex(t.bytes)))

# The edge of size s, taken from the tiles of a grow from 0 to s.
edge_of : U64 -> List(Tlog.TileBytes)
edge_of = |s| {
	wanted = Tlog.edge(s).map(Tlog.path)
	match Tlog.grow(0, [], entries_to(s)) {
		Ok(g) => g.tiles.keep_if(|t| wanted.contains(Tlog.path(t.tile)))
		Err(_) => []
	}
}

# The edge of size 3, made from the vector bytes (not from the code under test).
edge3 : List(Tlog.TileBytes)
edge3 = [
	{ tile: { level: Entries, index: 0, width: 3 }, bytes: from_hex(vec_tiles3.entries) },
	{ tile: { level: Hashes(0), index: 0, width: 3 }, bytes: from_hex(vec_tiles3.hashes) },
]

# The root of size 257 in base64, as the checkpoint vector has it.
root_b64 : Str
root_b64 = "vXhvEMNOL1+XH1IO//veu+lZi0M5pziQ97JiZTrD48E="

# Signature lines after the body (parse_checkpoint does not check them).
sig_lines : Str
sig_lines = "\n— registry.roc-talon.org/log 74VGPxE3XQJfkEjIYH7SuhfQ8V8YiJ7KVXw5ZS9ls0fcNSoNJrel46tcEVBgTTH1zEJHhke7TSYUkE8WVJQDfILhpQQ=\n"

# --- R-SG2, R-SG3: the entry bytes ---

# R-SG2: `<grp> <version> <hash> <time>\n` of a release leaf.
expect Tlog.entry(vec_leaf(0)) == vec_entry0.to_utf8()

# R-SG3, R-SG2: the same form for a compiler leaf (group `roc-lang/nightlies:<target>`, hash `sha256:<hex>`).
expect Tlog.entry(vec_compiler_leaf) == vec_compiler_entry.to_utf8()

# R-SG2, R-IK6: the D1 idx i is the tlog index i - 1; idx 0 and below is no leaf.
expect [Tlog.tlog_index(1), Tlog.tlog_index(2), Tlog.tlog_index(300)] == [Ok(0), Ok(1), Ok(299)]

expect [Tlog.tlog_index(0), Tlog.tlog_index(-1)] == [Err(NotALeaf), Err(NotALeaf)]

# --- R-SG2, R-SE2: the RFC 6962 hashes ---

# R-SG2: the leaf hash is SHA-256(0x00 ‖ entry); the node hash is SHA-256(0x01 ‖ left ‖ right).
expect {
	h0 = Tlog.leaf_hash(vec_entry0.to_utf8())
	h1 = Tlog.leaf_hash(Tlog.entry(vec_leaf(1)))
	[to_hex(h0), to_hex(Tlog.leaf_hash(vec_compiler_entry.to_utf8())), to_hex(Tlog.node_hash(h0, h1))] == [vec_leaf_hashes.leaf0, vec_leaf_hashes.compiler, vec_leaf_hashes.node01]
}

# R-SE2: the root of the empty tree is SHA-256 of no bytes; the root of sizes 1 to 600 (sizes that are and are not a power of 2) is the RFC 6962 MTH.
expect to_hex(Tlog.root_of([])) == vec_leaf_hashes.empty

expect {
	hashes = entries_to(600).map(Tlog.leaf_hash)
	vec_roots.map(|(n, _)| (n, to_hex(Tlog.root_of(hashes.take_first(n))))) == vec_roots
}

# --- R-SG4: the tile paths of C2SP tlog-tiles ---

# R-SG4: 3-digit groups with leading zeros, `x` before each group but the last, `.p/<W>` only for a partial tile, `entries` for a bundle.
expect vec_paths.map(|(t, _)| (t, Tlog.path(t))) == vec_paths

# --- R-SG4, R-SG7 row 3: the tiles of a growth ---

# R-SG4, R-SG7 row 3: the new full tiles and the new partial tile of each level, entry bundles first. A size 256 tree is a full level 0 tile and a level 1 partial tile of width 1 (the tlog-tiles example).
expect vec_growth.map(|(s, n, _)| (s, n, Tlog.growth(s, n).map(Tlog.path))) == vec_growth

# R-SG7 row 3: no growth gives no tile; a smaller new size gives no tile.
expect [Tlog.growth(7, 3), Tlog.growth(256, 256)] == [[], []]

# R-SG4: large growths (3 levels, a level 3 tile): the count of tiles and the digest of their paths.
expect vec_big_growth.map(
	|(s, n, _, _)| {
		ps = Tlog.growth(s, n).map(Tlog.path)
		(s, n, ps.len(), sha_hex(ps.fold("", |acc, p| "${acc}${p}\n").to_utf8()))
	},
) == vec_big_growth

# R-SG7 row 1: the partial tiles that the step reads for size S.
expect vec_edges.map(|(s, _)| (s, Tlog.edge(s).map(Tlog.path))) == vec_edges

# --- R-SG7 row 3, R-SE2: the bytes of the tiles and the roots ---

# R-SG7 row 3: a growth from S to N with the edge of S gives the tiles of their definition, the root of S and the root of N.
expect vec_grow.map(
	|(s, n, _, _, _)| match Tlog.grow(s, edge_of(s), entries_to(n).drop_first(s)) {
		Ok(g) => (s, n, to_hex(g.old_root), to_hex(g.root), tile_digests(g.tiles))
		Err(_) => (s, n, "error", "", [])
	},
) == vec_grow

# R-SG4: the bytes of the partial tiles of size 3: the 3 leaf hashes; the 3 entries, each after its big-endian uint16 length.
expect Tlog.grow(0, [], entries_to(3)).map_ok(|g| g.tiles.map(|t| (Tlog.path(t.tile), to_hex(t.bytes)))) == Ok([("tile/entries/000.p/3", vec_tiles3.entries), ("tile/0/000.p/3", vec_tiles3.hashes)])

# R-SG7 row 3: an edge from the vector bytes (in any order) gives the same growth from 3 to 7 as the vectors.
expect {
	want = vec_grow.keep_if(|(s, n, _, _, _)| s == 3 and n == 7)
	got = [edge3, edge3.rev()].map(
		|e| match Tlog.grow(3, e, entries_to(7).drop_first(3)) {
			Ok(g) => (3.U64, 7.U64, to_hex(g.old_root), to_hex(g.root), tile_digests(g.tiles))
			Err(_) => (3, 7, "error", "", [])
		},
	)
	got == want.concat(want)
}

# R-SG7 row 3: no new entry: no tile, the root stays.
expect Tlog.grow(3, edge3, []).map_ok(|g| (to_hex(g.old_root), to_hex(g.root), g.tiles.len())) == Ok((vec_roots.keep_if(|(n, _)| n == 3).map(|(_, r)| r).first() ?? "", vec_roots.keep_if(|(n, _)| n == 3).map(|(_, r)| r).first() ?? "", 0))

expect Tlog.grow(0, [], []).map_ok(|g| (to_hex(g.old_root), to_hex(g.root), g.tiles.len())) == Ok((vec_leaf_hashes.empty, vec_leaf_hashes.empty, 0))

# R-SG7 row 3: a missing edge tile, a hash tile with a wrong length, a bundle with a wrong count: BadEdge.
expect {
	more = entries_to(4).drop_first(3)
	hashes_only = edge3.keep_if(|t| t.tile.level != Entries)
	short_hashes = edge3.map(|t| if (t.tile.level == Entries) t else { ..t, bytes: t.bytes.drop_last(1) })
	two_entries = edge3.map(|t| if (t.tile.level == Entries) { ..t, bytes: Tlog.bundle(entries_to(2)) ?? [] } else t)
	[Tlog.grow(3, [], more), Tlog.grow(3, hashes_only, more), Tlog.grow(3, short_hashes, more), Tlog.grow(3, two_entries, more)].map(|r| r.map_ok(|_| {})) == [Err(BadEdge), Err(BadEdge), Err(BadEdge), Err(BadEdge)]
}

# R-SG4: an entry of more than 65,535 bytes does not fit the uint16 length.
expect Tlog.grow(0, [], [List.repeat(97, 65536)]).map_ok(|_| {}) == Err(EntryTooLong)

# --- R-SG4, R-MX7: the entry bundle ---

# R-SG4, R-MX7: each entry after its big-endian uint16 length; 65,535 bytes fit, 65,536 do not.
expect [Tlog.bundle([]), Tlog.bundle([[1, 2, 3], []])] == [Ok([]), Ok([0, 3, 1, 2, 3, 0, 0])]

expect Tlog.bundle([List.repeat(97, 65535)]).map_ok(|b| (b.take_first(3), b.len())) == Ok(([255, 255, 97], 65537))

expect Tlog.bundle([[1], List.repeat(97, 65536)]) == Err(EntryTooLong)

# --- R-SG4, R-SE2: the checkpoint and the signed note ---

# R-SG4: `<origin>\n<size>\n<base64 root>\n`, no extension line.
expect Tlog.checkpoint_body(vec_origin, vec_checkpoint.size, from_hex(vec_checkpoint.root)) == vec_checkpoint.body

expect Tlog.checkpoint_body("example.com/log", 0, from_hex(vec_leaf_hashes.empty)) == "example.com/log\n0\n47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=\n"

# R-SG4: the key id is SHA-256(name ‖ 0x0A ‖ 0x01 ‖ public key)[:4]: the test key, and the Go example key PeterNeumann (c74f20a3).
expect [to_hex(Tlog.key_id(vec_origin, from_hex(vec_key.public))), to_hex(Tlog.key_id("PeterNeumann", from_hex(vec_go.public)))] == [vec_key.key_id, "c74f20a3"]

# R-SG4: the signed note: the text, an empty line, `— <name> <base64(key id ‖ signature)>\n`. The test checkpoint, and the Go example note.
expect Tlog.signed_note(vec_checkpoint.body, vec_origin, from_hex(vec_key.key_id), from_hex(vec_checkpoint.signature)) == vec_checkpoint.note

expect Tlog.signed_note(vec_go.text, "PeterNeumann", from_hex("c74f20a3"), from_hex(vec_go.signature)) == vec_go.note

# R-SG7 row 1: the size and the root of a signed checkpoint of this origin; size 0 is a size.
expect Tlog.parse_checkpoint(vec_origin, vec_checkpoint.note) == Ok({ size: 257, root: from_hex(vec_checkpoint.root) })

expect Tlog.parse_checkpoint(vec_origin, "${vec_origin}\n0\n47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=\n${sig_lines}") == Ok({ size: 0, root: from_hex(vec_leaf_hashes.empty) })

# R-SG7 row 1, R-SG4: not a checkpoint of this log: another origin or a prefix of it; a size with a leading zero, a sign, a space, no digit, over U64;
# a root that is not canonical base64 of 32 bytes; an extension line; no empty line after the body.
expect {
	o = vec_origin
	bad = [
		("registry.roc-talon.org/other", vec_checkpoint.note),
		("registry.roc-talon.org/lo", vec_checkpoint.note),
		(o, "${o}\n0257\n${root_b64}\n${sig_lines}"),
		(o, "${o}\n+257\n${root_b64}\n${sig_lines}"),
		(o, "${o}\n25 7\n${root_b64}\n${sig_lines}"),
		(o, "${o}\n\n${root_b64}\n${sig_lines}"),
		(o, "${o}\n18446744073709551616\n${root_b64}\n${sig_lines}"),
		(o, "${o}\n257\nvXhvEMNOL1+XH1IO//veu+lZi0M5pziQ97JiZTrD48F=\n${sig_lines}"),
		(o, "${o}\n257\nvXhvEMNOL1+XH1IO//veu+lZi0M5pziQ97JiZTrD48E\n${sig_lines}"),
		(o, "${o}\n257\nvXhvEMNOL1+XH1IO//veu+lZi0M5pziQ97JiZTrD4w==\n${sig_lines}"),
		(o, "${o}\n257\nvXhvEMNOL1+XH1IO//veu+lZi0M5pziQ97JiZTrD4*E=\n${sig_lines}"),
		(o, "${o}\n257\n${root_b64}\next\n${sig_lines}"),
		(o, "${o}\n257\n${root_b64}\n"),
		(o, "${o}\r\n257\r\n${root_b64}\r\n\r\n— x y\r\n"),
	]
	bad.map(|(origin, text)| Tlog.parse_checkpoint(origin, text)) == List.repeat(Err(BadCheckpoint), bad.len())
}

# --- R-WH14: the signer key text of LOG_KEY ---

# R-WH14: the name, the key id as written, the 32-byte seed. The Go example key has a `+` in its base64 key data.
expect [Tlog.parse_signer_key(vec_key.signer), Tlog.parse_signer_key(vec_go.signer)] == [Ok({ name: vec_origin, key_id: from_hex(vec_key.key_id), seed: from_hex(vec_key.seed) }), Ok({ name: "PeterNeumann", key_id: from_hex("c74f20a3"), seed: from_hex(vec_go.seed) })]

# R-WH14: not a signer key: another prefix, a missing part, an empty name, a name with a space, a key id of 7 digits or not hex, key data of another type, of 32 bytes, not base64.
expect {
	data = vec_key.signer.split_on("+").drop_first(4).first() ?? ""
	bad = [
		"PUBLIC+KEY+${vec_origin}+${vec_key.key_id}+${data}",
		"PRIVATE+KEY+${vec_origin}+${vec_key.key_id}",
		"PRIVATE+KEY++${vec_key.key_id}+${data}",
		"PRIVATE+KEY+a b+${vec_key.key_id}+${data}",
		"PRIVATE+KEY+${vec_origin}+ef85463+${data}",
		"PRIVATE+KEY+${vec_origin}+zz85463f+${data}",
		"PRIVATE+KEY+${vec_origin}+${vec_key.key_id}+${vec_bad_key_data.alg2}",
		"PRIVATE+KEY+${vec_origin}+${vec_key.key_id}+${vec_bad_key_data.short}",
		"PRIVATE+KEY+${vec_origin}+${vec_key.key_id}+!!!!",
		"",
	]
	bad.map(Tlog.parse_signer_key) == List.repeat(Err(BadKey), bad.len())
}

# R-WH14: the PKCS#8 of the seed for WebCrypto (node:crypto exports the same bytes).
expect to_hex(Tlog.pkcs8(from_hex(vec_key.seed))) == vec_key.pkcs8

# --- Slice 261b: the reader side (DESIGN-CLI 7.6). The expected values come from research/slice-261-vectors/vectors.mjs (node:crypto, the tiles and the
# tile lists from their definition), from the live checkpoint (public data), and from the 257a vectors above. ---

# The tiles of the distinct-leaf tree of size n: every full and partial tile, from a grow from 0 (257a code, checked above against the vectors).
tiles_of : U64 -> List(Tlog.TileBytes)
tiles_of = |n| match Tlog.grow(0, [], entries_to(n)) {
	Ok(g) => g.tiles
	Err(_) => []
}

# The checkpoint of the distinct-leaf tree of size n (the root from vec_roots).
cp_of : U64 -> Tlog.Checkpoint
cp_of = |n| { size: n, root: from_hex(vec_roots.keep_if(|(s, _)| s == n).map(|(_, r)| r).first() ?? "") }

# The first byte of a list changed.
flip : List(U8) -> List(U8)
flip = |bytes| match bytes {
	[b, .. as rest] => [b.bitwise_xor(1)].concat(rest)
	[] => [1]
}

# For each tile of `wanted` in `tiles`: the tiles with that one tile changed (its first byte).
each_flipped : List(Tlog.TileBytes), List(Tlog.Tile) -> List(List(Tlog.TileBytes))
each_flipped = |tiles, wanted| wanted.map(|w| tiles.map(|t| if (t.tile == w) { ..t, bytes: flip(t.bytes) } else t))

# For each tile of `wanted`: the tiles without that one tile.
each_missing : List(Tlog.TileBytes), List(Tlog.Tile) -> List(List(Tlog.TileBytes))
each_missing = |tiles, wanted| wanted.map(|w| tiles.keep_if(|t| t.tile != w))

# 256 to the power l.
pow256 : U8 -> U64
pow256 = |l| {
	var $p = 1.U64
	for _ in 0..<l.to_u64() {
		$p = $p * 256
	}
	$p
}

# The uniform test tree of vec_uniform with the special leaf s (40000 or 16777216): the entry of tlog index i.
uniform_entry : U64, U64 -> List(U8)
uniform_entry = |s, i| if (i == s) vec_uniform.special.to_utf8() else vec_uniform.same.to_utf8()

# The bytes of a tile of the uniform tree: the hash at level L, position p is special.L when p == s // 256^L, else plain.L.
uniform_tile : U64, Tlog.Tile -> Tlog.TileBytes
uniform_tile = |s, t| match t.level {
	Hashes(l) => {
		span = pow256(l)
		specials = if (s == 40000) vec_uniform.special_40000 else vec_uniform.special_16777216
		plain_h = from_hex(vec_uniform.plain.get(l.to_u64()) ?? "")
		special_h = from_hex(specials.get(l.to_u64()) ?? "")
		var $bytes = []
		for j in 0..<t.width {
			$bytes = $bytes.concat(if (t.index * 256 + j == s // span) special_h else plain_h)
		}
		{ tile: t, bytes: $bytes }
	}
	Entries => {
		var $es = []
		for j in 0..<t.width {
			$es = $es.append(uniform_entry(s, t.index * 256 + j))
		}
		{ tile: t, bytes: Tlog.bundle($es) ?? [] }
	}
}

# The checkpoint of the uniform tree with the special leaf s, of size n (the root from vec_uniform_roots).
uniform_cp : U64, U64 -> Tlog.Checkpoint
uniform_cp = |s, n| { size: n, root: from_hex(vec_uniform_roots.keep_if(|(a, b, _)| a == s and b == n).map(|(_, _, r)| r).first() ?? "") }

# Guard of the test helpers (not of the code under test, it passes now): the edge tiles of the uniform tree give the roots of vec_uniform_roots by `grow` (257a code),
# and a full tile hashes to the hash one level up (plain or special).
expect {
	roots = vec_uniform_roots.map(|(s, n, _)| (s, n, Tlog.grow(n, Tlog.edge(n).map(|t| uniform_tile(s, t)), []).map_ok(|g| to_hex(g.old_root)) ?? "error"))
	mth = |s, l, idx| to_hex(Tlog.root_of(uniform_tile(s, { level: Hashes(l), index: idx, width: 256 }).bytes.chunks_of(32)))
	up = [mth(40000, 0, 0), mth(40000, 0, 156), mth(40000, 1, 0), mth(16777216, 2, 1)]
	(roots, up) == (vec_uniform_roots, [vec_uniform.plain.get(1) ?? "", vec_uniform.special_40000.get(1) ?? "", vec_uniform.special_40000.get(2) ?? "", vec_uniform.special_16777216.get(3) ?? ""])
}

# --- R-LV4, R-SG4: the signed note, opened (the signature is checked in cli/lib) ---

# R-LV4, R-SG4: the live checkpoint: the text and its one signature line (the name, the key id e5942107 of the built-in key, the 64-byte signature).
expect Tlog.open_note(vec_live.note) == Ok({ text: vec_live.text, signatures: [{ name: vec_live.name, key_id: from_hex(vec_live.key_id), signature: from_hex(vec_live.signature) }] })

# R-LV4: the 257a note and the Go example note.
expect [Tlog.open_note(vec_checkpoint.note), Tlog.open_note(vec_go.note)] == [Ok({ text: vec_checkpoint.body, signatures: [{ name: vec_origin, key_id: from_hex(vec_key.key_id), signature: from_hex(vec_checkpoint.signature) }] }), Ok({ text: vec_go.text, signatures: [{ name: "PeterNeumann", key_id: from_hex("c74f20a3"), signature: from_hex(vec_go.signature) }] })]

# R-LV4: other signature lines stay, in the order of the note (the caller ignores them); a note with no signature line opens with no signature.
expect {
	go_line = vec_go.note.split_on("\n\n").get(1) ?? ""
	note = "${vec_checkpoint.note}${go_line}"
	sig_257 = { name: vec_origin, key_id: from_hex(vec_key.key_id), signature: from_hex(vec_checkpoint.signature) }
	sig_go = { name: "PeterNeumann", key_id: from_hex("c74f20a3"), signature: from_hex(vec_go.signature) }
	[Tlog.open_note(note), Tlog.open_note("${vec_checkpoint.body}\n")] == [Ok({ text: vec_checkpoint.body, signatures: [sig_257, sig_go] }), Ok({ text: vec_checkpoint.body, signatures: [] })]
}

# R-LV4: not a signed note: no empty line; a line with no U+2014, with no space, with an empty name, a name with `+`, base64 that does not decode, base64 of 4 bytes;
# no newline after the last line; a `\r` or a tab in the note; a line after the empty line that is not a signature line.
expect {
	b = vec_checkpoint.body
	sig = "74VGPxE3XQJfkEjIYH7SuhfQ8V8YiJ7KVXw5ZS9ls0fcNSoNJrel46tcEVBgTTH1zEJHhke7TSYUkE8WVJQDfILhpQQ="
	bad = [
		b,
		"${b}\n- ${vec_origin} ${sig}\n",
		"${b}\n— ${vec_origin}${sig}\n",
		"${b}\n—  ${sig}\n",
		"${b}\n— a+b ${sig}\n",
		"${b}\n— ${vec_origin} ${sig}*\n",
		"${b}\n— ${vec_origin} AAAAAA==\n",
		"${b}\n— ${vec_origin} ${sig}",
		"${vec_origin}\r\n257\n${root_b64}\n\n— ${vec_origin} ${sig}\n",
		"${vec_origin}\t\n257\n${root_b64}\n\n— ${vec_origin} ${sig}\n",
		"${b}\nhello\n",
	]
	bad.map(Tlog.open_note) == List.repeat(Err(BadNote), bad.len())
}

# --- R-LV2, R-SG2: the entry of an index from its bundle ---

# R-LV2: the bundle that holds an index, with its width at the size.
expect vec_entry_tiles.map(|(i, n, _)| (i, n, Tlog.entry_tile(i, n).map_ok(Tlog.path) ?? "error")) == vec_entry_tiles

expect [Tlog.entry_tile(7, 7), Tlog.entry_tile(8, 7), Tlog.entry_tile(0, 0)] == [Err(NotInTree), Err(NotInTree), Err(NotInTree)]

# R-LV2: the entries 0, 1, 2 of the partial bundle of size 3 (the vector bytes).
expect {
	b3 = edge3.keep_if(|t| t.tile.level == Entries).first() ?? { tile: { level: Entries, index: 0, width: 3 }, bytes: [] }
	[0, 1, 2].map(|i| Tlog.entry_at(i, b3)) == [Ok(vec_entry0.to_utf8()), Ok(Tlog.entry(vec_leaf(1))), Ok(Tlog.entry(vec_leaf(2)))]
}

# R-LV2: index 0 and 255 of a full bundle, index 256 of the last partial bundle of size 257.
expect {
	ts = tiles_of(257)
	full = ts.keep_if(|t| t.tile == { level: Entries, index: 0, width: 256 }).first() ?? { tile: { level: Entries, index: 0, width: 256 }, bytes: [] }
	last = ts.keep_if(|t| t.tile == { level: Entries, index: 1, width: 1 }).first() ?? { tile: { level: Entries, index: 1, width: 1 }, bytes: [] }
	[Tlog.entry_at(0, full), Tlog.entry_at(255, full), Tlog.entry_at(256, last)] == [Ok(vec_entry0.to_utf8()), Ok(Tlog.entry(vec_leaf(255))), Ok(Tlog.entry(vec_leaf(256)))]
}

# R-LV2: an index outside the bundle (past its width, another bundle), a hash tile: NotInBundle. Bytes that are not `width` entries (cut, one entry fewer, bytes after the last): BadBundle.
expect {
	b3 = { tile: { level: Entries, index: 0, width: 3 }, bytes: from_hex(vec_tiles3.entries) }
	h3 = { tile: { level: Hashes(0), index: 0, width: 3 }, bytes: from_hex(vec_tiles3.hashes) }
	[
		Tlog.entry_at(3, b3),
		Tlog.entry_at(256, b3),
		Tlog.entry_at(0, h3),
		Tlog.entry_at(0, { ..b3, bytes: b3.bytes.drop_last(1) }),
		Tlog.entry_at(0, { ..b3, bytes: Tlog.bundle(entries_to(2)) ?? [] }),
		Tlog.entry_at(0, { ..b3, bytes: b3.bytes.concat([0, 1, 65]) }),
	]
		== [Err(NotInBundle), Err(NotInBundle), Err(NotInBundle), Err(BadBundle), Err(BadBundle), Err(BadBundle)]
}

# R-LV2, R-SG2, R-SG3: the leaf of entry bytes: entry 1 of the live log, a test release entry, a compiler entry; and back to the same bytes.
expect {
	live1 = "github.com/Karakatiza666/roc-semver/releases/download/{v}/ 0.2.0 BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i 1794044326262\n"
	got = [live1, vec_entry0, vec_compiler_entry].map(|e| Tlog.parse_entry(e.to_utf8()))
	got == [Ok({ grp: "github.com/Karakatiza666/roc-semver/releases/download/{v}/", version: "0.2.0", hash: "BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i", time: 1794044326262 }), Ok(vec_leaf(0)), Ok(vec_compiler_leaf)]
}

# R-LV2: not an entry: 3 or 5 fields, no newline, two newlines, two spaces (an empty field), a space at the start, a time that is not decimal (a letter, a sign, empty), a time over I64, not UTF-8.
expect {
	bad = [
		"a 1.0.0 h\n",
		"a 1.0.0 h 5 6\n",
		"a 1.0.0 h 5",
		"a 1.0.0 h 5\n\n",
		"a  1.0.0 h 5\n",
		" a 1.0.0 h 5\n",
		"a 1.0.0 h 5x\n",
		"a 1.0.0 h -5\n",
		"a 1.0.0 h \n",
		"a 1.0.0 h 9223372036854775808\n",
	].map(Str.to_utf8)
	bad.concat([[97, 32, 0xff, 32, 104, 32, 53, 10]]).map(Tlog.parse_entry) == List.repeat(Err(BadEntry), bad.len() + 1)
}

# --- R-LV3: the inclusion proof from tiles ---

# R-LV3: the hash tiles of a proof: the path up from the level 0 tile to the first partial tile, then the rest of the edge. Sizes 1, 2, 3, 7, 256 (a power of two), 257, 511,
# 65,536, 65,537, 70,000, 16,777,217; the first, a middle and the last index; an index at or past the size gives no tile.
expect vec_proof_tiles.map(|(i, n, _)| (i, n, Tlog.proof_tiles(i, n).map(Tlog.path))) == vec_proof_tiles

# R-LV3: the proof passes at the first, a middle and the last index of the distinct-leaf trees of size 1, 2, 3, 7, 256, 257, 511, with all the tiles of the tree (extra tiles are ignored).
expect {
	cases = [(1, [0]), (2, [0, 1]), (3, [2]), (7, [0, 3, 6]), (256, [0, 128, 255]), (257, [0, 256]), (511, [100, 510])]
	got = cases.join_map(
		|(n, idxs)| {
			ts = tiles_of(n)
			idxs.map(|i| (n, i, Tlog.check_inclusion(i, cp_of(n), Tlog.entry(vec_leaf(i)), ts)))
		},
	)
	got == cases.join_map(|(n, idxs)| idxs.map(|i| (n, i, Ok({}))))
}

# R-LV3: the tiles of proof_tiles are enough (no other tile given).
expect {
	cases = [(7, 3), (256, 255), (257, 0), (257, 256), (511, 100)]
	got = cases.map(
		|(n, i)| {
			want = Tlog.proof_tiles(i, n)
			(n, i, Tlog.check_inclusion(i, cp_of(n), Tlog.entry(vec_leaf(i)), tiles_of(n).keep_if(|t| want.contains(t.tile))))
		},
	)
	got == cases.map(|(n, i)| (n, i, Ok({})))
}

# R-LV3: fails: the entry of another index, the right entry at another index, the root of another size, an index at the size, a tile with one hash fewer.
expect {
	ts = tiles_of(511)
	short = ts.map(|t| if (t.tile == { level: Hashes(0), index: 1, width: 255 }) { ..t, bytes: t.bytes.drop_last(32) } else t)
	[
		Tlog.check_inclusion(100, cp_of(511), Tlog.entry(vec_leaf(101)), ts),
		Tlog.check_inclusion(101, cp_of(511), Tlog.entry(vec_leaf(100)), ts),
		Tlog.check_inclusion(100, { size: 511, root: (cp_of(512)).root }, Tlog.entry(vec_leaf(100)), ts),
		Tlog.check_inclusion(511, cp_of(511), Tlog.entry(vec_leaf(100)), ts),
		Tlog.check_inclusion(100, cp_of(511), Tlog.entry(vec_leaf(100)), short),
	]
		== List.repeat(Err(NotIncluded), 5)
}

# R-LV3: one byte changed in each tile of the proof: NotIncluded; each tile of the proof missing: MissingTile (index 100 of 511: 3 tiles; index 0 of 257: 3 tiles).
expect {
	got = [(511, 100), (257, 0)].join_map(
		|(n, i)| {
			ts = tiles_of(n)
			want = Tlog.proof_tiles(i, n)
			e = Tlog.entry(vec_leaf(i))
			each_flipped(ts, want).map(|f| Tlog.check_inclusion(i, cp_of(n), e, f)).concat(each_missing(ts, want).map(|m| Tlog.check_inclusion(i, cp_of(n), e, m)))
		},
	)
	got == [Err(NotIncluded), Err(NotIncluded), Err(NotIncluded), Err(MissingTile), Err(MissingTile), Err(MissingTile), Err(NotIncluded), Err(NotIncluded), Err(NotIncluded), Err(MissingTile), Err(MissingTile), Err(MissingTile)]
}

# R-LV3: large trees (the uniform tree, 2 and 3 levels of hash tiles): the first, the special and the last index of 65,536, 65,537, 70,000 and 16,777,217.
expect {
	cases = [(40000, 0, 65536), (40000, 40000, 65536), (40000, 65535, 65536), (40000, 0, 65537), (40000, 65536, 65537), (40000, 40000, 70000), (40000, 69999, 70000), (16777216, 0, 16777217), (16777216, 16777216, 16777217)]
	got = cases.map(|(s, i, n)| (i, n, Tlog.check_inclusion(i, uniform_cp(s, n), uniform_entry(s, i), Tlog.proof_tiles(i, n).map(|t| uniform_tile(s, t)))))
	got == cases.map(|(_, i, n)| (i, n, Ok({})))
}

# R-LV3: large tree fails: the plain entry at the special index, the special entry at the next index, the root of another size, each tile of the proof changed.
expect {
	ts = Tlog.proof_tiles(40000, 70000).map(|t| uniform_tile(40000, t))
	sp = vec_uniform.special.to_utf8()
	cp = uniform_cp(40000, 70000)
	firsts = [
		Tlog.check_inclusion(40000, cp, vec_uniform.same.to_utf8(), ts),
		Tlog.check_inclusion(40001, cp, sp, Tlog.proof_tiles(40001, 70000).map(|t| uniform_tile(40000, t))),
		Tlog.check_inclusion(40000, { size: 70000, root: (uniform_cp(40000, 65537)).root }, sp, ts),
	]
	flips = each_flipped(ts, ts.map(|t| t.tile)).map(|f| Tlog.check_inclusion(40000, cp, sp, f))
	firsts.concat(flips) == List.repeat(Err(NotIncluded), 3 + ts.len())
}

# R-LV3, R-LV10 (gap test of the mutant incl-root-first-byte, research/slice-261b-revert): the whole root is compared: a signed root with only its LAST byte changed fails.
expect {
	last_flip = |bytes| bytes.drop_last(1).concat(flip(bytes.take_last(1)))
	ts = tiles_of(257)
	got = [
		Tlog.check_inclusion(0, { ..cp_of(257), root: last_flip((cp_of(257)).root) }, Tlog.entry(vec_leaf(0)), ts) == Err(NotIncluded),
		Tlog.check_consistency({ ..cp_of(7), root: last_flip((cp_of(7)).root) }, cp_of(257), ts) == Err(NotConsistent),
		Tlog.check_consistency(cp_of(7), { ..cp_of(257), root: last_flip((cp_of(257)).root) }, ts) == Err(NotConsistent),
		Tlog.check_consistency(cp_of(5), { ..cp_of(5), root: last_flip((cp_of(5)).root) }, []) == Err(NotConsistent),
	]
	got == [Bool.True, Bool.True, Bool.True, Bool.True]
}

# --- R-LV10: the consistency proof from tiles ---

# R-LV10: the hash tiles of a consistency proof (either order of the sizes; equal sizes and size 0 need no tile).
expect vec_consistency_tiles.map(|(m, n, _)| (m, n, Tlog.consistency_tiles(m, n).map(Tlog.path))) == vec_consistency_tiles

# R-LV10: the smaller tree is the start of the larger one: 1 to 2, 3 to 7, 7 to 256, 256 to 257, 7 to 257, 257 to 7 (the other way), 255 to 511; equal sizes; size 0.
expect {
	cases = [(1, 2), (3, 7), (7, 256), (256, 257), (7, 257), (257, 7), (255, 511), (5, 5), (0, 5)]
	got = cases.map(|(m, n)| (m, n, Tlog.check_consistency(cp_of(m), cp_of(n), tiles_of(if (m > n) m else n))))
	got == cases.map(|(m, n)| (m, n, Ok({})))
}

# R-LV10: large trees, with only the tiles of consistency_tiles: 255 to 70,000 (and back), 65,536 to 70,000, 300 to 65,537, 16,777,216 to 16,777,217.
expect {
	cases = [(40000, 255, 70000), (40000, 70000, 255), (40000, 65536, 70000), (40000, 300, 65537), (16777216, 16777216, 16777217)]
	got = cases.map(|(s, m, n)| (m, n, Tlog.check_consistency(uniform_cp(s, m), uniform_cp(s, n), Tlog.consistency_tiles(m, n).map(|t| uniform_tile(s, t)))))
	got == cases.map(|(_, m, n)| (m, n, Ok({})))
}

# R-LV10: not consistent: a forged old root (one byte changed), the old root of another size, a forged new root, the same size with another root, size 0 with another root.
expect {
	ts = tiles_of(257)
	old = cp_of(7)
	[
		Tlog.check_consistency({ ..old, root: flip(old.root) }, cp_of(257), ts),
		Tlog.check_consistency({ ..old, root: (cp_of(6)).root }, cp_of(257), ts),
		Tlog.check_consistency(old, { size: 257, root: (cp_of(256)).root }, ts),
		Tlog.check_consistency(cp_of(5), { size: 5, root: (cp_of(6)).root }, []),
		Tlog.check_consistency({ size: 0, root: (cp_of(1)).root }, cp_of(5), []),
	]
		== List.repeat(Err(NotConsistent), 5)
}

# R-LV10: one byte changed in each tile of the proof: NotConsistent; each tile missing: MissingTile (255 to 70,000: 5 tiles).
expect {
	ts = Tlog.consistency_tiles(255, 70000).map(|t| uniform_tile(40000, t))
	want = ts.map(|t| t.tile)
	old = uniform_cp(40000, 255)
	new = uniform_cp(40000, 70000)
	flips = each_flipped(ts, want).map(|f| Tlog.check_consistency(old, new, f))
	gone = each_missing(ts, want).map(|m| Tlog.check_consistency(old, new, m))
	(flips, gone) == (List.repeat(Err(NotConsistent), 5), List.repeat(Err(MissingTile), 5))
}

# --- vectors: generated by research/slice-257a-vectors/vectors.mjs, do not edit ---

# The leaf i of the vectors (tlog index i), as research/slice-257a-vectors/vectors.mjs makes it.
vec_leaf : U64 -> Tlog.Leaf
vec_leaf = |i| { grp: "github.com/acme/pkg/releases/download/{v}/", version: "1.0.${i.to_str()}", hash: "6YbXkqTz7pUm2Ff8RcWvJ3s9Hd1LgAeNo4QxBiKt5uP", time: 1763500000000 + i.to_i64_wrap() * 1000 }

vec_entry0 : Str
vec_entry0 = "github.com/acme/pkg/releases/download/{v}/ 1.0.0 6YbXkqTz7pUm2Ff8RcWvJ3s9Hd1LgAeNo4QxBiKt5uP 1763500000000\n"

vec_compiler_leaf : Tlog.Leaf
vec_compiler_leaf = { grp: "roc-lang/nightlies:x86_64-linux", version: "nightly-2026-10-14-38a3029", hash: "sha256:95199d6f9614f0ee7847afae7fccff094b4d5ac48d86dc32f10f60a7308452e1", time: 1760400000000 }

vec_compiler_entry : Str
vec_compiler_entry = "roc-lang/nightlies:x86_64-linux nightly-2026-10-14-38a3029 sha256:95199d6f9614f0ee7847afae7fccff094b4d5ac48d86dc32f10f60a7308452e1 1760400000000\n"

# SHA-256(0x00 || entry) of leaf 0, of the compiler leaf; SHA-256(0x01 || h0 || h1).
vec_leaf_hashes : { leaf0 : Str, compiler : Str, node01 : Str, empty : Str }
vec_leaf_hashes = { leaf0: "a6d8b335e216a8e97d5d498e6f40322de5db07c5767d68d30dcb887008526fb4", compiler: "c53d579096aa03a6d7caa27e64b88c2bd8bd0da99c3afebd452c4376aa1af1c1", node01: "c2b2b413031f8110ddc17cd366380e202b3e82a68e032079a155aaaa6621544a", empty: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" }

# (size, MTH of the first size leaves).
vec_roots : List((U64, Str))
vec_roots = [(0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"), (1, "a6d8b335e216a8e97d5d498e6f40322de5db07c5767d68d30dcb887008526fb4"), (2, "c2b2b413031f8110ddc17cd366380e202b3e82a68e032079a155aaaa6621544a"), (3, "123bc32343d7b9621aed87ed286cf71c042a504912d427272591bd0bdb3d5840"), (4, "ce78b7a2c9d33c5131f0eecca446e1b7ac88c542d77fe4efdf686be564ba744b"), (5, "ac65bfe4b9c03bd86f96af63392f6826bcc0d3e823ddd784f92fd76276a67b5a"), (6, "4fa23ecffeb601a4d40eba95803c6bd5aa0a07259249b3f8093cbf1266d80d02"), (7, "19f84ee93c2757858d772d7fe8a95515806ebbdcc893ef3649818a6dfb7b49ca"), (8, "2cfd113bd89b6432a3d1ff08ee0cfad10686cf49b3718d5c565a0978e50e618e"), (9, "ebe9fa668362133e893544f2984af9f66ce83bc05d77846e792a426f82be167b"), (255, "87947f81655b158550c94273f9fffe384282ae26491f52f792ddc14c7d3c10d3"), (256, "33c9bece12c945c9d212a69f9cf05668d8c465395178ddf2c752edabf1c7e525"), (257, "bd786f10c34e2f5f971f520efffbdebbe9598b4339a73890f7b262653ac3e3c1"), (511, "2d8c3ef713ea52451ef44a2b697dab3b64bda7a7541c4a9fed9e80510d24aecc"), (512, "d008a77fd615d6397dc751a978a49091de3b45927ee61ea8f35f7a71dcfdad77"), (513, "069f38cd267e4004d9c3f9f5e69c76ab9d8a333e60ebd37eeb9abb16898bb1aa"), (600, "3fb2f8dab53773ec251320816429f2e75fad96992a7794607c2127c848f01b7e")]

vec_paths : List((Tlog.Tile, Str))
vec_paths = [({ level: Hashes(0), index: 0, width: 256 }, "tile/0/000"), ({ level: Hashes(0), index: 999, width: 256 }, "tile/0/999"), ({ level: Hashes(0), index: 1000, width: 256 }, "tile/0/x001/000"), ({ level: Hashes(0), index: 1234067, width: 256 }, "tile/0/x001/x234/067"), ({ level: Hashes(0), index: 1000000, width: 256 }, "tile/0/x001/x000/000"), ({ level: Hashes(0), index: 1234, width: 7 }, "tile/0/x001/234.p/7"), ({ level: Hashes(2), index: 5, width: 1 }, "tile/2/005.p/1"), ({ level: Hashes(1), index: 0, width: 255 }, "tile/1/000.p/255"), ({ level: Hashes(63), index: 0, width: 1 }, "tile/63/000.p/1"), ({ level: Entries, index: 0, width: 256 }, "tile/entries/000"), ({ level: Entries, index: 1234, width: 7 }, "tile/entries/x001/234.p/7"), ({ level: Entries, index: 1234067, width: 255 }, "tile/entries/x001/x234/067.p/255")]

# (S, N, the paths of the new tiles in the order of Tlog.growth).
vec_growth : List((U64, U64, List(Str)))
vec_growth = [(0, 0, []), (5, 5, []), (0, 1, ["tile/entries/000.p/1", "tile/0/000.p/1"]), (1, 2, ["tile/entries/000.p/2", "tile/0/000.p/2"]), (2, 3, ["tile/entries/000.p/3", "tile/0/000.p/3"]), (3, 7, ["tile/entries/000.p/7", "tile/0/000.p/7"]), (0, 8, ["tile/entries/000.p/8", "tile/0/000.p/8"]), (0, 256, ["tile/entries/000", "tile/0/000", "tile/1/000.p/1"]), (255, 256, ["tile/entries/000", "tile/0/000", "tile/1/000.p/1"]), (256, 257, ["tile/entries/001.p/1", "tile/0/001.p/1"]), (255, 257, ["tile/entries/000", "tile/entries/001.p/1", "tile/0/000", "tile/0/001.p/1", "tile/1/000.p/1"]), (0, 257, ["tile/entries/000", "tile/entries/001.p/1", "tile/0/000", "tile/0/001.p/1", "tile/1/000.p/1"]), (257, 513, ["tile/entries/001", "tile/entries/002.p/1", "tile/0/001", "tile/0/002.p/1", "tile/1/000.p/2"]), (65535, 65536, ["tile/entries/255", "tile/0/255", "tile/1/000", "tile/2/000.p/1"]), (65536, 65537, ["tile/entries/256.p/1", "tile/0/256.p/1"]), (65535, 65537, ["tile/entries/255", "tile/entries/256.p/1", "tile/0/255", "tile/0/256.p/1", "tile/1/000", "tile/2/000.p/1"])]

# (S, N, count of the new tiles, SHA-256 hex of the paths joined with a newline after each path).
vec_big_growth : List((U64, U64, U64, Str))
vec_big_growth = [(0, 65537, 516, "e5ae2873b00e0a76e0ee19dc464d1dda7c07a85974d68b15055c9f7f3d429aa7"), (1000, 70000, 545, "83c95396e12ef29cf5e7814fffc4cc3319d7daaa0597c971983f0ea73d0bc733"), (16777215, 16777217, 7, "76f97924f806669f43949fbfc6838708158b3f6ebd5bab743bb8e0b2e05a28fe")]

# (S, the paths of the partial tiles of size S, in the order of Tlog.edge).
vec_edges : List((U64, List(Str)))
vec_edges = [(0, []), (1, ["tile/entries/000.p/1", "tile/0/000.p/1"]), (3, ["tile/entries/000.p/3", "tile/0/000.p/3"]), (255, ["tile/entries/000.p/255", "tile/0/000.p/255"]), (256, ["tile/1/000.p/1"]), (257, ["tile/entries/001.p/1", "tile/0/001.p/1", "tile/1/000.p/1"]), (511, ["tile/entries/001.p/255", "tile/0/001.p/255", "tile/1/000.p/1"]), (512, ["tile/1/000.p/2"]), (65535, ["tile/entries/255.p/255", "tile/0/255.p/255", "tile/1/000.p/255"]), (65536, ["tile/2/000.p/1"]), (65537, ["tile/entries/256.p/1", "tile/0/256.p/1", "tile/2/000.p/1"]), (70000, ["tile/entries/273.p/112", "tile/0/273.p/112", "tile/1/001.p/17", "tile/2/000.p/1"]), (16777216, ["tile/3/000.p/1"]), (16777217, ["tile/entries/x065/536.p/1", "tile/0/x065/536.p/1", "tile/3/000.p/1"])]

# (S, N, MTH of S, MTH of N, the new tiles: (path, SHA-256 hex of the tile bytes)).
vec_grow : List((U64, U64, Str, Str, List((Str, Str))))
vec_grow = [(0, 0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", []), (0, 1, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "a6d8b335e216a8e97d5d498e6f40322de5db07c5767d68d30dcb887008526fb4", [("tile/entries/000.p/1", "91fd9743d8283b1e4f8bbf1e4a9a9d7c54b131548e6a34319e995a29a54a7667"), ("tile/0/000.p/1", "23360929ed14fc4c25c9936746308b94ced66cdb0123fa8d970c918f0695ab66")]), (0, 3, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "123bc32343d7b9621aed87ed286cf71c042a504912d427272591bd0bdb3d5840", [("tile/entries/000.p/3", "fb4b58817f9a41bc27d8f0587af4f3ee8799db54e0cfb4d564715e0fcd3bbb8e"), ("tile/0/000.p/3", "55fccb6709af302544028ae67fe4cc41152ef113de429095643dfa0851a51c21")]), (3, 7, "123bc32343d7b9621aed87ed286cf71c042a504912d427272591bd0bdb3d5840", "19f84ee93c2757858d772d7fe8a95515806ebbdcc893ef3649818a6dfb7b49ca", [("tile/entries/000.p/7", "99f563a6ad42f83744827f7a1ddc5921210b9ac71ef3f375fedbe548c6dbe79b"), ("tile/0/000.p/7", "0eb4050e7f3f833e13ad3c99e4cc015b89853400e6ab8b76585f9a534fb1f603")]), (0, 7, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "19f84ee93c2757858d772d7fe8a95515806ebbdcc893ef3649818a6dfb7b49ca", [("tile/entries/000.p/7", "99f563a6ad42f83744827f7a1ddc5921210b9ac71ef3f375fedbe548c6dbe79b"), ("tile/0/000.p/7", "0eb4050e7f3f833e13ad3c99e4cc015b89853400e6ab8b76585f9a534fb1f603")]), (0, 256, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "33c9bece12c945c9d212a69f9cf05668d8c465395178ddf2c752edabf1c7e525", [("tile/entries/000", "c89390902bd87e2ab9472a334c6df4133dd078501631d8c755f12cfad1b4bf31"), ("tile/0/000", "d7140a9322a1377d97250d85e85c242949fc280f0c0149be707a8498d86338be"), ("tile/1/000.p/1", "88589eefcd58adb64a29e160fad381adff92d4576b02f322a5ad48ea2af22362")]), (255, 256, "87947f81655b158550c94273f9fffe384282ae26491f52f792ddc14c7d3c10d3", "33c9bece12c945c9d212a69f9cf05668d8c465395178ddf2c752edabf1c7e525", [("tile/entries/000", "c89390902bd87e2ab9472a334c6df4133dd078501631d8c755f12cfad1b4bf31"), ("tile/0/000", "d7140a9322a1377d97250d85e85c242949fc280f0c0149be707a8498d86338be"), ("tile/1/000.p/1", "88589eefcd58adb64a29e160fad381adff92d4576b02f322a5ad48ea2af22362")]), (256, 257, "33c9bece12c945c9d212a69f9cf05668d8c465395178ddf2c752edabf1c7e525", "bd786f10c34e2f5f971f520efffbdebbe9598b4339a73890f7b262653ac3e3c1", [("tile/entries/001.p/1", "052bd382e4446da6c1149cc25b6c0cc90c236aec054f4dc4a11c53319986adae"), ("tile/0/001.p/1", "342b19185b84a94629acc0e6efb3408b730ca7dd0f89774ed8c61cd265c0a958")]), (0, 257, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "bd786f10c34e2f5f971f520efffbdebbe9598b4339a73890f7b262653ac3e3c1", [("tile/entries/000", "c89390902bd87e2ab9472a334c6df4133dd078501631d8c755f12cfad1b4bf31"), ("tile/entries/001.p/1", "052bd382e4446da6c1149cc25b6c0cc90c236aec054f4dc4a11c53319986adae"), ("tile/0/000", "d7140a9322a1377d97250d85e85c242949fc280f0c0149be707a8498d86338be"), ("tile/0/001.p/1", "342b19185b84a94629acc0e6efb3408b730ca7dd0f89774ed8c61cd265c0a958"), ("tile/1/000.p/1", "88589eefcd58adb64a29e160fad381adff92d4576b02f322a5ad48ea2af22362")]), (7, 257, "19f84ee93c2757858d772d7fe8a95515806ebbdcc893ef3649818a6dfb7b49ca", "bd786f10c34e2f5f971f520efffbdebbe9598b4339a73890f7b262653ac3e3c1", [("tile/entries/000", "c89390902bd87e2ab9472a334c6df4133dd078501631d8c755f12cfad1b4bf31"), ("tile/entries/001.p/1", "052bd382e4446da6c1149cc25b6c0cc90c236aec054f4dc4a11c53319986adae"), ("tile/0/000", "d7140a9322a1377d97250d85e85c242949fc280f0c0149be707a8498d86338be"), ("tile/0/001.p/1", "342b19185b84a94629acc0e6efb3408b730ca7dd0f89774ed8c61cd265c0a958"), ("tile/1/000.p/1", "88589eefcd58adb64a29e160fad381adff92d4576b02f322a5ad48ea2af22362")]), (257, 513, "bd786f10c34e2f5f971f520efffbdebbe9598b4339a73890f7b262653ac3e3c1", "069f38cd267e4004d9c3f9f5e69c76ab9d8a333e60ebd37eeb9abb16898bb1aa", [("tile/entries/001", "a4969ae87275e8c52038570a88a30eafb5b1b9b295b073e67a9bc4a9f9fda644"), ("tile/entries/002.p/1", "2ba9a3ca16c4a7a167a8868cd53888cfc16e513bfd48484f47dc924ba420a4f9"), ("tile/0/001", "7f8311967a1e71d3047f8f1821cf7d19d0a70e7f7b4ed5598ec4b8ff53a82476"), ("tile/0/002.p/1", "d5596e2bc7e5306151e56ea356d61f92ac7180fd78f900fb2274393ea887fd37"), ("tile/1/000.p/2", "52b2363172ddff3634d9c066a0493e63167c4955589639a4372945b50a9a2908")]), (0, 513, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "069f38cd267e4004d9c3f9f5e69c76ab9d8a333e60ebd37eeb9abb16898bb1aa", [("tile/entries/000", "c89390902bd87e2ab9472a334c6df4133dd078501631d8c755f12cfad1b4bf31"), ("tile/entries/001", "a4969ae87275e8c52038570a88a30eafb5b1b9b295b073e67a9bc4a9f9fda644"), ("tile/entries/002.p/1", "2ba9a3ca16c4a7a167a8868cd53888cfc16e513bfd48484f47dc924ba420a4f9"), ("tile/0/000", "d7140a9322a1377d97250d85e85c242949fc280f0c0149be707a8498d86338be"), ("tile/0/001", "7f8311967a1e71d3047f8f1821cf7d19d0a70e7f7b4ed5598ec4b8ff53a82476"), ("tile/0/002.p/1", "d5596e2bc7e5306151e56ea356d61f92ac7180fd78f900fb2274393ea887fd37"), ("tile/1/000.p/2", "52b2363172ddff3634d9c066a0493e63167c4955589639a4372945b50a9a2908")]), (513, 600, "069f38cd267e4004d9c3f9f5e69c76ab9d8a333e60ebd37eeb9abb16898bb1aa", "3fb2f8dab53773ec251320816429f2e75fad96992a7794607c2127c848f01b7e", [("tile/entries/002.p/88", "cdb49a315583261fda6c732b7e7482c42a3e1dfcdecf05443568e0b3c19d819b"), ("tile/0/002.p/88", "571a52a30f16eee6799f4d76d63cf2ddeb911717792d7985a2d8e6555a90e2a6")]), (0, 600, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "3fb2f8dab53773ec251320816429f2e75fad96992a7794607c2127c848f01b7e", [("tile/entries/000", "c89390902bd87e2ab9472a334c6df4133dd078501631d8c755f12cfad1b4bf31"), ("tile/entries/001", "a4969ae87275e8c52038570a88a30eafb5b1b9b295b073e67a9bc4a9f9fda644"), ("tile/entries/002.p/88", "cdb49a315583261fda6c732b7e7482c42a3e1dfcdecf05443568e0b3c19d819b"), ("tile/0/000", "d7140a9322a1377d97250d85e85c242949fc280f0c0149be707a8498d86338be"), ("tile/0/001", "7f8311967a1e71d3047f8f1821cf7d19d0a70e7f7b4ed5598ec4b8ff53a82476"), ("tile/0/002.p/88", "571a52a30f16eee6799f4d76d63cf2ddeb911717792d7985a2d8e6555a90e2a6"), ("tile/1/000.p/2", "52b2363172ddff3634d9c066a0493e63167c4955589639a4372945b50a9a2908")])]

# The bytes of the 2 partial tiles of size 3, in hex: tile/0/000.p/3 and tile/entries/000.p/3.
vec_tiles3 : { hashes : Str, entries : Str }
vec_tiles3 = { hashes: "a6d8b335e216a8e97d5d498e6f40322de5db07c5767d68d30dcb887008526fb4b567b9a08cbd38b15b6350986002d2ddf645f4b40b2a5d8851ab915ffc7d49e26fbcfbc3b105337f04be09bf459d2ee300962a155ebe37056342897b483b6208", entries: "006b6769746875622e636f6d2f61636d652f706b672f72656c65617365732f646f776e6c6f61642f7b767d2f20312e302e3020365962586b71547a3770556d32466638526357764a3373394864314c6741654e6f34517842694b7435755020313736333530303030303030300a006b6769746875622e636f6d2f61636d652f706b672f72656c65617365732f646f776e6c6f61642f7b767d2f20312e302e3120365962586b71547a3770556d32466638526357764a3373394864314c6741654e6f34517842694b7435755020313736333530303030313030300a006b6769746875622e636f6d2f61636d652f706b672f72656c65617365732f646f776e6c6f61642f7b767d2f20312e302e3220365962586b71547a3770556d32466638526357764a3373394864314c6741654e6f34517842694b7435755020313736333530303030323030300a" }

vec_origin : Str
vec_origin = "registry.roc-talon.org/log"

# The throwaway test key: the seed, the public key, the key id, PKCS#8, the signer and verifier key texts.
vec_key : { seed : Str, public : Str, key_id : Str, pkcs8 : Str, signer : Str, verifier : Str }
vec_key = { seed: "b377903bb5ad4e807b8d26605d2d35d200336240135cf5395dd91815a1e38664", public: "33a2ee5ac65b3cc99933a47122e241b759f62ffbbf9d7fa51c95f52e831c83e2", key_id: "ef85463f", pkcs8: "302e020100300506032b657004220420b377903bb5ad4e807b8d26605d2d35d200336240135cf5395dd91815a1e38664", signer: "PRIVATE+KEY+registry.roc-talon.org/log+ef85463f+AbN3kDu1rU6Ae40mYF0tNdIAM2JAE1z1OV3ZGBWh44Zk", verifier: "registry.roc-talon.org/log+ef85463f+ATOi7lrGWzzJmTOkcSLiQbdZ9i/7v51/pRyV9S6DHIPi" }

# Key data that is not 0x01 || 32-byte seed: type byte 0x02 with the test seed; the test seed alone (32 bytes, no type byte).
vec_bad_key_data : { alg2 : Str, short : Str }
vec_bad_key_data = { alg2: "ArN3kDu1rU6Ae40mYF0tNdIAM2JAE1z1OV3ZGBWh44Zk", short: "s3eQO7WtToB7jSZgXS010gAzYkATXPU5XdkYFaHjhmQ=" }

# The checkpoint of size 257 (root of the 257 test leaves), its Ed25519 signature by the test key (hex), and the signed note.
vec_checkpoint : { size : U64, root : Str, body : Str, signature : Str, note : Str }
vec_checkpoint = { size: 257, root: "bd786f10c34e2f5f971f520efffbdebbe9598b4339a73890f7b262653ac3e3c1", body: "registry.roc-talon.org/log\n257\nvXhvEMNOL1+XH1IO//veu+lZi0M5pziQ97JiZTrD48E=\n", signature: "11375d025f9048c8607ed2ba17d0f15f18889eca557c39652f65b347dc352a0d26b7a5e3ab5c1150604d31f5cc42478647bb4d2614904f165494037c82e1a504", note: "registry.roc-talon.org/log\n257\nvXhvEMNOL1+XH1IO//veu+lZi0M5pziQ97JiZTrD48E=\n\n— registry.roc-talon.org/log 74VGPxE3XQJfkEjIYH7SuhfQ8V8YiJ7KVXw5ZS9ls0fcNSoNJrel46tcEVBgTTH1zEJHhke7TSYUkE8WVJQDfILhpQQ=\n" }

# The published example of golang.org/x/mod/sumdb/note: seed, public key, signature (hex), the note text, the signed note, the signer key text.
vec_go : { seed : Str, public : Str, signature : Str, text : Str, note : Str, signer : Str }
vec_go = { seed: "810a1402d5146c8d84f2443330f54080ebf98ee17d9c74f6252fc5d5c7283173", public: "1a5cd907143c384c41e830c5bce12aa8817ec5649aaabf2c31388b35b2d744d6", signature: "f64992e052f541bf49f7dcbc8010c5506d885ba92cbafca40704959227348b8652060dd451580b6a5948d5e02afa9fa9d9e0a2da5165be8a13a472c81c099c03", text: "If you think cryptography is the answer to your problem,\nthen you don't know what your problem is.\n", note: "If you think cryptography is the answer to your problem,\nthen you don't know what your problem is.\n\n— PeterNeumann x08go/ZJkuBS9UG/SffcvIAQxVBtiFupLLr8pAcElZInNIuGUgYN1FFYC2pZSNXgKvqfqdngotpRZb6KE6RyyBwJnAM=\n", signer: "PRIVATE+KEY+PeterNeumann+c74f20a3+AYEKFALVFGyNhPJEMzD1QIDr+Y7hfZx09iUvxdXHKDFz" }

# --- end of vectors ---

# --- vectors of slice 261b: generated by research/slice-261-vectors/vectors.mjs records, do not edit ---

# The live checkpoint of 2026-11-23 (public data): the note, its text, the one signature line (name, key id, signature in hex).
vec_live : { note : Str, text : Str, name : Str, key_id : Str, signature : Str }
vec_live = { note: "registry.roc-talon.org/log\n386\nD9mYoLv7k7hlsHqlLRp2zwA4l9i9kzWGhTfj1rP7In0=\n\n— registry.roc-talon.org/log 5ZQhBzhOnugdzVdM+OUvha15AUBSq7GR8XqqMCVGJylmiMX7nw5m8FP7T4Z18NVPmVzjnNUHT3aFHV30fsWr3RkopA8=\n", text: "registry.roc-talon.org/log\n386\nD9mYoLv7k7hlsHqlLRp2zwA4l9i9kzWGhTfj1rP7In0=\n", name: "registry.roc-talon.org/log", key_id: "e5942107", signature: "384e9ee81dcd574cf8e52f85ad79014052abb191f17aaa30254627296688c5fb9f0e66f053fb4f8675f0d54f995ce39cd5074f76851d5df47ec5abdd1928a40f" }

# (index, size, the paths of Tlog.proof_tiles(index, size)).
vec_proof_tiles : List((U64, U64, List(Str)))
vec_proof_tiles = [(0, 1, ["tile/0/000.p/1"]), (0, 2, ["tile/0/000.p/2"]), (1, 2, ["tile/0/000.p/2"]), (2, 3, ["tile/0/000.p/3"]), (0, 7, ["tile/0/000.p/7"]), (3, 7, ["tile/0/000.p/7"]), (6, 7, ["tile/0/000.p/7"]), (0, 256, ["tile/0/000", "tile/1/000.p/1"]), (128, 256, ["tile/0/000", "tile/1/000.p/1"]), (255, 256, ["tile/0/000", "tile/1/000.p/1"]), (0, 257, ["tile/0/000", "tile/1/000.p/1", "tile/0/001.p/1"]), (256, 257, ["tile/0/001.p/1", "tile/1/000.p/1"]), (100, 511, ["tile/0/000", "tile/1/000.p/1", "tile/0/001.p/255"]), (510, 511, ["tile/0/001.p/255", "tile/1/000.p/1"]), (0, 65536, ["tile/0/000", "tile/1/000", "tile/2/000.p/1"]), (40000, 65536, ["tile/0/156", "tile/1/000", "tile/2/000.p/1"]), (65535, 65536, ["tile/0/255", "tile/1/000", "tile/2/000.p/1"]), (0, 65537, ["tile/0/000", "tile/1/000", "tile/2/000.p/1", "tile/0/256.p/1"]), (65536, 65537, ["tile/0/256.p/1", "tile/2/000.p/1"]), (40000, 70000, ["tile/0/156", "tile/1/000", "tile/2/000.p/1", "tile/0/273.p/112", "tile/1/001.p/17"]), (69999, 70000, ["tile/0/273.p/112", "tile/1/001.p/17", "tile/2/000.p/1"]), (0, 16777217, ["tile/0/000", "tile/1/000", "tile/2/000", "tile/3/000.p/1", "tile/0/x065/536.p/1"]), (16777216, 16777217, ["tile/0/x065/536.p/1", "tile/3/000.p/1"]), (7, 7, []), (8, 7, [])]

# (index, size, the path of Tlog.entry_tile(index, size)).
vec_entry_tiles : List((U64, U64, Str))
vec_entry_tiles = [(0, 1, "tile/entries/000.p/1"), (0, 2, "tile/entries/000.p/2"), (1, 2, "tile/entries/000.p/2"), (2, 3, "tile/entries/000.p/3"), (0, 7, "tile/entries/000.p/7"), (3, 7, "tile/entries/000.p/7"), (6, 7, "tile/entries/000.p/7"), (0, 256, "tile/entries/000"), (128, 256, "tile/entries/000"), (255, 256, "tile/entries/000"), (0, 257, "tile/entries/000"), (256, 257, "tile/entries/001.p/1"), (100, 511, "tile/entries/000"), (510, 511, "tile/entries/001.p/255"), (0, 65536, "tile/entries/000"), (40000, 65536, "tile/entries/156"), (65535, 65536, "tile/entries/255"), (0, 65537, "tile/entries/000"), (65536, 65537, "tile/entries/256.p/1"), (40000, 70000, "tile/entries/156"), (69999, 70000, "tile/entries/273.p/112"), (0, 16777217, "tile/entries/000"), (16777216, 16777217, "tile/entries/x065/536.p/1")]

# (m, n, the paths of Tlog.consistency_tiles(m, n)).
vec_consistency_tiles : List((U64, U64, List(Str)))
vec_consistency_tiles = [(1, 2, ["tile/0/000.p/2"]), (3, 7, ["tile/0/000.p/7"]), (7, 256, ["tile/0/000", "tile/1/000.p/1"]), (256, 257, ["tile/1/000.p/1", "tile/0/001.p/1"]), (7, 257, ["tile/0/000", "tile/1/000.p/1", "tile/0/001.p/1"]), (257, 7, ["tile/0/000", "tile/1/000.p/1", "tile/0/001.p/1"]), (255, 511, ["tile/0/000", "tile/1/000.p/1", "tile/0/001.p/255"]), (255, 70000, ["tile/0/000", "tile/1/000", "tile/2/000.p/1", "tile/0/273.p/112", "tile/1/001.p/17"]), (65536, 70000, ["tile/2/000.p/1", "tile/0/273.p/112", "tile/1/001.p/17"]), (300, 65537, ["tile/0/001", "tile/1/000", "tile/2/000.p/1", "tile/0/256.p/1"]), (16777216, 16777217, ["tile/3/000.p/1", "tile/0/x065/536.p/1"]), (5, 5, []), (0, 5, [])]

# The uniform test tree: every leaf has the entry `same`, but the leaf `special_index` has the entry `special`. plain.L: the hash of a full subtree of
# height 8L with no special leaf (L 0 to 3). special_hashes.L: the hash of the subtree of height 8L that holds the special leaf. Two special indexes: 40000 and 16777216.
vec_uniform : { same : Str, special : Str, plain : List(Str), special_40000 : List(Str), special_16777216 : List(Str) }
vec_uniform = { same: "github.com/acme/same/releases/download/{v}/ 1.0.0 6YbXkqTz7pUm2Ff8RcWvJ3s9Hd1LgAeNo4QxBiKt5uP 1763500000000\n", special: "github.com/acme/special/releases/download/{v}/ 2.0.0 BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i 1763500001000\n", plain: ["e4ed78df435ab877bb683d7fb5f69a01b3daae0b16fcdec67376424f7c5388d0", "73892852b95774573a8b5d551142022d7f3671c460a219db7ef5f11a12aaf78c", "a1c80beaf53d4f4b91d469bcb921e6c20197319d093742d0684aeee5eded9b69", "1fdcbd67ba5432c2e6632af3cac1d1f6656fc798dd383ec59feb2f0a71af74a4"], special_40000: ["e9d3224fdb419e16c4e50b0cd28d2cabe23d998ee260fb80ffd2bf0b8d9c63ee", "53762f8a23a6b53fa47a73149eaeeccac053595a50e6bbb26be2bd6af0a61ec8", "029547428256f753f7f34b8c549017a1e7ad14d26d24c17fd2bb37a7501d831b"], special_16777216: ["e9d3224fdb419e16c4e50b0cd28d2cabe23d998ee260fb80ffd2bf0b8d9c63ee", "ebd9589ca66a6b3d560b38512315b8aada44d63e54bc011d0c4e3cc4c3a7a235", "df514d4f319077e7b389af4cc6e63c64370e56d2cb80e67954bf604d6c51dbd9", "ca8ef0a9ee12c65534a332dc9f7352cb2f25949973541d96bee82e089605a79f"] }

# (special index, size, the RFC 6962 root of the uniform tree of that size).
vec_uniform_roots : List((U64, U64, Str))
vec_uniform_roots = [(40000, 255, "2020d37ae52cbebb3249efdd3fd37545d8dca7f417b805d76b1ae35c0a41166e"), (40000, 300, "b3f16b9dad98e4fdf54ea5cafc6af60e474c2846f9a4d29c15a05ec4702d6990"), (40000, 65536, "029547428256f753f7f34b8c549017a1e7ad14d26d24c17fd2bb37a7501d831b"), (40000, 65537, "92aaf32d87805aa439ac6b276f745127b7570f8c0873f0fe59995dc0e426eb5c"), (40000, 70000, "b5739f5dab763904737da589a38ff43a667550a33ef9506cfd97989692e0d02b"), (16777216, 16777216, "1fdcbd67ba5432c2e6632af3cac1d1f6656fc798dd383ec59feb2f0a71af74a4"), (16777216, 16777217, "b6daa3943c0f0dd45d7d7d11447c6b0c258fca793e7111c3b84e080a2874e20b")]

# --- end of vectors of slice 261b ---
