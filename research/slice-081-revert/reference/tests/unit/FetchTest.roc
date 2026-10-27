import lib.Fetch
import lib.Roots

FetchTest :: [].{}

roots : Roots
roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/c/cfg/talon", data: "/c/data/talon" }

hash = "9LY5pVf1tPH1sGnyVhEC45z3R7SZc3MApWRN8QvUat17"

gh_url = "https://github.com/acme/json/releases/download/2.1.0/${hash}.tar.zst"

loop_url = "http://127.0.0.1:41234/pkg/greet-1.0.0/${hash}.tar.zst"

plan_of : Str -> Fetch.Plan
plan_of = |url| match Fetch.plan({ roots, url, hex: "0123456789abcdef" }) {
	Ok(p) => p
	Err(_) => { url: "", hash: "", what: "", item: "", temp: "", archive: "", extracted: "" }
}

# R-FE2 R-FE3 R-DA4 R-FE8 R-EV25: the plan of one URL. The item is `<pkgs>/<hash>`. The temp dir is `<pkgs>/<hash>.<16hex>.tmp`, in the packages dir, with
# the archive and the dir that `roc unbundle` makes in it. The name in a message is `<owner>/<repo> <version>` for GitHub and the URL form
# with the version for another host (Q7). A loopback URL is accepted. A URL that roc does not accept is refused before anything else
# (a usage failure, Q6, Q8).
expect {
	temp = "/c/roc/packages/${hash}.0123456789abcdef.tmp"
	view = |r| match r {
		Ok(p) => Ok(p)
		Err(fail) => Err((fail.kind.code(), fail.message))
	}
	rows = [
		(
			"a GitHub release",
			gh_url,
			Ok({ url: gh_url, hash, what: "acme/json 2.1.0", item: "/c/roc/packages/${hash}", temp, archive: "${temp}/${hash}.tar.zst", extracted: "${temp}/${hash}" }),
		),
		(
			"a loopback URL (R-EV25)",
			loop_url,
			Ok({ url: loop_url, hash, what: "127.0.0.1:41234/pkg/greet-1.0.0", item: "/c/roc/packages/${hash}", temp, archive: "${temp}/${hash}.tar.zst", extracted: "${temp}/${hash}" }),
		),
		(
			"http to another host",
			"http://10.0.0.1/pkg/1.0.0/${hash}.tar.zst",
			Err((2, "http://10.0.0.1/pkg/1.0.0/${hash}.tar.zst: a package URL must be https://, or http:// to 127.0.0.1, [::1] or localhost")),
		),
		# R-SE18 R-ID5 R-H4 R-DI1 (slice 076): a hash that is not a safe path part is no hash, so the URL is no release URL (exit 2): `<pkgs>/..` and `<pkgs>/.` are the cache dirs, not a package
		(
			"a hash that is ..",
			"https://github.com/acme/json/releases/download/2.1.0/...tar.zst",
			Err((2, "https://github.com/acme/json/releases/download/2.1.0/...tar.zst is not a package release URL")),
		),
		(
			"a hash that is .",
			"https://github.com/acme/json/releases/download/2.1.0/..tar.zst",
			Err((2, "https://github.com/acme/json/releases/download/2.1.0/..tar.zst is not a package release URL")),
		),
		(
			"a hash with a backslash",
			"https://github.com/acme/json/releases/download/2.1.0/a\\..\\b.tar.zst",
			Err((2, "https://github.com/acme/json/releases/download/2.1.0/a\\..\\b.tar.zst is not a package release URL")),
		),
		(
			"ftp",
			"ftp://example.com/pkg/1.0.0/${hash}.tar.zst",
			Err((2, "ftp://example.com/pkg/1.0.0/${hash}.tar.zst: a package URL must be https://, or http:// to 127.0.0.1, [::1] or localhost")),
		),
	]
	bad = rows.keep_if(|(_, url, want)| view(Fetch.plan({ roots, url, hex: "0123456789abcdef" })) != want).map(|(label, url, want)| (label, want, view(Fetch.plan({ roots, url, hex: "0123456789abcdef" }))))
	dbg bad
	bad == []
}

