import lib.LogPath
import lib.Route
import lib.Client
import lib.Problem
import records.Tlog

LogPathTest :: [].{}

# W0 tests of worker/lib/LogPath.roc, of the `/log/` rows of worker/lib/Route.roc (`decide_log`) and of `Client.is_checked` (slice 257d, docs/slices/257-log-tiles.md section 3.5).
# R-AP11 (the paths, the methods), R-AP48 rows 1 and 2 (404 before 405, no body check), R-AP45 and Design Q636 (no client check), R-AP23 and R-AP43 (the cache headers, the Cache API).
# The vectors are written by hand from C2SP tlog-tiles and from `Tlog.path` (slice 257a, 3-digit groups with `x`); no vector comes from the code under test.

tile : [Hashes(U8), Entries], U64, U64 -> Try(LogPath.Target, [BadPath])
tile = |level, index, width| Ok(Tile({ level, index, width }))

bad : Try(LogPath.Target, [BadPath])
bad = Err(BadPath)

# The text after `/log/` as the segments of the request (`Request.segments` splits at `/` and drops the empty items; the tests that need an empty item give the list).
parse : Str -> Try(LogPath.Target, [BadPath])
parse = |text| LogPath.parse(text.split_on("/"))

# --- the good paths: the checkpoint ---

# R-AP11
expect LogPath.parse(["checkpoint"]) == Ok(Checkpoint)

# --- the good paths: hash tiles (R-AP11, C2SP tlog-tiles; N in 3-digit groups, an `x` before each group but the last) ---

# R-AP11: the full tiles at level 0, the 3-digit groups.
expect parse("tile/0/000") == tile(Hashes(0), 0, 256)
expect parse("tile/0/001") == tile(Hashes(0), 1, 256)
expect parse("tile/0/067") == tile(Hashes(0), 67, 256)
expect parse("tile/0/999") == tile(Hashes(0), 999, 256)
expect parse("tile/0/x001/000") == tile(Hashes(0), 1000, 256)
expect parse("tile/0/x001/234") == tile(Hashes(0), 1234, 256)
expect parse("tile/0/x999/999") == tile(Hashes(0), 999999, 256)
expect parse("tile/0/x001/x000/000") == tile(Hashes(0), 1000000, 256)
expect parse("tile/0/x001/x234/067") == tile(Hashes(0), 1234067, 256)
expect parse("tile/0/x012/x345/x678/901") == tile(Hashes(0), 12345678901, 256)

# R-AP11: the levels 0 to 63 (Design 257a S4: no leading zero).
expect parse("tile/1/000") == tile(Hashes(1), 0, 256)
expect parse("tile/2/x001/234") == tile(Hashes(2), 1234, 256)
expect parse("tile/7/000") == tile(Hashes(7), 0, 256)
expect parse("tile/8/000") == tile(Hashes(8), 0, 256)
expect parse("tile/9/000") == tile(Hashes(9), 0, 256)
expect parse("tile/10/000") == tile(Hashes(10), 0, 256)
expect parse("tile/63/000") == tile(Hashes(63), 0, 256)

# R-AP11: the partial tiles: `.p/<W>` after the last group, W from 1 to 255.
expect parse("tile/0/000.p/1") == tile(Hashes(0), 0, 1)
expect parse("tile/0/000.p/7") == tile(Hashes(0), 0, 7)
expect parse("tile/0/000.p/10") == tile(Hashes(0), 0, 10)
expect parse("tile/0/000.p/128") == tile(Hashes(0), 0, 128)
expect parse("tile/0/000.p/254") == tile(Hashes(0), 0, 254)
expect parse("tile/0/000.p/255") == tile(Hashes(0), 0, 255)
expect parse("tile/0/x001/234.p/7") == tile(Hashes(0), 1234, 7)
expect parse("tile/0/x001/x234/067.p/255") == tile(Hashes(0), 1234067, 255)
expect parse("tile/3/x001/234.p/200") == tile(Hashes(3), 1234, 200)

