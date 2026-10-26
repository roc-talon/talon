import lib.Clock
import lib.Consent
import lib.Fail
import lib.Gc
import lib.Nightlies
import lib.Prompt
import lib.Roots
import lib.Zig

ZigTest :: [].{}

# Slice 044 (docs/slices/044-zig.md). The expected value of each row is the design text or the slice file text, not the code. A wrong row prints with `dbg`.
# Texts and fields that the design does not give are the proposals of the slice file (TW24).

roots : Roots
roots = Roots.{ cache: "/c/roc", pkgs: "/c/roc/packages", build: "/c/roc", config: "/f/talon", data: "/d/talon" }

hosts : List(Nightlies.Host)
hosts = [LinuxX64, LinuxArm64, MacosX64, MacosApple, WindowsX64, WindowsArm64]

keys : List(Str)
keys = ["x86_64-linux", "aarch64-linux", "x86_64-macos", "aarch64-macos", "x86_64-windows", "aarch64-windows"]

# The sha256, the size and the URL that the fake index gives for one target. Each target has its own values, so a wrong key shows.
sha_of : Str -> Str
sha_of = |key| match key {
	"x86_64-linux" => "1".repeat(64)
	"aarch64-linux" => "2".repeat(64)
	"x86_64-macos" => "3".repeat(64)
	"aarch64-macos" => "4".repeat(64)
	"x86_64-windows" => "5".repeat(64)
	_ => "6".repeat(64)
}

size_of : Str -> U64
size_of = |key| match key {
	"x86_64-linux" => 54_227_812
	"aarch64-linux" => 50_100_000
	"x86_64-macos" => 52_300_000
	"aarch64-macos" => 48_000_001
	"x86_64-windows" => 79_000_000
	_ => 74_999_999
}

archive_of : Str, Str -> Str
archive_of = |version, key| if key.ends_with("windows") "zig-${key}-${version}.zip" else "zig-${key}-${version}.tar.xz"

url_of : Str, Str -> Str
url_of = |version, key| "https://ziglang.org/download/${version}/${archive_of(version, key)}"

target_json : Str, Str -> Str
target_json = |version, key| "\"${key}\": { \"tarball\": \"${url_of(version, key)}\", \"shasum\": \"${sha_of(key)}\", \"size\": \"${size_of(key).to_str()}\" }"

# One release of the index, as ziglang.org writes it: a date, the docs, the source archive and one object for each target.
release_json : Str, List(Str) -> Str
release_json = |version, have| {
	src = "\"src\": { \"tarball\": \"https://ziglang.org/download/${version}/zig-${version}.tar.xz\", \"shasum\": \"${"f".repeat(64)}\", \"size\": \"17000000\" }"
	"\"${version}\": { \"date\": \"2026-09-01\", \"docs\": \"https://ziglang.org/documentation/${version}/\", ${src}, ${Str.join_with(have.map(|key| target_json(version, key)), ", ")} }"
}

# The master entry has a `version` field and the objects of its targets. Its x86_64-linux archive is not the one of a release.
master_json : Str -> Str
master_json = |version| "\"master\": { \"version\": \"${version}\", \"date\": \"2026-10-20\", \"x86_64-linux\": { \"tarball\": \"https://ziglang.org/builds/zig-x86_64-linux-${version}.tar.xz\", \"shasum\": \"${"9".repeat(64)}\", \"size\": \"1\" } }"

index : List(Str) -> Str
index = |parts| "{\n${Str.join_with(parts, ",\n")}\n}\n"

full_index : Str
full_index = index([master_json("0.18.0-dev.5+abcdef"), release_json("0.17.0", keys), release_json("0.16.2", keys), release_json("0.15.1", keys)])

entry_of : Str, Str -> Zig.Entry
entry_of = |version, key| { version, url: url_of(version, key), sha256: sha_of(key), size: size_of(key), archive: archive_of(version, key) }

# R-EV11, R-EV16, R-EV21: `ZIG` names the Zig of a source build. `TALON_ZIG_INDEX` replaces the URL of the index. The names are exact.
expect {
	env = [("HOME", "/h"), ("ZIG", "/opt/zig/zig")]
	moved = [("TALON_ZIG_INDEX", "http://127.0.0.1:8080/zig/index.json"), ("HOME", "/h")]
	dbg Zig.index_url(moved)
	Zig.env_zig(env) == Ok("/opt/zig/zig")
		and Zig.env_zig([("HOME", "/h")]) == Err(NotSet)
			and Zig.env_zig([("ZIG_HOME", "/x"), ("zig", "/y")]) == Err(NotSet)
				and Zig.index_url(env) == "https://ziglang.org/download/index.json"
					and Zig.index_url([]) == "https://ziglang.org/download/index.json"
						and Zig.index_url(moved) == "http://127.0.0.1:8080/zig/index.json"
							and Zig.index_url([("TALON_ZIG_INDEXX", "http://x/")]) == "https://ziglang.org/download/index.json"
}

