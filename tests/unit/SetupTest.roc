import lib.Args
import lib.Fail
import lib.Setup

SetupTest :: [].{}

# The expected value of each row is the design text or the slice file text, not the code (docs/slices/027-setup.md). A wrong row prints with `dbg`.
# Texts that the design does not give (the marker, the profile line, the completion text, the texts of failures) are the proposals of the slice file, section 6 (TW24).

usage = |text| Err(Fail.new(Usage, text))

# R-CM18, R-NI13, R-NI14: the flags of `setup`. No operand. `--yes`, `--json` and `--quiet` do not change the plan (they are in `Args`).
expect {
	read = |words| match Args.parse(words) {
		Ok(args) => Setup.read(args)
		Err(_) => Err(Fail.new(Internal, "the test words do not parse"))
	}
	rows = [
		("no flag", ["setup"], Ok({ replace_roc: Bool.False, no_modify_path: Bool.False })),
		("R-NI13: --replace-roc", ["setup", "--replace-roc"], Ok({ replace_roc: Bool.True, no_modify_path: Bool.False })),
		("R-NI14: --no-modify-path", ["setup", "--no-modify-path"], Ok({ replace_roc: Bool.False, no_modify_path: Bool.True })),
		("both, and the global flags", ["setup", "--yes", "--no-modify-path", "--json", "--quiet", "--replace-roc"], Ok({ replace_roc: Bool.True, no_modify_path: Bool.True })),
		("one operand", ["setup", "now"], usage("tln setup takes no operand, got 1")),
		("2 operands, flags between them", ["setup", "a", "--yes", "b"], usage("tln setup takes no operand, got 2")),
	]
	bad = rows.keep_if(|(_, words, want)| read(words) != want).map(|(label, words, want)| (label, want, read(words)))
	dbg bad
	bad == []
}

# R-ST1, R-ST13, R-ST14, R-ST15, R-ST2: the entries of the bin dir. `tln` and `roc` both come from the file `tln` (the launcher is the same binary, R-ST8, R-ST14). Each tool is its own file, in the order of `tools.json`. On Windows each name has `.exe`,
# also the source. The tool `talon` has no entry (its binary is `tln`). A tool that is named `tln` or `roc`, and a repeated name, is left out. `roc.old` is `roc.old.exe` on Windows.
expect {
	e = |entry, source| { entry, source }
	rows = [
		("R-ST13, R-ST14: no tool", Linux, [], [e("tln", "tln"), e("roc", "tln")]),
		("R-ST15: 2 tools, in order", Linux, ["foo", "bar"], [e("tln", "tln"), e("roc", "tln"), e("foo", "foo"), e("bar", "bar")]),
		("the entry talon of tools.json has no entry of its own", Macos, ["talon", "foo"], [e("tln", "tln"), e("roc", "tln"), e("foo", "foo")]),
		("a tool named tln or roc, and a repeat, is left out", Linux, ["roc", "foo", "tln", "foo"], [e("tln", "tln"), e("roc", "tln"), e("foo", "foo")]),
		("R-ST1: Windows, each name has .exe", Windows, ["foo"], [e("tln.exe", "tln.exe"), e("roc.exe", "tln.exe"), e("foo.exe", "foo.exe")]),
		("another system is a Unix", Other("freebsd"), ["foo"], [e("tln", "tln"), e("roc", "tln"), e("foo", "foo")]),
	]
	bad = rows.keep_if(|(_, os, tools, want)| Setup.names({ os, tools }) != want).map(|(label, os, tools, want)| (label, want, Setup.names({ os, tools })))
	dbg bad
	old = [Setup.old_roc(Linux), Setup.old_roc(Macos), Setup.old_roc(Windows), Setup.old_roc(Other("x"))]
	dbg old
	bad == [] and old == ["roc.old", "roc.old", "roc.old.exe", "roc.old"]
}

