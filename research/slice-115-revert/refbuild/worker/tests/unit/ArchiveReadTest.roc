import lib.ArchiveRead
import lib.Problem
import base58.Base58
import records.Artifact

import "fixtures/roc-semver-0.2.0.tar" as semver_tar : List(U8)

ArchiveReadTest :: [].{}

# W0 tests of worker/lib/ArchiveRead.roc (slice 111, Registry R-PU38). W0 has no zstd and no Native BLAKE3: the tests give the tar bytes to `push` with no
# decoder, and the digest is the builtin `Crypto.BLAKE3` of those bytes (the module only compares it with the hash of the URL).
# fixtures/roc-semver-0.2.0.tar is the tar of the real release asset BzgH68Q1... of roc-semver 0.2.0 (roc bundle output, made by worker/tests/tools/mk-bundle.mjs).
# The tar bytes of the other cases are made below with a small ustar writer (test code, not the reader).

# ---- a small ustar writer ----

octal : U64, U64 -> List(U8)
octal = |n, width| {
	var $digits = []
	var $v = n
	while $v > 0 {
		$digits = $digits.prepend(48 + ($v % 8).to_u8_wrap())
		$v = $v // 8
	}
	List.repeat(48, width - $digits.len()).concat($digits)
}

field : List(U8), U64 -> List(U8)
field = |bytes, len| bytes.concat(List.repeat(0, len - bytes.len()))

# One header block. `kind` is the type byte ('0' file, '1' hard link, '2' symbolic link, '3' character device, '5' directory, '6' FIFO, 'x' pax).
header_block : Str, Str, U8, U64, Str -> List(U8)
header_block = |name, prefix, kind, size, link| {
	before = field(name.to_utf8(), 100)
		.concat(octal(0o644, 7).append(0))
		.concat(octal(0, 7).append(0))
		.concat(octal(0, 7).append(0))
		.concat(octal(size, 11).append(0))
		.concat(octal(0, 11).append(0))
	after = [kind]
		.concat(field(link.to_utf8(), 100))
		.concat("ustar".to_utf8().append(0))
		.concat("00".to_utf8())
		.concat(List.repeat(0, 80))
		.concat(field(prefix.to_utf8(), 155))
		.concat(List.repeat(0, 12))
	sum = before.concat(List.repeat(32, 8)).concat(after).fold(0.U64, |acc, b| acc + b.to_u64())
	before.concat(octal(sum, 6)).concat([0, 32]).concat(after)
}

pad : List(U8) -> List(U8)
pad = |bytes| bytes.concat(List.repeat(0, (512 - (bytes.len() % 512)) % 512))

# A member with a path that fits the name field.
member : Str, U8, List(U8) -> List(U8)
member = |path, kind, data| header_block(path, "", kind, data.len(), "").concat(pad(data))

file : Str, Str -> List(U8)
file = |path, text| member(path, '0', text.to_utf8())

link_member : Str, U8, Str -> List(U8)
link_member = |path, kind, target| header_block(path, "", kind, 0, target)

# A member with a path in the ustar prefix and name fields (the reader joins them with `/`).
split_member : Str, Str, Str -> List(U8)
split_member = |prefix, name, text| header_block(name, prefix, '0', text.count_utf8_bytes(), "").concat(pad(text.to_utf8()))

end2 : List(U8)
end2 = List.repeat(0, 1024)

mod_text = |name| "${name} :: [].{\n\tx : U64\n\tx = 1\n}\n"

semver_url = "https://github.com/Karakatiza666/roc-semver/releases/download/0.2.0/BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i.tar.zst"

pkg_header = "## A made package of slice 111.\npackage\n\t[\n\t\tZeta,\n\t\tAlpha,\n\t]\n\t{\n\t\tsemver: \"${semver_url}\",\n\t}\n"

# The members of a made package: main.roc first (as roc bundle writes it), two modules, and a file in targets/ (not a target of a package, R-RE20).
pkg_members : List(U8)
pkg_members = file("main.roc", pkg_header).concat(file("Zeta.roc", mod_text("Zeta"))).concat(file("Alpha.roc", mod_text("Alpha"))).concat(file("targets/x64mac/libhost.a", "not a target"))

pkg_tar : List(U8)
pkg_tar = pkg_members.concat(end2)

