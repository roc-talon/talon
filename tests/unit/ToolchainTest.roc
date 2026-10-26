import lib.Args
import lib.Clock
import lib.Consent
import lib.Fail
import lib.JsonDoc
import lib.Nightlies
import lib.Pin
import lib.Prompt
import lib.Roots
import lib.Toolchain

ToolchainTest :: [].{}

# The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts and `data` fields that the design does not give are the proposals of docs/slices/021-roc-install.md (TW24).

sha_a = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

sha_b = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"

roots : Roots
roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/f/talon", data: "/d/talon" }

# One release of the list. `at` is `published_at` in seconds.
rel : { id : Str, at : U64, asset : Try(Nightlies.Asset, [NoAsset, Several(U64)]) } -> Nightlies.Release
rel = |r| { id: r.id, published_at: r.at, asset: r.asset }

one_asset : Str -> Nightlies.Asset
one_asset = |id| { name: "roc_nightly-linux_x86_64-${id}.tar.gz", url: "http://127.0.0.1:1/dl/${id}", size: 454, sha256: Ok(sha_a) }

# R-CV8: the host of a system. Any other system is a failure of kind `Environment` (exit 18).
expect {
	rows = [
		({ os: Linux, arch: X64 }, Ok(LinuxX64)),
		({ os: Linux, arch: Arm64 }, Ok(LinuxArm64)),
		({ os: Macos, arch: Arm64 }, Ok(MacosApple)),
		({ os: Macos, arch: X64 }, Ok(MacosX64)),
		({ os: Windows, arch: X64 }, Ok(WindowsX64)),
		({ os: Windows, arch: Arm64 }, Ok(WindowsArm64)),
		({ os: Other("freebsd"), arch: X64 }, Err(Fail.new(Environment, "no compiler asset exists for freebsd x64"))),
		({ os: Linux, arch: Other("riscv64") }, Err(Fail.new(Environment, "no compiler asset exists for linux riscv64"))),
		({ os: Windows, arch: Other("x86") }, Err(Fail.new(Environment, "no compiler asset exists for windows x86"))),
		({ os: Macos, arch: Arm64 }, Ok(MacosApple)),
	]
	bad = rows.keep_if(|(p, want)| Toolchain.host(p) != want).map(|(p, want)| (p, want, Toolchain.host(p)))
	dbg bad
	bad == [] and Toolchain.host({ os: Other("freebsd"), arch: X64 }).map_err(|f| f.kind.code()) == Err(18)
}

