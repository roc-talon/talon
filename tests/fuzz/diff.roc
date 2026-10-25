app [target] {
	fuzz: platform "https://github.com/lukewilliamboswell/roc-fuzz/releases/download/0.4.3/41NK5FShyGC9Z8HNpUdUeXMWwLmLNfFxsfmLvdPL4Fxb.tar.zst",
	lib: "../../cli/lib/main.roc",
}

import fuzz.Fuzz
import lib.Diff

# l1-runs: 20000
# L1 target of slice 042 (TESTING.md 4, the patch row): a random text and a random edit of it, through `Diff.make` and `Diff.apply`. The oracle of the length is a table of the longest common run of lines, written here
# (a second implementation, no code of `Diff`). One run checks these properties of one input. The first words of a crash text are the rule ids.
#
# | Property | Rule |
# | --- | --- |
# | The diff of `a` to `b` put on `a` gives `b` (the round trip). The same texts give no change. The edits: lines kept, deleted, replaced, inserted after a line, swapped with the next line, lines at the top, a final line end that is there or not, an empty text on either side | R-PA7 R-PA3 |
# | The hunks hold their numbers: `old_len` and `new_len` are the counts of the lines of the hunk, the hunk starts at the line `old_start`, the first and the last hunk have 3 lines of context or reach the end of the text, 2 runs of changes with 7 kept lines between them are 2 hunks (the lines between 2 hunks are never 0), a run of kept lines inside a hunk has 6 lines or fewer, the deleted lines of a run come before its inserted lines | R-PA7 |
# | The script is the shortest: the lines `Del` and `Ins` of all hunks are the old lines and the new lines less 2 times the longest common run of lines | R-PA7 |
#
# The lines of a text are all different (`a0`, `a1`, ..., and fresh lines `x0`, `x1`, ...): a hunk fits at one place, so the rule of 2 places (question Q2 of the slice file) does not decide anything here.

# `ops` has one number for each line of `a`: 0 keeps the line, 1 deletes it, 2 replaces it with a fresh line, 3 keeps it and adds a fresh line after it, 4 swaps it with the next line. `lead` is the number of fresh lines at the top of `b`.
# `flags` bit 0: `a` has a final line end. Bit 1: `b` has a final line end.
Raw : { ops : List(U8), lead : U8, flags : U8 }

generator : Fuzz.Generator(Raw)
generator = { ops: Fuzz.list(Fuzz.u8_in(0, 4), 26), lead: Fuzz.u8_in(0, 4), flags: Fuzz.u8_in(0, 3) }.Fuzz

fresh : U64 -> Str
fresh = |k| "x${k.to_str()}"

# The lines of `b` from the lines of `a` and the numbers of `ops`.
edited : { a : List(Str), ops : List(U8), lead : U64 } -> List(Str)
edited = |x| {
	n = x.a.len()
	var $b = List.repeat("", x.lead).map_with_index(|_, i| fresh(i))
	var $k = x.lead
	var $i = 0
	while $i < n {
		line = x.a.get($i) ?? ""
		next = x.a.get($i + 1) ?? ""
		match (x.ops.get($i) ?? 0) % 5 {
			1 => {}
			2 => {
				$b = $b.append(fresh($k))
				$k = $k + 1
			}
			3 => {
				$b = $b.append(line).append(fresh($k))
				$k = $k + 1
			}
			4 => if $i + 1 < n {
				$b = $b.append(next).append(line)
				$i = $i + 1
			} else {
				$b = $b.append(line)
			}
			_ => {
				$b = $b.append(line)
			}
		}
		$i = $i + 1
	}
	$b
}

# The text of the lines: each line has a line end, except the last one when `ending` is false.
text_of : List(Str), Bool -> Str
text_of = |ls, ending| {
	body = Str.join_with(ls, "\n")
	if ls.is_empty() "" else if ending "${body}\n" else body
}

# The lines of a text as `Diff` sees them: each has its own line end, except the last one of a text that has none.
lines_of : Str -> List(Str)
lines_of = |t| {
	parts = t.split_on("\n")
	match parts.last() {
		Ok("") => parts.drop_last(1).map(|p| "${p}\n")
		Ok(last) => parts.drop_last(1).map(|p| "${p}\n").append(last)
		Err(_) => []
	}
}

# The oracle: the length of the longest common run of lines, with the table of the suffixes (the lines are all different, so a plain DP is enough).
lcs : List(Str), List(Str) -> U64
lcs = |a, b| {
	var $row = List.repeat(0, b.len() + 1)
	for x in a.iter_rev() {
		var $new = [0]
		var $j = b.len()
		while $j > 0 {
			$j = $j - 1
			y = b.get($j) ?? ""
			diag = $row.get($j + 1) ?? 0
			down = $row.get($j) ?? 0
			right = $new.first() ?? 0
			cell = if x == y diag + 1 else if down >= right down else right
			$new = $new.prepend(cell)
		}
		$row = $new
	}
	$row.first() ?? 0
}

