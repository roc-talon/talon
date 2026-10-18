#!/usr/bin/env python3
# Plant one mutation at a time in roc-toml package/, run the L0 test file(s) and
# the fuzz target(s) for that rule, restore the file, and print one result line
# per mutation.
# Usage: mutate-roc-toml.py ORIG_PACKAGE_DIR [M-ID ...]
# Env: MRUNS (default 20000) runs for each fuzz target. ALL=1 runs all L0 files
# and no fuzz target (the second pass for a mutation that is not caught).
import os, re, shutil, subprocess, sys, filecmp

HERE = os.path.dirname(os.path.abspath(__file__))
TALON = os.path.normpath(os.path.join(HERE, "../../.."))
# The package checkout is next to the Talon checkout.
REPO = os.environ.get("REPO", os.path.join(os.path.dirname(TALON), "roc-toml"))
ROC = os.environ.get("ROC", os.path.join(TALON, "cloudflare-workers/.cache/nightlies/nightly-2026-10-14-38a3029/roc"))
ORIG = sys.argv[1]  # the copy of package/ from step 0
W = os.path.join(REPO, ".work")
env = dict(os.environ, XDG_CACHE_HOME=W + "/xdg", ROC_CACHE_DIR=W + "/xdg/roc")
runs = os.environ.get("MRUNS", "20000")

V, X, G, D, T, P, E, K = (
    "Value.roc", "Internal/Text.roc", "Internal/Grammar.roc", "Internal/Doc.roc",
    "Internal/Tree.roc", "Internal/Print.roc", "Internal/Edit.roc", "Toml.roc",
)
C = "Internal/Check.roc"
# Slice 6 (0.2.0)
S6C = (["edit.roc", "entries.roc", "values.roc"], ["replace-date"])
S6E = (["edit.roc", "entries.roc"], ["replace-date"])
S6S = (["structure.roc"], ["parse-total"])
S1 = (["values.roc"], [])
S2 = (["structure.roc"], [])
S2I = (["structure.roc", "toml_test_invalid.roc"], [])
S2F = (["structure.roc"], ["parse-total"])
S3 = (["print.roc"], ["print-roundtrip"])
S4 = (["edit.roc"], [])
S4F = (["edit.roc"], ["replace-span"])
S4T = (["edit.roc"], ["text-kept"])
S5 = (["entries.roc"], [])
S5F = (["entries.roc"], ["remove-entry"])
# The second pass for a mutation that the slice files do not catch: all L0 files.
ALL = (["values.roc", "structure.roc", "toml_test_valid.roc", "toml_test_invalid.roc", "toml_test_roundtrip.roc", "print.roc", "edit.roc", "entries.roc"], [])

