import Fail

## The download adapter, pure part (CLI 7.5, R-DA1 to R-DA7, R-HF4): which program, its command line, the meaning of its
## exit, and the check of a package URL (CLI 7.1, R-FE8). The children are run by `Fx.spawn_all!`.
Download :: [].{

	## The program of a download.
	Program : [Curl, Wget]

	## How a child ended (the result of `Fx.spawn_all!`).
	Ended : [Exited(I32), Signaled(I32), NotStarted(Str)]

	## The program of a run (R-DA2). `want` is `Settings.downloader` of `Net`. `curl` and `wget` tell which programs are on `PATH`
	## (`Fx.programs!`).
	##
	## | `want` | Result |
	## | --- | --- |
	## | `Auto` | `Curl` when `curl` is on `PATH`, else `Wget` when `wget` is. With none: a failure of kind `Environment` (exit 18), `no download program: curl and wget are not on PATH`. |
	## | `Curl`, `Wget` | That program when it is on `PATH`. Else a failure of kind `Environment`, `TALON_DOWNLOADER=<name>: <name> is not on PATH` (R-EV12). Talon does not fall back to the other program. |
	## | `Bad(text)` | A failure of kind `Usage` (exit 2), `TALON_DOWNLOADER must be curl or wget, not '<text>'` (question Q4). |
	choose : { want : [Auto, Curl, Wget, Bad(Str)], curl : Bool, wget : Bool } -> Try(Program, Fail)
	choose = |facts| match facts.want {
		Bad(text) => Err(Fail.new(Usage, "TALON_DOWNLOADER must be curl or wget, not '${text}'"))
		Curl => if facts.curl Ok(Curl) else Err(missing("curl"))
		Wget => if facts.wget Ok(Wget) else Err(missing("wget"))
		Auto => if facts.curl {
			Ok(Curl)
		} else if facts.wget {
			Ok(Wget)
		} else {
			Err(Fail.new(Environment, "no download program: curl and wget are not on PATH"))
		}
	}

	## The command line of one download (R-DA3), as the program name and its arguments, with no quoting. `dest` is the temp
	## file (R-DA4). There is no header and no token (R-DA3, R-DI9).
	##
	## | Program | Command line |
	## | --- | --- |
	## | `Curl` | `curl --fail --location --silent --show-error --proto =https,http --proto-redir =https --retry 2 --connect-timeout 30 --output <dest> <url>` |
	## | `Wget` | `wget --quiet --tries=3 --timeout=30 --output-document=<dest> <url>` |
	command : { program : Program, url : Str, dest : Str } -> List(Str)
	command = |facts| match facts.program {
		Curl => [
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
			facts.dest,
			facts.url,
		]
		Wget => ["wget", "--quiet", "--tries=3", "--timeout=30", "--output-document=${facts.dest}", facts.url]
	}

	## The meaning of the end of a download child (R-DA7). `last_line` is the last line of its stderr.
	##
	## | Ended | Result |
	## | --- | --- |
	## | `Exited(0)` | `Done` |
	## | `Curl`, `Exited(22)` | `Http(status)`: an HTTP error answer. The status is the number at the end of `last_line` after `error: ` (`curl: (22) The requested URL returned error: 404`), else `Err(Unknown)`. |
	## | `Wget`, `Exited(8)` | `Http(Err(Unknown))`: `wget --quiet` prints no status (question Q3). |
	## | Any other | `Failed` |
	outcome : { program : Program, ended : Ended, last_line : Str } -> [Done, Http(Try(U16, [Unknown])), Failed]
	outcome = |facts| match (facts.program, facts.ended) {
		(_, Exited(0)) => Done
		(Curl, Exited(22)) => Http(curl_status(facts.last_line))
		(Wget, Exited(8)) => Http(Err(Unknown))
		_ => Failed
	}

	## The check of a package URL before a download (CLI 7.1, R-FE8): `https://` to any host, and `http://` only to the
	## loopback hosts `127.0.0.1`, `[::1]` and `localhost` (the host is the text between `//` and the next `/`, `?` or `#`, with
	## no user info and no port). Any other URL (another scheme, `http://` to another host, a host that only starts like a
	## loopback host) is a failure of kind `Usage` (exit 2, question Q6): `<url>: a package URL must be https://, or http:// to 127.0.0.1, [::1] or localhost`.
	check_url : Str -> Try({}, Fail)
	check_url = |url| {
		refused = Err(Fail.new(Usage, "${url}: a package URL must be https://, or http:// to 127.0.0.1, [::1] or localhost"))
		if url.starts_with("https://") {
			Ok({})
		} else if url.starts_with("http://") and is_loopback(host_port(url.drop_prefix("http://"))) {
			Ok({})
		} else {
			refused
		}
	}
}

missing : Str -> Fail
missing = |name| Fail.new(Environment, "TALON_DOWNLOADER=${name}: ${name} is not on PATH")

# The status at the end of `curl: (22) The requested URL returned error: 404`.
curl_status : Str -> Try(U16, [Unknown])
curl_status = |line| match line.split_last("error: ") {
	Ok(parts) => U16.from_str(parts.after).map_err(|_| Unknown)
	Err(NotFound) => Err(Unknown)
}

# The text before the first `/`, `?` or `#`.
host_port : Str -> Str
host_port = |rest| match rest.to_utf8().find_first_index(|b| b == 47 or b == 63 or b == 35) {
	Ok(end) => Str.from_utf8_lossy(rest.to_utf8().take_first(end))
	Err(NotFound) => rest
}

# A loopback host, with no user info and an optional port of digits.
is_loopback : Str -> Bool
is_loopback = |text| ["127.0.0.1", "[::1]", "localhost"].any(
	|host| text == host or (
		text.starts_with("${host}:") and {
			port = text.drop_prefix("${host}:").to_utf8()
			!port.is_empty() and port.all(|b| b >= 48 and b <= 57)
		}
	),
)
