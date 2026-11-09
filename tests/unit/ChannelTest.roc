import lib.Channel

ChannelTest :: [].{}

# Slice 238 (docs/slices/238-channel-tables.md), R-CH1 R-CH2 R-CH3, Design Q612 (G-C242).
# `Channel` is a new module and the two functions are new names (a proposal for the code agent): until they exist, this file does not compile (red on purpose, as slice 236 did).
# `Channel.name_check : Str -> Try({}, [BadName, Reserved])`  (R-CH3: the syntax first, then the reserved list)
# `Channel.builtin : Str -> Try({ shape : Str, source : Str, tag_prefix : Str }, [NotBuiltIn])`  (R-CH2: the built-in tables; the record fields are those of shape `github-release`, R-CH4)

# R-CH3: names that are valid and not reserved.
expect {
	names = ["reify", "ab", "a1", "my-fork", "my-fork-2", "a-b", "abcdefghijklmnopqrstuvwx", "x0"]
	got = names.map(|n| Channel.name_check(n))
	dbg got
	got == names.map(|_| Ok({}))
}

# R-CH3: the syntax `[a-z][a-z0-9-]*`, 2 to 24 characters, no `-` at the end.
expect {
	names = ["", "a", "abcdefghijklmnopqrstuvwxy", "Reify", "reIfy", "1ab", "-ab", "ab-", "a--", "a_b", "a b", "a.b", "a/b", "réify", "ab\n"]
	got = names.map(|n| Channel.name_check(n))
	dbg got
	got == names.map(|_| Err(BadName))
}

# R-CH3 R-CH1: the nine reserved names.
expect {
	names = ["nightly", "stable", "git", "link", "copy", "zig", "debug", "local", "compat"]
	got = names.map(|n| Channel.name_check(n))
	dbg got
	got == names.map(|_| Err(Reserved))
}

# R-CH3: a name that only starts with a reserved word is free; a reserved word with a suffix or a prefix is a valid name.
expect {
	names = ["nightly2", "my-nightly", "gitx", "stable-1", "zigzag", "locals"]
	got = names.map(|n| Channel.name_check(n))
	dbg got
	got == names.map(|_| Ok({}))
}

# R-CH2 R-CH1: the built-in table `nightly`.
expect {
	got = Channel.builtin("nightly")
	dbg got
	got == Ok({ shape: "github-release", source: "roc-lang/nightlies", tag_prefix: "nightly-" })
}

# R-CH1: a user name is no built-in table. `stable` is reserved and has no table yet (Design 6.8, R-CH1: "later").
expect {
	got = ["reify", "stable", "git", ""].map(|n| Channel.builtin(n))
	dbg got
	got == [Err(NotBuiltIn), Err(NotBuiltIn), Err(NotBuiltIn), Err(NotBuiltIn)]
}

# Design Q613 items 4 and 5 (R-CH10): `Channel.compare` (the equality of the two files; the name is the one of the code agent).
# Equal known keys in another order and with other spaces: equal. An unknown key (a warning) is not compared. A name in one file only: no check.
good = "[channels.reify]\nshape = \"github-release\"\nsource = \"a/b\"\ntag-prefix = \"x-\"\n"

compare = |talon, config| match Channel.compare({ talon: { path: "/p/talon.toml", text: talon }, config: { path: "/c/config.toml", text: config } }) {
	Ok(_) => Ok({})
	Err(f) => Err((f.kind.code(), f.message))
}

expect {
	other_order = "# a comment\n[channels.reify]\ntag-prefix =   \"x-\"\nsource = \"a/b\"\nshape = \"github-release\"\n"
	extra_key = "${good}color = \"red\"\n"
	other_name = "[channels.mine]\nshape = \"github-release\"\nsource = \"c/d\"\ntag-prefix = \"y-\"\n"
	got = [compare(good, other_order), compare(extra_key, good), compare(good, extra_key), compare(good, other_name), compare("", good), compare(good, "")]
	dbg got
	got == [Ok({}), Ok({}), Ok({}), Ok({}), Ok({}), Ok({})]
}

# Design Q613 item 4: a known key that differs (each of the three) is exit 19, no hint line. The text is a proposal (TW24).
expect {
	rows = [
		"shape = \"github-release\"\nsource = \"a/b\"\ntag-prefix = \"z-\"\n",
		"shape = \"github-release\"\nsource = \"a/c\"\ntag-prefix = \"x-\"\n",
	]
	got = rows.map(|r| compare("[channels.reify]\n${r}", good))
	want = rows.map(|_| Err((19, "/p/talon.toml:1: channels.reify is not equal to channels.reify in /c/config.toml:1")))
	dbg got
	got == want
}
