import records.Tlog
import records.Release
import records.Toolchain
import Fail
import JsonDoc
import LogKey
import ed25519.Ed25519

## The pure checks of a log proof (CLI slice 261b, DESIGN-CLI 7.6 R-LV2, R-LV4). The tlog math is `records.Tlog` (Design Q636 (14));
## the Ed25519 verify is `Ed25519.verify` of the generic package roc-ed25519 (Design R-PK10), by its release URL in `cli/lib/main.roc`.
## Slice 261c adds the rest (D1, R-LV9, the texts). Tests: `tests/unit/LogproofTest.roc`.
LogProof :: [].{

	## R-LV4: the size and the root of a signed checkpoint, checked with the key. Steps, in this order:
	## 1. `Tlog.open_note(text)`; a bad note is `Err(BadNote)`.
	## 2. The signature lines with the name AND the key id of the key; none is `Err(NoSignature)` (lines of other keys are ignored).
	## 3. Each such line must have a 64-byte signature that `Ed25519.verify` accepts for the public key and the bytes of the note text; else `Err(BadSignature)`.
	## 4. `Tlog.parse_checkpoint(key.name, text)`: the origin is the key name, no extension line; else `Err(BadCheckpoint)`.
	open_checkpoint : LogKey.VerifierKey, Str -> Try(Tlog.Checkpoint, [BadNote, NoSignature, BadSignature, BadCheckpoint])
	open_checkpoint = |key, text| {
		note = Tlog.open_note(text)?
		lines = note.signatures.keep_if(|s| s.name == key.name and s.key_id == key.key_id)
		message = note.text.to_utf8()
		if lines.is_empty() {
			Err(NoSignature)
		} else if !lines.all(|s| Ed25519.verify({ public_key: key.public_key, message: message, signature: s.signature })) {
			Err(BadSignature)
		} else {
			Tlog.parse_checkpoint(key.name, text)
		}
	}

	## R-LV2: the leaf of a release row. The leaf must have `grp == group`, `version == version` and `hash == hash`, else `Err(EntryDiffers)` (T1).
	## Then the row `url` must be `https://` + `grp` with `{v}` changed to `version`, + `hash` + `.tar.zst` (R-ID2, Registry R-AP15), else `Err(UrlDiffers)` (T2b).
	check_release : { group : Str, version : Str, hash : Str, url : Str }, Tlog.Leaf -> Try({}, [EntryDiffers, UrlDiffers])
	check_release = |row, leaf| {
		if [leaf.grp == row.group, leaf.version == row.version, leaf.hash == row.hash].any(|same| !same) {
			Err(EntryDiffers)
		} else if row.url != "https://${leaf.grp.replace_each("{v}", leaf.version)}${leaf.hash}.tar.zst" {
			Err(UrlDiffers)
		} else {
			Ok({})
		}
	}

	## R-LV2, Registry R-SG3: the leaf of a compiler row (R-CV3): `grp == "roc-lang/nightlies:<target>"`, `version == tag`, `hash == "sha256:<sha256>"`, else `Err(EntryDiffers)`.
	check_compiler : { target : Str, tag : Str, sha256 : Str }, Tlog.Leaf -> Try({}, [EntryDiffers])
	check_compiler = |row, leaf| {
		same = [leaf.grp == "roc-lang/nightlies:${row.target}", leaf.version == row.tag, leaf.hash == "sha256:${row.sha256}"].all(|b| b)
		if same {
			Ok({})
		} else {
			Err(EntryDiffers)
		}
	}

	## Slice 261c (R-LV1, R-LV2, R-LV11): one release that the command checks. `text` is `<release>` of the texts (`<alias>: <name> <version>`, CLI 3).
	Check : { text : Str, log_index : U64, group : Str, version : Str, hash : Str, url : Str }

	## Slice 261d (R-LV1, R-LV11, section 7 of slice 261): the check of the tool release that `tln tool install` or `tln x` writes, from the registry row `row` (R-AP1) of the
	## full name `name`. `text` is `<release>` of the texts: `tool <name> <version>`. The other fields are those of the row (`url` is the row URL, the `release` of `error.details`).
	tool_check : { name : Str, row : Release.Row } -> LogProof.Check
	tool_check = |x| { text: "tool ${x.name} ${x.row.version}", log_index: x.row.log_index, group: x.row.group, version: x.row.version, hash: x.row.hash, url: x.row.url }

	## Slice 261d (R-LV1, R-SE11, Registry R-SG3, section 7 of slice 261): the check of a compiler that Talon installs with the sha256 of a registry row (R-CV3), before the download.
	## `text` is `<release>` of the texts: `<tag> (<target>)`. `log_index` is the row value. `group` is `roc-lang/nightlies:<target>`, `version` the tag, `hash` `sha256:<sha256>`
	## (the fields of the leaf). `url` is the tag: it is the `release` of `error.details` for a compiler (CLI 3 catalog), so `fail` gives it with no change.
	compiler_check : Toolchain.Row -> LogProof.Check
	compiler_check = |row| { text: "${row.tag} (${row.target})", log_index: row.log_index, group: "roc-lang/nightlies:${row.target}", version: row.tag, hash: "sha256:${row.sha256}", url: row.tag }

	## Slice 261d (R-LV2): the compare of a check and its leaf. A compiler check (a `group` that starts with `roc-lang/nightlies:`, `compiler_check`) is compared as
	## `check_compiler` does (group, version and hash; there is no URL check, so never `UrlDiffers`). Any other check is `check_release` (T1, then T2b).
	check_leaf : LogProof.Check, Tlog.Leaf -> Try({}, [EntryDiffers, UrlDiffers])
	check_leaf = |c, leaf| {
		if c.group.starts_with("roc-lang/nightlies:") {
			check_compiler({ target: c.group.drop_prefix("roc-lang/nightlies:"), tag: c.version, sha256: c.hash.drop_prefix("sha256:") }, leaf).map_err(|_| EntryDiffers)
		} else {
			check_release({ group: c.group, version: c.version, hash: c.hash, url: c.url }, leaf)
		}
	}

	## Slice 261c (R-LV1, Design R-SE2): the releases that a command checks. `after` are the header values that the command writes (alias, full name, URL), `before`
	## the URLs that the header has now, `rows` the release rows of the registry answers of the run. A value is checked when its URL is not in `before` and is the
	## `url` of a row. Each URL once (the first value that names it), in the order of `log_index` (a proposal: the order of the reads and of the first failure).
	to_check : { before : List(Str), after : List({ alias : Str, name : Str, url : Str }), rows : List(Release.Row) } -> List(LogProof.Check)
	to_check = |values| {
		var $seen = []
		var $found = []
		for value in values.after {
			if !values.before.contains(value.url) and !$seen.contains(value.url) {
				match values.rows.find_first(|r| r.url == value.url) {
					Ok(r) => {
						$seen = $seen.append(value.url)
						$found = $found.append({ text: "${value.alias}: ${value.name} ${r.version}", log_index: r.log_index, group: r.group, version: r.version, hash: r.hash, url: r.url })
					}
					Err(_) => {}
				}
			}
		}
		$found.sort_with(|a, b| if (a.log_index < b.log_index) Before else if (a.log_index > b.log_index) After else Same)
	}

	## Slice 261c (R-LV9): the decision after read `read` (1 to 4) of a checkpoint of size `size`, when the command needs the size `need` (the largest `log_index`).
	## `Covers` when `size >= need`. Else `Again(ms)`: the wait before the next read, 2000, 4000 and 8000 ms after the reads 1, 2 and 3. After read 4: `Behind` (T5).
	after_read : { read : U64, size : U64, need : U64 } -> [Covers, Again(U64), Behind]
	after_read = |x| {
		if x.size >= x.need {
			Covers
		} else {
			match x.read {
				1 => Again(2000)
				2 => Again(4000)
				3 => Again(8000)
				_ => Behind
			}
		}
	}

	## Slice 261c (R-LV3, R-LV7, R-LV10): the tiles of one command, in the order of the reads, with no duplicate. First the consistency tiles of `kept` and `size`
	## (`Tlog.consistency_tiles`; `kept` is the size of the kept checkpoint when the command read a new one, else `Err(None)`), then for each log index of
	## `indexes` in the given order: its entry bundle (`Tlog.entry_tile(log_index - 1, size)`) and its proof tiles (`Tlog.proof_tiles(log_index - 1, size)`).
	tiles_of : { kept : Try(U64, [None]), size : U64, indexes : List(U64) } -> List(Tlog.Tile)
	tiles_of = |x| {
		first = match x.kept {
			Ok(kept) => Tlog.consistency_tiles(kept, x.size)
			Err(None) => []
		}
		each = x.indexes.join_map(
			|i| {
				at = if (i == 0) 0 else i - 1
				entry = match Tlog.entry_tile(at, x.size) {
					Ok(tile) => [tile]
					Err(NotInTree) => []
				}
				entry.concat(Tlog.proof_tiles(at, x.size))
			},
		)
		first.concat(each).fold([], |all, tile| if (all.contains(tile)) all else all.append(tile))
	}

	## Slice 261c (R-IX8): the text of the copy of a tile. A hash tile: each 32-byte hash as 64 lower-case hex digits and `\n`. An entry bundle: its entries
	## one after the other, with no length (each entry ends in `\n`). Bytes that are not `width` hashes or entries, or an entry that is not UTF-8: `Err(BadTile)`.
	copy_text : Tlog.TileBytes -> Try(Str, [BadTile])
	copy_text = |tile_bytes| {
		tile = tile_bytes.tile
		match tile.level {
			Hashes(_) => {
				if tile_bytes.bytes.len() == tile.width * 32 {
					Ok(Str.join_with(tile_bytes.bytes.chunks_of(32).map(|hash| hex_of(hash)), "\n").concat("\n"))
				} else {
					Err(BadTile)
				}
			}
			Entries => {
				entries = Tlog.parse_bundle(tile_bytes.bytes).map_err(|_| BadTile)?
				whole = entries.all(|e| e.last() == Ok(10) and e.drop_last(1).keep_if(|b| b == 10).is_empty())
				if entries.len() == tile.width and whole {
					Str.from_utf8(entries.join_map(|e| e)).map_err(|_| BadTile)
				} else {
					Err(BadTile)
				}
			}
		}
	}

	## Slice 261c (R-IX8): the served bytes of a tile from the text of its copy (the reverse of `copy_text`). A text that is not `width` lines of the form: `Err(BadCopy)`.
	copy_bytes : Tlog.Tile, Str -> Try(List(U8), [BadCopy])
	copy_bytes = |tile, text| {
		if !text.ends_with("\n") {
			Err(BadCopy)
		} else {
			lines = text.drop_suffix("\n").split_on("\n")
			if lines.len() != tile.width {
				Err(BadCopy)
			} else {
				match tile.level {
					Hashes(_) => {
						decoded = lines.map_try(|line| hex_bytes(line, 64))?
						Ok(decoded.join_map(|b| b))
					}
					Entries => {
						sizes = lines.map(|line| line.to_utf8().len() + 1)
						if sizes.any(|n| n > 65535) {
							Err(BadCopy)
						} else {
							Ok(lines.join_map(|line| [(((line.to_utf8().len() + 1) // 256)).to_u8_wrap(), ((line.to_utf8().len() + 1) % 256).to_u8_wrap()].concat(line.to_utf8()).append(10)))
						}
					}
				}
			}
		}
	}

	## Slice 261c (R-LV11): why a check failed. `EntryDiffers(<grp> <version> <hash>)` of the leaf (T1), `NotIncluded` (T2), `UrlDiffers` (T2b), `BadSignature` (T3),
	## `NotConsistent` (T4: the kept size, the date `YYYY-MM-DD` (UTC) of the kept file, its path), `Behind` (T5), `NoAnswer(cause)` (T6), `TileMissing` (T6b: the tile path
	## `tile/...`, the cause), `Offline` (T7). A cause has the words of R-RG9 row 5: `timeout`, `status 404`, `status 503`, the text of `Failed`.
	Why : [EntryDiffers(Str), NotIncluded, UrlDiffers, BadSignature({ key : LogKey.VerifierKey, source : LogKey.Source }), NotConsistent({ kept : U64, date : Str, path : Str }), Behind, NoAnswer(Str), TileMissing({ tile : Str, cause : Str }), Offline]

	## Slice 261c (R-LV11, R-LV12, CLI 3 catalog): the failure of a check of the registry `base` (R-RG7 form). Kind `Integrity` (exit 16) for T1, T2, T2b, T3, T4;
	## kind `Network` (exit 15) for T5, T6, T6b, T7; the message is the approved text. `error.details`:
	## `{"log":"<base>/log","reason":<reason>,"size":<N or null>,"index":<log_index or null>,"release":<url or null>}`, in this order. A member is `null` when the text
	## does not name it (a proposal): `size` is null for T3, T6, T7; `index` and `release` are null for T3, T4, T6b. `size` is the size of the checkpoint of the check.
	fail : { base : Str, release : Try(LogProof.Check, [None]), size : Try(U64, [None]) }, LogProof.Why -> Fail
	fail = |context, why| {
		base = context.base
		text = context.release.map_ok(|c| c.text) ?? ""
		index = context.release.map_ok(|c| c.log_index)
		index_text = index.map_ok(|n| n.to_str()) ?? ""
		size_text = context.size.map_ok(|n| n.to_str()) ?? ""
		(kind, reason, message) = match why {
			EntryDiffers(entry) => (Integrity, "entry-differs", "${text}: the log of ${base} has another entry at log index ${index_text}: ${entry}. Talon wrote nothing.")
			NotIncluded => (Integrity, "not-included", "${text}: the inclusion proof of log index ${index_text} does not match the signed checkpoint of ${base} (size ${size_text}). Talon wrote nothing.")
			UrlDiffers => (Integrity, "url-differs", "${text}: the registry ${base} gave the URL ${context.release.map_ok(|c| c.url) ?? ""}, which is not the URL of its log entry. Talon wrote nothing.")
			BadSignature({ key, source }) => {
				via = match source {
					BuiltIn => "the built-in key"
					Env => "TALON_LOG_KEY"
					Config(path) => "log-key in ${path}"
				}
				(Integrity, "bad-signature", "the checkpoint of the log of ${base} has no valid signature of ${key.name}+${hex_of(key.key_id)} (${via}). Talon wrote nothing.")
			}
			NotConsistent({ kept, date, path }) => (Integrity, "not-consistent", "the log of ${base} changed its history: the checkpoint of size ${size_text} does not contain the checkpoint of size ${kept.to_str()} that Talon kept on ${date} (${path}). Talon wrote nothing. Report this to the registry operator.")
			Behind => (Network, "behind", "${text} (log index ${index_text}) is not in the log of ${base} yet: the checkpoint has size ${size_text} after 4 reads. Try again in a few minutes.")
			NoAnswer(cause) => (Network, "no-answer", "the log of ${base} does not answer (${cause}): Talon cannot check ${text}. Try again later, or use --registry direct.")
			TileMissing({ tile, cause }) => (Network, "tile-missing", "the log of ${base} has no tile ${tile} for size ${size_text} (${cause}). Try again later.")
			Offline => (Network, "offline", "${text} has no kept log proof and --offline is set. Run the command without --offline.")
		}
		# A member that the text does not name is null: the index and the release for T3, T4, T6b, the size for T3, T6, T7.
		names_release = ![reason == "bad-signature", reason == "not-consistent", reason == "tile-missing"].any(|b| b)
		names_size = ![reason == "bad-signature", reason == "no-answer", reason == "offline"].any(|b| b)
		details = LogKey.details({ base, reason, size: if (names_size) context.size else Err(None), index: if (names_release) index else Err(None), release: if (names_release) context.release.map_ok(|c| c.url) else Err(None) })
		{ ..Fail.new(kind, message), details: Ok(details) }
	}
}

# The lower-case hex digits of bytes.
hex_of : List(U8) -> Str
hex_of = |bytes| {
	digits = "0123456789abcdef".to_utf8()
	Str.from_utf8(bytes.join_map(|b| [digits.get((b // 16).to_u64()) ?? 48, digits.get((b % 16).to_u64()) ?? 48])) ?? ""
}

# The bytes of `digits` lower-case hex digits (R-IX8: no upper case). Else `Err(BadCopy)`.
hex_bytes : Str, U64 -> Try(List(U8), [BadCopy])
hex_bytes = |text, digits| {
	chars = text.to_utf8()
	values = chars.map_try(|c| if (c >= 48 and c <= 57) Ok(c - 48) else if (c >= 97 and c <= 102) Ok(c - 87) else Err(BadCopy))?
	if chars.len() == digits {
		Ok(values.chunks_of(2).map(|pair| pair.fold(0.U8, |acc, v| acc * 16 + v)))
	} else {
		Err(BadCopy)
	}
}
