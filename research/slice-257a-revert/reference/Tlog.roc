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
	tlog_index = |idx| if (idx < 1) Err(NotALeaf) else (idx - 1).to_u64_try().map_err(|_| NotALeaf)

	## RFC 6962: SHA-256(0x00 ‖ entry bytes).
	leaf_hash : List(U8) -> List(U8)
	leaf_hash = |e| Crypto.SHA256.hash([0].concat(e)).to_bytes()

	## RFC 6962: SHA-256(0x01 ‖ left ‖ right).
	node_hash : List(U8), List(U8) -> List(U8)
	node_hash = |l, r| Crypto.SHA256.hash([1].concat(l).concat(r)).to_bytes()

	## RFC 6962 MTH of the leaf hashes in order. No leaf: SHA-256 of no bytes.
	root_of : List(List(U8)) -> List(U8)
	root_of = |hs| {
		n = hs.len()
		if n == 0 {
			Crypto.SHA256.hash([]).to_bytes()
		} else if n == 1 {
			hs.first() ?? []
		} else {
			var $k = 1
			while $k * 2 < n {
				$k = $k * 2
			}
			Tlog.node_hash(Tlog.root_of(hs.take_first($k)), Tlog.root_of(hs.drop_first($k)))
		}
	}

	## tlog-tiles: `tile/<L>/<N>[.p/<W>]` or `tile/entries/<N>[.p/<W>]`, with no prefix and no leading `/`. N is in 3-digit groups, each with leading zeros,
	## and each group but the last has an `x` before it (1234067 is `x001/x234/067`). `.p/<W>` only when the width is less than 256.
	path : Tlog.Tile -> Str
	path = |t| {
		prefix = match t.level {
			Entries => "tile/entries/"
			Hashes(l) => "tile/${l.to_str()}/"
		}
		suffix = if (t.width >= 256) "" else ".p/${t.width.to_str()}"
		"${prefix}${n_path(t.index)}${suffix}"
	}

	# The groups of 3 digits, high first, `x` before each but the last.
	n_path : U64 -> Str
	n_path = |n| {
		var $groups = [n % 1000]
		var $rest = n // 1000
		while $rest > 0 {
			$groups = [$rest % 1000].concat($groups)
			$rest = $rest // 1000
		}
		last = $groups.len() - 1
		var $out = ""
		var $i = 0
		for g in $groups {
			pad = if (g < 10) "00" else if (g < 100) "0" else ""
			x = if ($i < last) "x" else ""
			sep = if ($i < last) "/" else ""
			$out = "${$out}${x}${pad}${g.to_str()}${sep}"
			$i = $i + 1
		}
		$out
	}

	## The tiles that a tree of size `new` has and a tree of size `old` does not have (the full tiles that the growth fills, and the partial tile of `new` at each level where it changed).
	## Order: the entry bundles, then level 0, level 1, and on; in index order in each. `old >= new` gives `[]`.
	growth : U64, U64 -> List(Tlog.Tile)
	growth = |old, new| {
		if old >= new {
			[]
		} else {
			var $out = level_growth(Entries, old, new)
			var $co = old
			var $cn = new
			var $l = 0.U8
			while $cn > 0 {
				$out = $out.concat(level_growth(Hashes($l), $co, $cn))
				$co = $co // 256
				$cn = $cn // 256
				$l = $l + 1
			}
			$out
		}
	}

	# The new tiles of one level, from co to cn hashes.
	level_growth : [Hashes(U8), Entries], U64, U64 -> List(Tlog.Tile)
	level_growth = |level, co, cn| {
		if co == cn {
			[]
		} else {
			var $out = []
			var $n = co // 256
			while $n < cn // 256 {
				$out = $out.append({ level, index: $n, width: 256 })
				$n = $n + 1
			}
			if cn % 256 > 0 {
				$out.append({ level, index: cn // 256, width: cn % 256 })
			} else {
				$out
			}
		}
	}

	## The partial tiles of a tree of size `size` (the entry bundle and each hash level that has one), in the order of `growth`. The step reads them before `grow` (R-SG7 row 1).
	edge : U64 -> List(Tlog.Tile)
	edge = |size| {
		var $out = if (size % 256 > 0) [{ level: Entries, index: size // 256, width: size % 256 }] else []
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
	grow = |old, given, entries| {
		if entries.any(|e| e.len() > 65535) {
			Err(EntryTooLong)
		} else {
			# The partial tiles of old, as lists: the entries, and the hashes of each level.
			var $old_entries = []
			var $parts = []
			for t in Tlog.edge(old) {
				found = given.keep_if(|g| g.tile == t).first() ?? { tile: t, bytes: [] }
				match t.level {
					Entries => {
						es = parse_bundle(found.bytes) ?? []
						if es.len() != t.width {
							return Err(BadEdge)
						}
						$old_entries = es
					}
					Hashes(l) => {
						if found.bytes.len() != t.width * 32 {
							return Err(BadEdge)
						}
						while $parts.len() < l.to_u64() {
							$parts = $parts.append([])
						}
						$parts = $parts.append(found.bytes.chunks_of(32))
					}
				}
			}
			# The entry bundles.
			var $tiles = []
			if entries.len() > 0 {
				first_bundle = old // 256
				var $k = 0
				for chunk in $old_entries.concat(entries).chunks_of(256) {
					$tiles = $tiles.append({ tile: { level: Entries, index: first_bundle + $k, width: chunk.len() }, bytes: Tlog.bundle(chunk) ?? [] })
					$k = $k + 1
				}
			}
			# The hash levels: the hashes from the start of the old partial tile, the full chunks go one level up.
			var $new_hashes = entries.map(Tlog.leaf_hash)
			var $new_parts = []
			var $co = old
			var $l = 0.U8
			while $new_hashes.len() > 0 or $co > 0 {
				part = $parts.get($l.to_u64()) ?? []
				if $new_hashes.len() == 0 {
					$new_parts = $new_parts.append(part)
				} else {
					all = part.concat($new_hashes)
					var $up = []
					var $k = 0
					var $last = []
					for chunk in all.chunks_of(256) {
						$tiles = $tiles.append({ tile: { level: Hashes($l), index: $co // 256 + $k, width: chunk.len() }, bytes: chunk.join() })
						if chunk.len() == 256 {
							$up = $up.append(Tlog.root_of(chunk))
						} else {
							$last = chunk
						}
						$k = $k + 1
					}
					$new_parts = $new_parts.append($last)
					$new_hashes = $up
				}
				$co = $co // 256
				$l = $l + 1
			}
			Ok({ old_root: root_of_parts($parts), root: root_of_parts($new_parts), tiles: $tiles })
		}
	}

	# The root from the partial tiles of a size (level 0 first): the perfect subtrees, largest first, then folded from the right.
	root_of_parts : List(List(List(U8))) -> List(U8)
	root_of_parts = |parts| {
		var $subs = []
		for hs in parts.rev() {
			var $rest = hs
			while $rest.len() > 0 {
				var $k = 1
				while $k * 2 <= $rest.len() {
					$k = $k * 2
				}
				$subs = $subs.append(Tlog.root_of($rest.take_first($k)))
				$rest = $rest.drop_first($k)
			}
		}
		match $subs.last() {
			Err(_) => Crypto.SHA256.hash([]).to_bytes()
			Ok(right) => $subs.drop_last(1).fold_rev(right, |h, acc| Tlog.node_hash(h, acc))
		}
	}

	# The entries of a bundle; a cut entry is an error.
	parse_bundle : List(U8) -> Try(List(List(U8)), [BadEdge])
	parse_bundle = |bytes| {
		var $out = []
		var $i = 0
		while $i < bytes.len() {
			hi = bytes.get($i) ?? 0
			lo = bytes.get($i + 1) ?? 0
			n = hi.to_u64() * 256 + lo.to_u64()
			if $i + 2 + n > bytes.len() {
				return Err(BadEdge)
			}
			$out = $out.append(bytes.sublist({ start: $i + 2, len: n }))
			$i = $i + 2 + n
		}
		Ok($out)
	}

	## tlog-tiles: the bytes of an entry bundle: each entry with a big-endian uint16 length before it. An entry longer than 65,535 bytes is `Err(EntryTooLong)`.
	bundle : List(List(U8)) -> Try(List(U8), [EntryTooLong])
	bundle = |entries| {
		if entries.any(|e| e.len() > 65535) {
			Err(EntryTooLong)
		} else {
			Ok(entries.fold([], |acc, e| acc.append((e.len() // 256).to_u8_wrap()).append((e.len() % 256).to_u8_wrap()).concat(e)))
		}
	}

	## tlog-checkpoint: `<origin>\n<size>\n<base64 root>\n`: the size in decimal, the root in standard base64 with `=` padding. No extension line (R-SG4).
	checkpoint_body : Str, U64, List(U8) -> Str
	checkpoint_body = |origin, size, root| "${origin}\n${size.to_str()}\n${b64(root)}\n"

	## signed-note: the key id of an Ed25519 key: the first 4 bytes of SHA-256(key name ‖ 0x0A ‖ 0x01 ‖ 32-byte public key).
	key_id : Str, List(U8) -> List(U8)
	key_id = |name, key| Crypto.SHA256.hash(name.to_utf8().concat([10, 1]).concat(key)).to_bytes().take_first(4)

	## signed-note: the note text (it ends in a newline), an empty line, and the line `— <key name> <base64(key id ‖ signature)>\n` (U+2014, a space).
	## Arguments: the note text, the key name, the 4-byte key id, the 64-byte Ed25519 signature of the note text.
	signed_note : Str, Str, List(U8), List(U8) -> Str
	signed_note = |text, name, id, sig| "${text}\n— ${name} ${b64(id.concat(sig))}\n"

	## The size and the root of a signed checkpoint of the log `origin` (R-SG7 row 1). The text must start with `<origin>\n<size>\n<root>\n\n`:
	## the origin equal to `origin`, the size in decimal with no leading zero (`0` is allowed) that fits in a U64, the root in canonical base64 (RFC 4648 3.5)
	## of 32 bytes, then the empty line (no extension line, R-SG4). The signature lines are not checked. Else `Err(BadCheckpoint)`.
	parse_checkpoint : Str, Str -> Try(Tlog.Checkpoint, [BadCheckpoint])
	parse_checkpoint = |origin, text| match text.split_on("\n") {
		[o, s, r, "", _, ..] if o == origin => {
			bytes = s.to_utf8()
			digits_ok = bytes.len() > 0 and bytes.all(|b| b >= 48 and b <= 57) and (bytes.len() == 1 or bytes.first() != Ok(48))
			size = if (digits_ok) U64.from_str(s).map_err(|_| BadCheckpoint) else Err(BadCheckpoint)
			root = unb64(r).map_err(|_| BadCheckpoint)
			match (size, root) {
				(Ok(n), Ok(h)) if h.len() == 32 => Ok({ size: n, root: h })
				_ => Err(BadCheckpoint)
			}
		}
		_ => Err(BadCheckpoint)
	}

	## The signer key text `PRIVATE+KEY+<name>+<key id>+<key data>` (R-WH14 `LOG_KEY`): a non-empty name with no space and no `+`,
	## the key id as 8 hex digits, the key data in base64 (it can hold `+`) of 33 bytes: 0x01 (Ed25519), then the 32-byte seed. Else `Err(BadKey)`.
	## The key id is not checked against the key here: the Worker checks it with the public key of the imported key (R-WH14).
	parse_signer_key : Str -> Try(Tlog.SignerKey, [BadKey])
	parse_signer_key = |text| match text.split_on("+") {
		["PRIVATE", "KEY", name, id, first, .. as more] => {
			data_text = more.fold(first, |acc, p| "${acc}+${p}")
			name_ok = name != "" and name.to_utf8().all(|b| b > 32)
			id_bytes = id.to_utf8()
			id_ok = id_bytes.len() == 8 and id_bytes.all(|b| (b >= 48 and b <= 57) or (b >= 97 and b <= 102) or (b >= 65 and b <= 70))
			data = unb64(data_text) ?? []
			if name_ok and id_ok and data.len() == 33 and data.first() == Ok(1) {
				Ok({ name, key_id: id_bytes.chunks_of(2).map(|p| p.fold(0, |a, c| a * 16 + hex_value(c))), seed: data.drop_first(1) })
			} else {
				Err(BadKey)
			}
		}
		_ => Err(BadKey)
	}

	hex_value : U8 -> U8
	hex_value = |c| if (c >= 97) c - 87 else if (c >= 65) c - 55 else c - 48

	alphabet : List(U8)
	alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".to_utf8()

	# Standard base64 with `=` padding.
	b64 : List(U8) -> Str
	b64 = |bytes| {
		ch = |i| alphabet.get(i.to_u64()) ?? 61
		out = bytes.chunks_of(3).fold(
			[],
			|acc, c| match c {
				[a, b, d] => acc.concat([ch(a // 4), ch((a % 4) * 16 + b // 16), ch((b % 16) * 4 + d // 64), ch(d % 64)])
				[a, b] => acc.concat([ch(a // 4), ch((a % 4) * 16 + b // 16), ch((b % 16) * 4), 61])
				[a] => acc.concat([ch(a // 4), ch((a % 4) * 16), 61, 61])
				_ => acc
			},
		)
		Str.from_utf8(out) ?? ""
	}

	# Canonical standard base64 (RFC 4648 3.5): padding, and zero bits after the last byte.
	unb64 : Str -> Try(List(U8), [BadBase64])
	unb64 = |text| {
		cs = text.to_utf8()
		if cs.len() % 4 != 0 {
			Err(BadBase64)
		} else {
			pad = if (cs.last() == Ok(61)) (if (cs.drop_last(1).last() == Ok(61)) 2 else 1) else 0
			body = cs.drop_last(pad)
			vals = body.map(
				|c| if (c >= 65 and c <= 90) c - 65 else if (c >= 97 and c <= 122) c - 71 else if (c >= 48 and c <= 57) c + 4 else if (c == 43) 62 else if (c == 47) 63 else 255,
			)
			if vals.any(|v| v == 255) {
				Err(BadBase64)
			} else {
				bits = vals.fold([], |acc, v| acc.concat([v // 32 % 2, v // 16 % 2, v // 8 % 2, v // 4 % 2, v // 2 % 2, v % 2]))
				whole = bits.len() // 8 * 8
				if bits.drop_first(whole).any(|b| b != 0) {
					Err(BadBase64)
				} else {
					Ok(bits.take_first(whole).chunks_of(8).map(|byte| byte.fold(0, |a, b| a * 2 + b)))
				}
			}
		}
	}

	## The PKCS#8 DER of an Ed25519 seed for `WebCrypto.import_key!`: the 16 bytes 30 2e 02 01 00 30 05 06 03 2b 65 70 04 22 04 20, then the 32-byte seed.
	pkcs8 : List(U8) -> List(U8)
	pkcs8 = |seed| [0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20].concat(seed)
}
