import lib.JsonDoc
import lib.RunPlan
import lib.ScriptsToml

OkexitTest :: [].{}

# Slice 087, `ok-exit` of a step (CLI 1: R-RUN1, R-RUN5, R-RUN7, R-RUN11, R-RUN18, R-RUN19). Part A: the read of a step table (`ScriptsToml.read`), the list of `tln run` (`RunPlan.list_text`, `RunPlan.list_data`) and the end of a step (`RunPlan.step_end`).

lines = |list| "${Str.join_with(list, "\n")}\n"

file = "/r/p/talon.toml"

# The list of a `[scripts]` text: the text and the `data` of `--json`, or the failure as `<code> <message>`.
list_view = |text| match ScriptsToml.read({ path: "talon.toml", text }) {
	Ok(scripts) => Ok((RunPlan.list_text({ file, scripts }), JsonDoc.render(RunPlan.list_data({ file, scripts }))))
	Err(e) => Err("${e.kind.code().to_str()} ${e.message}")
}

# Only the failure of a read, or `ok`.
read_fail = |text| match ScriptsToml.read({ path: "talon.toml", text }) {
	Ok(_) => "ok"
	Err(e) => "${e.kind.code().to_str()} ${e.message}"
}

table_msg = "a table step needs the string run, and can have the string in and ok-exit, no other key"

ok_msg = "ok-exit must be an array of 1 or more integers from 0 to 255"

# R-RUN1, R-RUN18, R-RUN11: a step table has `run` (required), and `in` and `ok-exit` (optional). `{ run }` alone is a plain step (a string in `data`). The list text adds ` (ok-exit = [<codes>])` (a proposal, R-OUT2).
# `data`: a step with `in` or `ok-exit` is `{ run, in, ok_exit }`, `null` for a key that the step does not have (a proposal, R-J4 style). 0 in `ok-exit` is allowed (0 is always a pass), and 255 is the highest code.
expect {
	text = lines([
		"[scripts]",
		"a = { run = \"tool-a\" }",
		"b = { run = \"roc build main.roc\", ok-exit = [2] }",
		"c = [{ in = \"d\", run = \"tool-c\", ok-exit = [0, 2, 255] }, \"tool-x\"]",
		"e = { in = \"d\", run = \"tool-e\" }",
		"f = [{ run = \"tool-f\", ok-exit = [0] }]",
	])
	list_view(text)
		== Ok((
			"scripts of /r/p/talon.toml\na:\n  tool-a\nb:\n  roc build main.roc (ok-exit = [2])\nc:\n  in d: tool-c (ok-exit = [0, 2, 255])\n  tool-x\ne:\n  in d: tool-e\nf:\n  tool-f (ok-exit = [0])\n",
			"{\"file\":\"/r/p/talon.toml\",\"scripts\":[{\"name\":\"a\",\"steps\":[\"tool-a\"]},{\"name\":\"b\",\"steps\":[{\"run\":\"roc build main.roc\",\"in\":null,\"ok_exit\":[2]}]},{\"name\":\"c\",\"steps\":[{\"run\":\"tool-c\",\"in\":\"d\",\"ok_exit\":[0,2,255]},\"tool-x\"]},{\"name\":\"e\",\"steps\":[{\"run\":\"tool-e\",\"in\":\"d\",\"ok_exit\":null}]},{\"name\":\"f\",\"steps\":[{\"run\":\"tool-f\",\"in\":null,\"ok_exit\":[0]}]}]}",
		))
}

# R-RUN18, R-RUN1 (exit code 19): `ok-exit` is an array of 1 or more integers from 0 to 255. An empty array, a value that is not an array, a string, a float, a code below 0 or above 255 give exit 19. The message names the script, and `[<n>]` for an item of an array (proposals).
expect {
	one = |v| read_fail("[scripts]\nn = { run = \"x\", ok-exit = ${v} }\n")
	bad = "19 talon.toml:2: scripts.n: ${ok_msg}"
	one("[]") == bad
		and one("2") == bad
			and one("[\"2\"]") == bad
				and one("[2.0]") == bad
					and one("[-1]") == bad
						and one("[256]") == bad
							and one("[2, 300]") == bad
								and one("[true]") == bad
									and one("[[2]]") == bad
										and read_fail("[scripts]\nn = [\"a\", { run = \"x\", ok-exit = [] }]\n") == "19 talon.toml:2: scripts.n[2]: ${ok_msg}"
											and one("[0]") == "ok"
												and one("[255]") == "ok"
}

# R-RUN18 (exit code 19): `ok-exit` with `run = "@<name>"`: the code of a script is the code of one of its steps, so `ok-exit` goes on that step. Also with `in`. The message names the script that the step runs (a proposal).
expect {
	read_fail("[scripts]\nb = \"x\"\nn = { run = \"@b\", ok-exit = [2] }\n") == "19 talon.toml:3: scripts.n: ok-exit is not allowed with run = \"@b\": put it on a step of the script b"
		and read_fail("[scripts]\nb = \"x\"\nn = [\"y\", { in = \"d\", run = \"@b\", ok-exit = [2] }]\n") == "19 talon.toml:3: scripts.n[2]: ok-exit is not allowed with run = \"@b\": put it on a step of the script b"
			and read_fail("[scripts]\nb = \"x\"\nn = { run = \"@b\" }\n") == "ok"
				and read_fail("[scripts]\nb = \"x\"\nn = { in = \"d\", run = \"@b\" }\n") == "ok"
}

