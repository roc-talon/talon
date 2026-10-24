#!/usr/bin/env python3
"""Slice 029b: split tests/commands/FakeFx.roc (868 lines) into FakeFx, FakeBase, FakeFiles, FakeJobs.
Reads research/slice-029b-revert/before/tests/commands/FakeFx.roc. No change in behavior."""
import re, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "research/slice-029b-revert/before/tests/commands/FakeFx.roc")
OUT = os.path.join(ROOT, "tests/commands")
L = open(SRC).read().split("\n")

def rng(a, b):  # 1-indexed, inclusive
    return L[a - 1:b]

def dedent(lines, n):
    out = []
    for l in lines:
        k = 0
        while k < n and l.startswith("\t"):
            l = l[1:]
            k += 1
        out.append(l)
    return out

BASE_FUNCS = ["log!", "read_or_empty!", "append!", "lines", "keep_empty", "exists!", "write_with_parents!", "create_item!"]

def qualify(text):
    for f in BASE_FUNCS:
        text = re.sub(r"(?<![\w.])" + re.escape(f) + r"\(", "FakeBase." + f + "(", text)
    return text

def field(a, b, name, sig, params):
    """A field of `make` (lines a..b, `name: |params| {` ... `},`) as a public function with `w` first."""
    body = dedent(rng(a, b), 1)
    first = body[0]
    assert first.lstrip().startswith(name + ":"), (name, first)
    rest = first.split("|", 2)  # name: | params | rest
    after = rest[2]
    body[0] = "\t" + name + " = |w, " + params + "|" + after
    assert body[-1].rstrip().endswith("},"), (name, body[-1])
    body[-1] = body[-1].rstrip()[:-1]
    return "\t" + name + " : Str, " + sig + "\n" + "\n".join(body)

def private(a, b):
    return "\n".join(rng(a, b))

def block(items):
    return "\n\n".join(items)

FILES_ERR = "[NotFound, Denied, Other(Str)]"

# ---------------- FakeBase
base = """import pf.Path

## Small helpers that the other `Fake*` modules share (the call log, reading a file, the text lines, the files that a fake call makes). No Talon logic (TW4).
FakeBase :: [].{

	## One line in `<w>/out/calls.log`.
	log! : Str, Str => {}
	log! = |w, line| append!("${w}/out/calls.log", "${line}\\n")

	## The text of a file, or the empty text when it cannot be read.
	read_or_empty! : Str => Str
	read_or_empty! = |path| match Path.read_utf8!(Path.utf8(path)) {
		Ok(text) => text
		Err(_) => ""
	}

	## The text is added at the end of the file.
	append! : Str, Str => {}
	append! = |path, text| {
		_ = Path.write_utf8!(Path.utf8(path), "${read_or_empty!(path)}${text}")
	}

	## The lines of a text, with the empty ones (an empty line is an answer: Enter). A last newline ends the last line.
	keep_empty : Str -> List(Str)
	keep_empty = |text| {
		parts = text.split_on("\\n")
		if parts.last() == Ok("") parts.drop_last(1) else parts
	}

	## The lines of a text, without the empty ones.
	lines : Str -> List(Str)
	lines = |text| text.split_on("\\n").keep_if(|l| !l.is_empty())

	exists! : Str => Bool
	exists! = |path| match Path.exists!(Path.utf8(path)) {
		Ok(b) => b
		Err(_) => Bool.False
	}

	## A write that creates the missing parent directories first (a decision of slice 002).
	write_with_parents! : Str, Str => Try({}, [PathErr(_, Path)])
	write_with_parents! = |file_path, content| {
		parent = Str.join_with(file_path.split_on("/").drop_last(1), "/")
		if !parent.is_empty() {
			_ = Path.create_all!(Path.utf8(parent))
		}
		Path.write_utf8!(Path.utf8(file_path), content)
	}

	## `file:<path>`, `dir:<path>` or `copy:<dest>=<source>`
	create_item! : Str => {}
	create_item! = |item| {
		if item.starts_with("dir:") {
			_ = Path.create_all!(Path.utf8(item.drop_prefix("dir:")))
		} else if item.starts_with("file:") {
			_ = write_with_parents!(item.drop_prefix("file:"), "fake")
		} else if item.starts_with("copy:") {
			match item.drop_prefix("copy:").split_on("=") {
				[dest, source] => {
					_ = write_with_parents!(dest, read_or_empty!(source))
				}
				_ => {}
			}
		}
	}
}
"""