# R-D4: the Zig version of a commit is `minimum_zig_version` of `build.zig.zon`. A comment line is not read. The series is the `major.minor`.
expect {
	zon = |lines| Str.join_with(lines, "\n")
	real = zon([".{", "    .name = .roc,", "    .version = \"0.0.0\",", "    // .minimum_zig_version = \"0.1.0\",", "    .fingerprint = 0x1234567890abcdef,", "    .minimum_zig_version = \"0.15.2\",", "    .dependencies = .{", "        .roc_bootstrap = .{ .url = \"https://example.com/x.tar.gz\" },", "    },", "}", ""])
	tight = zon([".{", "\t.minimum_zig_version=\"0.17.0-dev.31+abc\",", "}"])
	two = zon([".{", "    .minimum_zig_version = \"0.17.0\",", "    .minimum_zig_version = \"0.99.0\",", "}"])
	only_comment = zon([".{", "    // .minimum_zig_version = \"0.1.0\",", "    .version = \"0.0.0\",", "}"])
	series_rows = [
		("0.17.0", Ok({ major: 0, minor: 17 })),
		("0.17.9", Ok({ major: 0, minor: 17 })),
		("0.17.0-dev.31+abc", Ok({ major: 0, minor: 17 })),
		("1.2.3", Ok({ major: 1, minor: 2 })),
		("", Err(BadVersion)),
		("0", Err(BadVersion)),
		("a.b.c", Err(BadVersion)),
		("0.x.1", Err(BadVersion)),
	]
	bad = series_rows.keep_if(|(text, want)| Zig.series(text) != want).map(|(text, want)| (text, want, Zig.series(text)))
	dbg bad
	bad == []
		and Zig.minimum(real) == Ok("0.15.2")
			and Zig.minimum(tight) == Ok("0.17.0-dev.31+abc")
				and Zig.minimum(two) == Ok("0.17.0")
					and Zig.minimum(only_comment) == Err(NoKey)
						and Zig.minimum("") == Err(NoKey)
							and Zig.wanted("0.17.0") == "0.17.x"
								and Zig.wanted("0.17.0-dev.31+abc") == "0.17.x"
									and Zig.wanted("0.9.1") == "0.9.x"
										and Zig.wanted("master") == "master"
}