semver_dep = { alias: "semver", hash: "BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i", group: "github.com/Karakatiza666/roc-semver/releases/download/{v}/", series: Ok("0.2"), version: Ok("0.2.0"), url: semver_url }

b58 : List(U8) -> Str
b58 = |bytes| Base58.encode(Crypto.BLAKE3.hash(bytes).to_bytes())

# The read of W0: `count` and `push` for each chunk of `size` bytes, then `finish` with the digest of all bytes and the hash `hash`.
read_with : List(U8), U64, Str -> Try(Artifact.Row, ArchiveRead.Refusal)
read_with = |bytes, size, hash| {
	var $s = ArchiveRead.empty()
	for chunk in bytes.chunks_of(size) {
		match $s.count(chunk.len()) {
			Ok(s2) => {
				$s = if (s2.reading()) s2.push(chunk) else s2
			}

			Err(refusal) => return Err(refusal)
		}
	}
	$s.finish(Crypto.BLAKE3.hash(bytes).to_bytes(), hash)
}

read : List(U8) -> Try(Artifact.Row, ArchiveRead.Refusal)
read = |bytes| read_with(bytes, 4096, b58(bytes))

pkg_row : List(U8) -> Try(Artifact.Row, ArchiveRead.Refusal)
pkg_row = |bytes| Ok({ hash: b58(bytes), kind: Package, exposed: ["Zeta", "Alpha"], platform_hash: Err(None), roc_pin: Err(None), size: bytes.len(), deps: [semver_dep], target_names: [] })

# A package with one more member.
with_extra : List(U8) -> List(U8)
with_extra = |extra| pkg_members.concat(extra).concat(end2)

# ---- constants (R-PU38 rows 2, 3, 5, 7) ----

# R-PU38 rows 2 and 15 (100 MB = 10^8 bytes), row 3 (8 MiB, the hard limit of Native.ZstdStream), row 5 (256 MiB, 10,000 members, 255 bytes, 1 MiB), row 7 (main.roc)
expect [ArchiveRead.max_packed_bytes, ArchiveRead.max_window_bytes, ArchiveRead.max_unpacked_bytes, ArchiveRead.max_members, ArchiveRead.max_path_bytes, ArchiveRead.max_header_bytes] == [100000000, 8388608, 268435456, 10000, 255, 1048576]
expect ArchiveRead.header_path == "main.roc"

# ---- url_hash (Design 2: the hash is the last segment of the URL) ----

expect
	[
		"https://github.com/t/pkg/releases/download/1.0.0/EkFUp47m67vbivqsR14Qy8X2eWjUzEScVrzrsAPoBWqk.tar.zst",
		"https://example.com/pkgs/C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz.tar.zst",
		"https://github.com/t/pkg/releases/download/1.0.0/.tar.zst",
		"https://github.com/t/pkg/releases/download/1.0.0/x.tar.gz",
		"https://github.com/t/pkg/releases/download/1.0.0/",
	].map(ArchiveRead.url_hash)
		== [Ok("EkFUp47m67vbivqsR14Qy8X2eWjUzEScVrzrsAPoBWqk"), Ok("C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz"), Err(NoHash), Err(NoHash), Err(NoHash)]

# ---- size: Content-Length and the byte count (R-PU38 row 2) ----

# R-PU38 row 2: Content-Length before the read. No header passes (the count still applies). Exactly 100,000,000 passes.
expect
	[Err(NotFound), Ok("0"), Ok("8270"), Ok("100000000"), Ok("100000001"), Ok("2147483648")].map(ArchiveRead.check_length)
		== [Ok({}), Ok({}), Ok({}), Ok({}), Err(TooLarge({ bytes: 100000001, from: ContentLength })), Err(TooLarge({ bytes: 2147483648, from: ContentLength }))]

# R-PU38 row 2: a Content-Length over the U64 range is over the limit; the `detail` shows the header text as sent, not a number (proposal, slice file 7.3)
expect
	ArchiveRead.check_length(Ok("99999999999999999999")).map_err(ArchiveRead.problem)
		== Err(Problem.new(NotACandidate, "the asset has more than 100000000 bytes (Content-Length 99999999999999999999)"))