# (id and rule, file, old text, new text, (tests, fuzz targets))
M = [
    # Slice 1: value forms
    ("M1 V-STR2 escape \\f gives U+000B", G, "'f' => 0x0C", "'f' => 0x0B", S1),
    ("M2 V-STR5 surrogate \\uD800 accepted", G, "c < 0xD800 or", "c < 0xE000 or", S1),
    ("M3 ml literal: newline after ''' kept", G, ".skip(Utf8.string(\"'''\"))\n\t\t.skip(newline.maybe())", ".skip(Utf8.string(\"'''\"))", S1),
    ("M4 ml string: 5 quotes at close not accepted", G, "n >= 3 and n <= 5", "n >= 3 and n <= 4", S1),
    ("M5 V-STR15 (Q8) CRLF in ml string becomes LF", G, "Utf8.string(\"\\r\\n\").map(|_| ['\\r', '\\n'])", "Utf8.string(\"\\r\\n\").map(|_| ['\\n'])", S1),
    ("M6 hex integer read as base 8", G, "radix_rule(\"0x\", hex_digits, 16)", "radix_rule(\"0x\", hex_digits, 8)", S1),
    ("M7 octal integer read as base 10", G, "radix_rule(\"0o\", octal_digits, 8)", "radix_rule(\"0o\", octal_digits, 10)", S1),
    ("M8 binary digit 2 accepted", G, "is_binary = |b| b == '0' or b == '1'", "is_binary = |b| b >= '0' and b <= '2'", S1),
    ("M9 double underscore accepted", G, ".skip(Utf8.codeunit('_')).keep(d)", ".skip(Utf8.codeunit('_').many()).keep(d)", S1),
    ("M10 i64 range: radix overflow wraps", G, "times = $n.times_try(base) ? |_| \"integer out of range\"", "times = $n.times_wrap(base)", S1),
    ("M11 leading zero accepted in decimal", G, ".keep(Utf8.codeunit_satisfies(|b| b >= '1' and b <= '9'))", ".keep(Utf8.codeunit_satisfies(|b| b >= '0' and b <= '9'))", S1),
    ("M12 -inf reads as inf", G, "if negative(s) -F64.infinity else F64.infinity", "if negative(s) F64.infinity else F64.infinity", S1),
    ("M13 exponent sign dropped", G, "['e'].concat(minus(s)).concat(digits)", "['e'].concat(digits)", S1),
    ("M14 offset minutes: hour * 100", G, "h.to_i16() * 60 + m.to_i16()", "h.to_i16() * 100 + m.to_i16()", S1),
    ("M15 nanoseconds rounded, not truncated", G, "List.repeat(0, 9 - first.len()).fold(n, |acc, _| acc * 10)\n",
     "List.repeat(0, 9 - first.len()).fold(n, |acc, _| acc * 10) + (if (digits.get(9) ?? '0') >= '5' 1 else 0)\n", S1),
    ("M16 V-DT12 (Q9) second 60 rejected", G, "} else if second > 60 {", "} else if second > 59 {", S1),
    ("M17 V-DT12 (Q9) second 61 accepted", G, "} else if second > 60 {", "} else if second > 61 {", S1),
    ("M18 leap year: every 4th year", G, "(year % 4 == 0 and year % 100 != 0) or year % 400 == 0", "year % 4 == 0", S1),
    ("M19 offset date-time and local date-time order", G, "offset_date_time.alt(local_date_time)", "local_date_time.alt(offset_date_time)", S1),
    ("M20 Value.is_eq: NaN not equal", V, "(x.is_nan() and y.is_nan()) or x == y", "x == y", S1),
    ("M21 empty array not accepted", G, ".keep(comma_in_array.maybe())\n\t\t.alt(Parser.const([]))", ".keep(comma_in_array.maybe())", S1),
    ("M22 newline accepted in inline table", G, "Parser.const({}).skip(ws).skip(Utf8.codeunit(',')).skip(ws)", "Parser.const({}).skip(ws).skip(Utf8.codeunit(',')).skip(ws_comment_newline)", S1),
    ("M23 array trailing comma not accepted", G, "Parser.const(|items| |_| items)\n\t\t.keep(element.sep_by_one_or_more(comma_in_array))\n\t\t.keep(comma_in_array.maybe())",
     "Parser.const(|items| |_| items)\n\t\t.keep(element.sep_by_one_or_more(comma_in_array))\n\t\t.keep(Parser.const({}))", S1),
    ("M24 Toml.get: empty path is NotFound", K, "get = |doc, path| lookup(Value.Table(doc.table), path)", "get = |doc, path| if path.is_empty() Err(NotFound) else lookup(Value.Table(doc.table), path)", S2),
    # Slice 2: structure
    ("M25 dotted key: no whitespace around the dot", G, "Parser.const({}).skip(ws).skip(Utf8.codeunit('.')).skip(ws)", "Parser.const({}).skip(Utf8.codeunit('.'))", S2),
    ("M26 table defined twice accepted", T, "\t\t(Ok(Tab(_)), _) => Err(\"the table is defined twice\")", "\t\t(Ok(Tab(t)), Bool.False) => Ok(Tab(t))\n\t\t(Ok(Tab(_)), _) => Err(\"the table is defined twice\")", S2I),
    ("M27 key defined twice accepted", T, "if t.kids.contains(k) {", "if t.kids.contains(k) and Bool.False {", S2I),
    ("M28 dotted key adds to a table of another section", T, "Ok(Tab({ made: Dotted(n), kids })) if n == sid =>", "Ok(Tab({ made: Dotted(n), kids })) =>", S2I),
    ("M29 [[a]] keys go to the first element", T, "match items.last() {", "match items.first() {", S2),
    ("M30 error column on line 1 is 0-based", D, "Err(_) => offset + 1", "Err(_) => offset", S2),
    ("M31 error column after newline off by one", D, "Ok(i) => offset - i", "Ok(i) => offset - i - 1", S2),
    ("M32 error line is 0-based", D, "line_of = |bytes, offset| 1 + bytes", "line_of = |bytes, offset| 0 + bytes", S2),
    ("M33 error offset ignores the BOM", D, "|e| { offset: bom + e.offset, message: e.message }", "|e| { offset: e.offset, message: e.message }", S2),
    ("M34 BOM not skipped", D, "if bytes.starts_with([0xEF, 0xBB, 0xBF]) 3 else 0", "if bytes.starts_with([0xEF, 0xBB, 0xBF]) 0 else 0", S2),
    ("M35 S-BOM4 BOM in a comment rejected", G, "comment_class = Utf8.ByteClass.from_predicate(|b| b == '\\t' or (b >= 0x20 and b != 0x7F))", "comment_class = Utf8.ByteClass.from_predicate(|b| b == '\\t' or (b >= 0x20 and b != 0x7F and b != 0xEF))", S2),
    ("M36 N1 nesting limit 129", D, "max_depth = 128", "max_depth = 129", S2F),
    ("M37 N1 nesting limit 127", D, "max_depth = 128", "max_depth = 127", S2F),
    ("M38 S-DEEP4 '[' in a comment counts", D, "'#' => { next: Comment, skip: 1, delta: Same }", "'#' => { next: Normal, skip: 1, delta: Same }", S2F),
    ("M39 lone CR is a newline", G, "Utf8.string(\"\\r\\n\").map(|_| ['\\r', '\\n'])", "Utf8.string(\"\\r\").map(|_| ['\\r', '\\n'])", S2I),
    ("M40 [a] after [[a]] accepted", T, "(Ok(Aot(_)), Bool.False) => Err(\"the name is an array of tables\")", "(Ok(Aot(items)), Bool.False) => Ok(Aot(items))", S2I),
    # Slice 3: print
    ("M41 print: U+007F not escaped", X, "is_control = |b| b < 0x20 or b == 0x7F", "is_control = |b| b < 0x20", S3),
    ("M42 print: lowercase hex in \\u", X, "'A' + n - 10", "'a' + n - 10", S3),
    ("M43 print: float without .0", V, "if s.contains(\".\") or s.contains(\"e\") s else \"${s}.0\"", "if s.contains(\".\") or s.contains(\"e\") s else s", S3),
    ("M44 print: trailing zeros of fraction kept", V, "kept = digits.len() - count_trailing(digits, '0')", "kept = digits.len()", S3),
    ("M45 print: offset 0 as +00:00", V, "if minutes == 0 {\n\t\t\"Z\"", "if minutes == 0 {\n\t\t\"+00:00\"", S3),
    ("M46 print: offset sign reversed", V, "sign = if minutes < 0 \"-\" else \"+\"", "sign = if minutes < 0 \"+\" else \"-\"", S3),
    ("M47 print: no header for an empty table", P, "path.is_empty() or (lines.is_empty() and !nested.is_empty())", "path.is_empty() or lines.is_empty()", S3),
    ("M48 print: no blank line before a header", P, "gap = if $out.is_empty() \"\" else \"\\n\"", "gap = \"\"", S3),
    ("M49 print: '-' not a bare key byte", X, " or b == '_' or b == '-'", " or b == '_'", S3),
    ("M50 print: sections before values", P, "[own].concat(rest)", "rest.concat([own])", S3),
    ("M51 print: inf as Infinity sign lost", V, "if f > 0 \"inf\" else \"-inf\"", "\"inf\"", S3),
    # Slice 4: span edit of values
    ("M52 to_str gives the print", K, "to_str = |doc| doc.text", "to_str = |doc| Print.document(doc.table)", S4T),
    ("M53 E-BOM1 to_str drops the BOM", K, "Ok({ table, index }) => Ok({ text, table, index })", "Ok({ table, index }) => Ok({ text: text.drop_prefix(\"\\u(FEFF)\"), table, index })", S4T),
    ("M54 replace changes the byte before the value", E, "Ok(splice(bytes, e.value.start, e.value.end, value_text(old, new)))", "Ok(splice(bytes, e.value.start - 1, e.value.end, \" ${value_text(old, new)}\"))", S4F),
    ("M55 replace eats the same-line comment", E, "Ok(splice(bytes, e.value.start, e.value.end, value_text(old, new)))", "Ok(splice(bytes, e.value.start, line_end(bytes, e.value.end), \"${value_text(old, new)}${newline_of(bytes)}\"))", S4F),
    ("M56 Q6 literal string not kept", E, "Literal => if fits_literal(s) \"'${s}'\" else Text.basic(s)", "Literal => Text.basic(s)", S4),
    ("M57 Q6 literal kept with a control character", E, "fits_literal = |s| s.to_utf8().all(|b| b != '\\'' and (b == '\\t' or !Text.is_control(b)))", "fits_literal = |s| s.to_utf8().all(|b| b != '\\'')", S4),
    ("M58 Q13 ml literal read as literal", E, "if old.starts_with(['\\'', '\\'', '\\'']) {", "if old.starts_with(['\\'', '\\'', '\\'', '\\'']) {", S4),
    ("M59 Q13 ml basic: newline as \\n", X, "0x0A => if raw_newline ['\\n'] else ['\\\\', 'n']", "0x0A => ['\\\\', 'n']", S4),
    ("M60 Q13 ml literal kept with '''", E, "fits_ml_literal = |s| !s.contains(\"'''\") and", "fits_ml_literal = |s|", S4),
    ("M61 Toml.line gives the line of the value end", E, "Ok(Doc.line_of(text.to_utf8(), first_key(e)))", "Ok(Doc.line_of(text.to_utf8(), e.value.end))", S4),
    ("M62 NoEntry: path into an array of tables", E, "index.ents.find_first(|e| e.path == path and reaches(index, e))", "index.ents.find_first(|e| e.path == path)", S4),
    ("M63 NoEntry: the empty path", E, "if path.is_empty() {\n\t\tErr(NoEntry)", "if path.len() > 99 {\n\t\tErr(NoEntry)", S4),
    # Slice 5: whole entries
    ("M64 Q1 insert after the header, not the last entry", E, "\tmatch last_line_entry(index, s) {\n\t\tOk(e) => after_line(bytes, index.bom, e.value.end, entry, nl)",
     "\tmatch last_line_entry(index, s) {\n\t\tOk(_) => after_line(bytes, index.bom, index.secs.get(s).map_ok(|sec| sec.end) ?? 0, entry, nl)", S5),
    ("M65 Q11 root insert: no blank line before the header", E, "splice(bytes, at, at, \"${entry}${nl}${nl}\")", "splice(bytes, at, at, \"${entry}${nl}\")", S5),
    ("M66 Q11 root insert: at the top, not after the comments", E, "at = line_start(bytes, first.start, index.bom)", "at = index.bom", S5),
    ("M67 Q3 inline insert: no space after comma", E, "splice(bytes, last_end, last_end, \", ${pair}\")", "splice(bytes, last_end, last_end, \",${pair}\")", S5),
    ("M68 Q12 {} insert: no spaces", E, "\" ${pair} \")", "\"${pair}\")", S5),
    ("M69 Q7 CRLF text gets LF", E, "Ok(i) if i > 0 and bytes.get(i - 1) == Ok('\\r') => \"\\r\\n\"", "Ok(i) if i > 0 and bytes.get(i - 1) == Ok('\\r') => \"\\n\"", S5),
    ("M70 Q2 new header: no blank line before it", E, "gap = if ends_open(bytes, bom) \"${nl}${nl}\" else nl", "gap = if ends_open(bytes, bom) nl else \"\"", S5),
    ("M71 insert into an array of tables not NotATable", E, "\t\t\t\tOk(_) => Err(NotATable)\n\t\t\t\tErr(_) => Err(Missing)", "\t\t\t\tOk(_) => Err(Missing)\n\t\t\t\tErr(_) => Err(Missing)", S5),
    ("M72 insert of an existing key not KeyExists", E, "Ok(t) => if t.contains(key) Err(KeyExists) else Ok({})", "Ok(_) => Ok({})", S5),
    ("M73 Q3 dotted insert: full path, not from the section", E, "Text.path(parent.drop_first(base).append(key))", "Text.path(parent.append(key))", S5),
    ("M74 Q4 remove keeps the same-line comment", E, "end: line_end(bytes, e.value.end) }", "end: e.value.end }", S5F),
    ("M75 Q4 remove takes the comment line above", E, "Line => { start: line_start(bytes, first_key(e), bom),", "Line => { start: line_start(bytes, line_start(bytes, first_key(e), bom) - (if line_start(bytes, first_key(e), bom) > bom 1 else 0), bom),", S5F),
    ("M76 Q4 remove last inline entry keeps the comma", E, "{ start: i.prev_end, end: e.value.end }", "{ start: first_key(e), end: e.value.end }", S5),
    ("M77 Q4 remove inner inline entry keeps the comma", E, "{ start: first_key(e), end: i.next_start }", "{ start: first_key(e), end: e.value.end }", S5),
    ("M78 Q12 remove the only inline entry keeps spaces", E, "{ start: i.open, end: i.close }", "{ start: first_key(e), end: e.value.end }", S5),
    ("M79 Q5 rename without KeyExists", E, "if has_key(table, path.drop_last(1), new_key) {", "if Bool.False {", S5),
    ("M80 Q5 rename: new key always quoted", E, "Ok(splice(text.to_utf8(), span.start, span.end, Text.key(new_key)))", "Ok(splice(text.to_utf8(), span.start, span.end, Text.basic(new_key)))", S5),
    ("M81 Q5 rename changes the first key of a dotted key", E, "span = e.keys.last() ?? e.value", "span = e.keys.first() ?? e.value", S5),
    ("M82 Q10 remove of the first line drops the BOM", E, "while $i > floor and bytes.get($i - 1) != Ok('\\n') {", "while $i > floor * 0 and bytes.get($i - 1) != Ok('\\n') {", S5),
    # Slice 6 (0.2.0), C1: InvalidValue. Check.roc is also used by parse, so values.roc runs too.
    ("M83 C1 year 10000 valid", C, "if year > 9999 {", "if year > 10000 {", S6C),
    ("M84 C1 month 13 valid", C, "month < 1 or month > 12", "month < 1 or month > 13", S6C),
    ("M85 C1 month 0 valid", C, "month < 1 or month > 12", "month > 12", S6C),
    ("M86 C1 day 0 valid", C, "day < 1 or day > days_in_month(year, month)", "day > days_in_month(year, month)", S6C),
    ("M87 C1 November has 31 days", C, "4 | 6 | 9 | 11 => 30", "4 | 6 | 9 => 30", S6C),
    ("M88 C1 leap year: every 4th year (2100-02-29 valid)", C, "2 => if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 29 else 28", "2 => if year % 4 == 0 29 else 28", S6C),
    ("M89 C1 leap year: no 400 rule (2000-02-29 invalid)", C, "2 => if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 29 else 28", "2 => if year % 4 == 0 and year % 100 != 0 29 else 28", S6C),
    ("M90 C1 hour 24 valid", C, "if hour > 23 {", "if hour > 24 {", S6C),
    ("M91 C1 minute 60 valid", C, "} else if minute > 59 {", "} else if minute > 60 {", S6C),
    ("M92 C1 (Q9) second 60 invalid", C, "} else if second > 60 {", "} else if second > 59 {", S6C),
    ("M93 C1 second 61 valid", C, "} else if second > 60 {", "} else if second > 61 {", S6C),
    ("M94 C1 (Q17) nanosecond 1000000000 valid", C, "nanosecond > 999_999_999", "nanosecond > 1_000_000_000", S6C),
    ("M95 C1 (Q17) nanosecond 999999999 invalid", C, "nanosecond > 999_999_999", "nanosecond >= 999_999_999", S6C),
    ("M96 C1 offset +24:00 valid", C, "minutes >= -1439 and minutes <= 1439", "minutes >= -1439 and minutes <= 1440", S6C),
    ("M97 C1 offset -24:00 valid", C, "minutes >= -1439 and minutes <= 1439", "minutes >= -1440 and minutes <= 1439", S6C),
    ("M98 C1 offset +23:59 invalid", C, "minutes >= -1439 and minutes <= 1439", "minutes >= -1439 and minutes < 1439", S6C),
    ("M99 C1 offset date-time: time not checked", C, "Value.OffsetDateTime({ date, time, offset_minutes }) => date_problem(date).is_empty() and time_problem(time).is_empty() and",
     "Value.OffsetDateTime({ date, time, offset_minutes }) => date_problem(date).is_empty() and time.hour < 255 and", S6C),
    ("M100 C1 local date-time: date not checked", C, "Value.LocalDateTime({ date, time }) => date_problem(date).is_empty() and time_problem(time).is_empty()",
     "Value.LocalDateTime({ date, time }) => date.year <= 65535 and time_problem(time).is_empty()", S6C),
    ("M101 C1 nested: array not checked", C, "Value.Array(items) => items.all(Check.value_ok)", "Value.Array(items) => items.len() >= 0", S6C),
    ("M102 C1 nested: inline table not checked", C, "Value.Table(t) => t.to_list().all(|(_, v)| Check.value_ok(v))", "Value.Table(t) => t.len() >= 0", S6C),
    ("M103 C1 replace writes an invalid value (no check)", E, "\t\te = find(index, path)?\n\t\tvalid(new)?\n", "\t\te = find(index, path)?\n", S6E),
    ("M104 C1 insert writes an invalid value (no check)", E, "\t\t\t\tvalid(value)?\n", "", S6E),
    ("M105 P6-2 replace: InvalidValue before NoEntry", E, "\t\te = find(index, path)?\n\t\tvalid(new)?\n", "\t\tvalid(new)?\n\t\te = find(index, path)?\n", S6E),
    ("M106 P6-2 insert: InvalidValue before KeyExists and NotATable", E, "\t\t\t\tcheck_insert(table, path.drop_last(1), path.last() ?? \"\")?\n\t\t\t\tvalid(value)?\n",
     "\t\t\t\tvalid(value)?\n\t\t\t\tcheck_insert(table, path.drop_last(1), path.last() ?? \"\")?\n", S6E),
    ("M107 C1 replace on InvalidValue gives Ok with the document unchanged", K, "replace = |doc, path, new| Edit.replace(doc.text, doc.index, path, new).map_ok(reread)",
     "replace = |doc, path, new| Edit.replace(doc.text, doc.index, path, new).map_ok(reread).on_err(|e| match e { InvalidValue => Ok(doc), NoEntry => Err(NoEntry) })", S6E),
    # Slice 6, C2: error columns
    ("M108 C2 syntax column: no furthest failure in a line (0.1.0 seal)", G, "line = Parser.lazy(|_| line_rule)", "line = Parser.custom(|input| Parser.run(line_rule, input))", S6S),
    ("M109 C2 end of the text: the column of the last byte", D, "column: column_of(bytes, offset), message })", "column: column_of(bytes, if offset > 0 and offset >= bytes.len() offset - 1 else offset), message })", S6S),
    ("M110 C2 line 1 column without the BOM bytes", D, "Err(_) => offset + 1", "Err(_) => offset + 1 - bom_size(bytes)", S6S),
    ("M111 C2 (Q18) dotted key: column of the first part", T, "changed = put(kid, rest, value, sid, at + 1)?", "changed = put(kid, rest, value, sid, at)?", S6S),
    ("M112 C2 (Q18) [a.b] again: column of the first part", T, "changed = open(kid, rest, array, at + 1)?", "changed = open(kid, rest, array, at)?", S6S),
    ("M113 C2 (Q18) inline table: column of the first key", D, "$tree = Tree.entry($tree, [], names(p.keys), v, 0) ? |e| { offset: part_start(p.keys, e.at, key_start(p, total), total), message: e.message }",
     "$tree = Tree.entry($tree, [], names(p.keys), v, 0) ? |e| { offset: key_start(p, total), message: e.message }", S6S),
    ("M114 C2 table defined again: column of '['", D, "offset: part_start(h.keys, e.at, total - h.start, total), message: e.message }", "offset: total - h.start, message: e.message }", S6S),
    ("M115 C2 i64 overflow: a syntax error, not a rule error", G, ".alt(integer.map(|r| rule_checked(r, |n| Value.Integer(n))))", ".alt(integer.flatten().map(|n| Scalar(Value.Integer(n))))", S6S),
    ("M116 C2 date that does not exist: column of the value end", D, "Odd(_, m) => Err({ offset: total - node.start, message: m })", "Odd(_, m) => Err({ offset: total - node.end, message: m })", S6S),
    ("M117 C2 word matcher: failure at the start of the word", G, "Err(ParseError({ message, offset: common_prefix(input, expected) }))", "Err(ParseError({ message, offset: 0 }))", S6S),
    ("M118 C2 bare CR: Utf8.string, not word", G, ".alt(word(\"\\r\\n\").map(|_| ['\\r', '\\n']))", ".alt(Utf8.string(\"\\r\\n\").map(|_| ['\\r', '\\n']))", S6S),
    ("M119 C2 bad \\u escape: column of the backslash", G, "offset: 1 + count_while(digits, is_hex) }))", "offset: 1 }))", S6S),
]