# R-D1: the search order is `$ZIG`, then `zig` on `PATH` with a matching version, then a Zig that Talon installed. A version matches with the same major and minor (R-D4). The order does not depend on the order of the list.
# `$ZIG` is used as it is: the version is not checked (R-D1 says "a matching version" only for `PATH`; review of the manager, Q1). A `$ZIG` that does not run is a failure (kind Environment) that names `ZIG`.
# Of 2 or more fitting installed dirs the newest version wins, in the order of the numbers and not of the text (review of the manager, Q2).
# R-D3: `Missing` has the reason of the `[ ]` line.
expect {
	c = |source, path, version| { source, path, version }
	env = |v| c(Env, "/opt/zig/zig", Ok(v))
	path = |v| c(Path, "zig", Ok(v))
	inst = |v| c(Installed, "/c/roc/toolchains/zig-${v}/zig", Ok(v))
	found = |source, at, v| Found({ source, path: at, version: v })
	env_failed = |at| Failed(Fail.new(Environment, "ZIG is set to ${at}, but \"${at} version\" did not run"))
	rows : List({ need : Str, list : List(Zig.Candidate), want : Zig.Search })
	rows = [
		{ need: "0.17.0", list: [], want: Missing("zig not found") },
		{ need: "0.17.0", list: [path("0.16.0")], want: Missing("found zig 0.16.0 on PATH") },
		{ need: "0.17.0", list: [path("0.17.2")], want: found(Path, "zig", "0.17.2") },
		{ need: "0.17.2", list: [path("0.17.0")], want: found(Path, "zig", "0.17.0") },
		{ need: "0.17.0", list: [inst("0.17.0"), path("0.17.2"), env("0.17.1")], want: found(Env, "/opt/zig/zig", "0.17.1") },
		{ need: "0.17.0", list: [inst("0.17.0"), path("0.17.2")], want: found(Path, "zig", "0.17.2") },
		{ need: "0.17.0", list: [env("0.16.0")], want: found(Env, "/opt/zig/zig", "0.16.0") },
		{ need: "0.17.0", list: [path("0.17.2"), env("0.18.3"), inst("0.17.0")], want: found(Env, "/opt/zig/zig", "0.18.3") },
		{ need: "0.17.0", list: [env("0.17.1")], want: found(Env, "/opt/zig/zig", "0.17.1") },
		{ need: "0.17.0", list: [inst("0.17.0"), env("1.0.0")], want: found(Env, "/opt/zig/zig", "1.0.0") },
		{ need: "0.17.0", list: [c(Env, "/opt/zig/zig", Err(Unknown)), path("0.17.2"), inst("0.17.0")], want: env_failed("/opt/zig/zig") },
		{ need: "0.17.0", list: [path("0.17.2"), c(Env, "/bin/zig-x", Err(Unknown))], want: env_failed("/bin/zig-x") },
		{ need: "0.17.0", list: [c(Env, "/opt/zig/zig", Err(Unknown))], want: env_failed("/opt/zig/zig") },
		{ need: "0.17.0", list: [inst("0.17.9"), inst("0.17.10")], want: found(Installed, "/c/roc/toolchains/zig-0.17.10/zig", "0.17.10") },
		{ need: "0.17.0", list: [inst("0.17.10"), inst("0.17.9")], want: found(Installed, "/c/roc/toolchains/zig-0.17.10/zig", "0.17.10") },
		{ need: "0.17.0", list: [inst("0.17.2"), inst("0.17.0"), inst("0.17.1")], want: found(Installed, "/c/roc/toolchains/zig-0.17.2/zig", "0.17.2") },
		{ need: "0.17.0", list: [inst("0.16.9"), inst("0.17.1"), inst("0.18.0")], want: found(Installed, "/c/roc/toolchains/zig-0.17.1/zig", "0.17.1") },
		{ need: "0.17.0", list: [inst("0.17.1"), c(Installed, "/c/roc/toolchains/zig-0.17.9/zig", Err(Unknown))], want: found(Installed, "/c/roc/toolchains/zig-0.17.1/zig", "0.17.1") },
		{ need: "0.17.0", list: [path("0.16.0"), inst("0.17.0")], want: found(Installed, "/c/roc/toolchains/zig-0.17.0/zig", "0.17.0") },
		{ need: "0.17.0", list: [c(Path, "zig", Err(Unknown)), inst("0.17.0")], want: found(Installed, "/c/roc/toolchains/zig-0.17.0/zig", "0.17.0") },
		{ need: "0.17.0", list: [c(Path, "zig", Err(Unknown))], want: Missing("found zig on PATH, its version is not known") },
		{ need: "0.17.0", list: [inst("0.16.0")], want: Missing("found zig 0.16.0 installed by Talon") },
		{ need: "0.17.0", list: [inst("0.15.0"), path("0.16.0")], want: Missing("found zig 0.16.0 on PATH") },
		{ need: "0.17.0", list: [inst("0.15.0"), inst("0.16.0")], want: Missing("found zig 0.15.0 installed by Talon") },
		{ need: "0.17.0", list: [inst("0.16.0"), inst("0.15.0")], want: Missing("found zig 0.16.0 installed by Talon") },
		{ need: "0.17.0", list: [c(Path, "zig", Err(Unknown)), path("0.16.0")], want: Missing("found zig on PATH, its version is not known") },
		{ need: "1.17.0", list: [path("0.17.0")], want: Missing("found zig 0.17.0 on PATH") },
		{ need: "0.17.0", list: [path("0.18.0")], want: Missing("found zig 0.18.0 on PATH") },
		{ need: "0.17.0", list: [path("1.17.0")], want: Missing("found zig 1.17.0 on PATH") },
	]
	bad = rows.keep_if(|r| Zig.search({ need: r.need, candidates: r.list }) != r.want).map(|r| (r.need, r.list, r.want, Zig.search({ need: r.need, candidates: r.list })))
	dbg bad
	describe_rows = [
		(Env, Ok("0.16.0"), "found zig 0.16.0 in $ZIG"),
		(Path, Ok("0.16.0"), "found zig 0.16.0 on PATH"),
		(Installed, Ok("0.17.0"), "found zig 0.17.0 installed by Talon"),
		(Path, Err(Unknown), "found zig on PATH, its version is not known"),
		(Installed, Err(Unknown), "found zig installed by Talon, its version is not known"),
	]
	bad_describe = describe_rows.keep_if(|(source, version, want)| Zig.describe({ source, version }) != want)
	dbg bad_describe
	bad == [] and bad_describe == []
}

