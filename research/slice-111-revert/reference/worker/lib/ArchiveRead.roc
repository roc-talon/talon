import tar.Tar
import header.Header
import header.PackageUrl
import base58.Base58
import records.Artifact
import records.Code
import Problem

## The archive read of a package asset (Registry R-PU38, Design 2, R-GA2, R-PK5, R-PK8; slice 111). Pure: the steps of one read and their checks.
## `worker/Archive.roc` (`Archive.read!`) orders the effects: the HTTP read, `Native.Blake3` and `Native.ZstdStream`. The tests are W0 (`worker/tests/unit/ArchiveReadTest.roc`)
## and W2 (`worker/tests/cases/archive/`, through the test app `worker/archive-test.roc`).
##
## The state holds only the packed byte count, the tar reader, the header file `main.roc`, the paths, and the first refusal (R-PU38 row 1). It never holds a chunk.
##
## | Step | Function | Rule |
## | --- | --- | --- |
## | Before the body read | `check_length` of the `Content-Length` header | Row 2 |
## | Each packed chunk, before any other work on it | `count` with the chunk length. `Err(TooLarge)` stops the read at once: no more hash, no more decode. | Row 2 |
## | Each decoded chunk, while `reading` is true | `push`: the tar reader (`tar_limits`, `choose`), and for each member: the kind, `Tar.check_portable_path`, a duplicate key, a member below a file | Rows 5, 6, 7, 12, 17 |
## | A zstd error (push or close) | `unzip_failed` | Row 3 (`WindowTooLarge`), row 10 |
## | The end of the body | `finish` with the 32 digest bytes and the hash of the URL | Rows 4 to 7, R-RE1, R-RE19, R-RE20 |
##
## After a refusal of `push` or `unzip_failed`, `reading` is false: the effect code gives no more bytes to the zstd decoder and the tar reader, but it still reads the
## body to its end and gives each chunk to BLAKE3 and to `count` (row 4: "the header read can end early, but the hash reads to the end").
## The tar can also end (two zero blocks) before the body ends: `reading` stays true, and `push` takes the zero bytes after the end (roc-tar accepts them).
##
## The order of the refusals that `finish` gives (row 9): a hash that is not the hash of the URL first, then the first refusal of the read, then the end
## check of the tar (`Tar.finish`), then no header file, then the header. `TooLarge` of `count` never reaches `finish`.
ArchiveRead :: {
	# The backing fields are private: the code agent can change them. The functions below are fixed.
	packed : U64,
	tar : Tar,
	header : Try(List(U8), [None]),
	paths : List(Str),
	seen : Set(Str),
	keys : Dict(Str, Str),
	files : Dict(Str, Str),
	below : Dict(Str, Str),
	tail : List(U8),
	base : U64,
	refused : Try(ArchiveRead.Refusal, [None]),
}.{

	## Row 2: the most bytes of the `.tar.zst` asset. 100 MB is 100,000,000 bytes (row 15).
	max_packed_bytes : U64
	max_packed_bytes = 100000000

	## Row 3: the largest zstd window, the hard limit of `Native.ZstdStream` (its default). `Archive.read!` opens the stream with `open!` (the default limit).
	max_window_bytes : U64
	max_window_bytes = 8388608

	## Row 5: the unpacked total (256 MiB), the members, the bytes of one path (as `roc unbundle`), and the header file (1 MiB).
	max_unpacked_bytes : U64
	max_unpacked_bytes = 268435456

	max_members : U64
	max_members = 10000

	max_path_bytes : U64
	max_path_bytes = 255

	max_header_bytes : U64
	max_header_bytes = 1048576

	## Row 7: the header file is the member `main.roc` at the archive root.
	header_path : Str
	header_path = "main.roc"

	## Why the asset is not a candidate (R-PU6). `problem` gives the problem of each.
	Refusal : [
		# Row 2. `from`: the `Content-Length` header (before the read) or the count of the bytes read (at the chunk that went over the limit).
		TooLarge({ bytes : U64, from : [ContentLength, Count] }),
		# Row 2: a Content-Length over the U64 range, with the header text as sent
		TooLargeHeader(Str),
		# Row 3
		WindowTooLarge,
		# Row 10: the other zstd errors of `Native.ZstdStream`
		BadZstd([BadFrame, Truncated, Unsupported, OutputLimit]),
		# Rows 5 and 6: a limit or a strict error of roc-tar
		BadTar(Tar.Error),
		# Row 6: a path that `Tar.check_portable_path` refuses
		BadPath({ path : Str, problem : [EmptyPath, TooLong, Absolute, DriveLetter, ParentDir, DotPart, ReservedName, EndsWithSpace, EndsWithPeriod, ReservedChar(U8), Backslash] }),
		# Rows 6, 12: a member that is not a file (type `0` or NUL) or a dir (type `5`). roc-tar gives `File` also for type `7` (contiguous): that member is
		# `NotAFile({ path, kind: Other('7') })` (the type byte is at `entry.offset + 156` of the decoded bytes).
		NotAFile({ path : Str, kind : Tar.Kind }),
		# Row 17: a member whose `path_key` is the key of a member before it. The payload is the path of the later member, as in the archive.
		Duplicate(Str),
		# Row 17: a member below a file member: `path` is the member below (the file `a` and the member `a/b`, in any order), `file` is the file. Paths as in the archive.
		UnderFile({ path : Str, file : Str }),
		# Row 7: no member `main.roc`
		NoHeader,
		# Rows 7, 16, Design R-PK5: `main.roc` is not UTF-8, or `Header.parse` refuses it. An app with no platform is accepted (row 16).
		BadHeader([NotUtf8, NoHeader, BadHeader(U64)]),
		# Row 14: a `deps` entry that does not start with `https://`, that `PackageUrl.parse` refuses (except `NoVersion`), or whose hash is not base58 of 32 bytes.
		BadDep({ alias : Str, url : Str }),
		# Row 4
		HashMismatch({ expected : Str, actual : Str }),
	]

	## The fields of the header (R-RE1, R-RE19, R-AP49, row 13). `exposed` is empty for an app. `platform_hash` is the hash of the platform URL of an app (`None` for an app
	## with no platform, row 16, and for a package and a platform). `roc_pin` is the value of the entry `roc`. `deps` has one item for each other entry, in header order:
	## not the platform entry of an app, not `roc`. A platform entry of a package or a platform header is a `deps` item (row 13).
	Fields : { kind : Code.Kind, exposed : List(Str), platform_hash : Try(Str, [None]), roc_pin : Try(Str, [None]), deps : List(Artifact.Dep) }

	## The limits of the tar reader (row 5): `max_members`, `max_path_bytes`, `max_unpacked_bytes` as `max_total_size`. The other limits are the defaults of roc-tar.
	tar_limits : Tar.Limits
	tar_limits = Tar.Limits.{ max_members: 10000, max_path_bytes: 255, max_total_size: 268435456 }

	## The choice of the tar reader for each member: `Collect(max_header_bytes)` for a file whose path key with no case fold is `main.roc` (row 17:
	## `main.roc`, `main.roc/` is a dir, `MAIN.ROC` is not the header), `Skip` for each other member.
	choose : Tar.Entry -> Tar.Action
	choose = |entry| if (raw_key(entry.path) == "main.roc" and entry.kind == File) Collect(1048576) else Skip

	## The state before the first chunk.
	empty : () -> ArchiveRead
	empty = || { packed: 0, tar: Tar.new(tar_limits), header: Err(None), paths: [], seen: Set.empty(), keys: Dict.empty(), files: Dict.empty(), below: Dict.empty(), tail: [], base: 0, refused: Err(None) }

	## The hash text of an asset URL: the last path segment with no `.tar.zst` (Design 2). `NoHash` when the URL has no such segment.
	url_hash : Str -> Try(Str, [NoHash])
	url_hash = |url| match url.split_last("/") {
		Ok({ after, .. }) if after.ends_with(".tar.zst") and after != ".tar.zst" => Ok(after.drop_suffix(".tar.zst"))
		_ => Err(NoHash)
	}

	## Row 2, before the read: the value of `Content-Length`. No header passes (the count still applies). A value of decimal digits over `max_packed_bytes` is
	## `TooLarge({ bytes, from: ContentLength })`. A value that is not decimal digits passes (proposal: workerd checks the framing; the count still applies).
	check_length : Try(Str, [NotFound]) -> Try({}, ArchiveRead.Refusal)
	check_length = |value| match value {
		Ok(text) if text != "" and text.to_utf8().all(|b| b >= '0' and b <= '9') => {
			match U64.from_str(text) {
				Ok(n) => if n > max_packed_bytes Err(TooLarge({ bytes: n, from: ContentLength })) else Ok({})
				Err(_) => Err(TooLargeHeader(text))
			}
		}

		_ => Ok({})
	}

	## Row 2, while the read goes on: add the bytes of one packed chunk. Over `max_packed_bytes` in all is `TooLarge({ bytes: <the new total>, from: Count })`.
	count : ArchiveRead, U64 -> Try(ArchiveRead, ArchiveRead.Refusal)
	count = |state, bytes| {
		total = state.packed + bytes
		if total > max_packed_bytes {
			Err(TooLarge({ bytes: total, from: Count }))
		} else {
			Ok({ ..state, packed: total })
		}
	}

	## True while no refusal is kept: the effect code gives the decoded bytes to `push` only then.
	reading : ArchiveRead -> Bool
	reading = |state| state.refused.is_err()

	## Give decoded bytes (any size, also empty) to the tar reader. For each member (`Entry` event), in this order: a kind that is not `File` or `Dir`, or type `7`,
	## is `NotAFile` (row 12); a path that `Tar.check_portable_path` refuses is `BadPath`; a `path_key` seen before is `Duplicate`; a member below a file, or a file
	## above a member seen before, is `UnderFile` (row 17). An error of `Tar.push` is `BadTar`.
	## The first refusal is kept, and the state reads no more bytes. The `Content` of `main.roc` is the header file.
	push : ArchiveRead, List(U8) -> ArchiveRead
	push = |state, bytes| {
		if state.refused.is_ok() {
			return state
		}
		window_start = state.base - state.tail.len()
		window = state.tail.concat(bytes)
		after = { ..state, base: state.base + bytes.len(), tail: List.repeat(0, 0).concat(window.drop_first(if (window.len() > 512) window.len() - 512 else 0)) }
		match state.tar.push(bytes, choose) {
			Err(_) if bytes.len() > 512 => bytes.chunks_of(512).fold(state, |st, piece| push(st, piece))
			Err(e) => { ..after, refused: Ok(BadTar(e)) }
			Ok((t2, events)) => {
				var $s = { ..after, tar: t2 }
				for ev in events {
					if $s.refused.is_ok() {
						break
					}
					match ev {
						Entry(e) => {
							type7 = e.kind == File and window.get(e.offset + 156 - window_start) == Ok('7')
							$s = if (type7) { ..$s, refused: Ok(NotAFile({ path: e.path, kind: Other('7') })) } else check_member($s, e)
						}

						Content(e, data) => {
							if raw_key(e.path) == "main.roc" {
								$s = { ..$s, header: Ok(data) }
							}
						}
					}
				}
				$s
			}
		}
	}

	## Keep a zstd error of `Native.ZstdStream.push!` or `close!`: `WindowTooLarge` (row 3), else `BadZstd`. A refusal kept before stays.
	unzip_failed : ArchiveRead, [OutputLimit, WindowTooLarge, BadFrame, Truncated, Unsupported] -> ArchiveRead
	unzip_failed = |state, err| {
		if state.refused.is_ok() {
			state
		} else {
			refusal = match err {
				WindowTooLarge => WindowTooLarge
				OutputLimit => BadZstd(OutputLimit)
				BadFrame => BadZstd(BadFrame)
				Truncated => BadZstd(Truncated)
				Unsupported => BadZstd(Unsupported)
			}
			{ ..state, refused: Ok(refusal) }
		}
	}

	## The end of the read: the 32 bytes of the BLAKE3 digest and the hash of the URL. The order of the checks is in the module comment.
	## `Ok` gives the artifact record: `hash` (the hash of the URL), `size` (the packed byte count), the `Fields`, and `target_names`.
	finish : ArchiveRead, List(U8), Str -> Try(Artifact.Row, ArchiveRead.Refusal)
	finish = |state, digest, hash| {
		actual = Base58.encode(digest)
		if actual != hash {
			return Err(HashMismatch({ expected: hash, actual }))
		}
		match state.refused {
			Ok(r) => return Err(r)
			Err(None) => {}
		}
		_summary = state.tar.finish().map_err(|e| BadTar(e))?
		bytes = state.header ? |_| NoHeader
		f = header_fields(bytes)?
		Ok({ hash, kind: f.kind, exposed: f.exposed, platform_hash: f.platform_hash, roc_pin: f.roc_pin, size: state.packed, deps: f.deps, target_names: target_names(f.kind, state.paths) })
	}

	## Row 7, R-PK5, R-RE1, R-RE19, R-AP49: the fields of the bytes of `main.roc`, with `Header.parse` of roc-app-header and `PackageUrl.parse` for each dep.
	## A dep URL that `PackageUrl.parse` reads gives the group `url_form`, the series and the version `X.Y.Z`. A URL with no version (`NoVersion`) gives the group of
	## R-AP49 (the URL with no scheme and no last segment), and no series and no version. Row 14: a dep that does not start with `https://`, each other error of
	## `PackageUrl.parse`, and a hash that `Base58.decode` does not give as 32 bytes are `BadDep`.
	header_fields : List(U8) -> Try(ArchiveRead.Fields, ArchiveRead.Refusal)
	header_fields = |bytes| {
		text = Str.from_utf8(bytes) ? |_| BadHeader(NotUtf8)
		h = match Header.parse(text) {
			Ok(parsed) => parsed
			Err(NoHeader) => return Err(BadHeader(NoHeader))
			Err(BadHeader({ offset })) => return Err(BadHeader(BadHeader(offset)))
		}
		kind = match h.kind() {
			App => App
			Package => Package
			Platform(_) => Platform
		}
		var $platform = Err(None)
		var $pin = Err(None)
		var $deps = []
		for e in h.entries() {
			if e.name == "roc" {
				$pin = Ok(e.value)
			} else if e.is_platform and kind == App {
				$platform = Ok(dep_of(e.name, e.value)?.hash)
			} else {
				$deps = $deps.append(dep_of(e.name, e.value)?)
			}
		}
		Ok({ kind, exposed: if (kind == App) [] else h.exposed(), platform_hash: $platform, roc_pin: $pin, deps: $deps })
	}

	## Row 17: the key of a member path: the parts between `/` with no empty part, joined by `/`, each ASCII `A` to `Z` as `a` to `z`. `a//b`, `a/b/` and `A/B` have the key `a/b`.
	path_key : Str -> Str
	path_key = |path| Str.from_utf8(raw_key(path).to_utf8().map(|b| if (b >= 'A' and b <= 'Z') b + 32 else b)) ?? path

	## R-RE20, R-IK7: the target names of a platform: for each path `targets/<name>/<more>`, the `<name>` when it matches `[a-z0-9]{1,32}`
	## (`Code.is_new_target_name`, or a known target). Distinct, sorted by bytes. Empty for an app and a package. A name that does not match (`macos-sysroot`) is skipped (row 11).
	target_names : Code.Kind, List(Str) -> List(Str)
	target_names = |kind, paths| {
		if kind != Platform {
			return []
		}
		var $names = Set.empty()
		for p in paths {
			if p.starts_with("targets/") {
				match p.drop_prefix("targets/").split_first("/") {
					Ok({ before, .. }) if Code.is_new_target_name(before) => {
						$names = $names.insert(before)
					}

					_ => {}
				}
			}
		}
		$names.to_list().sort_with(Artifact.compare)
	}

	## The problem of a refusal (R-AP21): 422 `not-a-candidate` with the `detail` of the slice file (section 5) for each refusal. `HashMismatch` too (row 8).
	problem : ArchiveRead.Refusal -> Problem
	problem = |refusal| Problem.new(NotACandidate, detail(refusal))

	## The problem of a failed asset read: 502 `upstream` (a proposal; slice 112 can map a 404 in another way).
	upstream_problem : [Status(U16), NoAnswer, BodyRead] -> Problem
	upstream_problem = |err| Problem.new(
		Upstream,
		match err {
			Status(n) => "the asset read failed with status ${n.to_str()}"
			NoAnswer => "the asset read failed: no answer"
			BodyRead => "the asset read failed: the body stopped"
		},
	)
}