# --- the good paths: entry bundles ---

# R-AP11: `tile/entries/<N>[.p/<W>]`.
expect parse("tile/entries/000") == tile(Entries, 0, 256)
expect parse("tile/entries/x001/234") == tile(Entries, 1234, 256)
expect parse("tile/entries/x001/x234/067") == tile(Entries, 1234067, 256)
expect parse("tile/entries/000.p/3") == tile(Entries, 0, 3)
expect parse("tile/entries/x001/234.p/255") == tile(Entries, 1234, 255)

# R-AP11: the largest index (U64) is 7 groups.
expect parse("tile/0/x018/x446/x744/x073/x709/x551/615") == tile(Hashes(0), 18446744073709551615, 256)
expect parse("tile/entries/x018/x446/x744/x073/x709/x551/615.p/1") == tile(Entries, 18446744073709551615, 1)

# --- the round trip with `Tlog.path` (257a): every path that the writer makes is a path that the reader serves, to the same tile ---

round_ok : Tlog.Tile -> Bool
round_ok = |t| LogPath.parse(Tlog.path(t).split_on("/")) == Ok(Tile(t)) and LogPath.key(Tile(t)) == Tlog.path(t)

levels : List([Hashes(U8), Entries])
levels = [Hashes(0), Hashes(1), Hashes(2), Hashes(7), Hashes(10), Hashes(63), Entries]

indexes : List(U64)
indexes = [0, 1, 9, 10, 67, 99, 100, 255, 256, 257, 999, 1000, 1001, 1234, 99999, 100000, 999999, 1000000, 1234067, 4294967296, 18446744073709551615]

widths : List(U64)
widths = [1, 2, 3, 9, 10, 99, 100, 128, 254, 255, 256]

# R-AP11, R-SG4
expect levels.all(|level| indexes.all(|index| widths.all(|width| round_ok({ level, index, width }))))

# --- the bad paths: each is `Err(BadPath)` (R-AP48 row 1: 404, no R2 read) ---

# The segments: none, another first word, a case, the checkpoint with more.
expect LogPath.parse([]) == bad
expect parse("Checkpoint") == bad
expect parse("CHECKPOINT") == bad
expect parse("checkpoints") == bad
expect parse("checkpoint.p/1") == bad
expect LogPath.parse(["checkpoint", ""]) == bad
expect LogPath.parse(["checkpoint", "x"]) == bad
expect LogPath.parse(["checkpoint", "tile"]) == bad
expect parse("tile") == bad
expect parse("tiles/0/000") == bad
expect parse("Tile/0/000") == bad
expect parse("log/checkpoint") == bad
expect parse("v1/checkpoint") == bad
expect parse("entries/000") == bad
expect parse("tile/entries") == bad

# An empty segment, a segment with a slash (an extra slash that reached the segments), `.` and `..`.
expect LogPath.parse(["tile", "0", "", "000"]) == bad
expect LogPath.parse(["tile", "", "0", "000"]) == bad
expect LogPath.parse(["", "tile", "0", "000"]) == bad
expect LogPath.parse(["tile", "0", "000", ""]) == bad
expect LogPath.parse(["tile", "0/000"]) == bad
expect LogPath.parse(["tile/0/000"]) == bad
expect LogPath.parse(["tile", "0", "x001/234"]) == bad
expect LogPath.parse(["checkpoint/"]) == bad
expect LogPath.parse(["tile", "0", "000/"]) == bad
expect LogPath.parse(["tile", "0", "..", "000"]) == bad
expect LogPath.parse(["tile", "..", "checkpoint"]) == bad
expect LogPath.parse(["..", "tile", "0", "000"]) == bad
expect LogPath.parse(["tile", ".", "000"]) == bad
expect LogPath.parse(["tile", "0", "000", ".."]) == bad
expect LogPath.parse(["tile", "0", "..%2F000"]) == bad
expect LogPath.parse(["tile", "0", "..\\000"]) == bad