# R-D1: the dirs of Talon that hold a Zig. A file, a temp dir, a lock dir, a trash dir, a dev version and a compiler dir are not a Zig. The list is in byte order. A Windows host runs `zig.exe`.
expect {
	entry = |name, is_dir| { name, is_dir, mtime: 1 }
	entries = [
		entry("zig-0.17.0", Bool.True),
		entry("nightly-2026-10-09-258ab27", Bool.True),
		entry("zig-0.16.2", Bool.True),
		entry("zig-0.17.1", Bool.False),
		entry("zig-0.17.0.0123456789abcdef.tmp", Bool.True),
		entry("zig-0.17.0.lock", Bool.True),
		entry("zig-0.15.0.0123456789abcdef.trash", Bool.True),
		entry("zig-0.17.0-dev.1+abc", Bool.True),
		entry("zig-dev", Bool.True),
		entry("link-dev", Bool.True),
	]
	linux = Zig.installed({ roots, host: LinuxX64, entries })
	windows = Zig.installed({ roots, host: WindowsArm64, entries })
	dbg linux
	linux == [
		{ source: Installed, path: "/c/roc/toolchains/zig-0.16.2/zig", version: Ok("0.16.2") },
		{ source: Installed, path: "/c/roc/toolchains/zig-0.17.0/zig", version: Ok("0.17.0") },
	]
		and windows == [
			{ source: Installed, path: "/c/roc/toolchains/zig-0.16.2/zig.exe", version: Ok("0.16.2") },
			{ source: Installed, path: "/c/roc/toolchains/zig-0.17.0/zig.exe", version: Ok("0.17.0") },
		]
			and Zig.installed({ roots, host: MacosApple, entries: [] }) == []
}

# R-D2, Q2 (review): with 2 or more releases of the series the newest wins in the order of the numbers (0.17.10 over 0.17.9, in any order of the keys). R-D2: the key of each host, and the archive that the index gives. The release of the series is chosen, not `master` (also when `master` has the series: its version is `0.17.1-dev`), and the patch of `need` does not count.
# `src` and the other targets are not read. The archive name is the last segment of the URL.
expect {
	rows = hosts.map2(keys, |host, key| (host, key))
	bad_keys = rows.keep_if(|(host, key)| Zig.target(host) != key)
	same_series_master = index([master_json("0.17.1-dev.9+ff"), release_json("0.17.0", keys), release_json("0.16.2", keys)])
	two_of_series = |order| index([master_json("0.18.0-dev.5+abcdef")].concat(order.map(|v| release_json(v, keys))).concat([release_json("0.16.2", keys)]))
	newest_last = two_of_series(["0.17.2", "0.17.9", "0.17.10"])
	newest_first = two_of_series(["0.17.10", "0.17.9", "0.17.2"])
	newest_middle = two_of_series(["0.17.9", "0.17.10", "0.17.2"])
	numeric_size = "{ \"0.17.0\": { \"x86_64-linux\": { \"tarball\": \"https://z/zig-x86_64-linux-0.17.0.tar.xz\", \"shasum\": \"${sha_of("x86_64-linux")}\", \"size\": 12345 } } }"
	bad_picks = rows.keep_if(|(host, key)| Zig.pick({ index: full_index, need: "0.17.0", host }) != Ok(entry_of("0.17.0", key))).map(|(host, _key)| (host, Zig.pick({ index: full_index, need: "0.17.0", host })))
	dbg bad_picks
	bad_keys == []
		and bad_picks == []
			and Zig.pick({ index: newest_last, need: "0.17.0", host: LinuxX64 }) == Ok(entry_of("0.17.10", "x86_64-linux"))
				and Zig.pick({ index: newest_first, need: "0.17.0", host: LinuxX64 }) == Ok(entry_of("0.17.10", "x86_64-linux"))
					and Zig.pick({ index: newest_middle, need: "0.17.3", host: MacosApple }) == Ok(entry_of("0.17.10", "aarch64-macos"))
						and Zig.pick({ index: full_index, need: "0.16.1", host: LinuxArm64 }) == Ok(entry_of("0.16.2", "aarch64-linux"))
							and Zig.pick({ index: full_index, need: "0.15.0", host: MacosApple }) == Ok(entry_of("0.15.1", "aarch64-macos"))
								and Zig.pick({ index: full_index, need: "0.17.0-dev.31+abc", host: WindowsX64 }) == Ok(entry_of("0.17.0", "x86_64-windows"))
									and Zig.pick({ index: same_series_master, need: "0.17.0", host: LinuxX64 }) == Ok(entry_of("0.17.0", "x86_64-linux"))
										and Zig.pick({ index: numeric_size, need: "0.17.0", host: LinuxX64 }) == Ok({ version: "0.17.0", url: "https://z/zig-x86_64-linux-0.17.0.tar.xz", sha256: sha_of("x86_64-linux"), size: 12345, archive: "zig-x86_64-linux-0.17.0.tar.xz" })
}