# R-PU38 rows 2, 9, 15: the count of the bytes read, over all chunks: exactly 100,000,000 passes, one byte more is refused with the new total.
expect {
	s1 = ArchiveRead.empty().count(60000000) ?? crash "count 1"
	s2 = s1.count(40000000)
	s3 = (s2 ?? crash "count 2").count(1)
	(s2.is_ok(), s3.map_ok(|_| {})) == (Bool.True, Err(TooLarge({ bytes: 100000001, from: Count })))
}

expect ArchiveRead.empty().count(100000001).map_ok(|_| {}) == Err(TooLarge({ bytes: 100000001, from: Count }))

# R-RE1: `size` is the packed byte count of `count` (the bytes of the asset), not the unpacked size.
expect {
	s = ArchiveRead.empty().count(1234) ?? crash "count"
	s.push(pkg_tar).finish(Crypto.BLAKE3.hash(pkg_tar).to_bytes(), b58(pkg_tar)).map_ok(|row| row.size) == Ok(1234)
}

# ---- the real bundle (R-PU38 rows 1, 7, R-RE1, R-AP49) ----

# R-PU38 row 1: a real roc bundle tar gives the same record for each chunk size (a chunk can stop in a header, in data, in padding)
expect {
	want = Ok({ hash: b58(semver_tar), kind: Package, exposed: ["Semver", "VersionReq"], platform_hash: Err(None), roc_pin: Err(None), size: 31744, deps: [], target_names: [] })
	[1, 7, 511, 512, 513, 4096, 31744].map(|n| read_with(semver_tar, n, b58(semver_tar))).all(|got| got == want)
}

# ---- the header fields (R-PU38 row 7, Design R-PK5, R-RE1, R-RE19, R-AP49) ----

plat_url = "https://github.com/t/plat/releases/download/1.2.3/3wQ1i3oJpeXzvm6Sdb7KsQRrxmGiz2Rn4WpTnZcbXtfe.tar.zst"

json_hash = "7Hc1J9u5WrD1NGTHxmFr6t3CQ4F9VXPUCyRcZ1HGnFno"

json_url = "https://github.com/t/json/releases/download/v0.25.1/${json_hash}.tar.zst"

json_dep = { alias: "json", hash: json_hash, group: "github.com/t/json/releases/download/v{v}/", series: Ok("0.25"), version: Ok("0.25.1"), url: json_url }

alpha_url = "https://example.com/pkgs/C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz.tar.zst"

lead_url = "https://github.com/t/lead/releases/download/01.2.3/4Bq3mTwzSUnGqGPJ6NRkZYfUmMxhgVHTpS3QfrUj9qgu.tar.zst"

cbor_url = "https://github.com/Karakatiza666/roc-cbor/releases/download/0.2.2/Cn5TmeqTbMewyChxexex2F3izTnMriXRv5ZMLVV3eUYb.tar.zst"

app_header = "app [main!] {\n\tpf: platform \"${plat_url}\",\n\tjson: \"${json_url}\",\n\talpha: \"${alpha_url}\",\n\tlead: \"${lead_url}\",\n\troc: \"nightly-2026-10-31-f7bef6b\",\n}\n\nmain! = |_args| Ok({})\n"

plat_header = "platform \"\"\n\trequires {\n\t\tmain! : List(Str) => Try({}, [Exit(I32)])\n\t}\n\texposes [Stdout, Arg]\n\tpackages {\n\t\tcbor: \"${cbor_url}\",\n\t}\n\tprovides { \"roc_main\": main_for_host! }\n\ttargets: {\n\t\tfiles: \"targets/\",\n\t\texe: { x64mac: [\"libhost.a\", app] },\n\t}\n"