# R-LY8, R-ST1: the bin dir is `<HOME>/.local/bin` on Linux and macOS, `<USERPROFILE>\.local\bin` on Windows (as uv). A variable that is not set or is empty is `Environment` (exit 18).
# HOME is not used on Windows, USERPROFILE not on Linux.
expect {
	env = |pairs| pairs
	rows = [
		("R-LY8: Linux", Linux, env([("HOME", "/home/u")]), Ok("/home/u/.local/bin")),
		("a / at the end of HOME", Macos, env([("HOME", "/Users/u/")]), Ok("/Users/u/.local/bin")),
		("R-LY8: Windows", Windows, env([("USERPROFILE", "C:\\Users\\u"), ("HOME", "/wrong")]), Ok("C:\\Users\\u\\.local\\bin")),
		("a \\ at the end of USERPROFILE", Windows, env([("USERPROFILE", "C:\\Users\\u\\")]), Ok("C:\\Users\\u\\.local\\bin")),
		("Linux does not read USERPROFILE", Linux, env([("USERPROFILE", "C:\\Users\\u")]), Err(Fail.new(Environment, "HOME is not set"))),
		("an empty HOME", Linux, env([("HOME", "")]), Err(Fail.new(Environment, "HOME is not set"))),
		("Windows with no USERPROFILE", Windows, env([("HOME", "/h")]), Err(Fail.new(Environment, "USERPROFILE is not set"))),
	]
	bad = rows.keep_if(|(_, os, vars, want)| Setup.bin_dir({ os, env: vars }) != want).map(|(label, os, vars, want)| (label, want, Setup.bin_dir({ os, env: vars })))
	dbg bad
	bad == []
}

# R-ST11, R-ST6, R-ST7, R-ST12: the ownership test and what follows. An entry is Talon's only when its sha256 equals the one of its source. A missing entry is made. A Talon entry that is up to date is kept (nothing is written: setup can run again).
# A file with other content, a directory and a file that cannot be read are foreign: Talon never overwrites them (R-ST6). A source that is missing gives no entry.
expect {
	s = Sha("aa")
	rows = [
		("R-ST7: no entry", s, Absent, Make),
		("R-ST11: the same sha256 is Talon's", s, Sha("aa"), Keep),
		("R-ST6: another content is foreign", s, Sha("bb"), Foreign),
		("R-ST6: a directory is foreign", s, Dir, Foreign),
		("R-ST6: an unreadable file is foreign", s, Unreadable, Foreign),
		("no source file, no entry", Missing, Absent, NoSource),
		("no source file, and an entry that is there", Missing, Sha("aa"), NoSource),
	]
	bad = rows.keep_if(|(_, source, have, want)| Setup.judge({ source, have }) != want).map(|(label, source, have, want)| (label, want, Setup.judge({ source, have })))
	dbg bad
	bad == []
}

# R-ST4, R-ST3: the `PATH` tests. `on_path`: the bin dir is a part of `PATH` (an empty part and a `/` at the end do not matter). `shadow`: a `roc` file in a part of `PATH` before the first part that is the bin dir. The files of `found` are in the order of
# `PATH` (`Fx.path_roc!`). A `roc` in the bin dir itself is not a shadow. A `roc` after the bin dir is not. When the bin dir is not on `PATH` nothing comes before it (question Q3).
expect {
	bin = "/home/u/.local/bin"
	on = |path| Setup.on_path({ path, dir: bin })
	shadow = |path, found| Setup.shadow({ path, dir: bin, found })
	on_rows = [
		("R-ST4: first", "${bin}:/usr/bin", Bool.True),
		("last", "/usr/bin:${bin}", Bool.True),
		("a / at the end, an empty part", "/usr/bin::${bin}/:", Bool.True),
		("not on PATH", "/usr/bin:/bin", Bool.False),
		("a longer path is not the dir", "${bin}/x:/usr/bin", Bool.False),
		("a shorter path is not the dir", "/home/u/.local:/usr/bin", Bool.False),
		("an empty PATH", "", Bool.False),
	]
	shadow_rows = [
		("R-ST3: /usr/local/bin/roc comes first", "/usr/local/bin:${bin}:/usr/bin", ["/usr/local/bin/roc"], Ok("/usr/local/bin/roc")),
		("the first of two", "/opt/a:/opt/b:${bin}", ["/opt/a/roc", "/opt/b/roc"], Ok("/opt/a/roc")),
		("a roc after the bin dir is no shadow", "${bin}:/usr/local/bin", ["/usr/local/bin/roc"], Err(None)),
		("the roc in the bin dir is no shadow", "/usr/bin:${bin}", ["${bin}/roc"], Err(None)),
		("the roc of the bin dir is skipped, a shadow before it is found", "/usr/local/bin:${bin}", ["/usr/local/bin/roc", "${bin}/roc"], Ok("/usr/local/bin/roc")),
		("a // before roc, as path_roc writes a PATH part with a /", "/usr/local/bin/:${bin}", ["/usr/local/bin//roc"], Ok("/usr/local/bin//roc")),
		("the bin dir is not on PATH: nothing is before it (Q3)", "/usr/local/bin:/usr/bin", ["/usr/local/bin/roc"], Err(None)),
		("no roc file", "/usr/bin:${bin}", [], Err(None)),
	]
	bad_on = on_rows.keep_if(|(_, path, want)| on(path) != want).map(|(label, path, want)| (label, want, on(path)))
	bad_shadow = shadow_rows.keep_if(|(_, path, found, want)| shadow(path, found) != want).map(|(label, path, found, want)| (label, want, shadow(path, found)))
	dbg bad_on
	dbg bad_shadow
	bad_on == [] and bad_shadow == []
}