## The checks of one member (rows 6, 12, 17), in the order of `push`.
check_member : ArchiveRead, Tar.Entry -> ArchiveRead
check_member = |st, e| {
	refuse = |r| { ..st, refused: Ok(r) }
	match e.kind {
		File | Dir => {}
		other => return refuse(NotAFile({ path: e.path, kind: other }))
	}
	match Tar.check_portable_path(e.path) {
		Err(problem) => return refuse(BadPath({ path: e.path, problem }))
		Ok(_) => {}
	}
	k = ArchiveRead.path_key(e.path)
	if st.keys.contains(k) {
		return refuse(Duplicate(e.path))
	}
	parts = k.split_on("/")
	var $prefix = ""
	var $i = 0.U64
	for part in parts {
		$i = $i + 1
		if $i < parts.len() {
			$prefix = if ($prefix == "") part else "${$prefix}/${part}"
			match st.files.get($prefix) {
				Ok(f) => return refuse(UnderFile({ path: e.path, file: f }))
				Err(_) => {}
			}
		}
	}
	if e.kind == File {
		match st.below.get(k) {
			Ok(p) => return refuse(UnderFile({ path: p, file: e.path }))
			Err(_) => {}
		}
	}
	var $below = st.below
	var $pre = ""
	var $j = 0.U64
	for part in parts {
		$j = $j + 1
		if $j < parts.len() {
			$pre = if ($pre == "") part else "${$pre}/${part}"
			if !$below.contains($pre) {
				$below = $below.insert($pre, e.path)
			}
		}
	}
	{ ..st, keys: st.keys.insert(k, e.path), files: if (e.kind == File) st.files.insert(k, e.path) else st.files, below: $below, seen: st.seen.insert(e.path), paths: st.paths.append(e.path) }
}