# R-AP49, R-RE19: an app: no exposed names, the hash of the platform URL, the `roc:` pin, the deps in header order (not the platform, not `roc`, R-PU38 row 13).
# A tag `v0.25.1` keeps `v` in the group. A URL with no version: the group is the URL with no scheme and no last segment, no series, no version. `01.2.3` is version 1.2.3.
expect
	ArchiveRead.header_fields(app_header.to_utf8())
		== Ok({
			kind: App,
			exposed: [],
			platform_hash: Ok("3wQ1i3oJpeXzvm6Sdb7KsQRrxmGiz2Rn4WpTnZcbXtfe"),
			roc_pin: Ok("nightly-2026-10-31-f7bef6b"),
			deps: [
				{ alias: "json", hash: "7Hc1J9u5WrD1NGTHxmFr6t3CQ4F9VXPUCyRcZ1HGnFno", group: "github.com/t/json/releases/download/v{v}/", series: Ok("0.25"), version: Ok("0.25.1"), url: json_url },
				{ alias: "alpha", hash: "C6Jtcve7FRNtkwgmuyRBJnZfJyTrfJWhDcLp6gk4w4Gz", group: "example.com/pkgs/", series: Err(None), version: Err(None), url: alpha_url },
				{ alias: "lead", hash: "4Bq3mTwzSUnGqGPJ6NRkZYfUmMxhgVHTpS3QfrUj9qgu", group: "github.com/t/lead/releases/download/{v}/", series: Ok("1"), version: Ok("1.2.3"), url: lead_url },
			],
		})

# R-AP49: a package (exposed in header order, Design Q93) and a platform (its `exposes` list, its `packages` deps, no platform hash)
expect
	[pkg_header, plat_header].map(|t| ArchiveRead.header_fields(t.to_utf8()))
		== [
			Ok({ kind: Package, exposed: ["Zeta", "Alpha"], platform_hash: Err(None), roc_pin: Err(None), deps: [semver_dep] }),
			Ok({ kind: Platform, exposed: ["Stdout", "Arg"], platform_hash: Err(None), roc_pin: Err(None), deps: [{ alias: "cbor", hash: "Cn5TmeqTbMewyChxexex2F3izTnMriXRv5ZMLVV3eUYb", group: "github.com/Karakatiza666/roc-cbor/releases/download/{v}/", series: Ok("0.2"), version: Ok("0.2.2"), url: cbor_url }] }),
		]

# R-PU38 rows 7, 16, R-PK5: a header file that is not UTF-8, and one with no app, package or platform header
expect
	[[0xff, 0xfe, 0x00], "module [x]\n\nx = 1\n".to_utf8()].map(ArchiveRead.header_fields)
		== [Err(BadHeader(NotUtf8)), Err(BadHeader(NoHeader))]

# R-PU38 row 16, R-AP49: an app that names no platform is accepted (roc gives it the Echo platform), with no platform hash
expect
	ArchiveRead.header_fields("app [main!] { json: \"${json_url}\" }\n".to_utf8())
		== Ok({ kind: App, exposed: [], platform_hash: Err(None), roc_pin: Err(None), deps: [json_dep] })

# R-PU38 row 14, R-RE19: each `deps` entry is an `https://` package URL whose hash is base58 of 32 bytes. A path, `http://`, no hash, 2 versions, `0.0.0`,
# a bad base58 character, 31 and 33 bytes are refused. A URL with no version passes (the app row above).
bad_deps = [
	"../util/main.roc",
	"http://github.com/t/u/releases/download/1.0.0/${json_hash}.tar.zst",
	"https://github.com/t/u/releases/download/1.0.0/main.roc",
	"https://github.com/t/u/releases/download/1.0.0/2.0.0/${json_hash}.tar.zst",
	"https://github.com/t/u/releases/download/0.0.0/${json_hash}.tar.zst",
	"https://github.com/t/u/releases/download/1.0.0/0Hc1J9u5WrD1NGTHxmFr6t3CQ4F9VXPUCyRcZ1HGnFno.tar.zst",
	"https://github.com/t/u/releases/download/1.0.0/G6ShajrrdiRnD4mW22j8T5kXyKSvwXaC64S9VGSzFA.tar.zst",
	"https://github.com/t/u/releases/download/1.0.0/6541KsXhNYsav4wZjH4ZfEdkqQ6Wv7csYioYgd82EUrfi.tar.zst",
]

expect
	bad_deps.map(|u| ArchiveRead.header_fields("package [A] { util: \"${u}\" }\n".to_utf8()))
		== bad_deps.map(|u| Err(BadDep({ alias: "util", url: u })))

