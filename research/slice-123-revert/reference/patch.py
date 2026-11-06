# Reference patch of slice 123 on a copy of the repository (argument: the copy dir). Stages: S1 headers, S2 the type byte of roc-tar 0.0.2.
import sys, re, pathlib
B = pathlib.Path(sys.argv[1]) / "worker"
P2 = "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.2/f352LLRKJCZ4JJVEocp3H9e4e6Sxa6Ym5CxZ1GZCpfd.tar.zst"
P3 = "https://github.com/Karakatiza666/roc-cloudflare-workers/releases/download/0.0.3/Bup7G6Xgk53Bot1YY9AKQP9e73JVGbWqUyqD24taUYRv.tar.zst"
T1 = "https://github.com/Karakatiza666/roc-tar/releases/download/0.0.1/FGAUE1Pds7Fvd48GkrAYd9rRUpztew8bgUZjUrKPGyo7.tar.zst"
T2 = "https://github.com/Karakatiza666/roc-tar/releases/download/0.0.2/ynGk61syE32Lobjgwd3ZNRURf78xPGxr8Nzi1bSuhUr.tar.zst"

def sub(path, old, new, count=1):
    p = B / path
    s = p.read_text()
    if old not in s:
        if new in s:
            print(f"patch: {path}: already done, skipped: {old[:50]!r}")
            return
        sys.exit(f"patch: {path}: text not found: {old[:60]!r}")
    p.write_text(s.replace(old, new) if count == 0 else s.replace(old, new, count))

# S1: headers
for f in ["main.roc", "archive-test.roc", "lib/main.roc", "tests/unit/w0.roc"]:
    p = B / f
    s = p.read_text().replace(P2, P3).replace(T1, T2)
    p.write_text(s)

# S2 (skipped when the code agent has done it: the file uses entry.type_byte): the type byte of roc-tar 0.0.2 (no tail of 511 bytes)
DO2 = "entry.type_byte" not in (B / "lib/ArchiveRead.roc").read_text()
def sub2(*args):
    if DO2:
        sub(*args)
a = "lib/ArchiveRead.roc"
sub2(a, "\t# The count of the decoded bytes, and the last 511 of them (for the type byte of a member, see `type_byte`).\n\tdecoded : U64,\n\ttail : List(U8),\n", "")
sub2(a, "\t\tdecoded: 0,\n\t\ttail: [],\n", "")
sub2(a, """				base = state.decoded - state.tail.len()
				next = { ..state, tar, decoded: state.decoded + bytes.len(), tail: tail_of(state.tail, bytes) }
				events.fold(next, |s, event| if (reading(s)) on_event(s, event, |offset| type_byte(state.tail, bytes, offset + 156 - base)) else s)""",
    "\t\t\t\tnext = { ..state, tar }\n\t\t\t\tevents.fold(next, |s, event| if (reading(s)) on_event(s, event) else s)")
if DO2:
    p = B / a
    t = p.read_text()
    i1 = t.index("# The last 511 decoded bytes after"); j1 = t.index("# The checks of one event of the tar reader")
    p.write_text(t[:i1] + t[j1:])
sub2(a, "on_event : ArchiveRead, Tar.Event, (U64 -> U8) -> ArchiveRead\non_event = |state, event, type_at|", "on_event : ArchiveRead, Tar.Event -> ArchiveRead\non_event = |state, event|")
sub2(a, "check_member(state, entry, type_at)", "check_member(state, entry)")
sub2(a, "check_member : ArchiveRead, Tar.Entry, (U64 -> U8) -> Try(ArchiveRead, ArchiveRead.Refusal)\ncheck_member = |state, entry, type_at|", "check_member : ArchiveRead, Tar.Entry -> Try(ArchiveRead, ArchiveRead.Refusal)\ncheck_member = |state, entry|")
sub2(a, """	# roc-tar 0.0.1 gives `File` also for type 7 (contiguous). Read the type byte of the header until roc-tar keeps it (slice 111, row 12).
	kind = if (entry.kind == File and type_at(entry.offset) == '7') Other('7') else entry.kind""",
    """	# roc-tar gives `File` also for type 7 (contiguous). `entry.type_byte` tells it apart (roc-tar 0.0.2, row 12).
	kind = if (entry.type_byte == '7') Other('7') else entry.kind""")

# S3: Shorts.parse_query on Request.query_all (the stub of the test agent gets its body; parse_url stays, unused)
sub("lib/Shorts.roc", "	parse_query = |_shorts, _qs| crash \"todo\"\n", '''	parse_query = |shorts, qs| {
		count = shorts.len()
		if count > short_limit {
			Err(TooMany(count))
		} else if count > 0 and !qs.is_empty() {
			bad("the query parameters short and q must not be used together")
		} else if shorts.any(|v| v == "") {
			bad("the query parameter short must not be empty")
		} else if qs.len() > 1 {
			bad("the query parameter q must not be given more than once")
		} else {
			match qs {
				[""] => bad("the query parameter q must not be empty")
				[q] => Ok(Search(q))
				_ => if (count > 0) Ok(Short(shorts)) else bad("GET /v1/packages needs the query parameter short or q")
			}
		}
	}
''')
sub("ShortRoutes.roc", "match Shorts.parse_url(req.url()) {", 'match Shorts.parse_query(req.query_all("short"), req.query_all("q")) {')