## The parts between `/` with no empty part, joined by `/`, with no case fold.
raw_key : Str -> Str
raw_key = |path| Str.join_with(path.split_on("/").keep_if(|p| p != ""), "/")

dep_of : Str, Str -> Try(Artifact.Dep, ArchiveRead.Refusal)
dep_of = |alias, url| {
	bad = Err(BadDep({ alias, url }))
	if !url.starts_with("https://") {
		return bad
	}
	dep = dep_url(alias, url)?
	match Base58.decode(dep.hash) {
		Ok(b) if b.len() == 32 => Ok(dep)
		_ => bad
	}
}

dep_url : Str, Str -> Try(Artifact.Dep, ArchiveRead.Refusal)
dep_url = |alias, url| match PackageUrl.parse(url) {
	Ok(p) => {
		v = p.version()
		Ok({ alias, hash: p.hash(), group: p.url_form(), series: Ok(p.series()), version: Ok("${v.major.to_str()}.${v.minor.to_str()}.${v.patch.to_str()}"), url })
	}

	Err(NoVersion) => {
		rest = url.drop_prefix("https://").drop_prefix("http://")
		match rest.split_last("/") {
			Ok({ before, after }) if after.ends_with(".tar.zst") and after != ".tar.zst" => Ok({ alias, hash: after.drop_suffix(".tar.zst"), group: "${before}/", series: Err(None), version: Err(None), url })
			_ => Err(BadDep({ alias, url }))
		}
	}

	Err(_) => Err(BadDep({ alias, url }))
}

