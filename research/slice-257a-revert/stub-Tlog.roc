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
	entry = |_leaf| crash "todo"

	## R-SG2: the tlog index of the D1 `idx`: `idx - 1`. An `idx` below 1 is `Err(NotALeaf)`.
	tlog_index : I64 -> Try(U64, [NotALeaf])
	tlog_index = |_idx| crash "todo"

	## RFC 6962: SHA-256(0x00 ‖ entry bytes).
	leaf_hash : List(U8) -> List(U8)
	leaf_hash = |_entry| crash "todo"

	## RFC 6962: SHA-256(0x01 ‖ left ‖ right).
	node_hash : List(U8), List(U8) -> List(U8)
	node_hash = |_left, _right| crash "todo"

	## RFC 6962 MTH of the leaf hashes in order. No leaf: SHA-256 of no bytes.
	root_of : List(List(U8)) -> List(U8)
	root_of = |_leaf_hashes| crash "todo"

	## tlog-tiles: `tile/<L>/<N>[.p/<W>]` or `tile/entries/<N>[.p/<W>]`, with no prefix and no leading `/`. N is in 3-digit groups, each with leading zeros,
	## and each group but the last has an `x` before it (1234067 is `x001/x234/067`). `.p/<W>` only when the width is less than 256.
	path : Tlog.Tile -> Str
	path = |_tile| crash "todo"

	## The tiles that a tree of size `new` has and a tree of size `old` does not have (the full tiles that the growth fills, and the partial tile of `new` at each level where it changed).
	## Order: the entry bundles, then level 0, level 1, and on; in index order in each. `old >= new` gives `[]`.
	growth : U64, U64 -> List(Tlog.Tile)
	growth = |_old, _new| crash "todo"

	## The partial tiles of a tree of size `size` (the entry bundle and each hash level that has one), in the order of `growth`. The step reads them before `grow` (R-SG7 row 1).
	edge : U64 -> List(Tlog.Tile)
	edge = |_size| crash "todo"

	## The growth of the tree from size `old` to size `old + entries.len()`. `edge` holds the tiles of `edge(old)` with their bytes, in any order (other tiles are ignored).
	## `entries` are the entry bytes of the new leaves in tlog index order, from index `old`.
	## A tile of `edge(old)` that is missing, or whose bytes do not have its width (32 bytes for each hash; `width` entries in a bundle), is `Err(BadEdge)`.
	## An entry longer than 65,535 bytes is `Err(EntryTooLong)`.
	grow : U64, List(Tlog.TileBytes), List(List(U8)) -> Try(Tlog.Grown, [BadEdge, EntryTooLong])
	grow = |_old, _edge, _entries| crash "todo"

	## tlog-tiles: the bytes of an entry bundle: each entry with a big-endian uint16 length before it. An entry longer than 65,535 bytes is `Err(EntryTooLong)`.
	bundle : List(List(U8)) -> Try(List(U8), [EntryTooLong])
	bundle = |_entries| crash "todo"

	## tlog-checkpoint: `<origin>\n<size>\n<base64 root>\n`: the size in decimal, the root in standard base64 with `=` padding. No extension line (R-SG4).
	checkpoint_body : Str, U64, List(U8) -> Str
	checkpoint_body = |_origin, _size, _root| crash "todo"

	## signed-note: the key id of an Ed25519 key: the first 4 bytes of SHA-256(key name ‖ 0x0A ‖ 0x01 ‖ 32-byte public key).
	key_id : Str, List(U8) -> List(U8)
	key_id = |_name, _public_key| crash "todo"

	## signed-note: the note text (it ends in a newline), an empty line, and the line `— <key name> <base64(key id ‖ signature)>\n` (U+2014, a space).
	## Arguments: the note text, the key name, the 4-byte key id, the 64-byte Ed25519 signature of the note text.
	signed_note : Str, Str, List(U8), List(U8) -> Str
	signed_note = |_text, _name, _key_id, _signature| crash "todo"

	## The size and the root of a signed checkpoint of the log `origin` (R-SG7 row 1). The text must start with `<origin>\n<size>\n<root>\n\n`:
	## the origin equal to `origin`, the size in decimal with no leading zero (`0` is allowed) that fits in a U64, the root in canonical base64 (RFC 4648 3.5)
	## of 32 bytes, then the empty line (no extension line, R-SG4). The signature lines are not checked. Else `Err(BadCheckpoint)`.
	parse_checkpoint : Str, Str -> Try(Tlog.Checkpoint, [BadCheckpoint])
	parse_checkpoint = |_origin, _text| crash "todo"

	## The signer key text `PRIVATE+KEY+<name>+<key id>+<key data>` (R-WH14 `LOG_KEY`): a non-empty name with no space and no `+`,
	## the key id as 8 hex digits, the key data in base64 (it can hold `+`) of 33 bytes: 0x01 (Ed25519), then the 32-byte seed. Else `Err(BadKey)`.
	## The key id is not checked against the key here: the Worker checks it with the public key of the imported key (R-WH14).
	parse_signer_key : Str -> Try(Tlog.SignerKey, [BadKey])
	parse_signer_key = |_text| crash "todo"

	## The PKCS#8 DER of an Ed25519 seed for `WebCrypto.import_key!`: the 16 bytes 30 2e 02 01 00 30 05 06 03 2b 65 70 04 22 04 20, then the 32-byte seed.
	pkcs8 : List(U8) -> List(U8)
	pkcs8 = |_seed| crash "todo"
}
