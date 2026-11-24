import records.Tlog
import ed25519.Ed25519

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
}