# R-RUN1 (exit code 19): a table with no string `run`, an `in` that is not a string, or another key (a key that is near `ok-exit` too).
expect {
	one = |t| read_fail("[scripts]\nn = ${t}\n")
	bad = "19 talon.toml:2: scripts.n: ${table_msg}"
	one("{ ok-exit = [2] }") == bad
		and one("{ in = \"d\", ok-exit = [2] }") == bad
			and one("{ run = 2 }") == bad
				and one("{ run = \"x\", in = 1 }") == bad
					and one("{ run = \"x\", okexit = [2] }") == bad
						and one("{ run = \"x\", ok_exit = [2] }") == bad
							and one("{ run = \"x\", ok-exit = [2], more = 1 }") == bad
								and read_fail("[scripts]\nn = [\"a\", { run = \"x\", other = 1 }]\n") == "19 talon.toml:2: scripts.n[2]: ${table_msg}"
}

# What `RunPlan.step_end` gives: `pass <code>` or `fail <code>`, and ` | <note>` when there is a note. The text of the step is its words.
end_view = |words, ok_exit, ended| {
	e = RunPlan.step_end({ words, text: Str.join_with(words, " "), ok_exit, ended })
	head = "${if e.pass "pass" else "fail"} ${e.code.to_str()}"
	match e.note {
		Ok(note) => "${head} | ${note}"
		Err(None) => head
	}
}

hint = "tln: note: roc exits with 2 when it finds warnings and no errors; to accept them in this step, use { run = \"...\", ok-exit = [2] } (R-RUN18)"

accepted = |step, code| "tln: note: step \"${step}\" exited with ${code}; this is accepted as success by the ok-exit of the step"

# R-RUN5, R-RUN7, R-RUN18: a step passes with 0 or a code of its `ok-exit`. 0 is always a pass and gets no note. A pass with another code gets the note. A code that is not in the list fails with that code, and gets no note.
expect {
	end_view(["tool-a"], [], Exited(0)) == "pass 0"
		and end_view(["tool-a"], [2], Exited(0)) == "pass 0"
			and end_view(["roc", "build", "main.roc"], [2], Exited(2)) == "pass 2 | ${accepted("roc build main.roc", "2")}"
				and end_view(["tool-a"], [0, 2], Exited(2)) == "pass 2 | ${accepted("tool-a", "2")}"
					and end_view(["tool-a"], [2, 3], Exited(3)) == "pass 3 | ${accepted("tool-a", "3")}"
						and end_view(["tool-a"], [255], Exited(255)) == "pass 255 | ${accepted("tool-a", "255")}"
							and end_view(["roc", "build", "main.roc"], [2], Exited(1)) == "fail 1"
								and end_view(["tool-a"], [], Exited(3)) == "fail 3"
}

# R-RUN18, R-RUN7: a signal is a failure with 128 + the signal number, also when that number is in `ok-exit`. A code below 0 or above 255 (a Windows exception code) is a failure, also when its low byte is in `ok-exit`.
expect {
	end_view(["tool-a"], [130], Signaled(2)) == "fail 130"
		and end_view(["tool-a"], [], Signaled(15)) == "fail 143"
			and end_view(["tool-a"], [143, 0], Signaled(15)) == "fail 143"
				and end_view(["tool-a"], [130], Exited(130)) == "pass 130 | ${accepted("tool-a", "130")}"
					and end_view(["tool-a"], [2], Exited(258)) == "fail 258"
						and end_view(["tool-a"], [0], Exited(256)) == "fail 256"
							and end_view(["tool-a"], [], Exited(256)) == "fail 256"
								and end_view(["tool-a"], [5], Exited(-1073741819)) == "fail -1073741819"
									and end_view(["tool-a"], [255], Exited(-1)) == "fail -1"
}

# R-RUN19: the hint is for a step whose first word is `roc` and whose next word, after an optional `+<id>` selector (R-SC11), is `check`, `build` or `test`, that fails with 2 and has no `ok-exit`. No hint for `roc run`, `roc <file>.roc`, a `.roc` script, another program, another code, or a step with an `ok-exit` that does not have 2. The exit code does not change.
expect {
	end_view(["roc", "build", "main.roc"], [], Exited(2)) == "fail 2 | ${hint}"
		and end_view(["roc", "check", "main.roc"], [], Exited(2)) == "fail 2 | ${hint}"
			and end_view(["roc", "test", "main.roc", "--", "x"], [], Exited(2)) == "fail 2 | ${hint}"
				and end_view(["roc", "build"], [], Exited(2)) == "fail 2 | ${hint}"
					and end_view(["roc", "+nightly-2026-10-14-38a3029", "build", "main.roc"], [], Exited(2)) == "fail 2 | ${hint}"
						and end_view(["roc", "+nightly-2026-10-14-38a3029", "run", "main.roc"], [], Exited(2)) == "fail 2"
							and end_view(["roc", "run", "main.roc"], [], Exited(2)) == "fail 2"
								and end_view(["roc", "main.roc"], [], Exited(2)) == "fail 2"
									and end_view(["scripts/notes.roc", "--since", "v1"], [], Exited(2)) == "fail 2"
										and end_view(["tool-x", "build"], [], Exited(2)) == "fail 2"
											and end_view(["tln", "build"], [], Exited(2)) == "fail 2"
												and end_view(["roc", "build", "main.roc"], [], Exited(1)) == "fail 1"
													and end_view(["roc", "build", "main.roc"], [3], Exited(2)) == "fail 2"
														and end_view(["roc", "check", "main.roc"], [], Signaled(2)) == "fail 130"
}