# The level: 64 or more, a leading zero, a sign, not a digit, empty, `entries` with another case, no level.
expect parse("tile/64/000") == bad
expect parse("tile/65/000") == bad
expect parse("tile/100/000") == bad
expect parse("tile/255/000") == bad
expect parse("tile/256/000") == bad
expect parse("tile/99999999999999999999/000") == bad
expect parse("tile/00/000") == bad
expect parse("tile/01/000") == bad
expect parse("tile/007/000") == bad
expect parse("tile/-1/000") == bad
expect parse("tile/+1/000") == bad
expect parse("tile/a/000") == bad
expect parse("tile/0x1/000") == bad
expect parse("tile/1.0/000") == bad
expect parse("tile/ 0/000") == bad
expect parse("tile/0 /000") == bad
expect LogPath.parse(["tile", "", "000"]) == bad
expect parse("tile/Entries/000") == bad
expect parse("tile/ENTRIES/000") == bad
expect parse("tile/entrie/000") == bad
expect parse("tile/entriess/000") == bad
expect parse("tile/000") == bad
expect parse("tile/x001/234") == bad

# The index groups: 1 to 7 groups of exactly 3 ASCII digits; an `x` before each group but the last, and only there.
expect parse("tile/0") == bad
expect parse("tile/0/00") == bad
expect parse("tile/0/0") == bad
expect parse("tile/0/0000") == bad
expect parse("tile/0/1234") == bad
expect parse("tile/0/x1000/001") == bad
expect parse("tile/0/x01/234") == bad
expect parse("tile/0/x001/23") == bad
expect parse("tile/0/x001/2345") == bad
expect parse("tile/0/x001") == bad
expect parse("tile/0/x") == bad
expect parse("tile/0/x/234") == bad
expect parse("tile/0/x001/x234") == bad
expect parse("tile/0/x001/x234/x067") == bad
expect parse("tile/0/001/234") == bad
expect parse("tile/0/001/x234") == bad
expect parse("tile/0/001/234/067") == bad
expect parse("tile/0/x001/234/067") == bad
expect parse("tile/0/X001/234") == bad
expect parse("tile/0/xx001/234") == bad
expect parse("tile/0/x001/x234/x067/x890") == bad
expect parse("tile/0/x00a/234") == bad
expect parse("tile/0/00a") == bad
expect parse("tile/0/-01") == bad
expect parse("tile/0/+01") == bad
expect parse("tile/0/ 01") == bad
expect parse("tile/0/01 ") == bad
expect parse("tile/0/0.1") == bad
expect parse("tile/0/0x1") == bad
expect parse("tile/entries/x001") == bad
expect parse("tile/entries/x001/x234") == bad
expect parse("tile/entries") == bad
expect parse("tile/entries/001/234") == bad
expect parse("tile/entries/0000") == bad

# A leading zero group: N has the least groups (67 is `067`, not `x000/067`).
expect parse("tile/0/x000/067") == bad
expect parse("tile/0/x000/000") == bad
expect parse("tile/0/x000/x000/067") == bad
expect parse("tile/0/x001/x000/000") == tile(Hashes(0), 1000000, 256)
expect parse("tile/entries/x000/000") == bad

# 8 groups, and a number above U64.
expect parse("tile/0/x001/x001/x001/x001/x001/x001/x001/001") == bad
expect parse("tile/0/x018/x446/x744/x073/x709/x551/616") == bad
expect parse("tile/0/x018/x447/x000/000/000/000/000") == bad
expect parse("tile/0/x999/x999/x999/x999/x999/x999/999") == bad
expect parse("tile/entries/x018/x446/x744/x073/x709/x551/616") == bad
expect parse("tile/entries/x100/x000/x000/x000/x000/x000/000") == bad

