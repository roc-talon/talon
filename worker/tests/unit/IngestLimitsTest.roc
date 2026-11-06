import lib.IngestLimits

IngestLimitsTest :: [].{}

# W0 tests of worker/lib/IngestLimits.roc (slice 112b, docs/slices/112b-ingest-limits.md section 3).
# The times were computed with python (datetime), not with the Roc code: 1767225600000 is 2026-01-01T00:00:00Z, 1767312000000 is 2026-01-02T00:00:00Z.

# The rate key (R-AP68 "Rate key", Design Q168) is `Client.rate_key`: its W0 tests are in ClientTest.roc (slice 116b, Design Q185).

# ---- R-AP68 row 5, "Owner count" (Design Q167) ----

# The owner text and its byte range (`/` 0x2F to `0` 0x30, so `acme-x` and `acme2` are out of the range of `acme`).
expect {
	(IngestLimits.owner_of("acme/lib") == "acme")
		and (IngestLimits.owner_range("acme") == { lo: "acme/", hi: "acme0" })
		and (IngestLimits.day_start(1767225630000) == 1767225600000)
		and (IngestLimits.day_start(1767225600000) == 1767225600000)
		and (IngestLimits.day_start(1767225599999) == 1767139200000)
}

# The limit: 20 or more new names today and a new name is 429 with the seconds to the next 00:00 UTC, rounded up. A known name and 19 rows pass.
expect {
	c = |has_repo, count, now_ms| IngestLimits.owner_check({ owner: "acme", has_repo, count, now_ms })
	limited = |s| Err((IngestLimits.owner_limited("acme"), s))
	got = [
		c(Bool.False, 20, 1767225630000),
		c(Bool.False, 25, 1767225600000),
		c(Bool.False, 20, 1767311999999),
		c(Bool.False, 20, 1767311999000),
		c(Bool.False, 19, 1767225630000),
		c(Bool.True, 25, 1767225630000),
	]
	got == [limited(86370), limited(86400), limited(1), limited(1), Ok({}), Ok({})]
}

# The texts (R-AP68 "429 texts") and the constants.
expect {
	(IngestLimits.ip_retry_after == 60)
		and (IngestLimits.owner_limit == 20)
		and (IngestLimits.ip_binding == "RL_INGEST")
}

# ---- R-AP69 (Design Q166) ----

# The query value: each byte outside the unreserved set of RFC 3986 as %XX, upper-case hex; each byte of a UTF-8 character.
expect {
	got = [
		IngestLimits.query_value("github.com/acme/lib/releases/download/{v}/"),
		IngestLimits.query_value("a b~-._Z9"),
		IngestLimits.query_value("é?&=+%"),
		IngestLimits.query_value("0.2"),
		IngestLimits.query_value(""),
	]
	got == ["github.com%2Facme%2Flib%2Freleases%2Fdownload%2F%7Bv%7D%2F", "a%20b~-._Z9", "%C3%A9%3F%26%3D%2B%25", "0.2", ""]
}

# The 4 keys, in the order of the table; the packages key has the lower-case name.
expect {
	got = IngestLimits.drop_keys({ origin: "https://registry.example", group: "github.com/Acme/Lib/releases/download/v{v}/", series: "0.3", name: "acme/lib", hash: "4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi" })
	got
		== [
			"https://registry.example/v1/releases?group=github.com%2FAcme%2FLib%2Freleases%2Fdownload%2Fv%7Bv%7D%2F",
			"https://registry.example/v1/releases?group=github.com%2FAcme%2FLib%2Freleases%2Fdownload%2Fv%7Bv%7D%2F&series=0.3",
			"https://registry.example/v1/packages/acme/lib/releases",
			"https://registry.example/v1/artifacts/4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi",
		]
}