# R-DA7 R-FE6 R-FE10 R-FE2 R-HF12 R-FE7: the failures of the store. A 404 gives exit 15 and the text of the design (R-FE10, with the reason `Run tln audit to see why`:
# no release state in P0). An HTTP error with no status (wget) is also exit 15 (Q3). Another failure of the program names the last
# line of its stderr, or its exit code. A program that does not start is exit 18. `roc unbundle` that fails is exit 16. A missing package
# offline is exit 15 (Q9).
expect {
	plan = plan_of(gh_url)
	loop_plan = plan_of(loop_url)
	view = |fail| (fail.kind.code(), fail.message)
	conn = "curl: (7) Failed to connect to 127.0.0.1 port 1 after 0 ms: Could not connect to server"
	download_rows = [
		(
			"404",
			{ plan, program: Curl, ended: Exited(22), outcome: Http(Ok(404)), last_line: "curl: (22) The requested URL returned error: 404" },
			(15, "download of acme/json 2.1.0 failed: 404 (${gh_url}). Run tln audit to see why."),
		),
		(
			"410",
			{ plan, program: Curl, ended: Exited(22), outcome: Http(Ok(410)), last_line: "curl: (22) The requested URL returned error: 410" },
			(15, "download of acme/json 2.1.0 failed: 410 (${gh_url}). Run tln audit to see why."),
		),
		(
			"an HTTP error with no status",
			{ plan, program: Wget, ended: Exited(8), outcome: Http(Err(Unknown)), last_line: "" },
			(15, "download of acme/json 2.1.0 failed: HTTP error (${gh_url}). Run tln audit to see why."),
		),
		(
			"404 on another host",
			{ plan: loop_plan, program: Curl, ended: Exited(22), outcome: Http(Ok(404)), last_line: "x" },
			(15, "download of 127.0.0.1:41234/pkg/greet-1.0.0 failed: 404 (${loop_url}). Run tln audit to see why."),
		),
		(
			"another failure: the last line of the program",
			{ plan, program: Curl, ended: Exited(7), outcome: Failed, last_line: conn },
			(15, "download of acme/json 2.1.0 failed: ${conn} (${gh_url})"),
		),
		(
			"another failure: no last line, an exit code",
			{ plan, program: Wget, ended: Exited(4), outcome: Failed, last_line: "" },
			(15, "download of acme/json 2.1.0 failed: wget exited with code 4 (${gh_url})"),
		),
		(
			"killed",
			{ plan, program: Curl, ended: Signaled(9), outcome: Failed, last_line: "" },
			(15, "download of acme/json 2.1.0 failed: curl was stopped by signal 9 (${gh_url})"),
		),
		(
			"the program does not start",
			{ plan, program: Curl, ended: NotStarted("no such file"), outcome: Failed, last_line: "" },
			(18, "cannot run curl: no such file"),
		),
	]
	bad_download = download_rows.keep_if(|(_, facts, want)| view(Fetch.download_failed(facts)) != want).map(|(label, facts, want)| (label, want, view(Fetch.download_failed(facts))))
	dbg bad_download

	unbundle_rows = [
		(
			"hash mismatch",
			{ plan, ended: Exited(1), last_line: "Error: Hash mismatch" },
			(16, "roc unbundle rejected acme/json 2.1.0 (${gh_url}): Error: Hash mismatch"),
		),
		(
			"no last line",
			{ plan, ended: Exited(1), last_line: "" },
			(16, "roc unbundle rejected acme/json 2.1.0 (${gh_url}): exit code 1"),
		),
		("roc is not there", { plan, ended: NotStarted("no such file"), last_line: "" }, (18, "cannot run roc: no such file")),
	]
	bad_unbundle = unbundle_rows.keep_if(|(_, facts, want)| view(Fetch.unbundle_failed(facts)) != want).map(|(label, facts, want)| (label, want, view(Fetch.unbundle_failed(facts))))
	dbg bad_unbundle

	offline = view(Fetch.offline_missing(plan))
	dbg offline
	bad_download == [] and bad_unbundle == [] and offline == (15, "acme/json 2.1.0 is not in the package cache and --offline is set (${gh_url})")
}