# R-D2, R-CV4, slice 045 review Q4: a dev `minimum_zig_version` is read as the series before `-dev`, and an index with no release of that series gives the normal no-release failure. The failures of the index. No sha256 (missing, short or not hex) is `Integrity` (exit 16): Talon does not install a Zig that it cannot check. The kinds and the texts are proposals (TW24).
expect {
	pick = |text, need, host| Zig.pick({ index: text, need, host })
	no_release = index([master_json("0.18.0-dev.5+abcdef"), release_json("0.16.2", keys), release_json("0.18.0", keys)])
	no_windows_arm = index([release_json("0.17.0", ["x86_64-linux", "x86_64-windows"])])
	no_tarball = "{ \"0.17.0\": { \"x86_64-linux\": { \"shasum\": \"${sha_of("x86_64-linux")}\", \"size\": \"1\" } } }"
	null_target = "{ \"0.17.0\": { \"x86_64-linux\": null } }"
	with_sha = |sha| "{ \"0.17.0\": { \"x86_64-linux\": { \"tarball\": \"https://z/a.tar.xz\", \"shasum\": ${sha}, \"size\": \"1\" } } }"
	no_sha = "{ \"0.17.0\": { \"x86_64-linux\": { \"tarball\": \"https://z/a.tar.xz\", \"size\": \"1\" } } }"
	not_json = Fail.new(Network, "the Zig index is not a JSON object")
	integrity = Fail.new(Integrity, "the Zig index has no sha256 for zig 0.17.0 (x86_64-linux). Talon does not install it.")
	dbg pick("[1, 2]", "0.17.0", LinuxX64)
	pick("", "0.17.0", LinuxX64) == Err(not_json)
		and pick("[1, 2]", "0.17.0", LinuxX64) == Err(not_json)
			and pick("{ \"0.17.0\": ", "0.17.0", LinuxX64) == Err(not_json)
				and pick("\"text\"", "0.17.0", LinuxX64) == Err(not_json)
					and pick(no_release, "0.17.0", LinuxX64) == Err(Fail.new(Environment, "the Zig index has no release of zig 0.17.x"))
						and pick("{}", "0.17.0", LinuxX64) == Err(Fail.new(Environment, "the Zig index has no release of zig 0.17.x"))
							and pick(no_release, "0.17.0-dev.31+abc", LinuxX64) == Err(Fail.new(Environment, "the Zig index has no release of zig 0.17.x"))
								and pick(no_windows_arm, "0.17.0", WindowsArm64) == Err(Fail.new(Environment, "the Zig index has no archive of zig 0.17.0 for aarch64-windows"))
									and pick(no_windows_arm, "0.17.0", WindowsX64) == Ok(entry_of("0.17.0", "x86_64-windows"))
										and pick(no_tarball, "0.17.0", LinuxX64) == Err(Fail.new(Environment, "the Zig index has no archive of zig 0.17.0 for x86_64-linux"))
											and pick(null_target, "0.17.0", LinuxX64) == Err(Fail.new(Environment, "the Zig index has no archive of zig 0.17.0 for x86_64-linux"))
												and pick(no_sha, "0.17.0", LinuxX64) == Err(integrity)
													and pick(with_sha("\"${"a".repeat(63)}\""), "0.17.0", LinuxX64) == Err(integrity)
														and pick(with_sha("\"${"a".repeat(65)}\""), "0.17.0", LinuxX64) == Err(integrity)
															and pick(with_sha("\"${"z".repeat(64)}\""), "0.17.0", LinuxX64) == Err(integrity)
																and pick(with_sha("null"), "0.17.0", LinuxX64) == Err(integrity)
																	and pick(with_sha("\"\""), "0.17.0", LinuxX64) == Err(integrity)
																		and integrity.kind.code() == 16
																			and Fail.new(Environment, "x").kind.code() == 18
																				and not_json.kind.code() == 15
}

