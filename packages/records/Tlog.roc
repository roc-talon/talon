## The math of the transparency log (Registry R-SG2, R-SG4, R-SE2; Design Q636; slice 257a). Pure: no `Fx`, no clock, no key.
## The Worker writes the tiles and the checkpoint with it (R-SG7, slice 257b), and `tln` checks the proofs with the same code (Design Q636 (14)).
## Formats: RFC 6962 (the Merkle tree hash), C2SP tlog-tiles (tile height 8), C2SP tlog-checkpoint, C2SP signed-note (Ed25519, type 0x01),
## and the signer key text of golang.org/x/mod/sumdb/note. The Ed25519 signature itself is a host call (WebCrypto, slice 257b), so this module takes it as an input.
## A hash is 32 bytes. A key id is 4 bytes. A size and a tlog index start at 0 (R-SG2: the D1 `idx` i is the tlog index i - 1).
Tlog :: [].{

	## A tile of tlog-tiles. `level`: `Hashes(L)` (L from 0 to 63) is a hash tile of level L, `Entries` is an entry bundle (it has the index space of level 0).
	## `index` is N of the path. `width` is the count of hashes or entries, from 1 to 256: 256 is a full tile, less is a partial tile.
	Tile : { level : [Hashes(U8), Entries], index : U64, width : U64 }

	## A log leaf as D1 has it (R-SG2, R-SG3, R-SG8): the columns `grp`, `version`, `hash` (text) and `time` (ms).
	Leaf : { grp : Str, version : Str, hash : Str, time : I64 }

	## A tile and its bytes. A hash tile is the 32-byte hashes in order. An entry bundle is the entries, each with a big-endian uint16 length before it.
	TileBytes : { tile : Tlog.Tile, bytes : List(U8) }

	## The result of `grow`: the root hash of the old size, the root hash of the new size, and the new tiles in the order of `growth`.
	Grown : { old_root : List(U8), root : List(U8), tiles : List(Tlog.TileBytes) }

	## The size and the root hash of a checkpoint.
	Checkpoint : { size : U64, root : List(U8) }

	## The parts of a signer key text `PRIVATE+KEY+<name>+<key id>+<base64(0x01 ‖ seed)>` (R-WH14 `LOG_KEY`): the key name, the 4-byte key id as written, the 32-byte Ed25519 seed.
	SignerKey : { name : Str, key_id : List(U8), seed : List(U8) }

	## R-SG2: the entry bytes of a leaf: `<grp> <version> <hash> <time>\n`, UTF-8, single spaces, `time` in decimal.
	entry : Tlog.Leaf -> List(U8)
	entry = |leaf| "${leaf.grp} ${leaf.version} ${leaf.hash} ${leaf.time.to_str()}\n".to_utf8()

	## R-SG2: the tlog index of the D1 `idx`: `idx - 1`. An `idx` below 1 is `Err(NotALeaf)`.
	tlog_index : I64 -> Try(U64, [NotALeaf])
	tlog_index = |idx| if (idx < 1) Err(NotALeaf) else Ok(idx.to_u64_wrap() - 1)

	## RFC 6962: SHA-256(0x00 ‖ entry bytes).
	leaf_hash : List(U8) -> List(U8)
	leaf_hash = |entry_bytes| sha([0].concat(entry_bytes))

	## RFC 6962: SHA-256(0x01 ‖ left ‖ right).
	node_hash : List(U8), List(U8) -> List(U8)
	node_hash = |left, right| sha([1].concat(left).concat(right))

	## RFC 6962 MTH of the leaf hashes in order. No leaf: SHA-256 of no bytes.
	root_of : List(List(U8)) -> List(U8)
	root_of = |leaf_hashes| {
		n = leaf_hashes.len()
		if n == 0 {
			sha([])
		} else if n == 1 {
			leaf_hashes.first() ?? sha([])
		} else {
			k = split_point(n)
			node_hash(root_of(leaf_hashes.take_first(k)), root_of(leaf_hashes.drop_first(k)))
		}
	}

	## tlog-tiles: `tile/<L>/<N>[.p/<W>]` or `tile/entries/<N>[.p/<W>]`, with no prefix and no leading `/`. N is in 3-digit groups, each with leading zeros,
	## and each group but the last has an `x` before it (1234067 is `x001/x234/067`). `.p/<W>` only when the width is less than 256.
	path : Tlog.Tile -> Str
	path = |tile| {
		level_text = match tile.level {
			Hashes(l) => l.to_str()
			Entries => "entries"
		}
		partial = if (tile.width < 256) ".p/${tile.width.to_str()}" else ""
		"tile/${level_text}/${index_text(tile.index)}${partial}"
	}

	## The tiles that a tree of size `new` has and a tree of size `old` does not have (the full tiles that the growth fills, and the partial tile of `new` at each level where it changed).
	## Order: the entry bundles, then level 0, level 1, and on; in index order in each. `old >= new` gives `[]`.
	growth : U64, U64 -> List(Tlog.Tile)
	growth = |old, new| {
		if new <= old {
			[]
		} else {
			var $out = tiles_between(Entries, old, new)
			var $oc = old
			var $nc = new
			var $l = 0.U8
			while $nc > 0 {
				if $nc > $oc {
					$out = $out.concat(tiles_between(Hashes($l), $oc, $nc))
				}
				$oc = $oc // 256
				$nc = $nc // 256
				$l = $l + 1
			}
			$out
		}
	}

	## The partial tiles of a tree of size `size` (the entry bundle and each hash level that has one), in the order of `growth`. The step reads them before `grow` (R-SG7 row 1).
	edge : U64 -> List(Tlog.Tile)
	edge = |size| {
		var $out = []
		if size % 256 > 0 {
			$out = $out.append({ level: Entries, index: size // 256, width: size % 256 })
		}
		var $c = size
		var $l = 0.U8
		while $c > 0 {
			if $c % 256 > 0 {
				$out = $out.append({ level: Hashes($l), index: $c // 256, width: $c % 256 })
			}
			$c = $c // 256
			$l = $l + 1
		}
		$out
	}

	## The growth of the tree from size `old` to size `old + entries.len()`. `edge` holds the tiles of `edge(old)` with their bytes, in any order (other tiles are ignored).
	## `entries` are the entry bytes of the new leaves in tlog index order, from index `old`.
	## A tile of `edge(old)` that is missing, or whose bytes do not have its width (32 bytes for each hash; `width` entries in a bundle), is `Err(BadEdge)`.
	## An entry longer than 65,535 bytes is `Err(EntryTooLong)`.
	grow : U64, List(Tlog.TileBytes), List(List(U8)) -> Try(Tlog.Grown, [BadEdge, EntryTooLong])
	grow = |old, edge_tiles, entries| {
		if !entries.all(|e| e.len() <= 65535) {
			Err(EntryTooLong)
		} else {
			old_entries = edge_entries(old, edge_tiles)?
			old_tails = edge_tails(old, edge_tiles)?
			new = old + entries.len()
			leaf_hashes = entries.map(leaf_hash)
			var $levels = []
			var $oc = old
			var $nc = new
			var $l = 0.U64
			var $prev = []
			var $prev_base = 0.U64
			while $nc > 0 {
				base = ($oc // 256) * 256
				tail = old_tails.get($l) ?? []
				var $fresh = []
				if $l == 0 {
					$fresh = leaf_hashes
				} else {
					for j in $oc..<$nc {
						$fresh = $fresh.append(root_of($prev.sublist({ start: j * 256 - $prev_base, len: 256 })))
					}
				}
				have = tail.concat($fresh)
				$levels = $levels.append({ base: base, count: $nc, hashes: have })
				$prev = have
				$prev_base = base
				$oc = $oc // 256
				$nc = $nc // 256
				$l = $l + 1
			}
			levels = $levels
			all_entries = old_entries.concat(entries)
			base_e = (old // 256) * 256
			tiles = growth(old, new).map(
				|t| match t.level {
					Entries => { tile: t, bytes: bundle(all_entries.sublist({ start: t.index * 256 - base_e, len: t.width })) ?? [] }
					Hashes(l) => match levels.get(l.to_u64()) {
						Ok(lv) => { tile: t, bytes: lv.hashes.sublist({ start: t.index * 256 - lv.base, len: t.width }).join() }
						Err(_) => { tile: t, bytes: [] }
					}
				},
			)
			new_tails = levels.map(|lv| lv.hashes.take_last(lv.count % 256))
			Ok({ old_root: peaks_root(old_tails), root: peaks_root(new_tails), tiles: tiles })
		}
	}

	## tlog-tiles: the bytes of an entry bundle: each entry with a big-endian uint16 length before it. An entry longer than 65,535 bytes is `Err(EntryTooLong)`.
	bundle : List(List(U8)) -> Try(List(U8), [EntryTooLong])
	bundle = |entries| {
		if entries.all(|e| e.len() <= 65535) {
			Ok(entries.fold([], |acc, e| acc.append((e.len() // 256).to_u8_wrap()).append((e.len() % 256).to_u8_wrap()).concat(e)))
		} else {
			Err(EntryTooLong)
		}
	}

	## tlog-checkpoint: `<origin>\n<size>\n<base64 root>\n`: the size in decimal, the root in standard base64 with `=` padding. No extension line (R-SG4).
	checkpoint_body : Str, U64, List(U8) -> Str
	checkpoint_body = |origin, size, root| "${origin}\n${size.to_str()}\n${b64_encode(root)}\n"

	## signed-note: the key id of an Ed25519 key: the first 4 bytes of SHA-256(key name ‖ 0x0A ‖ 0x01 ‖ 32-byte public key).
	key_id : Str, List(U8) -> List(U8)
	key_id = |name, public_key| sha(name.to_utf8().concat([10, 1]).concat(public_key)).take_first(4)

	## signed-note: the note text (it ends in a newline), an empty line, and the line `— <key name> <base64(key id ‖ signature)>\n` (U+2014, a space).
	## Arguments: the note text, the key name, the 4-byte key id, the 64-byte Ed25519 signature of the note text.
	signed_note : Str, Str, List(U8), List(U8) -> Str
	signed_note = |text, name, id, signature| "${text}\n— ${name} ${b64_encode(id.concat(signature))}\n"

	## The size and the root of a signed checkpoint of the log `origin` (R-SG7 row 1). The text must start with `<origin>\n<size>\n<root>\n\n`:
	## the origin equal to `origin`, the size in decimal with no leading zero (`0` is allowed) that fits in a U64, the root in canonical base64 (RFC 4648 3.5)
	## of 32 bytes, then the empty line (no extension line, R-SG4). The signature lines are not checked. Else `Err(BadCheckpoint)`.
	parse_checkpoint : Str, Str -> Try(Tlog.Checkpoint, [BadCheckpoint])
	parse_checkpoint = |origin, text| match text.split_on("\n") {
		[o, size_text, root_text, ext, .. as rest] if o == origin and ext == "" and rest.len() > 0 => {
			size = parse_size(size_text)?
			root = b64_decode(root_text).map_err(|_| BadCheckpoint)?
			if root.len() == 32 {
				Ok({ size: size, root: root })
			} else {
				Err(BadCheckpoint)
			}
		}
		_ => Err(BadCheckpoint)
	}

	## The signer key text `PRIVATE+KEY+<name>+<key id>+<key data>` (R-WH14 `LOG_KEY`): a non-empty name with no space and no `+`,
	## the key id as 8 hex digits, the key data in base64 (it can hold `+`) of 33 bytes: 0x01 (Ed25519), then the 32-byte seed. Else `Err(BadKey)`.
	## The key id is not checked against the key here: the Worker checks it with the public key of the imported key (R-WH14).
	parse_signer_key : Str -> Try(Tlog.SignerKey, [BadKey])
	parse_signer_key = |text| match text.split_on("+") {
		["PRIVATE", "KEY", name, id_text, .. as rest] => {
			if name.count_utf8_bytes() == 0 or !name.to_utf8().all(|b| b > 32) {
				Err(BadKey)
			} else {
				id = hex_bytes(id_text)?
				data = b64_decode(Str.join_with(rest, "+")).map_err(|_| BadKey)?
				match data {
					[1, .. as seed] if seed.len() == 32 => Ok({ name: name, key_id: id, seed: seed })
					_ => Err(BadKey)
				}
			}
		}
		_ => Err(BadKey)
	}

	## The PKCS#8 DER of an Ed25519 seed for `WebCrypto.import_key!`: the 16 bytes 30 2e 02 01 00 30 05 06 03 2b 65 70 04 22 04 20, then the 32-byte seed.
	pkcs8 : List(U8) -> List(U8)
	pkcs8 = |seed| [0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20].concat(seed)

	# --- Private helpers ---

	sha : List(U8) -> List(U8)
	sha = |bytes| Crypto.SHA256.hash(bytes).to_bytes()

	# The largest power of 2 that is smaller than n (n at least 2).
	split_point : U64 -> U64
	split_point = |n| {
		var $p = 1.U64
		while $p * 2 < n {
			$p = $p * 2
		}
		$p
	}

	# N in 3-digit groups, each group but the last with an `x` before it.
	index_text : U64 -> Str
	index_text = |index| {
		var $groups = [index % 1000]
		var $rest = index // 1000
		while $rest > 0 {
			$groups = $groups.append($rest % 1000)
			$rest = $rest // 1000
		}
		# $groups has the last group first.
		match $groups {
			[] => "000"
			[last, .. as higher] => higher.rev().fold("", |acc, g| "${acc}x${pad3(g)}/").concat(pad3(last))
		}
	}

	pad3 : U64 -> Str
	pad3 = |v| if (v < 10) "00${v.to_str()}" else if (v < 100) "0${v.to_str()}" else v.to_str()

	# The tiles of one kind (the entry bundles, or one hash level) that change when the count goes from oc to nc (nc > oc), in index order.
	tiles_between : [Hashes(U8), Entries], U64, U64 -> List(Tlog.Tile)
	tiles_between = |level, oc, nc| {
		var $out = []
		for n in (oc // 256)..=((nc - 1) // 256) {
			$out = $out.append({ level: level, index: n, width: if (nc - n * 256 > 256) 256 else nc - n * 256 })
		}
		$out
	}

	# The entries of the partial bundle of size `old`, from the edge tiles.
	edge_entries : U64, List(Tlog.TileBytes) -> Try(List(List(U8)), [BadEdge])
	edge_entries = |old, tiles| {
		w = old % 256
		if w == 0 {
			Ok([])
		} else {
			want = { level: Entries, index: old // 256, width: w }
			match tiles.find_first(|t| t.tile == want) {
				Ok(t) => {
					parsed = parse_bundle(t.bytes)?
					if parsed.len() == w {
						Ok(parsed)
					} else {
						Err(BadEdge)
					}
				}
				Err(_) => Err(BadEdge)
			}
		}
	}

	parse_bundle : List(U8) -> Try(List(List(U8)), [BadEdge])
	parse_bundle = |bytes| match bytes {
		[] => Ok([])
		[a, b, .. as rest] => {
			n = a.to_u64() * 256 + b.to_u64()
			if rest.len() < n {
				Err(BadEdge)
			} else {
				tail = parse_bundle(rest.drop_first(n))?
				Ok([rest.take_first(n)].concat(tail))
			}
		}
		_ => Err(BadEdge)
	}

	# For each hash level (lowest first) while the count is above 0: the hashes of the partial tile of size `old` (none if the tile is full).
	edge_tails : U64, List(Tlog.TileBytes) -> Try(List(List(List(U8))), [BadEdge])
	edge_tails = |old, tiles| {
		var $out = []
		var $c = old
		var $l = 0.U8
		while $c > 0 {
			w = $c % 256
			if w == 0 {
				$out = $out.append([])
			} else {
				want = { level: Hashes($l), index: $c // 256, width: w }
				match tiles.find_first(|t| t.tile == want) {
					Ok(t) if t.bytes.len() == w * 32 => {
						$out = $out.append(t.bytes.chunks_of(32))
					}
					_ => return Err(BadEdge)
				}
			}
			$c = $c // 256
			$l = $l + 1
		}
		Ok($out)
	}

	# The RFC 6962 root from the partial tiles of each level (lowest first): the peaks of the tree, the smallest peak is the right-most.
	peaks_root : List(List(List(U8))) -> List(U8)
	peaks_root = |tails| {
		peaks = tails.rev().join_map(tile_peaks)
		match peaks.rev() {
			[] => sha([])
			[smallest, .. as bigger] => bigger.fold(smallest, |acc, p| node_hash(p, acc))
		}
	}

	# The roots of the perfect subtrees in a partial tile (width below 256): one for each bit of the width, the highest bit first.
	tile_peaks : List(List(U8)) -> List(List(U8))
	tile_peaks = |hashes| {
		var $out = []
		var $pos = 0.U64
		var $bit = 128.U64
		width = hashes.len()
		while $bit > 0 {
			if (width // $bit) % 2 == 1 {
				$out = $out.append(root_of(hashes.sublist({ start: $pos, len: $bit })))
				$pos = $pos + $bit
			}
			$bit = $bit // 2
		}
		$out
	}

	# A size in decimal: at least one digit, no leading zero (but `0`), fits in a U64.
	parse_size : Str -> Try(U64, [BadCheckpoint])
	parse_size = |text| {
		bs = text.to_utf8()
		ok_form = bs.len() > 0 and bs.all(|b| b >= 48 and b <= 57) and (bs.len() == 1 or bs.first() != Ok(48))
		if ok_form {
			U64.from_str(text).map_err(|_| BadCheckpoint)
		} else {
			Err(BadCheckpoint)
		}
	}

	hex_val : U8 -> Try(U8, [BadKey])
	hex_val = |c| {
		if in_range(c, 48, 57) {
			Ok(c - 48)
		} else if in_range(c, 97, 102) {
			Ok(c - 87)
		} else if in_range(c, 65, 70) {
			Ok(c - 55)
		} else {
			Err(BadKey)
		}
	}

	# 8 hex digits as 4 bytes.
	hex_bytes : Str -> Try(List(U8), [BadKey])
	hex_bytes = |text| {
		bs = text.to_utf8()
		if bs.len() != 8 {
			Err(BadKey)
		} else {
			vals = bs.map_try(hex_val)?
			Ok(
				vals.chunks_of(2).map(
					|p| match p {
						[a, b] => a * 16 + b
						_ => 0
					},
				),
			)
		}
	}

	b64_alphabet : List(U8)
	b64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".to_utf8()

	# Standard base64 with `=` padding.
	b64_encode : List(U8) -> Str
	b64_encode = |bytes| {
		out = bytes.chunks_of(3).map(
			|c| {
				x0 = (c.get(0) ?? 0).to_u64()
				x1 = (c.get(1) ?? 0).to_u64()
				x2 = (c.get(2) ?? 0).to_u64()
				n = x0 * 65536 + x1 * 256 + x2
				d0 = b64_alphabet.get(n // 262144) ?? 61
				d1 = b64_alphabet.get((n // 4096) % 64) ?? 61
				d2 = if (c.len() > 1) (b64_alphabet.get((n // 64) % 64) ?? 61) else 61
				d3 = if (c.len() > 2) (b64_alphabet.get(n % 64) ?? 61) else 61
				[d0, d1, d2, d3]
			},
		).join()
		Str.from_utf8(out) ?? ""
	}

	in_range : U8, U8, U8 -> Bool
	in_range = |c, lo, hi| c >= lo and c <= hi

	b64_val : U8 -> Try(U8, [BadBase64])
	b64_val = |c| {
		if in_range(c, 65, 90) {
			Ok(c - 65)
		} else if in_range(c, 97, 122) {
			Ok(c - 71)
		} else if in_range(c, 48, 57) {
			Ok(c + 4)
		} else if c == 43 {
			Ok(62)
		} else if c == 47 {
			Ok(63)
		} else {
			Err(BadBase64)
		}
	}

	# Canonical base64 (RFC 4648 3.5): the length is a multiple of 4, `=` only at the end (at most 2), the unused bits are 0.
	b64_decode : Str -> Try(List(U8), [BadBase64])
	b64_decode = |text| {
		cs = text.to_utf8()
		if cs.len() % 4 != 0 {
			Err(BadBase64)
		} else {
			pad = if (cs.take_last(2) == [61, 61]) 2 else if (cs.take_last(1) == [61]) 1 else 0
			vals = cs.drop_last(pad).map_try(b64_val)?
			groups = vals.chunks_of(4).map_try(
				|g| {
					k = g.len()
					n = g.concat(List.repeat(0, 4 - k)).fold(0.U64, |acc, v| acc * 64 + v.to_u64())
					canonical = k == 4 or (k == 3 and n % 256 == 0) or (k == 2 and n % 65536 == 0)
					if canonical {
						Ok([(n // 65536).to_u8_wrap(), ((n // 256) % 256).to_u8_wrap(), (n % 256).to_u8_wrap()].take_first(k - 1))
					} else {
						Err(BadBase64)
					}
				},
			)?
			Ok(groups.join())
		}
	}
}