# R-FE4 R-FE2 R-NS6 R-PB1 R-LB3 (slice 060, moved from `ProbecmdTest`, slice 037, with 9 new rows): `Fetch.unbundler`, the one choice of the compiler that runs `roc unbundle` for all fetches, as an id.
# The selected compiler when it is installed, else the newest installed nightly or release, else the `roc` on PATH (rank 7), else a required download. A `git-`, `link-` or `copy-` build is
# selected by name only (R-NS6): it is never the "newest". The program of the id is `Launch.program!` (the L2 case `fetch/fe-flow` run 16 reads a link).
expect {
	path = Ok({ id: "nightly-2026-10-14-38a3029", path: "/bin/roc" })
	three = ["nightly-2026-10-03-3d3d3d3", "nightly-2026-10-10-0e0e0e0", "nightly-2026-10-05-5f5f5f5"]
	view = |selected, installed, on_path| match Fetch.unbundler({ selected, installed, path: on_path }) {
		Ok(id) => id
		Err(NoCompiler) => "none"
	}
	rows = [
		("the selected compiler is installed (rule 1): not the newest", view("nightly-2026-10-03-3d3d3d3", three, path), "nightly-2026-10-03-3d3d3d3"),
		("the selected compiler is not installed: the newest installed (rule 2)", view("nightly-2026-10-02-2c2c2c2", three, path), "nightly-2026-10-10-0e0e0e0"),
		("no compiler is selected: the newest installed", view("", three, path), "nightly-2026-10-10-0e0e0e0"),
		("the selected compiler is the roc on PATH and is not installed: an installed one wins", view("nightly-2026-10-14-38a3029", three, path), "nightly-2026-10-10-0e0e0e0"),
		("the order is by the day of the tag, the other tag form too", view("", ["nightly-2026-10-10-0e0e0e0", "nightly-2026-October-13-91fa0c2", "nightly-2026-10-12-1a1a1a1"], path), "nightly-2026-October-13-91fa0c2"),
		("nothing installed: the roc on PATH (rule 3)", view("nightly-2026-10-14-38a3029", [], path), "nightly-2026-10-14-38a3029"),
		("nothing installed and no roc on PATH: a required download (rule 4)", view("nightly-2026-10-14-38a3029", [], Err(NoCompiler)), "none"),
		("the selected id is installed and is also the one on PATH", view("nightly-2026-10-14-38a3029", ["nightly-2026-10-14-38a3029"], path), "nightly-2026-10-14-38a3029"),
		("one installed compiler", view("", ["nightly-2026-10-03-3d3d3d3"], Err(NoCompiler)), "nightly-2026-10-03-3d3d3d3"),
		("two nightlies of one day: the tag text decides", view("", ["nightly-2026-10-10-aaaaaaa", "nightly-2026-10-10-bbbbbbb"], path), "nightly-2026-10-10-bbbbbbb"),
		("a release with no time is older than a nightly (it has no day)", view("", ["0.2.0", "nightly-2026-10-03-3d3d3d3"], path), "nightly-2026-10-03-3d3d3d3"),
		("two releases with no time: the version decides", view("", ["0.10.0", "0.9.0"], path), "0.10.0"),
		("a named build is selected by name (R-NS6)", view("git-dev", ["git-dev", "nightly-2026-10-10-0e0e0e0"], path), "git-dev"),
		("a link is selected by name (its program is read by Launch.program!)", view("link-mine", ["link-mine", "nightly-2026-10-10-0e0e0e0"], path), "link-mine"),
		("a named build is not the newest, in any list order (R-NS6)", view("", ["link-mine", "nightly-2026-10-03-3d3d3d3", "git-dev", "copy-x"], path), "nightly-2026-10-03-3d3d3d3"),
		("only named builds installed: the roc on PATH (R-NS6)", view("", ["copy-x", "git-dev", "link-mine"], path), "nightly-2026-10-14-38a3029"),
		("only named builds installed and no roc on PATH: a required download (R-NS6)", view("", ["git-dev"], Err(NoCompiler)), "none"),
		("a selected id that only looks like a named build and is not installed: the newest", view("git-other", ["git-dev", "nightly-2026-10-03-3d3d3d3"], path), "nightly-2026-10-03-3d3d3d3"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}

# R-FE4 R-SO6 (slice 060, question Q1 (a)): `Fetch.selected`, the compiler that a fetch calls "selected". The held compiler of a flow with a decision wins over the `default-roc` of `config.toml`.
# A flow with no decision gives the default (when it knows it), else no compiler (`""`). The held compiler is not checked here: it can be a compiler that is not installed (the choice then goes on to the newest).
expect {
	rows = [
		("a held compiler wins over the default", Fetch.selected({ held: "nightly-2026-10-03-3d3d3d3", default: "nightly-2026-10-10-0e0e0e0" }), "nightly-2026-10-03-3d3d3d3"),
		("no decision: the default", Fetch.selected({ held: "", default: "nightly-2026-10-10-0e0e0e0" }), "nightly-2026-10-10-0e0e0e0"),
		("a held compiler and no default", Fetch.selected({ held: "nightly-2026-10-03-3d3d3d3", default: "" }), "nightly-2026-10-03-3d3d3d3"),
		("a held named build wins", Fetch.selected({ held: "git-dev", default: "nightly-2026-10-10-0e0e0e0" }), "git-dev"),
		("a default that is a link", Fetch.selected({ held: "", default: "link-mine" }), "link-mine"),
		("nothing: no selected compiler", Fetch.selected({ held: "", default: "" }), ""),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