# R-D2, R-CC1, R-CC4: the paths of one install, the program name of a host, the check for `xz` (R-EC18), and the text of `.talon.json` (R-TF1). The program is `zig.exe` on Windows.
expect {
	linux = Zig.plan({ roots, host: LinuxX64, version: "0.17.0", archive: "zig-x86_64-linux-0.17.0.tar.xz", hex: "0123456789abcdef" })
	windows = Zig.plan({ roots, host: WindowsX64, version: "0.17.0", archive: "zig-x86_64-windows-0.17.0.zip", hex: "00000000000000ff" })
	temp = "/c/roc/toolchains/zig-0.17.0.0123456789abcdef.tmp"
	xz_rows = [
		(LinuxX64, "zig-x86_64-linux-0.17.0.tar.xz", Bool.True),
		(LinuxArm64, "zig-aarch64-linux-0.17.0.tar.xz", Bool.True),
		(LinuxX64, "zig-x86_64-linux-0.17.0.zip", Bool.False),
		(MacosApple, "zig-aarch64-macos-0.17.0.tar.xz", Bool.False),
		(MacosX64, "zig-x86_64-macos-0.17.0.tar.xz", Bool.False),
		(WindowsX64, "zig-x86_64-windows-0.17.0.zip", Bool.False),
		(WindowsArm64, "zig-aarch64-windows-0.17.0.tar.xz", Bool.False),
	]
	bad_xz = xz_rows.keep_if(|(host, archive, want)| Zig.needs_xz({ host, archive }) != want)
	meta = Zig.meta({ version: "0.17.0", url: "https://ziglang.org/download/0.17.0/zig-x86_64-linux-0.17.0.tar.xz", sha256: sha_of("x86_64-linux"), now: 1792670400 })
	dbg linux
	dbg meta
	linux == {
		version: "0.17.0",
		item: "/c/roc/toolchains/zig-0.17.0",
		temp,
		archive: "${temp}/zig-x86_64-linux-0.17.0.tar.xz",
		zig: "${temp}/zig",
		meta: "${temp}/.talon.json",
	}
		and windows.zig == "/c/roc/toolchains/zig-0.17.0.00000000000000ff.tmp/zig.exe"
			and windows.archive == "/c/roc/toolchains/zig-0.17.0.00000000000000ff.tmp/zig-x86_64-windows-0.17.0.zip"
				and windows.item == "/c/roc/toolchains/zig-0.17.0"
					and Zig.exe(LinuxArm64) == "zig"
						and Zig.exe(MacosApple) == "zig"
							and Zig.exe(WindowsArm64) == "zig.exe"
								and bad_xz == []
									and meta == "{\"format\":1,\"id\":\"zig-0.17.0\",\"url\":\"https://ziglang.org/download/0.17.0/zig-x86_64-linux-0.17.0.tar.xz\",\"sha256\":\"${sha_of("x86_64-linux")}\",\"sha256_source\":\"zig-index\",\"installed_at\":\"2026-10-22T12:00:00Z\"}\n"
}

# R-D3: the dependency list. `[x]` is found, `[ ]` with a reason is missing. The LLVM bundle line is always `[ ]` and has the target and the size of the asset. The first 2 rows are the example of CLI 6.6
# (the size has one digit: `Toolchain.size_text`, a proposal, TW24).
expect {
	llvm = { target: "x86_64-linux-musl", size: Ok(45_000_000) }
	lines = |rows| "Dependencies:\n${Str.join_with(rows, "\n")}\n"
	llvm_row = "  [ ] LLVM bundle           x86_64-linux-musl, 45.0 MB, zig gets it during the build"
	missing = Zig.deps({ need: "0.17.0", search: Missing("found zig 0.16.0 on PATH"), llvm })
	found_path = Zig.deps({ need: "0.17.0", search: Found({ source: Path, path: "zig", version: "0.17.2" }), llvm })
	found_env = Zig.deps({ need: "0.17.0", search: Found({ source: Env, path: "/opt/zig/zig", version: "0.17.1" }), llvm })
	found_inst = Zig.deps({ need: "0.15.2", search: Found({ source: Installed, path: "/c/roc/toolchains/zig-0.15.1/zig", version: "0.15.1" }), llvm })
	none = Zig.deps({ need: "0.17.0", search: Missing("zig not found"), llvm: { target: "aarch64-macos", size: Err(Unknown) } })
	dbg missing
	missing == lines(["  [ ] zig 0.17.x            found zig 0.16.0 on PATH", llvm_row])
		and found_path == lines(["  [x] zig 0.17.x            found zig 0.17.2 on PATH", llvm_row])
			and found_env == lines(["  [x] zig 0.17.x            found zig 0.17.1 in $ZIG", llvm_row])
				and found_inst == lines(["  [x] zig 0.15.x            found zig 0.15.1 installed by Talon", llvm_row])
					and none == lines(["  [ ] zig 0.17.x            zig not found", "  [ ] LLVM bundle           aarch64-macos, zig gets it during the build"])
}