# The width: only `.p/<W>` after the last group, W 1 to 255, no leading zero, no sign.
expect parse("tile/0/000.p") == bad
expect parse("tile/0/000.p/") == bad
expect LogPath.parse(["tile", "0", "000.p", ""]) == bad
expect parse("tile/0/000.p/0") == bad
expect parse("tile/0/000.p/256") == bad
expect parse("tile/0/000.p/257") == bad
expect parse("tile/0/000.p/300") == bad
expect parse("tile/0/000.p/1000") == bad
expect parse("tile/0/000.p/99999999999999999999") == bad
expect parse("tile/0/000.p/01") == bad
expect parse("tile/0/000.p/001") == bad
expect parse("tile/0/000.p/00") == bad
expect parse("tile/0/000.p/-1") == bad
expect parse("tile/0/000.p/+1") == bad
expect parse("tile/0/000.p/ 1") == bad
expect parse("tile/0/000.p/1 ") == bad
expect parse("tile/0/000.p/1.0") == bad
expect parse("tile/0/000.p/0x1") == bad
expect parse("tile/0/000.p/a") == bad
expect parse("tile/0/000.p/1/2") == bad
expect parse("tile/0/000.p/1/") == bad
expect parse("tile/0/000.p/1.p/1") == bad
expect parse("tile/0/000.P/1") == bad
expect parse("tile/0/000.q/1") == bad
expect parse("tile/0/000.pp/1") == bad
expect parse("tile/0/000p/1") == bad
expect parse("tile/0/000.p.p/1") == bad
expect parse("tile/0/000.p.1") == bad
expect parse("tile/0/000.1") == bad
expect parse("tile/0/.p/1") == bad
expect parse("tile/0/x001/.p/1") == bad
expect parse("tile/0/x001.p/234/1") == bad
expect parse("tile/0/x001.p/1/234") == bad
expect parse("tile/entries/000.p/0") == bad
expect parse("tile/entries/000.p/256") == bad
expect parse("tile/entries/x001/234.p/256") == bad
expect parse("tile/entries/000.p") == bad
expect parse("tile/entries/000.p/1/2") == bad

# Not ASCII: a full-width or Arabic-Indic digit is not a digit here, a trailing byte, a percent escape (the Worker compares the decoded text, so `%30` is `0` before it gets here, and a text `%30` is not a digit).
expect LogPath.parse(["tile", "0", "０００"]) == bad
expect LogPath.parse(["tile", "０", "000"]) == bad
expect LogPath.parse(["tile", "0", "000.p", "１"]) == bad
expect LogPath.parse(["tile", "0", "000.p", "١"]) == bad
expect parse("tile/%30/000") == bad
expect parse("tile/0/%30%30%30") == bad
expect parse("tile/0/000%00") == bad
expect parse("tile/0/000\n") == bad
expect parse("tile/0/000\t.p/1") == bad

# --- the key, the cache headers, the Cache API (R-AP11, R-AP23, Design Q636, Q257-12) ---

# Design Q257-7: the R2 key is the path after `/log/`.
expect LogPath.key(Checkpoint) == "checkpoint"
expect LogPath.key(Tile({ level: Hashes(0), index: 1234, width: 7 })) == "tile/0/x001/234.p/7"
expect LogPath.key(Tile({ level: Entries, index: 0, width: 256 })) == "tile/entries/000"
expect LogPath.key(Tile({ level: Hashes(2), index: 1234067, width: 256 })) == "tile/2/x001/x234/067"

# R-AP11: the checkpoint is `max-age=5`. Every tile, a full one, a partial one and an entry bundle, is `max-age=31536000, immutable`.
expect LogPath.cache_control(Checkpoint) == "max-age=5"
expect LogPath.cache_control(Tile({ level: Hashes(0), index: 0, width: 256 })) == "max-age=31536000, immutable"
expect LogPath.cache_control(Tile({ level: Hashes(1), index: 5, width: 3 })) == "max-age=31536000, immutable"
expect LogPath.cache_control(Tile({ level: Entries, index: 5, width: 255 })) == "max-age=31536000, immutable"
expect LogPath.cache_control(Tile({ level: Entries, index: 5, width: 256 })) == "max-age=31536000, immutable"