# R-PU38 row 18 (Design Q136): the platform URL of an app gets the checks of row 14: a path, a URL with no `<hash>.tar.zst`, `http://`, a hash of 31 bytes
bad_platforms = [
	"../pf/main.roc",
	"https://github.com/t/plat/releases/download/1.2.3/main.roc",
	"http://github.com/t/plat/releases/download/1.2.3/3wQ1i3oJpeXzvm6Sdb7KsQRrxmGiz2Rn4WpTnZcbXtfe.tar.zst",
	"https://github.com/t/plat/releases/download/1.2.3/G6ShajrrdiRnD4mW22j8T5kXyKSvwXaC64S9VGSzFA.tar.zst",
]

expect
	bad_platforms.map(|u| ArchiveRead.header_fields("app [main!] { pf: platform \"${u}\" }\n".to_utf8()))
		== bad_platforms.map(|u| Err(BadDep({ alias: "pf", url: u })))

# R-PU38 row 13: a platform entry in a package or a platform header is a `deps` row (`platform_hash` is null for these kinds)
expect
	ArchiveRead.header_fields("package [A] { pf: platform \"${plat_url}\" }\n".to_utf8())
		== Ok({ kind: Package, exposed: ["A"], platform_hash: Err(None), roc_pin: Err(None), deps: [{ alias: "pf", hash: "3wQ1i3oJpeXzvm6Sdb7KsQRrxmGiz2Rn4WpTnZcbXtfe", group: "github.com/t/plat/releases/download/{v}/", series: Ok("1"), version: Ok("1.2.3"), url: plat_url }] })

# R-PK5: a header that stops in the middle is `BadHeader(BadHeader(offset))` (the offset of roc-app-header)
expect
	match ArchiveRead.header_fields("package [A, B".to_utf8()) {
		Err(BadHeader(BadHeader(_))) => Bool.True
		_ => Bool.False
	}

# ---- the targets of a platform (R-RE20, R-IK7) ----

long_target = "targets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/x"

target_paths = [
	"main.roc",
	"targets/",
	"targets/x64mac/libhost.a",
	"targets/x64mac/crt1.o",
	"targets/arm64musl/libhost.a",
	"targets/wasm32/",
	"targets/newtarget1/host.o",
	"targets/macos-sysroot/usr/lib/libSystem.tbd",
	"targets/Upper/x",
	long_target,
	"targets/README.md",
	"src/targets/x64win/a",
]

# R-RE20, R-IK7: the names of targets/<name>/ of a platform, distinct, sorted; a known name, a new name (36 and up), a dir entry; no name for a file in targets/,
# a name in a subdir, an upper case name, a name of 33 bytes, and `macos-sysroot` (R-PU38 row 11). Empty for an app and a package (R-AP49).
expect
	[Platform, Package, App].map(|k| ArchiveRead.target_names(k, target_paths))
		== [["arm64musl", "newtarget1", "wasm32", "x64mac"], [], []]

# ---- the paths and members (R-PU38 rows 5, 6) ----

# R-PU38 row 6: each path that `roc unbundle` refuses (Tar.check_portable_path)
expect
	[
		"src/../main.roc",
		"/abs.roc",
		"C:x.roc",
		"src/./A.roc",
		"src/con.roc",
		"src /A.roc",
		"src./A.roc",
		"src/A<.roc",
		"src\\A.roc",
	].map(|p| read(with_extra(file(p, "x"))))
		== [
			Err(BadPath({ path: "src/../main.roc", problem: ParentDir })),
			Err(BadPath({ path: "/abs.roc", problem: Absolute })),
			Err(BadPath({ path: "C:x.roc", problem: DriveLetter })),
			Err(BadPath({ path: "src/./A.roc", problem: DotPart })),
			Err(BadPath({ path: "src/con.roc", problem: ReservedName })),
			Err(BadPath({ path: "src /A.roc", problem: EndsWithSpace })),
			Err(BadPath({ path: "src./A.roc", problem: EndsWithPeriod })),
			Err(BadPath({ path: "src/A<.roc", problem: ReservedChar('<') })),
			Err(BadPath({ path: "src\\A.roc", problem: Backslash })),
		]