# S4: ZstdStream.feed! in a loop, parts of ArchiveRead.feed_bytes
sub("lib/ArchiveRead.roc", "	feed_bytes = 0\n", "	feed_bytes = 65536\n")
_skip_archive = "feed!" in (B / "Archive.roc").read_text()
(lambda *a: None if _skip_archive else sub(*a))("Archive.roc", """					if $state.reading() {
						$state = match z.push!(c) {
							Ok(out) => $state.push(out)
							Err(BadHandle) | Err(WrongTask) => return Err(Fault("zstd push"))
							Err(OutputLimit) => $state.unzip_failed(OutputLimit)
							Err(WindowTooLarge) => $state.unzip_failed(WindowTooLarge)
							Err(BadFrame) => $state.unzip_failed(BadFrame)
							Err(Truncated) => $state.unzip_failed(Truncated)
							Err(Unsupported) => $state.unzip_failed(Unsupported)
						}
					}
""", """					var $input = c
					var $go = $state.reading()
					while $go {
						match z.feed!($input, ArchiveRead.feed_bytes) {
							Ok(part) => {
								$state = $state.push(part.out)
								$input = []
								$go = part.more and $state.reading()
							}
							Err(BadHandle) | Err(WrongTask) => return Err(Fault("zstd feed"))
							Err(WindowTooLarge) => {
								$state = $state.unzip_failed(WindowTooLarge)
								$go = Bool.False
							}
							Err(BadFrame) => {
								$state = $state.unzip_failed(BadFrame)
								$go = Bool.False
							}
							Err(Truncated) => {
								$state = $state.unzip_failed(Truncated)
								$go = Bool.False
							}
							Err(Unsupported) => {
								$state = $state.unzip_failed(Unsupported)
								$go = Bool.False
							}
						}
					}
""")

# S5: the JWKS Memo is only a bound above the rule of Oidc.key_for (1 h, `age > max_age_ms`): on one clock a Memo of exactly 1 h expires at 1 h, the rule at 1 h + 1 ms
sub("Auth.roc", 'Memo.new("github-jwks", { max_age_ms: 3_600_000 })', 'Memo.new("github-jwks", { max_age_ms: 7_200_000 })')

# S6 (Q441, R-PU38 row 5): all decoded bytes count, the limit is 285,212,672 bytes; over it the read stops (refusal TooLargeUnpacked)
a = "lib/ArchiveRead.roc"
DO6 = "TooLargeUnpacked" not in (B / a).read_text()
def sub6(*args):
    if DO6:
        sub(*args)
sub6(a, "	header : Try(List(U8), [None]),\n", "	decoded : U64,\n	header : Try(List(U8), [None]),\n")
sub6(a, "		header: Err(None),\n", "		decoded: 0,\n		header: Err(None),\n")
sub6(a, "	max_header_bytes : U64\n", "	max_decoded_bytes : U64\n	max_decoded_bytes = 285212672\n\n	max_header_bytes : U64\n")
sub6(a, "		# Row 4\n		HashMismatch(", "		# Row 5, Design Q441: all decoded bytes over `max_decoded_bytes`\n		TooLargeUnpacked(U64),\n		# Row 4\n		HashMismatch(")
sub6(a, "		match state.tar.push(bytes, choose) {", """		total = state.decoded + bytes.len()
		if total > max_decoded_bytes {
			return { ..state, refused: Ok(TooLargeUnpacked(max_decoded_bytes)) }
		}
		match state.tar.push(bytes, choose) {""")
sub6(a, "next = { ..state, tar }", "next = { ..state, tar, decoded: total }")
sub6(a, "	HashMismatch({ expected, actual }) =>", '	TooLargeUnpacked(limit) => "the unpacked archive has more than ${limit.to_str()} bytes"\n	HashMismatch({ expected, actual }) =>')

# S7 (Q440, R-AP82): on_trap in Worker.new, written inline
sub("main.roc", "worker = Worker.new({ fetch!: fetch!,", """trap_problem : U16, Str, Str, Str, List({ name : Str, value : Str }) -> Worker.Fixed
trap_problem = |status, type, title, detail, extra| {
	status,
	headers: [{ name: "content-type", value: "application/problem+json" }, { name: "cache-control", value: "no-store" }].concat(extra),
	body: Str.to_utf8("{\\"type\\":\\"${type}\\",\\"title\\":\\"${title}\\",\\"status\\":${status.to_str()},\\"detail\\":\\"${detail}\\"}"),
}

trap_internal = trap_problem(500, "/errors/internal", "Internal error", "a fault in the Worker", [])
trap_oom = trap_problem(503, "/errors/busy", "Busy", "the Worker has no memory for this request", [])
trap_shed = trap_problem(503, "/errors/busy", "Busy", "the Worker is busy: send the request again", [])
trap_cpu = trap_problem(503, "/errors/busy", "Busy", "the request used its CPU budget", [])
trap_deadline = trap_problem(503, "/errors/busy", "Busy", "the request used its time budget", [])
trap_stop = trap_problem(503, "/errors/busy", "Busy", "the Worker stopped the request", [])

worker = Worker.new({ fetch!: fetch!, on_trap: { default: trap_internal, crashed: trap_internal, oom: trap_oom, shed: trap_shed, cpu: trap_cpu, deadline: trap_deadline, alarm: trap_stop, cancelled: trap_stop, event: trap_internal, failed: trap_internal },""")

# S8 (slice 123d, Q463): Busy in the Worker Problem type (the 3 stub rows, in the order kebab, status, title)
_p = B / "lib/Problem.roc"
_t = _p.read_text()
for _v in ['"busy"', '503', '"Busy"']:
    _t = _t.replace('Busy => crash "todo"', 'Busy => ' + _v, 1)
_p.write_text(_t)
