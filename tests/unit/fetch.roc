app [main!] { lib: "../../cli/lib/main.roc" }

import lib.Fetch
import lib.Roots

main! = |_args| Ok({})

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