# R-ST4, R-ST5, R-LY9: the shell of the user and its files. `SHELL` gives the shell by its last path part. Another shell, an empty value and a name that only contains `bash` have no shell (question Q5). The profile and the completion file have
# a path under HOME. The line has the marker comment `# talon: added by tln setup` (CLI 6.5: `tln tool rm talon` finds it). The form of the line and the paths of the completions are proposals (questions Q5, Q6).
expect {
	home = "/home/u"
	dir = "/home/u/.local/bin"
	shells = [
		("/bin/bash", Ok(Bash)),
		("/usr/bin/zsh", Ok(Zsh)),
		("/usr/local/bin/fish", Ok(Fish)),
		("bash", Ok(Bash)),
		("/bin/tcsh", Err(Unknown)),
		("/bin/sh", Err(Unknown)),
		("/opt/mybash", Err(Unknown)),
		("", Err(Unknown)),
	]
	bad_shell = shells.keep_if(|(value, want)| Setup.shell_of(value) != want).map(|(value, want)| (value, want, Setup.shell_of(value)))
	profiles = [
		(Bash, "/home/u/.bashrc", "/home/u/.local/share/bash-completion/completions/tln", "export PATH=\"/home/u/.local/bin:\$PATH\" # talon: added by tln setup"),
		(Zsh, "/home/u/.zshrc", "/home/u/.local/share/zsh/site-functions/_tln", "export PATH=\"/home/u/.local/bin:\$PATH\" # talon: added by tln setup"),
		(Fish, "/home/u/.config/fish/conf.d/talon.fish", "/home/u/.config/fish/completions/tln.fish", "fish_add_path \"/home/u/.local/bin\" # talon: added by tln setup"),
	]
	bad_files = profiles.keep_if(
		|(shell, profile, completion, line)| Setup.profile({ home, shell }) != profile or Setup.completion_path({ home, shell }) != completion or Setup.path_line({ shell, dir }) != line,
	).map(|(shell, profile, completion, line)| (profile, completion, line, Setup.profile({ home, shell }), Setup.completion_path({ home, shell }), Setup.path_line({ shell, dir })))
	dbg bad_shell
	dbg bad_files
	bad_shell == [] and bad_files == []
}

# R-ST4, R-ST12: the edit of the profile and of the file of `GITHUB_PATH`. The marker line is in the profile already: `Keep`, also when it names another dir (setup changes only what is missing). Else the line is added at the end, with a line end
# before it when the old text has no last line end. No file: the line alone. `GITHUB_PATH` has the plain path of the dir, one for each line, and the same rules. The file of fish is the profile of fish (`talon.fish`), so it is the same function.
expect {
	dir = "/home/u/.local/bin"
	line = "export PATH=\"${dir}:\$PATH\" # talon: added by tln setup"
	fish = "fish_add_path \"${dir}\" # talon: added by tln setup"
	profile = |shell, existing| Setup.profile_edit({ shell, dir, existing })
	github = |existing| Setup.github_edit({ dir, existing })
	profile_rows = [
		("R-ST4: no file", Bash, Err(NotFound), Write("${line}\n")),
		("an empty file", Zsh, Ok(""), Write("${line}\n")),
		("a text with a last line end", Bash, Ok("alias a=b\n"), Write("alias a=b\n${line}\n")),
		("a text with no last line end", Bash, Ok("alias a=b"), Write("alias a=b\n${line}\n")),
		("R-ST12: the line is there", Bash, Ok("alias a=b\n${line}\nalias c=d\n"), Keep),
		("R-ST12: the marker is there with another dir", Zsh, Ok("export PATH=\"/old/bin:\$PATH\" # talon: added by tln setup\n"), Keep),
		("the dir without the marker is not the line of Talon", Bash, Ok("export PATH=\"${dir}:\$PATH\"\n"), Write("export PATH=\"${dir}:\$PATH\"\n${line}\n")),
		("fish: no file", Fish, Err(NotFound), Write("${fish}\n")),
		("fish: the line is there", Fish, Ok("${fish}\n"), Keep),
	]
	github_rows = [
		("R-ST4: no file", Err(NotFound), Write("${dir}\n")),
		("an empty file", Ok(""), Write("${dir}\n")),
		("other lines, a last line end", Ok("/a/bin\n"), Write("/a/bin\n${dir}\n")),
		("other lines, no last line end", Ok("/a/bin"), Write("/a/bin\n${dir}\n")),
		("R-ST12: the dir is a line", Ok("/a/bin\n${dir}\n"), Keep),
		("a longer path is not the dir", Ok("${dir}/x\n"), Write("${dir}/x\n${dir}\n")),
	]
	bad_profile = profile_rows.keep_if(|(_, shell, existing, want)| profile(shell, existing) != want).map(|(label, shell, existing, want)| (label, want, profile(shell, existing)))
	bad_github = github_rows.keep_if(|(_, existing, want)| github(existing) != want).map(|(label, existing, want)| (label, want, github(existing)))
	dbg bad_profile
	dbg bad_github
	bad_profile == [] and bad_github == []
}