# R-NI6, R-DL1, R-DL3, R-DL4: the prompt of the Zig install. It is a Default prompt: interactive, the default is Yes (R-DL3: "the Zig of `roc install`"). Non-interactive, and with `--yes`, the answer is Yes with no prompt (the command
# names the build, so it is the consent, R-DL4). The prompt names the version and the size (R-DL1, R-NR2). The question is the text of CLI 6.6.
expect {
	p = Consent.zig_install({ version: "0.17.0", size: 54_227_812 })
	decide = |mode, yes, flag| Prompt.decide(p, { mode, yes, flag })
	declined = Consent.zig_install_declined("0.17.0")
	dbg p.question
	p.id == "zig-install"
		and p.kind == Default
			and p.shape == YesNo
				and p.default == Yes
					and p.question == "Install zig 0.17.0 (54.2 MB) for Talon builds?"
						and p.subject == "the download of zig 0.17.0"
							and (p.answer_line)(Yes) == "installing zig 0.17.0 (54.2 MB)"
								and (p.answer_line)(No) == "no install of zig 0.17.0"
									and Prompt.text(p) == "Install zig 0.17.0 (54.2 MB) for Talon builds? [Y/n] "
										and Prompt.reply(p, "") == Ok(Yes)
											and Prompt.reply(p, "N") == Ok(No)
												and decide(NonInteractive, Bool.False, Err(NoFlag)) == Use(Yes)
													and decide(NonInteractive, Bool.True, Err(NoFlag)) == Use(Yes)
														and decide(Interactive, Bool.False, Err(NoFlag)) == Ask
															and decide(Interactive, Bool.True, Err(NoFlag)) == Use(Yes)
																and decide(NeedsTty, Bool.False, Err(NoFlag)) == NeedTty
																	and declined == Fail.new(Consent, "zig 0.17.0 is not installed. Nothing was downloaded.")
																		and declined.kind.code() == 13
}

# Slice 061, R-D2, R-D1: the Zig installs in the store. `Gc.zig_dirs` takes the listing of `<cache>/toolchains` and gives the ids `zig-<X.Y.Z>` of the Zig installs that Talon makes (R-D2: a dir `zig-<version>`
# with a release version, as `Zig.installed` finds them), in byte order. The name decides (Q4 of the slice file): the time and the `.talon.json` are not read, and a `git-*` entry changes nothing (Q1).
# Not in the answer: a file, a dev version, a version with 2 numbers or 4, a temp, a lock dir, a trash dir (R-CC2 removes the temps and trash dirs by age), a compiler (a nightly, a release, `git-`, `link-`, `copy-`), a name that only has `zig` in it.
expect {
	dir = |name, mtime| { name, is_dir: Bool.True, mtime }
	file = |name| { name, is_dir: Bool.False, mtime: 5 }
	odd = [
		file("zig-0.17.1"),
		dir("zig-0.18.0-dev.31+abc1234", 5),
		dir("zig-0.17", 5),
		dir("zig-0.17.0.1", 5),
		dir("zig-0.17.0.0123456789abcdef.tmp", 5),
		dir("zig-0.17.0.lock", 5),
		dir("zig-0.17.0.0123456789abcdef.trash", 5),
		dir("zig-", 5),
		dir("zig-a.b.c", 5),
		dir("zig", 5),
		dir("zigzag-0.17.0", 5),
		dir("link-zig-0.17.0", 5),
		dir("git-0123abcd", 5),
		dir("copy-fix-1", 5),
		dir("nightly-2026-10-14-38a3029", 5),
		dir("0.1.0", 5),
	]
	rows = [
		([], []),
		([dir("zig-0.17.0", 5)], ["zig-0.17.0"]),
		# The time of an entry is not read.
		([dir("zig-0.16.1", 0), dir("zig-0.17.0", 99999999999)], ["zig-0.16.1", "zig-0.17.0"]),
		# Byte order of the names: 0.17.10 comes before 0.17.9. The order of the listing does not matter.
		([dir("zig-0.17.9", 5), dir("zig-0.17.10", 5), dir("zig-0.16.0", 5)], ["zig-0.16.0", "zig-0.17.10", "zig-0.17.9"]),
		([dir("zig-0.16.0", 5), dir("zig-0.17.10", 5), dir("zig-0.17.9", 5)], ["zig-0.16.0", "zig-0.17.10", "zig-0.17.9"]),
		(odd, []),
		(odd.concat([dir("zig-0.17.0", 5)]), ["zig-0.17.0"]),
		([dir("zig-0.17.0", 5)].concat(odd).concat([dir("zig-0.15.2", 5)]), ["zig-0.15.2", "zig-0.17.0"]),
	]
	bad = rows.keep_if(|(entries, want)| Gc.zig_dirs(entries) != want).map(|(entries, want)| (entries.len(), want, Gc.zig_dirs(entries)))
	dbg bad
	bad == []
}