# R-PU38 rows 6, 12: a symbolic link, a hard link, a device, a FIFO and a contiguous file (type 7: roc-tar gives it as `File`) are refused
expect
	[
		link_member("evil", '2', "/etc/passwd"),
		link_member("hard", '1', "main.roc"),
		link_member("dev", '3', ""),
		link_member("fifo", '6', ""),
		member("contig", '7', "x".to_utf8()),
	].map(|m| read(with_extra(m)))
		== [
			Err(NotAFile({ path: "evil", kind: Symlink })),
			Err(NotAFile({ path: "hard", kind: HardLink })),
			Err(NotAFile({ path: "dev", kind: Other('3') })),
			Err(NotAFile({ path: "fifo", kind: Other('6') })),
			Err(NotAFile({ path: "contig", kind: Other('7') })),
		]

# R-PU38 row 12: a dir (type 5) and a file of type NUL are accepted
expect {
	t = with_extra(link_member("src/", '5', "").concat(member("src/zero.roc", 0, "x".to_utf8())))
	read(t) == pkg_row(t)
}

# R-PU38 row 17: the path key: the parts between `/` with no empty part, ASCII letters folded (not other letters)
expect
	["a/b", "a//b", "a/b/", "/a/b", "A/B.Roc", "src/", "Ä/b"].map(ArchiveRead.path_key)
		== ["a/b", "a/b", "a/b", "a/b", "a/b.roc", "src", "Ä/b"]

# R-PU38 row 17: 2 members with one key are a duplicate (the payload is the later path): the same text, a case difference, `a//b` and `a/b/` after `a/b`,
# the dir `src/` 2 times, `main.roc` and `MAIN.ROC`
expect
	[
		file("Zeta.roc", "again"),
		file("zeta.roc", "again"),
		file("a/b", "x").concat(file("a//b", "y")),
		file("a/b", "x").concat(link_member("a/b/", '5', "")),
		link_member("src/", '5', "").concat(link_member("src/", '5', "")),
		file("MAIN.ROC", "x"),
	].map(|m| read(with_extra(m)))
		== [
			Err(Duplicate("Zeta.roc")),
			Err(Duplicate("zeta.roc")),
			Err(Duplicate("a//b")),
			Err(Duplicate("a/b/")),
			Err(Duplicate("src/")),
			Err(Duplicate("MAIN.ROC")),
		]

# R-PU38 row 17: a member below a file member is refused, in both orders (the file `a`, then `a/b`; `a/b`, then the file `a`)
expect
	[file("a", "x").concat(file("a/b", "y")), file("a/b", "y").concat(file("a", "x"))].map(|m| read(with_extra(m)))
		== [Err(UnderFile({ path: "a/b", file: "a" })), Err(UnderFile({ path: "a/b", file: "a" }))]

# R-PU38 row 5: a path of 255 bytes (ustar prefix and name) is accepted, 256 bytes are refused by the tar limit
expect {
	p155 = "d".repeat(154)
	ok = with_extra(split_member(p155, "${"e".repeat(94)}/A.roc", "x"))
	bad = with_extra(split_member("d".repeat(155), "${"e".repeat(94)}/A.roc", "x"))
	(read(ok), read(bad)) == (pkg_row(ok), Err(BadTar(PathTooLong({ offset: pkg_members.len(), bytes: 256, limit: 255 }))))
}

# R-PU38 row 5: the header file is collected to 1 MiB (a header that claims 1 MiB + 1 is refused at its header block), the unpacked total is 256 MiB
# (a member that claims 256 MiB + 1 is refused at its header; a member of exactly 256 MiB passes the limit, so its missing data is `Truncated`)
expect {
	big_main = header_block("main.roc", "", '0', 1048577, "")
	over = header_block("big.bin", "", '0', 268435457, "")
	at = header_block("big.bin", "", '0', 268435456, "")
	[read(big_main), read(over), read(at)]
		== [
			Err(BadTar(ContentTooLarge({ offset: 0, size: 1048577, limit: 1048576 }))),
			Err(BadTar(TotalSizeTooLarge({ offset: 0, limit: 268435456 }))),
			Err(BadTar(Truncated({ offset: 512, inside: Data }))),
		]
}

# R-PU38 row 5: at most 10,000 members (10,000 files and main.roc are 10,001)
expect {
	var $many = []
	for i in 0.U64..<10000 {
		$many = $many.concat(header_block("m${i.to_str()}", "", '0', 0, ""))
	}
	many = $many
	read(pkg_members.concat(many).concat(end2)) == Err(BadTar(TooManyMembers({ offset: pkg_members.len() + 512 * 9996, limit: 10000 })))
}

