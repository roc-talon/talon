import Fail
import JsonDoc
import TalonFile

## `share.json` in the data dir (slice 213, CLI 1 R-SH5, R-SH6, R-SH13, 6.1 R-TF1, R-TF2, R-TF6, Design Q201). Pure: the text of the file, the id and the read.
## The calls are in `ShareFlow`. The file is made by `tln share on` when it is missing (R-SH5), under the lock `share.json.lock` (R-LY3, R-CC6).
##
## | Member | Form in `Doc` | In the text |
## | --- | --- | --- |
## | `format` | not in `Doc` (always `ShareJson.format`) | first |
## | `id` | `id` | 32 lower-case hex characters |
## | `sent`, `counted`, `first` | `U64` | integers |
## | `first_sent_at`, `last_sent_at`, `token`, `token_expires_at` | `Try(Str, [Unset])` | text, or `null` for `Unset` |
## | `account` | `Try({ id : U64, login : Str }, [Unset])` | an object `{"id":<integer>,"login":<text>}` (Registry R-AP37), or `null` |
##
## A member that Talon does not know is in `extra`, in the order of the text, and `text` writes it after the known members (R-TF2).
ShareJson :: [].{

	## R-TF1, R-SH13: the `format` that this Talon writes.
	format : U64
	format = 1

	Doc : {
		id : Str,
		sent : U64,
		counted : U64,
		first : U64,
		first_sent_at : Try(Str, [Unset]),
		last_sent_at : Try(Str, [Unset]),
		token : Try(Str, [Unset]),
		token_expires_at : Try(Str, [Unset]),
		account : Try({ id : U64, login : Str }, [Unset]),
		extra : List((Str, JsonDoc)),
	}

	## R-SH5: the id from 2 random numbers (`Fx.random!`, TW2): 16 lower-case hex digits of `high`, then 16 of `low`, each with leading zeros.
	id_of : { high : U64, low : U64 } -> Str
	id_of = |halves| "${hex16(halves.high)}${hex16(halves.low)}"

	## R-SH5, R-SH6, R-SH13: a new file for `id`: the 3 totals are 0 and each other member is `Unset`. `extra` is empty.
	fresh : Str -> Doc
	fresh = |id| {
		id,
		sent: 0,
		counted: 0,
		first: 0,
		first_sent_at: Err(Unset),
		last_sent_at: Err(Unset),
		token: Err(Unset),
		token_expires_at: Err(Unset),
		account: Err(Unset),
		extra: [],
	}

	## Slice 213b (Design Q213, R-SH8, R-SH13): the `Doc` that `tln share` shows (`ShareJson.absent({})`) when `share.json` does not exist: the id is the text `none`, the 3 totals are 0, each other member is `Unset`, `extra` is empty.
	## It is never written. `Share.status_lines` and `Share.status_data` show it as `id: none` (`status_lines`) and `"id":null` (`status_data`, Q217).
	absent : {} -> Doc
	absent = |_none| fresh("none")

	## R-SH13, R-TF1: the text to write, as `TalonFile.render` makes it (one line, no spaces, one line end): `format`, `id`, `sent`, `counted`, `first`, `first_sent_at`,
	## `last_sent_at`, `token`, `token_expires_at`, `account`, then `extra`. For `fresh("<32 hex>")`:
	## `{"format":1,"id":"<32 hex>","sent":0,"counted":0,"first":0,"first_sent_at":null,"last_sent_at":null,"token":null,"token_expires_at":null,"account":null}`
	text : Doc -> Str
	text = |doc| {
		time = |value| match value {
			Ok(t) => JsonDoc.Text(t)
			Err(Unset) => JsonDoc.Null
		}
		account = match doc.account {
			Ok(a) => JsonDoc.Obj([("id", num(a.id)), ("login", JsonDoc.Text(a.login))])
			Err(Unset) => JsonDoc.Null
		}
		known = [
			("id", JsonDoc.Text(doc.id)),
			("sent", num(doc.sent)),
			("counted", num(doc.counted)),
			("first", num(doc.first)),
			("first_sent_at", time(doc.first_sent_at)),
			("last_sent_at", time(doc.last_sent_at)),
			("token", time(doc.token)),
			("token_expires_at", time(doc.token_expires_at)),
			("account", account),
		]
		TalonFile.render({ format: ShareJson.format, fields: known.concat(doc.extra) })
	}

	## R-TF1, R-TF2, R-TF3, R-TF6: reads the text of the file. `TalonFile.open` with `can_recreate` false: a `format` above `ShareJson.format` is a failure of kind `Input` (exit 19) with the
	## text of R-TF3, and text that is not a JSON object with an integer `format` is a failure of kind `Input`: `<path>: the content does not parse` (R-TF6: the id cannot be made again).
	## A member of the table above that is missing or has the wrong form (a total that is not a whole number of 0 or more, an `id` that is not 32 lower-case hex digits, a time or
	## `token` that is not text or `null`, an `account` that is not `null` or an object with the whole number `id` and the text `login`) gives the same failure as text that does not parse.
	read : { path : Str, text : Str } -> Try(Doc, Fail)
	read = |facts| {
		garbage = Fail.new(Input, "${facts.path}: the content does not parse")
		fields = match TalonFile.open({ path: facts.path, text: facts.text, newest: ShareJson.format, can_recreate: Bool.False })? {
			Use(used) => used.fields
			_ => return Err(garbage)
		}
		member = |name| fields.find_first(|(key, _)| key == name).map_ok(|(_, value)| value)
		total = |name| match member(name) {
			Ok(Num(n)) if n >= 0 => Ok(n.to_u64_wrap())
			_ => Err(garbage)
		}
		time = |name| match member(name) {
			Ok(Text(t)) => Ok(Ok(t))
			Ok(Null) => Ok(Err(Unset))
			_ => Err(garbage)
		}
		id = match member("id") {
			Ok(Text(t)) if is_id(t) => t
			_ => return Err(garbage)
		}
		account = match member("account") {
			Ok(Null) => Err(Unset)
			Ok(Obj(pairs)) => match (pairs.find_first(|(k, _)| k == "id"), pairs.find_first(|(k, _)| k == "login")) {
				(Ok((_, Num(n))), Ok((_, Text(login)))) if n >= 0 => Ok({ id: n.to_u64_wrap(), login })
				_ => return Err(garbage)
			}
			_ => return Err(garbage)
		}
		Ok({
			id,
			sent: total("sent")?,
			counted: total("counted")?,
			first: total("first")?,
			first_sent_at: time("first_sent_at")?,
			last_sent_at: time("last_sent_at")?,
			token: time("token")?,
			token_expires_at: time("token_expires_at")?,
			account,
			extra: fields.keep_if(|(key, _)| !known_members.contains(key)),
		})
	}
}

known_members : List(Str)
known_members = ["id", "sent", "counted", "first", "first_sent_at", "last_sent_at", "token", "token_expires_at", "account"]

num : U64 -> JsonDoc
num = |n| JsonDoc.Num(n.to_i64_wrap())

# R-SH5: 32 lower-case hex digits.
is_id : Str -> Bool
is_id = |text| {
	bytes = text.to_utf8()
	bytes.len() == 32 and bytes.all(|b| (b >= 48 and b <= 57) or (b >= 97 and b <= 102))
}

# 16 lower-case hex digits, leading zeros kept. Digit 0 is the most significant.
hex16 : U64 -> Str
hex16 = |n| {
	digit = |i| {
		d = (n // (16.U64).pow(15 - i)) % 16
		if d < 10 48 + d.to_u8_wrap() else 87 + d.to_u8_wrap()
	}
	Str.from_utf8_lossy(U64.to(0, 15).iter().map(digit).collect())
}
