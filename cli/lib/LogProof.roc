import records.Tlog
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
}