# ---- the end of the archive (R-PU38 rows 4, 6) ----

# R-PU38 row 6: one zero block and no zero block at the end are accepted. Row 4: zero bytes after the end (GNU tar pads to 10240, and more) are accepted.
expect {
	one = pkg_members.concat(List.repeat(0, 512))
	none = pkg_members
	padded = pkg_tar.concat(List.repeat(0, 10240 - (pkg_tar.len() % 10240))).concat(List.repeat(0, 300000))
	[read(one), read(none), read(padded)] == [pkg_row(one), pkg_row(none), pkg_row(padded)]
}

# R-PU38 row 6: the strict errors of roc-tar: a lone zero block, data after the end, a cut in member data
expect {
	lone = pkg_members.concat(List.repeat(0, 512)).concat(file("Late.roc", "x")).concat(end2)
	after = pkg_tar.append('x')
	cut = pkg_members.concat(header_block("Cut.roc", "", '0', 1000, "")).concat(List.repeat(65, 100))
	[read(lone), read(after), read(cut)]
		== [
			Err(BadTar(LoneZeroBlock({ offset: pkg_members.len() + 512 }))),
			Err(BadTar(DataAfterEnd({ offset: pkg_tar.len() }))),
			Err(BadTar(Truncated({ offset: cut.len(), inside: Data }))),
		]
}

# R-PU38 rows 7, 17: no main.roc, a main.roc that is only in a subdir, and only `MAIN.ROC` (the header key keeps the case)
expect {
	no_main = file("Zeta.roc", mod_text("Zeta")).concat(end2)
	sub = file("src/main.roc", pkg_header).concat(end2)
	upper = file("MAIN.ROC", pkg_header).concat(file("Zeta.roc", mod_text("Zeta"))).concat(end2)
	[read(no_main), read(sub), read(upper)] == [Err(NoHeader), Err(NoHeader), Err(NoHeader)]
}

# ---- the hash and the order of the refusals (R-PU38 rows 4, 8, 9) ----

wrong = "GddgvsGjiNXrHFW6au5i5dUDbTs8FinQdrgE2Gqmw53t"

# R-PU38 row 4: the hash of all bytes must be the hash of the URL. A refused archive with a wrong hash gives the hash refusal (row 9).
expect {
	bad = with_extra(link_member("evil", '2', "x"))
	[read_with(pkg_tar, 4096, wrong), read_with(bad, 4096, wrong)]
		== [Err(HashMismatch({ expected: wrong, actual: b58(pkg_tar) })), Err(HashMismatch({ expected: wrong, actual: b58(bad) }))]
}

# R-PU38 row 9: the stream order also holds inside one chunk: a symbolic link, then a block that is not a tar header, in one push, gives the link
# (roc-tar gives no events before its error), for the whole archive as one chunk and in chunks of 4096 bytes
expect {
	t = pkg_members.concat(link_member("evil", '2', "x")).concat(List.repeat('A', 512)).concat(end2)
	[read_with(t, t.len(), b58(t)), read_with(t, 4096, b58(t))] == [Err(NotAFile({ path: "evil", kind: Symlink })), Err(NotAFile({ path: "evil", kind: Symlink }))]
}

# R-PU38 rows 4, 6: the first refusal is kept, and `reading` is false after it. The tar end does not stop the read.
expect {
	two = with_extra(link_member("evil", '2', "x").concat(file("src/../x.roc", "x")))
	refused = ArchiveRead.empty().push(two)
	ended = ArchiveRead.empty().push(pkg_tar)
	(read(two), refused.reading(), ended.reading()) == (Err(NotAFile({ path: "evil", kind: Symlink })), Bool.False, Bool.True)
}