path_why : [EmptyPath, TooLong, Absolute, DriveLetter, ParentDir, DotPart, ReservedName, EndsWithSpace, EndsWithPeriod, ReservedChar(U8), Backslash] -> Str
path_why = |p| match p {
	EmptyPath => "empty"
	TooLong => "more than 255 bytes"
	Absolute => "absolute"
	DriveLetter => "a drive letter"
	ParentDir => "a .. part"
	DotPart => "a . part"
	ReservedName => "a Windows reserved name"
	EndsWithSpace => "a part ends with a space"
	EndsWithPeriod => "a part ends with a period"
	ReservedChar(b) => "the character ${Str.from_utf8([b]) ?? "?"}"
	Backslash => "a backslash"
}

detail : ArchiveRead.Refusal -> Str
detail = |r| match r {
	TooLarge({ bytes, from: ContentLength }) => "the asset has ${bytes.to_str()} bytes (Content-Length), more than the limit of 100000000 bytes"
	TooLargeHeader(text) => "the asset has more than 100000000 bytes (Content-Length ${text})"
	TooLarge({ bytes, from: Count }) => "the asset has more than the limit of 100000000 bytes (the read stopped at ${bytes.to_str()} bytes)"
	WindowTooLarge => "the zstd window of the asset is larger than 8388608 bytes"
	BadZstd(z) => {
		why = match z {
			BadFrame => "a damaged frame"
			Truncated => "the stream ends inside a frame"
			Unsupported => "a frame needs a dictionary"
			OutputLimit => "a block gives too many bytes"
		}
		"the asset is not a valid zstd stream: ${why}"
	}

	BadTar(e) => Tar.err_to_str(e)
	BadPath({ path, problem }) => "the archive has a path that roc unbundle refuses (${path_why(problem)}): ${path}"
	NotAFile({ path, kind }) => {
		what = match kind {
			Symlink => "a symbolic link"
			HardLink => "a hard link"
			Other(b) => "a member of type ${Str.from_utf8([b]) ?? "?"}"
			File | Dir => "a member"
		}
		"the archive has ${what}, not a file: ${path}"
	}

	Duplicate(path) => "the archive has the path ${path} two times"
	UnderFile({ path, file }) => "the archive has ${path} below the file ${file}"
	NoHeader => "the archive has no main.roc at its root"
	BadHeader(NotUtf8) => "main.roc has no valid header: it is not UTF-8"
	BadHeader(NoHeader) => "main.roc has no valid header: it starts with no app, package or platform header"
	BadHeader(BadHeader(offset)) => "main.roc has no valid header: the header stops to be valid at byte ${offset.to_str()}"
	BadDep({ alias, url }) => "main.roc has a header entry ${alias} that is not a package URL with a hash: ${url}"
	HashMismatch({ expected, actual }) => "the BLAKE3 hash of the asset is ${actual}, not the hash ${expected} of the URL"
}