# R-ST5, R-ST12: the completion text. It names each command of CLI 1 and the subcommands of `roc`, `tool` and `cache` (the words that `Args` knows), and it is the same text on each call (so a second setup writes nothing). The form of each shell is a proposal
# (question Q6): bash has `complete -F`, zsh starts with `#compdef tln`, fish has `complete -c tln`.
expect {
	commands = ["init", "install", "remove", "update", "upgrade", "outdated", "why", "probe", "list", "patch", "verify", "x", "publish", "audit", "roc", "tool", "cache", "setup", "yank", "move", "share"]
	subs = ["link", "use", "default", "rebuild", "gc", "clean", "dir"]
	words_of = |text| text.replace_each("\"", " ").replace_each("'", " ").replace_each("(", " ").replace_each(")", " ").replace_each(";", " ").replace_each("\n", " ").replace_each("\t", " ").split_on(" ")
	missing = |text| commands.concat(subs).keep_if(|word| !words_of(text).contains(word))
	bash = Setup.completion(Bash)
	zsh = Setup.completion(Zsh)
	fish = Setup.completion(Fish)
	dbg (missing(bash), missing(zsh), missing(fish))
	missing(bash) == [] and missing(zsh) == [] and missing(fish) == []
		and bash.contains("complete -F _tln tln") and zsh.starts_with("#compdef tln\n") and fish.contains("complete -c tln")
			and Setup.completion(Bash) == bash and bash != zsh and zsh != fish
}

# R-HF11, R-ST4, R-LY9: the Windows `Path` edit as a command line. `powershell -NoProfile -NonInteractive -Command <script>`. The dir is in the variable `TALON_BIN_DIR`, not in the script: a dir with a space, a quote, `$` or `%` needs no quoting, and the script
# is the same for each dir. The script reads the value with no expansion of `%VAR%` (`DoNotExpandEnvironmentNames`), writes it as `REG_EXPAND_SZ` (`ExpandString`), sends `WM_SETTINGCHANGE`, and never uses `setx` (it cuts the value at 1024 characters).
# `Add` and `Remove` are 2 scripts.
expect {
	dir = "C:\\Users\\A B\\it's\\%X%\\$y\\.local\\bin"
	add = Setup.windows_path({ dir, op: Add })
	remove = Setup.windows_path({ dir, op: Remove })
	other = Setup.windows_path({ dir: "D:\\bin", op: Add })
	script = |cmd| match cmd.argv {
		["powershell", "-NoProfile", "-NonInteractive", "-Command", text] => text
		_ => ""
	}
	has_all = |text| ["GetValue('Path', '', 'DoNotExpandEnvironmentNames')", "ExpandString", "WM_SETTINGCHANGE", "TALON_BIN_DIR"].all(|word| text.contains(word))
	registry = |text| text.contains("CurrentUser") and text.contains("'Environment'")
	dbg (add.argv.len(), add.env, remove.env)
	add.argv.len() == 5 and script(add) != "" and has_all(script(add)) and registry(script(add))
		and !script(add).contains("setx") and !script(add).contains(dir) and !script(add).contains("A B")
			and add.env == [("TALON_BIN_DIR", dir)] and remove.env == [("TALON_BIN_DIR", dir)]
				and script(add) == script(other) and script(add) != script(remove) and has_all(script(remove))
}

