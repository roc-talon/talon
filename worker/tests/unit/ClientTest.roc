import lib.Client
import lib.Route

ClientTest :: [].{}

# W0 tests of worker/lib/Client.roc (slice 116b). The design answers are Design Q168, Q182 to Q186, R-AP45, R-AP68, R-CT11 (docs/slices/116b-hint-limits.md section 12).

agent : Str -> Try(Str, [NotFound])
agent = |text| Ok(text)

# The `minimum` of a refusal, or "ok" for an accepted request.
verdict : { user_agent : Try(Str, [NotFound]), write : Bool, min : Str, min_write : Str } -> Str
verdict = |x| match Client.check(x) {
	Ok({}) => "ok"
	Err({ problem, minimum }) => "${problem.http_status().to_str()} ${minimum}"
}

# R-AP45, R-AP48 row 3: the check of `User-Agent: tln/<v>`. `MIN_TLN_WRITE` covers the write routes (`write` True), `MIN_TLN` all routes. Versions compare as numbers (`tln/0.10.0` is above `0.5.0`),
# an equal version is good, a pre-release is below its release. A refusal is 400 `unsupported-client` and gives the setting that refused; with both settings the larger one.
expect {
	v = |ua, write, min, min_write| verdict({ user_agent: agent(ua), write, min, min_write })
	v("tln/0.4.1", Bool.True, "", "0.5.0") == "400 0.5.0"
		and v("tln/0.4.1", Bool.False, "", "0.5.0") == "ok"
		and v("tln/0.4.1", Bool.False, "0.5.0", "") == "400 0.5.0"
		and v("tln/0.4.1", Bool.True, "0.5.0", "") == "400 0.5.0"
		and v("tln/0.10.0", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("tln/0.5.0", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("tln/0.5.0-rc.1", Bool.True, "", "0.5.0") == "400 0.5.0"
		and v("tln/0.9.9", Bool.True, "", "0.10.0") == "400 0.10.0"
		and v("tln/0.4.1", Bool.True, "0.6.0", "0.5.0") == "400 0.6.0"
		and v("tln/0.4.1", Bool.True, "0.3.0", "0.5.0") == "400 0.5.0"
		and v("tln/0.5.5", Bool.True, "0.6.0", "0.5.0") == "400 0.6.0"
		and v("tln/0.4.1", Bool.True, "", "") == "ok"
		and v("tln/0.4.1", Bool.True, "banana", "") == "ok"
		and v("tln/banana", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("tln/", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("tln", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("tln/0.4.1 (linux)", Bool.True, "", "0.5.0") == "400 0.5.0"
		and v("tln/0.4.1 curl/8", Bool.False, "0.5.0", "") == "400 0.5.0"
		and v("tln/0.5.0 (linux)", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("curl/8 tln/0.4.1", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("tln/dev", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("TLN/0.4.1", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v(" tln/0.4.1", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("curl/8.4.0", Bool.True, "0.5.0", "0.5.0") == "ok"
		and v("Mozilla/5.0 (X11; Linux x86_64)", Bool.True, "9.0.0", "9.0.0") == "ok"
		and v("", Bool.True, "9.0.0", "9.0.0") == "ok"
		and verdict({ user_agent: Err(NotFound), write: Bool.True, min: "9.0.0", min_write: "9.0.0" }) == "ok"
}

# R-AP45: the `detail` names the version of the client and the minimum. R-AP21: the body has the members of the problem and `minimum`. The write routes of R-AP41 are `PostCompat`, `PostRelease`, `PutToolchain`;
# every read, and the closure query (a read that uses `POST`), is not.
expect {
	refused = Client.check({ user_agent: Ok("tln/0.4.1"), write: Bool.True, min: "", min_write: "0.5.0" })
	body = match refused {
		Err(r) => Client.refusal_json(r)
		Ok(_) => ""
	}
	detail_ok = match refused {
		Err(r) => r.problem.to_json().contains("0.4.1") and r.problem.to_json().contains("0.5.0")
		Ok(_) => Bool.False
	}
	detail_ok
		and body.contains("\"type\":\"/errors/unsupported-client\"")
		and body.contains("\"status\":400")
		and body.contains("\"minimum\":\"0.5.0\"")
		and body.contains("\"detail\":")
		and Client.is_write(PostCompat)
		and Client.is_write(PostRelease)
		and Client.is_write(PutToolchain("nightly-2026-10-29-aaaaaaa"))
		and !Client.is_write(PostClosure)
		and !Client.is_write(GetToolchains)
		and !Client.is_write(GetReleases)
		and !Client.is_write(GetPackages)
		and !Client.is_write(GetSweep("nightly-2026-10-29-aaaaaaa"))
		and !Client.is_write(GetCompatHints)
		and !Client.is_write(GetArtifact("x"))
		and !Client.is_write(GetArtifactCompat("x"))
		and !Client.is_write(GetRepoReleases("o", "r"))
}

# R-CT11, R-AP68 row 3 (Design Q168, Q185): the key of the rate limit, the one function of the hint and the ingest path. IPv4: the text. IPv6: the first 4 groups in lower case hex with no leading zero, then `::/64`; `::` is read; two addresses in one /64 have one key. An IPv4-mapped IPv6 address is the IPv4
# address. A missing or unreadable address is `unknown` (R-CT11, Design Q185).
expect {
	k = |ip| Client.rate_key(Ok(ip))
	k("1.2.3.4") == "1.2.3.4"
		and k("203.0.113.77") == "203.0.113.77"
		and k("2001:DB8::1") == "2001:db8:0:0::/64"
		and k("2001:db8:0:0:1:2:3:4") == "2001:db8:0:0::/64"
		and k("2001:db8::ffff:1:2") == "2001:db8:0:0::/64"
		and k("2001:0db8:0000:0000:ffff:ffff:ffff:ffff") == "2001:db8:0:0::/64"
		and k("2001:db8:0:1::1") == "2001:db8:0:1::/64"
		and k("2001:0db8:85a3:0000:0000:8a2e:0370:7334") == "2001:db8:85a3:0::/64"
		and k("::1") == "0:0:0:0::/64"
		and k("::") == "0:0:0:0::/64"
		and k("1::") == "1:0:0:0::/64"
		and k("::ffff:1.2.3.4") == "1.2.3.4"
		and k("::FFFF:203.0.113.77") == "203.0.113.77"
		and k("2001:db8:0:2::1") != k("2001:db8:0:1::1")
		and k("1.2.3.5") != k("1.2.3.4")
		and Client.rate_key(Err(NotFound)) == "unknown"
		and k("") == "unknown"
		and k("not an ip") == "unknown"
		and k("1.2.3") == "unknown"
		and k("1.2.3.256") == "unknown"
		and k("2001:db8::1::2") == "unknown"
		and k("2001:db8:0:0:1:2:3:4:5") == "unknown"
		and k("gggg::1") == "unknown"
}

# R-CT11, R-AP25: the 429 of the rate limit: kind `rate-limited`, and a `Retry-After` of the period of the binding, 60 seconds (R-CT11, Design Q168, Q185).
expect {
	Client.rate_problem().http_status() == 429
		and Client.rate_problem().to_json().contains("/errors/rate-limited")
		and Client.limit_retry_after == 60
}