# The kept, deleted and inserted lines of a hunk, as numbers: the kind is 0, 1, 2.
kinds : Diff.Hunk -> List(U8)
kinds = |h| h.lines.map(
	|l| match l {
		Keep(_) => 0
		Del(_) => 1
		Ins(_) => 2
	},
)

# The runs of kept lines in a list of kinds, as `(length, touches the start, touches the end)`.
keep_runs : List(U8) -> List({ len : U64, first : Bool, last : Bool })
keep_runs = |ks| {
	var $runs = []
	var $len = 0
	var $start = 0.U64
	var $i = 0.U64
	for k in ks {
		if k == 0 {
			if $len == 0 {
				$start = $i
			}
			$len = $len + 1
		} else if $len > 0 {
			$runs = $runs.append({ len: $len, first: $start == 0, last: Bool.False })
			$len = 0
		}
		$i = $i + 1
	}
	if $len > 0 {
		$runs = $runs.append({ len: $len, first: $start == 0, last: Bool.True })
	}
	$runs
}

# A crash text for a hunk that breaks a rule, or the empty text.
hunk_fault : Diff.Hunk, U64 -> Str
hunk_fault = |h, old_total| {
	ks = kinds(h)
	runs = keep_runs(ks)
	old_len = ks.count_if(|k| k != 2)
	new_len = ks.count_if(|k| k != 1)
	lead = runs.find_first(|r| r.first) ?? { len: 0, first: Bool.False, last: Bool.False }
	trail = runs.find_first(|r| r.last) ?? { len: 0, first: Bool.False, last: Bool.False }
	starts_kept = match ks.first() {
		Ok(0) => Bool.True
		_ => Bool.False
	}
	ends_kept = match ks.last() {
		Ok(0) => Bool.True
		_ => Bool.False
	}
	lead_len = if starts_kept lead.len else 0
	trail_len = if ends_kept trail.len else 0
	inner = runs.keep_if(|r| !(r.first and starts_kept) and !(r.last and ends_kept))
	ends_text = h.old_len == 0 or h.old_start + h.old_len == old_total + 1
	if old_len != h.old_len or new_len != h.new_len {
		"R-PA7: the numbers of a hunk are not the counts of its lines"
	} else if lead_len > 3 or trail_len > 3 {
		"R-PA7: a hunk has more than 3 lines of context"
	} else if lead_len < 3 and h.old_start > 1 {
		"R-PA7: a hunk that does not start the text has less than 3 lines before its first change"
	} else if trail_len < 3 and !ends_text {
		"R-PA7: a hunk that does not end the text has less than 3 lines after its last change"
	} else if inner.any(|r| r.len > 6) {
		"R-PA7: a hunk has 7 kept lines or more between 2 changes (it must be 2 hunks)"
	} else if ks.map2(ks.drop_first(1), |x, y| x == 2 and y == 1).any(|bad| bad) {
		"R-PA7: an inserted line comes before a deleted line of the same run"
	} else {
		""
	}
}

test : Raw -> Fuzz.Outcome
test = |raw| {
	a = raw.ops.map_with_index(|_, i| "a${i.to_str()}")
	b = edited({ a, ops: raw.ops, lead: raw.lead.to_u64() })
	a_text = text_of(a, raw.flags % 2 == 1)
	b_text = text_of(b, raw.flags // 2 == 1)
	base = [{ path: "f", content: Utf8(a_text) }]
	made = Diff.make({ base, copy: [{ path: "f", content: Utf8(b_text) }] })
	applied = Diff.apply({ changes: made, target: base })
	if a_text == b_text {
		if made != [] or Diff.render(made) != "" or applied != { done: [], failed: [] } {
			crash "R-PA7: the same texts have a change"
		} else {
			Fuzz.keep
		}
	} else if applied != { done: [{ path: "f", what: Write(b_text) }], failed: [] } {
		crash "R-PA7: the diff on its own base does not give the copy"
	} else {
		hunks = match made {
			[Edit(one)] => one.hunks
			_ => []
		}
		old_lines = lines_of(a_text)
		new_lines = lines_of(b_text)
		fault = hunks.map(|h| hunk_fault(h, old_lines.len())).find_first(|f| f != "") ?? ""
		gaps_ok = hunks.map2(hunks.drop_first(1), |p, q| q.old_start > p.old_start + p.old_len).all(|ok| ok)
		changed = hunks.map(|h| kinds(h).count_if(|k| k != 0)).sum()
		if hunks.is_empty() {
			crash "R-PA7: 2 different texts have no hunk"
		} else if fault != "" {
			crash fault
		} else if !gaps_ok {
			crash "R-PA7: 2 hunks have no line between them"
		} else if changed != old_lines.len() + new_lines.len() - 2 * lcs(old_lines, new_lines) {
			crash "R-PA7: the script is not the shortest"
		} else {
			Fuzz.keep
		}
	}
}

target = Fuzz.target_with({
	name: "diff",
	generator,
	test,
	show: |raw| Str.inspect(raw),
})