# R-ST1, R-ST11, R-TF1, R-TF2, R-TF3, R-TF6: the tool names in `tools.json` (question Q1: the form is a proposal). The names are the keys of the object `tools`, in the order of the text. No `tools` field gives no tool. A field that Talon does not know
# is no problem (R-TF2). A text that does not parse, or has no integer `format`, a `format` above 1, and a `tools` that is not an object are `Input` (exit 19). The file is named in the message.
expect {
	path = "/d/talon/tools.json"
	input = |text| Err(Fail.new(Input, text))
	rows = [
		("R-ST1: 2 tools, in order", "{\"format\":1,\"tools\":{\"foo\":{\"bin\":\"foo\"},\"bar\":{}}}", Ok(["foo", "bar"])),
		("the entry talon is a name like the others", "{\"format\":1,\"tools\":{\"talon\":{},\"foo\":{}}}", Ok(["talon", "foo"])),
		("no tools field", "{\"format\":1}", Ok([])),
		("an empty object", "{\"format\":1,\"tools\":{}}", Ok([])),
		("R-TF2: a field that Talon does not know", "{\"format\":1,\"next\":[1],\"tools\":{\"foo\":{}}}", Ok(["foo"])),
		("R-TF6: not JSON", "tools", input("${path}: the content does not parse")),
		("R-TF6: an array", "[]", input("${path}: the content does not parse")),
		("R-TF1: no format", "{\"tools\":{}}", input("${path}: the content does not parse")),
		("R-TF3: a newer format", "{\"format\":2,\"tools\":{}}", input("${path}: format 2 is newer than this tln (format 1). Run: tln tool update talon")),
		("tools is not an object", "{\"format\":1,\"tools\":[\"foo\"]}", input("${path}: tools is not an object")),
	]
	bad = rows.keep_if(|(_, text, want)| Setup.tool_names({ path, text }) != want).map(|(label, text, want)| (label, want, Setup.tool_names({ path, text })))
	dbg bad
	bad == []
}

# R-RM8 R-ST4 (slice 051): `tln tool remove talon --remove-tools` takes the line of `tln setup` out of the profile. `profiles` are the 3 files that `profile` can give (the shell of the day of `tln setup` is not known). `profile_strip` removes each line that has the marker (`# talon: added by tln setup`,
# whatever the dir in it) and keeps all other lines and their order. No such line: `Keep` (nothing is written). A file that has only that line is the empty text. The text of the last line does not change (a final line end stays, a missing one stays missing).
expect {
	line = Setup.path_line({ shell: Bash, dir: "/h/.local/bin" })
	fish_line = Setup.path_line({ shell: Fish, dir: "/h/.local/bin" })
	strip = |text| match Setup.profile_strip(text) {
		Keep => "keep"
		Write(new) => "write ${Str.inspect(new)}"
	}
	rows = [
		("R-RM8: the 3 profiles", Str.join_with(Setup.profiles({ home: "/h" }), " "), "/h/.bashrc /h/.zshrc /h/.config/fish/conf.d/talon.fish"),
		("no marker: keep", strip("# mine\nalias ll='ls -l'\n"), "keep"),
		("the empty text: keep", strip(""), "keep"),
		("the line in the middle", strip("# mine\n${line}\nalias ll='ls -l'\n"), "write ${Str.inspect("# mine\nalias ll='ls -l'\n")}"),
		("the line is the last, with a line end", strip("# mine\n${line}\n"), "write ${Str.inspect("# mine\n")}"),
		("the line is the last, with no line end", strip("# mine\n${line}"), "write ${Str.inspect("# mine")}"),
		("only the line", strip("${line}\n"), "write \"\""),
		("the fish line", strip("# fish\n${fish_line}\n"), "write ${Str.inspect("# fish\n")}"),
		("2 lines with the marker, each goes", strip("${line}\nx\n${fish_line}\ny\n"), "write ${Str.inspect("x\ny\n")}"),
		("the marker with another dir", strip("export PATH=\"/other:\$PATH\" # talon: added by tln setup\n"), "write \"\""),
		("a line that only names talon stays", strip("# talon is nice\nexport T=1\n"), "keep"),
	]
	bad = rows.keep_if(|(_, got, want)| got != want)
	dbg bad
	bad == []
}