def same_tree():
    for root, _, files in os.walk(ORIG):
        for f in files:
            o = os.path.join(root, f)
            p = os.path.join(REPO, "package", os.path.relpath(o, ORIG))
            if not os.path.exists(p) or not filecmp.cmp(o, p, shallow=False):
                return False
    for root, _, files in os.walk(REPO + "/package"):
        for f in files:
            if not os.path.exists(os.path.join(ORIG, os.path.relpath(os.path.join(root, f), REPO + "/package"))):
                return False
    return True


def ids_at(test, lines):
    # The rule id of each failed expect: the first word of the comment above it.
    src = open(f"{REPO}/tests/{test}").read().split("\n")
    out = []
    for n in lines:
        i = n - 1
        while i >= 0 and not src[i].startswith("# "):
            i -= 1
        out.append(src[i][2:].split(",")[0].split(" ")[0] if i >= 0 else f"line{n}")
    return sorted(set(out))


def fuzz_run(f, no_cache):
    exe = f"{W}/fuzz/m-{f}"
    if os.path.exists(exe):
        os.remove(exe)
    cmd = [ROC, "build", "--fuzz", f"fuzz/{f}.roc", f"--output={exe}"] + (["--no-cache"] if no_cache else [])
    subprocess.run(cmd, cwd=REPO, env=env, capture_output=True, text=True)
    if not os.path.exists(exe):
        return "build-fail", ""
    art = f"{W}/fuzz/mart-{f}"
    shutil.rmtree(art, ignore_errors=True)
    os.makedirs(art, exist_ok=True)
    r = subprocess.run([exe, "run", f"--runs={runs}", "--seed=1", "--time=0",
                        "--dictionary=fuzz/dictionaries/toml.dict", f"--artifact-dir={art}"],
                       cwd=REPO, env=env, capture_output=True, text=True)
    out = r.stdout + r.stderr
    if r.returncode == 0:
        return None, out
    m = re.search(r"roc crashed\]?[: ]*(.*)", out)
    return f"exit {r.returncode}" + (f": {m.group(1)[:70]}" if m else ""), out