# ---------------- FakeFiles
files_pub = [
    field(124, 137, "read_files!", "List(Str) => List(Try(Str, " + FILES_ERR + "))", "paths"),
    field(138, 162, "write_atomic!", "List({ path : Str, content : Str }) => Try({}, { path : Str, err : " + FILES_ERR + " })", "files"),
    field(165, 173, "list_dirs!", "List(Str) => List(Try(List({ name : Str, is_dir : Bool, mtime : U64 }), " + FILES_ERR + "))", "dirs"),
    field(174, 184, "tree_info!", "List(Str) => List(Try({ newest : U64, size : U64 }, " + FILES_ERR + "))", "paths"),
    field(185, 210, "delete!", "List(Str) => List(Try({}, " + FILES_ERR + "))", "paths"),
    field(211, 224, "canonical!", "List(Str) => List(Try(Str, " + FILES_ERR + "))", "paths"),
    field(256, 271, "rename!", "{ from : Str, to : Str } => Try({}, [NotFound, Exists, Denied, Other(Str)])", "move"),
    field(272, 285, "make_dirs!", "List(Str) => Try({}, [Denied, Other(Str)])", "dirs"),
    field(360, 368, "sha256_file!", "Str => Try(Str, " + FILES_ERR + ")", "path"),
]
copy_pub = [
    "\t" + "\n\t".join(dedent(rng(773, 785), 0)[0:1]) if False else None
]
def moved(a, b):
    """A top-level function of the old file moved into the type block."""
    return "\n".join("\t" + l if l else l for l in rng(a, b))
files_pub += [moved(773, 785), moved(787, 812), moved(814, 836)]
files_priv = [
    private(384, 412),
    private(414, 423).replace("## The answer of the fake `tree_info!` for one path (see the table at the top).", "## The answer of the fake `tree_info!` for one path (see the table in `FakeFx.roc`)."),
    private(425, 454),
    private(456, 463),
    private(465, 469),
    private(511, 516),
    private(838, 861),
]
files = ("import pf.Path\nimport lib.Text\nimport FakeBase\n\n"
         "## The file calls of the fake `Fx` (read, write, list, tree info, delete, canonical, rename, make dirs, copy, hard link, sha256). They read and write real files in the case dir `<w>`.\n"
         "## The table of the `fx/` files and the log lines is in the doc of `FakeFx`. Each call gets the case dir `w` first.\n"
         "FakeFiles :: [].{\n\n" + block(files_pub) + "\n}\n\n" + block(files_priv) + "\n")
files = qualify(files)
files = files.replace("(see the table at the top)", "(see the table in `FakeFx.roc`)")

# ---------------- FakeJobs
jobs_pub = [
    moved(524, 566).replace("\t## The answer of the fake `http_get!` (see the table at the top). The route is `<host>/<path>[?<query>]` of the URL.", "\t## The answer of the fake `http_get!` (see the table in `FakeFx.roc`). The route is `<host>/<path>[?<query>]` of the URL."),
    moved(569 - 1, 607),
    moved(730 - 1, 753),
    field(344, 359, "exec!", "{ argv : List(Str), env : List((Str, Str)) } => Try(I32, [NotStarted(Str)])", "run"),
]
jobs_priv = [
    private(609, 667),
    private(669, 674),
    private(676, 685),
    private(687, 701),
    private(703, 710),
    private(755, 771),
    private(863, 868),
]
jobs = ("import pf.Path\nimport lib.Probe\nimport FakeBase\n\n"
        "## The job calls of the fake `Fx` (http, spawn, probes, exec). The answers come from the files in `<w>/fx/`.\n"
        "## The table of the `fx/` files and the log lines is in the doc of `FakeFx`. Each call gets the case dir `w` first.\n"
        "FakeJobs :: [].{\n\n" + block(jobs_pub) + "\n}\n\n" + block(jobs_priv) + "\n")