# R-CM15, R-R8, R-CM19: the operand of `tln roc install`: one text, as typed. No operand and 2 or more are usage failures (exit 2).
expect {
	read = |words| match Args.parse(words) {
		Ok(args) => Toolchain.read(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	rows = [
		(["roc", "install", "nightly-2026-10-09-258ab27"], Ok("nightly-2026-10-09-258ab27")),
		(["roc", "i", "@latest", "--yes"], Ok("@latest")),
		(["roc", "add", "nightly-2026-10", "--json", "--quiet"], Ok("nightly-2026-10")),
		(["roc", "install"], Err(Fail.new(Usage, "tln roc install needs one compiler: a full id, a prefix or @latest"))),
		(["roc", "install", "--yes"], Err(Fail.new(Usage, "tln roc install needs one compiler: a full id, a prefix or @latest"))),
		(["roc", "install", "a", "b"], Err(Fail.new(Usage, "tln roc install takes one compiler, got 2"))),
		(["roc", "install", "a", "b", "c"], Err(Fail.new(Usage, "tln roc install takes one compiler, got 3"))),
	]
	bad = rows.keep_if(|(words, want)| read(words) != want).map(|(words, want)| (words, want, read(words)))
	dbg bad
	bad == []
}

# R-SC10, R-SL5, R-NS4, R-C7, R-CV2: the 2 lists for `pick`. `named` is each candidate (one asset on the host), in the order of the list, with no limit of age (R-NS4).
# `auto` is the candidates that are at least `min_age` old (exactly the age is visible). A nightly with no asset or with 2 assets is in no list.
# Slice 022 (R-NS3, R-NS4, R-NS2): with the `nightly` switch off `auto` is empty (the domain is the releases only, and there is none), and `named` is the same (a name is not limited by the switch).
expect {
	now = 1_000_000
	day = 86400
	list = [
		rel({ id: "nightly-2026-10-09-258ab27", at: now - 9 * day, asset: Ok(one_asset("nightly-2026-10-09-258ab27")) }),
		rel({ id: "nightly-2026-10-10-abcdef0", at: now - 8 * day, asset: Err(NoAsset) }),
		rel({ id: "nightly-2026-10-11-1a2b3c4", at: now - 7 * day, asset: Err(Several(2)) }),
		rel({ id: "nightly-2026-10-12-2664a27", at: now - 2 * day, asset: Ok(one_asset("nightly-2026-10-12-2664a27")) }),
		rel({ id: "nightly-2026-10-13-91fa0c2", at: now - 2 * day + 1, asset: Ok(one_asset("nightly-2026-10-13-91fa0c2")) }),
		rel({ id: "nightly-2026-10-14-38a3029", at: now - 10, asset: Ok(one_asset("nightly-2026-10-14-38a3029")) }),
	]
	two_days = Toolchain.domain({ releases: list, now, min_age: 2 * day, nightly: Bool.True })
	none = Toolchain.domain({ releases: list, now, min_age: 0, nightly: Bool.True })
	empty = Toolchain.domain({ releases: [], now, min_age: 2 * day, nightly: Bool.True })
	off = Toolchain.domain({ releases: list, now, min_age: 0, nightly: Bool.False })
	all_named = ["nightly-2026-10-09-258ab27", "nightly-2026-10-12-2664a27", "nightly-2026-10-13-91fa0c2", "nightly-2026-10-14-38a3029"]
	dbg two_days
	dbg none
	two_days.named == all_named
		and two_days.auto == ["nightly-2026-10-09-258ab27", "nightly-2026-10-12-2664a27"]
			and none.named == all_named
				and none.auto == all_named
					and empty == { named: [], auto: [] }
						and off == { named: all_named, auto: [] }
}

# R-ST16, R-RU1, R-NS3, R-C7, R-SO14 (slice 072): `latest`, the compiler that `tln setup` writes as `default-roc` and that R-SO14 downloads outside a project: the newest release that the `nightly` switch and `min-release-age`
# allow. A release that is too new is hidden (exactly the age is visible). A release with no asset, or with 2 assets, for the host is no candidate (it cannot be installed). The order is the order of `Nightlies.candidates`
# (the list order: the oldest first, as `domain`), so the answer is the last visible id. No release, all too new, and the switch off: `Err(Empty)` (the caller says why: R-NS2).
expect {
	now = 1_000_000
	day = 86400
	list = [
		rel({ id: "nightly-2026-10-09-258ab27", at: now - 9 * day, asset: Ok(one_asset("nightly-2026-10-09-258ab27")) }),
		rel({ id: "nightly-2026-10-12-2664a27", at: now - 2 * day, asset: Ok(one_asset("nightly-2026-10-12-2664a27")) }),
		rel({ id: "nightly-2026-10-13-91fa0c2", at: now - 2 * day + 1, asset: Ok(one_asset("nightly-2026-10-13-91fa0c2")) }),
		rel({ id: "nightly-2026-10-14-38a3029", at: now - 10, asset: Err(NoAsset) }),
		rel({ id: "nightly-2026-10-15-38e6c42", at: now - 5, asset: Err(Several(2)) }),
	]
	young = [rel({ id: "nightly-2026-10-16-1df370f", at: now - 10, asset: Ok(one_asset("nightly-2026-10-16-1df370f")) })]
	latest = |releases, min_age, nightly| Toolchain.latest({ releases, now, min_age, nightly })
	two_days = latest(list, 2 * day, Bool.True)
	none = latest(list, 0, Bool.True)
	dbg two_days
	dbg none
	two_days == Ok("nightly-2026-10-12-2664a27")
		and none == Ok("nightly-2026-10-13-91fa0c2")
			and latest(list, 9 * day, Bool.True) == Ok("nightly-2026-10-09-258ab27")
				and latest(young, 2 * day, Bool.True) == Err(Empty)
					and latest([], 0, Bool.True) == Err(Empty)
						and latest(list, 0, Bool.False) == Err(Empty)
}

# R-CV2, R-SC10, R-NS2 (review of slice 021, Q6): why `pick` found no compiler. The exact id of a nightly that has no asset for the host names the host: `<id> has no asset for <target>` (kind `Usage`, exit 2).
# A prefix of that id, an id that is not in the list, an id with an asset, and every other error keep the text of `Nightlies.failure`.
# Slice 022 (Q5 of slice 020, R-NS2): `Empty` with the switch off names the switch and its source (exit 10). With the switch on it is the text of `Nightlies.failure`.
expect {
	list = [
		rel({ id: "nightly-2026-10-08-0badc0d", at: 100, asset: Err(NoAsset) }),
		rel({ id: "nightly-2026-10-09-258ab27", at: 200, asset: Ok(one_asset("nightly-2026-10-09-258ab27")) }),
	]
	failed = |host, error| Toolchain.pick_failed({ error, releases: list, host, switch: { nightly: Bool.True, source: Default } })
	off = |source| Toolchain.pick_failed({ error: Empty, releases: list, host: LinuxX64, switch: { nightly: Bool.False, source } })
	other_off = Toolchain.pick_failed({ error: NoMatch("nightly-2030"), releases: list, host: LinuxX64, switch: { nightly: Bool.False, source: Env } })
	exact = failed(LinuxX64, NoMatch("nightly-2026-10-08-0badc0d"))
	on_windows = failed(WindowsArm64, NoMatch("nightly-2026-10-08-0badc0d"))
	prefix = failed(LinuxX64, NoMatch("nightly-2026-10-08"))
	unknown = failed(LinuxX64, NoMatch("nightly-2030"))
	has_asset = failed(LinuxX64, NoMatch("nightly-2026-10-09-258ab27"))
	ambiguous = failed(LinuxX64, Ambiguous({ text: "nightly-2026-10", ids: ["nightly-2026-10-09-258ab27"] }))
	dbg exact
	dbg prefix
	exact == Fail.new(Usage, "nightly-2026-10-08-0badc0d has no asset for linux_x86_64")
		and exact.kind.code() == 2
			and on_windows == Fail.new(Usage, "nightly-2026-10-08-0badc0d has no asset for windows_arm64")
				and prefix == Fail.new(Usage, "no compiler matches nightly-2026-10-08")
					and unknown == Fail.new(Usage, "no compiler matches nightly-2030")
						and has_asset == Fail.new(Usage, "no compiler matches nightly-2026-10-09-258ab27")
							and ambiguous == Nightlies.failure(Ambiguous({ text: "nightly-2026-10", ids: ["nightly-2026-10-09-258ab27"] }))
								and failed(LinuxX64, Empty) == Nightlies.failure(Empty)
									and off(Env) == Fail.new(NoTuple, "no compiler release is known, and nightly is false (set by TALON_NIGHTLY)")
										and off(Config) == Fail.new(NoTuple, "no compiler release is known, and nightly is false (set by nightly in config.toml)")
											and off(Default) == Fail.new(NoTuple, "no compiler release is known, and nightly is false (set by the default)")
												and off(Env).kind.code() == 10
													and other_off == Fail.new(Usage, "no compiler matches nightly-2030")
}

# R-CC4 step 6, R-LY1, R-DA4, R-CC1, R-CC3: the paths of one install. The lock item is the install dir. The archive is in the temp dir. A Windows host has `roc.exe`.
expect {
	linux = Toolchain.plan({ roots, host: LinuxX64, id: "nightly-2026-10-09-258ab27", asset: "roc_nightly-linux_x86_64-2026-10-09-258ab27.tar.gz", hex: "0123456789abcdef" })
	windows = Toolchain.plan({ roots, host: WindowsArm64, id: "nightly-2026-10-09-258ab27", asset: "roc_nightly-windows_arm64-2026-10-09-258ab27.zip", hex: "00000000000000ff" })
	release = Toolchain.plan({ roots, host: MacosApple, id: "0.1.0", asset: "roc-0.1.0.tar.gz", hex: "0123456789abcdef" })
	dbg linux
	dbg windows
	linux == {
		id: "nightly-2026-10-09-258ab27",
		item: "/c/roc/toolchains/nightly-2026-10-09-258ab27",
		temp: "/c/roc/toolchains/nightly-2026-10-09-258ab27.0123456789abcdef.tmp",
		archive: "/c/roc/toolchains/nightly-2026-10-09-258ab27.0123456789abcdef.tmp/roc_nightly-linux_x86_64-2026-10-09-258ab27.tar.gz",
		roc: "/c/roc/toolchains/nightly-2026-10-09-258ab27.0123456789abcdef.tmp/roc",
		meta: "/c/roc/toolchains/nightly-2026-10-09-258ab27.0123456789abcdef.tmp/.talon.json",
		probe_dir: "/c/roc/talon/tmp/0123456789abcdef",
		probe_file: "/c/roc/talon/tmp/0123456789abcdef/empty.roc",
	}
		and windows.roc == "/c/roc/toolchains/nightly-2026-10-09-258ab27.00000000000000ff.tmp/roc.exe"
			and windows.meta == "/c/roc/toolchains/nightly-2026-10-09-258ab27.00000000000000ff.tmp/.talon.json"
				and windows.probe_file == "/c/roc/talon/tmp/00000000000000ff/empty.roc"
					and release.item == "/c/roc/toolchains/0.1.0"
						and release.roc == "/c/roc/toolchains/0.1.0.0123456789abcdef.tmp/roc"
}

# R-HF5, R-SE9, R-HF2: the command of `tar` (the same line for `.tar.gz` and `.zip`, with the top dir of the archive cut) and of `chmod` (none on Windows).
expect {
	tar = Toolchain.tar_command({ archive: "/t/a.tar.gz", dir: "/t" })
	zip = Toolchain.tar_command({ archive: "/t/a.zip", dir: "/t" })
	hosts = [LinuxX64, LinuxArm64, MacosApple, MacosX64, WindowsX64, WindowsArm64]
	chmod = hosts.map(|h| Toolchain.chmod_command({ host: h, file: "/t/roc" }))
	dbg chmod
	tar == ["tar", "-xf", "/t/a.tar.gz", "-C", "/t", "--strip-components=1"]
		and zip == ["tar", "-xf", "/t/a.zip", "-C", "/t", "--strip-components=1"]
			and chmod == [Ok(["chmod", "0755", "/t/roc"]), Ok(["chmod", "0755", "/t/roc"]), Ok(["chmod", "0755", "/t/roc"]), Ok(["chmod", "0755", "/t/roc"]), Err(NotNeeded), Err(NotNeeded)]
}

# R-CV4, R-SE11, R-DA7, R-SE9, R-HF5, R-DI12, R-HF12: the checks of the digest and the failures with their kinds (exit codes 16, 15, 18).
expect {
	id = "nightly-2026-10-09-258ab27"
	url = "http://h/a.tar.gz"
	asset = |digest| { name: "a.tar.gz", url, size: 1, sha256: digest }
	http = |program, status| Toolchain.download_failed({ id, url, program, ended: Exited(22), outcome: Http(status), last_line: "curl: (22) The requested URL returned error: 404" })
	failed = |program, ended, last| Toolchain.download_failed({ id, url, program, ended, outcome: Failed, last_line: last })
	rows = [
		# The digest before the download
		(Toolchain.require_digest({ id, asset: asset(Ok(sha_a)) }), Ok(sha_a)),
		(Toolchain.require_digest({ id, asset: asset(Err(None)) }), Err(Fail.new(Integrity, "the asset of ${id} has no sha256 digest. Talon does not install it."))),
		# The check of the file that the download wrote
		(Toolchain.check_download({ id, want: sha_a, got: sha_a }).map_ok(|_| "ok"), Ok("ok")),
		(Toolchain.check_download({ id, want: sha_a, got: sha_b }).map_ok(|_| "ok"), Err(Fail.new(Integrity, "sha256 of ${id} differs: expected ${sha_a}, got ${sha_b}. Talon deleted the download."))),
		# The download child (R-DA7)
		(Err(http(Curl, Ok(404))), Err(Fail.new(Network, "download of ${id} failed: 404 (${url})"))),
		(Err(http(Wget, Err(Unknown))), Err(Fail.new(Network, "download of ${id} failed: HTTP error (${url})"))),
		(Err(failed(Curl, Exited(6), "curl: (6) Could not resolve host: h")), Err(Fail.new(Network, "download of ${id} failed: curl: (6) Could not resolve host: h (${url})"))),
		(Err(failed(Wget, Exited(4), "")), Err(Fail.new(Network, "download of ${id} failed: wget exited with code 4 (${url})"))),
		(Err(failed(Curl, Signaled(9), "")), Err(Fail.new(Network, "download of ${id} failed: curl was stopped by signal 9 (${url})"))),
		(Err(failed(Wget, NotStarted("no such file"), "")), Err(Fail.new(Environment, "cannot run wget: no such file"))),
		# tar
		(Err(Toolchain.tar_failed({ id, url, ended: Exited(2), last_line: "tar: Member name contains '..'" })), Err(Fail.new(Integrity, "tar rejected ${id} (${url}): tar: Member name contains '..'"))),
		(Err(Toolchain.tar_failed({ id, url, ended: Exited(2), last_line: "" })), Err(Fail.new(Integrity, "tar rejected ${id} (${url}): tar exited with code 2"))),
		(Err(Toolchain.tar_failed({ id, url, ended: Signaled(11), last_line: "" })), Err(Fail.new(Integrity, "tar rejected ${id} (${url}): tar was stopped by signal 11"))),
		(Err(Toolchain.tar_failed({ id, url, ended: NotStarted("no such file"), last_line: "" })), Err(Fail.new(Environment, "cannot run tar: no such file"))),
		# --offline
		(Err(Toolchain.offline_missing(id)), Err(Fail.new(Network, "${id} is not installed and --offline is set"))),
		(Err(Toolchain.offline_no_list({})), Err(Fail.new(Network, "no cached list of compilers and --offline is set"))),
	]
	bad = rows.map_with_index(|(got, want), i| (i, got, want)).keep_if(|(_, got, want)| got != want)
	dbg bad
	codes = [
		Toolchain.require_digest({ id, asset: asset(Err(None)) }),
		Toolchain.check_download({ id, want: sha_a, got: sha_b }).map_ok(|_| ""),
		Err(http(Curl, Ok(404))),
		Err(failed(Curl, NotStarted("x"), "")),
		Err(Toolchain.tar_failed({ id, url, ended: Exited(2), last_line: "x" })),
		Err(Toolchain.offline_missing(id)),
	].map(
		|r| match r {
			Ok(_) => 0
			Err(f) => f.kind.code()
		},
	)
	dbg codes
	bad == [] and codes == [16, 16, 15, 18, 16, 15]
}

# R-GC10: the compat id is the dir of the build root that `roc check` of an empty file touched: a new `compat-` dir, or one with a later time.
expect {
	dir = |name, mtime| { name, is_dir: Bool.True, mtime }
	file = |name| { name, is_dir: Bool.False, mtime: 9 }
	base = [dir("toolchains", 5), dir("talon", 5), dir("compat-old", 5), file("compat-file")]
	rows = [
		# a new dir (the usual case: a first run of this compiler)
		({ before: base, after: base.concat([dir("compat-abc", 7)]) }, Ok("abc")),
		# no build root before: every dir is new
		({ before: [], after: [dir("compat-abc", 7)] }, Ok("abc")),
		# a dir that exists and has a later time (an entry was added to it)
		({ before: base, after: [dir("toolchains", 5), dir("talon", 5), dir("compat-old", 8), file("compat-file")] }, Ok("old")),
		# nothing touched: the same list, an older time, a file named compat-, a dir that is not a compat dir
		({ before: base, after: base }, Err(Unknown)),
		({ before: base, after: [dir("toolchains", 5), dir("talon", 5), dir("compat-old", 4), file("compat-file")] }, Err(Unknown)),
		({ before: base, after: base.concat([file("compat-new-file")]) }, Err(Unknown)),
		({ before: base, after: base.concat([dir("other", 9)]) }, Err(Unknown)),
		({ before: [], after: [] }, Err(Unknown)),
		# 2 or more: the names, in byte order (another process made one too)
		({ before: base, after: base.concat([dir("compat-b", 7), dir("compat-a", 7)]) }, Err(Several(["a", "b"]))),
		({ before: base, after: [dir("compat-old", 9), dir("compat-new", 9)] }, Err(Several(["new", "old"]))),
	]
	bad = rows.map_with_index(|(f, want), i| (i, Toolchain.learn_compat(f), want)).keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == []
}

# R-CV5, R-LY1, R-TF1, R-TF2: the text of `.talon.json`: one line, `format` first, then the fields in this order. A compat id that is not known is `null`.
# Slice 022 (Q5 of the review, R-NS1): the last key is `published_at`, the GitHub time of the release in the form of `installed_at`. `Compiler.times` reads it.
expect {
	base = { id: "nightly-2026-10-09-258ab27", url: "http://127.0.0.1:1/dl/a.tar.gz", sha256: sha_a, typed: "@latest", compat: Ok("c0ffee"), now: 1792670400, published_at: 1791558066 }
	ok = Toolchain.meta(base)
	unknown = Toolchain.meta({ ..base, compat: Err(Unknown) })
	several = Toolchain.meta({ ..base, compat: Err(Several(["a", "b"])) })
	quoted = Toolchain.meta({ ..base, typed: "a\"b" })
	dbg ok
	dbg unknown
	ok == "{\"format\":1,\"id\":\"nightly-2026-10-09-258ab27\",\"url\":\"http://127.0.0.1:1/dl/a.tar.gz\",\"sha256\":\"${sha_a}\",\"sha256_source\":\"github-digest\",\"typed\":\"@latest\",\"compat\":\"c0ffee\",\"installed_at\":\"2026-10-22T12:00:00Z\",\"published_at\":\"2026-10-09T15:01:06Z\"}\n"
		and unknown == ok.replace_each("\"compat\":\"c0ffee\"", "\"compat\":null")
			and several == unknown
				and quoted == ok.replace_each("\"typed\":\"@latest\"", "\"typed\":\"a\\\"b\"")
					and JsonDoc.parse(ok.trim()).is_ok()
}

# R-SO15, R-LY4, R-CC6, R-TF4: the edit of `config.toml` for the first default. The key in any form is "set": no write. Else one line, and every other byte stays.
# The line goes after the last top-level key, before the first table (a key after a table would be in the table).
expect {
	id = "nightly-2026-10-09-258ab27"
	line = "default-roc = \"${id}\"\n"
	edit = |text| Toolchain.default_edit({ path: "/f/talon/config.toml", text, id })
	rows = [
		("", Ok(Set(line))),
		("nightly = true", Ok(Set("nightly = true\n${line}"))),
		("# my settings\nmin-release-age = \"0d\"\n", Ok(Set("# my settings\nmin-release-age = \"0d\"\n${line}"))),
		("# c\nnightly = true\n\n[probe]\nmax = 1\n", Ok(Set("# c\nnightly = true\n${line}\n[probe]\nmax = 1\n"))),
		("[probe]\nmax = 1\n", Ok(Set("${line}\n[probe]\nmax = 1\n"))),
		("# default-roc = \"x\"\n", Ok(Set("# default-roc = \"x\"\n${line}"))),
		("[probe]\ndefault-roc = 1\n", Ok(Set("${line}\n[probe]\ndefault-roc = 1\n"))),
		("default-roc = \"nightly-2026-10-14-38a3029\"\n", Ok(Keep)),
		("\"default-roc\" = 'x' # mine\nnightly = true\n", Ok(Keep)),
		("nightly = true\ndefault-roc = \"\"\n", Ok(Keep)),
		("nightly = \n", Err(Fail.new(Input, "/f/talon/config.toml:1: not valid TOML"))),
	]
	bad = rows.map_with_index(|(text, want), i| (i, edit(text), want)).keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == [] and edit("nightly = \n").map_err(|f| f.kind.code()) == Err(19)
}

# R-DA6, R-NR2 (slice 028b, Q5: a GB step from 999 950 000 bytes, as the MB step starts at 999 950: 999.9 MB, 1.0 GB, 3.1 GB), R-NI6, R-DL1, R-DL3, R-DL4, R-NM4, R-NM6, R-CC4 step 2: the size for a person (slice 022, T17 of slice 021: the KB value is rounded to the nearest tenth, not cut: 1550 is `1.6 KB`), and the prompt "download the compiler that the command names".
# It is a Default prompt: no flag, `--yes` and non-interactive mode give Yes (the command is the consent); the interactive default is Yes; No stops with exit 13.
expect {
	sizes = [(0, "0 B"), (999, "999 B"), (1000, "1.0 KB"), (1500, "1.5 KB"), (1549, "1.5 KB"), (1550, "1.6 KB"), (1951, "2.0 KB"), (999_949, "999.9 KB"), (1_500_000, "1.5 MB"), (73_861_067, "73.9 MB"), (60_149_999, "60.1 MB"), (999_949_999, "999.9 MB"), (999_950_000, "1.0 GB"), (1_000_000_000, "1.0 GB"), (3_100_000_000, "3.1 GB"), (3_149_999_999, "3.1 GB"), (3_150_000_000, "3.2 GB")]
	bad_sizes = sizes.keep_if(|(n, want)| Toolchain.size_text(n) != want).map(|(n, want)| (n, want, Toolchain.size_text(n)))
	dbg bad_sizes
	p = Consent.roc_install({ id: "nightly-2026-10-09-258ab27", size: 73_861_067 })
	decide = |mode, yes| Prompt.decide(p, { mode, yes, flag: Err(NoFlag) })
	declined = Consent.roc_install_declined("nightly-2026-10-09-258ab27")
	dbg p.question
	bad_sizes == []
		and p.id == "roc-install"
			and p.kind == Default
				and p.shape == YesNo
					and p.default == Yes
						and p.question == "Download 1 compiler, 73.9 MB: nightly-2026-10-09-258ab27?"
							and p.subject == "the download of nightly-2026-10-09-258ab27"
								and (p.answer_line)(Yes) == "downloading nightly-2026-10-09-258ab27 (73.9 MB)"
									and (p.answer_line)(No) == "no download of nightly-2026-10-09-258ab27"
										and Prompt.text(p) == "Download 1 compiler, 73.9 MB: nightly-2026-10-09-258ab27? [Y/n] "
											and Prompt.reply(p, "") == Ok(Yes)
												and Prompt.reply(p, "n") == Ok(No)
													and decide(NonInteractive, Bool.False) == Use(Yes)
														and decide(NonInteractive, Bool.True) == Use(Yes)
															and decide(Interactive, Bool.False) == Ask
																and decide(NeedsTty, Bool.False) == NeedTty
																	and declined == Fail.new(Consent, "nightly-2026-10-09-258ab27 is not installed. Nothing was downloaded.")
																		and declined.kind.code() == 13
}

# R-OUT2, R-J3, R-J4, R-FL4, R-SO15, R-GC10: the text and the `data` of a finished run. The compat warning is only for a new install.
expect {
	id = "nightly-2026-10-09-258ab27"
	rep = |how, default, compat| Toolchain.report({ id, how, default, compat })
	item = "/c/roc/toolchains/${id}"
	installed_set = rep(Installed, Set, Ok("c0ffee"))
	installed_kept = rep(Installed, Kept, Ok("c0ffee"))
	present = rep(Present, Kept, Err(Unknown))
	none = rep(Installed, Kept, Err(Unknown))
	many = rep(Installed, Set, Err(Several(["a", "b"])))
	data = |how, default| Toolchain.data({ id, item, how, default }).render()
	dbg many
	installed_set == { stdout: ["installed ${id}\n", "${id} is now the default compiler\n"], stderr: [] }
		and installed_kept == { stdout: ["installed ${id}\n"], stderr: [] }
			and present == { stdout: ["${id} is already installed\n"], stderr: [] }
				and none == { stdout: ["installed ${id}\n"], stderr: ["warning: the compat id of ${id} is not known: roc check touched no compat dir\n"] }
					and many == { stdout: ["installed ${id}\n", "${id} is now the default compiler\n"], stderr: ["warning: the compat id of ${id} is not known: roc check touched 2 compat dirs (a, b)\n"] }
						and data(Installed, Set) == "{\"id\":\"${id}\",\"path\":\"${item}\",\"installed\":true,\"default\":true}"
							and data(Installed, Kept) == "{\"id\":\"${id}\",\"path\":\"${item}\",\"installed\":true,\"default\":false}"
								and data(Present, Kept) == "{\"id\":\"${id}\",\"path\":\"${item}\",\"installed\":false,\"default\":false}"
}

# R-SO13, R-NS1, R-NS2, R-NS3, R-NS7, R-C7 (slice 025b): the compiler that rank 4 downloads when no installed compiler is in the range. It is the newest release of the list that the range, the `nightly` switch,
# `min-release-age` and the snapshot allow. The rows: the age (exactly 2 days is visible), the snapshot (a time equal to `published_at` is visible), the 3 range forms, the other tag form of an id (the id of the list is the result),
# a release with no asset for the host, the switch off (releases only), the order of 2 nightlies of one day (R-NS1: `published_at`, not the sha), and a release against a nightly of the same day.
expect {
	now = 1_000_000
	day = 86400
	hour = 3600
	ids = ["nightly-2026-10-18-5349569", "nightly-2026-10-17-601b54c", "nightly-2026-10-16-1df370f", "nightly-2026-10-15-38e6c42", "nightly-2026-10-14-38a3029", "nightly-2026-10-13-91fa0c2"]
	list = [
		rel({ id: "nightly-2026-10-18-5349569", at: now - hour, asset: Ok(one_asset("nightly-2026-10-18-5349569")) }),
		rel({ id: "nightly-2026-10-17-601b54c", at: now - 2 * day + 1, asset: Ok(one_asset("nightly-2026-10-17-601b54c")) }),
		rel({ id: "nightly-2026-10-16-1df370f", at: now - 3 * day, asset: Ok(one_asset("nightly-2026-10-16-1df370f")) }),
		rel({ id: "nightly-2026-10-15-38e6c42", at: now - 4 * day, asset: Ok(one_asset("nightly-2026-10-15-38e6c42")) }),
		rel({ id: "nightly-2026-10-14-38a3029", at: now - 5 * day, asset: Err(NoAsset) }),
		rel({ id: "nightly-2026-10-13-91fa0c2", at: now - 6 * day, asset: Ok(one_asset("nightly-2026-10-13-91fa0c2")) }),
	]
	pick = |releases, req, min_age, snapshot, nightly| Toolchain.range_pick({ releases, req, now, min_age, snapshot, nightly })
	newest = ids.get(0) ?? ""
	third = ids.get(2) ?? ""
	fourth = ids.get(3) ?? ""
	sixth = ids.get(5) ?? ""
	# 2 nightlies of 2026-10-12: the sha of the later one sorts first.
	same_day = [
		rel({ id: "nightly-2026-10-12-aaaaaaa", at: now - 7 * day, asset: Ok(one_asset("nightly-2026-10-12-aaaaaaa")) }),
		rel({ id: "nightly-2026-10-12-0000001", at: now - 7 * day + 4 * hour, asset: Ok(one_asset("nightly-2026-10-12-0000001")) }),
	]
	# Releases and a nightly. The time of a release is its day (R-NS1), so these have real times.
	at = |text| Clock.parse_utc(text) ?? 0
	nightly_14 = rel({ id: "nightly-2026-10-14-38a3029", at: at("2026-10-14T15:00:00Z"), asset: Ok(one_asset("nightly-2026-10-14-38a3029")) })
	mixed = [
		nightly_14,
		rel({ id: "0.1.0", at: at("2026-10-02T12:00:00Z"), asset: Ok(one_asset("0.1.0")) }),
		rel({ id: "0.1.1", at: at("2026-10-09T12:00:00Z"), asset: Ok(one_asset("0.1.1")) }),
		rel({ id: "0.2.0", at: at("2026-10-20T12:00:00Z"), asset: Ok(one_asset("0.2.0")) }),
	]
	# A release of the day of the nightly, before it in the day and after it.
	early = [nightly_14, rel({ id: "0.1.1", at: at("2026-10-14T10:00:00Z"), asset: Ok(one_asset("0.1.1")) })]
	late = [nightly_14, rel({ id: "0.1.1", at: at("2026-10-14T20:00:00Z"), asset: Ok(one_asset("0.1.1")) })]
	rows = [
		("Any, 2 days: the 2 newest are too new", pick(list, Any, 2 * day, Err(None), Bool.True), Ok(third)),
		("Any, 0 days: the newest", pick(list, Any, 0, Err(None), Bool.True), Ok(newest)),
		("snapshot equal to the time of a release: visible, later ones hidden", pick(list, Any, 0, Ok(now - 4 * day), Bool.True), Ok(fourth)),
		("a lower bound that the newest meets", pick(list, AtLeast(sixth), 0, Err(None), Bool.True), Ok(newest)),
		("a lower bound after every release", pick(list, AtLeast("nightly-2026-10-30-abcdef0"), 0, Err(None), Bool.True), Err(NoneKnown)),
		("a lower bound that only too new releases meet", pick(list, AtLeast("nightly-2026-10-17-0000000"), 2 * day, Err(None), Bool.True), Err(NoneKnown)),
		("exact, the other tag form: the id of the list", pick(list, Exactly("nightly-2026-October-15-38e6c42"), 0, Err(None), Bool.True), Ok(fourth)),
		("exact, a release with no asset for the host is no candidate", pick(list, Exactly("nightly-2026-10-14-38a3029"), 0, Err(None), Bool.True), Err(NoneKnown)),
		("the switch is off and the list has nightlies only", pick(list, Any, 0, Err(None), Bool.False), Err(NoneKnown)),
		("an empty list", pick([], Any, 0, Err(None), Bool.True), Err(NoneKnown)),
		("a semver range takes releases only", pick(list, Semver("0.1.*"), 0, Err(None), Bool.True), Err(NoneKnown)),
		("a semver range: not the newer series", pick(mixed, Semver("0.1.*"), 0, Err(None), Bool.True), Ok("0.1.1")),
		("2 nightlies of one day: published_at, not the sha (R-NS1)", pick(same_day, Any, 0, Err(None), Bool.True), Ok("nightly-2026-10-12-0000001")),
		("a release is newer than a nightly of its day, early in the day (R-NS1)", pick(early, Any, 0, Err(None), Bool.True), Ok("0.1.1")),
		("a release is newer than a nightly of its day, late in the day (R-NS1)", pick(late, Any, 0, Err(None), Bool.True), Ok("0.1.1")),
		("Any: the newest release of all", pick(mixed, Any, 0, Err(None), Bool.True), Ok("0.2.0")),
		("the switch is off: the newest release", pick(mixed, Any, 0, Err(None), Bool.False), Ok("0.2.0")),
		("the switch is off: no nightly even when it is the newest", pick(early, Any, 0, Err(None), Bool.False), Ok("0.1.1")),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(name, got, want)| (name, got, want))
	dbg bad
	bad == []
}

# R-SO13, R-NS2, R-EC10 (slice 025b): the failure when the list has no compiler for the range. Kind `NoTuple` (exit 10), as R-NS2 gives for a compiler that the switch does not admit. With the switch off the text names the
# switch and its source (R-NS2). The texts are a proposal (TW24).
expect {
	on = Toolchain.range_failed({ req_text: ">=nightly-2026-10-09-258ab27", switch: { nightly: Bool.True, source: Default } })
	off = |source| Toolchain.range_failed({ req_text: "*", switch: { nightly: Bool.False, source } })
	on == Fail.new(NoTuple, "no compiler release is in [toolchain] roc (>=nightly-2026-10-09-258ab27)")
		and on.kind.code() == 10
			and off(Env) == Fail.new(NoTuple, "no compiler release is in [toolchain] roc (*), and nightly is false (set by TALON_NIGHTLY)")
				and off(Toml) == Fail.new(NoTuple, "no compiler release is in [toolchain] roc (*), and nightly is false (set by [toolchain] nightly in talon.toml)")
					and off(Config) == Fail.new(NoTuple, "no compiler release is in [toolchain] roc (*), and nightly is false (set by nightly in config.toml)")
}

# R-SL7, R-PD16 (slice 026): only a relative step needs the base (the compiler that Resolution 13 selects for `main.roc` of the current directory): one `@`, a sign and decimal digits. Every other form needs no base, so a command that is given one makes no call to find it. A step with no `@` is a prefix text (`Nightlies.pick`).
expect {
	rows = [
		("@-1", Bool.True),
		("@+2", Bool.True),
		("@-10", Bool.True),
		("-1", Bool.False),
		("+1", Bool.False),
		("@latest", Bool.False),
		("@nightly-2026-10-09-258ab27", Bool.False),
		("nightly-2026-10-09-258ab27", Bool.False),
		("nightly-2026-10", Bool.False),
		("@1.2.3", Bool.False),
		("@-x", Bool.False),
		("@-", Bool.False),
		("@", Bool.False),
		("", Bool.False),
	]
	bad = rows.keep_if(|(text, want)| Toolchain.needs_base(text) != want).map(|(text, want)| (text, want))
	dbg bad
	bad == []
}