# Design Q636, Q257-12: a tile is in the Cache API of the colo, the checkpoint is not.
expect LogPath.in_cache_api(Checkpoint) == Bool.False
expect LogPath.in_cache_api(Tile({ level: Hashes(0), index: 0, width: 256 })) == Bool.True
expect LogPath.in_cache_api(Tile({ level: Hashes(0), index: 0, width: 7 })) == Bool.True
expect LogPath.in_cache_api(Tile({ level: Entries, index: 3, width: 256 })) == Bool.True
expect LogPath.in_cache_api(Tile({ level: Entries, index: 3, width: 1 })) == Bool.True

# --- Route.decide: the `/log/` rows (R-AP11, R-AP48 rows 1 and 2) ---

input = |method, segments| { method, segments, content_type: Err(NotFound), has_body: Bool.False }

not_allowed = |method, path| NotAllowed(Problem.new(MethodNotAllowed, "${method} is not allowed on ${path}"), ["GET", "HEAD"])

no_route = |method, path| Refuse(Problem.new(NotFound, "no route for ${method} ${path}"))

# R-AP11: `GET` and `HEAD` of the checkpoint and of a tile are served.
expect Route.decide(input("GET", ["log", "checkpoint"])) == Handle(GetLogCheckpoint)
expect Route.decide(input("HEAD", ["log", "checkpoint"])) == Handle(GetLogCheckpoint)
expect Route.decide(input("GET", ["log", "tile", "0", "000"])) == Handle(GetLogTile("tile/0/000"))
expect Route.decide(input("HEAD", ["log", "tile", "0", "000"])) == Handle(GetLogTile("tile/0/000"))
expect Route.decide(input("GET", ["log", "tile", "0", "x001", "234.p", "7"])) == Handle(GetLogTile("tile/0/x001/234.p/7"))
expect Route.decide(input("GET", ["log", "tile", "2", "x001", "x234", "067"])) == Handle(GetLogTile("tile/2/x001/x234/067"))
expect Route.decide(input("GET", ["log", "tile", "entries", "000"])) == Handle(GetLogTile("tile/entries/000"))
expect Route.decide(input("HEAD", ["log", "tile", "entries", "x001", "234.p", "255"])) == Handle(GetLogTile("tile/entries/x001/234.p/255"))

# R-AP48 row 2, R-AP21: another method is 405 with `Allow: GET, HEAD` (the order of the list is the order of the header). The method text is case sensitive.
expect Route.decide(input("POST", ["log", "checkpoint"])) == not_allowed("POST", "/log/checkpoint")
expect Route.decide(input("PUT", ["log", "checkpoint"])) == not_allowed("PUT", "/log/checkpoint")
expect Route.decide(input("DELETE", ["log", "checkpoint"])) == not_allowed("DELETE", "/log/checkpoint")
expect Route.decide(input("PATCH", ["log", "checkpoint"])) == not_allowed("PATCH", "/log/checkpoint")
expect Route.decide(input("OPTIONS", ["log", "checkpoint"])) == not_allowed("OPTIONS", "/log/checkpoint")
expect Route.decide(input("get", ["log", "checkpoint"])) == not_allowed("get", "/log/checkpoint")
expect Route.decide(input("head", ["log", "checkpoint"])) == not_allowed("head", "/log/checkpoint")
expect Route.decide(input("BREW", ["log", "checkpoint"])) == not_allowed("BREW", "/log/checkpoint")
expect Route.decide(input("POST", ["log", "tile", "0", "000"])) == not_allowed("POST", "/log/tile/0/000")
expect Route.decide(input("DELETE", ["log", "tile", "0", "x001", "234.p", "7"])) == not_allowed("DELETE", "/log/tile/0/x001/234.p/7")
expect Route.decide(input("PUT", ["log", "tile", "entries", "000"])) == not_allowed("PUT", "/log/tile/entries/000")

