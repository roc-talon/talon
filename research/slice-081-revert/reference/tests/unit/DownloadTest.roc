import lib.Download

DownloadTest :: [].{}

# R-DA2 R-EV12 R-HF12: the download program. `curl` when it is on PATH, else `wget`. `TALON_DOWNLOADER` picks one: it must be on PATH and
# there is no fallback to the other. With none: exit 18 (environment). A value that is not `curl` or `wget` is a usage failure (Q4).
expect {
	view = |r| match r {
		Ok(program) => Ok(program)
		Err(fail) => Err((fail.kind.code(), fail.message))
	}
	rows = [
		("auto, both", { want: Auto, curl: Bool.True, wget: Bool.True }, Ok(Curl)),
		("auto, wget only", { want: Auto, curl: Bool.False, wget: Bool.True }, Ok(Wget)),
		("auto, curl only", { want: Auto, curl: Bool.True, wget: Bool.False }, Ok(Curl)),
		("auto, none", { want: Auto, curl: Bool.False, wget: Bool.False }, Err((18, "no download program: curl and wget are not on PATH"))),
		("curl wanted", { want: Curl, curl: Bool.True, wget: Bool.True }, Ok(Curl)),
		("wget wanted, both there", { want: Wget, curl: Bool.True, wget: Bool.True }, Ok(Wget)),
		("wget wanted, missing: no fallback", { want: Wget, curl: Bool.True, wget: Bool.False }, Err((18, "TALON_DOWNLOADER=wget: wget is not on PATH"))),
		("curl wanted, missing: no fallback", { want: Curl, curl: Bool.False, wget: Bool.True }, Err((18, "TALON_DOWNLOADER=curl: curl is not on PATH"))),
		("another program", { want: Bad("fetch"), curl: Bool.True, wget: Bool.True }, Err((2, "TALON_DOWNLOADER must be curl or wget, not 'fetch'"))),
	]
	bad = rows.keep_if(|(_, facts, want)| view(Download.choose(facts)) != want).map(|(label, facts, want)| (label, want, view(Download.choose(facts))))
	dbg bad
	bad == []
}

# R-DA3 R-DA4 R-DI9: the command lines, as written in the design: no header, no token. The `--proto-redir =https` of curl stops a
# redirect to http://. The output is the temp file.
expect {
	url = "https://github.com/acme/json/releases/download/2.1.0/9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17.tar.zst"
	dest = "/c/roc/packages/9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17.0123456789abcdef.tmp/9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17.tar.zst"
	curl = [
		"curl",
		"--fail",
		"--location",
		"--silent",
		"--show-error",
		"--proto",
		"=https,http",
		"--proto-redir",
		"=https",
		"--retry",
		"2",
		"--connect-timeout",
		"30",
		"--output",
		dest,
		url,
	]
	wget = ["wget", "--quiet", "--tries=3", "--timeout=30", "--output-document=${dest}", url]
	Download.command({ program: Curl, url, dest }) == curl and Download.command({ program: Wget, url, dest }) == wget
}

# R-DA7 R-FE6: the meaning of the end of a download. An HTTP error answer is curl exit 22 and wget exit 8. curl names the status in its last
# stderr line. `wget --quiet` prints no status (Q3). Everything else is a failure.
expect {
	curl_404 = "curl: (22) The requested URL returned error: 404"
	rows = [
		("curl done", { program: Curl, ended: Exited(0), last_line: "" }, Done),
		("wget done", { program: Wget, ended: Exited(0), last_line: "" }, Done),
		("curl 404", { program: Curl, ended: Exited(22), last_line: curl_404 }, Http(Ok(404))),
		("curl 503", { program: Curl, ended: Exited(22), last_line: "curl: (22) The requested URL returned error: 503" }, Http(Ok(503))),
		("curl 22, no text", { program: Curl, ended: Exited(22), last_line: "" }, Http(Err(Unknown))),
		("curl 22, text with no number", { program: Curl, ended: Exited(22), last_line: "curl: (22) The requested URL returned error: abc" }, Http(Err(Unknown))),
		("wget 8", { program: Wget, ended: Exited(8), last_line: "" }, Http(Err(Unknown))),
		("curl uses 22, not 8", { program: Curl, ended: Exited(8), last_line: "" }, Failed),
		("wget uses 8, not 22", { program: Wget, ended: Exited(22), last_line: "" }, Failed),
		("curl: connection refused", { program: Curl, ended: Exited(7), last_line: "curl: (7) Failed to connect to 127.0.0.1 port 1" }, Failed),
		("wget: network failure", { program: Wget, ended: Exited(4), last_line: "" }, Failed),
		("killed", { program: Curl, ended: Signaled(9), last_line: "" }, Failed),
		("not started", { program: Wget, ended: NotStarted("not found"), last_line: "" }, Failed),
	]
	bad = rows.keep_if(|(_, facts, want)| Download.outcome(facts) != want).map(|(label, facts, want)| (label, want, Download.outcome(facts)))
	dbg bad
	bad == []
}

# R-FE8: the URLs that Talon accepts are the URLs that roc accepts: `https://` to any host, and `http://` only to a loopback host. The host is
# the text before the next `/`, `?` or `#`, after the user info. A host that only starts like a loopback host is not one. Another scheme is
# refused. The failure is a usage failure (Q6).
expect {
	good = [
		"https://example.com/p/1.0.0/H.tar.zst",
		"https://github.com/acme/json/releases/download/2.1.0/H.tar.zst",
		"https://10.0.0.1/p/1.0.0/H.tar.zst",
		"http://127.0.0.1/p/1.0.0/H.tar.zst",
		"http://127.0.0.1:41234/p/1.0.0/H.tar.zst",
		"http://localhost/p/1.0.0/H.tar.zst",
		"http://localhost:8080/p/1.0.0/H.tar.zst",
		"http://[::1]/p/1.0.0/H.tar.zst",
		"http://[::1]:8080/p/1.0.0/H.tar.zst",
	]
	refused = [
		"http://example.com/p/1.0.0/H.tar.zst",
		"http://github.com/acme/json/releases/download/2.1.0/H.tar.zst",
		"http://10.0.0.1/p/1.0.0/H.tar.zst",
		"http://127.0.0.1.example.com/p/1.0.0/H.tar.zst",
		"http://localhost.example.com/p/1.0.0/H.tar.zst",
		"http://127.0.0.1@example.com/p/1.0.0/H.tar.zst",
		"http://127.0.0.2/p/1.0.0/H.tar.zst",
		"ftp://example.com/p/1.0.0/H.tar.zst",
		"file:///tmp/p/1.0.0/H.tar.zst",
		"../util/main.roc",
		"example.com/p/1.0.0/H.tar.zst",
	]
	bad_good = good.keep_if(|url| Download.check_url(url) != Ok({}))
	bad_refused = refused.keep_if(
		|url| match Download.check_url(url) {
			Err(fail) => fail.kind.code() != 2
			Ok(_) => Bool.True
		},
	)
	message = match Download.check_url("http://example.com/p/1.0.0/H.tar.zst") {
		Err(fail) => fail.message
		Ok(_) => ""
	}
	dbg bad_good
	dbg bad_refused
	bad_good == [] and bad_refused == [] and message == "http://example.com/p/1.0.0/H.tar.zst: a package URL must be https://, or http:// to 127.0.0.1, [::1] or localhost"
}