# R-PU38 rows 3 and 10: a zstd error, at a push or at the close. A refusal before it stays.
expect {
	digest = Crypto.BLAKE3.hash([]).to_bytes()
	hash = Base58.encode(digest)
	fin = |s| s.finish(digest, hash)
	link = ArchiveRead.empty().push(with_extra(link_member("evil", '2', "x")))
	results = [
		fin(ArchiveRead.empty().unzip_failed(WindowTooLarge)),
		fin(ArchiveRead.empty().unzip_failed(BadFrame)),
		fin(ArchiveRead.empty().push(pkg_members).unzip_failed(Truncated)),
		fin(ArchiveRead.empty().unzip_failed(OutputLimit)),
		fin(link.unzip_failed(Truncated)),
	]
	want = [Err(WindowTooLarge), Err(BadZstd(BadFrame)), Err(BadZstd(Truncated)), Err(BadZstd(OutputLimit)), Err(NotAFile({ path: "evil", kind: Symlink }))]
	results == want and !ArchiveRead.empty().unzip_failed(BadFrame).reading()
}

# ---- the problems (R-AP21, R-PU38 rows 2 to 17; the `detail` texts are proposals, slice file section 5) ----

nac = |detail| Problem.new(NotACandidate, detail)

expect
	[
		TooLarge({ bytes: 100000001, from: ContentLength }),
		TooLarge({ bytes: 100003038, from: Count }),
		WindowTooLarge,
		BadZstd(BadFrame),
		BadZstd(Truncated),
		BadZstd(Unsupported),
		BadZstd(OutputLimit),
		BadTar(DataAfterEnd({ offset: 2048 })),
		BadPath({ path: "src/../main.roc", problem: ParentDir }),
		BadPath({ path: "src/con.roc", problem: ReservedName }),
		BadPath({ path: "src/A<.roc", problem: ReservedChar('<') }),
		NotAFile({ path: "evil", kind: Symlink }),
		NotAFile({ path: "hard", kind: HardLink }),
		NotAFile({ path: "dev", kind: Other('3') }),
		Duplicate("Zeta.roc"),
		UnderFile({ path: "a/b", file: "a" }),
		NoHeader,
		BadHeader(NotUtf8),
		BadHeader(NoHeader),
		BadHeader(BadHeader(12)),
		BadDep({ alias: "util", url: "../util/main.roc" }),
		HashMismatch({ expected: wrong, actual: "BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i" }),
	].map(ArchiveRead.problem)
		== [
			nac("the asset has 100000001 bytes (Content-Length), more than the limit of 100000000 bytes"),
			nac("the asset has more than the limit of 100000000 bytes (the read stopped at 100003038 bytes)"),
			nac("the zstd window of the asset is larger than 8388608 bytes"),
			nac("the asset is not a valid zstd stream: a damaged frame"),
			nac("the asset is not a valid zstd stream: the stream ends inside a frame"),
			nac("the asset is not a valid zstd stream: a frame needs a dictionary"),
			nac("the asset is not a valid zstd stream: a block gives too many bytes"),
			nac("tar: a byte that is not zero at offset 2048, after the end of the archive"),
			nac("the archive has a path that roc unbundle refuses (a .. part): src/../main.roc"),
			nac("the archive has a path that roc unbundle refuses (a Windows reserved name): src/con.roc"),
			nac("the archive has a path that roc unbundle refuses (the character <): src/A<.roc"),
			nac("the archive has a symbolic link, not a file: evil"),
			nac("the archive has a hard link, not a file: hard"),
			nac("the archive has a member of type 3, not a file: dev"),
			nac("the archive has the path Zeta.roc two times"),
			nac("the archive has a/b below the file a"),
			nac("the archive has no main.roc at its root"),
			nac("main.roc has no valid header: it is not UTF-8"),
			nac("main.roc has no valid header: it starts with no app, package or platform header"),
			nac("main.roc has no valid header: the header stops to be valid at byte 12"),
			nac("main.roc has a header entry util that is not a package URL with a hash: ../util/main.roc"),
			nac("the BLAKE3 hash of the asset is BzgH68Q1yBkg7F1ZpFsiEg73ZwkaBrFdcLpX2pUkay9i, not the hash ${wrong} of the URL"),
		]

# The asset read failed (a proposal of slice 111: slice 112 maps these for the ingest)
expect
	[Status(404), Status(500), NoAnswer, BodyRead].map(ArchiveRead.upstream_problem)
		== [
			Problem.new(Upstream, "the asset read failed with status 404"),
			Problem.new(Upstream, "the asset read failed with status 500"),
			Problem.new(Upstream, "the asset read failed: no answer"),
			Problem.new(Upstream, "the asset read failed: the body stopped"),
		]