# R-AP48 row 2 before row 5, Design Q636 (no body check): a body with a media type that is not JSON is still 405, and a `GET` with a body is served.
expect Route.decide({ method: "POST", segments: ["log", "checkpoint"], content_type: Ok("text/plain"), has_body: Bool.True }) == not_allowed("POST", "/log/checkpoint")
expect Route.decide({ method: "POST", segments: ["log", "tile", "0", "000"], content_type: Err(NotFound), has_body: Bool.True }) == not_allowed("POST", "/log/tile/0/000")
expect Route.decide({ method: "GET", segments: ["log", "checkpoint"], content_type: Ok("text/plain"), has_body: Bool.True }) == Handle(GetLogCheckpoint)

# R-AP48 row 1 before row 2: a bad path is 404 for each method, also for one that the route does not serve, and with a body.
expect Route.decide(input("GET", ["log"])) == no_route("GET", "/log")
expect Route.decide(input("POST", ["log"])) == no_route("POST", "/log")
expect Route.decide(input("GET", ["log", "checkpoint", "x"])) == no_route("GET", "/log/checkpoint/x")
expect Route.decide(input("GET", ["log", "Checkpoint"])) == no_route("GET", "/log/Checkpoint")
expect Route.decide(input("GET", ["Log", "checkpoint"])) == no_route("GET", "/Log/checkpoint")
expect Route.decide(input("GET", ["logs", "checkpoint"])) == no_route("GET", "/logs/checkpoint")
expect Route.decide(input("GET", ["v1", "log", "checkpoint"])) == no_route("GET", "/v1/log/checkpoint")
expect Route.decide(input("HEAD", ["log", "tile", "0", "000.p", "0"])) == no_route("HEAD", "/log/tile/0/000.p/0")
expect Route.decide(input("GET", ["log", "tile", "0", "000.p", "256"])) == no_route("GET", "/log/tile/0/000.p/256")
expect Route.decide(input("GET", ["log", "tile", "64", "000"])) == no_route("GET", "/log/tile/64/000")
expect Route.decide(input("GET", ["log", "tile", "0", "x1000", "001"])) == no_route("GET", "/log/tile/0/x1000/001")
expect Route.decide(input("GET", ["log", "tile", "entries", "x001"])) == no_route("GET", "/log/tile/entries/x001")
expect Route.decide(input("GET", ["log", "tile", "0", "..", "000"])) == no_route("GET", "/log/tile/0/../000")
expect Route.decide(input("POST", ["log", "tile", "0", "000.p", "0"])) == no_route("POST", "/log/tile/0/000.p/0")
expect Route.decide(input("DELETE", ["log", "tile", "64", "000"])) == no_route("DELETE", "/log/tile/64/000")
expect Route.decide({ method: "POST", segments: ["log", "tile", "01", "000"], content_type: Ok("text/plain"), has_body: Bool.True }) == no_route("POST", "/log/tile/01/000")

# R-AP11: a segment that holds a slash is not one path element (a `%2F` that the request gave as one segment).
expect Route.decide(input("GET", ["log", "tile/0/000"])) == no_route("GET", "/log/tile/0/000")
expect Route.decide(input("GET", ["log", "tile", "0/000"])) == no_route("GET", "/log/tile/0/000")

# --- Client.is_checked: no check of the client version for the log (R-AP45, Design Q636), a check for every other route ---

expect Client.is_checked(GetLogCheckpoint) == Bool.False
expect Client.is_checked(GetLogTile("tile/0/000")) == Bool.False
expect Client.is_checked(GetLogTile("tile/entries/x001/234.p/7")) == Bool.False
expect [Client.is_checked(PostClosure), Client.is_checked(GetToolchains), Client.is_checked(GetReleases), Client.is_checked(GetPackages), Client.is_checked(GetMe)].all(|b| b)
expect [Client.is_checked(PostRelease), Client.is_checked(GetRepoReleases("o", "r")), Client.is_checked(GetArtifact("h")), Client.is_checked(PutToolchain("t")), Client.is_checked(GetSweep("t"))].all(|b| b)