# Slice 061, R-D2, R-GC5, R-CC10, R-CC9 (Q2 of the slice file): the Zig installs that GC removes. A source build writes `.last-use` of its Zig before it starts (the UTC time and a line end, `Launch.last_use`). GC keeps a Zig with a last use in the last day (R-CC10:
# "a running build wrote it when it started"): not more than 86400 s before `now`, so exactly one day stays, and a time in the future stays. There is no GC age for a Zig (Q3), so a Zig with an older last use goes, and a Zig with no `.last-use` goes.
# A file that GC cannot read (`Denied`, `Other`) or a text that is no UTC time is not judged: the Zig stays (as an unreadable project file, D4 of slice 028). The result is in the order of `ids`.
expect {
	now : U64
	now = 1792670400
	at = |back| Ok("${Clock.format_utc(now - back)}\n")
	rows = [
		# ids, reads, the ids that go
		([], [], []),
		(["zig-0.17.0"], [at(3600)], []),
		(["zig-0.17.0"], [at(43200)], []),
		(["zig-0.17.0"], [at(86400)], []),
		(["zig-0.17.0"], [at(86401)], ["zig-0.17.0"]),
		(["zig-0.17.0"], [at(172800)], ["zig-0.17.0"]),
		(["zig-0.17.0"], [Ok(Clock.format_utc(now - 172800))], ["zig-0.17.0"]),
		(["zig-0.17.0"], [Ok("${Clock.format_utc(now + 5000)}\n")], []),
		(["zig-0.17.0"], [Err(NotFound)], ["zig-0.17.0"]),
		(["zig-0.17.0"], [Err(Denied)], []),
		(["zig-0.17.0"], [Err(Other("io"))], []),
		(["zig-0.17.0"], [Ok("yesterday\n")], []),
		(["zig-0.17.0"], [Ok("")], []),
		(
			["zig-0.14.0", "zig-0.15.1", "zig-0.16.1", "zig-0.17.0", "zig-0.18.0"],
			[at(172800), at(43200), Err(NotFound), Err(Denied), at(90000)],
			["zig-0.14.0", "zig-0.16.1", "zig-0.18.0"],
		),
	]
	bad = rows.keep_if(|(ids, reads, want)| Gc.zigs({ ids, reads, now }) != want).map(|(ids, reads, want)| (ids, reads, want, Gc.zigs({ ids, reads, now })))
	dbg bad
	bad == []
}

# R-D2 R-SE9 (slice 076, Q3): the archive name of the index is the last segment of the tarball URL, and it is a file name in the temp dir of the install. A name that is not a safe path part (`..`, `.`, empty, a backslash or a NUL byte in it)
# is not an archive: the failure of the row "no archive" (`Environment`, exit 18, nothing is written). A dot inside a name is safe.
expect {
	with_url = |url| "{ \"0.17.0\": { \"x86_64-linux\": { \"tarball\": \"${url}\", \"shasum\": \"${sha_of("x86_64-linux")}\", \"size\": \"1\" } } }"
	archive = |url| Zig.pick({ index: with_url(url), need: "0.17.0", host: LinuxX64 }).map_ok(|e| e.archive).map_err(|f| (f.kind.code(), f.message))
	none = Err((18, "the Zig index has no archive of zig 0.17.0 for x86_64-linux"))
	rows = [
		("a name", archive("https://z/zig-x86_64-linux-0.17.0.tar.xz"), Ok("zig-x86_64-linux-0.17.0.tar.xz")),
		("dots inside a name", archive("https://z/..a.tar.xz"), Ok("..a.tar.xz")),
		("a name that is ..", archive("https://z/.."), none),
		("a name that is .", archive("https://z/."), none),
		("an empty name (the URL ends with a /)", archive("https://z/dl/"), none),
		("a backslash in the name", archive("https://z/a\\\\..\\\\b.tar.xz"), none),
		("a NUL byte in the name", archive("https://z/a\\u0000b.tar.xz"), none),
	]
	bad = rows.keep_if(|(_, got, want)| got != want).map(|(label, got, want)| (label, want, got))
	dbg bad
	bad == []
}