jobs = qualify(jobs)
jobs = jobs.replace("(see the table at the top)", "(see the table in `FakeFx.roc`)")

# ---------------- FakeFx
head = "\n".join(rng(7, 95))
head = head.replace("## The fake `Fx` of L2 (TESTING.md 2.4).", "## The fake `Fx` of L2 (TESTING.md 2.4).", 1)
head += """
##
## Modules (slice 029b: the old file had 868 lines)
##
## | Module | Calls |
## | --- | --- |
## | `FakeFx` | The record, the table above, and the small calls: `args!`, `env_all!`, `cwd!`, `tty!`, `clock!`, `out!`, `err!`, `lock!`, `unlock!`, `programs!`, `random!`, `platform!`, `path_roc!`, `program_name!`, `ask!` |
## | `FakeFiles` | `read_files!`, `write_atomic!`, `list_dirs!`, `tree_info!`, `delete!`, `canonical!`, `rename!`, `make_dirs!`, `copy_tree!`, `copy_file!`, `hard_link!`, `sha256_file!` |
## | `FakeJobs` | `http_get!`, `spawn_all!`, `probes!`, `exec!` |
## | `FakeBase` | The call log, `read_or_empty!`, `append!`, the text lines, `write_with_parents!`, `create_item!` |"""
make = "\n".join(rng(96, 123)) + "\n"
# fields that stay or become a one line forward
keep = {
    "read_files!": ("FakeFiles", "paths"), "write_atomic!": ("FakeFiles", "files"), "list_dirs!": ("FakeFiles", "dirs"),
    "tree_info!": ("FakeFiles", "paths"), "delete!": ("FakeFiles", "paths"), "canonical!": ("FakeFiles", "paths"),
}
mk = []
mk += rng(96, 123)
mk.append("\t\tread_files!: |paths| FakeFiles.read_files!(w, paths),")
mk.append("\t\twrite_atomic!: |files| FakeFiles.write_atomic!(w, files),")
mk += rng(163, 164)
mk.append("\t\tlist_dirs!: |dirs| FakeFiles.list_dirs!(w, dirs),")
mk.append("\t\ttree_info!: |paths| FakeFiles.tree_info!(w, paths),")
mk.append("\t\tdelete!: |paths| FakeFiles.delete!(w, paths),")
mk.append("\t\tcanonical!: |paths| FakeFiles.canonical!(w, paths),")
mk += rng(225, 255)
mk.append("\t\trename!: |move| FakeFiles.rename!(w, move),")
mk.append("\t\tmake_dirs!: |dirs| FakeFiles.make_dirs!(w, dirs),")
mk += rng(286, 292)
mk.append("\t\tprobes!: |specs| FakeJobs.probes!(w, specs),")
mk.append("\t\tcopy_tree!: |move| FakeFiles.copy_tree!(w, move),")
mk.append("\t\tcopy_file!: |move| FakeFiles.copy_file!(w, move),")
mk.append("\t\thard_link!: |move| FakeFiles.hard_link!(w, move),")
mk += rng(297, 343)
mk.append("\t\texec!: |run| FakeJobs.exec!(w, run),")
mk.append("\t\tsha256_file!: |path| FakeFiles.sha256_file!(w, path),")
mk += rng(369, 382)
fx_body = "\n".join(mk)
fx_body = fx_body.replace("http_get!: |request| http_get!(w, request),", "http_get!: |request| FakeJobs.http_get!(w, request),")
fx_body = fx_body.replace("spawn_all!: |batch| spawn_all!(w, batch),", "spawn_all!: |batch| FakeJobs.spawn_all!(w, batch),")
fx_body = qualify(fx_body)
fx = ("import pf.Path\nimport lib.Fx\nimport lib.Lock\nimport FakeBase\nimport FakeFiles\nimport FakeJobs\n\n" + head + "\n" + fx_body + "\n\n" + private(505, 509) + "\n")
fx = fx.replace("(see the table at the top)", "(see the table above)")

for name, text in [("FakeBase", base), ("FakeFiles", files), ("FakeJobs", jobs), ("FakeFx", fx)]:
    with open(os.path.join(OUT, name + ".roc"), "w") as f:
        f.write(text)
    print(name, text.count("\n"))
