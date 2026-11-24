import records.Tlog
import ed25519.Ed25519
import Fail
import JsonDoc

## The log verifier key (CLI slice 261b, DESIGN-CLI 7.6 R-LV4, R-LV5; Registry R-SG4). Pure. The key of a registry and the setting are slice 261c.
## The key text is the verifier key of golang.org/x/mod/sumdb/note: `<name>+<key id>+<base64 key data>`. Tests: `tests/unit/LogkeyTest.roc`.
LogKey :: [].{

	## A verifier key: the key name (the origin of the log), the 4-byte key id, the 32-byte Ed25519 public key.
	VerifierKey : { name : Str, key_id : List(U8), public_key : List(U8) }

	## R-LV5: the verifier key text `<name>+<key id>+<key data>` (the rules of `NewVerifier` of golang.org/x/mod/sumdb/note):
	## the name not empty, with no space and no `+`; the key id 8 hex digits (lower or upper case); the key data standard base64 (it can hold `+`) of 33 bytes:
	## the type 0x01 (Ed25519), then the 32-byte public key; the key id equal to `records.Tlog.key_id(name, public key)`;
	## and the public key a point (`Ed25519.is_valid_public_key` of roc-ed25519, slice 261 section 12.4). Else `Err(BadKey)`.
	parse_verifier_key : Str -> Try(LogKey.VerifierKey, [BadKey])
	parse_verifier_key = |text| {
		# The verifier key text has the form of the signer key text after `PRIVATE+KEY+` (R-WH14): the same name, key id and 33-byte key data rules.
		parts = Tlog.parse_signer_key("PRIVATE+KEY+${text}")?
		public_key = parts.seed
		if parts.key_id != Tlog.key_id(parts.name, public_key) {
			Err(BadKey)
		} else if !Ed25519.is_valid_public_key(public_key) {
			Err(BadKey)
		} else {
			Ok({ name: parts.name, key_id: parts.key_id, public_key: public_key })
		}
	}

	## R-LV5, Design Q636 (15): the built-in key: the public line of `secrets/log-key-verifier` (F3 of slice 261). It applies to `https://registry.roc-talon.org` only.
	builtin_text : Str
	builtin_text = "registry.roc-talon.org/log+e5942107+AcChrF9eGpi29YDCTnBoS8Jd3xEVR1To+6RRg3korCQy"

	## Slice 261c (R-LV5): where the key of a check came from. `Config(path)` is `log-key` of the `config.toml` at `path`.
	Source : [BuiltIn, Env, Config(Str)]

	## Slice 261c (R-LV5, R-EV30, R-LY4, slice 261 13.7 N1): the key of the registry with the base URL `base` (R-RG7 form, for example `http://127.0.0.1:9`).
	## The set key is `env` (`TALON_LOG_KEY`) when it is set, else `config` (`log-key` of `config.toml`, with its path and line); only that one text is read (R-LY4, as Design Q439).
	## The text is trimmed of the white space around it before `parse_verifier_key` (N1). A set key applies when its name is `<authority>/log` of `base` (`<host>[:<port>]`);
	## else the built-in key applies when its name is `<authority>/log` (a set key with the name of the built-in key replaces it). No key: `Ok(Err(NoKey))` (no check, no note).
	## A bad set text is a failure even when it would not apply: `env` gives kind `Usage` (exit 2, T8b), `config` gives kind `Input` (exit 19, T8), each with the trimmed text,
	## and `error.details` `{"log":"<base>/log","reason":"bad-key","size":null,"index":null,"release":null}` (R-LV11, CLI 3 catalog).
	choose : { base : Str, env : Try(Str, [Unset]), config : Try({ text : Str, path : Str, line : U64 }, [Unset]) } -> Try(Try({ key : LogKey.VerifierKey, source : LogKey.Source }, [NoKey]), Fail)
	choose = |setting| {
		wanted = "${setting.base.drop_prefix("https://").drop_prefix("http://")}/log"
		builtin_parsed = LogKey.parse_verifier_key(LogKey.builtin_text).map_err(|_| NoKey)
		builtin = if (builtin_parsed.map_ok(|parsed| parsed.name) == Ok(wanted)) builtin_parsed.map_ok(|parsed| { key: parsed, source: BuiltIn }) else Err(NoKey)
		# Q261c-1: `log-key` is not read when `TALON_LOG_KEY` is set.
		set = match setting.env {
			Ok(text) => Ok({ text: text.trim(), source: Env, label: "TALON_LOG_KEY", kind: Usage })
			Err(Unset) => match setting.config {
				Ok(found) => Ok({ text: found.text.trim(), source: Config(found.path), label: "${found.path}: line ${found.line.to_str()}: log-key", kind: Input })
				Err(Unset) => Err(Unset)
			}
		}
		match set {
			Err(Unset) => Ok(builtin)
			Ok(chosen) => match LogKey.parse_verifier_key(chosen.text) {
				Err(BadKey) => {
					message = "${chosen.label}: '${chosen.text}' is not a log verifier key (the form is <name>+<8 hex digits>+<base64 key>)"
					Err({ ..Fail.new(chosen.kind, message), details: Ok(LogKey.details({ base: setting.base, reason: "bad-key", size: Err(None), index: Err(None), release: Err(None) })) })
				}
				Ok(parsed) => if (parsed.name == wanted) Ok(Ok({ key: parsed, source: chosen.source })) else Ok(builtin)
			}
		}
	}

	## The `error.details` of a failure of the log check (R-LV11): `{"log":"<base>/log","reason":...,"size":...,"index":...,"release":...}`. A member that the text does not name is `null`.
	details : { base : Str, reason : Str, size : Try(U64, [None]), index : Try(U64, [None]), release : Try(Str, [None]) } -> JsonDoc
	details = |facts| {
		number = |n| match n {
			Ok(v) => JsonDoc.Num(v.to_i64_wrap())
			Err(None) => JsonDoc.Null
		}
		JsonDoc.Obj([
			("log", JsonDoc.Text("${facts.base}/log")),
			("reason", JsonDoc.Text(facts.reason)),
			("size", number(facts.size)),
			("index", number(facts.index)),
			(
				"release",
				match facts.release {
					Ok(url) => JsonDoc.Text(url)
					Err(None) => JsonDoc.Null
				},
			),
		])
	}
}