only = sys.argv[2:]
wide = os.environ.get("ALL") == "1"
for name, rel, old, new, (tests, fuzz) in M:
    if wide:
        tests, fuzz = ALL
    mid = name.split()[0]
    if only and mid not in only:
        continue
    assert same_tree(), "package changed before " + name
    src, orig_f = os.path.join(REPO, "package", rel), os.path.join(ORIG, rel)
    orig = open(orig_f).read()
    assert orig.count(old) == 1, name + ": old text count " + str(orig.count(old))
    open(src, "w").write(orig.replace(old, new))
    lineno = orig[: orig.index(old)].count("\n") + 1
    res = []
    try:
        chk = subprocess.run([ROC, "check", "package/main.roc"], cwd=REPO, env=env, capture_output=True, text=True)
        co = chk.stdout + chk.stderr
        if chk.returncode != 0 and not re.search(r"\b0 errors? and \d+ warnings?", co):
            res.append("CHECK-ERROR")
        for t in tests:
            p = subprocess.run([ROC, "test", "tests/" + t, "--no-cache"], cwd=REPO, env=env, capture_output=True, text=True)
            out = p.stdout + p.stderr
            open(f"{W}/mut-{mid}-{t}.log", "w").write(out)
            # A warning gives a non-zero exit too: only failed expects or a crash count.
            if p.returncode != 0 and not re.search(r"All \(\d+\) tests passed", out):
                m = re.search(r"(\d+) failed", out)
                fl = sorted(set(int(x) for x in re.findall(r"tests/" + re.escape(t) + r":(\d+)", out)))
                ids = ids_at(t, fl)
                crashed = "crash" in out.lower()
                res.append(f"{t}: {m.group(0) if m else ('crash' if crashed else 'fail')} {' '.join(ids[:8])}{' ...' if len(ids) > 8 else ''}")
        for f in fuzz:
            err, out = fuzz_run(f, False)
            if err and re.search(r"leak", out, re.I):
                err2, _ = fuzz_run(f, True)
                err = (err2 + " (no-cache)") if err2 else None
            if err:
                res.append(f"{f}: {err}")
    finally:
        shutil.copyfile(orig_f, src)
    assert same_tree()
    print(f"{name} || {rel}:{lineno} || {'; '.join(res) if res else 'NOT CAUGHT'}", flush=True)
